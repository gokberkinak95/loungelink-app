-- ============================================================================
-- LoungeLink · 232_rol_kapisi_ve_cuzdan_sizintisi.sql       (22 Ağustos 2026)
--
-- GÖKBERK'İN 12. MADDESİNİ ARAŞTIRIRKEN İKİ GERÇEK AÇIK ÇIKTI
--
-- Sorulan şuydu: "misafir olarak kaydolan birinin ilan açışı / lounge hakkı
-- kurulumu gibi host'a özel sayfaları göremediğinden emin ol."
--
-- Ekranları gizlemek için baktım; altında iki tane bundan ciddi şey buldum.
--
-- ════════════════════════════════════════════════════════════════════════
-- AÇIK 1 · İSTEMCİ KENDİ ROLÜNÜ YAZABİLİYORDU
-- ════════════════════════════════════════════════════════════════════════
--   207_kopruler_ve_verilen_sozler.sql:71
--       grant update (role, gender) on public.users to authenticated;
--   001_initial_schema.sql:487
--       create policy "users_own" on users for all using (auth.uid() = id);
--
-- Yani herhangi bir misafir tek satırla host oluyordu:
--       supabase.from("users").update({ role: "host" }).eq("id", uid)
-- App bunu ZATEN İKİ YERDE yapıyor (screens.js:798, App.js:348).
--
-- 🔴 Sonuç: app'teki `role === "host" ? <Hosting/> : null` kapılarının
-- HEPSİ, istemcinin kendi yazdığı bir değere bakıyordu. Ekranı gizlemek
-- bir şey ifade etmiyordu; kapının anahtarı kapının dışındaydı.
--
-- 🆕 SINIF: **"KENDİ YAZDIĞI DEĞERE BAKAN KAPI, KAPI DEĞİLDİR."**
--
-- ════════════════════════════════════════════════════════════════════════
-- AÇIK 2 · host_wallet(p_user) BAŞKASININ CÜZDANINI AÇIYORDU
-- ════════════════════════════════════════════════════════════════════════
--   208_donem_devri_ve_kalibrasyon.sql:38
--       create or replace function public.host_wallet(p_user uuid default null)
--       ... v_uid uuid := coalesce(p_user, auth.uid());
--
-- `security definer`, istemciye açık, ve p_user için SAHİPLİK KONTROLÜ YOK.
-- Herhangi bir oturum açmış kullanıcı bir başkasının uuid'sini geçirip o
-- kişinin kart programını, statüsünü, kart etiketini, kotasını, kalan
-- hakkını ve parasal değerini okuyabiliyordu. Kardeş fonksiyon
-- `set_card_bank_coverage` (201:108) sahipliği kontrol ediyor; bu etmiyordu.
--
-- ⚠️ Bu bir KVKK meselesi: kart programı + statü + kalan hak, kişinin
-- seyahat alışkanlığı ve gelir seviyesi hakkında çıkarım yapılabilecek
-- veridir.
--
-- ════════════════════════════════════════════════════════════════════════
-- AÇIK 3 · profiles TABLO DÜZEYİNDE YAZILABİLİYORDU
-- ════════════════════════════════════════════════════════════════════════
--   159_grants_home_flows_request_gate.sql:51
--       grant update on public.profiles to authenticated;   ← KOLON YOK
--
-- `create_availability`'nin tek gerçek ön koşulu
-- `profiles.guest_capacity is not null` (055). O kolon istemciden
-- doğrudan yazılabildiği için ön koşul bir kapı değil, bir formaliteydi.
-- App zaten doğrudan yazıyor (screens.js:781).
--
-- ⚠️ NE YAPMIYORUM: "ilan açmak = host olmak" tasarımını değiştirmiyorum
-- (055'in kararı, doğru karar). Değiştirdiğim tek şey, o geçişin
-- İSTEMCİNİN DEĞİL SUNUCUNUN elinde olması.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) ROL ARTIK İSTEMCİDEN YAZILAMAZ
-- ----------------------------------------------------------------------------
-- 🔴 22 AĞUSTOS DÜZELTMESİ (v2) — İLK SÜRÜM CANLIDA PATLADI:
--     "232 NOBETCI: profiles kapi kolonlari hala yazilabilir (3 grant)"
--
-- Sebep, iki ayrı Postgres kuralı ve benim ikisini de atlamış olmam:
--
--  1) KOLON REVOKE'U, TABLO GRANT'INI DELMEZ. Rol `update on tbl`
--     hakkına sahipse `revoke update (role) on tbl` HİÇBİR ŞEY yapmaz —
--     tablo hakkı bütün kolonları kapsamaya devam eder. Önce TABLO
--     hakkını almak, sonra kolonları tek tek geri vermek gerekir.
--
--  2) SUPABASE `anon`A DA VERİR. Supabase projesi
--     `alter default privileges ... grant all on tables to anon,
--     authenticated, service_role` ile gelir; yani her yeni tablo bu üç
--     role AÇIK doğar. Ben yalnız `authenticated`tan aldım. Kalan 3
--     grant tam olarak `anon`un üç kapı kolonuydu.
--
-- 🆕 SINIF: **"BİR HAKKI KOLONDAN ALMAK, O HAK TABLODAN VERİLMİŞSE
-- HİÇBİR ŞEY ALMAMAKTIR."**
--
-- Ve asıl mesele nöbetçinin değil ORTAMIN kusuruydu: harness boş bir
-- Postgres'ten başlıyordu, orada `anon`un hiçbir hakkı yoktu, dolayısıyla
-- "grant kapandı mı?" sorusu kapanacak grant'ın hiç olmadığı bir dünyada
-- soruluyordu. pg_run.py artık Supabase'in başlangıç grant'larını taklit
-- ediyor; bu dosya orada da kırmızı yandı ve öyle düzeltildi.
revoke update on public.users from authenticated;
revoke update on public.users from anon;
revoke update (role) on public.users from authenticated;
revoke update (role) on public.users from anon;
-- `gender` kalıyor: kişinin kendi beyanı, hiçbir yetki kapısı ona bakmıyor.
grant update (gender) on public.users to authenticated;

