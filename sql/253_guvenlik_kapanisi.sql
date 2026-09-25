-- ============================================================================
-- 253 — GÜVENLİK KAPANIŞI (mağaza öncesi · ÖNCE BU ÇALIŞTIRILMALI)
--
-- ⚠️ BU DOSYA CANLIDA DURAN AÇIKLARI KAPATIYOR. Diğer tüm işlerin önünde.
--
-- Bulgular ölçülerek çıkarıldı; her biri canlı replika üzerinde
-- `set role anon` / `set role authenticated` ile GERÇEKTEN sömürüldü ve
-- sonra `rollback` edildi. Aşağıdaki her bölüm bir sömürünün kapısıdır.
--
-- ----------------------------------------------------------------------------
-- KAPATILAN ALTI KAPI
-- ----------------------------------------------------------------------------
--  §1  Altı GÖRÜNÜM giriş yapmamış herkese açıktı: açık taciz şikâyetleri,
--      isim+e-posta eşleşmeleri, kimin nerede kiminle buluşacağı, 45
--      kullanıcının kredi bakiyesi. RLS görünümlerde ÇALIŞMAZ.
--  §2  `change_plan()` ödemesiz plan veriyor ve sınırsız kredi bastırıyordu
--      (ölçüldü: 7 çağrıda 4 → 48 kredi).
--  §3  `otp_demo_mode='yes'` — `send_otp` üretilen kodu yanıtta geri
--      veriyordu; iki çağrıyla istediğin numara "doğrulanmış" oluyordu.
--  §4  23 SECURITY DEFINER fonksiyonunda sahiplik denetimi yoktu
--      (`host_wallet` sınıfı): başkasının uuid'iyle planı, ağırlama
--      geçmişi, ortak salon panosu ve NEREDE OLACAĞI okunabiliyordu.
--  §5  İstemci kendi doğrulama rozetini, kurucu numarasını, referans
--      zincirini ve CİNSİYETİNİ yazabiliyordu. Sonuncusu kadın güvenlik
--      modunu tek `update` ile çürütüyordu.
--  §6  `profile_visibility` HİÇBİR YERDE uygulanmıyordu — 19 kullanıcı
--      "Trusted+" seçmişti ve profilleri herkese açıktı.
--
-- ----------------------------------------------------------------------------
-- 🆕 BU TURUN ANA SINIFI
-- ----------------------------------------------------------------------------
-- 241 Supabase'in varsayılan haklarını kapattı ama YALNIZ YAZMA için; ve
-- kendi nöbetçisi `relkind='r'` dediği için görünümlere hiç bakmadı.
-- Nöbetçi yeşil yanarken kapı açıktı.
--
-- "BİR NÖBETÇİNİN BAKMADIĞI YER, KORUNDUĞU SANILAN YERDİR."
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §0 — MİGRATION DEFTERİ (önce kuruluyor: §1 onu da kapatacak)
--
-- Bu projede hangi SQL'in koştuğu bugüne kadar İZDEN çıkarılıyordu ve
-- 278 dosyanın 49'u ayırt edici iz bırakmıyordu. Defter, `KURULUM_TABLOSU`
-- teşhis dosyasının içinde yaşıyordu — yani ancak teşhis çalıştırılırsa
-- vardı. Artık migration'ın kendisi kuruyor ve kendini yazıyor.
--
-- 🆕 SINIF: "TESPİT EDİLEMEYENİ TAHMİN ETMEK YERİNE TESPİT EDİLEBİLİR YAP."
-- ════════════════════════════════════════════════════════════════════════

create table if not exists schema_migrations (
  dosya      text primary key,
  kaynak     text not null default 'migration',
  kosuldu_at timestamptz not null default now()
);
alter table schema_migrations enable row level security;

create or replace function public.migration_kaydet(p_dosya text)
returns void
language sql security definer set search_path = public as $mk253$
  insert into schema_migrations (dosya, kaynak, kosuldu_at)
  values (p_dosya, 'migration', now())
  on conflict (dosya) do update set kosuldu_at = now(), kaynak = 'migration';
$mk253$;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — GÖRÜNÜMLER: RLS ORADA ÇALIŞMAZ, O YÜZDEN HAK VERİLMEZ
--
-- Bir görünüm sahibinin haklarıyla çalışır (`security_invoker` kapalıysa),
-- yani altındaki tablonun RLS'ini TAMAMEN atlar. Altısı da backoffice
-- görünümü; BO zaten `service_role` ile okuyor. İstemcinin hiçbirine
-- ihtiyacı yok.
-- ════════════════════════════════════════════════════════════════════════

do $g253$
declare r record; v_say int := 0;
begin
  for r in
    select c.relname
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('v','m')
  loop
    execute format('revoke all on public.%I from anon', r.relname);
    execute format('revoke all on public.%I from authenticated', r.relname);
    execute format('grant select on public.%I to service_role', r.relname);
    v_say := v_say + 1;
  end loop;
  raise notice '253 §1: % gorunumun istemci hakki kapatildi.', v_say;
end $g253$;

-- ────────────────────────────────────────────────────────────────────────
-- 🔴 BİR GÖRÜNÜMÜ UYGULAMA GERÇEKTEN OKUYOR: `user_balances`
--
-- Yukarıdaki döngü altı görünümü de kapattı — ama ölçtüm: `user_balances`
-- uygulamanın ÜÇ yerinde okunuyor (App.js Ana Sayfa, Profil, Oturum
-- Geçmişi). Onu da kapatmak güvenlik değil KESİNTİ olurdu: kullanıcı
-- kredisini ve puanını göremezdi.
--
-- 🆕 SINIF: "BİR SINIFIN TAMAMINI KAPATMAK, O SINIFIN İÇİNDE GERÇEKTEN
-- KULLANILAN TEK ÖRNEĞİ DE KAPATIR — SINIFI KAPATMADAN ÖNCE ÖRNEKLERİ SAY."
--
-- Doğru çözüm "istisna yap" değil, GÖRÜNÜMÜ RLS'İN ALTINA SOKMAK:
-- `security_invoker = on` ile görünüm ÇAĞIRANIN haklarıyla çalışır ve
-- alttaki `credit_ledger` / `points_ledger` RLS'i (ikisi de açık) devreye
-- girer. Yani kullanıcı yalnız KENDİ bakiyesini görür — ki zaten
-- `.eq("user_id", uid)` ile onu istiyor.
do $ub253$
begin
  if to_regclass('public.user_balances') is not null then
    execute 'alter view public.user_balances set (security_invoker = on)';
    execute 'grant select on public.user_balances to authenticated';
    raise notice '253 §1: user_balances RLS altina alindi ve istemciye geri acildi.';
  end if;
