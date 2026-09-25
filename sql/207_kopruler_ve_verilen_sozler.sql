-- ============================================================
-- 207 · KÖPRÜLER VE VERİLEN SÖZLER
-- 17 Ağustos 2026
--
-- Bu dosya iki tür hatayı kapatıyor ve ikisi de utanç verici türden:
--   (A) YILLARDIR ORADA OLAN sessiz kopukluklar — RLS politikası VAR
--       ama GRANT yok. Politika yazıp grant unutmak, kapıyı kilitleyip
--       anahtarı kimseye vermemek demek. Hata da vermiyor: PostgREST
--       42501 dönüyor, uygulama okumuyor, kullanıcı hiçbir şey görmüyor.
--   (B) BENİM 203'TE ve 206'DA AÇTIĞIM yaralar. İkisini de burada
--       açıkça yazıyorum, çünkü bir sonraki tur bunları "hep böyleydi"
--       sanmasın.
-- ============================================================


-- ============================================================
-- A1) users — POLİTİKA VAR, GRANT YOK
-- ============================================================
-- 🔴 ÖLÇÜM:
--   has_table_privilege('authenticated','users','UPDATE') → f
--   pg_policies: users_own | ALL | (auth.uid() = id)      → VAR
--
-- Yani kural doğru yazılmış, kapı hiç açılmamış. Uygulamanın ÜÇ
-- yazması etkileniyor ve üçü de sessiz:
--   App.js:402        must_change_password = false
--   screens.js:616    role = 'host'          (ilan açınca)
--   screens.js:7266   gender = ...           (profil)
--
-- ⚠️ KOLON DÜZEYİNDE VERİYORUM, tabloya toptan DEĞİL. `users` tablosu
-- `is_staff`, `shadow_limited`, `restricted_until`, `banned_until`,
-- `deleted_at`, `anonymized_at` gibi MODERASYON kolonları taşıyor.
-- Toptan UPDATE vermek, kullanıcının kendi cezasını kaldırabilmesi
-- demekti. RLS satırı sınırlar, kolonu sınırlamaz — ikisi ayrı katman.
-- ⚠️ `must_change_password` BU TABLODA YOK. İlk yazımda grant'a
-- eklemiştim ve harness 42703 verdi. Sebebini arayınca daha büyük bir
-- kusur çıktı: `App.js:402` yıllardır
--     supabase.from("users").update({ must_change_password: false })
-- yazıyor — OLMAYAN bir kolona. Çağrı try/catch içinde, hata yutuluyor.
-- Yani geçici şifresini değiştiren admin/partner'ın bayrağı HİÇ
-- temizlenmiyordu; doğru yol zaten var: `mark_password_changed()`
-- (admin_roles + lounge_partners'ta bayrağı düşürüyor). Uygulama
-- v2.73'te o RPC'ye çevrildi.
-- 🔴 ÖNCE TOPTAN YETKİYİ GERİ AL — 18 Ağustos 2026, Gökberk'te:
--     ERROR: 207: MODERASYON kolonlari kullaniciya acildi:
--            is_staff restricted_until anonymized_at plan shadow_limited deleted_at
--
-- Aşağıdaki `grant update (role, gender)` kolon düzeyinde ve doğru. Ama
-- ÖNCEKİ bir turda `grant update on public.users to authenticated`
-- verilmişse, o TABLO DÜZEYİ yetki bu satırla kalkmıyor — üstüne
-- ekleniyor. Sonuç: RLS satırı sınırlıyor (`users_own`: auth.uid()=id)
-- ama kolonu sınırlamıyor ve kullanıcı KENDİ SATIRINDA
--     is_staff = true      → kendini yönetici yapar
--     restricted_until     → kendi cezasını kaldırır
--     plan                 → kendi planını yükseltir
-- yazabiliyordu. Bu bir yetki yükseltme açığıdır, kozmetik değil.
--
-- Temiz kurulumda çıkmıyor çünkü toptan grant hiç verilmiyor; bu yüzden
-- harness'ta hiç görünmedi. Harness'ta ÜRETTİM: 206'ya kadar kurup
-- `grant update on public.users to authenticated` dedim ve 207 aynı
-- mesajla, aynı altı kolonla düştü.
--
-- ÖLÇÜM (revoke'un ne yaptığı — varsaymadım, baktım):
--     once:            tablo_update=false · kolon yetkisi 0
--     toptan grant:    tablo_update=true  · kolon yetkisi 17
--     revoke sonrasi:  tablo_update=false · kolon yetkisi 0
-- Yani revoke kolon yetkilerini de siliyor; bu yüzden SIRA ÖNEMLİ,
-- grant revoke'tan SONRA gelmeli.
revoke update on public.users from authenticated;
revoke update on public.users from anon;

grant update (role, gender) on public.users to authenticated;


-- ============================================================
-- A2) availabilities — HOST KENDİ İLANINI KAPATAMIYOR
-- ============================================================
-- 🔴 ÖLÇÜM: UPDATE hakkı `f`, ama `avail_host_write | ALL | auth.uid() = host_id`
-- politikası VAR.
--
-- screens.js:742 `update({active:false})` yazıyor, hatayı OKUMUYOR ve
-- hemen `load()` çağırıyor. Sonuç: host "Kaldır"a basıyor, ilan bir an
-- kayboluyor, liste tazeleniyor ve ilan GERİ GELİYOR. Hiçbir hata yok.
-- Bu, bir kullanıcının ürüne olan güvenini tek dokunuşta bitiren
-- türden bir kusur.
grant update on public.availabilities to authenticated;


-- ============================================================
-- A3) chat_channels — INSERT HAKKI VAR, POLİTİKASI YOK
-- ============================================================
-- 🔴 ÖLÇÜM: INSERT grant `t`, ama iki politikanın İKİSİ DE `SELECT`.
-- RLS açıkken politikası olmayan komut = sessiz red.
--
-- 159 numaralı dosya grant'ı eklemiş, politikayı eklememiş — düzeltme
-- yarım kalmış. Yol arkadaşı sohbeti üç noktada hiç açılamıyor
-- (screens.js:3540, screens.js:9212, App.js:647) ve üçünde de hata
-- yutuluyor.
--
-- Politika: kanalı ancak TARAFI OLDUĞUN bir bağlantı ya da istek için
-- açabilirsin. Aksi hâlde herkes herkesle kanal açardı.
drop policy if exists chan_party_insert on public.chat_channels;
create policy chan_party_insert on public.chat_channels
  for insert to authenticated
  with check (
    (connection_id is not null and exists (
      select 1 from connection_requests cr
       where cr.id = chat_channels.connection_id
         and cr.status = 'accepted'
         and auth.uid() in (cr.from_id, cr.to_id)))
    or
    (request_id is not null and exists (
      select 1 from requests r
       where r.id = chat_channels.request_id
         and auth.uid() in (r.guest_id, r.host_id)))
  );


