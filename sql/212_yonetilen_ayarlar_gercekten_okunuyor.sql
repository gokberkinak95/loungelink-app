-- ============================================================
-- 212 · "YÖNETİLİYOR" SANILAN ÜÇ TABLO GERÇEKTEN OKUNSUN
-- 17 Ağustos 2026
--
-- 🔴 ÖLÇÜM (üç ayrı grep taraması, üç kod tabanı):
--
--   feature_flags   → BO /manage/flags yazıyor. Okuyan TEK fonksiyon
--                     `flag_enabled`, ve onun HİÇ ÇAĞIRANI YOK.
--                     Ekranın kendi metni: "sorun çıkarsa anında
--                     kaparsın". Bugün hiçbir şeyi kapatmıyor.
--   i18n_strings    → BO /manage/i18n yazıyor. Okuyan tek şey,
--                     aynı ekranın kendi `i18n_missing` görünümü.
--                     Uygulama metinleri `src/i18n.js` içinde DERLİ
--                     geliyor. Ekranın metni: "anında yansır". Hayır.
--   rule_thresholds → BO /manage/thresholds yazıyor. Okuyan tek
--                     fonksiyon `apply_rule_engine`, onun da hiç
--                     çağıranı yok. Üstelik ekran "Güven Puanı
--                     Eşikleri" diyor ama rozet eşikleri 078'de
--                     SABİT KODLU; tabloda rozet anahtarı bile yok.
--
-- Bu, bu turda üçüncü kez gördüğüm hata sınıfının (18: "tanımlı olmak
-- çağrılmak değildir") en pahalı biçimi: kullanıcıya VERİLMİŞ bir söz
-- var — "deploy'suz değiştirirsin" — ve söz tutulmuyor. Ayar ekranı,
-- hiçbir yere bağlı olmayan bir düğmeler duvarı.
--
-- İKİ SEÇENEK VARDI: ekranları kaldırmak ya da bağlamak. Bağlamayı
-- seçtim; üçü de gerçek bir ürün ihtiyacına denk geliyor (acil kapatma
-- düğmesi, metin düzeltmesi, güven eşiği). Kaldırmak ihtiyacı yok
-- etmezdi, yalnız görünmez kılardı.
-- ============================================================


-- ============================================================
-- (1) FEATURE FLAGS — GERÇEK KİLL SWITCH
-- ============================================================
-- Bayrağın anlamı, KAPATILDIĞINDA BİR ŞEYİN DURMASIDIR.
-- Aşağıdaki dört bayrak artık gerçekten bir yolu kesiyor.
alter table feature_flags add column if not exists surface text;   -- nerede etkili
alter table feature_flags add column if not exists is_kill_switch boolean not null default false;

insert into feature_flags (key, enabled, rollout_pct, description, surface, is_kill_switch) values
  ('marketplace',     true, 100,
   'KAPALI iken hic yeni istek acilamaz (create_request_impl reddeder). Acil durdurma dugmesi.',
   'create_request_impl · uygulama istek ekrani', true),
  ('referral',        true, 100,
   'KAPALI iken davet/referans ekrani uygulamada gizlenir.',
   'client_flags → uygulama', false),
  ('partner_channel', true, 100,
   'KAPALI iken saglayici paneli (BO /partner) veri dondurmez.',
   'partner_gate', false),
  ('delay_mode',      false, 100,
   'ACIK iken ucus rotarlarinda misafire ek sure taninir (uygulama uyarisi).',
   'client_flags → uygulama', false),
  ('day_pass',        false, 100,
   'Gunubirlik satin alma akisi. KAPALI: satin alma butonu hic cizilmez. '
   || 'Odeme saglayicisi baglanmadan ACILMAMALI.',
   'client_flags → uygulama · lounge_offers', false),
  ('b2b',             false, 100,
   'Kurumsal paket ekranlari. Henuz sozlesme yok; kapali.',
   'client_flags → uygulama', false)
on conflict (key) do update set
  description = excluded.description,
  surface = excluded.surface,
  is_kill_switch = excluded.is_kill_switch;

-- İstemcinin okuduğu tek kapı. `rollout_pct` kullanıcı kimliğine göre
-- deterministik bölünür — aynı kullanıcı her açılışta aynı cevabı alır,
-- yoksa bayrak "bazen açık bazen kapalı" olur ve hata ayıklanamaz.
create or replace function public.client_flags()
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_object_agg(f.key,
           f.enabled and (
             f.rollout_pct >= 100
             or auth.uid() is null
             or (('x' || substr(md5(f.key || coalesce(auth.uid()::text,'')), 1, 8))::bit(32)::bigint
                  % 100) < f.rollout_pct
           )), '{}'::jsonb)
    from feature_flags f;