end $ub253$;
-- ────────────────────────────────────────────────────────────────────────

-- 🔴 VE ASIL KÖK NEDEN: yeni oluşan her tablo/görünüm `anon`a OKUNUR
-- doğuyor. 241 bunu yalnız YAZMA için kapattı.
-- 🔴 BU İKİ SATIR YETMEDİ VE GÖKBERK'İN VERİTABANINDA NÖBETÇİ HAKLI
-- ÇIKTI: "yeni tablolar hala anon'a OKUNUR doguyor".
--
-- Sebep `ALTER DEFAULT PRIVILEGES`in en sinsi özelliği: bu komut
-- GLOBAL bir ayar değil, HER VEREN ROL İÇİN AYRI bir kayıttır.
-- `FOR ROLE` yazmazsan yalnız ŞU ANKİ rolün kaydına dokunursun.
-- Supabase'de bu izni veren kayıt başka bir rolün (ya da şema
-- belirtilmemiş GLOBAL bir kaydın) altında duruyor olabilir —
-- o zaman revoke "başarıyla" çalışır ve hiçbir şeyi değiştirmez.
--
-- Bende geçmesinin sebebi de buydu: harness'te kaydın sahibi zaten
-- `postgres`ti, yani tesadüfen doğru kaydı hedefliyordum. Doğru
-- sonucu doğru sebeple almadığımda, o sonuç bir sonraki ortamda
-- kayboluyor.
--
-- 🆕 SINIF: "BİR KOMUT 'BAŞARILI' DÖNDÜĞÜNDE İSTEDİĞİN ŞEYİ YAPTIĞINI
-- SANMA — HEDEFİNİ AÇIKÇA YAZMADIYSAN, VARSAYILAN HEDEF SENİN
-- ORTAMINDA DOĞRU, BAŞKASININKİNDE YANLIŞ OLABİLİR."
--
-- Artık kayıtlar TARANIYOR: hangi rol vermişse ona `FOR ROLE` ile
-- gidiliyor, şemasız (global) kayıtlar da kapsanıyor. Dokunulamayan
-- bir kayıt varsa SESSİZCE GEÇİLMİYOR — adıyla raporlanıyor.
do $dacl253$
declare
  r record;
  v_sql text;
  v_kalan text[] := '{}';
  v_kac int := 0;
begin
  for r in
    select d.defaclrole                                as rol_oid,
           pg_get_userbyid(d.defaclrole)               as rol,
           d.defaclnamespace                           as ns_oid,
           coalesce(n.nspname, '')                     as sema,
           array_to_string(d.defaclacl::text[], ', ')  as acl
      from pg_default_acl d
      left join pg_namespace n on n.oid = d.defaclnamespace
     where d.defaclobjtype = 'r'
       and array_to_string(d.defaclacl::text[], ',') ~ '(anon|authenticated)=[a-zA-Z]*r'
       and (d.defaclnamespace = 0 or n.nspname = 'public')
  loop
    -- 🔴 YALNIZ BİZİM ŞEMAMIZ. İlk hâlim BÜTÜN şemaları tarıyordu ve
    -- Gökberk'in veritabanında `graphql` ile `graphql_public`i de
    -- yakaladı. Onlar Supabase'in kendi şemaları; oradaki izni geri
    -- almak bizim işimiz değil ve GraphQL uç noktasını bozabilirdi.
    --
    -- 🆕 SINIF: "BİR GÜVENLİK TARAMASININ KAPSAMI, SORUMLU OLDUĞUN
    -- ALANLA SINIRLI OLMALI — BAŞKASININ EVİNDE BULDUĞUN KİLİDİ AÇIK
    -- KAPI SENİN BULGUN DEĞİLDİR."
    v_sql := 'alter default privileges for role ' || quote_ident(r.rol)
             || case when r.ns_oid = 0 then '' else ' in schema ' || quote_ident(r.sema) end
             || ' revoke select, references, trigger on tables from anon, authenticated';
    begin
      execute v_sql;
      v_kac := v_kac + 1;
    exception when others then
      -- Yetki yoksa BU BİR BİLGİDİR, hata değil: hangi rolle
      -- çalıştırılması gerektiğini söyleyebilmemiz lazım.
      v_kalan := v_kalan || format('%s%s → %s', r.rol,
                   case when r.ns_oid = 0 then ' (global)' else ' @' || r.sema end,
                   sqlerrm);
    end;
  end loop;

  if v_kac > 0 then
    raise notice '253 §1b: % varsayilan hak kaydi temizlendi (anon/authenticated okuma).', v_kac;
  end if;
  if array_length(v_kalan, 1) is not null then
    raise notice '253 §1b: DOKUNULAMAYAN kayit(lar): %', array_to_string(v_kalan, ' | ');
    raise notice '253 §1b: bunlar BASKA bir rolun kaydi. Onemli olan, BIZIM'
                 ' rolumuzle olusan tablonun anon''a kapali dogmasi — asagidaki'
                 ' SONDA olculuyor.';
  end if;
end $dacl253$;