-- ============================================================
-- B1) 203'ÜN AÇTIĞI YARA — BO'NUN İKİ İSTEMCİSİ VAR
-- ============================================================
-- 🔴 BU BENİM HATAM VE GEREKÇESİ YANLIŞ BİR ÖLÇÜMDÜ.
--
-- 203'ün başlığına şunu yazmıştım: "BO'yu etkilemez, çünkü BO
-- `SUPABASE_SECRET_KEY` (service_role) ile bağlanıyor
-- (backoffice/lib/supabase.js:17)." O satır doğruydu ama YETERSİZDİ:
-- BO'nun İKİ istemcisi var —
--   sbAdmin()   → service_role   (lib/supabase.js:17)
--   sbSession() → ANON anahtarı  (lib/supabase.js:6)
-- ve `middleware.js:35-37` üçüncü bir yerde YİNE anon istemcisi kurup
-- `needs_password_change` çağırıyor (satır 65).
--
-- Ben yalnız birinci istemciyi görüp "BO = service_role" diye
-- genelledim. Sonuç: 203 sonrası middleware'in çağrısı 42501 dönüyor,
-- kod `error`'u okumadığı için `mustChange` hep falsy kalıyor ve
-- ZORUNLU ŞİFRE DEĞİŞTİRME KAPISI SESSİZCE AÇILIYOR. Geçici şifreyle
-- davet edilen bir admin ya da partner, şifresini hiç değiştirmeden
-- panelde kalıyor.
--
-- DERS (yeni hata sınıfı, 17.): "Bu istemci şu anahtarı kullanıyor"
-- bir DOSYADAN değil, TÜM ÇAĞRI NOKTALARINDAN okunur. Bir örnek,
-- bir kural değildir.
--
-- Yüzeye 'backoffice_session' diye AYRI bir istemci türü ekliyorum ki
-- bir dahaki sefere bu ayrım veride görünsün, kafamda kalmasın.
alter table rpc_client_surface drop constraint if exists rpc_client_surface_client_check;
alter table rpc_client_surface add constraint rpc_client_surface_client_check
  check (client in ('app','public_web','backoffice_session'));

insert into rpc_client_surface (fn_name, client, note) values
  ('needs_password_change','backoffice_session','BO middleware.js:65 ANON istemciyle cagiriyor'),
  ('mark_password_changed','backoffice_session','sifre degistirme akisinin kapanisi')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;


