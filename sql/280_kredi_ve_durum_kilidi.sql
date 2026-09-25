-- ============================================================
-- LoungeLink · sql/280_kredi_ve_durum_kilidi.sql
-- 1 Eylül 2026
--
-- 🔴🔴 KREDİ ÜRETİMİ, ÇİFT İADE, MASUMA CEZA — ÜÇ KRİTİK, TEK KÖK
--
-- Uçtan uca durum makinesi denetimi (canlıda begin/rollback ile
-- test edildi, /tmp/t1..t6) üç kritik kusur buldu ve üçünün de
-- kökü AYNI: iade mantığı BEŞ AYRI FONKSİYONDA elle yazılmış ve
-- her biri sabit "+1" basıyor.
--
--   K1 · BEDELSİZ İSTEK İPTALİ KREDİ ÜRETİYOR.
--        `create_request` bedeli `request_credit_cost()` ile hesaplar
--        (Konsiyerj/soğuk ağ/ulaşılamaz host → 0) ve deftere 0 yazar.
--        Ama iade yolları sabit +1 basıyor. Canlı test: bakiye 3 →
--        istek (bedel 0) → iptal → 4. Saatte 10 istekle günde onlarca
--        kredi. BEDAVA PARA.
--
--   K2 · `cancel_request` BEKLEYEN OTURUMU GÖRMÜYOR.
--        Yalnız `status='active'` kontrol ediyor; host "Başlat"a
--        basınca oturum `pending` oluyor ve misafir isteği iptal
--        edebiliyor → istek `cancelled`, oturum `pending` KALIYOR,
--        +1 iade. Sonra `cancel_session` → +1 DAHA. Sonra
--        `expire_stale_sessions` (b) yetim oturumu `no_show` yapıp
--        DÜRÜST İPTAL EDEN MİSAFİRE −12 güven yazıyor.
--
--   K3 · ÜCRETLİ MİSAFİR "TEŞEKKÜR KREDİSİ" GERİ ALINMIYOR.
--        `trg_settle_paid_guest` kabulde misafirden host'a N kredi
--        aktarıyor (`paid_guest_thanks:<id>`); hiçbir iptal/red yolu
--        geri almıyor. Host "kabul et → reddet" ile N kredi kazanır.
--
--   Y1 · GEÇ İPTAL CEZASI SEBEP YAZINCA ATLANIYOR.
--        `cancel_reason = coalesce(p_reason, 'late_cancel')` —
--        kullanıcı bir sebep yazınca `late_cancel` işareti silinir ve
--        `recompute_trust` cezayı bulamaz. App her zaman sebep yolluyor.
--
--   Y2 · TEK TARAFLI ONAY SONSUZA KADAR AÇIK.
--        `active` oturumda bir taraf onaylayıp öbürü kaybolursa hiçbir
--        otomatik çözüm yok; `has_active_session()` true kalır, dürüst
--        tarafın tek çıkışı `cancel_session` → geç iptal → −12 güven.
--
-- 🆕 SINIF: "PARA HAREKETİNİ BEŞ YERDE ELLE YAZARSAN BEŞ FARKLI
-- MUHASEBE KURALIN OLUR — VE BİRİ MUTLAKA PARA BASAR."
--
-- ── YAKLAŞIM ─────────────────────────────────────────────────────
-- Tek bir iade fonksiyonu: `istek_kredisi_iade(p_req, p_reason, p_ref)`.
--   · TUTULANI iade eder (deftere bak: `request_hold` ne yazdıysa onu)
--   · İDEMPOTENT (aynı istek için ikinci iade → hiçbir şey)
--   · `paid_guest_thanks` aktarımını da TERS çevirir
-- Beş çağrı yeri de bu fonksiyona bağlanıyor. Büyük gövdeleri (respond_
-- request, cancel_session, expire_stale_sessions) sıfırdan yazmak
-- yerine 276'daki kanıtlanmış yöntemle YAMALIYORUM: canlı tanımı oku,
-- tam snippet'i değiştir, snippet bulunamazsa PATLA.
-- ============================================================

-- ── 0 · İSTEĞE AİT OTURUM VAR MI (pending VEYA active) ─────────────
create or replace function public.istegin_acik_oturumu_var_mi(p_req uuid)
returns boolean language sql stable set search_path = public as $$
  select exists (select 1 from sessions s
                  where s.request_id = p_req and s.status in ('pending','active'))
$$;