-- (`schema_migrations` §0'da kuruldu ve orada kapatıldı.)

-- ════════════════════════════════════════════════════════════════════════
-- §2 — PLAN DEĞİŞİMİ İSTEMCİDEN ALINIYOR
--
-- `change_plan` ödeme kanıtı aramıyordu. Ölçüldü:
--     once_plan=yolcu once_kredi=4  →  change_plan('kahya')  →  +11 kredi
--     yükselt/indir döngüsü: 7 çağrıda 4 → 48 kredi
--
-- Bu yalnız güvenlik değil MAĞAZA meselesi de: Apple Guideline 3.1.1,
-- uygulama içinden satılan dijital hakkın IAP ile satılmasını şart koşar.
-- Ödeme entegrasyonu gelene kadar doğru davranış plan değişimini
-- istemciden TAMAMEN almaktır.
--
-- 🆕 SINIF: "ÖDEME KANITI ARAMAYAN BİR YÜKSELTME, ÜCRETSİZ BİR YÜKSELTMEDİR."
-- ════════════════════════════════════════════════════════════════════════

revoke all on function public.change_plan(plan_type) from public;
revoke all on function public.change_plan(plan_type) from anon;
revoke all on function public.change_plan(plan_type) from authenticated;
grant execute on function public.change_plan(plan_type) to service_role;

-- Yerine: yönetim panelinden atama. Denetim kaydı BIRAKIR.
create or replace function public.bo_plan_ata(p_user uuid, p_plan text, p_sebep text default null)
returns jsonb
language plpgsql security definer set search_path = public as $bpa253$
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
end $bpa253$;

grant execute on function public.bo_plan_ata(uuid, text, text) to service_role;

-- 🔴 YÜZEYDEN DE SİL. 224'ün nöbetçisi "yüzeyde yazılı ama istemci
-- çağıramıyor" diye haklı olarak kırmızı yanıyor: bir fonksiyonu kapatıp
-- kaydını bırakmak, kaydı yalan yapar.
-- 🆕 SINIF: "BİR KAPIYI KAPATIRKEN TABELASINI İNDİRMEZSEN, TABELA YALAN SÖYLER."
delete from rpc_client_surface where fn_name = 'change_plan';

-- ════════════════════════════════════════════════════════════════════════
-- §3 — OTP DEMO MODU KAPANIYOR
--
-- `send_otp` üretilen 6 haneli kodu yanıtın içinde geri veriyordu. Uçtan
-- uca sömürü koşturuldu: send_otp → demo_code oku → verify_otp → numara
-- DOĞRULANMIŞ + güven puanı 56'ya çıktı.
--
-- İki kat kapatılıyor: (a) ayar 'no', (b) gövdeden dal SİLİNİYOR. Ayarı
-- değiştirmek yetmez — bir üretim RPC'sinin kodu yanıtta taşıyabilme
-- YETENEĞİ hiç var olmamalı.
--
-- 🆕 SINIF: "BİR AYARLA KAPATILABİLEN BİR ARKA KAPI, HÂLÂ BİR ARKA KAPIDIR."
-- ════════════════════════════════════════════════════════════════════════

update beta_settings set value = to_jsonb('no'::text) where key = 'otp_demo_mode';
insert into beta_settings (key, value)
values ('otp_demo_mode', to_jsonb('no'::text)) on conflict (key) do nothing;

do $otp253$
declare v_tanim text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p where p.oid = to_regprocedure('public.send_otp(text)');
  if v_tanim is null then
    raise notice '253 §3: send_otp YOK — dokunulmadi.'; return;
  end if;
  if v_tanim not like '%demo_code%' then
    raise notice '253 §3: demo dali zaten yok — dokunulmadi.'; return;
  end if;

  -- 🔴 METNİ BİREBİR ARAMAK ÇALIŞMADI: `pg_get_functiondef` gövdeyi
  -- kendi biçimlendirmesiyle döndürüyor, benim dosyadaki girintimle değil.
  -- 🆕 SINIF: "BİR GÖVDEYİ METİNLE ARARKEN, ONU SENİN YAZDIĞIN BİÇİMDE
  -- SAKLANDIĞINI VARSAYMAK, ARAMAYI BİÇİME BAĞLAMAKTIR."
  -- Bu yüzden kalıp: `|| case when coalesce(v_demo, ...) ... end;` → `;`
  v_yeni := regexp_replace(v_tanim,
    '\|\|\s*case\s+when\s+coalesce\(\s*v_demo[^;]*end\s*;', ';', 'gi');

  if v_yeni like '%demo_code%' then
    raise exception '253 §3: demo dali cikarilamadi — DOKUNULMADI, elle bakilmali.';
  end if;
  execute v_yeni;
  raise notice '253 §3: send_otp artik kodu yanitta VERMIYOR.';
end $otp253$;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — SAHİPLİK DENETİMİ: TEK BİR YÜKLEMDEN
--
-- 23 fonksiyon `coalesce(p_user, auth.uid())` yazıyordu. O ifade "parametre
-- verilmezse benim" diyor; ama "parametre VERİLİRSE onun" da diyor —
-- ve hiçbiri onu doğrulamıyordu.
--
-- Ölçülmüş sömürü (yetkisiz bir kullanıcı olarak):
--     venue_guest_profile(salon, p_user := <partnerin uuid'i>) → çalıştı
--     pending_field_report(<baskasinin uuid'i>) → o kişinin hangi salonda,
--       hangi gün bulunacağı DÖNDÜ
--
-- Fonksiyonları tek tek sarmalamak yerine İFADENİN KENDİSİNİ güvenli
-- yapıyoruz: `coalesce(p_user, auth.uid())` → `public.kimlik(p_user)`.
-- Bu, hem `plpgsql` hem `sql` gövdelerde çalışır ve gelecekte aynı ifadeyi
-- yazan bir dosya da nöbetçiye takılır.
--
-- 🆕 SINIF: "'VERİLMEZSE BENİM' DİYEN BİR VARSAYILAN, 'VERİLİRSE ONUN'
-- DEMENİN KİBAR HÂLİDİR."
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.kimlik(p_user uuid)
returns uuid
language plpgsql stable security definer set search_path = public as $k253$
declare v_ben uuid := auth.uid();
begin
  if p_user is null then return v_ben; end if;
  -- Sunucu içi çağrı (cron / service_role): oturum yok, parametre yetkilidir.
  if v_ben is null then return p_user; end if;
  if p_user = v_ben then return v_ben; end if;
  if exists (select 1 from admin_roles ar where ar.user_id = v_ben) then
    return p_user;
  end if;
  raise exception 'baskasinin_verisi';
end $k253$;

revoke all on function public.kimlik(uuid) from public;
revoke all on function public.kimlik(uuid) from anon;
grant execute on function public.kimlik(uuid) to authenticated;
grant execute on function public.kimlik(uuid) to service_role;

do $ik253$
declare r record; v_yeni text; v_say int := 0; v_atlanan text[] := '{}';
begin
  for r in
    select p.oid, p.proname, pg_get_functiondef(p.oid) as tanim
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       -- 🔴 `prokind='f'` ŞART: `pg_get_functiondef` bir TOPLAYICI (aggregate)
       -- ya da pencere fonksiyonu için HATA fırlatır ve tüm döngüyü düşürür.
       -- Yani "tüm fonksiyonları tara" demek, taramanın kendisini kırabilir.
       and p.prokind = 'f'
       and p.proname <> 'kimlik'
       and pg_get_functiondef(p.oid) ~ 'coalesce\(\s*p_user(_id)?\s*,\s*auth\.uid\(\)\s*\)'
     order by p.proname
  loop
    v_yeni := regexp_replace(r.tanim,
      'coalesce\(\s*p_user\s*,\s*auth\.uid\(\)\s*\)', 'public.kimlik(p_user)', 'g');
    v_yeni := regexp_replace(v_yeni,
      'coalesce\(\s*p_user_id\s*,\s*auth\.uid\(\)\s*\)', 'public.kimlik(p_user_id)', 'g');
    if v_yeni = r.tanim then
      v_atlanan := v_atlanan || r.proname;
      continue;
    end if;
    begin
      execute v_yeni;
      v_say := v_say + 1;
    exception when others then
      -- Bir fonksiyon yeniden kurulamıyorsa SESSİZ GEÇMİYORUZ.
      raise exception '253 §4: % yeniden kurulamadi: %', r.proname, sqlerrm;
    end;
  end loop;
  raise notice '253 §4: % fonksiyona sahiplik kapisi takildi.', v_say;
  if array_length(v_atlanan,1) is not null then
    raise notice '253 §4: degismeyen: %', array_to_string(v_atlanan, ', ');
  end if;
end $ik253$;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — SUNUCUYA AİT KOLONLAR İSTEMCİDEN ALINIYOR
--
-- Ölçülmüş sömürü (rollback'li):
--     update profiles set linkedin_verified = true  → UPDATE 1  (rozet)
--     update profiles set founding_host_no  = 1     → UPDATE 1  (kurucu no)
--     update users    set gender = 'female'         → UPDATE 1  (güvenlik modu)
--
-- Sonuncusu en ağırı: kadın güvenlik modu `u.gender = 'female'` üzerinden
-- çalışıyor. Erkek bir hesap tek `update` ile yalnız kadınların görünmesini
-- isteyen kadınların listesine giriyordu.
--
-- 🔴 VE 232 BUNU KAPATMAYA ÇALIŞMIŞTI: kapı listesinde `show_on_discover`
-- yazıyordu, gerçek kolon adı `show_on_discovery`. Yazım hatası sessizce
-- kapıyı açık bıraktı.
-- 🆕 SINIF: "ADIYLA ARANAN BİR KOLON, ADI YANLIŞSA KORUNMUŞ DEĞİL
-- ARANMAMIŞTIR — VE ARAMA HATA VERMEZ."
-- ════════════════════════════════════════════════════════════════════════

do $k5253$
declare r record; v_say int := 0;
begin
  for r in
    select unnest(array['linkedin_verified','founding_host_no','referred_by',
                        'referral_code','show_on_discovery','trust_score']) as kol
  loop
    if exists (select 1 from information_schema.columns
                where table_schema='public' and table_name='profiles'
                  and column_name = r.kol) then
      execute format('revoke update (%I) on public.profiles from authenticated', r.kol);
      execute format('revoke update (%I) on public.profiles from anon', r.kol);
      v_say := v_say + 1;
    else
      -- 🔴 SESSİZ GEÇMİYORUZ: 232'nin hatası tam da buydu.
      raise notice '253 §5: profiles.%s kolonu YOK — atlandi (ad dogru mu?)', r.kol;
    end if;
  end loop;
  raise notice '253 §5: profiles uzerinde % kolon yazmaya kapatildi.', v_say;
end $k5253$;

revoke update (gender) on public.users from authenticated;
revoke update (gender) on public.users from anon;

-- (`contact_email` §5b'de tabloyu tamamen terk etti.)

-- ────────────────────────────────────────────────────────────────────────
-- §5b — `contact_email` KENDİ TABLOSUNA TAŞINIYOR
--
-- 🔴 KOLON DÜZEYİNDE `revoke select` YETMEDİ — ölçtüm:
--     has_column_privilege('authenticated','profiles','contact_email','select')
--       → hâlâ TRUE
-- Çünkü PostgreSQL'de TABLO düzeyindeki `SELECT` hakkı, kolon düzeyindeki
-- iptali EZER. Bu projede bu dersi daha önce de almıştık.
-- 🆕 SINIF: "KOLONDAN ALINAN BİR HAK, TABLODAN VERİLMİŞSE ALINMAMIŞTIR."
--
-- `profiles` tablosu tasarımı gereği BAŞKALARI tarafından okunuyor (keşif,
-- profil kartı). Bir e-posta adresi orada duramaz. Kendi tablosuna alıyoruz:
-- satır politikası YALNIZ sahibine açık.
-- ────────────────────────────────────────────────────────────────────────

create table if not exists user_contact (
  user_id       uuid primary key references users(id) on delete cascade,
  contact_email text,
  updated_at    timestamptz not null default now()
);
alter table user_contact enable row level security;
drop policy if exists user_contact_self on user_contact;
create policy user_contact_self on user_contact for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke all on user_contact from anon;
grant select, insert, update on user_contact to authenticated;
grant select, insert, update on user_contact to service_role;

do $ce2253$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='profiles'
                and column_name='contact_email') then
    -- Veriyi TAŞI (kopyala), sonra kolonu düşür. Önce kopyalamadan düşürmek
    -- kullanıcıların yazdığı adresleri sessizce silerdi.
    insert into user_contact (user_id, contact_email)
    select user_id, contact_email from profiles
     where coalesce(btrim(contact_email),'') <> ''
    on conflict (user_id) do update set contact_email = excluded.contact_email;
    alter table profiles drop column contact_email;
    raise notice '253 §5b: contact_email `user_contact` tablosuna tasindi.';
  else
    raise notice '253 §5b: contact_email zaten yok — dokunulmadi.';
  end if;
end $ce2253$;

create or replace function public.iletisim_epostam()
returns text
language sql stable security definer set search_path = public as $ie253$
  select coalesce(
    (select c.contact_email from user_contact c where c.user_id = auth.uid()),
    (select u.email from users u where u.id = auth.uid()));
$ie253$;

create or replace function public.iletisim_epostam_yaz(p_eposta text)
returns jsonb
language plpgsql security definer set search_path = public as $iey253$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if coalesce(btrim(p_eposta),'') <> ''
     and p_eposta !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' then
    return jsonb_build_object('ok', false, 'reason', 'gecersiz_eposta');
  end if;
  insert into user_contact (user_id, contact_email, updated_at)
  values (v_uid, nullif(btrim(p_eposta),''), now())
  on conflict (user_id) do update
    set contact_email = excluded.contact_email, updated_at = now();
  return jsonb_build_object('ok', true);
end $iey253$;

grant execute on function public.iletisim_epostam() to authenticated;
grant execute on function public.iletisim_epostam_yaz(text) to authenticated;

-- Cinsiyet beyanı bir KEZ yazılır; sonrası moderasyon işidir.
create or replace function public.trg_cinsiyet_kilidi() returns trigger
language plpgsql security definer set search_path = public as $tck253$
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
end $tck253$;

drop trigger if exists trg_cinsiyet_kilidi on users;
create trigger trg_cinsiyet_kilidi before update of gender on users
  for each row execute function public.trg_cinsiyet_kilidi();

-- ════════════════════════════════════════════════════════════════════════
-- §6 — `profile_visibility` ARTIK BİR ŞEY İFADE EDİYOR
--
-- Ölçüm: 45 profilin 19'u 'Trusted+' seçmiş ve `profiles_read_auth`
-- politikası `using (true)`. Yani ayar HİÇBİR YERDE uygulanmıyordu —
-- ne tabloda, ne `discover_people` gövdesinde.
--
-- 🆕 SINIF: "DEĞİŞTİRİLEBİLEN AMA HİÇBİR ŞEYİ DEĞİŞTİRMEYEN BİR AYAR,
-- BİR AYAR DEĞİL BİR SÜSTÜR — VE GİZLİLİK AYARIYSA BİR YALANDIR."
--
-- ⚠️ KEŞİF DARALMIYOR: keşif `SECURITY DEFINER` RPC'lerden geçtiği için
-- RLS ona uygulanmaz. Değişen tek şey, keşifte gördüğün kartın ARDINDAKİ
-- tam profili açabilmen. Arz kaybı YOK; ölçüldü (§9 nöbetçisi).
-- ════════════════════════════════════════════════════════════════════════

insert into beta_settings (key, value) values
  ('profil_trusted_esik', to_jsonb(40))
on conflict (key) do nothing;

create or replace function public.profil_gorunur_mu(p_target uuid)
returns boolean
language plpgsql stable security definer set search_path = public as $pg253$
declare v_ben uuid := auth.uid(); v_gor text; v_esik int; v_puan int;
begin
  if v_ben is null then return false; end if;
  if p_target = v_ben then return true; end if;

  -- Aramızda gerçek bir ilişki varsa görünürlük tercihi devreye girmez:
  -- bir isteği kabul etmiş ya da göndermiş kişi zaten karşılaşmıştır.
  if exists (select 1 from connection_requests c
              where ((c.from_id = v_ben and c.to_id = p_target)
                  or (c.to_id = v_ben and c.from_id = p_target))
                and c.status in ('pending','accepted'))
     or exists (select 1 from requests r
                 where (r.guest_id = v_ben and r.host_id = p_target)
                    or (r.host_id = v_ben and r.guest_id = p_target))
  then
    return true;
  end if;

  select coalesce(profile_visibility::text, 'Everyone') into v_gor
    from profiles where user_id = p_target;
  if v_gor is null then return false; end if;
  if v_gor = 'Everyone' then return true; end if;
  if v_gor = 'Connections' then return false; end if;

  -- 'Trusted+' → bakanın güven puanı eşiği geçmeli.
  v_esik := coalesce((select (value #>> '{}')::int from beta_settings
                       where key = 'profil_trusted_esik'), 40);
  select score into v_puan from trust_scores where user_id = v_ben;
  return coalesce(v_puan, 0) >= v_esik;
end $pg253$;

grant execute on function public.profil_gorunur_mu(uuid) to authenticated;
grant execute on function public.profil_gorunur_mu(uuid) to service_role;

drop policy if exists profiles_read_auth on profiles;
create policy profiles_read_auth on profiles for select to authenticated
  using (public.profil_gorunur_mu(user_id));

drop policy if exists trust_read_auth on trust_scores;
create policy trust_read_auth on trust_scores for select to authenticated
  using (public.profil_gorunur_mu(user_id));

-- ════════════════════════════════════════════════════════════════════════
-- §7 — `chat_channels` POLİTİKASI KENDİNİ DELİYORDU
--
-- `chat_companion_read` ifadesi `(connection_id IS NULL) OR (...)` diye
-- başlıyordu. İstek tabanlı kanallarda `connection_id` HER ZAMAN NULL —
-- yani ilk dal her giriş yapana bütün kanalları açıyordu. RLS politikaları
-- OR'landığı için doğru yazılmış ikinci politika bunu telafi etmiyor.
--
-- 🆕 SINIF: "AYNI TABLODA ÜÇ POLİTİKA, BİRİNİN DİĞERİNİ DELMESİNİ
-- KAÇINILMAZ KILAR — ÇÜNKÜ RLS ONLARI 'VEYA' İLE BİRLEŞTİRİR."
-- ════════════════════════════════════════════════════════════════════════

drop policy if exists chat_companion_read on chat_channels;
drop policy if exists chan_parties on chat_channels;
-- 🔴 KENDİ ADINI DA DÜŞÜR: tekrar kurulumda "already exists" verirdi.
-- Bir dosya yalnız boş veritabanında çalışıyorsa, migration değil kurulumdur.
drop policy if exists chat_taraf_okur on chat_channels;
create policy chat_taraf_okur on chat_channels for select to authenticated
  using (
    (connection_id is not null and exists (
       select 1 from connection_requests c
        where c.id = chat_channels.connection_id
          and (c.from_id = auth.uid() or c.to_id = auth.uid())))
    or
    (request_id is not null and exists (
       select 1 from requests r
        where r.id = chat_channels.request_id
          and (r.guest_id = auth.uid() or r.host_id = auth.uid())))
  );

-- ════════════════════════════════════════════════════════════════════════
-- §8 — `phone_in_use` NUMARA TARAMA SERVİSİ OLMAKTAN ÇIKIYOR
--
-- Sınırsız çağrılabilen bir "bu numara kayıtlı mı" ucu, elindeki numara
-- listesinin hangilerinin kullanıcımız olduğunu söyler. Bu, KVKK açısından
-- "bir kişinin belirli bir hizmeti kullandığı" bilgisidir.
-- ════════════════════════════════════════════════════════════════════════

do $pin253$
declare v_tanim text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p where p.oid = to_regprocedure('public.phone_in_use(text)');
  if v_tanim is null then
    raise notice '253 §8: phone_in_use YOK — dokunulmadi.'; return;
  end if;
  if v_tanim like '%rate_limits%' then
    raise notice '253 §8: hiz siniri zaten var — dokunulmadi.'; return;
  end if;
end $pin253$;

create or replace function public.phone_in_use(p_phone text)
returns boolean
language plpgsql stable security definer set search_path = public as $piu253$
declare v_ben uuid := auth.uid(); v_say int;
begin
  if v_ben is null then raise exception 'not_authenticated'; end if;
  -- 🔴 Saatte 10 sorgu. Kayıt akışının ihtiyacı 1-2; tarama yapanın
  -- ihtiyacı binlerce. Aradaki fark kapının kendisidir.
  select count into v_say from rate_limits
   where user_id = v_ben and action = 'phone_in_use'
     and window_start = date_trunc('hour', now());
  if coalesce(v_say, 0) >= 10 then raise exception 'too_many_requests'; end if;
  insert into rate_limits (user_id, action, window_start, count)
  values (v_ben, 'phone_in_use', date_trunc('hour', now()), 1)
  on conflict (user_id, action, window_start) do update set count = rate_limits.count + 1;

  return exists (
    select 1 from users u
     where u.deleted_at is null and u.id <> v_ben
       and regexp_replace(coalesce(u.phone,''), '\D', '', 'g')
         = regexp_replace(coalesce(p_phone,''), '\D', '', 'g')
       and coalesce(p_phone,'') <> '');
end $piu253$;

grant execute on function public.phone_in_use(text) to authenticated;

-- ⚠️ `phone_in_use` STABLE değil artık (yazıyor). STABLE bırakmak
-- PostgreSQL'in çağrıyı atlamasına yol açabilirdi — yani sayaç
-- artmayabilirdi. Bu yüzden VOLATILE:
alter function public.phone_in_use(text) volatile;

-- ════════════════════════════════════════════════════════════════════════
-- §9 — `my_plan` HER ÇAĞRIDA PATLIYORDU (42883)
--
--   ERROR: operator does not exist: text = plan_type
--   CONTEXT: my_plan(uuid) line 52 → select * from plan_catalog
--            where plan::text = v_etkin
--
-- `v_etkin` `plan_type` tipinde bir değişken ama içine `::text` cast
-- edilmiş değer atanıyor. `plan_kredisi_yerlestir` hatayı yutuyor ve
-- `{"ok":false}` dönüyordu — yani AYLIK KREDİ YÜKLEMESİ sessizce
-- çalışmıyordu.
--
-- 🆕 SINIF: "BİR HATAYI YUTAN İŞ, ÇALIŞMADIĞINI DA YUTAR."
-- ════════════════════════════════════════════════════════════════════════

do $mp253$
declare r record; v_yeni text; v_say int := 0;
begin
  for r in
    select p.oid, p.proname, pg_get_functiondef(p.oid) as tanim
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
       and pg_get_functiondef(p.oid) like '%plan::text = v_etkin%'
  loop
    v_yeni := replace(r.tanim, 'plan::text = v_etkin', 'plan = v_etkin');
    execute v_yeni;
    v_say := v_say + 1;
    raise notice '253 §9: % icindeki tip uyusmazligi duzeltildi.', r.proname;
  end loop;
  if v_say = 0 then raise notice '253 §9: kalip bulunamadi — dokunulmadi.'; end if;
end $mp253$;

-- ════════════════════════════════════════════════════════════════════════
-- §10 — `anon` ROLÜNDEN İŞE YARAMAYAN YAZMA HAKLARI
--
-- Bugün zararsız (politikalar `auth.uid()` istiyor, `anon`da o NULL).
-- Ama bir politikanın şartı gevşediği gün kapı hazır bekliyor olur.
-- ════════════════════════════════════════════════════════════════════════

do $an253$
declare r record;
begin
  for r in
    select table_name, privilege_type
      from information_schema.role_table_grants
     where grantee = 'anon' and table_schema = 'public'
       and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')
       -- `waitlist` bilinçli: giriş yapmamış ziyaretçi bekleme listesine
       -- yazabilmeli (`with check (consent = true)` koruyor).
       and table_name <> 'waitlist'
  loop
    execute format('revoke %s on public.%I from anon', r.privilege_type, r.table_name);
  end loop;
end $an253$;

-- ════════════════════════════════════════════════════════════════════════
-- §11 — MİGRATION DEFTERİ: TAHMİN ETMEYİ BIRAKIYORUZ
--
-- Bu projede hangi SQL'in koştuğu bugüne kadar İZDEN çıkarılıyordu ve
-- 278 dosyanın 49'u iz bırakmıyordu. Bundan sonra her dosya kendini
-- yazsın; tahmin bitsin.
--
-- 🆕 SINIF: "TESPİT EDİLEMEYENİ TAHMİN ETMEK YERİNE TESPİT EDİLEBİLİR YAP."
-- ════════════════════════════════════════════════════════════════════════

-- Defter §0'da kuruldu. Bundan sonraki HER migration son satırında
-- `select public.migration_kaydet('<dosya adı>');` çağırmalı —
-- `sqlcheck.py` bunu artık zorunlu tutuyor.
revoke all on schema_migrations from anon;
revoke all on schema_migrations from authenticated;
grant select, insert, update on schema_migrations to service_role;

select public.migration_kaydet('253_guvenlik_kapanisi.sql');

-- ════════════════════════════════════════════════════════════════════════
-- §12 — NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════

do $n253$
declare
  v_h text[] := '{}';
  v_n int; v_r record; v_b boolean; v_ben uuid; v_oteki uuid;
begin
  begin
    -- (1) Hiçbir görünüm istemciye açık kalmamalı.
    select count(*) into v_n
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname='public' and c.relkind in ('v','m')
       and has_table_privilege('anon', c.oid, 'select');
    if v_n > 0 then
      v_h := v_h || format('%s gorunum hala ANON`a ACIK', v_n)::text;
    end if;

    -- `authenticated`e açık kalan TEK görünüm `user_balances` olmalı VE
    -- o da `security_invoker` ile RLS'in altında olmalı. İkisini birlikte
    -- ölçüyoruz: hak vermek yetmez, hakkın altında filtre olmalı.
    select count(*) into v_n
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname='public' and c.relkind in ('v','m')
       and has_table_privilege('authenticated', c.oid, 'select')
       and c.relname <> 'user_balances';
    if v_n > 0 then
      v_h := v_h || format('%s gorunum authenticated`e ACIK (yalniz user_balances olmali)', v_n)::text;
    end if;
    if to_regclass('public.user_balances') is not null then
      if not has_table_privilege('authenticated', 'public.user_balances', 'select') then
        v_h := v_h || 'user_balances istemciye KAPALI — app kredi/puan gosteremez'::text;
      end if;
      if not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
                      where n.nspname='public' and c.relname='user_balances'
                        and array_to_string(c.reloptions,',') like '%security_invoker=%on%') then
        v_h := v_h || 'user_balances acik AMA security_invoker KAPALI — RLS atlanir'::text;
      end if;
    end if;

    -- (2) Varsayılan haklar: yeni tablo `anon`a okunur DOĞMAMALI.
    -- ════════════════════════════════════════════════════════════
    -- 🔴 KATALOĞU OKUMAK YANLIŞ SORUYU SORMAKTI.
    --
    -- İlk iki denemem `pg_default_acl`i tarıyordu ve Gökberk'in
    -- veritabanında üç kayıt buldu — üçü de `supabase_admin`in.
    -- Ama `ALTER DEFAULT PRIVILEGES FOR ROLE r`, "r BİR TABLO
    -- OLUŞTURURSA ne olsun" demektir. Bizim migration'larımız
    -- `supabase_admin` olarak değil, kendi rolümüzle tablo oluşturuyor.
    -- Yani o kayıtlar BİZİM tablolarımıza HİÇ uygulanmıyordu.
    --
    -- Nöbetçi var olmayan bir kusuru bildiriyordu — ve daha kötüsü,
    -- gerçek kusuru (bizim rolümüzün kaydı) aynı gürültünün içinde
    -- gizleyebilirdi.
    --
    -- Doğru soru katalogda değil: "ŞİMDİ bir tablo oluşturursam,
    -- `anon` onu okuyabilir mi?" Bu soruyu SORMAK yerine ÖLÇÜYORUZ:
    -- bir deneme tablosu açılıyor, `anon`un hakkı ölçülüyor, tablo
    -- siliniyor. Hangi rolün hangi kaydı verdiği önemsiz — sonuç
    -- doğrudan görülüyor.
    --
    -- 🆕 SINIF: "BİR AYARIN DOĞRU OLUP OLMADIĞINI KATALOGDAN OKUMA —
    -- O AYARIN ETKİSİNİ ÜRET VE ÖLÇ. KATALOG NİYETİ, DENEY SONUCU
    -- SÖYLER."
    -- ════════════════════════════════════════════════════════════
    begin
      execute 'create table public.__dacl_sonda_253 (x int)';
      if has_table_privilege('anon', 'public.__dacl_sonda_253', 'select') then
        v_h := v_h || ('yeni tablolar hala anon''a OKUNUR doguyor — DENEY: '
               || 'public.__dacl_sonda_253 olusturuldu ve anon SELECT alabildi. '
               || '`alter default privileges for role ' || current_user
               || ' in schema public revoke select on tables from anon, authenticated` '
               || 'calistir.')::text;
      end if;
      if has_table_privilege('authenticated', 'public.__dacl_sonda_253', 'select') then
        v_h := v_h || ('yeni tablolar hala authenticated''a OKUNUR doguyor (ayni deney)')::text;
      end if;
      execute 'drop table public.__dacl_sonda_253';
    exception when others then
      begin execute 'drop table if exists public.__dacl_sonda_253'; exception when others then null; end;
      v_h := v_h || ('varsayilan hak DENEYI yapilamadi: ' || sqlerrm)::text;
    end;

    -- (3) change_plan istemciye kapalı olmalı.
    if has_function_privilege('authenticated', 'public.change_plan(plan_type)', 'execute') then
      v_h := v_h || 'change_plan hala istemciye ACIK — odemesiz plan'::text;
    end if;

    -- (4) send_otp kodu yanıtta VERMEMELİ.
    if (select pg_get_functiondef(to_regprocedure('public.send_otp(text)')::oid))
       like '%demo_code%' then
      v_h := v_h || 'send_otp hala demo_code donduruyor'::text;
    end if;

    -- (5) Sahiplik: `coalesce(p_user, auth.uid())` kalıntısı KALMAMALI.
    select count(*) into v_n
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname='public' and p.prokind = 'f'
       and pg_get_functiondef(p.oid) ~ 'coalesce\(\s*p_user(_id)?\s*,\s*auth\.uid\(\)\s*\)';
    if v_n > 0 then
      v_h := v_h || format('%s fonksiyonda sahipliksiz kalip DURUYOR', v_n)::text;
    end if;

    -- (6) `kimlik()` gerçekten reddediyor mu — DAVRANIŞ ölçümü.
    begin
      -- 🔴 YÖNETİCİ SEÇMEMEK ŞART: `kimlik()` yöneticiye bilerek izin veriyor.
      -- İlk denemede sıradaki ilk kullanıcıyı seçtim ve nöbetçi "kabul etti"
      -- dedi — kapı çalışıyordu, ÖLÇÜM yanlıştı.
      -- 🆕 SINIF: "BİR KAPIYI, ANAHTARI OLAN BİRİYLE DENEMEK KAPIYI DEĞİL
      -- ANAHTARI ÖLÇER."
      select u.id into v_ben from users u
       where u.deleted_at is null
         and not exists (select 1 from admin_roles a where a.user_id = u.id)
       order by u.created_at limit 1;
      select u.id into v_oteki from users u
       where u.deleted_at is null and u.id <> v_ben
       order by u.created_at desc limit 1;
      if v_ben is null or v_oteki is null then
        v_h := v_h || 'olcum icin iki yonetici-olmayan kullanici bulunamadi'::text;
      end if;
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_ben::text)::text, true);
      begin
        perform public.kimlik(v_oteki);
        v_h := v_h || 'kimlik() BASKASININ uuid`ini kabul etti'::text;
      exception when others then
        if sqlerrm not like '%baskasinin_verisi%' then
          v_h := v_h || ('kimlik() beklenmeyen hata: ' || sqlerrm)::text;
        end if;
      end;
      -- Kendi kimliğim geçmeli.
      if public.kimlik(null) is null then
        v_h := v_h || 'kimlik(null) kendi kimligimi DONDURMEDI'::text;
      end if;
      perform set_config('request.jwt.claims', '', true);
    exception when others then
      perform set_config('request.jwt.claims', '', true);
      v_h := v_h || ('kimlik olcumu coktu: ' || sqlerrm)::text;
    end;

    -- (7) Kolon kapıları.
    if has_column_privilege('authenticated', 'public.profiles', 'linkedin_verified', 'update')
       or has_column_privilege('authenticated', 'public.profiles', 'founding_host_no', 'update')
       or has_column_privilege('authenticated', 'public.users'::regclass::text, 'gender', 'update') then
      v_h := v_h || 'sunucuya ait kolonlar hala istemciden YAZILABILIR'::text;
    end if;

    -- (7b) `contact_email` artık `profiles` üzerinde OLMAMALI.
    if exists (select 1 from information_schema.columns
                where table_schema='public' and table_name='profiles'
                  and column_name='contact_email') then
      v_h := v_h || 'contact_email hala profiles uzerinde — herkese acik tabloda e-posta'::text;
    end if;
    if has_table_privilege('anon', 'public.user_contact', 'select') then
      v_h := v_h || 'user_contact anon`a ACIK'::text;
    end if;

    -- (8) Görünürlük yüklemi gerçekten ayırt ediyor mu.
    if public.profil_gorunur_mu(null) then
      v_h := v_h || 'profil_gorunur_mu(null) TRUE dondu'::text;
    end if;

    -- (9) 🔴 ARZ KAYBI OLMAMALI: keşif RPC'leri SECURITY DEFINER olduğu
    -- için RLS daralmasından ETKİLENMEMELİ. Sayıyla kanıtla.
    select count(*) into v_n from public.discover_availabilities();
    if v_n = 0 then
      v_h := v_h || 'kesif ilan sayisi 0 — RLS daralmasi arzi VURMUS olabilir'::text;
    end if;

    -- (10) chat_channels: tek politika kalmalı ve `connection_id is null`
    -- deliği gitmiş olmalı.
    if exists (select 1 from pg_policies where schemaname='public' and tablename='chat_channels'
                and qual like '%connection_id IS NULL%') then
      v_h := v_h || 'chat_channels`de `connection_id IS NULL` deligi DURUYOR'::text;
    end if;

    -- (11) Defter yazıyor mu.
    if not exists (select 1 from schema_migrations
                    where dosya = '253_guvenlik_kapanisi.sql' and kaynak = 'migration') then
      v_h := v_h || 'migration defterine YAZILMADI'::text;
    end if;

    raise exception 'GERI_AL_253';
  exception when others then
    if sqlerrm <> 'GERI_AL_253' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '253 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '253 OK · gorunumler kapali · plan odemesiz degistirilemez · otp kodu sizmiyor · sahiplik kapisi 23 fonksiyonda · gorunurluk uygulaniyor';
end $n253$;

-- 🔴 `kimlik` ve `profil_gorunur_mu` YÜZEYE YAZILMADI — bilerek.
-- Nöbetçi ilk denemede haklı olarak kırmızı yandı: ikisi de app tarafından
-- ÇAĞRILMIYOR. `kimlik` SECURITY DEFINER gövdelerin içinden, o gövdelerin
-- sahibi haklarıyla çalışıyor; `profil_gorunur_mu` ise RLS politikasından
-- çağrılıyor (o yüzden `authenticated` hakkı ŞART, ama bir "ekran ucu" değil).
-- 🆕 SINIF: "BİR FONKSİYONU İSTEMCİ YÜZEYİNE YAZMAK, ONU İSTEMCİ ÇAĞIRIYOR
-- DEMEK DEĞİL — YÜZEY BİR SÖZDÜR, TUTULMAZSA KAYIT YALAN OLUR."
revoke all on function public.kimlik(uuid) from authenticated;

insert into rpc_client_surface (fn_name, client, note) values
  ('iletisim_epostam', 'app', 'Iletisim e-postasi — profiles`tan cikarildi (253)'),
  ('iletisim_epostam_yaz', 'app', 'Iletisim e-postasini yaz (253)')
on conflict (fn_name) do update set note = excluded.note;

commit;

select '253 KURULDU' as sonuc,
       (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and c.relkind in ('v','m')
           and has_table_privilege('anon', c.oid, 'select'))            as acik_gorunum,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.prokind = 'f'
           and pg_get_functiondef(p.oid) ~ 'coalesce\(\s*p_user(_id)?\s*,\s*auth\.uid\(\)\s*\)') as sahipliksiz;