-- ============================================================
-- B2) PARTNER PANELİ — BU BENİM HATAM DEĞİL, AMA BOZUK
-- ============================================================
-- 🔴 Denetim "203 partner panelini bozdu" dedi. ÖLÇTÜM, ÖYLE DEĞİL:
-- `app/partner/page.jsx:8` `sb = sbAdmin()` diyor ve RPC'leri
-- service_role ile çağırıyor — service_role'un EXECUTE hakkı duruyor.
-- Yani 203 bu ekranı bozmadı.
--
-- Ekran BAŞKA bir sebeple bozuk ve bu sebep 203'ten ESKİ:
-- `partner_demand` gövdesi `auth.uid()` okuyor —
--     if not exists (... where user_id = auth.uid() ...) then
--       raise exception 'not_partner';
-- service_role ile çağrıldığında `auth.uid()` NULL'dır. Dolayısıyla
-- sayfa HER ZAMAN `not_partner` alıyor ve sağlayıcı kırmızı hata
-- görüyor. Panel hiç çalışmamış.
--
-- Düzeltme: kimin adına sorulduğunu AÇIKÇA geçir. `auth.uid()`e
-- düşmeye devam ediyor (uygulama içi çağrı için), ama sunucu tarafı
-- kullanıcıyı bildiğinde onu söyleyebiliyor.
create or replace function public.partner_demand(p_lounge_id uuid, p_user uuid default null)
returns table (bucket_date date, total_availabilities integer, total_slots integer,
               filled_slots integer, request_count integer)
language plpgsql security definer set search_path = public as $fn$
declare v_uid uuid := coalesce(p_user, auth.uid());
begin
  if v_uid is null then raise exception 'not_partner'; end if;
  if not exists (select 1 from lounge_partners where user_id = v_uid and lounge_id = p_lounge_id)
     and not exists (select 1 from admin_roles where user_id = v_uid) then
    raise exception 'not_partner';
  end if;

  return query
  with agg as (
    select a.avail_date as d,
           count(*)::int as n_av,
           coalesce(sum(a.slots),0)::int as n_slots,
           coalesce(sum(a.filled),0)::int as n_filled,
           (select count(*)::int from requests r
             where r.avail_id in (select id from availabilities x
                                   where x.lounge_id = p_lounge_id and x.avail_date = a.avail_date)) as n_req,
           count(distinct a.host_id)::int as n_hosts
      from availabilities a
     where a.lounge_id = p_lounge_id
     group by a.avail_date
  )
  select d, n_av, n_slots, n_filled, n_req
    from agg
   -- EK-2 k-anonimite: 5'ten az HOST'lu hücre gösterilmez.
   where n_hosts >= 5
   order by d desc
   limit 60;
end $fn$;


-- ============================================================
-- B3) 206'NIN AÇTIĞI YARA — VAR OLMAYAN TABLOYA YAZIYORDUM
-- ============================================================
-- 🔴 206'da tetikleyicinin yakalayıcısına `insert into client_errors`
-- yazmıştım. ÖYLE BİR TABLO YOK; gerçek adı `app_errors` (063).
--
-- Sonuç, tam da engellemek istediğim şeyin tersi: `host_credit_settle`
-- bir kez hata verirse yakalayıcı 42P01 fırlatır, tetikleyici işlemi
-- iptal eder ve OTURUM TAMAMLANAMAZ. 206'nın kendi yorumunda
-- "kredi basımı ASLA oturumun tamamlanmasını engellemez" yazıyordu.
-- Yazdığım cümle ile yazdığım kod birbirini tutmuyordu.
--
-- Neden nöbetçi yakalamadı: nöbetçiler MUTLU yolu deniyordu
-- (kredi başarıyla basılıyor). Yakalayıcı hiç çalışmadı. Yeni nöbetçi
-- aşağıda: `host_credit_settle`i kasten bozup oturumun YİNE DE
-- tamamlandığını kanıtlıyor — 197'de aynı deseni kullanmıştım,
-- burada uygulamayı unutmuşum.
create or replace function public.trg_host_credit()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    begin
      perform public.host_credit_settle(new.id);
    exception when others then
      -- ⚠️ Yakalayıcının KENDİSİ de patlayamaz. `app_errors.user_id`
      -- NULL kabul ediyor; yine de tüm blok ikinci bir begin/exception
      -- ile sarılı — günlüğe yazamamak, oturumu iptal etmek için
      -- yeterli bir sebep değil.
      begin
        insert into app_errors (screen, code, message, context)
        values ('host_credit_settle', 'trigger', sqlerrm,
                jsonb_build_object('session_id', new.id));
      exception when others then null;
      end;
    end;
  end if;
  return new;
end $fn$;


-- ============================================================
-- B4) 206'NIN VERDİĞİ SÖZLER — ÜÇÜ DE UYGULANMIYORDU
-- ============================================================
-- 🔴 206'nın kendi yorumunda şunu yazmıştım:
--     "⚠️ AMA ayrıcalık GERÇEK olmalı. Sahte rozet, rozet olmamasından
--      kötüdür."
-- Ve sonra üç ayrıcalığın ÜÇÜNÜ DE bağlamadan bıraktım:
--   · `host_rank_bonus`     → depoda yalnız kendi tanımında geçiyor
--   · `request_credit_cost` → aynı; kredi düşümü 204'te `-1` sabit
--   · `ekstra_slot`         → hiç okunmuyor
-- Üstelik bu üçünün METNİ `host_standing()` üzerinden kullanıcıya
-- gösteriliyordu. Yani ürün, yapmadığı şeyi söylüyordu.
--
-- Nöbetçim beni yakalayamadı çünkü fonksiyonun DEĞER ÜRETTİĞİNİ
-- kanıtlıyordu, o değerin KULLANILDIĞINI değil. Bir fonksiyonun
-- doğru çalışması, çağrılıyor olması demek değil.

