-- ============================================================================
-- 334 · KREDİ EKONOMİSİ + KULLANICI İÇERİĞİ SÜZGECİ (16 Ekim 2026 · mağaza öncesi)
--
-- Gökberk: "kredi ve abonelik sistemlerini en doğru gözle incele… free sürümde verdiğimiz
-- imkânlar abonelik ve kredi alımlarına engel olur mu?" + "ret yememiz kesinlikle önemli".
--
-- §1 · ÖLÇÜLEN EKONOMİ SORUNLARI
--   a) Kâhya, Sık Uçan'dan KREDİ BAŞINA PAHALI: 249/12 = 20,75 ₺ · 99/6 = 16,50 ₺.
--      Üst plan, kullanıcıya "daha çok öde, kredi başına daha çok öde" diyordu.
--      → Kâhya 16 kredi (15,56 ₺/kredi). Her basamak bir öncekinden ucuz; paket
--        (39 · 33 · 29,8 ₺/kredi) her abonelikten pahalı kalır (248 kuralı).
--   b) Yolcu'nun (ücretsiz) aylık kredisi SÜRESİZ BİRİKİYOR: bir yıl uygulamayı açmayan
--      kullanıcı 12 kredi biriktirip hiç ödeme yapmadan yıl boyu kullanabiliyordu.
--      → Ücretsiz planın aylık payı BİRİKMEZ: bakiye payın altındaysa paya TAMAMLANIR.
--        Ücretli planların kredisi birikir (parası ödenmiş hak).
--   c) Kayıt hediyesi 5 kredi. Kredi yalnız GERÇEKLEŞEN buluşmada harcanıyor (red, yanıtsız,
--      kapıda ret iade) → 5 kredi = 5 ücretsiz lounge girişi. Ödeme ihtiyacını aylarca erteliyordu.
--      → 3 kredi: ilk seyahatte iki-üç deneme için yeterli; ikinci seyahatte plan anlamlı.
--   Değişmeyenler: Yolcu'nun "aynı anda 1 açık istek" sınırı (en güçlü yükseltme gerekçesi),
--   host'un ağırlayarak kredi + 2 ağırlamada 30 gün Sık Uçan hediyesi (arz tarafı sübvanse
--   edilir; az olan taraf host), paket fiyatları.
--
-- §2 · KULLANICI İÇERİĞİ SÜZGECİ (Apple Guideline 1.2)
--   255 sohbette yalnız iletişim/ödeme bilgisini süzüyordu; küfür/hakaret/cinsel içerik süzgeci
--   YOKTU ve profil, bağlantı notu, soru-cevap, puan yorumu, istek notu HİÇ süzülmüyordu.
--   → `uygunsuz_maskele`: sözcük bazlı, Türkçe büyük/küçük harf duyarlı; eşleşen sözcük
--     "•••" olur. Sohbette ayrıca işaretlenir (moderasyon kuyruğu).
--   Yanlış pozitif özeni: "Sık Uçan" (ı) etkilenmez; çıplak "sik", "got", "pic", "oc" listede
--   YOK (Türkçe karaktersiz yazımda masum anlamları var).
-- Tekrar koşulabilir.
-- ============================================================================

-- ── §1a · Kâhya 16 kredi ───────────────────────────────────────────────────
update plan_catalog
   set monthly_credits = 16,
       perks = '["Aylık 16 misafir isteği", "Aynı anda 6 açık istek", "Ayda 8 kez ilan öne çıkarma", "Öncelikli destek"]'::jsonb,
       perks_en = '["16 guest requests per month", "6 open requests at a time", "Feature a listing 8× a month", "Priority support"]'::jsonb
 where plan = 'kahya';

update plan_catalog
   set perks = '["Her ay 1 misafir isteği (birikmez)", "Aynı anda 1 açık istek", "Kural motoru ve güven skoru — tam erişim"]'::jsonb,
       perks_en = '["1 guest request every month (does not roll over)", "1 open request at a time", "Rule engine and trust score — full access"]'::jsonb
 where plan = 'yolcu';

-- ── §1c · Kayıt hediyesi 3 ─────────────────────────────────────────────────
update beta_settings set value = jsonb_set(value, '{amount}', '3'::jsonb) where key = 'signup_credits';

