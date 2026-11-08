-- ============================================================================
-- 345 · KİMLİK BELGESİ (KYC) KAPANIR · "DOĞRULANMIŞ PROFİL" · GÜVEN PUANI
--       PAZARLAMA İZNİ (opt-in) · HESAP SİLMEDE EKSİKLER · SAKLAMA SÜRELERİ
--       (8 Kasım 2026 · Gökberk kararı: "biz basit bir eşleştirme uygulamasıyız")
--
-- §1 KYC KAPANIR. Kimlik belgesi ve selfie artık alınmaz: gönderim fonksiyonu
--    'kyc_kapali' der, `kyc` kovasının yazma kuralları kalkar, tablodaki belge
--    yolları ve bekleyen başvurular temizlenir. Kovadaki DOSYALAR SQL'le silinmez
--    (Supabase, storage tablosundan doğrudan silmeyi engelliyor ve blob kalır):
--    Dashboard › Storage › kyc › hepsini seç › Delete. Sayı aşağıdaki kontrolde.
-- §2 "DOĞRULANMIŞ PROFİL". verifications.id_verified kolonu artık KİMLİK değil,
--    şu dört şartın birlikte sağlanmasıdır: e-posta doğrulanmış · telefon SMS ile
--    doğrulanmış · profil fotoğrafı var · meslek yazılı. Tetikleyiciler kolonu
--    kendiliğinden tutar; id_verified okuyan her yer (istek kartı rozeti, profil
--    rozeti, "yalnız doğrulanmış profiller" ilan seçeneği) yeni anlamla çalışır.
-- §3 GÜVEN PUANI. Kimliğin 18 puanı dağıtıldı: telefon 10→14, profil fotoğrafı
--    (yeni) 6, oturumlar 6/10/14 → 8/13/18, puanlar 10/6/2 → 14/8/3. Üst sınır
--    aynı (host 90, misafir 82); rozet eşikleri değişmez. Herkes yeniden hesaplanır.
-- §4 PAZARLAMA İZNİ. users.pazarlama_izni (varsayılan KAPALI). Kayıtta işaretsiz
--    kutu, Ayarlar'da anahtar. Kampanya (BO › İletişim) YALNIZ izin verene gider.
--    Kanal yalnız uygulama bildirimi: ticari e-posta / SMS / arama yok.
-- §5 HESAP SİLME. Anonimleştirmede cinsiyet, pazarlama izni, bildirimler, bildirim
--    tercihleri, iletişim e-postası ve kimlik başvurusu izleri de silinir.
-- §6 SAKLAMA SÜRELERİ (Gizlilik §7'de yazanlar artık gerçekten uygulanıyor):
--    hata kayıtları 12 ay · bildirimler 12 ay · uçuş sorgu kayıtları 12 ay ·
--    sohbet mesajları 24 ay · şikayet kayıtları 5 yıl · silinen hesabın e-posta özeti
--    5 yıl · anonimleşmiş hesabın onay kayıtları 10 yıl. Her gece 04:10 (pg_cron).
--
-- Supabase SQL Editor'de tek parça; tekrar koşulabilir. Doğrulama: son sorguda
-- bütün satırlar tamam = true (kyc dosya sayısı satırı bilgi amaçlı).
-- ============================================================================

-- ── §1 KYC KAPANIR ──────────────────────────────────────────────────────────
create or replace function public.kimlik_belgesi_gonder(p_doc_path text, p_selfie_path text)
returns jsonb language plpgsql security definer set search_path = public as $kbg345$
begin
  -- 345 · Kimlik belgesi artık alınmıyor (eski uygulama sürümleri buraya düşer).
  raise exception 'kyc_kapali';
end $kbg345$;

drop policy if exists "kyc_own_write"  on storage.objects;
drop policy if exists "kyc_own_update" on storage.objects;

update public.verifications
   set id_doc_path = null, id_selfie_path = null, id_review_note = null,
       id_status = case when id_status in ('submitted', 'approved', 'rejected') then 'none' else id_status end,
       updated_at = now()
 where id_doc_path is not null or id_selfie_path is not null
    or id_status in ('submitted', 'approved', 'rejected');

-- ── §2 DOĞRULANMIŞ PROFİL ───────────────────────────────────────────────────
create or replace function public.profil_dogrulandi_hesapla(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $pdh345$
  select coalesce((
    select coalesce(v.email_verified, false)
       and coalesce(v.phone_verified, false)
       and coalesce(v.phone_verified_method, 'sms') <> 'bypass'
       and nullif(btrim(coalesce(p.photo_url, '')), '') is not null
       and nullif(btrim(coalesce(p.profession, '')), '') is not null
      from public.verifications v
      left join public.profiles p on p.user_id = v.user_id
     where v.user_id = p_user), false)
$pdh345$;
revoke execute on function public.profil_dogrulandi_hesapla(uuid) from public, anon;

create or replace function public.profil_dogrulama_esitle(p_user uuid)
returns void language plpgsql security definer set search_path = public as $pde345$
declare v_ok boolean := public.profil_dogrulandi_hesapla(p_user);
begin
  update public.verifications
     set id_verified    = v_ok,
         id_verified_at = case when v_ok then coalesce(id_verified_at, now()) else null end,
         id_provider    = case when v_ok then 'profil' else null end,
         updated_at     = now()
   where user_id = p_user and id_verified is distinct from v_ok;
end $pde345$;
revoke execute on function public.profil_dogrulama_esitle(uuid) from public, anon, authenticated;

create or replace function public.trg_profil_dogrulama()
returns trigger language plpgsql security definer set search_path = public as $tpd345$
begin
  perform public.profil_dogrulama_esitle(new.user_id);
  return null;
end $tpd345$;

drop trigger if exists profil_dogrulama_p on public.profiles;
create trigger profil_dogrulama_p
  after insert or update of photo_url, profession on public.profiles
  for each row execute function public.trg_profil_dogrulama();

drop trigger if exists profil_dogrulama_v on public.verifications;
create trigger profil_dogrulama_v
  after insert or update of email_verified, phone_verified, phone_verified_method on public.verifications
  for each row execute function public.trg_profil_dogrulama();

-- Güven puanı fotoğraf değişince de yeniden hesaplanır (yeni bileşen).
drop trigger if exists on_profile_trust on public.profiles;
create trigger on_profile_trust
  after insert or update of profession, bio, linkedin_url, linkedin_verified, guest_capacity, photo_url on public.profiles
  for each row execute function public.trg_profile_trust();

-- Mevcut herkes yeni tanıma göre (eski KYC onayları da bu tanıma geçer).
update public.verifications v
   set id_verified    = public.profil_dogrulandi_hesapla(v.user_id),
       id_verified_at = case when public.profil_dogrulandi_hesapla(v.user_id) then coalesce(v.id_verified_at, now()) else null end,
       id_provider    = case when public.profil_dogrulandi_hesapla(v.user_id) then 'profil' else null end
 where v.id_verified is distinct from public.profil_dogrulandi_hesapla(v.user_id)
    or coalesce(v.id_provider, '') not in ('profil', '');

-- ── §3 GÜVEN PUANI ──────────────────────────────────────────────────────────
create or replace function public.recompute_trust(p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_c jsonb := '{}'::jsonb; v_score int := 0;
  v_p profiles%rowtype; v_v verifications%rowtype;
  v_sessions int; v_rating numeric; v_rating_n int; v_badge text;
  v_bad int; v_penalty int := 0; v_atla int;
begin
  select * into v_p from profiles where user_id = p_user;
  select * into v_v from verifications where user_id = p_user;

  select count(*) into v_sessions
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' and (r.guest_id = p_user or r.host_id = p_user);

  v_c := v_c || '{"email":10}'::jsonb;
  -- 345 · kimlik (18) kalktı: telefon 10→14, profil fotoğrafı +6, oturum +4, puan +4
  if coalesce(v_v.phone_verified,false) then v_c := v_c || '{"phone":14}'::jsonb; end if;
  if nullif(btrim(coalesce(v_p.photo_url,'')),'') is not null then v_c := v_c || '{"photo":6}'::jsonb; end if;

  if coalesce(v_p.linkedin_verified, false) then
    v_c := v_c || '{"linkedin":8}'::jsonb;
  elsif coalesce(nullif(trim(v_p.linkedin_url),''), '') <> '' then
    v_c := v_c || '{"linkedin":4}'::jsonb;
  end if;

  if coalesce(nullif(trim(v_p.profession),''), '') <> '' then
    v_c := v_c || '{"profession":6}'::jsonb;
  end if;
  if length(coalesce(trim(v_p.bio),'')) >= 40 then
    v_c := v_c || '{"bio":6}'::jsonb;
  end if;

  if v_p.guest_capacity is not null and v_sessions >= 1 then
    v_c := v_c || '{"host_access":8}'::jsonb;
  end if;

  if v_sessions >= 10 then v_c := v_c || '{"sessions":18}'::jsonb;
  elsif v_sessions >= 3 then v_c := v_c || '{"sessions":13}'::jsonb;
  elsif v_sessions >= 1 then v_c := v_c || '{"sessions":8}'::jsonb;
  end if;

  select avg(score)::numeric, count(*) into v_rating, v_rating_n
    from ratings where rated_id = p_user;

  if coalesce(v_rating_n,0) >= 3 then
    if v_rating >= 4.5 then v_c := v_c || '{"rating":14}'::jsonb;
    elsif v_rating >= 4.0 then v_c := v_c || '{"rating":8}'::jsonb;
    elsif v_rating >= 3.0 then v_c := v_c || '{"rating":3}'::jsonb;
    end if;
  end if;

  -- 080: son 90 gündeki geç iptal + no-show cezası (her biri -12).
  select count(*) into v_bad from sessions s
   where s.completed_at > now() - interval '90 days'
     and ((s.cancel_reason = 'late_cancel' and s.cancelled_by = p_user)
       or (s.cancel_reason = 'no_show' and s.no_show_user_id = p_user));
  v_penalty := least(36, coalesce(v_bad,0) * 12);
  if v_penalty > 0 then
    v_c := v_c || jsonb_build_object('reliability', -v_penalty);
  end if;

  -- 307: 30 günde 2'yi aşan biniş kartı atlaması, her biri -3 (en çok -9).
  v_atla := greatest(0, public.binis_atlama_sayisi(p_user) - 2);
  if v_atla > 0 then
    v_c := v_c || jsonb_build_object('bp_atlama', -least(9, v_atla * 3));
  end if;

  select coalesce(sum(value::int),0) into v_score from jsonb_each_text(v_c);
  v_score := least(100, greatest(0, v_score));

  v_badge := public.compute_trust_badge(v_score);

  insert into trust_scores (user_id, score, badge, components, updated_at)
  values (p_user, v_score, v_badge, v_c, now())
  on conflict (user_id) do update
    set score = excluded.score, badge = excluded.badge,
        components = excluded.components, updated_at = now();

  return v_score;
end $$;

do $rt345$
declare r record; n int := 0;
begin
  for r in select u.id from public.users u where u.anonymized_at is null loop
    begin
      perform public.recompute_trust(r.id); n := n + 1;
    exception when others then
      raise notice '345: % puanlanamadi: %', r.id, sqlerrm;
    end;
  end loop;
  raise notice '345: % kullanicinin guven puani yeniden hesaplandi.', n;
end $rt345$;

-- ── §4 PAZARLAMA İZNİ (opt-in) ──────────────────────────────────────────────
alter table public.users add column if not exists pazarlama_izni boolean not null default false;
alter table public.users add column if not exists pazarlama_izni_at timestamptz;

create or replace function public.pazarlama_izni_yaz(p_acik boolean)
returns jsonb language plpgsql security definer set search_path = public as $piy345$
declare v_uid uuid := auth.uid(); v_acik boolean := coalesce(p_acik, false);
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  update users set pazarlama_izni = v_acik, pazarlama_izni_at = now() where id = v_uid;
  -- İspat kaydı: verilme de geri alma da ayrı satır (KVKK m.3 / 6563 m.6).
  insert into consents (user_id, type, version, granted_at)
  values (v_uid, case when v_acik then 'pazarlama_bildirimi' else 'pazarlama_bildirimi_geri_alindi' end, 'v17', now());
  return jsonb_build_object('ok', true, 'pazarlama_izni', v_acik);
end $piy345$;
revoke all on function public.pazarlama_izni_yaz(boolean) from public, anon;
grant execute on function public.pazarlama_izni_yaz(boolean) to authenticated;

-- Kayıtta işaretlenen isteğe bağlı kutu, onay listesinde 'pazarlama_bildirimi' olarak gelir
-- (kayıt akışının yeniden deneme / ertelenmiş yazma yolları aynen çalışsın diye).
create or replace function public.grant_consents(p_types text[], p_version text default 'v17')
returns jsonb language plpgsql security definer set search_path = public as $gc345$
declare v_uid uuid := auth.uid(); t text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  foreach t in array p_types loop
    insert into consents (user_id, type, version, granted_at)
    values (v_uid, t, p_version, now())
    on conflict do nothing;
  end loop;
  if 'pazarlama_bildirimi' = any(p_types) then
    update users set pazarlama_izni = true, pazarlama_izni_at = now() where id = v_uid;
  end if;
  return jsonb_build_object('ok', true, 'count', array_length(p_types,1));
end $gc345$;

create or replace function public.bildirim_tercihlerim()
returns jsonb
language plpgsql stable security definer set search_path = public as $bt345$
declare v_uid uuid := auth.uid(); v_p jsonb; v_kap jsonb; v_pz boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select prefs into v_p from notification_prefs where user_id = v_uid;
  select value into v_kap from beta_settings where key = 'bildirim_kapatilabilir';
  select pazarlama_izni into v_pz from users where id = v_uid;
  return jsonb_build_object(
    'tercihler', coalesce(v_p, '{}'::jsonb),
    'kapatilabilir', coalesce(v_kap, '[]'::jsonb),
    'kapatilamaz_not', public.metin('bildirim_zorunlu_not_tr'),
    'pazarlama_izni', coalesce(v_pz, false));
end $bt345$;
grant execute on function public.bildirim_tercihlerim() to authenticated;

create or replace function public.send_campaign(
  p_title text, p_body text, p_segment jsonb, p_admin uuid,
  p_user_ids uuid[] default null
)
returns jsonb language plpgsql security definer set search_path = public as $sc345$
declare v_cid uuid; v_n int := 0; v_govde text;
begin
  -- 345 · Kampanya YALNIZ pazarlama iznini veren kullanıcıya gider ve her iletide
  -- nasıl kapatılacağı yazar (6563 m.6, Ticari İletişim Yönetmeliği).
  v_govde := btrim(coalesce(p_body, '')) || E'\n' || 'Kapatmak için: Ayarlar › Bildirimler.';
  insert into notification_campaigns (title, body, segment, created_by)
  values (p_title, p_body, coalesce(p_segment,'{}'::jsonb), p_admin) returning id into v_cid;

  if p_user_ids is not null and array_length(p_user_ids, 1) > 0 then
    with target as (
      select u.id from users u
      where u.id = any(p_user_ids)
        and u.deleted_at is null
        and coalesce(u.is_staff, false) = false
        and u.pazarlama_izni
    ), ins as (
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      select id, 'system'::notif_category, p_title, v_govde, 'campaign', v_cid from target
      returning 1
    )
    select count(*) into v_n from ins;
  else
    with target as (
      select u.id from users u
      left join profiles p on p.user_id = u.id
      left join trust_scores ts on ts.user_id = u.id
      where u.deleted_at is null
        and coalesce(u.is_staff, false) = false
        and u.pazarlama_izni
        and (p_segment->>'role' is null or u.role::text = p_segment->>'role')
        and (p_segment->>'plan' is null or u.plan::text = p_segment->>'plan')
        and (p_segment->>'min_trust' is null or coalesce(ts.score,0) >= (p_segment->>'min_trust')::int)
        and (p_segment->>'airport' is null or exists (
              select 1 from visits v where v.user_id = u.id and v.airport_code = p_segment->>'airport'
            ))
    ), ins as (
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      select id, 'system'::notif_category, p_title, v_govde, 'campaign', v_cid from target
      returning 1
    )
    select count(*) into v_n from ins;
  end if;

  update notification_campaigns set sent_count = v_n where id = v_cid;
  return jsonb_build_object('ok', true, 'sent', v_n, 'campaign_id', v_cid);
end $sc345$;

-- ── §5 HESAP SİLME: EKSİK ALANLAR ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_anonymize_user(p_user_id uuid, p_admin text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_tag text;
begin
  perform 1 from users where id = p_user_id;
  if not found then raise exception 'user_not_found'; end if;
  if (select anonymized_at from users where id = p_user_id) is not null then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  v_tag := 'silinmis-' || left(replace(p_user_id::text, '-', ''), 8);

  -- 1) KİMLİK (345: cinsiyet ve pazarlama izni de)
  update users
     set email = v_tag || '@silinmis.loungelink',
         phone = null, phone_e164 = null, phone_kanonik = null, deleted_at = coalesce(deleted_at, now()),
         gender = null, pazarlama_izni = false,
         anonymized_at = now(),
         anonymized_by = p_admin
   where id = p_user_id;

  -- 2) PROFİL
  update profiles
     set name = 'Silinmiş kullanıcı',
         bio = null, profession = null, photo_url = null,
         linkedin_url = null, linkedin_verified = false,
         access_source = null,
         show_on_discovery = false, profile_visibility = 'Connections',
         updated_at = now()
   where user_id = p_user_id;

  -- 3) DOĞRULAMA İZLERİ (345: eski kimlik başvurusu alanları da)
  update verifications
     set phone_verified = false, id_verified = false,
         id_doc_path = null, id_selfie_path = null, id_review_note = null, id_status = 'none'
   where user_id = p_user_id;

  -- 4) SERBEST METİN İÇEREN KAYITLAR
  -- Mesajlar SİLİNMEZ (karşı tarafın sohbeti ve itiraz bağlamı); yazar anonimleşir,
  -- mesajlar saklama süresi (24 ay) dolunca §6 işiyle silinir.
  update reports set description = '[anonimlestirildi]'
   where reporter_id = p_user_id;
  update ratings set comment = null
   where rater_id = p_user_id;
  delete from push_tokens      where user_id = p_user_id;
  delete from otp_tokens       where user_id = p_user_id;
  delete from visits           where user_id = p_user_id and visit_date >= current_date;
  delete from availabilities   where host_id = p_user_id and avail_date >= current_date;
  delete from host_entitlements where user_id = p_user_id;
  -- 345 · kişiye özel kayıtlar
  delete from notifications      where user_id = p_user_id;
  delete from notification_prefs where user_id = p_user_id;
  delete from user_contact       where user_id = p_user_id;

  -- 5) OTURUMU KAPAT
  delete from auth.sessions  where user_id = p_user_id;
  delete from auth.identities where user_id = p_user_id;
  update auth.users
     set email = v_tag || '@silinmis.loungelink',
         phone = null,
         raw_user_meta_data = '{}'::jsonb,
         banned_until = 'infinity'
   where id = p_user_id;
  if exists (select 1 from information_schema.columns
              where table_schema = 'auth' and table_name = 'users' and column_name = 'deleted_at') then
    execute 'update auth.users set deleted_at = coalesce(deleted_at, now()) where id = $1' using p_user_id;
  end if;

  return jsonb_build_object('ok', true, 'tag', v_tag);