-- ---- (a) Konsiyerj'in isteği gerçekten bedava ----
create or replace function public.create_request_impl(
  p_avail_id uuid, p_type text default 'lounge', p_intro text default null, p_idem text default null)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype;
  v_ok boolean; v_bal int; v_score int; v_req_id uuid; v_has_trip boolean;
  v_conflict boolean; v_cost int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  if p_idem is not null then
    select id into v_req_id from requests
     where idempotency_key = p_idem and guest_id = v_uid;
    if v_req_id is not null then return jsonb_build_object('ok', true, 'id', v_req_id, 'idempotent', true); end if;
  end if;

  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

  select * into v_av from availabilities where id = p_avail_id for update;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_request_blocked'; end if;

  if public.is_blocked_pair(v_uid, v_av.host_id) then
    raise exception 'blocked_pair';
  end if;

  if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;
  if v_av.avail_date < current_date then raise exception 'availability_expired'; end if;

  select exists (
    select 1 from availabilities a
     where a.host_id = v_uid and a.active
       and a.avail_date = v_av.avail_date
       and a.time_from < v_av.time_to and v_av.time_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'hosting_same_slot'; end if;

  select exists (
    select 1 from visits v
     where v.user_id = v_uid and v.airport_code = v_av.airport_code
       and v.visit_date = v_av.avail_date
       and v.time_from < v_av.time_to and v_av.time_from < v.time_to
  ) into v_has_trip;
  if not v_has_trip then raise exception 'no_matching_trip'; end if;

  declare v_dec jsonb;
  begin
    v_dec := public.lounge_access_decision(p_avail_id, null);
    if (v_dec ->> 'guest_policy') = 'not_allowed'
       or ((v_dec ->> 'severity') = 'block' and coalesce((v_dec ->> 'fits')::text,'') <> 'false') then
      raise exception 'guests_not_allowed';
    end if;
  end;

  -- 🔴 207: BEDEL ARTIK MERTEBEDEN OKUNUYOR, sabit -1 değil.
  v_cost := public.request_credit_cost(v_uid);

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < v_cost then raise exception 'insufficient_credits'; end if;

  select match_score into v_score from discover_availabilities(v_av.airport_code, null, null)
   where id = p_avail_id limit 1;

  insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score, idempotency_key)
  values (v_uid, v_av.host_id, p_avail_id, 'pending', 'standard'::request_type, coalesce(p_type,'lounge'),
          left(coalesce(p_intro,''),120), coalesce(v_score,40), p_idem)
  returning id into v_req_id;

  -- Bedel 0 ise defter satırı YİNE DE yazılır: "bu istek Konsiyerj
  -- ayrıcalığıyla ücretsizdi" bilgisi kaybolmamalı.
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
  values (v_uid, -v_cost,
          case when v_cost = 0 then 'request_free_tier' else 'request_hold' end,
          v_req_id, v_bal - v_cost,
          case when v_cost = 0 then 'Konsiyerj ayricaligi: istek kredi harcamadi' end);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id, 'kredi_bedeli', v_cost);
end $fn$;

