-- ============================================================
-- LoungeLink · 162_source_truth_and_founder_badge.sql
-- CİHAZ TURU 4 — BULGULAR 6 ve 7
--
-- ⚠️ Uygulamayı ETKİLER.
--
-- ------------------------------------------------------------
-- 🔴 6) "MILES&SMILES: DOĞRULANMADI" — MOTORUN KENDİNE İFTİRASI
-- ------------------------------------------------------------
-- access_source_summary her çağrıda 'verified', FALSE döndürüyordu:
-- alan sabit yazılmıştı, hiçbir veriye bakmıyordu. Yani en iyi
-- bildiğimiz program (TK Miles&Smiles — 141 resmî ekran + canlı
-- sayfa doğrulaması, checked_at dolu) kullanıcıya "doğrulanmadı"
-- diye gösteriliyordu. Bu bir görsel kusur değil: ürünün TEK
-- farkı kural derinliği ve o fark ekranda inkâr ediliyordu.
--
-- Doğrusu: doğrulama HAKKIN SAHİBİNİN değil KURALIN özelliğidir.
-- Kullanıcının kartını doğrulayıp doğrulamadığı ayrı bir konudur
-- (host_entitlements.verified) ve zaten başka yerde gösterilir.
-- Bu kutu "bu programın kuralını resmî kaynaktan biliyor muyuz?"
-- sorusunu cevaplar — cevabı checked_at + source_url verir.
-- ============================================================

create or replace function public.access_source_summary(p_source text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_pid uuid; v_tier text; v_cost jsonb; v_prog lounge_programs%rowtype;
        v_rules int; v_fresh boolean;
begin
  -- Eşleştirme genişletildi: cihazda "Kredi Kartı Avantajı" ve
  -- "Banka / Özel Bankacılık" seçenekleri hiçbir programa bağlanmıyordu
  -- (yalnız '%kart%' vardı ve 'Havayolu Statüsü' TK_MS'e gidiyordu).
  select p.id into v_pid from lounge_programs p
   where p.active and (
     (p_source ilike '%priority%'   and p.code = 'PRIORITY_PASS') or
     (p_source ilike '%dragon%'     and p.code = 'DRAGONPASS')    or
     (p_source ilike '%loungekey%'  and p.code = 'LOUNGEKEY')     or
     (p_source ilike '%miles%'      and p.code = 'TK_MS')         or
     (p_source ilike '%ajet%'       and p.code = 'AJET_MS')       or
     (p_source ilike '%star%'       and p.code = 'STAR_GOLD')     or
     (p_source ilike '%pegasus%'    and p.code = 'PGS_PAID')      or
     (p_source ilike '%business%'   and p.code = 'BUSINESS_TICKET') or
     (p_source ilike '%havayolu%'   and p.code = 'TK_MS')         or
     ((p_source ilike '%kredi kart%' or p_source ilike '%banka%')
                                    and p.code = 'BANK_CARD'))
   limit 1;
  if v_pid is null then return jsonb_build_object('known', false); end if;

  select * into v_prog from lounge_programs where id = v_pid;
  select he.tier into v_tier from host_entitlements he
   where he.user_id = auth.uid() and he.program_id = v_pid limit 1;
  v_cost := public.entry_cost_note(v_pid, v_tier);

  -- Doğrulanmış sayılmanın İKİ şartı var ve ikisi de veriye dayanır:
  -- (a) programın kuralları resmî kaynaktan okunmuş (checked_at + url)
  -- (b) o programa ait EN AZ BİR kural satırı gerçekten modellenmiş
  select count(*) into v_rules from lounge_guest_rules r where r.program_id = v_pid;
  v_fresh := v_prog.checked_at is not null
             and v_prog.checked_at >= current_date - 180
             and coalesce(v_prog.source_url,'') <> ''
             and v_rules > 0;

  return jsonb_build_object(
    'known', true,
    'program', v_prog.name,
    'verified', v_fresh,
    'checked_at', v_prog.checked_at,
    'source_url', nullif(v_prog.source_url,''),
    'rule_count', v_rules,
    'summary', coalesce(v_cost ->> 'detail',
                        'Bu hakkın koşulları kartını veren kuruma göre değişir.'),
    'cost_warning', case when (v_cost ->> 'has_cost')::boolean
                         then v_cost ->> 'headline' end,
    'member_fee', v_cost ->> 'member_fee',
    'guest_fee', v_cost ->> 'guest_fee',
    'free_visits', v_cost -> 'free_visits');
end $$;

-- ---- DOĞRULAMA: TK_MS artık doğrulanmış görünmeli, BANK_CARD görünmemeli ----
do $$
declare a jsonb; b jsonb;
begin
  a := public.access_source_summary('Turkish Airlines Miles&Smiles');
  b := public.access_source_summary('Banka / Özel Bankacılık');
  if not coalesce((a ->> 'verified')::boolean, false) then
    raise exception '162: TK_MS hâlâ doğrulanmamış görünüyor (checked_at/source_url/kural sayısı?)';
  end if;
  if coalesce((b ->> 'verified')::boolean, false) then
    raise exception '162: BANK_CARD doğrulanmış görünüyor — bilmediğimizi biliyormuş gibi gösteriyoruz';
  end if;
end $$;

-- ============================================================
-- 🔴 7) KURUCU HOST ROZETİ: TIKLANIYOR AMA HİÇBİR YERE YAZILMIYOR
-- ------------------------------------------------------------
-- claim_founding_host sırayı veriyordu ama kullanıcıda GÖRÜNÜR bir
-- rozet oluşmuyordu: app kartı aynı kalıyor, BO'da iz yok. Rozet
-- "kalıcıdır" diye söz verilen bir şeyin hiçbir tabloda karşılığı
-- olmaması, sözün kendisini boşa çıkarır.
-- ============================================================
alter table profiles add column if not exists founding_host_no int;

-- Mevcut sıralar profile taşınır (founding_hosts tablosu varsa)
do $$
begin
  if to_regclass('public.founding_hosts') is not null then
    execute $q$
      update profiles p set founding_host_no = f.no
        from founding_hosts f
       where f.user_id = p.user_id and p.founding_host_no is null $q$;
  end if;
end $$;

-- claim_founding_host artık profile de yazar (BO profil ekranı ve app
-- aynı kaynaktan okur — iki ayrı gerçek olmaz).
do $$
declare v_src text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'claim_founding_host' and pronamespace = 'public'::regnamespace limit 1;
  if v_src is null then
    raise notice '162: claim_founding_host bulunamadı — profil yazımı atlandı';
  end if;
end $$;

create or replace function public.founding_badge_sync() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update profiles set founding_host_no = new.no where user_id = new.user_id;
  return new;
end $$;

do $$
begin
  if to_regclass('public.founding_hosts') is not null then
    drop trigger if exists trg_founding_badge on founding_hosts;
    create trigger trg_founding_badge after insert on founding_hosts
      for each row execute function public.founding_badge_sync();
  end if;
end $$;

select '162 OK - kaynak dogrulama gercek + kurucu rozet profile yaziliyor' as sonuc;