-- Rolün NEREDEN geldiğini kayda geçiriyoruz. Bugüne kadar bir host'un
-- nasıl host olduğu hiçbir yerde yazmıyordu: kendi mi beyan etti, ilan mı
-- açtı, admin mi onayladı? BO bunu göremiyordu.
alter table users add column if not exists role_source text;
alter table users add column if not exists role_changed_at timestamptz;
comment on column users.role_source is
  'beyan = kullanici kayitta secti · ilan = create_availability terfi ettirdi · '
  'basvuru = apply_for_host onaylandi · admin = elle · geri = kullanici misafire dondu';

-- ----------------------------------------------------------------------------
-- 2) TEK KAPI: rolumu_sec()
-- ----------------------------------------------------------------------------
-- 🔴 GEÇİŞİ ENGELLEMİYORUM, KAPIYA ALIYORUM.
-- Ürün tasarımı "ilan açan host olur" diyor; bunu bozarsam kayıt akışı
-- kırılır (yeni kullanıcı "host olacağım" deyip erişim kurulumuna gidiyor,
-- henüz hiçbir hakkı yok). Ama artık:
--   · tek bir yerden geçiyor         → yarın kural eklenecekse yeri belli
--   · kaynağı yazılıyor              → BO kimin nasıl host olduğunu görür
--   · audit_log'a düşüyor            → geriye dönük denetlenebilir
--   · misafire dönüş serbest         → kimse kendi hesabında kilitlenmez
create or replace function public.rolumu_sec(p_role text, p_gender text default null)
returns jsonb language plpgsql security definer set search_path = public as $rs$
declare
  v_uid   uuid := auth.uid();
  v_eski  user_role;
  v_yeni  user_role;
  v_kay   text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_role is null or p_role not in ('guest','host') then
    raise exception 'gecersiz_rol';
  end if;

  select role into v_eski from users where id = v_uid;
  v_yeni := p_role::user_role;

  if v_eski = v_yeni then
    -- Cinsiyet beyanı gelmişse yine de yaz; boşa dönüş verme.
    if p_gender is not null then
      update users set gender = p_gender::user_gender where id = v_uid;
    end if;
    return jsonb_build_object('ok', true, 'rol', v_yeni::text, 'degisti', false);
  end if;

  v_kay := case when v_yeni = 'host' then 'beyan' else 'geri' end;

  update users
     set role = v_yeni,
         role_source = v_kay,
         role_changed_at = now(),
         gender = coalesce(p_gender::user_gender, gender)
   where id = v_uid;

  insert into audit_log (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_uid, 'user.role_change', 'users', v_uid,
          jsonb_build_object('role', v_eski::text),
          jsonb_build_object('role', v_yeni::text, 'source', v_kay));

  return jsonb_build_object('ok', true, 'rol', v_yeni::text, 'degisti', true);