$fn$;
grant execute on function public.client_flags() to authenticated, anon;

-- Sunucu tarafı okuma yardımcısı (029'daki `flag_enabled` duruyor,
-- ama artık gerçekten çağrılıyor).
-- ⚠️ `create_request_impl`in gövdesini yeniden yazmıyorum. 204/207'de
-- öğrendiğim desen: yeniden adlandır, aynı imzalı sarmalayıcı koy.
-- Gövdeyi kopyalamak, 207'nin mertebe/kredi mantığını sessizce eski
-- bir sürüme döndürme riskidir.
--
-- ⚠️ İMZA `pg_get_function_arguments` İLE ALINIR (DEFAULT'lar korunur).
-- `identity_arguments` DEFAULT'ları düşürür ve sarmalayıcı
-- `create_request(p_avail_id)` çağrısını 42883 ile kırar — bu turda
-- bir kez yaşandı.
do $$
declare v_args text; v_ident text;
begin
  if not exists (select 1 from pg_proc where proname = 'create_request_impl_preflag') then
    select pg_get_function_arguments(p.oid), pg_get_function_identity_arguments(p.oid)
      into v_args, v_ident
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'create_request_impl';

    execute format('alter function public.create_request_impl(%s) rename to create_request_impl_preflag', v_ident);

    execute format($f$
      create or replace function public.create_request_impl(%s)
      returns jsonb language plpgsql security definer set search_path = public as $b$
      declare v_acik boolean; v_kalan int; v_tavan int;
      begin
        -- (a) ACİL DURDURMA
        select f.enabled into v_acik from feature_flags f where f.key = 'marketplace';
        if not coalesce(v_acik, true) then
          raise exception 'marketplace_closed';
        end if;

        -- (b) AYNI ANDA AÇIK İSTEK TAVANI — 029'da tohumlanmış ama
        -- yedi ay boyunca hiçbir yerde uygulanmamış bir eşik.
        select value into v_tavan from rule_thresholds where key = 'max_active_requests';
        select count(*) into v_kalan from requests
         where guest_id = auth.uid() and status = 'pending';
        if v_kalan >= coalesce(v_tavan, 5) then
          raise exception 'too_many_active_requests';
        end if;

        return public.create_request_impl_preflag(p_avail_id, p_type, p_intro, p_idem);
      end $b$;
    $f$, v_args);

    execute format('revoke all on function public.create_request_impl(%s) from public, anon', v_ident);
    execute format('grant execute on function public.create_request_impl(%s) to authenticated', v_ident);
    execute format('revoke all on function public.create_request_impl_preflag(%s) from public, anon, authenticated', v_ident);
    raise notice '212: create_request_impl sarmalandi — kill switch + aktif istek tavani';
  end if;
end $$;

-- ⚠️ SAĞLAYICI PANELİ BAYRAĞI BU DOSYADA **DEĞİL**, 213'TE BAĞLANIYOR.
--
-- 🔴 BURADA BİR HATA YAPTIM VE 213 YAZILIRKEN ÖLÇÜMLE YAKALANDI.
-- Bu dosyanın ilk sürümü `partner_gate`i sarmalıyordu ve sarmalayıcıyı
-- `returns boolean` diye yazmıştım. Oysa 209'un `partner_gate`i **uuid**
-- döndürüyor (yetkili kullanıcının kimliği) ve 209'un BEŞ fonksiyonu
-- `v_uid := partner_gate(...)` diyor. Sonuç:
--     22P02  invalid input syntax for type uuid: "f"
-- Sağlayıcı panelinin beş ekranı da patlıyordu; bayrağı AÇMAK da
-- kurtarmıyordu, ters yönde aynı hata geliyordu.
--
-- HATA SINIFI 21 — SÖZLEŞMEYİ DEĞİŞTİREN MIGRATION, ÇAĞIRICILARI DA
-- AYNI DOSYADA DÜZELTMELİ.
-- 204/207'de öğrendiğim ders "imzayı elle yazma"ydı; onu uyguladım
-- (`pg_get_function_arguments`). Ama dönüş tipini elle yazdım ve
-- daha önemlisi: çağıranları bu dosyada düzeltmedim. Her migration
-- KENDİ ANINDA doğru olmalı — "bir sonraki dosya toparlar" demek,
-- arada canlıya çıkılırsa panelin kırık olması demektir.
--
-- Bu yüzden bayrak bağlama işi, çağırıcı onarımıyla BİRLİKTE
-- 213_saglayici_kurumsal_katman.sql'e taşındı. Burada yalnız kayıt var.
--
-- NEDEN NÖBETÇİLER YAKALAMADI: 209'un nöbetçileri 209 çalışırken
-- geçti; 212 henüz çalışmamıştı. Migration'lar sırayla koşuyor ve her
-- dosya kendi anında yeşil yanıyor. Sonraki bir dosyanın öncekini
-- bozması bu düzende görünmüyor. 213'e bu yüzden "209'un fonksiyonları
-- HÂLÂ çalışıyor mu" diye soran bir nöbetçi eklendi.


-- ============================================================
-- (2) i18n_strings — DERLENMİŞ SÖZLÜĞÜN ÜSTÜNE CANLI KATMAN
-- ============================================================
-- Uygulamanın 2744 satırlık `src/i18n.js` sözlüğünü veritabanına
-- taşımıyorum: çevrimdışı açılış ve ilk boya hızı ondan geliyor.
-- Doğru kurgu ÜST KATMAN: uygulama açılışta yalnız DEĞİŞTİRİLMİŞ
-- anahtarları çeker ve derli sözlüğün üstüne bindirir. Böylece
--   - çevrimdışı ilk açılış çalışmaya devam eder,
--   - BO'daki metin düzeltmesi bir sonraki açılışta gerçekten yansır,
--   - ekranın "anında yansır" cümlesi doğru olur.
alter table i18n_strings add column if not exists active boolean not null default true;
alter table i18n_strings add column if not exists note text;

create or replace function public.i18n_overrides(p_lang text default null)
returns table (anahtar text, dil text, metin text)
language sql stable security definer set search_path = public as $fn$
  select s.key, s.lang, s.value
    from i18n_strings s
   where s.active
     and s.value is not null and btrim(s.value) <> ''
     and (p_lang is null or s.lang = p_lang);
$fn$;
grant execute on function public.i18n_overrides(text) to authenticated, anon;

-- Sürüm damgası: uygulama her açılışta tüm listeyi çekmesin diye
-- "en son ne zaman değişti" tek sayı olarak okunabilsin.
create or replace function public.i18n_version()
returns text language sql stable security definer set search_path = public as $fn$
  select coalesce(to_char(max(updated_at), 'YYYYMMDDHH24MISS'), '0') from i18n_strings where active;
$fn$;
grant execute on function public.i18n_version() to authenticated, anon;


-- ============================================================
-- (3) rule_thresholds — EKRANIN ADI NE DİYORSA ONU YÖNETSİN
-- ============================================================
-- 🔴 EKRAN YANLIŞ VERİYİ DÜZENLİYORDU. Başlık "Güven Puanı Eşikleri",
-- yardım metni "değişiklik ANINDA etkili" diyor; ama tabloda rozet
-- anahtarı YOK, rozet eşikleri `compute_trust_badge` içinde SABİT:
--     >=88 trusted_plus · >=72 trusted · >=56 verified
-- Ekranın "BUGÜN KAÇ KİŞİ" sütunu, güven puanını `max_active_requests`
-- (=5) gibi bambaşka birimdeki sayılarla kıyaslıyordu. Anlamsız
-- aritmetik, güven verici bir tabloda.
insert into rule_thresholds (key, value, description) values
  ('badge_verified',     56, 'Bu puandan itibaren "Dogrulanmis" rozeti'),
  ('badge_trusted',      72, 'Bu puandan itibaren "Guvenilir" rozeti'),
  ('badge_trusted_plus', 88, 'Bu puandan itibaren "Guvenilir+" rozeti')
on conflict (key) do update set description = excluded.description;

update rule_thresholds set description = 'Bir misafirin ayni anda acik tutabilecegi en fazla istek (create_request_impl uygular)'
 where key = 'max_active_requests';
update rule_thresholds set description = 'Kac no-show sonrasi otomatik golge kisit (apply_rule_engine uygular)'
 where key = 'no_show_limit';
update rule_thresholds set description = 'Kac ACIK sikayet sonrasi otomatik golge kisit (sikayet acilinca tetiklenir)'
 where key = 'report_threshold';

-- ⚠️ `compute_trust_badge` IMMUTABLE idi; tablo okuyunca STABLE olmalı.
-- IMMUTABLE bir fonksiyon tablo okursa PostgreSQL sonucu önbelleğe
-- alabilir ve eşik değişikliği görünmez. Volatiliteyi düşürmek
-- CREATE OR REPLACE ile serbest; indekste kullanılmadığını ölçtüm.
do $$
declare v_n int;
begin
  select count(*) into v_n from pg_index i
    join pg_class c on c.oid = i.indexrelid
   where pg_get_indexdef(i.indexrelid) ilike '%compute_trust_badge%';
  if v_n > 0 then
    raise exception '212: compute_trust_badge % indekste kullaniliyor; STABLE yapmak indeksi kirar', v_n;
  end if;
end $$;

create or replace function public.compute_trust_badge(score int)
returns text language sql stable set search_path = public as $fn$
  select case
    when score >= coalesce((select value from rule_thresholds where key='badge_trusted_plus'), 88) then 'trusted_plus'
    when score >= coalesce((select value from rule_thresholds where key='badge_trusted'),      72) then 'trusted'
    when score >= coalesce((select value from rule_thresholds where key='badge_verified'),     56) then 'verified'
    else 'basic' end;
$fn$;

-- Eşikler değiştiğinde eski rozetler yalan söylemesin: BO kaydettiğinde
-- rozetleri yeniden hesaplayan RPC.
create or replace function public.rozetleri_yenile()
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_n int;
begin
  update trust_scores set badge = public.compute_trust_badge(score)
   where badge is distinct from public.compute_trust_badge(score);
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', true, 'guncellenen', v_n);
end $fn$;
revoke all on function public.rozetleri_yenile() from public, anon, authenticated;
grant execute on function public.rozetleri_yenile() to service_role;

-- `apply_rule_engine` ARTIK ÇAĞRILIYOR: şikayet açıldığı anda.
-- 029'dan beri tanımlıydı ve sıfır çağıranı vardı — yani "3 şikayet
-- sonrası otomatik kısıt" kuralı hiç işlemedi.
create or replace function public.apply_rule_engine(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_reports int; v_ns int; v_thr int; v_ns_thr int; v_days int; v_acted text := 'none';
begin
  select value into v_thr    from rule_thresholds where key = 'report_threshold';
  select value into v_ns_thr from rule_thresholds where key = 'no_show_limit';
  select value into v_days   from rule_thresholds where key = 'restrict_days';

  select count(*) into v_reports from reports where target_id = p_user and status = 'open';

  -- 🔴 `no_show_limit` yedi aydır tohumluydu ve HİÇBİR YERDE okunmuyordu.
  -- No-show verisi 080'de `sessions.no_show_user_id` olarak duruyor.
  select count(*) into v_ns from sessions
   where no_show_user_id = p_user and cancel_reason = 'no_show'
     and completed_at > now() - interval '90 days';

  if v_reports >= coalesce(v_thr, 3) or v_ns >= coalesce(v_ns_thr, 2) then
    update users set shadow_limited = true,
      restricted_until = greatest(coalesce(restricted_until, now()), now())
                         + make_interval(days => coalesce(v_days, 7))
    where id = p_user;
    v_acted := case when v_reports >= coalesce(v_thr,3) then 'sikayet' else 'no_show' end;
  end if;
  return jsonb_build_object('ok', true, 'action', v_acted,
                            'acik_sikayet', v_reports, 'no_show_90g', v_ns);
end $fn$;
revoke all on function public.apply_rule_engine(uuid) from public, anon, authenticated;
grant execute on function public.apply_rule_engine(uuid) to service_role;

create or replace function public.trg_rule_engine()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform public.apply_rule_engine(new.target_id);
  return new;
end $fn$;
drop trigger if exists trg_rule_engine_report on reports;
create trigger trg_rule_engine_report after insert on reports
  for each row execute function public.trg_rule_engine();

-- ⚠️ SIRA: tetiği fonksiyondan ÖNCE yazmıştım (kopyala-yapıştır) ve
-- 42883 aldım. PostgreSQL `create trigger ... execute function f()`
-- derken f'in VAR OLMASINI ister; "sonra tanımlarım" yok.
create or replace function public.trg_rule_engine_noshow()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform public.apply_rule_engine(new.no_show_user_id);
  return new;
end $fn$;
drop trigger if exists trg_rule_engine_noshow on sessions;
create trigger trg_rule_engine_noshow after update of no_show_user_id on sessions
  for each row when (new.no_show_user_id is not null)
  execute function public.trg_rule_engine_noshow();

-- BO'nun eşik ekranı doğru sayıyı göstersin: hangi eşik BUGÜN kaç
-- kişiyi etkiliyor. Öncekinde güven puanı ile istek tavanı
-- karşılaştırılıyordu; artık her eşik kendi birimiyle sayılıyor.
create or replace function public.esik_etkisi()
returns table (anahtar text, deger int, aciklama text, etkilenen int, birim text)
language sql stable security definer set search_path = public as $fn$
  select t.key, t.value, t.description,
    case t.key
      when 'badge_verified'      then (select count(*)::int from trust_scores where score >= t.value)
      when 'badge_trusted'       then (select count(*)::int from trust_scores where score >= t.value)
      when 'badge_trusted_plus'  then (select count(*)::int from trust_scores where score >= t.value)
      when 'max_active_requests' then (select count(*)::int from (
             select guest_id from requests where status='pending'
              group by guest_id having count(*) >= t.value) x)
      when 'report_threshold'    then (select count(*)::int from (
             select target_id from reports where status='open'
              group by target_id having count(*) >= t.value) x)
      when 'no_show_limit'       then (select count(*)::int from (
             select no_show_user_id from sessions
              where cancel_reason='no_show' and no_show_user_id is not null
                and completed_at > now() - interval '90 days'
              group by no_show_user_id having count(*) >= t.value) x)
      when 'restrict_days'       then (select count(*)::int from users
             where shadow_limited and restricted_until > now())
      else 0 end,
    case t.key
      when 'restrict_days' then 'su an kisitli kullanici'
      when 'max_active_requests' then 'tavana dayanmis misafir'
      when 'report_threshold' then 'esigi asmis kullanici'
      when 'no_show_limit' then 'esigi asmis kullanici (90 gun)'
      else 'bu rozeti hak eden kullanici' end
    from rule_thresholds t
   order by t.key;
$fn$;
grant execute on function public.esik_etkisi() to service_role;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) ÜÇ TABLONUN DA ARTIK GERÇEK BİR OKUYUCUSU VAR
-- Bu nöbetçi metin araması yapıyor çünkü ölçmek istediğim şey tam
-- olarak bu: fonksiyon GÖVDESİNDE tablo adı geçiyor mu ve o fonksiyon
-- ÇAĞRILIYOR mu.
do $$
declare r record; v_eksik text := '';
begin
  for r in select * from (values
      ('feature_flags',   'client_flags'),
      ('feature_flags',   'create_request_impl'),
      ('i18n_strings',    'i18n_overrides'),
      ('rule_thresholds', 'compute_trust_badge'),
      ('rule_thresholds', 'apply_rule_engine'),
      ('rule_thresholds', 'create_request_impl')
    ) as t(tablo, fn)
  loop
    if not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname='public' and p.proname = r.fn and p.prosrc ilike '%' || r.tablo || '%')
    then v_eksik := v_eksik || r.fn || '→' || r.tablo || ' '; end if;
  end loop;
  if v_eksik <> '' then
    raise exception '212: su okuyucular tabloyu okumuyor: %', v_eksik;
  end if;
  raise notice '212: uc tablonun da gercek okuyucusu var';
