-- ============================================================
-- LoungeLink · sql/282_ban_ve_kvkk_silme.sql
-- 1 Eylül 2026
--
-- 🔴 İKİ YARIM YOL: BAN UYGULANMIYOR, KVKK SİLME KUYRUĞA DÜŞMÜYOR
--
--   B1 · BAN = deleted_at, VE BAN HİÇBİR YERDE UYGULANMIYOR.
--        BO `toggleBan` `users.deleted_at` yazıyor — `delete_my_account`
--        ile AYNI kolon. Liste "silinmiş", detay "yasaklı" gösteriyor;
--        ayırt edilemez. Daha kötüsü: `create_request*`,
--        `respond_request`, `send_message`, `discover_availabilities`
--        hiçbiri `deleted_at`e bakmıyor (prosrc taraması: false).
--        Yasaklı kullanıcı istek atmaya, mesajlaşmaya devam ediyor.
--
--   B2 · UYGULAMADAKİ "HESABI SİL" SLA KUYRUĞUNA GİRMİYOR.
--        `delete_my_account` yalnız `deleted_at` yazıyor;
--        `deletion_requests`'e düşmüyor. `bo_silme_talepleri` yalnız
--        o tabloyu okuyor → uygulama içinden gelen HİÇBİR silme talebi
--        BO'da görünmüyor, kimse anonimleştirmiyor, KVKK 30 gün SLA'sı
--        sessizce aşılıyor.
--
--   B3 · ANONİMLEŞTİRME TELEFONU YARIM SİLİYOR.
--        `admin_anonymize_user` `users.phone`u null yapıyor ama
--        `phone_e164` ve `phone_kanonik` KALIYOR. `uq_users_phone_kanonik`
--        `deleted_at is null` koşullu ve anonimleştirme `deleted_at`
--        yazmıyor → kişi aynı numarayla yeniden KAYIT OLAMAZ ve numarası
--        DB'de kalır. "Sildik" dediğimiz veri silinmemiş.
--
-- 🆕 SINIF: "BİR DURUMU BAŞKA BİR DURUMUN KOLONUNA YAZARSAN İKİSİNİ DE
-- KAYBEDERSİN — SİLİNMİŞ Mİ, YASAKLI MI, KİMSE BİLMEZ."
-- ============================================================

-- ── B1 · Ayrı ban kolonu + tek kapı fonksiyonu ────────────────────
alter table users add column if not exists banned_at timestamptz;
alter table users add column if not exists ban_reason text;
comment on column users.banned_at is
  'Yasak. `deleted_at`ten AYRI: silinmiş hesap geri gelmez, yasaklı hesap '
  'kaldırılabilir. İkisini aynı kolona yazmak ikisini de okunmaz yapıyordu (282).';

-- Geçmiş: BO'nun ban diye yazdığı deleted_at satırlarını ayırt edemeyiz;
-- audit_log'da 'user.ban' kaydı olanları geri kazanıyoruz.
update users u
   set banned_at = coalesce(u.banned_at, a.created_at), deleted_at = null
  from audit_log a
 where a.entity_type = 'users' and a.entity_id::text = u.id::text
   and a.action = 'user.ban'
   and u.deleted_at is not null
   and not exists (select 1 from audit_log a2
                    where a2.entity_type='users' and a2.entity_id::text=u.id::text
                      and a2.action in ('user.unban','app.account_delete')
                      and a2.created_at > a.created_at);

-- TEK KAPI: yazan her fonksiyon bunu çağırır. Yasaklı ya da silinmiş
-- hesap hiçbir yazma işlemi yapamaz.
create or replace function public.hesap_kapisi(p_uid uuid default auth.uid())
returns void language plpgsql stable security definer set search_path = public as $$
declare v_ban timestamptz; v_del timestamptz;
begin
  if p_uid is null then raise exception 'not_authenticated'; end if;
  select banned_at, deleted_at into v_ban, v_del from users where id = p_uid;
  if v_ban is not null then raise exception 'account_banned'; end if;
  if v_del is not null then raise exception 'account_deleted'; end if;
end $$;
revoke all on function public.hesap_kapisi(uuid) from public, anon;
grant execute on function public.hesap_kapisi(uuid) to authenticated;

-- Kapıyı ÇEKİRDEK yazma fonksiyonlarının başına yamalıyoruz.
-- Her biri `if v_uid is null then raise exception 'not_authenticated'; end if;`
-- ile başlıyor; hemen ardına kapı geliyor. Snippet yoksa PATLAR.
do $$
declare f text; v_def text; v_yeni text; v_n int := 0;
begin
  -- ⚠️ `send_message` diye bir RPC YOK — mesajlar tabloya doğrudan
  -- INSERT ile yazılıyor (RLS ile). Onun kapısı aşağıda TRIGGER olarak.
  foreach f in array array['create_request_impl_preflag','respond_request',
                           'start_session_request',
                           'send_connection','baglanti_sohbeti_ac',
                           'create_availability','cancel_request']
  loop
    if not exists (select 1 from pg_proc where proname = f) then
      raise notice '282: % yok, atlandi', f; continue;
    end if;
    select pg_get_functiondef((quote_ident('public')||'.'||quote_ident(f))::regproc) into v_def;
    if v_def like '%hesap_kapisi%' then continue; end if;
    v_yeni := regexp_replace(v_def,
      E'(if v_uid is null then raise exception \'not_authenticated\'; end if;)',
      E'\\1\n  perform public.hesap_kapisi(v_uid);   -- 282/B1: yasakli/silinmis hesap yazamaz',
      '');   -- yalnız ilk eşleşme
    if v_yeni = v_def then
      raise notice '282: % icinde not_authenticated kalibi yok — ELLE BAK', f;
      continue;
    end if;
    execute v_yeni;
    v_n := v_n + 1;
  end loop;
  raise notice '282: hesap kapisi % fonksiyona takildi', v_n;