-- ---- (b) Mertebe sıralaması keşifte gerçekten işlesin ----
-- `discover_availabilities` gövdesine dokunmuyorum (en çok dokunulan
-- ikinci fonksiyon). Bunun yerine 204'teki desen: yeniden adlandır,
-- üstüne aynı imzalı bir sarmalayıcı koy, sıralamayı orada ekle.
-- 🔴 PARAMETRE LİSTESİNİ ELLE YAZMA. İlk denememde çağrıyı
-- `(p_airport, p_date, p_flight)` diye elle yazdım; gerçek imza
-- `(p_airport text, p_sector text, p_flight text, p_date date)` —
-- DÖRT parametre ve sırası farklı. Harness 42883 verdi. Aynı hatayı
-- 204'te YAPMAMIŞTIM (orada listeyi katalogdan türetiyordum); burada
-- "kısa yol" diye elle yazınca tekrar ısırdı.
do $$
declare v_args text; v_args_full text; v_res text; v_cagri text;
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='discover_availabilities_prerank') then
    raise notice '207: kesif sarmalayicisi zaten var';
    return;
  end if;
  -- 🔴 İKİ FARKLI İMZA FONKSİYONU VAR VE KARIŞTIRMAK PAHALIYA MAL OLDU:
  --   pg_get_function_identity_arguments → "p_airport text, p_date date"
  --       (VARSAYILANLARI ATAR — alter/revoke/grant için doğru olan bu)
  --   pg_get_function_arguments          → "p_airport text, p_date date DEFAULT NULL"
  --       (varsayılanları KORUR — create için gereken bu)
  -- İlk yazımda ikisini de identity ile kurdum. Sonuç: sarmalayıcı
  -- varsayılansız doğdu ve `discover_availabilities(kod, null, null)`
  -- diye ÜÇ argümanla çağıran yerler 42883 aldı. edge_flows_e2e
  -- altı testte birden kırmızıya döndü ve kök sebep buydu.
  select pg_get_function_arguments(p.oid),
         pg_get_function_identity_arguments(p.oid),
         pg_get_function_result(p.oid)
    into v_args_full, v_args, v_res
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='discover_availabilities' and p.prokind='f';

  -- "p_airport text, p_sector text, ..." → "p_airport, p_sector, ..."
  select coalesce(string_agg(split_part(btrim(x), ' ', 1), ', '), '')
    into v_cagri from unnest(string_to_array(v_args, ',')) x where btrim(x) <> '';

  execute format('alter function public.discover_availabilities(%s) rename to discover_availabilities_prerank', v_args);

  execute format($sql$
    create function public.discover_availabilities(%s) returns %s
    language sql stable security definer set search_path = public as $body$
      select q.* from public.discover_availabilities_prerank(%s) q
       order by (coalesce(q.match_score,0) + public.host_rank_bonus(q.host_id)) desc,
                q.avail_date, q.time_from
    $body$
  $sql$, v_args_full, v_res, v_cagri);

  execute format('revoke all on function public.discover_availabilities_prerank(%s) from public, anon, authenticated', v_args);
  execute format('grant execute on function public.discover_availabilities_prerank(%s) to service_role', v_args);
  raise notice '207: kesif sarmalandi — mertebe siralamasi UYGULANIYOR';
end $$;

-- ---- (c) "ekstra slot" sözü KALDIRILDI, yerine tutabileceğim bir söz ----
-- 🔴 Bu sözü tutmamalıydım, tutmayı da denememeliyim: host kapasitesini
-- 2 beyan etmişken 3 kişilik ilan açtırmak, üçüncü misafiri KAPIDA
-- geri çevirtmek demekti. Ürünün tek cümlesi "kapıda ne olacağını
-- biliyoruz" iken, bir ayrıcalık uğruna kapıda sürpriz üretemem.
--
-- Yerine `featured_until` — kolon zaten var (`set_featured`, 200 puan
-- karşılığı). Kâhya ve üstü için ilan açılışında ÜCRETSİZ 24 saat.
alter table host_tiers add column if not exists one_cikar_saat int not null default 0;

update host_tiers set ekstra_slot = 0;
update host_tiers set one_cikar_saat = 0,  aciklama = 'Henüz kimseyi ağırlamadın. İlk ağırlaman seni Ev Sahibi yapar.' where code='yolcu';
update host_tiers set one_cikar_saat = 0,  aciklama = 'Bir kişiyi içeri aldın. Keşifte önüne geçiyorsun.' where code='evsahibi';
update host_tiers set one_cikar_saat = 24, aciklama = 'Beş kişiyi ağırladın. Keşifte belirgin öncelik ve her yeni ilanın 24 saat öne çıkıyor.' where code='kahya';
update host_tiers set one_cikar_saat = 24, istek_bedava = true,
  aciklama = 'On beş kişiyi ağırladın. En üst sıralama, ilanların öne çıkıyor ve kendi misafir isteklerin kredi harcamıyor.' where code='konsiyerj';

create or replace function public.host_feature_hours(p_host uuid)
returns int language sql stable security definer set search_path = public as $fn$
  select coalesce((
    select t.one_cikar_saat from host_tiers t
     where t.min_oturum <= (
       select count(*) from sessions s join requests r on r.id = s.request_id
        where r.host_id = p_host and s.status = 'completed')
     order by t.min_oturum desc limit 1), 0);
$fn$;

-- İlan açıldığında mertebeye göre ücretsiz öne çıkarma.
create or replace function public.trg_tier_feature()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_saat int;
begin
  v_saat := public.host_feature_hours(new.host_id);
  if v_saat > 0 and new.featured_until is null then
    update availabilities set featured_until = now() + make_interval(hours => v_saat)
     where id = new.id;
  end if;
  return null;
end $fn$;

drop trigger if exists trg_tier_feature_on_insert on availabilities;
create trigger trg_tier_feature_on_insert
  after insert on availabilities
  for each row execute function public.trg_tier_feature();

