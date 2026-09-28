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

-- ──────────────────────────────────────────────────────────────────────
-- §B1–B2 · respond_request  (canlı tanım + 300 yaması)
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.respond_request(p_request_id uuid, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid  uuid := auth.uid();
  v_req  requests%rowtype;
  v_av   availabilities%rowtype;
  v_bal  integer;
  v_chan uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);   -- 282/B1: yasakli/silinmis hesap yazamaz

  select * into v_req from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;

  if p_action = 'accept' then
    if v_req.host_id <> v_uid then raise exception 'not_host'; end if;
    if v_req.status <> 'pending' then raise exception 'not_pending'; end if;

    select * into v_av from availabilities where id = v_req.avail_id for update;
    if not found then raise exception 'availability_not_found'; end if;
    -- 🔴 300/B1: süresi geçmiş ya da kaldırılmış ilana KABUL yok.
    -- Eskiden host buluşma saati geçtikten sonra da kabul edebiliyordu:
    -- misafirin kredisi tutuluyor, sohbet açılıyor, ama buluşma imkânsız.
    if not coalesce(v_av.active, true)
       or public.yerel_an(v_av.avail_date, v_av.time_to, v_av.airport_code) < now() then
      raise exception 'availability_expired';
    end if;
    if coalesce(v_av.filled,0) >= v_av.slots then raise exception 'fully_booked'; end if;

    update requests set status='accepted', responded_at=now() where id = v_req.id;

    insert into chat_channels (request_id) values (v_req.id)
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req.id;

    -- 077-3: misafirin tanıtım metni sohbetin ilk mesajı
    if v_chan is not null and coalesce(nullif(trim(v_req.intro_message),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_req.guest_id, trim(v_req.intro_message), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    -- 080: OTURUM BURADA AÇILMAZ. Kabul, buluşma günlerce sonra olabileceği
    -- için "aktif oturum" değildir; iki taraf buluşunca start_session_request
    -- ile başlatılır.
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (v_req.guest_id, 'requests', 'İstek kabul edildi! 🎉',
            'Sohbet açıldı. Buluştuğunuzda iki taraf da "Oturumu Başlat"a basacak.',
            v_req.id, 'request');

    return jsonb_build_object('ok', true, 'channel_id', v_chan, 'session_id', null);

  elsif p_action in ('decline','cancel') then
    if p_action = 'decline' and v_req.host_id  <> v_uid then raise exception 'not_host'; end if;
    if p_action = 'cancel'  and v_req.guest_id <> v_uid then raise exception 'not_guest'; end if;
    if v_req.status not in ('pending','accepted') then raise exception 'not_open'; end if;
    -- 080: oturum başladıysa istek üzerinden iptal edilemez (cancel_session yolu)
    if exists (select 1 from sessions s where s.request_id = v_req.id and s.status in ('pending','active')
                 -- 🔴 300/B2: HİÇ BAŞLATILMAMIŞ boş 'pending' oturum engel değil.
                 -- 293'ten beri davet kabulü böyle bir satır açıyor; misafir
                 -- iptal edemiyor, süpürge de görmüyordu → kredi + slot kilitli.
                 and not (s.status = 'pending' and s.host_started_at is null
                          and s.guest_started_at is null)) then
      raise exception 'session_started';
    end if;

    update requests set status = case when p_action='decline' then 'declined' else 'cancelled' end::request_status,
           responded_at = now()
     where id = v_req.id;

    -- 300/B2: geride kalan boş oturumu da kapat (yetim kalmasın).
    update sessions set status = 'cancelled', completed_at = now(),
           cancelled_by = v_uid, cancel_reason = 'not_started'
     where request_id = v_req.id and status = 'pending'
       and host_started_at is null and guest_started_at is null;

    perform public.istek_kredisi_iade(v_req.id, 'request_refund');

    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (case when p_action='decline' then v_req.guest_id else v_req.host_id end,
            'requests',
            case when p_action='decline' then 'İstek reddedildi' else 'İstek iptal edildi' end,
            'Kredi anında iade edildi.', v_req.id, 'request');
    return jsonb_build_object('ok', true);
  end if;

  raise exception 'unknown_action';
end $function$;

-- ──────────────────────────────────────────────────────────────────────
-- §B3 · confirm_session  (canlı tanım + 300 yaması)
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.confirm_session(p_session_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_s sessions%rowtype; v_r requests%rowtype;
  v_done boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);   -- 300/B3: yasaklı hesap oturum kapatamaz (diğer akış fonksiyonlarıyla aynı)
  select * into v_s from sessions where id = p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_r from requests where id = v_s.request_id;
  if v_uid not in (v_r.host_id, v_r.guest_id) then raise exception 'not_party'; end if;
  if v_s.status <> 'active' then raise exception 'not_active'; end if;

  if v_uid = v_r.host_id then
    update sessions set host_confirmed = true where id = p_session_id;
  else
    update sessions set guest_confirmed = true where id = p_session_id;
  end if;

  select host_confirmed and guest_confirmed into v_done from sessions where id = p_session_id;

  if v_done then
    update sessions set status = 'completed', completed_at = now() where id = p_session_id;
    update requests set status = 'completed' where id = v_s.request_id;

    -- 078: ÖDÜL BURADA (oturum bitti = hak edildi). Host 500 / misafir 200.
    -- Çift ödemeye karşı: aynı oturum için daha önce yazılmışsa atlanır.
    -- NOT: points_ledger'da balance_after KOLONU YOK (SQL 050'de tespit
    -- edilmişti; bakiye user_balances view'ından okunur). Buraya yazmaya
    -- kalkmak fonksiyonu çalışma anında patlatır — yazılmıyor.
    if not exists (select 1 from points_ledger
                    where ref_id = p_session_id and reason = 'session_reward') then
      insert into points_ledger (user_id, delta, reason, ref_id)
      values (v_r.host_id, 500, 'session_reward', p_session_id),
             (v_r.guest_id, 200, 'session_reward', p_session_id);
    end if;

    -- 067'deki ESCROW KAPANIŞ NOTU korunur (drift_check yakaladı):
    -- kredi host'a aktarılmaz (kredi = hak, para değil); misafirin kredisi
    -- harcanmış sayılır, deftere kapanış satırı düşülür.
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    select v_r.guest_id, 0, 'session_settled', p_session_id, coalesce(sum(delta),0)
      from credit_ledger where user_id = v_r.guest_id;

    -- Güven: oturum sayısı değişti → İKİ TARAF için kanonik hesap
    perform public.recompute_trust(v_r.host_id);
    perform public.recompute_trust(v_r.guest_id);

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    select u, 'sessions', 'Oturum tamamlandı ✓',
           'Puanların hesabına eklendi. Karşı tarafı puanlamayı unutma.',
           'session', p_session_id
      from unnest(array[v_r.host_id, v_r.guest_id]) u;
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (case when v_uid = v_r.host_id then v_r.guest_id else v_r.host_id end,
            'sessions', 'Oturum onayı bekleniyor',
            'Karşı taraf oturumu tamamladı olarak işaretledi.', 'session', p_session_id);
  end if;

  return jsonb_build_object('ok', true, 'completed', coalesce(v_done,false));
end $function$;

-- ──────────────────────────────────────────────────────────────────────
-- §B2 · expire_stale_sessions  (canlı tanım + 300 yaması)
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.expire_stale_sessions(p_kaynak text DEFAULT 'uygulama'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_req int := 0; v_sess int := 0;
  v_son timestamptz;
  v_sonuc jsonb;
begin
  -- ── FREN (298) ────────────────────────────────────────────────────
  -- `for update` ile alıyoruz: iki istemci aynı anda çağırırsa ikincisi
  -- birincinin damgasını bekler ve "atlandi" döner. pg_cron ile uygulama
  -- tetiği AYNI FRENİ paylaşır — ikisi birden açık olsa bile gövde
  -- 5 dakikada bir koşar.
  select son_kosum into v_son from public.supurge_damgasi
   where ad = 'expire_stale_sessions' for update;

  if v_son is not null and v_son > now() - interval '5 minutes' then
    return jsonb_build_object('ok', true, 'durum', 'atlandi',
                              'kaynak', p_kaynak,
                              'sonraki', v_son + interval '5 minutes');
  end if;

  insert into public.supurge_damgasi (ad, son_kosum, kaynak)
  values ('expire_stale_sessions', now(), p_kaynak)
  on conflict (ad) do update set son_kosum = now(), kaynak = excluded.kaynak;

  -- ── GÖVDE ─────────────────────────────────────────────────────────
  --
  -- 🔴🔴 299/A2 — 298'DE KENDİ DÜŞÜRDÜĞÜM DÖRT ADIM GERİ KONULDU.
  --
  -- 298'de bu fonksiyonun başına freni takarken gövdeyi de yeniden
  -- yazdım ve 292'nin gövdesindeki DÖRT ADIMI düşürdüm. `drift_check.py`
  -- ikisini gösterdi (`perform public…`), kalan ikisini ben okuyarak
  -- buldum. Düşenler:
  --
  --   1) (b) bloğundaki `r.status = 'accepted'` KAPISI.
  --      280/K2'nin koyduğu kapı: iptal edilmiş isteğin yetim oturumu
  --      no_show DEĞİLDİR. Düşünce, iptal edilmiş bir isteğin arkasında
  --      kalan oturum yüzünden masum bir tarafa no_show yazılıyordu.
  --
  --   2) `perform public.recompute_trust(u) …`
  --      no_show işaretlenen tarafın güven puanı tazelenmiyordu. Yani
  --      ceza yazılıyor ama puana yansımıyordu.
  --
  --   3) (c) BLOĞUNUN TAMAMI — 187-noshow'un kapattığı hata.
  --      (b) oturumu 'expired' yapıyor ama isteği 'accepted' BIRAKIYOR.
  --      Bloksuz hali: misafirin kredisi sonsuza kilitli, host'un slotu
  --      sonsuza dolu (`sync_availability_filled` filled'ı accepted
  --      sayısından türetiyor). TEK BİR NO-SHOW İLANI KALICI OLARAK
  --      ÖLDÜRÜYORDU. 298 bunu geri getirmişti.
  --
  --   4) `perform public.tek_tarafli_oturumlari_kapat();`
  --
  -- 🆕 SINIF: "BİR FONKSİYONUN BAŞINA KAPI TAKARKEN GÖVDESİNİ YENİDEN
  -- YAZMA — ELDEKİ TANIMIN ÜSTÜNE EKLE. YENİDEN YAZMAK, GÖRMEDİĞİN HER
  -- ESKİ DÜZELTMEYİ SESSİZCE GERİ ALIR."
  --
  -- (a) Hiç başlatılmamış kabuller: kimse gelmedi ya da unutuldu →
  --     cezasız kapanış + kredi iadesi.
  --     🔴 İade tutarı artık sabit 1 değil: GERÇEKTEN TUTULAN kadar.
  with stale as (
    select r.id, r.guest_id
      from requests r
      join availabilities a on a.id = r.avail_id
      left join sessions s on s.request_id = r.id
     where r.status = 'accepted'
       -- 🔴 300/B2: `s.id is null` davet kabulünün açtığı BOŞ oturumu
       -- görmüyordu (293). Hiç kimse başlatmadıysa, oturum yok sayılır.
       and (s.id is null
            or (s.status = 'pending' and s.host_started_at is null
                and s.guest_started_at is null))
       and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours'
  ), upd as (
    update requests set status = 'cancelled' where id in (select id from stale) returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select u.guest_id, public.tutulan_kredi(u.id), 'expired_refund', u.id,
         coalesce((select sum(delta) from credit_ledger c where c.user_id = u.guest_id), 0)
           + public.tutulan_kredi(u.id)
    from upd u;
  get diagnostics v_req = row_count;
  -- 300/B2: iptal edilen isteğin arkasındaki boş oturum → 'expired' (no_show DEĞİL).
  update sessions s set status = 'expired', completed_at = now(), cancel_reason = 'not_started'
    from requests r
   where r.id = s.request_id and r.status = 'cancelled'
     and s.status = 'pending' and s.host_started_at is null and s.guest_started_at is null;

  -- (b) Tek taraf başlatmış ama diğeri hiç gelmemiş → 'expired'.
  --     `r.status = 'accepted'` KAPISI 280/K2'den; 299'da geri kondu.
  update sessions s
     set status = 'expired',
         completed_at = now(),
         cancel_reason = 'no_show',
         no_show_user_id = case when s.host_started_at is null then r.host_id else r.guest_id end
    from requests r, availabilities a
   where r.id = s.request_id and a.id = r.avail_id
     and s.status = 'pending'
     and r.status = 'accepted'
     and (s.host_started_at is null) <> (s.guest_started_at is null)
     and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours';
  get diagnostics v_sess = row_count;

  -- Etkilenenlerin güvenini tazele (292'den; 298'de düşmüştü).
  perform public.recompute_trust(u) from (
    select distinct no_show_user_id as u from sessions
     where cancel_reason = 'no_show' and no_show_user_id is not null
       and completed_at > now() - interval '1 day'
  ) x where u is not null;

  -- (c) 187-noshow · 298'de TAMAMEN DÜŞMÜŞTÜ, geri konuldu.
  --     (b) oturumu kapatır ama isteği 'accepted' bırakır; burada istek
  --     de kapanır ve kredi iade edilir. Yoksa kredi de slot da sonsuza
  --     kilitli kalır.
  with kapanan as (
    select r.id, r.guest_id
      from requests r
      join sessions s2 on s2.request_id = r.id
     where r.status = 'accepted'
       and s2.status = 'expired'
       and s2.cancel_reason = 'no_show'
  ), iade as (
    update requests set status = 'cancelled'
     where id in (select id from kapanan)
    returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select i.guest_id, public.tutulan_kredi(i.id), 'no_show_refund', i.id,
         coalesce((select sum(c.delta) from credit_ledger c
                    where c.user_id = i.guest_id), 0) + public.tutulan_kredi(i.id)
    from iade i
   where not exists (select 1 from credit_ledger c2
                      where c2.ref_id = i.id and c2.reason = 'no_show_refund');

  perform public.tek_tarafli_oturumlari_kapat();

  v_sonuc := jsonb_build_object('ok', true, 'durum', 'kosuldu',
                                'kaynak', p_kaynak,
                                'iptal_edilen', v_req, 'suresi_dolan', v_sess);

  -- Sonucu damgaya yaz: panelde "en son koşum NE YAPTI" görünsün.
  update public.supurge_damgasi
     set son_sonuc = v_sonuc, ardisik_hata = 0
   where ad = 'expire_stale_sessions';

  return v_sonuc;
exception
  when others then
    -- ⚠️ BURADA `update` DEĞİL `insert … on conflict` KULLANILIYOR VE
    -- BUNUN SEBEBİ ÖNEMLİ: plpgsql'de bir istisna, bloğun BAŞINDAN
    -- itibaren her şeyi geri alır — yukarıdaki damga `insert`i DAHİL.
    -- Yani handler'a girildiğinde satır ARTIK YOKTUR; `update` 0 satır
    -- günceller ve hata izi sessizce kaybolur. Tam da görünür kılmaya
    -- çalıştığımız şeyi kaybederdik.
    --
    -- 🆕 SINIF: "BİR HATA KAYDINI, HATANIN GERİ ALDIĞI SATIRIN ÜSTÜNE
    -- YAZAMAZSIN — HANDLER'DA HER ZAMAN YENİDEN OLUŞTURMAYA HAZIR OL."
    --
    -- Hatayı istisna olarak ATMIYORUZ, jsonb olarak DÖNÜYORUZ: çağıran
    -- `ok=false` görür, damga kalıcı olur ve `bo_supurge_sagligi()`
    -- onu gösterir. Yutmak değil — yerini değiştirmek.
    insert into public.supurge_damgasi (ad, son_kosum, kaynak, ardisik_hata, son_hata, son_hata_an)
    values ('expire_stale_sessions', coalesce(v_son, now() - interval '1 hour'),
            p_kaynak, 1, left(SQLERRM, 400), now())
    on conflict (ad) do update
      set ardisik_hata = public.supurge_damgasi.ardisik_hata + 1,
          kaynak       = excluded.kaynak,
          son_hata     = excluded.son_hata,
          son_hata_an  = excluded.son_hata_an;
    return jsonb_build_object('ok', false, 'durum', 'hata',
                              'kaynak', p_kaynak, 'hata', left(SQLERRM, 400));
end $function$;

-- ──────────────────────────────────────────────────────────────────────
-- §B4 · bayat_istekleri_iade_et  (canlı tanım + 300 yaması)
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.bayat_istekleri_iade_et()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_saat int := coalesce((select (value #>> '{}')::int from beta_settings
                           where key = 'bayat_istek_saat'), 72);
  r record; v_bal int; v_kapatilan int := 0; v_iade int := 0;
begin
  perform public.motor_yazimi_ac();

  for r in
    select req.id, req.guest_id
      from requests req
      join availabilities a on a.id = req.avail_id
     where req.status = 'pending'
       and req.responded_at is null
       -- 🔴 300/B4: UTC tarihi değil, havalimanının yerel saati. Eskiden
       -- saati geçmiş bir ilanın bekleyen isteği ertesi UTC gününe kadar
       -- açık kalıyordu (kredi tutulu, host cevap veremez).
       and (public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now()
            or req.created_at < now() - make_interval(hours => v_saat))
  loop
    -- Satır satır: bir satır bir iş kuralına takılırsa toplu iş çökmesin.
    begin
      update requests
         set status = 'cancelled',
             responded_at = now(),
             decision_note = coalesce(decision_note,
               'Host süresinde yanıtlamadı — istek otomatik kapatıldı (274).')
       where id = r.id and status = 'pending';
      if not found then continue; end if;
      v_kapatilan := v_kapatilan + 1;

      -- İADE yalnız gerçekten kredi düşülmüşse ve daha önce iade
      -- edilmemişse. `request_free_tier` satırları burada kasıtla dışarıda:
      -- harcanmayan kredi iade edilmez.
      if exists (select 1 from credit_ledger cl
                  where cl.ref_id = r.id and cl.reason in ('request_hold','invite_hold') and cl.delta < 0)
         and not exists (select 1 from credit_ledger cl
                          where cl.ref_id = r.id and cl.reason = 'request_stale_refund')
      then
        select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = r.guest_id;
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
        values (r.guest_id, public.tutulan_kredi(r.id), 'request_stale_refund', r.id,
                v_bal + public.tutulan_kredi(r.id),
                format('%s saat içinde yanıt gelmedi', v_saat));
        v_iade := v_iade + 1;
      end if;

      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      values (r.guest_id, 'requests', 'İsteğin kapandı',
              format('Başvurun %s saat içinde yanıtlanmadı. Artık yeni istek gönderebilirsin.', v_saat),
              'request', r.id);
    exception when others then
      raise notice '274: istek % kapatilamadi: %', r.id, sqlerrm;
    end;
  end loop;

  return jsonb_build_object('ok', true, 'kapatilan', v_kapatilan,
                            'iade_edilen', v_iade, 'esik_saat', v_saat);
end $function$;

-- ──────────────────────────────────────────────────────────────────────
-- §B5 · create_request_impl  (canlı tanım + 300 yaması)
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_request_impl(p_avail_id uuid, p_type text DEFAULT 'lounge'::text, p_intro text DEFAULT NULL::text, p_idem text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

        -- 🔴 300/B5: iki kapı, ikisi de ÖLÇÜLDÜ (SEED8 §5):
        --  · aynı ilana ikinci başvuru ham bir kısıt hatası döndürüyordu:
        --    "duplicate key value violates unique constraint …" — uygulama
        --    bunu "Bir şeyler ters gitti" diye gösteriyordu.
        --  · tarih bugünse ama SAAT geçmişse başvuru kabul ediliyordu.
        --  · 🔴 AYNI İLANA YENİDEN İSTEK SESSİZCE HİÇBİR ŞEY YAPMIYORDU.
        --    Uygulama tekrar-deneme anahtarını `uid:ilan` olarak üretiyor; iptal
        --    ettiğin (ya da reddedilen) isteğin anahtarı aynı kalıyordu. Yeni
        --    istek bu anahtarla gelince `preflag` ESKİ, KAPALI isteği
        --    `{"ok":true,"idempotent":true}` diye döndürüyordu — ekran "gönderildi"
        --    diyor, host hiçbir şey görmüyor. (Ölçüldü: ilk → iptal → tekrar =
        --    aynı id, durum `cancelled`.)
        --    Kapalı bir isteğin anahtarı artık serbest bırakılıyor: çift dokunuş
        --    korunur (açık istek), yeni deneme yeni istek olur.
        -- 🆕 SINIF: "BİR TEKRAR-DENEME ANAHTARI, KORUDUĞU İŞLEMDEN UZUN
        -- YAŞARSA, SONRAKİ HER GERÇEK İSTEĞİ BİR TEKRAR SANIR."
        if p_idem is not null then
          update requests set idempotency_key = null
           where idempotency_key = p_idem and guest_id = auth.uid()
             and status not in ('pending', 'accepted');
        end if;
        -- Tekrar deneme anahtarı (p_idem) ile gelen AÇIK istek dokunulmadan geçer.
        if p_idem is null or not exists (select 1 from requests
                                          where idempotency_key = p_idem and guest_id = auth.uid()) then
          if exists (select 1 from requests where guest_id = auth.uid() and avail_id = p_avail_id
                                              and status in ('pending','accepted')) then
            raise exception 'already_requested';
          end if;
          if exists (select 1 from availabilities a where a.id = p_avail_id
                      and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now()) then
            raise exception 'availability_expired';
          end if;
        end if;

        return public.create_request_impl_preflag(p_avail_id, p_type, p_intro, p_idem);
      end $function$;

-- ──────────────────────────────────────────────────────────────────────
-- §B6 · trg_bakiye_negatife_dusemez  (canlı tanım + 300 yaması)
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_bakiye_negatife_dusemez()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare v_bal int;
begin
  if new.delta >= 0 then return new; end if;
  if new.reason like 'paid_guest_thanks_reversal:%' or new.reason like 'admin%' then
    return new;
  end if;

  -- 🔴 300/B6: KİLİT TETİKLEYİCİNİN İÇİNDE. 299/B2 kilidi dört yola
  -- koymuştu; `misafir_hakki_hediye_et` beşinciydi ve kilitsizdi. İki
  -- eşzamanlı hediye aynı 3 krediyi iki kez harcayabiliyordu (ölçüldü:
  -- ikinci oturum birincinin commit'ini beklemeden geçti).
  -- Kilit burada olunca YOL SAYISI önemsizleşiyor: bakiyeyi eksilten her
  -- satır, aynı kullanıcının diğer eksiltmesini commit'e kadar bekler ve
  -- sonra GÜNCEL toplamı okur.
  perform pg_advisory_xact_lock(hashtextextended('kredi:' || new.user_id::text, 0));
  select coalesce(sum(delta), 0) into v_bal
    from credit_ledger where user_id = new.user_id;

  if v_bal + new.delta < 0 then
    raise exception 'insufficient_credits'
      using detail = format('kullanıcı %s: bakiye %s, denenen %s (%s)',
                            new.user_id, v_bal, new.delta, new.reason),
            hint   = 'Bu satır bakiyeyi negatife düşürürdü; 299/B1 reddetti.';
  end if;
  return new;
end $function$;

-- ════════════════════════════════════════════════════════════════════════
-- §Z — KENDİNİ ÖLÇ. Açık kalan kapı varsa DUR.
-- ════════════════════════════════════════════════════════════════════════
do $z300$
declare v_n int; v_liste text;
begin
  -- A1: kilitli olanlar authenticated/anon tarafından çağrılamaz
  select count(*), string_agg(p.proname, ', ') into v_n, v_liste
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and p.proname in ('change_plan','kredi_akis_raporu','anonymized_users',
                       'host_kota_durumu','doluluk_reddi_sayisi','oturum_kural_hedefi',
                       'kural_guncelligi','access_options_for_user','bo_slot_asimlari')
     and (has_function_privilege('authenticated', p.oid, 'execute')
          or has_function_privilege('anon', p.oid, 'execute'));
  if v_n > 0 then raise exception '300 §Z/A1: hâlâ açık: %', v_liste; end if;

  -- A2: PUBLIC'e açık SECURITY DEFINER fonksiyon kalmadı
  select count(distinct p.oid), string_agg(distinct p.proname, ', ') into v_n, v_liste
    from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace and p.prosecdef
     and a.grantee = 0 and a.privilege_type = 'EXECUTE';
  if v_n > 0 then raise exception '300 §Z/A2: PUBLIC''e açık % fonksiyon: %', v_n, v_liste; end if;

  -- A2: küresel varsayılan gerçekten yazıldı mı?
  if not exists (select 1 from pg_default_acl d
                  where d.defaclnamespace = 0 and d.defaclobjtype = 'f'
                    and d.defaclrole = 'postgres'::regrole) then
    raise exception '300 §Z/A2: küresel varsayılan yetki kaydı yok';
  end if;

  -- Uygulamanın çağırdığı beş fonksiyon authenticated'da KALDI mı?
  select count(*), string_agg(p.proname, ', ') into v_n, v_liste
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and p.proname in ('cancel_availability','binis_karti_kaydet','ilani_yeniden_yayinla',
                       'hikaye_davetini_ertele','kesifte_gorun','profil_karti',
                       'create_request','respond_request','confirm_session')
     and not has_function_privilege('authenticated', p.oid, 'execute');
  if v_n > 0 then raise exception '300 §Z: uygulama fonksiyonu KAPANDI: %', v_liste; end if;

  -- A3 / B6 tetikleyicileri yerinde mi?
  if not exists (select 1 from pg_trigger where tgname = 'trg_visit_0_beyan_temizle') then
    raise exception '300 §Z/A3: tetikleyici yok';
  end if;
  if position('pg_advisory_xact_lock' in
       (select prosrc from pg_proc where proname = 'trg_bakiye_negatife_dusemez')) = 0 then
    raise exception '300 §Z/B6: kredi kilidi tetikleyicide yok';
  end if;
  if position('availability_expired' in
       (select prosrc from pg_proc where proname = 'respond_request')) = 0 then
    raise exception '300 §Z/B1: kabul kapısı yok';
  end if;
  if position('already_requested' in
       (select prosrc from pg_proc where proname = 'create_request_impl')) = 0 then
    raise exception '300 §Z/B5: mükerrer başvuru kapısı yok';
  end if;

  raise notice '300 §Z: bütün kapılar ölçüldü — kapalı';
end $z300$;

select '300 OK — uçtan uca denetim bulguları kapatıldı' as sonuc;
