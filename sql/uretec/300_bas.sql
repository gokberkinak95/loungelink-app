-- ============================================================================
-- LoungeLink · 300_uctan_uca_denetim.sql                     (23 Eylül 2026)
--
-- UÇTAN UCA DENETİMİN SUNUCU BULGULARI — HER BİRİ YERELDE ÖLÇÜLDÜ
--
-- Bu dosya yeni özellik eklemiyor; ölçülmüş kusurları kapatıyor. Her
-- bölümün başında ölçümün kendisi yazılı. Fonksiyon gövdeleri ELLE
-- YENİDEN YAZILMADI: `uretec/uret_300.py` canlı tanımı veritabanından
-- okuyup üstüne yama ekledi (299/A2 dersi). Çapa bulunamazsa üretim durur.
--
--   §A1  KRİTİK — `change_plan` herkese açıktı: ödemesiz plan + bedava kredi
--   §A2  Yeni fonksiyonlar herkese (PUBLIC) açık doğuyordu
--   §A3  Kullanıcı kendi uçuşunu "doğrulanmış" yazabiliyordu
--   §A4  Keşifte görün anahtarı hiç kaydedemiyordu (her dokunuş hata)
--   §A5  Başkasının profilinde doğrulama rozetleri hiç görünmüyordu
--   §A6  Pasif salon notları ("214 kaynaksız → pasif") ekranda
--   §A7  Eksik / mükerrer indeksler
--   §B1  Süresi geçmiş ilana KABUL verilebiliyordu
--   §B2  Davetle açılan boş oturum: iptal edilemiyor, süpürge görmüyor
--   §B3  confirm_session hesap kapısından geçmiyordu
--   §B4  Bayat istek süpürgesi UTC tarihine bakıyordu
--   §B5  İkinci başvuru ham kısıt hatası · saati geçmiş ilana başvuru ·
--        iptal edilen ilana YENİDEN istek sessizce eski isteği döndürüyordu
--   §B6  Eşzamanlı iki hediye aynı krediyi iki kez harcayabiliyordu
--
-- TEKRAR KOŞULABİLİR. Sonunda §Z kendi kendini ölçer; bir kapı açık
-- kaldıysa `raise exception` ile durur.
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════
-- §A1 — KRİTİK: `change_plan` HERKESE AÇIKTI
--
-- Ölçüm (rollback'li, authenticated rolüyle):
--     kredi 3 → change_plan('frequent') → {"credits_added":19} → kredi 22
-- Planlar arasında gidip gelmek her seferinde yeniden kredi basıyordu.
-- 253 bunu kilitlemişti; 265 §2 "bo_ olmayan HER ŞEYİ authenticated'a
-- ver" derken geri açtı. 265'in gerekçesi "hepsi zaten auth.uid()
-- kontrolü yapıyor" idi — change_plan yapmıyordu.
--
-- 🆕 SINIF: "TOPLU BİR YETKİ, ONU GEREKÇELENDİREN VARSAYIMIN EN ZAYIF
-- ÖRNEĞİ KADAR GÜVENLİDİR."
--
-- Aynı dalgada açık kalanlar (istemci ÇAĞIRMIYOR — ölçüldü, 154 RPC'lik
-- uygulama listesinde yoklar; BO bunları service_role ile çağırıyor):
--   kredi_akis_raporu — platformun kredi toplamları
--   anonymized_users  — silinen kullanıcılar ve silen yönetici
--   host_kota_durumu / doluluk_reddi_sayisi / oturum_kural_hedefi /
--   kural_guncelligi  — gövdede kimlik kontrolü YOK, id alıyorlar
--   access_options_for_user — herkesin kart haklarını döndürüyor
--   bo_slot_asimlari  — 298 authenticated'dan aldı, PUBLIC geri veriyordu
-- ════════════════════════════════════════════════════════════════════════
do $a1$
declare r record; n int := 0;
begin
  for r in
    select p.oid::regprocedure as imza
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('change_plan','kredi_akis_raporu','anonymized_users',
                         'host_kota_durumu','doluluk_reddi_sayisi','oturum_kural_hedefi',
                         'kural_guncelligi','access_options_for_user','bo_slot_asimlari')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.imza);
    execute format('grant execute on function %s to service_role', r.imza);
    n := n + 1;
  end loop;
  raise notice '300 §A1: % fonksiyon service_role''a kilitlendi', n;
end $a1$;

-- İzin listesinde (`rpc_client_surface`) olmadıklarından emin ol —
-- `apply_rpc_surface()` bir gün koşarsa aynı sonuca varsın.
delete from rpc_client_surface
 where fn_name in ('change_plan','kredi_akis_raporu','anonymized_users',
                   'host_kota_durumu','doluluk_reddi_sayisi','oturum_kural_hedefi',
                   'kural_guncelligi','access_options_for_user','bo_slot_asimlari');

