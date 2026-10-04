-- ============================================================================
-- 329 · SİLİNEN HESAP 14 GÜN SONRA OTOMATİK ANONİMLEŞİR · E-POSTA SERBEST KALIR
--       (yasaklı hesap hariç)  (4 Ekim 2026 · Gökberk sorusu)
--
-- DURUM (ölçüldü): "Hesabımı sil" (322) hesabı "silme talep edildi"ye alıyor; e-posta
-- ve Google/Apple kimliği ancak BO ELLE anonimleştirince (admin_anonymize_user)
-- serbest kalıyordu. Unutulursa aynı e-postayla bir daha HİÇ kayıt olunamıyordu.
-- KARAR (süre: 14 gün):
--   · Anında serbest bırakmak bir açık olurdu: kötü puan, gelmedi kaydı, düşük güven ya
--     da YASAK, "sil → aynı e-postayla yeniden kaydol" ile sıfırlanabilirdi.
--   · 14 gün: kötüye kullanımı keser, yanlışlıkla silmede destekle geri dönüşe yer bırakır,
--     uzun değil. Her gece 03:30'da pg_cron 14 günü dolanları anonimleştirir → e-posta ve
--     Google/Apple kimliği serbest; aynı adresle TEMİZ yeni hesap açılabilir.
--   · YASAKLI hesabın e-postası serbest kalmaz: özeti (sha256, okunamaz) saklanır; aynı
--     adresle açılan yeni hesap da yasaklı açılır.
--   · Daha önce silinmiş bir e-posta yeniden kayıt olursa hoş geldin kredisi tekrar verilmez.
-- 🔴 EK BULGU (B22): admin_anonymize_user auth.users'ta OLMAYAN kolonlara (phone_e164,
-- phone_kanonik) yazıyordu → BO'nun "Anonimleştir"i canlıda hata verip hiçbir şey yapmıyordu.
-- Bu dosya onu da düzeltir (aşağıda).
-- ÖNKOŞUL: 322 (yasak tetikleyicisi) · 328 (handle_new_user). Tekrar koşulabilir.
-- ============================================================================