-- ── §1b · Ücretsiz planın aylık payı birikmez ──────────────────────────────
create or replace function public.plan_kredisi_yerlestir(p_user uuid default null::uuid)
returns jsonb
language plpgsql security definer set search_path to 'public' as $pk334$
declare
  v_uid uuid := public.kimlik(p_user);
  v_ay text; v_n int; v_reason text; v_bal int; v_plan plan_type; v_ucretsiz boolean;
  v_onceki int := 0;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'neden', 'oturum_yok'); end if;

  v_plan := public.etkin_plan(v_uid);
  v_ay := to_char(timezone('Europe/Istanbul', now()), 'YYYY-MM');
  v_reason := 'plan_monthly:' || v_ay || ':' || v_plan::text;

  if exists (select 1 from credit_ledger where user_id = v_uid and reason = v_reason) then
    return jsonb_build_object('ok', true, 'durum', 'zaten_verildi', 'ay', v_ay, 'plan', v_plan);
  end if;

  select coalesce(p.monthly_credits, 0), coalesce(p.price_try, 0) = 0
    into v_n, v_ucretsiz
    from plan_catalog p where p.plan = v_plan and p.aktif;
  v_n := coalesce(v_n, 0);
  if v_n <= 0 then
    return jsonb_build_object('ok', true, 'durum', 'plan_kredisi_yok', 'ay', v_ay);
  end if;

  -- Ay içinde plan yükseldiyse yalnız FARK verilir (232/236 davranışı).
  select coalesce(max(delta), 0) into v_onceki from credit_ledger
   where user_id = v_uid and reason like 'plan_monthly:' || v_ay || '%';
  if v_onceki >= v_n then
    return jsonb_build_object('ok', true, 'durum', 'zaten_yeterli', 'ay', v_ay);
  end if;
  v_n := v_n - v_onceki;

  select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = v_uid;

  -- 334 §1b — ücretsiz planın payı BİRİKMEZ: bakiye paya tamamlanır.
  if v_ucretsiz then
    v_n := least(v_n, greatest(0, v_n - v_bal));
  end if;

  -- 0 da olsa ayın kaydı düşülür: aynı ay ikinci kez denenmez.
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (v_uid, v_n, v_reason, v_bal + v_n);

  if v_n <= 0 then
    return jsonb_build_object('ok', true, 'durum', 'birikmez', 'ay', v_ay, 'plan', v_plan);
  end if;

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_uid, 'credits', 'Aylık kredin yüklendi ✓',
          v_n || ' kredi hesabına eklendi. Planın her ay bu krediyi veriyor.',
          'credits');

  return jsonb_build_object('ok', true, 'durum', 'verildi', 'adet', v_n, 'ay', v_ay, 'plan', v_plan);
exception when others then
  return jsonb_build_object('ok', false, 'neden', sqlerrm);
end $pk334$;

-- ── §2 · Uygunsuz içerik süzgeci ───────────────────────────────────────────
create or replace function public.uygunsuz_maskele(p text)
returns text
language plpgsql immutable set search_path = public as $um334$
declare
  r record; v_out text := ''; v_norm text; v_bas text;
  -- Normalize sözcükle TAM eşleşir (önek kökler `.*` ile). Liste bilerek dar.
  v_desen constant text :=
    '^(siktir.*|sikeyim|sikerim|sikiyim|sikik.*|sikiş.*|sikis.*|yarrak.*|yarak|amk|amq|amına.*|amina.*|amını|amini|'
    'amcık.*|amcik.*|orospu.*|oç|piç|piçler|göt|götveren|gotveren|ibne.*|pezevenk.*|kahpe.*|şerefsiz.*|serefsiz.*|'
    'gavat.*|yavşak.*|yavsak.*|puşt.*|pust|kaltak.*|sürtük.*|surtuk.*|ananı|anani|'
    'fuck.*|motherfuck.*|shit|shitty|bitch.*|cunt.*|nigg.*|faggot.*|asshole.*|whore.*|slut.*|dick|pussy)$';
begin
  if p is null or p = '' then return p; end if;
  v_bas := substring(p from '^\s*');
  v_out := coalesce(v_bas, '');
  for r in select m[1] as tok, m[2] as sp from regexp_matches(p, '(\S+)(\s*)', 'g') as m loop
    v_norm := lower(translate(r.tok, 'ÇĞİIÖŞÜÂÎÛ', 'çğiıöşüâîû'));
    v_norm := regexp_replace(v_norm, '[^a-zçğıöşüâîû0-9]', '', 'g');
    if v_norm <> '' and v_norm ~ v_desen then
      v_out := v_out || '•••' || r.sp;
    else
      v_out := v_out || r.tok || r.sp;
    end if;
  end loop;
  return v_out;
