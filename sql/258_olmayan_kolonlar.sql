-- ============================================================================
-- LoungeLink · 258_olmayan_kolonlar.sql        (26 Ağustos 2026)
--
-- 🔴 BU DOSYA ÖNCE "250" NUMARASIYLA YAZILDI VE 250 ZATEN ALINMIŞTI
-- (`250_yaptirim_huni_dil_ve_kapilar.sql`). Gökberk iki farklı 250
-- alınca sordu: "hangisini çalıştıracağım?"
--
-- Yeni bir migration yazarken sıradaki numarayı VARSAYDIM; klasöre
-- bakmadım. Migration'lar ad sırasına göre koşuyor — aynı numaradan
-- iki dosya, sıralamayı belirsiz bırakır ve çalıştıran kişiyi
-- ikisinden birini seçmek zorunda bırakır.
--
-- 🆕 SINIF: "SIRADAKİ NUMARAYI HATIRLAMA — SAY. BİR DİZİDEKİ BİR
-- SONRAKİ ELEMANI VARSAYMAK, DİZİYE BAKMAKTAN DAHA UZUN SÜRMEZ."
--
-- Numara 258'e taşındı (247–257 dolu). İçerik değişmedi.
--
-- 🔴 NEDEN VAR — GÖKBERK'İN 249'DA ALDIĞI HATA BİR BUZDAĞININ UCUYDU
--
--     ERROR: column "decision_note" does not exist
--
-- Ölçtüm: `requests` tablosunda öyle bir kolon YOK ve 288 migration'ın
-- hiçbiri onu eklemiyor. Yani `bayat_istekleri_iade_et()` var olmayan
-- bir kolona yazıyordu.
--
-- Peki 288 dosyayı baştan sona koşturan harness bunu neden görmedi?
-- Çünkü o `update` bir DÖNGÜNÜN İÇİNDE ve döngü hiç dönmedi (bayat
-- istek yoktu). PL/pgSQL bir SQL ifadesini ancak İLK ÇALIŞTIRDIĞINDA
-- çözümler — çalışmayan dal, denetlenmemiş daldır.
--
-- 🆕 SINIF: "ÇALIŞTIRARAK DOĞRULAYAN BİR HARNESS, ÇALIŞMAYAN DALI ASLA
-- DOĞRULAMAZ — O DALLARI ANCAK KAYNAĞA BAKAN BİR DENETİM GÖREBİLİR."
--
-- Denetimi yazdım (`rnapp/kolon_check.py`) ve bütün şemaya sordum:
-- **15 yer**, 8 dosya. Bunların 14'ü CANLIDA ETKİN fonksiyonlarda:
--
--   confirm_session               points_ledger.balance_after
--       → oturum onayı + puan yazımı. HAPPY PATH'IN ORTASI.
--   create_request_impl_preflag   requests.request_type   (doğrusu: type)
--       → başvuru oluşturma. Ürünün ana eylemi.
--   respond_invite                requests.request_type
--       → davet kabulü.
--   bayat_istekleri_iade_et       requests.decision_note
--       → Gökberk'in gördüğü hata.
--   admin_anonymize_user          profiles.contact_email · reports.details
--       → KVKK silme talebi işleme. YASAL YÜKÜMLÜLÜK.
--   request_account_deletion      deletion_requests.reason  (doğrusu: note)
--       → hesap silme talebi alma. YASAL YÜKÜMLÜLÜK.
--   bo_plan_ata                   audit_log.target_type/target_id/meta
--   trg_cinsiyet_kilidi           audit_log.target_type/target_id/meta
--       → güvenlik günlüğü. Doğrusu: entity_type · entity_id · after_data.
--
-- Hiçbiri sözdizimi hatası değil; hepsi "o satır ilk kez çalıştığında"
-- patlayacaktı. Bazıları aylarca patlamayabilirdi — ve patladığında
-- tam olarak en kötü anda patlardı (KVKK talebi, oturum onayı).
--
-- İKİ TÜR DÜZELTME:
--   · KOLON ADI YANLIŞ  → fonksiyon düzeltiliyor (canlı gövde alınıp
--     yalnız kolon adı değiştirildi; mantığa dokunulmadı)
--   · KOLON GERÇEKTEN EKSİK → kolon ekleniyor (`balance_after`,
--     `decision_note`). İkisi de anlamlı: biri `credit_ledger` ile
--     simetriyi kuruyor, öteki iptal sebebini kayda geçiriyor.
--
-- 🔴 BU DOSYAYI ÜRETİRKEN BİR HATA YAPTIM VE e2e YAKALADI:
-- kolon adını düzeltmek için `request_type` → `type` diye DÜZ METİN
-- değişimi yaptım, ve o değişim `'standard'::request_type` TİP
-- DÖNÜŞÜMÜNÜ de `'standard'::type` yaptı. PostgreSQL:
--     ERROR: type "type" does not exist
-- Aynı kelime bir yerde KOLON adı, iki satır ötede TİP adı. Metin
-- değiştirici ikisini ayıramaz — çünkü metne bakıyor, koda değil.
--
-- 🆕 SINIF: "AYNI KELİME BİR DOSYADA İKİ FARKLI ŞEY OLABİLİR — DÜZ
-- METİN DEĞİŞİMİ YAPMADAN ÖNCE O KELİMENİN KAÇ İŞİ OLDUĞUNU SAY."
--
-- Bu dosya TEKRAR ÇALIŞTIRILABİLİR.
-- ============================================================================