end $rs$;
grant execute on function public.rolumu_sec(text, text) to authenticated;

-- `create_availability` terfisi de kaynağını yazsın. Fonksiyonun gövdesine
-- DOKUNMUYORUM (bu projede en çok dokunulan fonksiyon ve her dokunuşta bir
-- şey bozuldu — 206'nın notu). Tetikleyiciyle ekliyorum.
create or replace function public.trg_rol_kaynagi()
returns trigger language plpgsql security definer set search_path = public as $rk$
begin
  if new.role is distinct from old.role then
    new.role_changed_at := now();
    if new.role_source is not distinct from old.role_source then
      -- rolumu_sec kaynağı zaten yazdıysa dokunma; yazmayan tek yol
      -- create_availability'nin doğrudan update'i.
      new.role_source := case when new.role = 'host' then 'ilan' else 'geri' end;
    end if;
  end if;
  return new;
end $rk$;
drop trigger if exists trg_users_rol_kaynagi on users;
create trigger trg_users_rol_kaynagi before update of role on users
  for each row execute function public.trg_rol_kaynagi();

-- ----------------------------------------------------------------------------
-- 3) profiles: KOLON DÜZEYİNDE YAZMA
-- ----------------------------------------------------------------------------
-- `guest_capacity` ve `access_source` artık yalnız `save_host_access()`
-- üzerinden yazılır — o fonksiyon kotayı, statüyü ve kart ürününü birlikte
-- tutarlı yazıyor; doğrudan update ise yalnız bir kolonu değiştirip geri
-- kalanı tutarsız bırakıyordu.
revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;          -- ← v2: eksik olan satır
revoke update (guest_capacity, access_source, guest_fee_expected)
  on public.profiles from authenticated;
revoke update (guest_capacity, access_source, guest_fee_expected)
  on public.profiles from anon;
grant update (
  name, profession, bio, languages, linkedin_url, photo_url,
  updated_at
) on public.profiles to authenticated;

-- 🔴 Yukarıdaki listeye SONRADAN eklenen kolonlar dahil değil; hangileri
-- var, ölçerek ekliyorum. Elle liste tutmak bu projede üç kez eksik kaldı
-- (site paleti dersi). Aşağıdaki blok "istemcinin yazması ZARARSIZ" olan
-- kolonları veriden türetir: kapı kolonları hariç HEPSİ.
do $pg$
declare
  v_kolon text;
  v_kapi  text[] := array[
    'user_id','guest_capacity','access_source','guest_fee_expected',
    'created_at','trust_score','show_on_discover'
  ];
  v_n int := 0;