create table if not exists public.onceki_epostalar (
  ozet       text primary key,            -- sha256(lower(trim(email))) — ham e-posta TUTULMAZ
  yasakli    boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.onceki_epostalar enable row level security;   -- politika yok: yalnız sunucu
revoke all on public.onceki_epostalar from public, anon, authenticated;

create or replace function public.eposta_ozeti(p_email text)
 returns text language sql immutable set search_path to 'public', 'extensions' as $f$
  select encode(extensions.digest(lower(trim(coalesce(p_email, ''))), 'sha256'), 'hex');
$f$;
revoke execute on function public.eposta_ozeti(text) from public, anon, authenticated;

-- Var olan yasaklı hesapların özetleri (bir kez; tekrar koşmak zararsız)
insert into public.onceki_epostalar (ozet, yasakli)
select public.eposta_ozeti(u.email), true from public.users u
 where u.banned_at is not null and u.email is not null and u.email not like '%@silinmis.loungelink'
on conflict (ozet) do update set yasakli = true;

create or replace function public.silinen_hesaplari_anonimlestir()
 returns jsonb language plpgsql security definer set search_path to 'public' as $f$
declare r record; n int := 0;
begin
  for r in
    select u.id, u.email, u.banned_at from public.users u
     where u.deleted_at is not null and u.deleted_at < now() - interval '14 days'
       and u.anonymized_at is null
  loop
    begin
      insert into public.onceki_epostalar (ozet, yasakli)
      values (public.eposta_ozeti(r.email), r.banned_at is not null)
      on conflict (ozet) do update set yasakli = public.onceki_epostalar.yasakli or excluded.yasakli;
      perform public.admin_anonymize_user(r.id, 'otomatik-329', '14 gün doldu');
      update public.users set anonymized_at = coalesce(anonymized_at, now()) where id = r.id;
      update public.deletion_requests
         set status = 'done', handled_at = coalesce(handled_at, now()),
             resolution = coalesce(resolution, '14 gün sonra otomatik anonimleştirildi (329)')
       where matched_user_id = r.id and status in ('pending', 'verified');
      n := n + 1;
    exception when others then
      raise notice '329: % anonimlestirilemedi: %', r.id, sqlerrm;
    end;
  end loop;
  return jsonb_build_object('ok', true, 'anonimlestirilen', n);
end $f$;
revoke execute on function public.silinen_hesaplari_anonimlestir() from public, anon, authenticated;
grant execute on function public.silinen_hesaplari_anonimlestir() to service_role;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g user_gender; n text; r user_role; v_staff boolean;
  v_onceki record; v_onceki_var boolean := false;
begin
  begin g := (new.raw_user_meta_data->>'gender')::user_gender; exception when others then g := null; end;
  begin r := coalesce((new.raw_user_meta_data->>'role')::user_role, 'guest'); exception when others then r := 'guest'; end;
  -- 328 · TEK YOL: host rolü YALNIZ BO onaylı başvuruyla. Kayıtta "host" seçen hesap misafir
  -- açılır; niyet raw_user_meta_data.role'de kalır ve uygulama onu başvuru formuna götürür.
  if r = 'host' then r := 'guest'; end if;
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1));

  -- YENİ (041): BO daveti bu bayrakları zaten gönderiyor
  begin
    v_staff := coalesce((new.raw_user_meta_data->>'is_staff')::boolean, false)
            or coalesce((new.raw_user_meta_data->>'is_partner')::boolean, false);
  exception when others then v_staff := false;
  end;

  insert into public.users (id, email, role, gender, password_hash, is_staff)
  values (new.id, new.email, r, g, 'supabase-auth', v_staff) on conflict (id) do nothing;

  -- 329 · Bu e-posta daha önce silinmiş bir hesaba mı aitti? (yalnız özet tutulur)
  --   · YASAKLI hesabınsa: yeni hesap da yasaklı açılır (yasak, silip yeniden kayıtla aşılamaz)
  --   · değilse: hoş geldin kredisi YENİDEN verilmez (sil-kaydol ile kredi toplanamaz)
  select * into v_onceki from public.onceki_epostalar
   where ozet = public.eposta_ozeti(new.email);
  v_onceki_var := found;
  if v_onceki_var and v_onceki.yasakli then
    update public.users set banned_at = now(), ban_reason = 'Önceki hesabı yasaklıydı (329)' where id = new.id;
  end if;

  -- staff ise keşifte görünme
  insert into public.profiles (user_id, name, show_on_discovery)
  values (new.id, n, not v_staff) on conflict (user_id) do nothing;

  insert into public.verifications (user_id, email_verified, email_verified_at)
  values (new.id, true, now()) on conflict (user_id) do nothing;
  insert into public.trust_scores (user_id, score, components, badge)
  values (new.id, 10, '{"email":10}'::jsonb, 'New') on conflict (user_id) do nothing;

  -- BETA (033): açılış kredisi — ama ekip hesabına DEĞİL.
  -- Kendi hatasını yutar: kredi verilemezse KAYIT YİNE DE TAMAMLANIR.
  if not v_staff and not v_onceki_var then
    begin
      perform grant_signup_credits(new.id);
    exception when others then
      null;
    end;
  end if;

  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.trg_users_yasak_acik_isleri_kapat()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if old.banned_at is null and new.banned_at is not null then
    perform public.hesap_acik_islerini_kapat(new.id);
    -- 329 · yasaklı e-postanın özeti saklanır: silinip yeniden kayıt olursa yeni hesap da yasaklı açılır
    if coalesce(new.ban_reason, '') <> 'Önceki hesabı yasaklıydı (329)' then
      insert into public.onceki_epostalar (ozet, yasakli)
      values (public.eposta_ozeti(new.email), true)
      on conflict (ozet) do update set yasakli = true;
    end if;
  end if;
  return new;
end $function$;