end $function$;

-- Zaten anonimleşmiş hesaplarda kalan cinsiyet / izin / kimlik izleri
update public.users set gender = null, pazarlama_izni = false
 where anonymized_at is not null and (gender is not null or pazarlama_izni);

-- ── §6 SAKLAMA SÜRELERİ ─────────────────────────────────────────────────────
create or replace function public.saklama_suresi_imha()
returns jsonb language plpgsql security definer set search_path = public as $ssi345$
declare
  v_sonuc jsonb := '{}'::jsonb; v_n int;
  r record;
begin
  for r in
    select * from (values
      ('app_errors',       'created_at', interval '12 months'),
      ('notifications',    'created_at', interval '12 months'),
      ('flight_fetch_log', 'created_at', interval '12 months'),
      ('messages',         'created_at', interval '24 months'),
      ('reports',          'created_at', interval '5 years')
    ) as t(tablo, kolon, sure)
  loop
    if exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = r.tablo and column_name = r.kolon) then
      begin
        execute format('delete from public.%I where %I < now() - $1', r.tablo, r.kolon) using r.sure;
        get diagnostics v_n = row_count;
        v_sonuc := v_sonuc || jsonb_build_object(r.tablo, v_n);
      exception when others then
        -- Bir tablo başka bir kayda bağlıysa (yabancı anahtar) iş durmaz; hata sayılır.
        v_sonuc := v_sonuc || jsonb_build_object(r.tablo, 'hata: ' || left(sqlerrm, 120));
      end;
    end if;
  end loop;

  -- Onay kayıtları: hesap silindikten (anonimleştikten) 10 yıl sonra
  begin
    delete from public.consents c using public.users u
     where u.id = c.user_id and u.anonymized_at is not null
       and u.anonymized_at < now() - interval '10 years';
    get diagnostics v_n = row_count;
    v_sonuc := v_sonuc || jsonb_build_object('consents', v_n);
  exception when others then
    v_sonuc := v_sonuc || jsonb_build_object('consents', 'hata: ' || left(sqlerrm, 120));
  end;

  -- Silinen hesabın e-posta özeti: 5 yıl
  begin
    delete from public.onceki_epostalar where created_at < now() - interval '5 years';
    get diagnostics v_n = row_count;
    v_sonuc := v_sonuc || jsonb_build_object('onceki_epostalar', v_n);
  exception when others then
    v_sonuc := v_sonuc || jsonb_build_object('onceki_epostalar', 'hata: ' || left(sqlerrm, 120));
  end;

  return jsonb_build_object('ok', true, 'silinen', v_sonuc, 'kosuldu', now());