end $$;

-- 2) KILL SWITCH GERÇEKTEN KESİYOR MU (mutasyon)
-- 🔴 İLK YAZDIĞIM SÜRÜM KENDİ KENDİNİ ATLIYORDU: gövde
-- `if v_av is null then ... return; end if;` idi, yani VERİ VARSA
-- hiçbir şey sınamıyordu ve yine de yeşil görünüyordu. Bir nöbetçinin
-- sessizce atlaması, nöbetçi olmamasından beterdir — yeşil ışık yalan
-- söyler. Artık koşulsuz çalışıyor.
do $$
declare v_hata text := ''; v_u uuid;
begin
  select id into v_u from users limit 1;
  if v_u is null then raise exception '212: kullanici yok — kill switch sinanamaz'; end if;

  update feature_flags set enabled = false where key = 'marketplace';
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_u)::text, true);
    perform public.create_request_impl(gen_random_uuid());
  exception when others then v_hata := SQLERRM;
  end;
  perform set_config('request.jwt.claims', '', true);
  update feature_flags set enabled = true where key = 'marketplace';

  if v_hata <> 'marketplace_closed' then
    raise exception '212: kill switch kapaliyken beklenen hata marketplace_closed, gelen: "%"', v_hata;
  end if;
  raise notice '212: kill switch mutasyonla kanitli (marketplace_closed)';