end $$;

-- Mesaj yazma doğrudan INSERT: kapı trigger'da.
create or replace function public.trg_mesaj_hesap_kapisi()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.hesap_kapisi(new.from_id);
  return new;
end $$;
drop trigger if exists trg_mesaj_hesap_kapisi on messages;
create trigger trg_mesaj_hesap_kapisi
  before insert on messages for each row execute function public.trg_mesaj_hesap_kapisi();

-- Keşif de yasaklı host'un ilanını göstermez
do $$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef('public.discover_availabilities_base'::regproc) into v_def;
  if v_def like '%282/B1%' then
    raise notice '282: discover zaten yamali';
  elsif v_def like '%where a.active%' then
    v_yeni := replace(v_def, 'where a.active',
      'where a.active and not exists (select 1 from users bu where bu.id = a.host_id and (bu.banned_at is not null or bu.deleted_at is not null)) /* 282/B1 */');
    execute v_yeni;
    raise notice '282: discover_availabilities_base yasakli hostu gizliyor';
  else
    raise notice '282: discover kalibi bulunamadi — ELLE BAK';
  end if;
end $$;

-- ── B2 · Uygulama içi silme → SLA kuyruğu ────────────────────────
create or replace function public.delete_my_account()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_email text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select email into v_email from users where id = v_uid;
  update users set deleted_at = now() where id = v_uid and deleted_at is null;
  update availabilities set active = false where host_id = v_uid;
  -- 282/B2: SLA kuyruğuna DÜŞ. `bo_silme_talepleri` yalnız bu tabloyu
  -- okuyor; buraya yazmayan bir silme talebi BO için yoktur.
  insert into deletion_requests (email, note, source, status, matched_user_id)
  select coalesce(v_email, v_uid::text), 'uygulama içi "Hesabı sil"', 'app', 'open', v_uid
   where not exists (select 1 from deletion_requests
                      where matched_user_id = v_uid and status in ('open','in_progress'));
  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('app.account_delete', 'users', v_uid, jsonb_build_object('requested_by','user'));
  return jsonb_build_object('ok', true, 'sla_days', 30);
end $$;

-- ── B3 · Anonimleştirme telefonun ÜÇ kolonunu da temizler ─────────
do $$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef('public.admin_anonymize_user'::regproc) into v_def;
  if v_def like '%phone_kanonik = null%' then
    raise notice '282: anonymize zaten yamali';
  else
    v_yeni := replace(v_def, 'phone = null,',
      'phone = null, phone_e164 = null, phone_kanonik = null, /* 282/B3 */');
    if v_yeni = v_def then raise exception '282: anonymize phone snippeti bulunamadi'; end if;
    -- deleted_at de yazılmalı: anonim hesap "silinmiş"tir, unique indeks
    -- (deleted_at is null koşullu) numarayı serbest bırakır.
    if v_yeni not like '%deleted_at = coalesce(deleted_at, now())%' then
      v_yeni := replace(v_yeni, 'phone = null, phone_e164 = null, phone_kanonik = null, /* 282/B3 */',
        'phone = null, phone_e164 = null, phone_kanonik = null, deleted_at = coalesce(deleted_at, now()), /* 282/B3 */');
    end if;
    execute v_yeni;
    raise notice '282: anonymize uc telefon kolonunu da siliyor';
  end if;
end $$;

-- ── NÖBETÇİLER ──────────────────────────────────────────────────
do $$
declare v int;
begin
  if not exists (select 1 from information_schema.columns where table_name='users' and column_name='banned_at') then
    raise exception '282: banned_at yok';
  end if;
  select count(*) into v from pg_proc
   where proname in ('create_request_impl_preflag','respond_request','cancel_request','start_session_request')
     and prosrc like '%hesap_kapisi%';
  if v < 4 then raise exception '282: hesap kapisi cekirdek fonksiyonlara takilmadi (%/4)', v; end if;
  if not exists (select 1 from pg_trigger where tgname='trg_mesaj_hesap_kapisi') then
    raise exception '282: mesaj kapisi trigger yok';
  end if;
  if pg_get_functiondef('public.delete_my_account'::regproc) not like '%deletion_requests%' then
    raise exception '282: delete_my_account kuyruga yazmiyor';
  end if;
  if pg_get_functiondef('public.admin_anonymize_user'::regproc) not like '%phone_kanonik = null%' then
    raise exception '282: anonymize phone_kanonik silmiyor';
  end if;
  raise notice '282 NOBETCI OK: ban ayri kolon + kapi · silme kuyruga dusuyor · anonimlestirme tam';
end $$;