end $ssi345$;
revoke execute on function public.saklama_suresi_imha() from public, anon, authenticated;
grant execute on function public.saklama_suresi_imha() to service_role;

do $cr345$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'll-saklama-imha') then
      perform cron.unschedule('ll-saklama-imha');
    end if;
    perform cron.schedule('ll-saklama-imha', '10 4 * * *', 'select public.saklama_suresi_imha()');
    raise notice '345: pg_cron isi kuruldu — ll-saklama-imha, her gece 04:10.';
  else
    raise notice '345: pg_cron yok — is kurulmadi.';
  end if;
end $cr345$;

-- İlk imha hemen (süresi zaten dolmuş kayıtlar için)
select public.saklama_suresi_imha() as ilk_imha;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'kimlik belgesi gonderimi kapali' as kontrol,
       position('kyc_kapali' in pg_get_functiondef('public.kimlik_belgesi_gonder(text,text)'::regprocedure)) > 0 as tamam
union all
select 'kyc kovasina yazma kurali yok',
       not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
                    and policyname in ('kyc_own_write', 'kyc_own_update'))
union all
select 'tabloda belge yolu kalmadi',
       not exists (select 1 from public.verifications where id_doc_path is not null or id_selfie_path is not null)
union all
select 'id_verified = dogrulanmis profil (herkes)',
       not exists (select 1 from public.verifications v
                    where v.id_verified is distinct from public.profil_dogrulandi_hesapla(v.user_id))
union all
select 'guven puaninda kimlik bileseni kalmadi',
       not exists (select 1 from public.trust_scores where components ? 'id')
union all
select 'kampanya pazarlama iznine bakiyor',
       position('pazarlama_izni' in pg_get_functiondef('public.send_campaign(text,text,jsonb,uuid,uuid[])'::regprocedure)) > 0
union all
select 'kayit onayi pazarlama iznini aciyor',
       position('pazarlama_izni' in pg_get_functiondef('public.grant_consents(text[],text)'::regprocedure)) > 0
union all
select 'anonimlestirme cinsiyeti siliyor',
       position('gender = null' in pg_get_functiondef('public.admin_anonymize_user(uuid,text,text)'::regprocedure)) > 0
union all
select 'saklama isi kurulu',
       not exists (select 1 from pg_namespace where nspname = 'cron')
       or exists (select 1 from cron.job where jobname = 'll-saklama-imha')
union all
select 'BILGI: kyc kovasinda kalan dosya sayisi = '
       || (select count(*) from storage.objects where bucket_id = 'kyc')::text
       || ' (0 degilse Dashboard › Storage › kyc › sil)', true;