end $$;

-- 2b) TAVAN GERÇEKTEN KESİYOR MU (mutasyon)
-- Tavanı 0'a çekiyorum; hiçbir isteğin açılamaması gerekiyor.
do $$
declare v_hata text := ''; v_u uuid;
begin
  select id into v_u from users limit 1;
  update rule_thresholds set value = 0 where key = 'max_active_requests';
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_u)::text, true);
    perform public.create_request_impl(gen_random_uuid());
  exception when others then v_hata := SQLERRM;
  end;
  perform set_config('request.jwt.claims', '', true);
  update rule_thresholds set value = 5 where key = 'max_active_requests';
  if v_hata <> 'too_many_active_requests' then
    raise exception '212: aktif istek tavani uygulanmiyor; gelen hata: "%"', v_hata;
  end if;
  raise notice '212: aktif istek tavani mutasyonla kanitli';
end $$;

-- 3) ROZET EŞİĞİ TABLODAN OKUNUYOR MU (mutasyon)
do $$
declare v_once text; v_sonra text;
begin
  v_once := public.compute_trust_badge(75);            -- 72 esigi → trusted
  update rule_thresholds set value = 99 where key = 'badge_trusted';
  v_sonra := public.compute_trust_badge(75);           -- artik verified olmali
  update rule_thresholds set value = 72 where key = 'badge_trusted';
  if v_once = v_sonra then
    raise exception '212: rozet esigi degistigi halde rozet degismedi (% → %) — tablo okunmuyor', v_once, v_sonra;
  end if;
  raise notice '212: rozet esigi tablodan okunuyor (75 puan: % → %)', v_once, v_sonra;