-- ── admin_anonymize_user: auth.users güncellemesi (B22) ──────────────────────
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
         phone = null, phone_e164 = null, phone_kanonik = null, deleted_at = coalesce(deleted_at, now()), /* 282/B3 */
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
  -- 🔴 329 · BU GÜNCELLEME HİÇ ÇALIŞMIYORDU. 282/B3 düzenlemesi buraya public.users'ın
  -- kolonlarını (phone_e164, phone_kanonik) da yazmıştı; auth.users'ta bu kolonlar YOK →
  -- "column ... does not exist" → bütün fonksiyon geri alınıyor: BO'nun "Anonimleştir"i
  -- hiçbir şey yapmıyor, e-posta ve Google/Apple kimliği hiç serbest kalmıyordu.
  -- Yalnız auth.users'ın gerçek kolonları; deleted_at Supabase'de var (yoksa atlanır).
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

  -- 🔴 Denetim kaydını BURADA yazmıyoruz. audit_log'un kolonları
  -- (actor_id uuid, entity_type, before_data, after_data) BO'nun audit()
  -- yardımcısıyla yazılıyor; buradan ikinci bir yol açmak iki farklı
  -- şemayla iki farklı kayıt üretirdi. Çağıran BO action'ı audit() çağırır.

  return jsonb_build_object('ok', true, 'tag', v_tag);
end $function$;

-- ── delete_my_account: silme sürecinde giriş kapalı ─────────────────────────
CREATE OR REPLACE FUNCTION public.delete_my_account()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_email text; v_kapanan jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select email into v_email from users where id = v_uid;

  -- 322 · açık işler (istekler · oturumlar · bağlantılar · ilanlar · keşif görünürlüğü)
  v_kapanan := public.hesap_acik_islerini_kapat(v_uid);

  update users set deleted_at = now() where id = v_uid and deleted_at is null;
  -- 329 · Silme sürecinde GİRİŞ KAPALI: eskiden 14 gün içinde yeniden giriş yapan kişi salt
  -- okunur, yarı silinmiş bir hesaba düşüyordu ("yazma işlemleri kapalı"). Auth katmanında
  -- 15 gün kilit → uygulama "Bu hesap kapatıldı…" der. 14. gün gece anonimleştirme kilidi
  -- kalıcı yapar ve e-postayı serbest bırakır (aradaki gün boşluk bırakmaz).
  update auth.users set banned_until = greatest(coalesce(banned_until, now()), now() + interval '15 days')
   where id = v_uid;

  -- 282/B2: SLA kuyruğuna DÜŞ (bo_silme_talepleri yalnız bu tabloyu okur).
  -- 322: durum sözlüğü tablonun ve BO'nun sözlüğü — 'pending' (eskiden 'open' → kısıt hatası).
  insert into deletion_requests (email, note, source, status, matched_user_id)
  select coalesce(v_email, v_uid::text), 'uygulama içi "Hesabı sil"', 'app', 'pending', v_uid
   where not exists (select 1 from deletion_requests
                      where matched_user_id = v_uid and status in ('pending', 'verified'));
  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('app.account_delete', 'users', v_uid, jsonb_build_object('requested_by', 'user') || coalesce(v_kapanan, '{}'::jsonb));
  return jsonb_build_object('ok', true, 'sla_days', 30);
end $function$;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'll-silinen-hesap-anonim') then
      perform cron.unschedule('ll-silinen-hesap-anonim');
    end if;
    perform cron.schedule('ll-silinen-hesap-anonim', '30 3 * * *', 'select public.silinen_hesaplari_anonimlestir()');
    raise notice '329: pg_cron isi kuruldu — ll-silinen-hesap-anonim, her gece 03:30.';
  else
    raise notice '329: pg_cron yok — is kurulmadi (canlida var).';
  end if;
end $$;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'kayit onceki e-postayi taniyor' as kontrol,
       position('onceki_epostalar' in pg_get_functiondef('public.handle_new_user()'::regprocedure)) > 0 as tamam
union all
select 'yasakta e-posta ozeti saklaniyor',
       position('onceki_epostalar' in pg_get_functiondef('public.trg_users_yasak_acik_isleri_kapat()'::regprocedure)) > 0
union all
select 'anonimlestirme fonksiyonu kullaniciya kapali',
       not has_function_privilege('authenticated', 'public.silinen_hesaplari_anonimlestir()', 'execute')
union all
select 'anonimlestirme auth kolonlari dogru',
       position('329 · BU GÜNCELLEME' in pg_get_functiondef('public.admin_anonymize_user(uuid,text,text)'::regprocedure)) > 0
union all
select 'silme surecinde giris kapali',
       position('329 · Silme sürecinde' in pg_get_functiondef('public.delete_my_account()'::regprocedure)) > 0;
-- Beklenen: beş satır tamam = true. Canlıda ayrıca Integrations › Cron'da 'll-silinen-hesap-anonim' görünür.