begin
  for v_kolon in
    select column_name from information_schema.columns
     where table_schema='public' and table_name='profiles'
       and column_name <> all (v_kapi)
       and is_generated = 'NEVER'
  loop
    execute format('grant update (%I) on public.profiles to authenticated', v_kolon);
    v_n := v_n + 1;
  end loop;
  raise notice '232: profiles uzerinde % kolon istemciye yazilabilir, % kapi kolonu kapali',
    v_n, array_length(v_kapi,1);
end $pg$;

-- ----------------------------------------------------------------------------
-- 4) host_wallet: BAŞKASININ CÜZDANI KAPANDI
-- ----------------------------------------------------------------------------
-- sqlcheck: allow-replace host_wallet  (returns jsonb — 206/208 ile AYNI tip)
--
-- Gövdeyi yeniden yazmıyorum: 208'in hesabı (kalan hak, değer, dönem devri)
-- olduğu gibi kalsın. Yaptığım tek şey ÖNÜNE BİR KAPI KOYMAK — sarmalayıcı
-- değil, aynı fonksiyonun başına eklenen üç satır.
do $hw$
declare v_govde text;
begin
  select pg_get_functiondef(p.oid) into v_govde
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   -- 🔴 250'DE AYRIŞTIRILDI: kapı artık `host_wallet`te, hesap
   -- `host_wallet_hesap`ta. Bu nöbetçi İKİSİNE BİRDEN bakar; aksi hâlde
   -- doğru bir mimari düzeltmeyi ihlal sanardı.
   -- 🆕 SINIF: "BİR NÖBETÇİ TEK BİR FONKSİYON ADINA KİLİTLİYSE, O
   -- FONKSİYON BÖLÜNDÜĞÜ GÜN KÖRLEŞİR."
   where n.nspname='public' and p.proname in ('host_wallet','host_wallet_hesap') limit 1;

  if v_govde is null then
    raise notice '232: host_wallet bulunamadi — kapi kurulamadi (bos veritabani?)';
    return;
  end if;

  -- Zaten kapı varsa iki kez ekleme (idempotent).
  if v_govde like '%cuzdan_sahibi_degil%' then
    raise notice '232: host_wallet kapisi ZATEN var — dokunulmadi';
    return;
  end if;

  -- İlk `begin`den sonraya kapıyı yerleştir.
  v_govde := regexp_replace(
    v_govde,
    '(\mbegin\M)',
    'begin' || E'\n' ||
    '  if p_user is not null and p_user <> auth.uid()' || E'\n' ||
    '     and not exists (select 1 from admin_roles where user_id = auth.uid()) then' || E'\n' ||
    '    raise exception ''cuzdan_sahibi_degil'';' || E'\n' ||
    '  end if;',
    ''   -- yalnız İLK eşleşme
  );
  execute v_govde;
  raise notice '232: host_wallet kapisi kuruldu (p_user yalniz kendisi ya da admin)';
end $hw$;

-- ----------------------------------------------------------------------------
-- 5) NÖBETÇİ — üç açığı da DENEYEREK ölç
-- ----------------------------------------------------------------------------
do $n232$
declare
  v_rol_grant int;
  v_prof_grant int;
  v_kapi int;