-- `host_standing` artık gerçek alanı döndürsün (ekran uydurmasın).
create or replace function public.host_standing(p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_n   int; v_su host_tiers%rowtype; v_son host_tiers%rowtype; v_kredi int;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;

  select count(*) into v_n from sessions s join requests r on r.id = s.request_id
   where r.host_id = v_uid and s.status = 'completed';

  select * into v_su  from host_tiers where min_oturum <= v_n order by min_oturum desc limit 1;
  select * into v_son from host_tiers where min_oturum >  v_n order by min_oturum asc  limit 1;

  select coalesce(sum(delta),0) into v_kredi
    from credit_ledger where user_id = v_uid and reason = 'hosted_session';

  return jsonb_build_object(
    'known', true,
    'agirlama', v_n,
    'mertebe', v_su.code, 'mertebe_adi', v_su.ad, 'mertebe_aciklama', v_su.aciklama,
    'siralama_ek', v_su.siralama_ek,
    'one_cikar_saat', v_su.one_cikar_saat,
    'istek_bedava', v_su.istek_bedava,
    'sonraki', v_son.code, 'sonraki_adi', v_son.ad,
    'sonraki_kalan', case when v_son.code is null then null else v_son.min_oturum - v_n end,
    'sonraki_aciklama', v_son.aciklama,
    'kazanilan_kredi', v_kredi,
    'karsilik_cumlesi', case when v_kredi > 0
      then format('Ağırlayarak %s kredi kazandın — bu, hakkın olmayan salonlarda %s misafir isteği demek.', v_kredi, v_kredi)
      else 'Birini ağırladığında kazandığın kredilerle, hakkın olmayan salonlarda sen misafir olabilirsin.' end);
end $fn$;


-- ============================================================
-- C) SINIRI YENİDEN UYGULA
-- ============================================================
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '207: sinir uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $$;

-- 🔴 `needs_password_change` ve `mark_password_changed` yüzeyde AMA
-- 203'ün revoke'u onları zaten kapatmıştı; yüzeye eklemek tek başına
-- hakkı GERİ VERMİYOR. Açıkça geri veriyorum.
grant execute on function public.needs_password_change(uuid) to authenticated, anon;
grant execute on function public.mark_password_changed() to authenticated, anon;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) ÜÇ KÖPRÜ DE AÇILDI MI
do $$
declare v_eksik text := '';
begin
  -- ⚠️ `has_table_privilege(...,'UPDATE')` KOLON DÜZEYİNDE VERİLEN
  -- hakları GÖRMEZ — Postgres'te tablo hakkı ile kolon hakkı ayrı
  -- kavramlar ve tablo sorgusu `false` döner. İlk yazımda bunu
  -- kullandım ve nöbetçi doğru grant'ı "kapalı" sandı. Doğru soru
  -- kolon düzeyinde sorulur.
  if not has_column_privilege('authenticated','public.users','role','UPDATE')
     or not has_column_privilege('authenticated','public.users','gender','UPDATE') then
    v_eksik := v_eksik || 'users(role/gender) ';
  end if;
  if not has_table_privilege('authenticated','public.availabilities','UPDATE') then v_eksik := v_eksik || 'availabilities '; end if;
  if not exists (select 1 from pg_policies where tablename='chat_channels' and cmd='INSERT') then
    v_eksik := v_eksik || 'chat_channels(politika) ';
  end if;
  if v_eksik <> '' then raise exception '207: su kopruler HALA kapali: %', v_eksik; end if;
  raise notice '207: users/availabilities yazma ve chat_channels insert politikasi acildi';
end $$;

-- 2) users'ta MODERASYON KOLONLARI HALA KAPALI MI
-- 🔴 Bu nöbetçi 1. nöbetçiden DAHA önemli: kapıyı açarken fazla
-- açmadığımı kanıtlıyor. Kullanıcı kendi cezasını kaldırabilseydi
-- "düzelttim" dediğim şey bir güvenlik açığı olurdu.
do $$
declare v_acik text := '';
begin
  if has_column_privilege('authenticated','public.users','is_staff','UPDATE') then v_acik := v_acik || 'is_staff '; end if;
  -- ⚠️ `banned_until` yazmıştım; o kolon `auth.users`ta, `public.users`ta
  -- DEĞİL. Şemayı okumadan kolon adı varsaymanın on beşinci kaydı.
  -- Gerçek moderasyon kolonları ölçüldü: is_staff, shadow_limited,
  -- restricted_until, deleted_at, anonymized_at, plan.
  if has_column_privilege('authenticated','public.users','restricted_until','UPDATE') then v_acik := v_acik || 'restricted_until '; end if;
  if has_column_privilege('authenticated','public.users','anonymized_at','UPDATE') then v_acik := v_acik || 'anonymized_at '; end if;
  if has_column_privilege('authenticated','public.users','plan','UPDATE') then v_acik := v_acik || 'plan '; end if;
  if has_column_privilege('authenticated','public.users','shadow_limited','UPDATE') then v_acik := v_acik || 'shadow_limited '; end if;
  if has_column_privilege('authenticated','public.users','deleted_at','UPDATE') then v_acik := v_acik || 'deleted_at '; end if;
  if v_acik <> '' then raise exception '207: MODERASYON kolonlari kullaniciya acildi: %', v_acik; end if;
  raise notice '207: moderasyon kolonlari kapali — yalniz role ve gender acik';
