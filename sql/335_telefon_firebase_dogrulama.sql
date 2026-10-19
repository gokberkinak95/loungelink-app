-- ============================================================================
-- 335 · TELEFON DOĞRULAMASI: FIREBASE KANALI + GÜVENİLİR ÜYE EŞİĞİ 25  (18 Ekim 2026)
--
-- Gökberk onayı (önizleme "Telefon Doğrulama Akışı"):
--   · SMS'i Firebase Telefon Doğrulama gönderir (günde ilk 10 SMS ücretsiz, yalnız Türkiye).
--   · Kodun doğruluğuna UYGULAMA karar vermez: Firebase'in imzalı jetonu panel sunucusunda
--     (/api/telefon-dogrula) doğrulanır, numara eşleşmesi kontrol edilir ve doğrulamayı
--     YALNIZ service_role bu dosyadaki `telefon_dogrulandi_yaz` ile yazar.
--   · Maliyet kilidi: kullanıcı başına günde 3, numara başına günde 3 gönderim izni
--     (`telefon_gonderim_izni` — uygulama Firebase'e gitmeden önce sorar), yalnız +90 5xx.
--   · Güvenilir üyelere açık profilleri görme eşiği 40 → 25: e-posta (16) görmez,
--     e-posta + telefon (26) görür. Puanlar değişmez (e-posta 10 · telefon 10 · kimlik 18).
--
-- Kanal anahtarı: beta_settings.telefon_kanali = 'kapali' (varsayılan) | 'firebase'.
-- Firebase kurulumu bitince TEK SATIR:
--   update beta_settings set value = to_jsonb('firebase'::text) where key = 'telefon_kanali';
--   update beta_settings set value = to_jsonb('<firebase-proje-id>'::text) where key = 'firebase_proje_id';
-- Supabase SQL Editor: her ifade ayrı işlemde koşar; geçici tablo / psql komutu yok.
-- Tekrar koşulabilir.
-- ============================================================================

-- §1 · ayarlar
insert into beta_settings (key, value) values ('telefon_kanali', to_jsonb('kapali'::text))
  on conflict (key) do nothing;
insert into beta_settings (key, value) values ('firebase_proje_id', to_jsonb(''::text))
  on conflict (key) do nothing;
insert into beta_settings (key, value) values ('telefon_gunluk_kullanici', to_jsonb(3))
  on conflict (key) do nothing;
insert into beta_settings (key, value) values ('telefon_gunluk_numara', to_jsonb(3))
  on conflict (key) do nothing;
insert into beta_settings (key, value) values ('profil_trusted_esik', to_jsonb(25))
  on conflict (key) do update set value = to_jsonb(25);

-- §2 · gönderim defteri (maliyet kilidi)
create table if not exists public.telefon_gonderimleri (
  id bigserial primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  phone_kanonik text not null,
  created_at timestamptz not null default now()
);
create index if not exists telefon_gonderimleri_kullanici on public.telefon_gonderimleri (user_id, created_at desc);
create index if not exists telefon_gonderimleri_numara on public.telefon_gonderimleri (phone_kanonik, created_at desc);
alter table public.telefon_gonderimleri enable row level security;
-- politika yok: yalnız security definer fonksiyonlar ve service_role erişir

-- §3 · kanal: uygulama hangi yolu kullanacağını sunucudan öğrenir (güncelleme gerekmeden açılır)
create or replace function public.dogrulama_kanali()
returns jsonb
language sql stable security definer set search_path = public as $dk335$
  select jsonb_build_object(
    'kanal', coalesce((select value #>> '{}' from beta_settings where key = 'otp_channel'), 'email'),
    'sms_hazir', coalesce((select value #>> '{}' from beta_settings where key = 'otp_sms_saglayici'), '') <> '',
    'telefon_kanali', coalesce((select value #>> '{}' from beta_settings where key = 'telefon_kanali'), 'kapali'),
    'firebase_hazir', coalesce((select value #>> '{}' from beta_settings where key = 'telefon_kanali'), '') = 'firebase'
                      and coalesce((select value #>> '{}' from beta_settings where key = 'firebase_proje_id'), '') <> '',
    'not', coalesce((select value #>> '{}' from beta_settings where key = 'otp_notice_phone_declared'), '')
  );
$dk335$;
revoke execute on function public.dogrulama_kanali() from public;
grant execute on function public.dogrulama_kanali() to authenticated, anon;

-- §4 · gönderim izni: uygulama Firebase'e SMS istemeden önce sorar
create or replace function public.telefon_gonderim_izni(p_phone text)
returns jsonb
language plpgsql security definer set search_path = public as $tg335$
declare
  v_uid uuid := auth.uid();
  v_kan text;
  v_k int; v_n int;
  v_tavan_k int := coalesce((select (value #>> '{}')::int from beta_settings where key = 'telefon_gunluk_kullanici'), 3);
  v_tavan_n int := coalesce((select (value #>> '{}')::int from beta_settings where key = 'telefon_gunluk_numara'), 3);
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if coalesce((select value #>> '{}' from beta_settings where key = 'telefon_kanali'), 'kapali') <> 'firebase' then
    raise exception 'sms_not_configured';
  end if;
  v_kan := public.telefon_kanonik(p_phone);
  -- kanonik biçim artısız: 905XXXXXXXXX (268 · telefon_kanonik)
  if v_kan is null or v_kan !~ '^905[0-9]{9}$' then raise exception 'telefon_yalniz_tr_cep'; end if;
  if exists (select 1 from users where phone_kanonik = v_kan and deleted_at is null and id <> v_uid) then
    raise exception 'phone_taken';
  end if;
  if exists (select 1 from telefon_gonderimleri where user_id = v_uid and created_at > now() - interval '60 seconds') then
    raise exception 'too_many_requests';
  end if;
  select count(*) into v_k from telefon_gonderimleri where user_id = v_uid and created_at > now() - interval '24 hours';
  select count(*) into v_n from telefon_gonderimleri where phone_kanonik = v_kan and created_at > now() - interval '24 hours';
  if v_k >= v_tavan_k or v_n >= v_tavan_n then raise exception 'telefon_gunluk_sinir'; end if;
  insert into telefon_gonderimleri (user_id, phone_kanonik) values (v_uid, v_kan);
  return jsonb_build_object('ok', true, 'telefon', '+' || v_kan, 'kalan', least(v_tavan_k - v_k, v_tavan_n - v_n) - 1);
end $tg335$;
revoke all on function public.telefon_gonderim_izni(text) from public, anon;
grant execute on function public.telefon_gonderim_izni(text) to authenticated;

-- §5 · doğrulamayı yazan TEK kapı (yalnız service_role: panel /api/telefon-dogrula)
create or replace function public.telefon_dogrulandi_yaz(p_user uuid, p_phone text)
returns jsonb
language plpgsql security definer set search_path = public as $td335$
declare
  v_kan text; v_once int; v_sonra int;
begin
  v_kan := public.telefon_kanonik(p_phone);
  if v_kan is null then raise exception 'invalid_phone'; end if;
  if not exists (select 1 from users where id = p_user and deleted_at is null) then raise exception 'user_not_found'; end if;
  if exists (select 1 from users where phone_kanonik = v_kan and deleted_at is null and id <> p_user) then
    raise exception 'phone_taken';
  end if;
  select coalesce((select score from trust_scores where user_id = p_user), 0) into v_once;
  begin
    update users set phone = '+' || v_kan, phone_e164 = v_kan, phone_kanonik = v_kan where id = p_user;
  exception when unique_violation then
    raise exception 'phone_taken';
  end;
  insert into verifications (user_id, phone_verified, phone_verified_at, phone_verified_method)
  values (p_user, true, now(), 'sms')
  on conflict (user_id) do update
    set phone_verified = true, phone_verified_at = now(), phone_verified_method = 'sms';
  v_sonra := public.recompute_trust(p_user);
  return jsonb_build_object('ok', true, 'telefon', '+' || v_kan, 'puan_once', v_once, 'puan_sonra', v_sonra,
    'esik', coalesce((select (value #>> '{}')::int from beta_settings where key = 'profil_trusted_esik'), 40));
end $td335$;
revoke all on function public.telefon_dogrulandi_yaz(uuid, text) from public, anon, authenticated;
grant execute on function public.telefon_dogrulandi_yaz(uuid, text) to service_role;

-- §6 · numara değişince doğrulama düşer (eski numaranın doğrulaması yeni numaraya geçmesin)
create or replace function public.trg_telefon_degisti()
returns trigger
language plpgsql security definer set search_path = public as $tt335$
begin
  if coalesce(old.phone_kanonik, '') <> coalesce(new.phone_kanonik, '') then
    update verifications set phone_verified = false, phone_verified_at = null
     where user_id = new.id and phone_verified;
    if found then perform public.recompute_trust(new.id); end if;
  end if;
  return new;
end $tt335$;
drop trigger if exists telefon_degisti on public.users;
create trigger telefon_degisti after update of phone_kanonik on public.users
  for each row execute function public.trg_telefon_degisti();

-- telefon_dogrulandi_yaz önce numarayı yazar (tetikleyici doğrulamayı düşürür), SONRA
-- doğrulamayı true yapar: sıra bilerek böyle.

-- §6b · bildirim yönlendirmesi (uygulama içi şerit, telefon bildirimi ve bildirim listesi aynı
-- hedefi kullanır). Hedefi olmayan bildirim (genel duyuru) uygulamada Bildirimler sayfasını açar.
create or replace function public.bildirim_hedefi(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $bh335$
declare v_uid uuid := auth.uid(); n record; v_req requests%rowtype; v_cr connection_requests%rowtype; v_rid uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into n from notifications where id = p_id and user_id = v_uid;
  if n.id is null then return jsonb_build_object('ekran', null); end if;

  -- 335 · yönlendirmesi olmayan türler ölçüldü (yerel DB, 21 tür örneği): ilan kapandı,
  -- sistem kategorisinde kredi, plan değişikliği, kaçırılan fırsat özeti hiçbir yere gitmiyordu.
  if n.ref_type = 'availability' then
    return jsonb_build_object('ekran', 'plan', 'alt', 'ilan', 'ref', n.ref_id);
  elsif n.ref_type = 'credits' then
    return jsonb_build_object('ekran', 'cuzdan');
  elsif n.ref_type = 'plan' then
    return jsonb_build_object('ekran', 'planlar');
  elsif n.ref_type = 'missed_digest' then
    return jsonb_build_object('ekran', 'kesfet');
  end if;

  if n.ref_type = 'message' then
    return jsonb_build_object('ekran', 'sohbet', 'ref', n.ref_id);
  elsif n.ref_type = 'rate_reminder' then
    return jsonb_build_object('ekran', 'degerlendirmeler', 'ref', n.ref_id);
  elsif n.ref_type = 'trip_reminder' or n.ref_type = 'meet_soon' then
    return jsonb_build_object('ekran', 'istek_sohbet', 'ref', n.ref_id);
  elsif n.ref_type = 'question' then
    return jsonb_build_object('ekran', 'akis', 'alt', 'soru', 'ref', n.ref_id);
  elsif n.ref_type = 'invite' then
    return jsonb_build_object('ekran', 'akis', 'alt', 'davet', 'ref', n.ref_id);
  elsif n.ref_type = 'session' then
    select request_id into v_rid from sessions where id = n.ref_id;
    if v_rid is not null then
      return jsonb_build_object('ekran', 'istek_sohbet', 'ref', v_rid);
    end if;
    return jsonb_build_object('ekran', 'akis', 'alt', 'sohbet');
  elsif n.ref_type = 'request' then
    select * into v_req from requests where id = n.ref_id;
    if v_req.id is not null and v_req.status in ('accepted','completed') then
      return jsonb_build_object('ekran', 'istek_sohbet', 'ref', v_req.id);
    end if;
    return jsonb_build_object('ekran', 'akis', 'alt', 'istek', 'ref', n.ref_id);
  elsif n.ref_type = 'connection' then
    select * into v_cr from connection_requests where id = n.ref_id;
    if v_cr.id is not null and coalesce(v_cr.intent,'') = 'kural_sorusu' then
      return jsonb_build_object('ekran', 'akis', 'alt', 'soru', 'ref', n.ref_id);
    elsif v_cr.id is not null and v_cr.status = 'accepted' then
      return jsonb_build_object('ekran', 'akis', 'alt', 'baglanti', 'ref', n.ref_id);
    elsif v_cr.id is not null and v_cr.status = 'pending' and v_cr.to_id = v_uid then
      return jsonb_build_object('ekran', 'akis', 'alt', 'davet', 'ref', n.ref_id);
    end if;
    return jsonb_build_object('ekran', 'tanis', 'ref', n.ref_id);
  end if;

  return case n.category::text
    when 'requests'    then jsonb_build_object('ekran','akis','alt','istek','ref', n.ref_id)
    when 'sessions'    then jsonb_build_object('ekran','akis','alt','sohbet','ref', n.ref_id)
    when 'invites'     then jsonb_build_object('ekran','akis','alt','davet','ref', n.ref_id)
    when 'connections' then jsonb_build_object('ekran','tanis','ref', n.ref_id)
    when 'credits'     then jsonb_build_object('ekran','cuzdan')
    when 'ratings'     then jsonb_build_object('ekran','degerlendirmeler','ref', n.ref_id)
    when 'safety'      then jsonb_build_object('ekran','guvenlik')
    else jsonb_build_object('ekran', null) end;
end $bh335$;
grant execute on function public.bildirim_hedefi(uuid) to authenticated;

-- §6c · telefon şartı (Gökberk onayı, 19 Ekim). SMS kanalı açıkken ('firebase') buluşma ya da
-- yazışma açan her kapı (lounge isteği, Tanış bağlantısı, davet, ilan açma, host başvurusu) için
-- TELEFON doğrulaması şart. Kanal kapalıyken bugünkü kural: telefon veya e-posta.
-- Kural sorusu (host'a ilan kuralını sormak) buluşma açmaz: her zaman telefon VEYA e-posta yeter.
-- (Önceki hata: kural sorusu yalnız telefon istiyordu; SMS olmadığı için kimse soru soramıyordu.)
create or replace function public.iletisim_dogrulandi_gevsek(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $ig335$
  select coalesce(bool_or(phone_verified) or bool_or(email_verified), false)
    from verifications where user_id = p_user
$ig335$;
revoke all on function public.iletisim_dogrulandi_gevsek(uuid) from public, anon, authenticated;
grant execute on function public.iletisim_dogrulandi_gevsek(uuid) to service_role;

create or replace function public.is_contact_verified(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $cv335$
  select case
    when coalesce((select value #>> '{}' from beta_settings where key = 'telefon_kanali'), 'kapali') = 'firebase'
      then coalesce((select phone_verified from verifications where user_id = p_user), false)
    else public.iletisim_dogrulandi_gevsek(p_user) end
$cv335$;
revoke all on function public.is_contact_verified(uuid) from public, anon, authenticated;
grant execute on function public.is_contact_verified(uuid) to service_role;

do $ks335$
declare v_tanim text; v_eski text := 'select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception ''phone_not_verified''; end if;';
begin
  select pg_get_functiondef(p.oid) into v_tanim from pg_proc p
   where p.proname = 'ilan_kurali_sor' and p.pronamespace = 'public'::regnamespace limit 1;
  if v_tanim is null then raise notice '335: ilan_kurali_sor yok — atlandi.'; return; end if;
  if v_tanim like '%iletisim_dogrulandi_gevsek%' then raise notice '335: ilan_kurali_sor zaten guncel.'; return; end if;
  if position(v_eski in v_tanim) = 0 then raise exception '335: ilan_kurali_sor govdesi beklenenden farkli — elle bak.'; end if;
  v_tanim := replace(v_tanim, v_eski, 'if not public.iletisim_dogrulandi_gevsek(v_uid) then raise exception ''contact_not_verified''; end if;');
  execute v_tanim;
end $ks335$;

-- §6d · kredi paketlerinin adları son modele (Cüzdan "Tek hak / Üç hak / Beş hak" yazıyordu)
update kredi_paketleri set ad = '1 kredi', aciklama = 'Tek bir lounge isteği için.' where kod = 'tek';
update kredi_paketleri set ad = '3 kredi', aciklama = 'Aynı anda birkaç ilana başvurmak için.' where kod = 'uclu';
update kredi_paketleri set ad = '5 kredi', aciklama = 'En uygun fiyat: kredi başına 60 ₺.' where kod = 'besli';

-- §7 · doğrulama
select 'kanal anahtari' as kontrol, exists (select 1 from beta_settings where key = 'telefon_kanali') as tamam
union all
select 'esik 25', (select (value #>> '{}')::int from beta_settings where key = 'profil_trusted_esik') = 25
union all
select 'yazan kapi yalniz service_role',
       not has_function_privilege('authenticated', 'public.telefon_dogrulandi_yaz(uuid, text)', 'execute')
union all
select 'gonderim izni authenticated', has_function_privilege('authenticated', 'public.telefon_gonderim_izni(text)', 'execute')
union all
select 'numara degisince dusuren tetikleyici', exists (select 1 from pg_trigger where tgname = 'telefon_degisti')
union all
select 'bildirim hedefi: ilan ve kredi turleri', pg_get_functiondef('public.bildirim_hedefi(uuid)'::regprocedure) like '%missed_digest%'
union all
select 'kural sorusu e-postayla acik', (select bool_or(prosrc like '%iletisim_dogrulandi_gevsek%') from pg_proc where proname = 'ilan_kurali_sor')
union all
select 'telefon sarti kanala bagli', pg_get_functiondef('public.is_contact_verified(uuid)'::regprocedure) like '%telefon_kanali%'
union all
select 'paket adlari guncel', (select count(*) from kredi_paketleri where aktif and ad in ('1 kredi','3 kredi','5 kredi')) = 3;
-- Beklenen: dokuz satır tamam = true.