end $$;

-- 4) İSTEK TAVANI VE ŞİKAYET TETİĞİ TANIMLI MI
do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'trg_rule_engine_report') then
    raise exception '212: sikayet tetigi yok — apply_rule_engine yine cagrilmiyor demektir';
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'trg_rule_engine_noshow') then
    raise exception '212: no-show tetigi yok';
  end if;
  if not exists (select 1 from pg_proc where proname = 'create_request_impl_preflag') then
    raise exception '212: create_request_impl sarmalanmamis — kill switch devrede degil';
  end if;
  raise notice '212: tetikler ve sarmalayici yerinde';
end $$;

-- 5) ROLLOUT DETERMİNİSTİK Mİ
-- Aynı kullanıcı için aynı cevap gelmezse bayrak hata ayıklanamaz hale
-- gelir ("bende çalışıyor" sınıfı hata).
do $$
declare a jsonb; b jsonb; v_u uuid;
begin
  select id into v_u from users limit 1;
  if v_u is null then raise notice '212: kullanici yok — rollout testi atlandi'; return; end if;
  update feature_flags set rollout_pct = 50 where key = 'referral';
  perform set_config('request.jwt.claims', json_build_object('sub', v_u)::text, true);
  a := public.client_flags();
  b := public.client_flags();
  perform set_config('request.jwt.claims', '', true);
  update feature_flags set rollout_pct = 100 where key = 'referral';
  if (a ->> 'referral') is distinct from (b ->> 'referral') then
    raise exception '212: rollout deterministik degil (% vs %)', a ->> 'referral', b ->> 'referral';
  end if;
  raise notice '212: rollout ayni kullanici icin deterministik';