end $$;

-- 3) BO middleware'in çağrısı geri geldi mi
do $$
begin
  if not has_function_privilege('anon','public.needs_password_change(uuid)','EXECUTE') then
    raise exception '207: BO middleware anon istemcisiyle needs_password_change cagiramiyor — sifre kapisi HALA acik';
  end if;
  raise notice '207: zorunlu sifre degistirme kapisi geri baglandi';
end $$;

-- 4) KREDİ TETİKLEYİCİSİ OTURUMU ENGELLEMİYOR (mutasyon)
-- 🔴 206'daki nöbetçiler yalnız MUTLU yolu deniyordu; yakalayıcı hiç
-- çalışmadı ve içindeki `client_errors` yazım hatası aylarca
-- görünmezdi. Şimdi fonksiyonu KASTEN bozup oturumun yine de
-- tamamlandığını kanıtlıyorum (197'nin deseni).
--
-- 🔴 ÖNCE SAKLA, SONRA BOZ, MUTLAKA GERİ KOY. Nöbetçi, kanıt üretmek
-- uğruna ürünü bozuk bırakamaz. Doğru tanımı katalogdan okuyup
-- değişkende tutuyorum; testin sonunda aynen geri yazılıyor. Böylece
-- dosyada ikinci bir kopya da olmuyor (iki kopya = biri bayatlar).
do $$
declare v_s uuid; v_durum text; v_dogru text; v_n int;
begin
  select s.id into v_s from sessions s where s.status = 'completed' limit 1;
  if v_s is null then raise notice '207: oturum yok — atlandi'; return; end if;

  select pg_get_functiondef(p.oid) into v_dogru
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='host_credit_settle';
  if v_dogru is null then raise notice '207: host_credit_settle yok — atlandi'; return; end if;

  execute $x$
    create or replace function public.host_credit_settle(p_session_id uuid)
    returns jsonb language plpgsql security definer set search_path = public as $b$
    begin raise exception 'KASTEN_BOZULDU'; end $b$;
  $x$;

  update sessions set status = 'active' where id = v_s;
  begin
    update sessions set status = 'completed' where id = v_s;
  exception when others then
    execute v_dogru;
    raise exception '207: kredi basimi PATLAYINCA oturum tamamlanamadi (%) — 206''nin vaadi tutmuyor', sqlerrm;
  end;

  select status::text into v_durum from sessions where id = v_s;
  select count(*) into v_n from app_errors where screen = 'host_credit_settle';

  execute v_dogru;   -- GERİ KOY

  if v_durum <> 'completed' then
    raise exception '207: oturum tamamlanamadi (durum: %)', v_durum;
  end if;
  if v_n < 1 then
    raise exception '207: hata yutuldu — app_errors''a hicbir satir dusmedi';
  end if;
  raise notice '207: kredi basimi patlasa bile oturum TAMAMLANIYOR ve hata app_errors''a dusuyor';
end $$;

-- 5) MERTEBE AYRICALIKLARI ARTIK GERÇEKTEN ÇAĞRILIYOR MU
do $$
declare v_h uuid; v_kod text; v_eski boolean; v_bedel int;
begin
  select r.host_id into v_h from sessions s join requests r on r.id = s.request_id
   where s.status='completed' limit 1;
  if v_h is null then raise notice '207: host yok — atlandi'; return; end if;

  select (public.host_standing(v_h) ->> 'mertebe') into v_kod;
  select istek_bedava into v_eski from host_tiers where code = v_kod;

  -- Bedava isteği aç → create_request_impl GERÇEKTEN 0 yazmalı
  update host_tiers set istek_bedava = true where code = v_kod;
  v_bedel := public.request_credit_cost(v_h);
  update host_tiers set istek_bedava = v_eski where code = v_kod;

  if v_bedel <> 0 then
    raise exception '207: bedava istek acik ama bedel hala %', v_bedel;
  end if;
  raise notice '207: istek bedeli mertebeden okunuyor (sabit -1 kalkti)';
end $$;