-- ════════════════════════════════════════════════════════════════════════
-- §A2 — YENİ FONKSİYONLAR HERKESE AÇIK DOĞUYORDU
--
-- 265/280 `alter default privileges IN SCHEMA public revoke … from public`
-- yazdı. Şema düzeyindeki varsayılan, küresel varsayılana yalnız EKLEME
-- yapabilir, çıkaramaz. Küresel kayıt yoktu (`pg_default_acl` içinde
-- defaclnamespace=0 → 0 satır). Sonuç: 20 SECURITY DEFINER fonksiyonda
-- `=X/postgres` (PUBLIC) duruyordu. Ölçüm: anon rolüyle
-- `select count(*) from bo_slot_asimlari()` → HATASIZ çalıştı.
--
-- 🆕 SINIF: "HATA VERMEYEN BİR YETKİ KOMUTU, İŞE YARADIĞINI GÖSTERMEZ —
-- ETKİSİNİ SONRADAN ÖLÇMEDİĞİN HER REVOKE BİR TEMENNİDİR."
-- ════════════════════════════════════════════════════════════════════════
alter default privileges for role postgres revoke execute on functions from public;

do $a2$
declare r record; n int := 0; v_ad text;
begin
  for r in
    select distinct p.oid::regprocedure as imza, p.proname
      from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     where p.pronamespace = 'public'::regnamespace
       and a.grantee = 0 and a.privilege_type = 'EXECUTE'
       and p.prosecdef
  loop
    execute format('revoke execute on function %s from public, anon', r.imza);
    -- uygulamanın çağırdığı ya da yardımcı olanlar authenticated'da KALIR
    if r.proname in ('cancel_availability','binis_karti_kaydet','binis_karti_durumu',
                     'ilani_yeniden_yayinla','hikaye_davetini_ertele',
                     'yerel_an','yerel_gun','yerel_saat','yonetici_kapisi') then
      execute format('grant execute on function %s to authenticated', r.imza);
    end if;
    execute format('grant execute on function %s to service_role', r.imza);
    n := n + 1;
  end loop;
  raise notice '300 §A2: % fonksiyondan PUBLIC yetkisi alındı', n;
end $a2$;

-- ════════════════════════════════════════════════════════════════════════
-- §A3 — KULLANICI KENDİ UÇUŞUNU "DOĞRULANMIŞ" YAZABİLİYORDU
--
-- Ölçüm: insert into visits(…, flight_verified, flight_source, terminal)
--        values (…, true, 'fake', '9')  → t | fake | 9
-- `venue_stay_pressure` (partner analitiği) YALNIZ doğrulanmış uçuşları
-- sayıyor — tam da elle yazılan saatler veriyi bozmasın diye. 240 bilerek
-- INSERT'i kolonsuz bıraktı; burada kolonları değil, DEĞERLERİ temizliyoruz:
-- istemciden gelen satırda sunucuya ait alanlar sıfırlanır, doğrulamayı
-- AFTER tetikleyici (`trg_visit_flight_sync`) kendisi yazar.
-- Ad bilerek `trg_visit_0…`: BEFORE tetikleyicileri ada göre sıralanır.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.trg_visit_0_beyan_temizle()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Sunucu yolları (tohum, cron, motor) auth.uid() olmadan yazar → dokunma.
  if auth.uid() is null or coalesce(current_setting('loungelink.motor', true), '') = 'evet' then
    return new;
  end if;
  new.flight_verified     := false;
  new.flight_source       := null;
  new.flight_checked_at   := null;
  new.scheduled_departure := null;
  new.scheduled_arrival   := null;
  new.terminal            := null;
  return new;
end $$;
revoke execute on function public.trg_visit_0_beyan_temizle() from public, anon, authenticated;
drop trigger if exists trg_visit_0_beyan_temizle on public.visits;
create trigger trg_visit_0_beyan_temizle before insert on public.visits
  for each row execute function public.trg_visit_0_beyan_temizle();