end $um334$;
grant execute on function public.uygunsuz_maskele(text) to authenticated, service_role;

-- Sohbet: mevcut süzgece (255) uygunsuz sözcük maskesi + işaret eklenir.
create or replace function public.trg_sohbet_suzgeci() returns trigger
language plpgsql security definer set search_path = public as $tss334$
declare v jsonb; v_temiz text;
begin
  v := public.sohbet_temizle(new.body);
  new.body := v ->> 'body';
  v_temiz := public.uygunsuz_maskele(new.body);
  if v_temiz is distinct from new.body then
    new.body := v_temiz;
    v := jsonb_set(v, '{sebep}', coalesce(v -> 'sebep', '[]'::jsonb) || '"uygunsuz"'::jsonb);
  end if;
  if jsonb_array_length(coalesce(v -> 'sebep', '[]'::jsonb)) > 0 then
    new.flagged := true;
    new.flag_reason := array_to_string(array(select jsonb_array_elements_text(v -> 'sebep')), ',');
  end if;
  return new;
exception when others then
  return new;
end $tss334$;

-- Diğer görünür metinler: tetikleyiciye kolon adları argüman olarak verilir.
create or replace function public.trg_uygunsuz_suz() returns trigger
language plpgsql security definer set search_path = public as $tus334$
declare c text; v text; m text; j jsonb := to_jsonb(new); degisti boolean := false;
begin
  foreach c in array tg_argv loop
    v := j ->> c;
    if v is not null then
      m := public.uygunsuz_maskele(v);
      if m is distinct from v then
        j := jsonb_set(j, array[c], to_jsonb(m));
        degisti := true;
      end if;
    end if;
  end loop;
  if degisti then new := jsonb_populate_record(new, j); end if;
  return new;
exception when others then
  return new;
end $tus334$;

drop trigger if exists trg_uygunsuz_profil on profiles;
create trigger trg_uygunsuz_profil before insert or update of name, bio, profession on profiles
  for each row execute function public.trg_uygunsuz_suz('name', 'bio', 'profession');
drop trigger if exists trg_uygunsuz_baglanti on connection_requests;
create trigger trg_uygunsuz_baglanti before insert or update of intro, cevap, cevap_notu on connection_requests
  for each row execute function public.trg_uygunsuz_suz('intro', 'cevap', 'cevap_notu');
drop trigger if exists trg_uygunsuz_soru on kural_sorulari;
create trigger trg_uygunsuz_soru before insert or update of soru, cevap, cevap_notu on kural_sorulari
  for each row execute function public.trg_uygunsuz_suz('soru', 'cevap', 'cevap_notu');
drop trigger if exists trg_uygunsuz_puan on ratings;
create trigger trg_uygunsuz_puan before insert or update of comment on ratings
  for each row execute function public.trg_uygunsuz_suz('comment');
drop trigger if exists trg_uygunsuz_istek on requests;
create trigger trg_uygunsuz_istek before insert or update of intro_message, decision_note on requests
  for each row execute function public.trg_uygunsuz_suz('intro_message', 'decision_note');
drop trigger if exists trg_uygunsuz_davet on invites;
create trigger trg_uygunsuz_davet before insert or update of note on invites
  for each row execute function public.trg_uygunsuz_suz('note');
drop trigger if exists trg_uygunsuz_ilan on availabilities;
create trigger trg_uygunsuz_ilan before insert or update of rule_note on availabilities
  for each row execute function public.trg_uygunsuz_suz('rule_note');

-- ── DOĞRULAMA ──────────────────────────────────────────────────────────────
select 'kahya kredi basi en ucuz' as kontrol,
       (select price_try::numeric / monthly_credits from plan_catalog where plan = 'kahya')
     < (select price_try::numeric / monthly_credits from plan_catalog where plan = 'sik_ucan') as tamam
union all
select 'kayit hediyesi 3', (select (value ->> 'amount')::int from beta_settings where key = 'signup_credits') = 3
union all
select 'suzgec maskeler, masumu birakir',
       public.uygunsuz_maskele('Selam orospu çocuğu, Sık Uçan planı güzel') = 'Selam ••• çocuğu, Sık Uçan planı güzel'
   and public.uygunsuz_maskele('I got the pic, sik ucan') = 'I got the pic, sik ucan';
-- Beklenen: üç satır tamam = true.