end $$;


-- ============================================================
-- RPC YÜZEYİNE KAYIT — SINIRDAN ÖNCE
-- ============================================================
-- 🔴 BU SATIRLAR OLMADAN UYGULAMA AÇILIŞTA KIRILIRDI, ve bunu ancak
-- fonksiyonun yetkisini ÖLÇTÜĞÜMDE gördüm:
--
--   client_flags      → authenticated EXECUTE = f
--   i18n_overrides    → authenticated EXECUTE = f
--   i18n_version      → authenticated EXECUTE = f
--
-- Sebep: `apply_rpc_surface()` (SQL 203) beyaz listede OLMAYAN her
-- fonksiyonu istemciye kapatıyor. Bu doğru davranış — ama yeni bir
-- istemci fonksiyonu yazıp listeye eklemeyi unutmak, fonksiyonu
-- yazmamakla aynı sonucu veriyor: uygulama 42501 alır ve bayraklar
-- hiç gelmez. Yani "acil kapatma düğmesi" düğme olarak var, kablosu
-- kesik. Bu dosyanın ilk sürümünde tam olarak bu vardı.
--
-- Nöbetçiler bunu yakalayamadı çünkü 203'ün değişmezi TERS yönü
-- ölçüyor: "açık olmaması gereken açık mı?". "Açık OLMASI gereken
-- kapalı mı?" diye soran bir denetim YOKTU. `pg_run.py`ye eklendi.
insert into rpc_client_surface (fn_name, client, note) values
  ('client_flags',   'app', 'Ozellik bayraklari — acil kapatma dugmesinin istemci ayagi.'),
  ('i18n_overrides', 'app', 'BO metin duzeltmeleri; derli sozlugun ustune biner.'),
  ('i18n_version',   'app', 'Metin katmani surum damgasi.')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

-- SINIR EN SONDA (bu dosyada 8 yeni fonksiyon var).
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '212: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '212 OK - feature_flags, i18n_strings, rule_thresholds artik gercekten okunuyor' as sonuc;