-- ════════════════════════════════════════════════════════════════════════
-- §A4 — "KEŞİFTE GÖRÜN" ANAHTARI HİÇ KAYDEDEMİYORDU
--
-- 253 §5 `profiles.show_on_discovery` güncellemesini istemciden aldı
-- (sunucuya ait kolonlarla aynı listeye girmişti). Ama Ayarlar ekranı
-- hâlâ doğrudan `update` yapıyordu → her dokunuş "permission denied",
-- ekranda "kaydedilemedi" ve anahtar geri zıplıyor.
-- Bu bir KULLANICI TERCİHİ; sunucuya ait değil. Yetkiyi geri açmak
-- yerine tek amaçlı bir kapı: yalnız kendi satırın, yalnız bu kolon.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.kesifte_gorun(p_acik boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  update profiles set show_on_discovery = coalesce(p_acik, true), updated_at = now()
   where user_id = v_uid;
  return jsonb_build_object('ok', true, 'show_on_discovery', coalesce(p_acik, true));
end $$;
revoke execute on function public.kesifte_gorun(boolean) from public, anon;
grant execute on function public.kesifte_gorun(boolean) to authenticated;
insert into rpc_client_surface (fn_name, client, note)
select 'kesifte_gorun', 'app', '300 §A4 — Ayarlar: Keşifte görün'
 where not exists (select 1 from rpc_client_surface where fn_name = 'kesifte_gorun');

-- ════════════════════════════════════════════════════════════════════════
-- §A5 — BAŞKASININ PROFİLİNDE DOĞRULAMA ROZETLERİ HİÇ GÖRÜNMÜYORDU
--
-- Profil ekranı `users` ve `verifications` tablolarını doğrudan okuyor;
-- ikisinin RLS'i (`users_own`, `verif_own`) yalnız KENDİ satırını
-- gösteriyor. Ölçüm (A kullanıcısı olarak): B'nin verifications → 0 satır.
-- Sonuç: başka birinin profilinde telefon/kimlik/e-posta rozetleri ve
-- "doğrulanmış kadın" hiçbir zaman çizilmiyor, host rengi hiç gelmiyor,
-- "Oturum N" yalnız ikinizin ortak oturumlarını sayıyor.
-- P2P bir buluşma ürününde güvenin görünür kanıtı TAM OLARAK bu rozetler.
--
-- Tabloları açmak yerine dar bir kart: yalnız evet/hayır bayrakları,
-- ham telefon/e-posta/cinsiyet YOK (cinsiyetten yalnız "kadın mı" —
-- kadın güvenlik modu zaten bunun üzerine kurulu).
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.profil_karti(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_user is null then return null; end if;
  if p_user <> v_uid then
    if public.is_blocked_pair(v_uid, p_user) then return null; end if;
    if exists (select 1 from users u where u.id = p_user
                and (u.deleted_at is not null or u.banned_at is not null)) then
      return null;
    end if;
  end if;
  select jsonb_build_object(
           'role', u.role,
           'kadin', (u.gender = 'female'),
           'phone_verified', coalesce(vf.phone_verified, false),
           'email_verified', coalesce(vf.email_verified, false),
           'id_verified',    coalesce(vf.id_verified, false),
           'linkedin_verified', coalesce(vf.linkedin_verified, false),
           'oturum', (select count(*) from sessions s join requests r on r.id = s.request_id
                       where s.status = 'completed' and (r.guest_id = p_user or r.host_id = p_user)))
    into v
    from users u left join verifications vf on vf.user_id = u.id
   where u.id = p_user;
  return v;
end $$;
revoke execute on function public.profil_karti(uuid) from public, anon;
grant execute on function public.profil_karti(uuid) to authenticated;
insert into rpc_client_surface (fn_name, client, note)
select 'profil_karti', 'app', '300 §A5 — Profil: doğrulama rozetleri'
 where not exists (select 1 from rpc_client_surface where fn_name = 'profil_karti');

-- ════════════════════════════════════════════════════════════════════════
-- §A6 — PASİF SALON NOTLARI EKRANDA
--
-- 190/211/214 pasife aldıkları salonların ADINA iz düştü:
--   "Primeclass Lounge (214 kaynaksız → pasif)"
-- Bu iz o salona bağlı eski ilanların `lounge_name` kopyasına da geçmiş
-- olabilir ve oturum geçmişinde aynen çiziliyor (sahne 25'te görüldü).
-- Salon tablosundaki ize DOKUNMUYORUZ (yönetim için anlamlı); yalnız
-- ilanın ekranda görünen kopyası temizleniyor.
-- ════════════════════════════════════════════════════════════════════════
update availabilities
   set lounge_name = btrim(regexp_replace(lounge_name, '\s*\(\d{3}\s[^)]*\)', '', 'g'))
 where lounge_name ~ '\(\d{3}\s';

-- ════════════════════════════════════════════════════════════════════════
-- §A7 — İNDEKSLER
--
-- Eksik: her iadenin mükerrer kontrolü ve `tutulan_kredi` `credit_ledger.
-- ref_id` ile filtreliyor — indeks yoktu. `invites.avail_id`
-- (cancel_availability), `messages.from_id`, `ratings.rater_id` da.
-- Mükerrer (aynı tanım iki kez — her yazmada iki kez güncelleniyor):
--   idx_requests_unique_active ≡ requests_guest_avail_active_uniq
--   requests_idem_uniq         ⊂ requests_idempotency_key_key (kısıt)
--   idx_sessions_request       ≡ sessions_request_id_key (kısıt)
-- ════════════════════════════════════════════════════════════════════════
create index if not exists idx_credit_ledger_ref_reason on public.credit_ledger (ref_id, reason);
create index if not exists idx_invites_avail_status on public.invites (avail_id, status);
create index if not exists idx_messages_from on public.messages (from_id);
create index if not exists idx_ratings_rater on public.ratings (rater_id);
do $a7$ begin
  if to_regclass('public.requests_guest_avail_active_uniq') is not null then
    drop index if exists public.idx_requests_unique_active;
  end if;
  if exists (select 1 from pg_constraint where conname = 'requests_idempotency_key_key') then
    drop index if exists public.requests_idem_uniq;
  end if;
  if exists (select 1 from pg_constraint where conname = 'sessions_request_id_key') then
    drop index if exists public.idx_sessions_request;
  end if;
end $a7$;