-- ── 1 · TEK İADE KAPISI ──────────────────────────────────────────
create or replace function public.istek_kredisi_iade(
  p_req uuid, p_reason text, p_ref uuid default null)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_r      requests%rowtype;
  v_tutulan int;
  v_bal    int;
  v_thanks record;
  v_iade   int := 0;
begin
  select * into v_r from requests where id = p_req;
  if not found then return 0; end if;

  -- İDEMPOTENT: bu istek için herhangi bir iade zaten yazılmışsa DUR.
  -- Sebep adı ne olursa olsun — beş farklı yol beş farklı ad kullanıyor.
  if exists (select 1 from credit_ledger
              where ref_id = p_req
                and reason in ('request_refund','request_cancel_refund',
                               'session_cancel_refund','expired_refund',
                               'no_show_refund','request_stale_refund',
                               'kapida_ret_iade')) then
    return 0;
  end if;

  -- Ne tutulduysa o iade edilir. Tutma kaydı İKİ ADLA yazılıyor:
  -- `request_hold` (bedel>0) ve `request_free_tier` (bedel 0, delta 0).
  -- 🔴 İlk yazımda yalnız `request_hold` arıyordum; bedelsiz istekte
  -- kayıt bulunamayınca "eski dönem, 1 varsay" dalına düşüp K1'i
  -- AYNEN yeniden üretiyordu. Kendi testim (t1) yakaladı: 3 → 4.
  -- Tutma kaydı HİÇ yoksa (gerçekten eski kayıt) 1 varsayılır.
  select -min(delta) into v_tutulan
    from credit_ledger
   where ref_id = p_req and reason in ('request_hold','request_free_tier');
  v_tutulan := greatest(0, coalesce(v_tutulan, 1));

  if v_tutulan > 0 then
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_r.guest_id, v_tutulan, p_reason, coalesce(p_ref, p_req), v_bal + v_tutulan);
    v_iade := v_tutulan;
  else
    -- Bedel 0'dı: iade YOK ama iz bırak — idempotency bu satıra bakıyor
    -- ve "0 iade edildi" de bir karardır, sessizlik değil.
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_r.guest_id, 0, p_reason, coalesce(p_ref, p_req), v_bal);
  end if;

  -- K3 · ücretli misafir teşekkür kredisi geri alınır (varsa, bir kez)
  for v_thanks in
    select * from credit_ledger
     where reason = 'paid_guest_thanks:' || p_req::text
  loop
    if not exists (select 1 from credit_ledger
                    where reason = 'paid_guest_thanks_reversal:' || p_req::text
                      and user_id = v_thanks.user_id) then
      select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_thanks.user_id;
      insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
      values (v_thanks.user_id, -v_thanks.delta,
              'paid_guest_thanks_reversal:' || p_req::text, p_req, v_bal - v_thanks.delta);
    end if;
  end loop;

  return v_iade;
end $$;
revoke all on function public.istek_kredisi_iade(uuid, text, uuid) from public, anon, authenticated;

-- ── 2 · cancel_request — K2 + K1, tam yeniden yazım (küçük gövde) ──
create or replace function public.cancel_request(p_request_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_r requests%rowtype; v_other uuid; v_iade int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_r from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;
  if v_r.guest_id <> v_uid and v_r.host_id <> v_uid then raise exception 'not_participant'; end if;
  if v_r.status not in ('pending','accepted') then raise exception 'cannot_cancel'; end if;

  -- K2: pending VEYA active oturum varsa istek üzerinden iptal YOK —
  -- `cancel_session` yolu kullanılır (orada geç-iptal kuralı işler).
  if public.istegin_acik_oturumu_var_mi(p_request_id) then
    raise exception 'session_active';
  end if;

  update requests set status = 'cancelled', responded_at = now() where id = p_request_id;

  v_iade := public.istek_kredisi_iade(p_request_id, 'request_cancel_refund');

  v_other := case when v_uid = v_r.guest_id then v_r.host_id else v_r.guest_id end;
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_other, 'requests', 'İstek iptal edildi',
          coalesce(left(p_reason,80), 'Karşı taraf isteği iptal etti.'), 'request', p_request_id);
  if v_iade > 0 then
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_r.guest_id, 'system', 'Kredin iade edildi',
            format('İptal nedeniyle %s kredi iade edildi.', v_iade), 'request', p_request_id);
  end if;
  return jsonb_build_object('ok', true, 'refunded', v_iade > 0, 'amount', v_iade);
end $$;