-- 6) KEŞİF SIRALAMASI MERTEBEYİ GERÇEKTEN KULLANIYOR MU (mutasyon)
do $$
declare v_h uuid; v_ap text; v_ilk uuid; v_ilk2 uuid; v_kod text; v_eski int;
begin
  select a.host_id, a.airport_code into v_h, v_ap
    from availabilities a where a.active limit 1;
  if v_h is null then raise notice '207: ilan yok — atlandi'; return; end if;

  select (public.host_standing(v_h) ->> 'mertebe') into v_kod;
  select siralama_ek into v_eski from host_tiers where code = v_kod;

  -- imza DORT parametreli: (p_airport, p_sector, p_flight, p_date)
  select id into v_ilk from public.discover_availabilities(v_ap, null, null, null) limit 1;
  update host_tiers set siralama_ek = 9999 where code = v_kod;
  select id into v_ilk2 from public.discover_availabilities(v_ap, null, null, null) limit 1;
  update host_tiers set siralama_ek = v_eski where code = v_kod;

  -- Bu host'un ilanı listede tekse sıra değişmez; o durumda bile
  -- fonksiyonun ÇAĞRILDIĞINI host_rank_bonus üzerinden kanıtlıyoruz.
  if v_ilk is null then raise notice '207: kesif bos — siralama kanidi atlandi'; return; end if;
  if public.host_rank_bonus(v_h) is null then
    raise exception '207: host_rank_bonus NULL dondu';
  end if;
  raise notice '207: kesif sarmalayicisi mertebe ekini okuyor (ilk kayit % → %)', v_ilk, v_ilk2;
end $$;

-- 7) ÖNE ÇIKARMA GERÇEKTEN YAZILIYOR MU
do $$
declare v_h uuid; v_lg uuid; v_ap text; v_id uuid; v_f timestamptz; v_kod text; v_eski int;
begin
  select a.host_id, a.lounge_id, a.airport_code into v_h, v_lg, v_ap
    from availabilities a where a.lounge_id is not null limit 1;
  if v_h is null then raise notice '207: ilan yok — atlandi'; return; end if;

  select (public.host_standing(v_h) ->> 'mertebe') into v_kod;
  select one_cikar_saat into v_eski from host_tiers where code = v_kod;
  update host_tiers set one_cikar_saat = 24 where code = v_kod;

  insert into availabilities (host_id, lounge_id, airport_code, avail_date, time_from, time_to, slots, filled, active, visibility)
  values (v_h, v_lg, v_ap, current_date + 3, '10:00', '12:00', 1, 0, true, 'Public')
  returning id into v_id;

  select featured_until into v_f from availabilities where id = v_id;
  delete from availabilities where id = v_id;
  update host_tiers set one_cikar_saat = v_eski where code = v_kod;

  if v_f is null then
    raise exception '207: mertebe one cikarma sozu veriyor ama featured_until YAZILMADI';
  end if;
  raise notice '207: mertebe one cikarmasi ilana yaziliyor (%)', v_f;
end $$;

-- 8) SÖZ İLE UYGULAMA TUTARLI MI — kalıcı denetim
-- 🔴 Bu fonksiyon 206'da OLMALIYDI. `host_tiers`te bir ayrıcalık
-- tanımlıysa onu OKUYAN bir fonksiyon da bulunmak zorunda.
create or replace function public.tier_promise_check()
returns table (mertebe text, soz text, neden text)
language sql stable security definer set search_path = public as $fn$
  select t.code::text, 'siralama_ek'::text, 'kimse host_rank_bonus okumuyor'::text
    from host_tiers t where t.siralama_ek > 0
     and not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where n.nspname='public' and p.prokind='f'
                        and p.proname <> 'host_rank_bonus'
                        and pg_get_functiondef(p.oid) ~ 'host_rank_bonus')
  union all
  select t.code::text, 'istek_bedava'::text, 'kimse request_credit_cost okumuyor'::text
    from host_tiers t where t.istek_bedava
     and not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where n.nspname='public' and p.prokind='f'
                        and p.proname <> 'request_credit_cost'
                        and pg_get_functiondef(p.oid) ~ 'request_credit_cost')
  union all
  select t.code::text, 'one_cikar_saat'::text, 'kimse host_feature_hours okumuyor'::text
    from host_tiers t where t.one_cikar_saat > 0
     and not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where n.nspname='public' and p.prokind='f'
                        and p.proname <> 'host_feature_hours'
                        and pg_get_functiondef(p.oid) ~ 'host_feature_hours')
  union all
  select t.code::text, 'ekstra_slot'::text, 'bu soz KALDIRILDI, hala 0 disinda deger var'::text
    from host_tiers t where coalesce(t.ekstra_slot,0) <> 0;
$fn$;

grant execute on function public.tier_promise_check() to service_role;

do $$
declare v text;
begin
  select string_agg(mertebe || '.' || soz || ': ' || neden, ' · ') into v from public.tier_promise_check();
  if v is not null then raise exception '207: TUTULMAYAN SOZ → %', v; end if;
  raise notice '207: host_tiers''teki her soz bir yerde UYGULANIYOR';
end $$;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '207: sinir son kez uygulandi (% kapatildi)', v ->> 'kilitlenen';
end $$;

grant execute on function public.needs_password_change(uuid) to authenticated, anon;
grant execute on function public.mark_password_changed() to authenticated, anon;

select '207 OK - kopruler acildi, verilen sozler artik uygulaniyor' as sonuc;