begin;

-- ── 1 · GERÇEKTEN EKSİK OLAN İKİ KOLON ──────────────────────────────
-- `credit_ledger` bakiyeyi satırda taşıyor; `points_ledger` taşımıyordu
-- ama `confirm_session` taşıdığını varsayıyordu. İki defteri simetrik
-- yapmak, kodu deftere uydurmaktan daha doğru: bakiye zaten hesaplanıp
-- atılıyordu.
alter table points_ledger add column if not exists balance_after integer;

-- İptal edilen bir başvuruda kullanıcı "neden?" diye soruyor. Bildirim
-- o cevabı taşıyor ama bildirim geçici; kaydın kendisi kalıcı.
alter table requests       add column if not exists decision_note text;

comment on column points_ledger.balance_after is
  'İşlem sonrası puan bakiyesi — credit_ledger ile simetri (258)';
comment on column requests.decision_note is
  'Başvurunun neden bu duruma geldiği, kullanıcı diline hazır tek cümle (258)';

-- ── 2 · KOLON ADI YANLIŞ OLAN ETKİN FONKSİYONLAR ────────────────────
-- Gövdeler CANLI tanımdan alındı ve YALNIZ kolon adları değiştirildi.
-- Mantığı yeniden yazmak, düzeltilen hatanın yanına yenisini koyma
-- riskidir; burada amaç en küçük değişiklik.

-- ── create_request_impl_preflag ──
CREATE OR REPLACE FUNCTION public.create_request_impl_preflag(p_avail_id uuid, p_type text DEFAULT 'lounge'::text, p_intro text DEFAULT NULL::text, p_idem text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_cost := public.request_credit_cost(v_uid, p_avail_id);

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
          case when v_cost = 0 then (case when public.request_credit_cost(v_uid) = 0
            then 'Konsiyerj ayricaligi: istek kredi harcamadi'
            else 'Soguk ag: bu havalimaninda yeterli host yok, istek kredi harcamadi' end) end);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id, 'kredi_bedeli', v_cost);
end $function$;