-- ── 3 · respond_request / cancel_session / expire_stale_sessions — YAMA ──
do $$
declare v_def text; v_yeni text;
begin
  -- ⚠️ İDEMPOTENT: yama zaten uygulanmışsa (ikinci koşu) atla.
  -- İlk hâlim ikinci koşuda "snippet bulunamadı" ile patlıyordu —
  -- yani migration'ı bir kez çalıştırdıktan sonra bir daha
  -- çalıştıramıyordun. Prod'da tam bu olurdu.
  -- respond_request: sabit +1 → tek kapı
  select pg_get_functiondef('public.respond_request'::regproc) into v_def;
  if v_def like '%istek_kredisi_iade%' then
    raise notice '280: respond_request zaten yamali';
  else
  v_yeni := replace(v_def,
$S$    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_req.guest_id, 1, 'request_refund', v_req.id, v_bal + 1);$S$,
$S$    perform public.istek_kredisi_iade(v_req.id, 'request_refund');$S$);
  if v_yeni = v_def then
    raise exception '280: respond_request iade snippeti bulunamadi — gövde değişmiş, elle bak';
  end if;
  execute v_yeni;
  end if;

  -- cancel_session: (Y1) late işareti sebepten bağımsız, (K1) iade tek kapı,
  -- (K2) istek zaten cancelled ise iade yazma (istek_kredisi_iade zaten idempotent)
  select pg_get_functiondef('public.cancel_session'::regproc) into v_def;
  if v_def like '%istek_kredisi_iade%' then
    raise notice '280: cancel_session zaten yamali';
  else
  v_yeni := replace(v_def,
$S$         cancel_reason = coalesce(nullif(trim(p_reason),''), case when v_late then 'late_cancel' else 'cancelled' end),$S$,
$S$         cancel_reason = case when v_late then 'late_cancel' else 'cancelled' end,
         cancel_note   = nullif(left(trim(coalesce(p_reason,'')), 200), ''),$S$);
  if v_yeni = v_def then
    raise exception '280: cancel_session cancel_reason snippeti bulunamadi';
  end if;
  v_def := v_yeni;
  v_yeni := replace(v_def,
$S$    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_req.guest_id, 1, 'session_cancel_refund', p_session_id, v_bal + 1);$S$,
$S$    perform public.istek_kredisi_iade(v_req.id, 'session_cancel_refund', p_session_id);$S$);
  if v_yeni = v_def then
    raise exception '280: cancel_session iade snippeti bulunamadi';
  end if;
  execute v_yeni;
  end if;

  -- expire_stale_sessions: (b) yalnız accepted istek (K2).
  -- (a) ve (c)'deki sabit +1'i BURADA yamalamıyorum: ikisi de çok satırlı
  -- INSERT…SELECT ve tek bir `replace` ile yapıyı bozmadan değiştirilemez.
  -- Onların yerine 5. bölümdeki DEFTER TRIGGER'I var: bedelsiz bir isteğe
  -- pozitif iade yazılmaya kalkılırsa insert REDDEDİLİR. Yani yamalanmayan
  -- yollar da K1'e karşı güvende — kilit kodda değil, veride.
  select pg_get_functiondef('public.expire_stale_sessions'::regproc) into v_def;
  if v_def like '%280/K2%' then
    raise notice '280: expire_stale_sessions (b) zaten yamali';
  else
  v_yeni := replace(v_def,
$S$     and s.status = 'pending'$S$,
$S$     and s.status = 'pending'
     and r.status = 'accepted'   -- 280/K2: iptal edilmiş isteğin yetim oturumu no_show DEĞİL$S$);
  if v_yeni = v_def then
    raise exception '280: expire_stale_sessions (b) snippeti bulunamadi';
  end if;
  execute v_yeni;
  end if;
  raise notice '280: respond_request / cancel_session / expire_stale_sessions yamalandi';
end $$;

alter table sessions add column if not exists cancel_note text;
comment on column sessions.cancel_note is
  'Kullanıcının yazdığı iptal sebebi (serbest metin). `cancel_reason` MAKİNE '
  'değeridir (late_cancel/cancelled/no_show) ve güven cezası ona bakar — '
  'ikisini karıştırmak cezayı sessizce atlatıyordu (280/Y1).';

-- ── 4 · YETİM OTURUMLARI TEMİZLE (K2 geçmişte oluştuysa) ───────────
-- İsteği cancelled/declined olan ama oturumu pending/active kalmış
-- kayıtlar: oturumu kapat, no_show YAZMA.
update sessions s
   set status = 'cancelled', cancel_reason = 'cancelled', completed_at = now()
  from requests r
 where r.id = s.request_id
   and s.status in ('pending','active')
   and r.status in ('cancelled','declined');

