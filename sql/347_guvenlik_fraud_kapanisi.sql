-- ============================================================================
-- 347 · GÜVENLİK / SUİSTİMAL KAPANIŞI   (8 Kasım 2026 · güvenlik denetiminin 21 bulgusu)
--
-- Ölçümler (yerel kurulum 001→346 + SEED, uygulama/BO/site kaynakları):
--   · apply_referral kayıt anında çağrılıyor (App.js: kayıttan hemen sonra ve
--     "ll_kayit_bekliyor" ile ilk açılışta) — o anda telefon HENÜZ doğrulanmamış.
--     Bu yüzden kod reddedilmez: kod kaydedilir, iki tarafın 500 puanı telefon
--     SMS ile doğrulanınca yazılır (tetikleyici). "İlk oturumda yaz" yapılmadı:
--     uygulama metni "Arkadaşın kodunu uyguladığında ikinize de +500" diyor
--     (i18n v7RefNe) ve uygulama metnine dokunulmuyor.
--   · points_ledger referral_joined tekrarı: yerelde 0 → tekil kısmi indeks
--     canlıda da tekrar YOKSA kurulur; varsa fonksiyon içi kontrol + kilit yeter (NOTICE).
--   · credit_ledger plan kredisi biçimi 'plan_monthly:YYYY-MM:<plan>' ve
--     'plan_expire:YYYY-MM' (ay içi yükseltmede farklı plan ekiyle ikinci satır meşru).
--     Tekil kısmi indeks (user_id, reason) yalnız tekrar yoksa kurulur.
--   · availabilities: uygulama BAŞKASININ ilanını doğrudan okuyor
--     (ekranlar_ana.js: id, carrier · id, yalniz_kimlikli) → avail_public_read DARALTILMADI.
--   · messages: uygulama insert'te id, channel_id, from_id, body gönderiyor
--     (cevrimdisi.js idempotans anahtarı id) → kolon hakkı bu dördüne.
--   · profiles.photo_url: tek yazan ortak.js (avatars/<uid>/<rastgele>.jpg + ?t=).
--   · avatars yüklemesi: contentType image/jpeg.
--   · 13 tanı/rapor fonksiyonu: uygulama ve site çağırmıyor; BO sbAdmin() ile
--     (service_role) çağırıyor → istemciden kapatıldı.
--   · waitlist: site tarayıcıdan PostgREST'e yazıyor (WaitlistForm "use client")
--     → x-forwarded-for ziyaretçinin adresi.
--   · e-posta onayı: auth.users UPDATE tetikleyicisi 269'dan beri var
--     (on_auth_email_confirmed → trg_email_onayi_aynala); yalnız yoksa kurulur.
--
-- Gövdeler canlı tanımın üstüne yama (pg_get_functiondef + replace, CRLF normalize);
-- baştan yazılanlar: apply_referral (yalnız 028'de tanımlı), rc_olay_isle (yalnız 332),
-- trg_waitlist_rate (yalnız 194), eposta_ozeti (yalnız 329).
-- Supabase SQL Editor'de tek parça; her ifade ayrı işlemde koşabilir. Tekrar koşulabilir.
-- Doğrulama: son sorguda 21 satır, hepsi tamam = true.
-- ============================================================================

-- ── 0 · yama yardımcısı (dosya sonunda silinir) ─────────────────────────────
-- p_mod: 'sonra' (çapanın arkasına ekle) · 'once' (önüne ekle) · 'degistir'.
-- Çapa boşluk farkına duyarsız aranır (\s+); işaret gövdede varsa dokunulmaz.
create or replace function public.yama_347(p_imza text, p_isaret text, p_capa text, p_ek text, p_mod text default 'sonra')
returns text language plpgsql as $y347$
declare v_def text; v_re text; v_esles text; v_pos int;
begin
  v_def := replace(pg_get_functiondef(p_imza::regprocedure), chr(13), '');
  if position(p_isaret in v_def) > 0 then
    raise notice '347: % zaten yamali (%).', p_imza, p_isaret;
    return 'zaten';
  end if;
  v_re := regexp_replace(replace(p_capa, chr(13), ''), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_re := regexp_replace(v_re, '\s+', '\\s+', 'g');
  v_esles := substring(v_def from v_re);
  if v_esles is null then
    raise exception '347: % govdesinde capa bulunamadi — elle bak: %', p_imza, left(p_capa, 120);
  end if;
  v_pos := position(v_esles in v_def);
  v_def := overlay(v_def placing
             case p_mod when 'once' then p_ek || v_esles
                        when 'degistir' then p_ek
                        else v_esles || p_ek end
           from v_pos for length(v_esles));
  execute v_def;
  return 'yamandi';
end $y347$;
revoke all on function public.yama_347(text, text, text, text, text) from public, anon, authenticated;

-- Telefon SMS ile doğrulanmış mı (345 "doğrulanmış profil" ile aynı ölçüt: bypass sayılmaz)
create or replace function public.telefon_dogrulandi_mi(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $td347$
  select coalesce((select coalesce(v.phone_verified, false)
                      and coalesce(v.phone_verified_method, 'sms') <> 'bypass'
                     from verifications v where v.user_id = p_user), false)
$td347$;
revoke all on function public.telefon_dogrulandi_mi(uuid) from public, anon, authenticated;
grant execute on function public.telefon_dogrulandi_mi(uuid) to service_role;

-- ── 1 · apply_referral ──────────────────────────────────────────────────────
-- Kod kayıtta uygulanır (akış aynı). Ödül: davet edilenin telefonu SMS ile doğrulanınca
-- (şimdi ya da sonra), kişi başına bir kez; davet eden 30 günde en çok 5 ödül alır.
create or replace function public.davet_odulu_yaz(p_uid uuid)
returns jsonb language plpgsql security definer set search_path = public as $do347$
declare v_ref uuid; v_n int; v_davet_eden boolean := false;
begin
  if p_uid is null then return jsonb_build_object('odul', 'yok'); end if;
  perform pg_advisory_xact_lock(hashtextextended('davet:' || p_uid::text, 0));
  select referred_by into v_ref from profiles where user_id = p_uid;
  if v_ref is null then return jsonb_build_object('odul', 'yok'); end if;
  if exists (select 1 from users where id = p_uid and (banned_at is not null or deleted_at is not null)) then
    return jsonb_build_object('odul', 'hesap_kapali');
  end if;
  if not public.telefon_dogrulandi_mi(p_uid) then
    return jsonb_build_object('odul', 'telefon_bekliyor');
  end if;
  if exists (select 1 from points_ledger where user_id = p_uid and reason = 'referral_joined') then
    return jsonb_build_object('odul', 'zaten_verildi');
  end if;

  insert into points_ledger (user_id, delta, reason, ref_id) values (p_uid, 500, 'referral_joined', v_ref);

  -- Davet eden: 30 günde en çok 5 ödül (aynı davet edenin eşzamanlı ödülleri sıraya girer)
  perform pg_advisory_xact_lock(hashtextextended('davet_eden:' || v_ref::text, 0));
  select count(*) into v_n from points_ledger
   where user_id = v_ref and reason = 'referral_invite' and created_at > now() - interval '30 days';
  if v_n < 5 and exists (select 1 from users where id = v_ref and banned_at is null and deleted_at is null) then
    insert into points_ledger (user_id, delta, reason, ref_id) values (v_ref, 500, 'referral_invite', p_uid);
    insert into notifications (user_id, category, title, body, ref_type)
    values (v_ref, 'system', 'Davetin kabul edildi 🎉', 'Arkadaşın katıldı · +500 puan', 'referral');
    v_davet_eden := true;
  end if;
  return jsonb_build_object('odul', 'verildi', 'davet_eden_odulu', v_davet_eden);
end $do347$;
revoke all on function public.davet_odulu_yaz(uuid) from public, anon, authenticated;
grant execute on function public.davet_odulu_yaz(uuid) to service_role;

create or replace function public.apply_referral(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $ar347$
declare v_uid uuid := auth.uid(); v_ref uuid; v_odul jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  -- 347: aynı kişinin eşzamanlı iki çağrısı sıraya girer (çift ödül yarışı)
  perform pg_advisory_xact_lock(hashtextextended('davet:' || v_uid::text, 0));
  perform public.hesap_kapisi(v_uid);
  if exists (select 1 from profiles where user_id = v_uid and referred_by is not null) then
    raise exception 'referral_already_used';
  end if;
  select user_id into v_ref from profiles where upper(referral_code) = upper(btrim(p_code));
  if v_ref is null then raise exception 'invalid_referral_code'; end if;
  if v_ref = v_uid then raise exception 'self_referral_blocked'; end if;
  -- 347: karşılıklı davet yok (A, B'nin koduyla geldiyse B, A'nın kodunu uygulayamaz)
  if exists (select 1 from profiles where user_id = v_ref and referred_by = v_uid) then
    raise exception 'referral_mutual_blocked';
  end if;

  update profiles set referred_by = v_ref where user_id = v_uid;
  insert into invites (host_id, guest_id, status, created_at)
  values (v_ref, v_uid, 'accepted', now()) on conflict do nothing;

  -- 347: puan yalnız telefonu SMS ile doğrulanmış hesaba; değilse doğrulandığı an yazılır.
  v_odul := public.davet_odulu_yaz(v_uid);
  return jsonb_build_object('ok', true, 'odul', v_odul ->> 'odul');
end $ar347$;
revoke all on function public.apply_referral(text) from public, anon;
grant execute on function public.apply_referral(text) to authenticated;

create or replace function public.trg_davet_odulu_telefon()
returns trigger language plpgsql security definer set search_path = public as $tdo347$
begin
  if coalesce(new.phone_verified, false) and coalesce(new.phone_verified_method, 'sms') <> 'bypass'
     and exists (select 1 from profiles where user_id = new.user_id and referred_by is not null) then
    begin
      perform public.davet_odulu_yaz(new.user_id);
    exception when others then
      raise notice '347: davet odulu yazilamadi (%): %', new.user_id, sqlerrm;  -- doğrulama asla bozulmaz
    end;
  end if;
  return null;
end $tdo347$;
revoke all on function public.trg_davet_odulu_telefon() from public, anon, authenticated;

drop trigger if exists davet_odulu_telefon on public.verifications;
create trigger davet_odulu_telefon
  after insert or update of phone_verified, phone_verified_method on public.verifications
  for each row execute function public.trg_davet_odulu_telefon();

do $ri347$
declare v_tekrar int;
begin
  select count(*) into v_tekrar from (
    select user_id from points_ledger where reason = 'referral_joined' group by user_id having count(*) > 1) t;
  if v_tekrar = 0 then
    create unique index if not exists uq_points_referral_joined
      on public.points_ledger (user_id) where reason = 'referral_joined';
  else
    raise notice '347/1: % kullanicida referral_joined tekrari var — indeks kurulmadi; kilit + fonksiyon ici kontrol gecerli.', v_tekrar;
  end if;
end $ri347$;

-- ── 2 · kapida_giremedim: tamamlanmış / iptal / süresi dolmuş oturumda iade yok ──
-- (süresi dolan oturumun kredisi zaten 'expired_refund' ile iade edilmişti)
select public.yama_347('public.kapida_giremedim(uuid,text,text)', '347/2',
$c$if v_uid <> v_req.guest_id then raise exception 'not_guest'; end if;$c$,
$e$
  -- 347/2: buluşma tamamlandıysa ya da oturum kapandıysa kapı iadesi yok
  if v_s.status in ('completed', 'cancelled', 'expired') then
    return jsonb_build_object('ok', false, 'reason', 'oturum_tamamlandi');
  end if;$e$);

select public.yama_347('public.kapida_ret_bildirebilir_mi(uuid)', '347/2',
$c$if v_uid <> v_req.guest_id then return jsonb_build_object('olur', false); end if;$c$,
$e$
  -- 347/2: kapalı oturumda düğme görünmez (sunucu da reddeder)
  if v_s.status in ('completed', 'cancelled', 'expired') then
    return jsonb_build_object('olur', false, 'sebep', 'oturum_tamamlandi');
  end if;$e$);

-- ── 3 · confirm_session: 15 dk dolmadan onay yok · puanda çift halka + günlük tavan ──
create or replace function public.oturum_puani_hakki(p_user uuid, p_host uuid, p_guest uuid)
returns boolean language plpgsql stable security definer set search_path = public as $oph347$
declare
  v_tavan  int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_credit_daily_cap'), 3);
  v_pencere int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_ring_window_days'), 30);
  v_tekrar int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_ring_max_repeat'), 3);
  v_n int;
begin
  -- host_credit_settle ile aynı kural: aynı çift 30 günde en çok 3 tamamlanmış oturum
  select count(*) into v_n from sessions s2 join requests r2 on r2.id = s2.request_id
   where s2.status = 'completed' and s2.completed_at >= now() - make_interval(days => v_pencere)
     and ((r2.host_id = p_host and r2.guest_id = p_guest) or (r2.host_id = p_guest and r2.guest_id = p_host));
  if v_n > v_tekrar then return false; end if;
  -- günlük tavan: bugün en çok v_tavan oturum puanı
  select count(*) into v_n from points_ledger
   where user_id = p_user and reason = 'session_reward' and delta > 0 and created_at >= date_trunc('day', now());
  return v_n < v_tavan;
end $oph347$;
revoke all on function public.oturum_puani_hakki(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.oturum_puani_hakki(uuid, uuid, uuid) to service_role;

select public.yama_347('public.confirm_session(uuid)', '347/3a',
$c$if v_s.status <> 'active' then raise exception 'not_active'; end if;$c$,
$e$
  -- 347/3a: oturum başladıktan sonra en az 15 dakika (beta_settings.oturum_onay_en_erken_dk).
  -- ll.test_mode (176, yalnız işlem içi; PostgREST'ten ayarlanamaz) tohum/tezgah akışlarını muaf tutar.
  if coalesce(current_setting('ll.test_mode', true), '') <> 'on'
     and v_s.started_at is not null and v_s.started_at > now() - make_interval(mins =>
       coalesce((select (value #>> '{}')::int from beta_settings where key = 'oturum_onay_en_erken_dk'), 15)) then
    raise exception 'cok_erken';
  end if;$e$);

select public.yama_347('public.confirm_session(uuid)', '347/3b',
$c$insert into points_ledger (user_id, delta, reason, ref_id)
      values (v_r.host_id, public.plan_agirlama_puani(v_r.host_id), 'session_reward', p_session_id),
             (v_r.guest_id, public.plan_agirlama_puani(v_r.guest_id), 'session_reward', p_session_id);$c$,
$e$-- 347/3b: aynı çift / günlük tavanı aşan oturum tamamlanır ama puan yazılmaz
      insert into points_ledger (user_id, delta, reason, ref_id)
      select x.uid, public.plan_agirlama_puani(x.uid), 'session_reward', p_session_id
        from (values (v_r.host_id), (v_r.guest_id)) as x(uid)
       where public.oturum_puani_hakki(x.uid, v_r.host_id, v_r.guest_id);$e$, 'degistir');

-- ── 4 · start_session_request: ilan başlangıcından en çok 1 saat önce ────────
select public.yama_347('public.start_session_request(uuid)', '347/4',
$c$v_is_host := (v_uid = v_req.host_id);$c$,
$e$-- 347/4: ilan başlangıcından (havalimanı saatiyle) 1 saatten önce başlatılamaz (ll.test_mode muaf)
  if coalesce(current_setting('ll.test_mode', true), '') <> 'on'
     and exists (select 1 from availabilities a
              where a.id = v_req.avail_id
                and public.yerel_an(a.avail_date, a.time_from, a.airport_code) > now() + interval '1 hour')
     and not exists (select 1 from sessions where request_id = p_request_id and status = 'active') then
    raise exception 'session_too_early';
  end if;
  $e$, 'once');

-- ── 5 · plan_hediyesi_degerlendir: 3 FARKLI misafir · hediyeler arası 60 gün ──
select public.yama_347('public.plan_hediyesi_degerlendir(uuid)', 'count(distinct r.guest_id)',
$c$select count(*) into v_agir$c$,
$e$select count(distinct r.guest_id) into v_agir  -- 347/5: aynı kişiyi üç kez ağırlamak sayılmaz$e$, 'degistir');

select public.yama_347('public.plan_hediyesi_degerlendir(uuid)', 'host_free_upgrade_cooldown_days''), 60)',
$c$key='host_free_upgrade_cooldown_days'), 0)$c$,
$e$key='host_free_upgrade_cooldown_days'), 60)$e$, 'degistir');

insert into beta_settings (key, value) values ('host_free_upgrade_cooldown_days', to_jsonb(60))
on conflict (key) do update
   set value = to_jsonb(greatest(60, coalesce((beta_settings.value #>> '{}')::int, 0))), updated_at = now();

-- ── 6 · plan_kredisi_yerlestir: kullanıcı başına kilit · aylık kredi tekil ──
select public.yama_347('public.plan_kredisi_yerlestir(uuid)', '347/6',
$c$if v_uid is null then return jsonb_build_object('ok', false, 'neden', 'oturum_yok'); end if;$c$,
$e$
  -- 347/6: eşzamanlı iki çağrı (webhook + cron + hediye) aynı ayın kredisini iki kez yazamaz
  perform pg_advisory_xact_lock(hashtextextended('kredi:' || v_uid::text, 0));$e$);

do $pk347$
declare v_tekrar int;
begin
  select count(*) into v_tekrar from (
    select user_id, reason from credit_ledger
     where reason like 'plan_monthly:%' or reason like 'plan_expire:%'
     group by user_id, reason having count(*) > 1) t;
  if v_tekrar = 0 then
    create unique index if not exists uq_credit_plan_ayligi
      on public.credit_ledger (user_id, reason)
      where reason like 'plan_monthly:%' or reason like 'plan_expire:%';
  else
    raise notice '347/6: % (kullanici, ay) ciftinde plan kredisi tekrari var — indeks kurulmadi; kilit + exists gecerli. Liste: select user_id, reason, count(*) from credit_ledger where reason like ''plan_monthly:%%'' group by 1,2 having count(*) > 1;', v_tekrar;
  end if;
end $pk347$;

-- ── 7 · abonelik: TRANSFER · SANDBOX · süresi geçen abonelik ────────────────
-- Sandbox satın alması yalnız test hesabına uygulanır: seed/sahne/vitrin/e2e adresleri,
-- test_gorunurlugu listesindekiler ve mağaza inceleme hesabı (Apple incelemesi sandbox'ta alır).
create or replace function public.odeme_test_hesabi(p_uid uuid)
returns boolean language sql stable security definer set search_path = public as $oth347$
  select coalesce((select public.seed_test_hesabi(u.email) or lower(coalesce(u.email, '')) = 'inceleme@loungelink.co'
                     from users u where u.id = p_uid), false)
      or exists (select 1 from test_gorunurlugu g where g.user_id = p_uid)
$oth347$;
revoke all on function public.odeme_test_hesabi(uuid) from public, anon, authenticated;
grant execute on function public.odeme_test_hesabi(uuid) to service_role;

create or replace function public.rc_olay_isle(p_olay jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $rc347$
declare
  e        jsonb := coalesce(p_olay -> 'event', p_olay);
  v_id     text  := e ->> 'id';
  v_tur    text  := upper(coalesce(e ->> 'type', ''));
  v_magaza text  := case upper(coalesce(e ->> 'store', ''))
                      when 'APP_STORE' then 'apple' when 'MAC_APP_STORE' then 'apple'
                      when 'PLAY_STORE' then 'google' else 'diger' end;
  v_sandbox boolean := upper(coalesce(e ->> 'environment', '')) = 'SANDBOX';
  v_urun   text;
  v_islem  text  := coalesce(e ->> 'transaction_id', e ->> 'original_transaction_id');
  v_uid    uuid;
  v_aday   text;
  v_u      iap_urunleri%rowtype;
  v_bitis  timestamptz;
  v_sonuc  text;
  v_r      jsonb;
  v_bal    int;
  v_satis  kredi_satislari%rowtype;
  v_geri   int;
  v_kaynak uuid;
  v_ab     abonelikler%rowtype;
  v_tasi   abonelikler%rowtype;
  v_biten  int := 0;
begin
  -- 🔴 İSTEMCİ BURAYA GELEMEZ: auth.uid() doluysa çağıran bir kullanıcıdır.
  if auth.uid() is not null then raise exception 'not_admin'; end if;
  if coalesce(v_id, '') = '' then raise exception 'olay_kimligi_bos'; end if;

  -- Aynı olay ikinci kez gelirse: hata değil, "zaten işlendi" (RevenueCat yeniden dener).
  if exists (select 1 from rc_olaylari where olay_kimlik = v_id) then
    return jsonb_build_object('ok', true, 'zaten_islendi', true);
  end if;

  -- Ürün: PRODUCT_CHANGE'de yeni ürün `new_product_id`. Google "urun:temelplan" → "urun_temelplan".
  v_urun := replace(coalesce(nullif(e ->> 'new_product_id', ''), e ->> 'product_id', ''), ':', '_');
  select * into v_u from iap_urunleri where urun_kodu = v_urun;

  -- Kullanıcı: uygulama RevenueCat'e Supabase kimliğiyle giriş yapar (Purchases.logIn(uid)).
  -- Anonim kimlikle gelen olayda takma adlar (aliases) taranır.
  -- 347: TRANSFER'de alıcı `transferred_to` dizisindedir.
  for v_aday in
    select x from (
      select jsonb_array_elements_text(case when v_tur = 'TRANSFER'
                                            then coalesce(e -> 'transferred_to', '[]'::jsonb)
                                            else '[]'::jsonb end) as x
      union all select e ->> 'app_user_id'
      union all select e ->> 'original_app_user_id'
      union all select jsonb_array_elements_text(coalesce(e -> 'aliases', '[]'::jsonb))
    ) a where x ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  loop
    select id into v_uid from users where id = v_aday::uuid;
    exit when v_uid is not null;
  end loop;

  if e ? 'expiration_at_ms' and nullif(e ->> 'expiration_at_ms', '') is not null then
    v_bitis := to_timestamp((e ->> 'expiration_at_ms')::numeric / 1000.0);
  end if;

  if v_tur = 'TEST' then
    v_sonuc := 'test';

  -- 347: sandbox (test mağazası) olayı yalnız test hesabına uygulanır
  elsif v_sandbox and (v_uid is null or not public.odeme_test_hesabi(v_uid)) then
    v_sonuc := 'sandbox_yok_sayildi';

  -- ── 347 · TRANSFER: abonelik eski hesaptan alıcıya geçer ────────────────
  -- Eski hesap(lar)ın abonelik kaynaklı planı düşer (hediye plan_grants ayrı kalır).
  elsif v_tur = 'TRANSFER' then
    for v_aday in
      select x from jsonb_array_elements_text(coalesce(e -> 'transferred_from', '[]'::jsonb)) as t(x)
       where x ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    loop
      v_kaynak := v_aday::uuid;
      continue when v_kaynak = v_uid;
      select * into v_ab from abonelikler where user_id = v_kaynak;
      continue when v_ab.user_id is null;
      if v_ab.durum <> 'bitti' and (v_tasi.user_id is null or coalesce(v_ab.bitis, 'infinity') > coalesce(v_tasi.bitis, '-infinity')) then
        v_tasi := v_ab;
      end if;
      update abonelikler set durum = 'bitti', son_olay = 'TRANSFER', guncellendi = now()
       where user_id = v_kaynak and durum <> 'bitti';
      update users set plan = 'yolcu' where id = v_kaynak and plan = v_ab.plan;
      v_biten := v_biten + 1;
    end loop;

    if v_uid is not null and v_tasi.user_id is not null and coalesce(v_tasi.bitis, 'infinity') > now() then
      insert into abonelikler (user_id, plan, urun_kodu, magaza, durum, bitis, son_olay, guncellendi)
      values (v_uid, v_tasi.plan, v_tasi.urun_kodu, v_tasi.magaza, 'aktif', coalesce(v_bitis, v_tasi.bitis), v_tur, now())
      on conflict (user_id) do update
        set plan = excluded.plan, urun_kodu = excluded.urun_kodu, magaza = excluded.magaza,
            durum = 'aktif', bitis = excluded.bitis, son_olay = excluded.son_olay, guncellendi = now();
      update users set plan = v_tasi.plan where id = v_uid;
      perform public.plan_kredisi_yerlestir(v_uid);
      v_sonuc := 'transfer_' || v_tasi.plan::text;
    elsif v_uid is not null and v_u.tur = 'abonelik' and coalesce(v_bitis, '-infinity') > now() then
      -- Eski hesap bizde abonelikli değildi ama olay ürünü ve bitişi taşıyor
      insert into abonelikler (user_id, plan, urun_kodu, magaza, durum, bitis, son_olay, guncellendi)
      values (v_uid, v_u.plan, v_u.urun_kodu, v_magaza, 'aktif', v_bitis, v_tur, now())
      on conflict (user_id) do update
        set plan = excluded.plan, urun_kodu = excluded.urun_kodu, magaza = excluded.magaza,
            durum = 'aktif', bitis = excluded.bitis, son_olay = excluded.son_olay, guncellendi = now();
      update users set plan = v_u.plan where id = v_uid;
      perform public.plan_kredisi_yerlestir(v_uid);
      v_sonuc := 'transfer_' || v_u.plan::text;
    else
      v_sonuc := 'transfer_abonelik_yok_' || v_biten;
    end if;

  elsif v_uid is null then
    v_sonuc := 'kullanici_yok';
  elsif v_u.urun_kodu is null then
    v_sonuc := 'urun_tanimsiz';

  -- ── KREDİ ──────────────────────────────────────────────────────────────
  elsif v_u.tur = 'kredi' and v_tur in ('NON_RENEWING_PURCHASE', 'INITIAL_PURCHASE') then
    if v_magaza = 'diger' then
      v_sonuc := 'magaza_tanimsiz';
    else
      v_r := public.kredi_paketi_isle(v_uid, v_magaza, coalesce(v_islem, v_id), v_u.paket_kod, e);
      v_sonuc := case when coalesce((v_r ->> 'zaten_islendi')::boolean, false) then 'kredi_zaten_islendi'
                      else 'kredi_yuklendi' end;
    end if;

  elsif v_u.tur = 'kredi' and v_tur = 'CANCELLATION' then
    -- Mağaza iadesi: satış 'iade'; verilen kredi en fazla mevcut bakiye kadar geri alınır
    -- (bakiye negatife düşemez — 299/B1 kilidi).
    select * into v_satis from kredi_satislari
     where saglayici = v_magaza and makbuz_kimlik = coalesce(v_islem, v_id) and durum = 'dogrulandi';
    if v_satis.id is null then
      v_sonuc := 'iade_satis_bulunamadi';
    else
      update kredi_satislari set durum = 'iade' where id = v_satis.id;
      select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = v_uid;
      v_geri := least(v_satis.kredi, greatest(v_bal, 0));
      if v_geri > 0 then
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
        values (v_uid, -v_geri, 'kredi_magaza_iadesi', v_satis.id, v_bal - v_geri,
                format('Mağaza iadesi · %s kredi geri alındı', v_geri));
      end if;
      v_sonuc := 'kredi_iade_' || v_geri;
    end if;

  -- ── ABONELİK ───────────────────────────────────────────────────────────
  elsif v_u.tur = 'abonelik' and v_tur in ('INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE', 'UNCANCELLATION') then
    insert into abonelikler (user_id, plan, urun_kodu, magaza, durum, bitis, son_olay, guncellendi)
    values (v_uid, v_u.plan, v_u.urun_kodu, v_magaza, 'aktif', v_bitis, v_tur, now())
    on conflict (user_id) do update
      set plan = excluded.plan, urun_kodu = excluded.urun_kodu, magaza = excluded.magaza,
          durum = 'aktif', bitis = excluded.bitis, son_olay = excluded.son_olay, guncellendi = now();
    update users set plan = v_u.plan where id = v_uid;
    -- Bu ayın plan kredisi hemen (aylık yerleştirme zaten verilmişse farkı verir).
    perform public.plan_kredisi_yerlestir(v_uid);
    v_sonuc := 'plan_' || v_u.plan::text;

  elsif v_u.tur = 'abonelik' and v_tur = 'CANCELLATION' then
    update abonelikler set durum = 'yenileme_kapali', bitis = coalesce(v_bitis, bitis),
                           son_olay = v_tur, guncellendi = now()
     where user_id = v_uid;
    v_sonuc := 'yenileme_kapali';

  elsif v_u.tur = 'abonelik' and v_tur = 'BILLING_ISSUE' then
    update abonelikler set durum = 'odeme_sorunu', son_olay = v_tur, guncellendi = now() where user_id = v_uid;
    v_sonuc := 'odeme_sorunu';

  elsif v_u.tur = 'abonelik' and v_tur = 'EXPIRATION' then
    -- Yalnız SÜRESİ BİTEN ürün hâlâ kayıtlı abonelikse düşür (yükseltme sonrası eski ürünün
    -- bitişi yeni planı düşürmesin).
    if exists (select 1 from abonelikler where user_id = v_uid and urun_kodu = v_u.urun_kodu) then
      update abonelikler set durum = 'bitti', son_olay = v_tur, guncellendi = now() where user_id = v_uid;
      update users set plan = 'yolcu' where id = v_uid;
      v_sonuc := 'plan_bitti';
    else
      v_sonuc := 'eski_urun_bitti';
    end if;

  else
    v_sonuc := 'kayit';
  end if;

  insert into rc_olaylari (olay_kimlik, tur, user_id, urun_kodu, magaza, islem_kimlik, sonuc, ham)
  values (v_id, v_tur, v_uid, nullif(v_urun, ''), v_magaza, v_islem, v_sonuc, p_olay);

  return jsonb_build_object('ok', true, 'sonuc', v_sonuc);
end $rc347$;
revoke all on function public.rc_olay_isle(jsonb) from public, anon, authenticated;
grant execute on function public.rc_olay_isle(jsonb) to service_role;

-- Süresi 3 günden çok geçmiş abonelik: EXPIRATION webhook'u kaçsa da plan düşer.
create or replace function public.abonelik_suresi_dolanlari_kapat()
returns jsonb language plpgsql security definer set search_path = public as $ask347$
declare r record; v_n int := 0;
begin
  for r in
    select a.user_id, a.plan from abonelikler a
     where a.durum in ('aktif', 'yenileme_kapali', 'odeme_sorunu')
       and a.bitis is not null and a.bitis < now() - interval '3 days'
     for update
  loop
    update abonelikler set durum = 'bitti', son_olay = 'SURE_DOLDU', guncellendi = now() where user_id = r.user_id;
    -- Yalnız abonelikten gelen plan düşer; elle verilmiş başka bir plan (BO) ezilmez.
    update users set plan = 'yolcu' where id = r.user_id and plan = r.plan;
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'kapanan', v_n, 'kosuldu', now());
end $ask347$;
revoke all on function public.abonelik_suresi_dolanlari_kapat() from public, anon, authenticated;
grant execute on function public.abonelik_suresi_dolanlari_kapat() to service_role;

do $cr347$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'll-abonelik-bitis') then
      perform cron.unschedule('ll-abonelik-bitis');
    end if;
    perform cron.schedule('ll-abonelik-bitis', '20 4 * * *', 'select public.abonelik_suresi_dolanlari_kapat()');
    raise notice '347: pg_cron isi kuruldu — ll-abonelik-bitis, her gece 04:20.';
  else
    raise notice '347: pg_cron yok — is kurulmadi.';
  end if;
end $cr347$;

select public.abonelik_suresi_dolanlari_kapat() as ilk_kapanis;

-- etkin plan da aynı kuralı hemen uygular (cron koşmadan önce)
select public.yama_347('public.etkin_plan_ic(uuid)', '347/7',
$c$select coalesce(u.plan::text,'yolcu') into v_satin from users u where u.id = p_user;$c$,
$e$
  -- 347/7: bitişi 3 günden çok geçmiş abonelik satın alınmış plan sayılmaz
  if exists (select 1 from abonelikler a where a.user_id = p_user and a.plan::text = v_satin
              and a.durum <> 'bitti' and a.bitis is not null and a.bitis < now() - interval '3 days') then
    v_satin := 'yolcu';
  end if;$e$);

select public.yama_347('public.etkin_plan(uuid)', '347/7',
$c$select coalesce(u.plan::text,'yolcu') into v_satin from users u where u.id = v_uid;$c$,
$e$
  -- 347/7: bitişi 3 günden çok geçmiş abonelik satın alınmış plan sayılmaz
  if exists (select 1 from abonelikler a where a.user_id = v_uid and a.plan::text = v_satin
              and a.durum <> 'bitti' and a.bitis is not null and a.bitis < now() - interval '3 days') then
    v_satin := 'yolcu';
  end if;$e$);

-- ── 8 · handle_new_user: ekip bayrakları app_metadata'dan · e-posta onayı gerçek ──
-- raw_user_meta_data kullanıcının kendi yazabildiği alan (signUp options.data);
-- raw_app_meta_data yalnız sunucu (BO createUser app_metadata) yazar.
select public.yama_347('public.handle_new_user()', $i$raw_app_meta_data->>'is_staff'$i$,
$c$(new.raw_user_meta_data->>'is_staff')::boolean$c$,
$e$(new.raw_app_meta_data->>'is_staff')::boolean$e$, 'degistir');

select public.yama_347('public.handle_new_user()', $i$raw_app_meta_data->>'is_partner'$i$,
$c$(new.raw_user_meta_data->>'is_partner')::boolean$c$,
$e$(new.raw_app_meta_data->>'is_partner')::boolean$e$, 'degistir');

-- "Confirm email" kapalıysa email_confirmed_at kayıtta dolar; açıksa onayda dolar ve
-- 269'un on_auth_email_confirmed tetikleyicisi verifications.email_verified'ı açar.
-- Test hesapları (seed_test_hesabi) doğrulanmış sayılır: SEED'ler auth.users'a onay tarihi yazmıyor.
select public.yama_347('public.handle_new_user()', '347/8',
$c$values (new.id, true, now()) on conflict (user_id) do nothing;$c$,
$e$values (new.id,
          new.email_confirmed_at is not null or public.seed_test_hesabi(new.email),   -- 347/8
          case when new.email_confirmed_at is not null or public.seed_test_hesabi(new.email)
               then coalesce(new.email_confirmed_at, now()) end)
  on conflict (user_id) do nothing;$e$, 'degistir');

create or replace function public.trg_email_onayi_aynala()
returns trigger language plpgsql security definer set search_path = public as $eoa347$
begin
  if NEW.email_confirmed_at is not null
     and (OLD.email_confirmed_at is null) then
    insert into verifications (user_id, email_verified, email_verified_at)
    values (NEW.id, true, NEW.email_confirmed_at)
    on conflict (user_id) do update
      set email_verified = true,
          email_verified_at = coalesce(verifications.email_verified_at, excluded.email_verified_at);
    -- Puan ANINDA güncellensin: kullanıcı onay bağlantısına tıklayıp
    -- uygulamaya döndüğünde puanı çoktan artmış olmalı.
    perform public.recompute_trust(NEW.id);
  end if;
  return NEW;
end $eoa347$;
revoke all on function public.trg_email_onayi_aynala() from public, anon, authenticated;

do $et347$
begin
  if not exists (select 1 from pg_trigger where tgname = 'on_auth_email_confirmed'
                    and tgrelid = 'auth.users'::regclass) then
    create trigger on_auth_email_confirmed
      after update of email_confirmed_at on auth.users
      for each row execute function public.trg_email_onayi_aynala();
    raise notice '347/8: on_auth_email_confirmed kuruldu.';
  end if;
end $et347$;

-- ── 9 · redeem_reward: hesap kapısı · telefon · 30 günde en çok 3 talep ─────
select public.yama_347('public.redeem_reward(uuid,integer)', '347/9',
$c$perform pg_advisory_xact_lock(hashtextextended('puan:' || v_uid::text, 0));$c$,
$e$
  -- 347/9: yasaklı/silinmiş hesap yok · telefon SMS ile doğrulanmış · 30 günde en çok 3 talep
  perform public.hesap_kapisi(v_uid);
  if not public.telefon_dogrulandi_mi(v_uid) then raise exception 'phone_not_verified'; end if;
  if (select count(*) from redemptions
       where user_id = v_uid and created_at > now() - interval '30 days'
         and coalesce(durum, '') <> 'iptal') >= 3 then
    raise exception 'odul_talep_siniri';
  end if;$e$);

-- ── 10 · profiles.photo_url: yalnız kendi avatars klasörü ───────────────────
create or replace function public.avatar_adres_oneki()
returns text language sql stable security definer set search_path = public as $aao347$
  select rtrim(coalesce((select nullif(value #>> '{}', '') from beta_settings where key = 'supabase_url'),
                        'https://wgprynisnriyblccxuhq.supabase.co'), '/')
         || '/storage/v1/object/public/avatars/'
$aao347$;
revoke all on function public.avatar_adres_oneki() from public, anon, authenticated;
grant execute on function public.avatar_adres_oneki() to service_role;

create or replace function public.trg_profil_foto_adresi()
returns trigger language plpgsql security definer set search_path = public as $tpf347$
declare v_rol text;
begin
  -- Yalnız istemcinin (uygulama JWT'si) doğrudan yazdığı değer denetlenir; SQL Editor,
  -- service_role (BO) ve SEED'ler serbest. Değişmeyen eski değer engellenmez.
  begin
    v_rol := nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role';
  exception when others then v_rol := null;
  end;
  if coalesce(v_rol, '') not in ('authenticated', 'anon') then return new; end if;
  if new.photo_url is null then return new; end if;
  if tg_op = 'UPDATE' and new.photo_url is not distinct from old.photo_url then return new; end if;
  if left(new.photo_url, length(public.avatar_adres_oneki() || new.user_id::text || '/'))
     <> public.avatar_adres_oneki() || new.user_id::text || '/' then
    raise exception 'photo_url_gecersiz';
  end if;
  return new;
end $tpf347$;
revoke all on function public.trg_profil_foto_adresi() from public, anon, authenticated;

drop trigger if exists profil_foto_adresi on public.profiles;
create trigger profil_foto_adresi
  before insert or update of photo_url on public.profiles
  for each row execute function public.trg_profil_foto_adresi();

-- ── 11 · availabilities: avail_public_read DARALTILMADI (uygulama başkasının ilanını okuyor) ──
--   ekranlar_ana.js:415  select("id, carrier").in("id", ids)              (keşif listesi)
--   ekranlar_ana.js:424  select("id").in("id", ids).eq("yalniz_kimlikli", true)
--   (kendi ilanları: App.js:3824, screens.js:589/1502/1944, ekranlar_yalin.js:4074 → host_id = uid)

-- ── 12 · avatars kovası: 5 MB · jpeg/png/webp/heic ──────────────────────────
do $av347$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'storage' and table_name = 'buckets' and column_name = 'allowed_mime_types') then
    execute $u$update storage.buckets
                 set file_size_limit = 5242880,
                     allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic']
               where id = 'avatars'$u$;
  else
    raise notice '347/12: storage.buckets kovasi sinir kolonlari yok (yerel taklit) — atlandi.';
  end if;
end $av347$;

-- ── 13 · ağır tanı / rapor fonksiyonları yalnız service_role ────────────────
do $tf347$
declare r record; v_n int := 0;
begin
  for r in
    select format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)) as imza
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = any (array['rule_matrix_test','rule_venue_test','rule_coverage_audit',
             'rule_contamination_check','rule_matrix_check','determinism_check','multi_entitlement_check',
             'tier_promise_check','coverage_summary','visit_flight_coverage','blok_kapsam_denetimi',
             'rpc_surface_violations','waitlist_summary'])
  loop
    execute 'revoke execute on function ' || r.imza || ' from public, anon, authenticated';
    execute 'grant execute on function ' || r.imza || ' to service_role';
    v_n := v_n + 1;
  end loop;
  raise notice '347/13: % tani fonksiyonu istemciden kapatildi.', v_n;
end $tf347$;

-- ── 14 · log_client_error: 4000 bayttan büyük bağlam tutulmaz ───────────────
select public.yama_347('public.log_client_error(text,text,text,text,text,jsonb)', '347/14',
$c$p_context);$c$,
$e$case when octet_length(coalesce(p_context::text, '')) > 4000 then null else p_context end);  -- 347/14$e$, 'degistir');

-- ── 15 · save_push_token: en çok 200 karakter · kullanıcı başına 10 cihaz ────
select public.yama_347('public.save_push_token(text,text)', '347/15a',
$c$if coalesce(p_token,'') not like 'ExponentPushToken%' then$c$,
$e$-- 347/15a: aşırı uzun token kabul edilmez
  if length(coalesce(p_token, '')) > 200 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_token_format');
  end if;
  $e$, 'once');

select public.yama_347('public.save_push_token(text,text)', '347/15b',
$c$return jsonb_build_object('ok', true);$c$,
$e$-- 347/15b: kullanıcı başına en yeni 10 token kalır
  delete from push_tokens pt
   where pt.user_id = v_uid
     and pt.token in (select x.token from push_tokens x where x.user_id = v_uid
                       order by x.updated_at desc nulls last offset 10);
  $e$, 'once');

-- ── 16 · messages: insert yalnız uygulamanın gönderdiği kolonlara · gövde ≤ 2000 ──
revoke insert on public.messages from anon, authenticated;
grant insert (id, channel_id, from_id, body) on public.messages to authenticated;

do $mk347$
begin
  if not exists (select 1 from pg_constraint where conname = 'mesaj_cok_uzun'
                    and conrelid = 'public.messages'::regclass) then
    if exists (select 1 from public.messages where char_length(body) > 2000) then
      alter table public.messages add constraint mesaj_cok_uzun check (char_length(body) <= 2000) not valid;
      raise notice '347/16: 2000 karakteri asan eski mesaj var — kisit NOT VALID eklendi (yeni mesajlara uygulanir).';
    else
      alter table public.messages add constraint mesaj_cok_uzun check (char_length(body) <= 2000);
    end if;
  end if;
end $mk347$;

-- ── 17 · misafir_hakki_hediye_et: kredi kilidi başta ────────────────────────
select public.yama_347('public.misafir_hakki_hediye_et(uuid,integer,text)', '347/17',
$c$if v_uid is null then raise exception 'not_authenticated'; end if;$c$,
$e$
  -- 347/17: aynı kişinin eşzamanlı iki hediyesi bakiyeyi iki kez okuyamaz
  perform pg_advisory_xact_lock(hashtextextended('kredi:' || v_uid::text, 0));$e$);

-- ── 18 · e-posta özeti: Gmail noktaları ve +etiket aynı kişi ────────────────
create or replace function public.eposta_normal(p_email text)
returns text language sql immutable set search_path to 'public' as $en347$
  select case when split_part(e, '@', 2) in ('gmail.com', 'googlemail.com') and position('@' in e) > 1
              then replace(split_part(split_part(e, '@', 1), '+', 1), '.', '') || '@gmail.com'
              else e end
    from (select lower(trim(coalesce(p_email, ''))) as e) x
$en347$;
revoke all on function public.eposta_normal(text) from public, anon, authenticated;

-- 329'un özeti (eski kayıtlarla eşleşmek için korunur)
create or replace function public.eposta_ozeti_eski(p_email text)
returns text language sql immutable set search_path to 'public', 'extensions' as $eoe347$
  select encode(extensions.digest(lower(trim(coalesce(p_email, ''))), 'sha256'), 'hex');
$eoe347$;
revoke all on function public.eposta_ozeti_eski(text) from public, anon, authenticated;

create or replace function public.eposta_ozeti(p_email text)
returns text language sql immutable set search_path to 'public', 'extensions' as $eo347$
  -- 347: Gmail'de a.b+x@gmail.com = ab@gmail.com (sil-kaydol ile yasak / kredi aşılamaz)
  select encode(extensions.digest(public.eposta_normal(p_email), 'sha256'), 'hex');
$eo347$;
revoke all on function public.eposta_ozeti(text) from public, anon, authenticated;

select public.yama_347('public.handle_new_user()', 'eposta_ozeti_eski',
$c$where ozet = public.eposta_ozeti(new.email);$c$,
$e$where ozet in (public.eposta_ozeti(new.email), public.eposta_ozeti_eski(new.email))   -- 347/18
   order by yasakli desc limit 1;$e$, 'degistir');

-- ── 19 · send_otp: yalnız Türkiye cep numarası ──────────────────────────────
select public.yama_347('public.send_otp(text)', '347/19',
$c$if p_phone !~ '^\+[1-9][0-9]{9,14}$' then raise exception 'bad_phone_format'; end if;$c$,
$e$if coalesce(p_phone, '') !~ '^\+905[0-9]{9}$' then raise exception 'bad_phone_format'; end if;  -- 347/19$e$, 'degistir');

-- ── 20 · hesap silme formu hız sınırı (BO /hesap-sil · request_account_deletion) ──
create or replace function public.trg_silme_talebi_hiz()
returns trigger language plpgsql security definer set search_path = public as $sth347$
begin
  -- Uygulama içi "Hesabı sil" (source = 'app') sınırlanmaz.
  if coalesce(new.source, 'web') <> 'web' then return new; end if;
  if (select count(*) from deletion_requests
       where lower(email) = lower(new.email) and created_at > now() - interval '24 hours') >= 3 then
    raise exception 'rate_limited_deletion' using hint = 'Bu e-posta için 24 saatte en çok 3 talep.';
  end if;
  if (select count(*) from deletion_requests
       where coalesce(source, 'web') = 'web' and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'rate_limited_deletion' using hint = 'Dakikada 30 talep sınırı.';
  end if;
  return new;
end $sth347$;
revoke all on function public.trg_silme_talebi_hiz() from public, anon, authenticated;

drop trigger if exists silme_talebi_hiz on public.deletion_requests;
create trigger silme_talebi_hiz before insert on public.deletion_requests
  for each row execute function public.trg_silme_talebi_hiz();

-- ── 21 · waitlist: IP başına dakikada 3 · genel tavan 200 ───────────────────
-- IP'nin kendisi değil md5 özeti tutulur (yalnız hız sınırı için).
alter table public.waitlist add column if not exists ip_ozeti text;
create index if not exists ix_waitlist_ip on public.waitlist (ip_ozeti, created_at desc) where ip_ozeti is not null;

create or replace function public.trg_waitlist_rate()
returns trigger language plpgsql security definer set search_path = public as $wr347$
declare v_n int; v_ip text;
begin
  -- 347: ziyaretçi adresi PostgREST başlığından (ilk adres = istemci); istemci yazdığı değeri ezer.
  begin
    v_ip := btrim(split_part(nullif(current_setting('request.headers', true), '')::json ->> 'x-forwarded-for', ',', 1));
  exception when others then v_ip := null;
  end;
  new.ip_ozeti := case when coalesce(v_ip, '') <> '' then md5('ll-waitlist:' || v_ip) end;

  if new.ip_ozeti is not null then
    select count(*) into v_n from waitlist
     where ip_ozeti = new.ip_ozeti and created_at > now() - interval '1 minute';
    if v_n >= 3 then
      raise exception 'rate_limited_waitlist'
        using hint = 'Bu bağlantıdan çok sık kayıt geldi. Bir dakika sonra tekrar dene.';
    end if;
  end if;

  select count(*) into v_n from waitlist
   where created_at > now() - interval '1 minute';
  if v_n >= 200 then
    raise exception 'rate_limited_waitlist'
      using hint = 'Şu an çok fazla kayıt geliyor. Bir dakika sonra tekrar dene.';
  end if;
  return new;
end $wr347$;
revoke all on function public.trg_waitlist_rate() from public, anon, authenticated;

drop trigger if exists trg_waitlist_rate on public.waitlist;
create trigger trg_waitlist_rate before insert on public.waitlist
  for each row execute function public.trg_waitlist_rate();

-- yardımcı silinir
drop function if exists public.yama_347(text, text, text, text, text);

-- ── DOĞRULAMA (21 satır, hepsi tamam = true) ────────────────────────────────
select '01 apply_referral: kilit + hesap kapisi + karsilikli yasak + telefon + 30 gunde 5'
       || case when to_regclass('public.uq_points_referral_joined') is null
               then ' (BILGI: referral_joined tekrari var, indeks yok — fonksiyon ici kontrol)' else ' + tekil indeks' end as kontrol,
       position('pg_advisory_xact_lock' in pg_get_functiondef('public.apply_referral(text)'::regprocedure)) > 0
   and position('hesap_kapisi' in pg_get_functiondef('public.apply_referral(text)'::regprocedure)) > 0
   and position('referral_mutual_blocked' in pg_get_functiondef('public.apply_referral(text)'::regprocedure)) > 0
   and position('telefon_dogrulandi_mi' in pg_get_functiondef('public.davet_odulu_yaz(uuid)'::regprocedure)) > 0
   and position('v_n < 5' in pg_get_functiondef('public.davet_odulu_yaz(uuid)'::regprocedure)) > 0
   and exists (select 1 from pg_trigger where tgname = 'davet_odulu_telefon') as tamam
union all
select '02 kapida_giremedim: kapali oturumda iade yok',
       position('oturum_tamamlandi' in pg_get_functiondef('public.kapida_giremedim(uuid,text,text)'::regprocedure)) > 0
   and position('oturum_tamamlandi' in pg_get_functiondef('public.kapida_ret_bildirebilir_mi(uuid)'::regprocedure)) > 0
union all
select '03 confirm_session: 15 dk + puanda cift halka / gunluk tavan',
       position('cok_erken' in pg_get_functiondef('public.confirm_session(uuid)'::regprocedure)) > 0
   and position('oturum_puani_hakki' in pg_get_functiondef('public.confirm_session(uuid)'::regprocedure)) > 0
union all
select '04 start_session_request: 1 saatten erken yok, 342 ust siniri duruyor',
       position('session_too_early' in pg_get_functiondef('public.start_session_request(uuid)'::regprocedure)) > 0
   and position('session_window_closed' in pg_get_functiondef('public.start_session_request(uuid)'::regprocedure)) > 0
union all
select '05 plan hediyesi: farkli misafir + 60 gun bekleme',
       position('count(distinct r.guest_id)' in pg_get_functiondef('public.plan_hediyesi_degerlendir(uuid)'::regprocedure)) > 0
   and coalesce((select (value #>> '{}')::int from beta_settings where key = 'host_free_upgrade_cooldown_days'), 0) >= 60
union all
select '06 plan_kredisi_yerlestir: kilit'
       || case when to_regclass('public.uq_credit_plan_ayligi') is null
               then ' (BILGI: plan kredisi tekrari var, indeks yok — kilit + exists)' else ' + tekil indeks' end,
       position('pg_advisory_xact_lock' in pg_get_functiondef('public.plan_kredisi_yerlestir(uuid)'::regprocedure)) > 0
union all
select '07 abonelik: TRANSFER + SANDBOX + suresi gecen kapanir',
       position('transferred_from' in pg_get_functiondef('public.rc_olay_isle(jsonb)'::regprocedure)) > 0
   and position('sandbox_yok_sayildi' in pg_get_functiondef('public.rc_olay_isle(jsonb)'::regprocedure)) > 0
   and position('347/7' in pg_get_functiondef('public.etkin_plan_ic(uuid)'::regprocedure)) > 0
   and public.cron_isi_var('ll-abonelik-bitis')
   and not exists (select 1 from abonelikler where durum <> 'bitti' and bitis < now() - interval '3 days')
union all
select '08 handle_new_user: bayraklar app_metadata, email_verified onaya bagli',
       position('raw_user_meta_data->>''is_staff''' in pg_get_functiondef('public.handle_new_user()'::regprocedure)) = 0
   and position('raw_app_meta_data->>''is_staff''' in pg_get_functiondef('public.handle_new_user()'::regprocedure)) > 0
   and position('email_confirmed_at is not null' in pg_get_functiondef('public.handle_new_user()'::regprocedure)) > 0
   and exists (select 1 from pg_trigger where tgname = 'on_auth_email_confirmed' and tgrelid = 'auth.users'::regclass)
union all
select '09 redeem_reward: hesap kapisi + telefon + 30 gunde 3',
       position('odul_talep_siniri' in pg_get_functiondef('public.redeem_reward(uuid,integer)'::regprocedure)) > 0
   and position('hesap_kapisi' in pg_get_functiondef('public.redeem_reward(uuid,integer)'::regprocedure)) > 0
union all
select '10 photo_url yalniz kendi avatars klasoru (BILGI: kurala uymayan mevcut deger = '
       || (select count(*) from profiles p where p.photo_url is not null
             and left(p.photo_url, length(public.avatar_adres_oneki() || p.user_id::text || '/'))
                 <> public.avatar_adres_oneki() || p.user_id::text || '/')::text || ', dokunulmadi)',
       exists (select 1 from pg_trigger where tgname = 'profil_foto_adresi' and tgrelid = 'public.profiles'::regclass)
union all
select '11 availabilities: uygulama dogrudan okuyor, avail_public_read korunuyor',
       exists (select 1 from pg_policies where tablename = 'availabilities' and policyname = 'avail_public_read')
union all
select '12 avatars kovasi 5 MB + 4 resim turu',
       case when exists (select 1 from information_schema.columns
                          where table_schema = 'storage' and table_name = 'buckets' and column_name = 'allowed_mime_types')
            then not exists (select 1 from storage.buckets where id = 'avatars')
                 or coalesce((select (to_jsonb(b) ->> 'file_size_limit')::bigint from storage.buckets b where b.id = 'avatars'), 0) = 5242880
            else true end
union all
select '13 tani fonksiyonlari istemciye kapali',
       not exists (select 1 from pg_proc p
                    where p.pronamespace = 'public'::regnamespace
                      and p.proname = any (array['rule_matrix_test','rule_venue_test','rule_coverage_audit',
                            'rule_contamination_check','rule_matrix_check','determinism_check','multi_entitlement_check',
                            'tier_promise_check','coverage_summary','visit_flight_coverage','blok_kapsam_denetimi',
                            'rpc_surface_violations','waitlist_summary'])
                      and (has_function_privilege('authenticated', p.oid, 'EXECUTE')
                           or has_function_privilege('anon', p.oid, 'EXECUTE')))
union all
select '14 log_client_error baglam 4000 bayt',
       position('347/14' in pg_get_functiondef('public.log_client_error(text,text,text,text,text,jsonb)'::regprocedure)) > 0
union all
select '15 save_push_token 200 karakter + 10 cihaz',
       position('347/15a' in pg_get_functiondef('public.save_push_token(text,text)'::regprocedure)) > 0
   and position('347/15b' in pg_get_functiondef('public.save_push_token(text,text)'::regprocedure)) > 0
union all
select '16 messages: insert yalniz 4 kolon + govde 2000',
       not has_table_privilege('authenticated', 'public.messages', 'INSERT')
   and has_column_privilege('authenticated', 'public.messages', 'body', 'INSERT')
   and has_column_privilege('authenticated', 'public.messages', 'id', 'INSERT')
   and not has_column_privilege('authenticated', 'public.messages', 'flagged', 'INSERT')
   and exists (select 1 from pg_constraint where conname = 'mesaj_cok_uzun')
union all
select '17 misafir_hakki_hediye_et kredi kilidi',
       position('347/17' in pg_get_functiondef('public.misafir_hakki_hediye_et(uuid,integer,text)'::regprocedure)) > 0
union all
select '18 gmail ozeti normal + eski ozet de araniyor',
       public.eposta_ozeti('A.Li+x@GoogleMail.com') = public.eposta_ozeti('ali@gmail.com')
   and public.eposta_ozeti('a.li@ornek.com') = public.eposta_ozeti_eski('a.li@ornek.com')
   and position('eposta_ozeti_eski' in pg_get_functiondef('public.handle_new_user()'::regprocedure)) > 0
union all
select '19 send_otp yalniz +905',
       position('+905' in pg_get_functiondef('public.send_otp(text)'::regprocedure)) > 0
union all
select '20 hesap silme formu hiz siniri',
       exists (select 1 from pg_trigger where tgname = 'silme_talebi_hiz' and tgrelid = 'public.deletion_requests'::regclass)
union all
select '21 waitlist IP basina 3 / genel 200',
       position('ip_ozeti' in pg_get_functiondef('public.trg_waitlist_rate()'::regprocedure)) > 0
   and position('>= 200' in pg_get_functiondef('public.trg_waitlist_rate()'::regprocedure)) > 0;