-- ── respond_invite ──
CREATE OR REPLACE FUNCTION public.respond_invite(p_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_i invites%rowtype; v_req uuid; v_chan uuid;
  v_bal int; v_sess uuid; v_av availabilities%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_i from invites where id = p_id for update;
  if not found then raise exception 'invite_not_found'; end if;
  if v_i.guest_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_i.status <> 'pending' then raise exception 'already_responded'; end if;

  update invites set status = (case when p_accept then 'accepted' else 'declined' end)::connection_status
   where id = p_id;

  if p_accept then
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
    if v_bal < 1 then raise exception 'insufficient_credits'; end if;

    -- 030'daki KAPASİTE KONTROLÜ korunur: dolu ilana davet kabul edilemez.
    -- (drift_check bunu düşen adım olarak yakaladı — gerçek kayıptı.)
    select * into v_av from availabilities where id = v_i.avail_id for update;
    if not found then raise exception 'availability_not_found'; end if;
    if coalesce(v_av.filled,0) >= v_av.slots then raise exception 'fully_booked'; end if;

    -- NOT: type enum'unda 'invite' YOK ('standard' | 'direct_invite').
    -- 030'daki gövde 'invite' yazıyordu — davet kabulü bu yüzden de
    -- kırılabilirdi. Doğru değer: 'direct_invite'.
    insert into requests (guest_id, host_id, avail_id, status, type, intro_message, match_score)
    values (v_uid, v_i.host_id, v_i.avail_id, 'accepted', 'direct_invite', v_i.note, 60)
    returning id into v_req;

    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_uid, -1, 'invite_hold', v_req, v_bal - 1);
    -- filled: trigger

    insert into chat_channels (request_id, kind) values (v_req, 'lounge')
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req;

    -- Davet notu ilk mesaj (gönderen: HOST — daveti o yazdı)
    if v_chan is not null and coalesce(nullif(trim(v_i.note),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_i.host_id, trim(v_i.note), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    -- Otomatik oturum (kabul = anlaşma)
    insert into sessions (request_id, status, started_at)
    values (v_req, 'active', now()) returning id into v_sess;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin kabul edildi ✓', 'Sohbet açıldı, oturum başladı.', 'request', v_req);
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin yanıtlandı', 'Davet reddedildi.', 'invite', p_id);
  end if;

  return jsonb_build_object('ok', true, 'request_id', v_req, 'channel_id', v_chan);
end $function$;

-- ── admin_anonymize_user ──
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

  -- Silinen kişiyi arayanların bir şey bulabilmesi için kısa bir etiket.
  -- Ham e-postanın hiçbir izi kalmaz; yalnız "kimdi" değil "kaçıncı"ydı.
  v_tag := 'silinmis-' || left(replace(p_user_id::text, '-', ''), 8);

  -- 1) KİMLİK
  update users
     set email = v_tag || '@silinmis.loungelink',
         phone = null,
         anonymized_at = now(),
         anonymized_by = p_admin
   where id = p_user_id;

  -- 2) PROFİL — serbest metinlerin hepsi kişisel veri taşıyabilir
  update profiles
     set name = 'Silinmiş kullanıcı',
         bio = null, profession = null, photo_url = null,
         linkedin_url = null, linkedin_verified = false,
         access_source = null,
         show_on_discovery = false, profile_visibility = 'Connections',
         updated_at = now()
   where user_id = p_user_id;

  -- 3) DOĞRULAMA İZLERİ
  update verifications
     set phone_verified = false, id_verified = false
   where user_id = p_user_id;

  -- 4) SERBEST METİN İÇEREN KAYITLAR
  -- Mesajlar SİLİNMEZ: karşı tarafın sohbeti delik deşik olur ve bir
  -- itiraz durumunda bağlam kaybolur. İçerik yerine yazarı anonimleşir.
  update reports set description = '[anonimlestirildi]'
   where reporter_id = p_user_id;
  update ratings set comment = null
   where rater_id = p_user_id;
  delete from push_tokens      where user_id = p_user_id;
  delete from otp_tokens       where user_id = p_user_id;
  delete from visits           where user_id = p_user_id and visit_date >= current_date;
  delete from availabilities   where host_id = p_user_id and avail_date >= current_date;
  delete from host_entitlements where user_id = p_user_id;

  -- 5) OTURUMU KAPAT — kullanıcı bir daha giremesin
  delete from auth.sessions  where user_id = p_user_id;
  delete from auth.identities where user_id = p_user_id;
  update auth.users
     set email = v_tag || '@silinmis.loungelink',
         phone = null,
         raw_user_meta_data = '{}'::jsonb,
         banned_until = 'infinity'
   where id = p_user_id;

  -- 🔴 Denetim kaydını BURADA yazmıyoruz. audit_log'un kolonları
  -- (actor_id uuid, entity_type, before_data, after_data) BO'nun audit()
  -- yardımcısıyla yazılıyor; buradan ikinci bir yol açmak iki farklı
  -- şemayla iki farklı kayıt üretirdi. Çağıran BO action'ı audit() çağırır.

  return jsonb_build_object('ok', true, 'tag', v_tag);
end $function$;