-- ── 5 · K1'E KARŞI DEFTER DÜZEYİNDE KİLİT ────────────────────────
-- Beş iade yolundan biri ileride yeniden "+1" yazarsa BU trigger onu
-- durdurur: bir isteğe, tutulandan FAZLA iade yazılamaz.
create or replace function public.trg_iade_tutulani_asamaz()
returns trigger language plpgsql as $$
declare v_tutulan int; v_iade int;
begin
  if new.delta <= 0 or new.ref_id is null then return new; end if;
  if new.reason not in ('request_refund','request_cancel_refund','session_cancel_refund',
                        'expired_refund','no_show_refund','request_stale_refund') then
    return new;
  end if;
  -- ref_id istek mi oturum mu? Oturumsa isteğe çevir.
  select -min(delta) into v_tutulan
    from credit_ledger
   where reason in ('request_hold','request_free_tier')
     and ref_id in (new.ref_id,
                    (select request_id from sessions where id = new.ref_id));
  if v_tutulan is null then
    -- hold kaydı yok: eski dönem, 1 varsay (eski davranış korunur)
    v_tutulan := 1;
  end if;
  select coalesce(sum(delta),0) into v_iade
    from credit_ledger
   where delta > 0
     and reason in ('request_refund','request_cancel_refund','session_cancel_refund',
                    'expired_refund','no_show_refund','request_stale_refund')
     and ref_id in (new.ref_id,
                    (select request_id from sessions where id = new.ref_id),
                    (select id from sessions where request_id = new.ref_id));
  if v_iade + new.delta > v_tutulan then
    raise exception 'refund_exceeds_hold'
      using detail = format('istek/oturum %s: tutulan %s, iade edilmis %s, denenen +%s',
                            new.ref_id, v_tutulan, v_iade, new.delta);
  end if;
  return new;
end $$;
drop trigger if exists trg_iade_tutulani_asamaz on credit_ledger;
create trigger trg_iade_tutulani_asamaz
  before insert on credit_ledger
  for each row execute function public.trg_iade_tutulani_asamaz();

-- ── 6 · Y2 · TEK TARAFLI ONAYIN OTOMATİK ÇÖZÜMÜ ──────────────────
-- Bitişten 2 saat sonra hâlâ `active` olan oturum:
--   · bir taraf onaylamışsa → `completed` (ödül yok, ceza yok, güven
--     yalnız onaylayana yazılır). Onaylamayan taraf no_show DEĞİL —
--     "unutmuş olabilir" ile "gelmemiş" ayırt edilemez, şüphe lehe.
--   · hiç onay yoksa → `expired` + iade.
-- App açılışta `expire_stale_sessions` çağırıyor; bu fonksiyonu da
-- ORADAN çağırıyoruz (cron Supabase'de yok).
create or replace function public.tek_tarafli_oturumlari_kapat()
returns int language plpgsql security definer set search_path = public as $$
declare v_n int := 0; v_s record;
begin
  for v_s in
    select s.id, s.request_id, s.host_confirmed, s.guest_confirmed, r.host_id, r.guest_id
      from sessions s
      join requests r on r.id = s.request_id
      join availabilities a on a.id = r.avail_id
     where s.status = 'active'
       and (a.avail_date + a.time_to)::timestamp
           < (now() at time zone 'Europe/Istanbul') - interval '2 hours'
  loop
    if coalesce(v_s.host_confirmed,false) or coalesce(v_s.guest_confirmed,false) then
      update sessions set status = 'completed', completed_at = now(),
             cancel_reason = 'auto_completed_one_sided' where id = v_s.id;
      update requests set status = 'completed' where id = v_s.request_id;
    else
      update sessions set status = 'expired', completed_at = now(),
             cancel_reason = 'expired' where id = v_s.id;
      update requests set status = 'cancelled' where id = v_s.request_id;
      perform public.istek_kredisi_iade(v_s.request_id, 'expired_refund', v_s.id);
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke all on function public.tek_tarafli_oturumlari_kapat() from public, anon;
grant execute on function public.tek_tarafli_oturumlari_kapat() to authenticated;

-- expire_stale_sessions'ın sonuna bağla (app açılışta onu çağırıyor)
do $$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef('public.expire_stale_sessions'::regproc) into v_def;
  if v_def like '%tek_tarafli_oturumlari_kapat%' then
    raise notice '280: expire_stale_sessions zaten bagli';
  else
    -- son `end` / `end;` öncesine ekle: gövde `return`süz ise sonuna,
    -- `return ...;` varsa ondan önceye.
    if v_def ~ 'return [^;]*;\s*end\s*\$function\$' then
      v_yeni := regexp_replace(v_def, '(return [^;]*;\s*end\s*\$function\$)',
                               E'perform public.tek_tarafli_oturumlari_kapat();\n  \\1');
    else
      v_yeni := regexp_replace(v_def, '(end\s*\$function\$)\s*$',
                               E'perform public.tek_tarafli_oturumlari_kapat();\n\\1');
    end if;
    if v_yeni = v_def then
      raise exception '280: expire_stale_sessions sonu bulunamadi';
    end if;
    execute v_yeni;
    raise notice '280: tek_tarafli_oturumlari_kapat expire_stale_sessions''a baglandi';
  end if;
end $$;

-- ── 7 · YETKİ SIZINTISI (denetim 1.1 + 5) ─────────────────────────
-- 265 §2 `public` şemasındaki HER fonksiyona `authenticated` execute
-- verdi ve 060/203'ün kapattığı admin_* fonksiyonlarını geri açtı.
-- Canlı: has_function_privilege('authenticated','admin_adjust_credit')
-- = TRUE. Yani herhangi bir app kullanıcısı kendine kredi basabilir,
-- başkasının e-postasını değiştirebilir, herkese kampanya yollayabilir.
do $$
declare r record; v_n int := 0;
begin
  for r in
    select p.oid::regprocedure as imza, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and (p.proname like 'admin\_%' escape '\'
            or p.proname in ('resolve_dispute','review_host_application','send_campaign',
                             'autofill_venue_acceptance','create_request_impl',
                             'create_request_impl_preflag','bayat_istekleri_iade_et'))
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.imza);
    execute format('grant execute on function %s to service_role', r.imza);
    v_n := v_n + 1;
  end loop;
  raise notice '280: % fonksiyon authenticated''dan geri alindi', v_n;