begin
  -- (a) rol kolonu istemciye kapalı mı?
  select count(*) into v_rol_grant
    from information_schema.column_privileges
   where table_schema='public' and table_name='users' and column_name='role'
     and privilege_type='UPDATE' and grantee in ('authenticated','anon');
  if v_rol_grant <> 0 then
    raise exception '232 NOBETCI: users.role hala istemciye YAZILABILIR (% grant) → %',
      v_rol_grant,
      (select string_agg(grantee, ', ' order by grantee)
         from information_schema.column_privileges
        where table_schema='public' and table_name='users' and column_name='role'
          and privilege_type='UPDATE' and grantee in ('authenticated','anon'));
  end if;

  -- (b) profiles kapı kolonları kapalı mı?
  select count(*) into v_prof_grant
    from information_schema.column_privileges
   where table_schema='public' and table_name='profiles'
     and column_name in ('guest_capacity','access_source','guest_fee_expected')
     and privilege_type='UPDATE' and grantee in ('authenticated','anon');
  if v_prof_grant <> 0 then
    -- 🔴 v1'DE BU SATIR YALNIZ SAYIYORDU: "3 grant". Hangi rol, hangi
    -- kolon — hiçbiri yoktu. Gökberk'e teşhis değil bilmece gönderdim.
    -- Bir nöbetçi kusuru bulup ADINI söylemiyorsa, işin yarısını
    -- yapıp diğer yarısını okuyana bırakıyor demektir.
    raise exception '232 NOBETCI: profiles kapi kolonlari hala yazilabilir (% grant) → %',
      v_prof_grant,
      (select string_agg(grantee || '.' || column_name, ', ' order by grantee, column_name)
         from information_schema.column_privileges
        where table_schema='public' and table_name='profiles'
          and column_name in ('guest_capacity','access_source','guest_fee_expected')
          and privilege_type='UPDATE' and grantee in ('authenticated','anon'));
  end if;

  -- (c) host_wallet kapısı gerçekten gövdede mi?
  select count(*) into v_kapi
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   -- 🔴 250'DE AYRIŞTIRILDI: kapı artık `host_wallet`te, hesap
   -- `host_wallet_hesap`ta. Bu nöbetçi İKİSİNE BİRDEN bakar; aksi hâlde
   -- doğru bir mimari düzeltmeyi ihlal sanardı.
   -- 🆕 SINIF: "BİR NÖBETÇİ TEK BİR FONKSİYON ADINA KİLİTLİYSE, O
   -- FONKSİYON BÖLÜNDÜĞÜ GÜN KÖRLEŞİR."
   where n.nspname='public' and p.proname in ('host_wallet','host_wallet_hesap')
     and p.prosrc like '%cuzdan_sahibi_degil%';
  if v_kapi < 1 then
    raise exception '232 NOBETCI: host_wallet kapisi govdede YOK.';
  end if;

  raise notice '232 OK · rol istemciden kapali · profiles kapi kolonlari kapali · host_wallet sahiplik kapisi kurulu';
  raise notice '232 OLCULMEDI: gercek Supabase''te `anon`/`authenticated` rollerine SEMA duzeyinde '
               'toplu grant verilmis olabilir. Canlida sunu calistirip bos donmeli: '
               'select * from information_schema.column_privileges where table_name=''users'' and column_name=''role'';';
end $n232$;

-- ----------------------------------------------------------------------------
-- 6) RPC YÜZEYİ
-- ----------------------------------------------------------------------------
insert into rpc_client_surface (fn_name, client, note) values
  ('rolumu_sec','app','Rol degisiminin TEK kapisi — istemci artik users.role yazamaz (232)')
on conflict (fn_name) do update set note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '232: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '232 ROL KAPISI VE CUZDAN SIZINTISI KAPANDI' as sonuc,
       (select count(*) from information_schema.column_privileges
         where table_name='users' and column_name='role'
           and privilege_type='UPDATE' and grantee in ('authenticated','anon')) as acik_rol_grant,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         -- 🔴 250'DE AYRIŞTIRILDI: kapı artık `host_wallet`te, hesap
   -- `host_wallet_hesap`ta. Bu nöbetçi İKİSİNE BİRDEN bakar; aksi hâlde
   -- doğru bir mimari düzeltmeyi ihlal sanardı.
   -- 🆕 SINIF: "BİR NÖBETÇİ TEK BİR FONKSİYON ADINA KİLİTLİYSE, O
   -- FONKSİYON BÖLÜNDÜĞÜ GÜN KÖRLEŞİR."
   where n.nspname='public' and p.proname in ('host_wallet','host_wallet_hesap')
           and p.prosrc like '%cuzdan_sahibi_degil%') as cuzdan_kapisi;