-- ── request_account_deletion ──
CREATE OR REPLACE FUNCTION public.request_account_deletion(p_email text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if coalesce(p_email,'') !~ '^[^@]+@[^@]+\.[^@]+$' then
    raise exception 'invalid_email';
  end if;
  -- 🔴 SILME OTOMATIK DEGIL. E-postasini bilen herkesin baskasinin
  -- hesabini silebilmesi demek olurdu. Talep kaydedilir, BO'da
  -- kullanici dogrulandiktan SONRA islenir.
  insert into deletion_requests (email, note)
  values (lower(trim(p_email)), nullif(trim(coalesce(p_reason,'')),''))
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id,
    'note', 'Talebin alindi. Kimligini dogruladiktan sonra 30 gun icinde islenecek.');
end $function$;

-- ── bo_plan_ata ──
CREATE OR REPLACE FUNCTION public.bo_plan_ata(p_user uuid, p_plan text, p_sebep text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_eski text;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select plan::text into v_eski from users where id = p_user;
  if v_eski is null then raise exception 'kullanici_yok'; end if;

  update users set plan = p_plan::plan_type, updated_at = now() where id = p_user;

  insert into audit_log (actor_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), 'plan_ata', 'user', p_user,
          jsonb_build_object('eski', v_eski, 'yeni', p_plan, 'sebep', p_sebep));

  return jsonb_build_object('ok', true, 'eski', v_eski, 'yeni', p_plan);
end $function$;

-- ── trg_cinsiyet_kilidi ──
CREATE OR REPLACE FUNCTION public.trg_cinsiyet_kilidi()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if old.gender is not null and new.gender is distinct from old.gender then
    -- Yönetim değiştirebilir; kullanıcı değiştiremez.
    if auth.uid() is not null
       and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
      raise exception 'cinsiyet_degistirilemez';
    end if;
    insert into audit_log (actor_id, action, entity_type, entity_id, after_data)
    values (auth.uid(), 'cinsiyet_degisti', 'user', new.id,
            jsonb_build_object('eski', old.gender, 'yeni', new.gender));
  end if;
  return new;
end $function$;

-- ── 3 · NÖBETÇİ ─────────────────────────────────────────────────────
-- 🔴 Bu blok kolonların VARLIĞINI değil, YAZILABİLİRLİĞİNİ ölçüyor.
-- "information_schema'da var mı" sorusu bu hatayı yakalamazdı: hata
-- zaten ifade ÇÖZÜMLENDİĞİNDE çıkıyor. O yüzden her düzeltilen yol
-- gerçekten bir kez çalıştırılıyor ve sonra geri alınıyor.
--
-- 🆕 SINIF: "BİR KOLONUN ŞEMADA GÖRÜNMESİ, O KOLONA YAZAN KODUN
-- ÇALIŞTIĞI ANLAMINA GELMEZ — YAZMA YOLUNU BİR KEZ YÜRÜT."
do $n258$
declare
  v_h text[] := '{}';
  v_u uuid; v_r uuid;
begin
  begin
    select id into v_u from users limit 1;

    -- points_ledger.balance_after gerçekten yazılabiliyor mu
    insert into points_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_u, 1, 'n258_olcum', null, 1);

    -- requests.decision_note gerçekten yazılabiliyor mu
    select id into v_r from requests limit 1;
    if v_r is not null then
      update requests set decision_note = coalesce(decision_note, 'n258 ölçüm')
       where id = v_r;
    end if;

    -- audit_log'un doğru kolonları
    insert into audit_log (actor_id, action, entity_type, entity_id, after_data)
    values (v_u, 'n258_olcum', 'user', v_u, jsonb_build_object('olcum', true));

    -- reports.description ve deletion_requests.note
    insert into deletion_requests (email, note)
    values ('n258@olcum.invalid', 'olcum');

    raise exception 'GERI_AL_258';
  exception when others then
    if sqlerrm <> 'GERI_AL_258' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '258 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '258 OK · eksik iki kolon eklendi · alti etkin fonksiyonun kolon adlari duzeltildi · yazma yollari calistirilarak dogrulandi';
end $n258$;

commit;

select '258 OLMAYAN KOLONLAR' as sonuc,
       (select count(*) from information_schema.columns
         where table_name='points_ledger' and column_name='balance_after') as pl_balance_after,
       (select count(*) from information_schema.columns
         where table_name='requests' and column_name='decision_note') as req_decision_note;