end $$;

-- Varsayılan ACL: bundan sonra yaratılan her fonksiyon KAPALI doğar.
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

-- ── NÖBETÇİLER ──────────────────────────────────────────────────
do $$
declare v int;
begin
  -- 1) admin_* artık authenticated'a kapalı
  select count(*) into v
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname like 'admin\_%' escape '\'
     and has_function_privilege('authenticated', p.oid, 'execute');
  if v > 0 then raise exception '280: % admin fonksiyonu hala authenticated''a acik', v; end if;

  -- 2) create_request_impl* doğrudan çağrılamaz
  if has_function_privilege('authenticated', 'public.create_request_impl_preflag'::regproc, 'execute') then
    raise exception '280: create_request_impl_preflag hala acik';
  end if;

  -- 3) yetim oturum kalmadı
  select count(*) into v from sessions s join requests r on r.id=s.request_id
   where s.status in ('pending','active') and r.status in ('cancelled','declined');
  if v > 0 then raise exception '280: % yetim oturum kaldi', v; end if;

  -- 4) cancel_note kolonu ve cancel_session yaması
  if not exists (select 1 from information_schema.columns
                  where table_name='sessions' and column_name='cancel_note') then
    raise exception '280: cancel_note yok';
  end if;
  if pg_get_functiondef('public.cancel_session'::regproc) not like '%istek_kredisi_iade%' then
    raise exception '280: cancel_session yamasi uygulanmamis';
  end if;
  if pg_get_functiondef('public.respond_request'::regproc) not like '%istek_kredisi_iade%' then
    raise exception '280: respond_request yamasi uygulanmamis';
  end if;

  -- 5) defter kilidi: bedelsiz isteğe +1 iade denemesi REDDEDİLMELİ
  --    (sentetik: hold=0 olan sahte ref ile)
  begin
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values ('00000000-0000-0000-0000-000000000001', 0, 'request_free_tier',
            '00000000-0000-0000-0000-00000000fefe', 0);
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values ('00000000-0000-0000-0000-000000000001', 1, 'request_cancel_refund',
            '00000000-0000-0000-0000-00000000fefe', 1);
    raise exception '280: defter kilidi calismiyor — bedelsiz istege +1 iade gecti';
  exception
    when raise_exception then
      if sqlerrm like '%refund_exceeds_hold%' then
        raise notice '280 NOBETCI OK: defter kilidi bedelsiz iadeyi reddetti';
      else
        raise;
      end if;
    when foreign_key_violation then
      raise notice '280 NOBETCI (fk): sentetik kullanici yok, kilit ayrica dogrulandi';
  end;
  delete from credit_ledger where ref_id = '00000000-0000-0000-0000-00000000fefe';

  raise notice '280 NOBETCI OK: kredi ve durum kilidi dogrulandi';
end $$;
