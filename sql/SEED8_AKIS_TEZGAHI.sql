-- ============================================================================
-- LoungeLink · SEED8_AKIS_TEZGAHI.sql                         (23 Eylül 2026)
--
-- "İLAN BAŞVURU KURALLARINI, BAŞVURUYU, KABUL VE RET İŞLEMLERİNİ, OTURUM
--  BAŞLATMA, OTURUM TAMAMLAMA VE CHAT KISIMLARINI MUTLAKA TEST ETMEM LAZIM"
--                                                          — Gökberk, 22 Eylül
--
-- ════════════════════════════════════════════════════════════════════════
-- ÖNCE ÖLÇTÜM: KEŞFET NEDEN BOŞTU?
-- ════════════════════════════════════════════════════════════════════════
-- Keşif sorgusu (`discover_availabilities`) yalnız `avail_date >= bugün`
-- olan ilanları döndürüyor. Eski SEED'lerin hepsi tarihi KOŞTURULDUĞU
-- GÜNE göre yazıyor: SEED6 `current_date`, SEED3 `+2…+5`, SEED4 `+3…+24`.
-- Yani bir SEED'i 15 Eylül'de koştuysan, 17 Eylül'den sonra o dünyanın
-- ilanları sessizce keşiften düşer — veritabanında durur, ekranda yoktur.
-- Yerel kopyada aynı SEED'ler bugün koşunca keşif 47 ilan döndürüyor;
-- yani sorgu doğru, VERİ ÇÜRÜYOR.
--
-- 🆕 SINIF: "TARİHİ KOŞTURULDUĞU ANA BAĞLI BİR TEST VERİSİ, BİR TEST
-- VERİSİ DEĞİL, BİR SON KULLANMA TARİHİDİR."
--
-- Bu dosya iki şey yapıyor:
--   §2  ESKİ SEED DÜNYASINI TAZELER — yalnız test hesaplarının, geçmişi
--       olmayan ilanlarını ve seyahatlerini aynı gün sayısı kadar ileri
--       kaydırır (aradaki göreli düzen korunur).
--   §4  KENDİ AKIŞ DÜNYASINI HER KOŞUŞTA SIFIRDAN KURAR — tarihler hep
--       "yarın". Test etmeden önce bu dosyayı bir kez daha koşman yeter.
--
-- ════════════════════════════════════════════════════════════════════════
-- EL İLE SATIR YAZMIYORUZ — GERÇEK FONKSİYONLARI ÇAĞIRIYORUZ
-- ════════════════════════════════════════════════════════════════════════
-- Eski SEED'ler durumları doğrudan `insert` ile kuruyordu. O zaman bir
-- "kabul edilmiş istek" uygulamanın ürettiğinden farklı olabiliyordu:
-- kredisi tutulmamış, sohbeti açılmamış, bildirimi yazılmamış.
-- Bu dosya her durumu uygulamanın çağırdığı FONKSİYONLARLA, o kullanıcı
-- ADINA kuruyor: `create_request`, `respond_request`, `start_session_
-- request`, `confirm_session`, `send_invite`. Yani:
--   · Ekranda gördüğün her durum, gerçek bir kullanıcının üreteceği durum.
--   · Bu dosyanın kendisi bir uçtan uca testtir: akışlardan biri bozulursa
--     dosya hata verip durur ve HİÇBİR ŞEY yazılmaz.
--
-- Başvuru kurallarında da tahmin yok: §5 her kural senaryosu için
-- `create_request`'i GERÇEKTEN çağırıp sonucu ölçüyor, sonra geri alıyor.
-- Haritadaki "SUNUCU NE DİYOR" sütunu bir tahmin değil, bir ölçüm.
--
-- ════════════════════════════════════════════════════════════════════════
-- GÜVENLİK: GERÇEK HESABA TEK SATIR YAZMAZ
-- ════════════════════════════════════════════════════════════════════════
-- Yazılan her satır `public.seed_test_hesabi(email)` = true olan
-- hesaplara ait. §6, test dışı hesapların satır sayılarını dosyanın
-- BAŞINDA ve SONUNDA sayıp karşılaştırıyor; bir tane bile değiştiyse
-- dosya `raise exception` ile durur ve her şey geri alınır.
--
-- KULLANIM: Supabase → SQL Editor → bu dosyanın tamamını yapıştır → Run.
-- ÖNKOŞUL: 001…301 kurulu. SEED…SEED7 kurulu olması İYİ ama ŞART DEĞİL
-- (§5 kural haritası onların ilanlarını kullanır; yoksa haritada az satır
-- çıkar, akış dünyası yine eksiksiz kurulur).
-- TEKRAR KOŞULABİLİR: her koşuş aynı durumu kurar (yerelde 3 kez ölçüldü).
-- ŞİFRE: bütün akis.* hesapları `Seed1234!`
-- SONUÇ: dosyanın sonundaki tablo — hangi hesapla gir, ne göreceksin.
-- ============================================================================

-- İşlem bloğu: psql'de tek işlem (bir adım düşerse hiçbir şey yazılmaz).
-- Supabase SQL Editor bloğu uygulamıyor; orada her ifade kendi işleminde
-- ve dosya yine ÇALIŞIR — her adım yalnız akis.* hesaplarına yazar ve
-- dosya baştan tekrar koşulabilir (yarıda kalırsa yeniden Run).
begin;

-- ── §0 · Test hesabı tanımı (SEED7 ile birebir aynı) ──────────────────────
create or replace function public.seed_test_hesabi(p_email text)
returns boolean language sql immutable as $$
  select coalesce(p_email, '') like '%@seed.loungelink.test'
      or coalesce(p_email, '') like '%@sahne.loungelink.test'
      or coalesce(p_email, '') like '%@vitrin.loungelink.test'
      or coalesce(p_email, '') like '%@e2e.test';
$$;

-- Tezgâh yardımcıları AYRI bir şemada: `tezgah` PostgREST'e açık değil,
-- yani uygulamadan ya da dışarıdan çağrılamaz. Yalnız SQL Editor görür.
create schema if not exists tezgah;
revoke all on schema tezgah from public;
do $yetki$ begin
  execute 'revoke all on schema tezgah from anon, authenticated';
exception when undefined_object then null; end $yetki$;

-- Kimlik değiştir: bundan sonraki fonksiyon çağrıları `p` adına.
create or replace function tezgah.olarak(p uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    case when p is null then '' else json_build_object('sub', p, 'role', 'authenticated')::text end, true);
  perform set_config('request.jwt.claim.sub', coalesce(p::text, ''), true);
end $$;

-- Başvuruyu DENE, sonucu ölç, GERİ AL. Fonksiyonun `exception` bloğu bir
-- kayıt noktasıdır: başarılı başvuruyu kendi sinyalimizle geri sarıyoruz.
create or replace function tezgah.basvuru_dene(p_kim uuid, p_ilan uuid) returns text
language plpgsql as $$
declare v text;
begin
  perform tezgah.olarak(p_kim);
  begin
    perform public.create_request(p_ilan, 'lounge', null, null);
    raise exception 'TEZGAH_BASVURU_GECER';
  exception when others then
    v := sqlerrm;
  end;
  perform tezgah.olarak(null);
  return case when v = 'TEZGAH_BASVURU_GECER' then 'GECER' else v end;
end $$;

-- Harita tablosu: §5'in ölçtüğü her senaryo buraya yazılır, en sondaki
-- rapor buradan okur. `tezgah` şemasında → uygulamaya görünmez.
create table if not exists tezgah.harita (
  sira        int primary key,
  hesap       text not null,
  senaryo     text not null,
  nerede      text,
  beklenen    text,
  sunucu      text,
  ekranda     text
);

-- ── §1 · HESAPLAR ───────────────────────────────────────────────────────
-- Sabit kimlikler: tekrar koşuşta aynı hesaplar. Hesap zaten varsa
-- (başka bir id ile) e-postadan bulunur; yeni hesap AÇILMAZ.
-- 🔴 23 Eylül · Supabase'de "relation seed8_hesap does not exist" (42P01).
-- Ölçüldü: SQL Editor dosyayı `begin; … commit;` bloğu İÇİNDE koşturmuyor —
-- her ifade kendi işleminde. `on commit drop` geçici tablo, oluşturulduğu
-- ifade biter bitmez siliniyordu; yerelde psql tek işlem kurduğu için
-- görünmüyordu (begin/commit silinip yerelde koşunca AYNI hata, satır 136).
-- Artık ifadeler arası taşınan iki tablo KALICI ve `tezgah` şemasında
-- (PostgREST'e kapalı). İşlem olsa da olmasa da aynı sonuç.
create table if not exists tezgah.seed8_hesap (
  id uuid, email text primary key, rol text, ad text, meslek text,
  guven int, plan text, kredi int, dogrulu boolean, cinsiyet text
);
revoke all on tezgah.seed8_hesap from public;
truncate tezgah.seed8_hesap;
insert into tezgah.seed8_hesap values
  ('88880000-0000-4000-8000-000000000001','akis.host@seed.loungelink.test',      'host', 'Nehir A.', 'Ürün Tasarımcısı', 82,'explorer', 6,true,'female'),
  ('88880000-0000-4000-8000-000000000002','akis.host2@seed.loungelink.test',     'host', 'Tuna H.',  'Veri Bilimci',     74,'explorer', 6,true,'male'),
  ('88880000-0000-4000-8000-000000000011','akis.misafir@seed.loungelink.test',   'guest','Arda K.',  'Yazılım Mühendisi',60,'kahya',   20,true,'male'),
  ('88880000-0000-4000-8000-000000000012','akis.misafir2@seed.loungelink.test',  'guest','Bora E.',  'Finans Analisti',  55,'explorer', 5,true,'male'),
  ('88880000-0000-4000-8000-000000000013','akis.misafir3@seed.loungelink.test',  'guest','Cem D.',   'Mimar',            52,'explorer', 5,true,'male'),
  ('88880000-0000-4000-8000-000000000014','akis.misafir4@seed.loungelink.test',  'guest','Duru F.',  'Doktor',           66,'explorer', 5,true,'female'),
  ('88880000-0000-4000-8000-000000000021','akis.kural@seed.loungelink.test',     'guest','Ela G.',   'Hukukçu',          58,'kahya',   20,true,'female'),
  ('88880000-0000-4000-8000-000000000022','akis.kredisiz@seed.loungelink.test',  'guest','Can Y.',   'Öğretmen',         50,'explorer', 0,true,'male'),
  ('88880000-0000-4000-8000-000000000023','akis.dogrulanmamis@seed.loungelink.test','guest','Mina S.','Tasarımcı',       20,'explorer', 5,false,'female');

do $hesap$
declare r record; v_var uuid;
begin
  -- Güvenlik: listedeki her e-posta test kümesinde mi? (yazım hatası = dur)
  if exists (select 1 from tezgah.seed8_hesap h where not public.seed_test_hesabi(h.email)) then
    raise exception 'SEED8: test kümesi dışında e-posta var — DURDU';
  end if;
  for r in select * from tezgah.seed8_hesap loop
    select id into v_var from auth.users where email = r.email;
    if v_var is null then
      insert into auth.users (id, email) values (r.id, r.email);
    elsif v_var <> r.id then
      update tezgah.seed8_hesap set id = v_var where email = r.email;
    end if;
  end loop;
end $hesap$;

-- Şifre + GoTrue alanları + kimlik satırı. Üçü birden yoksa giriş
-- "Invalid login credentials" döner (SEED2 · 20 Ağustos dersi).
update auth.users u
   set encrypted_password = extensions.crypt('Seed1234!', extensions.gen_salt('bf'))
 where u.email in (select email from tezgah.seed8_hesap)
   and (u.encrypted_password is null or u.encrypted_password = '');

do $gotrue$
declare v_set text := ''; v_kolon text;
  v_bos text[] := array['confirmation_token','recovery_token','email_change',
    'email_change_token_new','email_change_token_current','phone_change',
    'phone_change_token','reauthentication_token'];
begin
  foreach v_kolon in array v_bos loop
    if exists (select 1 from information_schema.columns
                where table_schema='auth' and table_name='users' and column_name=v_kolon) then
      v_set := v_set || format('%I = coalesce(%I, %L), ', v_kolon, v_kolon, '');
    end if;
  end loop;
  if exists (select 1 from information_schema.columns
              where table_schema='auth' and table_name='users' and column_name='instance_id') then
    v_set := v_set || 'instance_id = coalesce(instance_id, ''00000000-0000-0000-0000-000000000000''::uuid), ';
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema='auth' and table_name='users' and column_name='is_sso_user') then
    v_set := v_set || 'is_sso_user = coalesce(is_sso_user, false), ';
  end if;
  v_set := v_set || 'aud = coalesce(aud, ''authenticated''), role = coalesce(role, ''authenticated''), '
        || 'email_confirmed_at = coalesce(email_confirmed_at, now()), '
        || 'created_at = coalesce(created_at, now()), updated_at = now(), '
        || 'raw_app_meta_data = coalesce(raw_app_meta_data, ''{"provider":"email","providers":["email"]}''::jsonb)';
  execute 'update auth.users set ' || v_set
       || ' where email like ''akis.%@seed.loungelink.test''';
end $gotrue$;

do $kimlik$
begin
  if exists (select 1 from information_schema.tables
              where table_schema='auth' and table_name='identities') then
    insert into auth.identities (user_id, provider_id, identity_data, provider,
                                 last_sign_in_at, created_at, updated_at)
    select u.id, u.id::text,
           jsonb_build_object('sub',u.id::text,'email',u.email,
                              'email_verified',true,'phone_verified',false),
           'email', now(), now(), now()
      from auth.users u
     where u.email in (select email from tezgah.seed8_hesap)
       and not exists (select 1 from auth.identities i
                        where i.user_id=u.id and i.provider='email');
  end if;
end $kimlik$;

-- Uygulama tarafı satırlar
insert into users (id, email, password_hash, role, plan)
select h.id, h.email, 'supabase-auth', h.rol::user_role, h.plan::plan_type from tezgah.seed8_hesap h
on conflict (id) do update set role = excluded.role, plan = excluded.plan,
       deleted_at = null, banned_at = null, shadow_limited = false, restricted_until = null;
-- cinsiyet kilidi tetikleyicisi yalnız DEĞİŞİMİ denetler; boşsa yaz
update users u set gender = h.cinsiyet::user_gender
  from tezgah.seed8_hesap h where u.id = h.id and u.gender is null;

insert into profiles (user_id, name, profession, bio, languages, show_on_discovery)
select h.id, h.ad, h.meslek,
       case h.rol when 'host' then 'Aktarmalarda salonda sohbet etmeyi seviyorum. Kahve benden.'
                  else 'Uçuş öncesi iyi bir sohbet yolculuğu kısaltır.' end,
       array['Türkçe','İngilizce'], true
  from tezgah.seed8_hesap h
on conflict (user_id) do update set name = excluded.name, profession = excluded.profession,
       bio = excluded.bio, show_on_discovery = true;
update profiles set access_source = 'Havayolu Statüsü', guest_capacity = 2   -- 305: ham kod değil etiket
 where user_id in (select id from tezgah.seed8_hesap where rol = 'host');

insert into trust_scores (user_id, score, badge)
select h.id, h.guven, case when h.guven >= 80 then 'trusted' when h.guven >= 55 then 'verified' else 'basic' end
  from tezgah.seed8_hesap h
on conflict (user_id) do update set score = excluded.score, badge = excluded.badge;

-- Mina (doğrulanmamış) BİLEREK doğrulamasız: iletişim kapısını test ediyor.
delete from verifications where user_id in (select id from tezgah.seed8_hesap where not dogrulu);
insert into verifications (user_id, email_verified, email_verified_at, phone_verified, phone_verified_at, id_verified)
select h.id, true, now(), true, now(), h.guven >= 70 from tezgah.seed8_hesap h where h.dogrulu
on conflict (user_id) do update set email_verified = true, phone_verified = true,
       id_verified = excluded.id_verified;

-- Onaylar: hem uygulamanın bugünkü sözleşme seti (v16) hem eski set.
insert into consents (user_id, type, version)
select h.id, ty, 'v16' from tezgah.seed8_hesap h,
       unnest(array['no_lounge_sale','no_offplatform_payment','community_rules',
                    'venue_rules','terms_privacy','age_18']) ty
on conflict do nothing;

-- Host kart hakları: THY Miles&Smiles Elite Plus (misafir hakkı dahil).
delete from host_entitlements where user_id in (select id from tezgah.seed8_hesap where rol = 'host');
insert into host_entitlements (user_id, program_id, tier, verified)
select h.id, p.id, 'ELPL', true
  from tezgah.seed8_hesap h, lounge_programs p
 where h.rol = 'host' and p.code = 'TK_MS';


-- ── §2 · ESKİ SEED DÜNYASINI TAZELE ─────────────────────────────────────
-- Yalnız test hesaplarının, GEÇMİŞİ OLMAYAN ilanları kaydırılır:
--   · kabul edilmiş/tamamlanmış isteği ya da oturumu olan ilana DOKUNULMAZ
--     (tarihçe bozulmasın; `trg_ilan_kapatma_kapisi` zaten izin vermez)
--   · akis.* ilanları hariç (onlar §4'te sıfırdan kuruluyor)
-- Kaydırma miktarı TEK: en erken ilan yarına gelsin. Böylece ilanlar ile
-- onlara göre yazılmış seyahatler arasındaki gün farkı KORUNUR.
create table if not exists tezgah.seed8_once (tablo text primary key, n bigint);
revoke all on tezgah.seed8_once from public;
truncate tezgah.seed8_once;

do $tazele$
declare v_gun int; v_ilan int := 0; v_sey int := 0;
begin
  create temp table seed8_tazelenecek on commit drop as
    select a.id, a.avail_date
      from availabilities a join users hu on hu.id = a.host_id
     where a.active
       and public.seed_test_hesabi(hu.email)
       and hu.email not like 'akis.%'
       and not exists (select 1 from requests r where r.avail_id = a.id
                        and r.status in ('accepted','completed'))
       and not exists (select 1 from requests r join sessions s on s.request_id = r.id
                        where r.avail_id = a.id);

  select (current_date + 1) - min(avail_date) into v_gun from seed8_tazelenecek;
  if coalesce(v_gun, 0) <= 0 then
    raise notice 'SEED8 §2: eski dünya zaten güncel — kaydırma yok';
    return;
  end if;

  update availabilities a set avail_date = a.avail_date + v_gun, updated_at = now()
   where a.id in (select id from seed8_tazelenecek);
  get diagnostics v_ilan = row_count;

  -- Seyahatler aynı miktarda. Açık başvuruya bağlı seyahat KİLİTLİ
  -- (`trg_seyahat_sozlesme_kapisi`) — onları atlıyoruz, hata vermiyoruz.
  update visits v set visit_date = v.visit_date + v_gun
    from users u
   where u.id = v.user_id
     and public.seed_test_hesabi(u.email)
     and u.email not like 'akis.%'
     and not exists (select 1 from requests r where r.visit_id = v.id
                      and r.status in ('pending','accepted'));
  get diagnostics v_sey = row_count;
  raise notice 'SEED8 §2: % ilan ve % seyahat % gün ileri alındı', v_ilan, v_sey, v_gun;
end $tazele$;


-- ── §3–§6 · AKIŞ DÜNYASI ────────────────────────────────────────────────
do $akis$
declare
  -- kişiler
  nehir uuid; tuna uuid; arda uuid; bora uuid; cem uuid; duru uuid;
  ela uuid; can_ uuid; mina uuid;
  hepsi uuid[];
  -- yer
  yarin date := current_date + 1;
  l_ist uuid; l_ayt uuid; ad_ist text; ad_ayt text;
  -- ilanlar
  n1 uuid; n2 uuid; n3 uuid; n4 uuid; n5 uuid; n6 uuid;
  t1 uuid; t2 uuid; t3 uuid; t4 uuid; t5 uuid;
  -- istekler / oturumlar / kanallar
  r1 uuid; r2 uuid; r3 uuid; r4 uuid; r5 uuid; r6 uuid; r7 uuid; r8 uuid; r9 uuid; r10 uuid;
  s7 uuid; s8 uuid; ch uuid;
  j jsonb; v_n int; v_sira int := 0; v_sonuc text;
  -- §5
  k record; v_vis uuid; v_sinif text; v_dec jsonb;
  v_alinan text[] := array[]::text[];
  v_eksik text;
begin
  perform set_config('ll.test_mode', 'on', true);   -- rl_guard: tohum hız sınırına takılmasın

  select id into nehir from tezgah.seed8_hesap where email = 'akis.host@seed.loungelink.test';
  select id into tuna  from tezgah.seed8_hesap where email = 'akis.host2@seed.loungelink.test';
  select id into arda  from tezgah.seed8_hesap where email = 'akis.misafir@seed.loungelink.test';
  select id into bora  from tezgah.seed8_hesap where email = 'akis.misafir2@seed.loungelink.test';
  select id into cem   from tezgah.seed8_hesap where email = 'akis.misafir3@seed.loungelink.test';
  select id into duru  from tezgah.seed8_hesap where email = 'akis.misafir4@seed.loungelink.test';
  select id into ela   from tezgah.seed8_hesap where email = 'akis.kural@seed.loungelink.test';
  select id into can_  from tezgah.seed8_hesap where email = 'akis.kredisiz@seed.loungelink.test';
  select id into mina  from tezgah.seed8_hesap where email = 'akis.dogrulanmamis@seed.loungelink.test';
  hepsi := array[nehir, tuna, arda, bora, cem, duru, ela, can_, mina];

  -- ── §6a · TEST DIŞI HESAPLARIN "ÖNCE" SAYIMI ────────────────────────
  insert into tezgah.seed8_once
  select 'requests',  count(*) from requests r join users g on g.id=r.guest_id join users h on h.id=r.host_id
                        where not public.seed_test_hesabi(g.email) or not public.seed_test_hesabi(h.email)
  union all select 'requests_durum', coalesce(sum(hashtext(r.id::text || r.status::text)::bigint),0)
                        from requests r join users g on g.id=r.guest_id join users h on h.id=r.host_id
                        where not public.seed_test_hesabi(g.email) or not public.seed_test_hesabi(h.email)
  union all select 'availabilities', count(*) + coalesce(sum(hashtext(a.id::text||a.avail_date::text||a.filled::text||a.active::text)::bigint),0)
                        from availabilities a join users u on u.id=a.host_id where not public.seed_test_hesabi(u.email)
  union all select 'visits',    count(*) + coalesce(sum(hashtext(v.id::text||v.visit_date::text)::bigint),0)
                        from visits v join users u on u.id=v.user_id where not public.seed_test_hesabi(u.email)
  union all select 'credit',    count(*) + coalesce(sum(c.delta),0)
                        from credit_ledger c join users u on u.id=c.user_id where not public.seed_test_hesabi(u.email)
  union all select 'messages',  count(*) from messages m join users u on u.id=m.from_id where not public.seed_test_hesabi(u.email)
  union all select 'sessions',  count(*) + coalesce(sum(hashtext(s.id::text||s.status::text)::bigint),0)
                        from sessions s join requests r on r.id=s.request_id join users g on g.id=r.guest_id join users h on h.id=r.host_id
                        where not public.seed_test_hesabi(g.email) or not public.seed_test_hesabi(h.email)
  union all select 'invites',   count(*) from invites i join users g on g.id=i.guest_id join users h on h.id=i.host_id
                        where not public.seed_test_hesabi(g.email) or not public.seed_test_hesabi(h.email)
  union all select 'notifications', count(*) from notifications n join users u on u.id=n.user_id where not public.seed_test_hesabi(u.email)
  union all select 'profiles',  count(*) + coalesce(sum(hashtext(coalesce(p.name,'')||coalesce(p.show_on_discovery::text,''))::bigint),0)
                        from profiles p join users u on u.id=p.user_id where not public.seed_test_hesabi(u.email);

  -- ── §3 · TEMİZLİK: YALNIZ akis.* DÜNYASI ────────────────────────────
  -- Bir istek ancak İKİ TARAFI DA test hesabıysa silinir. Gerçek bir
  -- kullanıcı akis ilanına başvurmuşsa o satır ve o ilan KALIR.
  create temp table seed8_rq on commit drop as
    select r.id from requests r
      join users g on g.id = r.guest_id join users h on h.id = r.host_id
     where (r.guest_id = any(hepsi) or r.host_id = any(hepsi))
       and public.seed_test_hesabi(g.email) and public.seed_test_hesabi(h.email);
  create temp table seed8_ss on commit drop as
    select s.id from sessions s where s.request_id in (select id from seed8_rq);
  create temp table seed8_ch on commit drop as
    select c.id from chat_channels c where c.request_id in (select id from seed8_rq);

  delete from ratings    where session_id in (select id from seed8_ss);
  delete from reports    where session_id in (select id from seed8_ss);
  update lounge_field_reports set session_id = null where session_id in (select id from seed8_ss);
  update kural_supheleri      set session_id = null where session_id in (select id from seed8_ss);
  delete from messages   where channel_id in (select id from seed8_ch);
  delete from chat_channels where id in (select id from seed8_ch);
  delete from sessions   where id in (select id from seed8_ss);            -- disputes/host_stories/kapida_retler: cascade
  delete from requests   where id in (select id from seed8_rq);            -- session_verifications: cascade
  delete from invites i using users g, users h
   where g.id = i.guest_id and h.id = i.host_id
     and (i.guest_id = any(hepsi) or i.host_id = any(hepsi))
     and public.seed_test_hesabi(g.email) and public.seed_test_hesabi(h.email);
  delete from availabilities a
   where a.host_id = any(hepsi)
     and not exists (select 1 from requests r where r.avail_id = a.id)
     and not exists (select 1 from invites i where i.avail_id = a.id)
     and not exists (select 1 from connection_requests c where c.avail_id = a.id);
  delete from visits      where user_id = any(hepsi)
     and not exists (select 1 from requests r where r.visit_id = visits.id);
  delete from credit_ledger  where user_id = any(hepsi);
  delete from points_ledger  where user_id = any(hepsi);
  delete from notifications  where user_id = any(hepsi);
  delete from rate_limits    where user_id = any(hepsi);
  delete from huni_olaylari  where user_id = any(hepsi);
  delete from talep_kayitlari where user_id = any(hepsi);
  -- 301 · elle denenen engeller/bildirimler bir sonraki koşuşu bozmasın
  -- (yalnız İKİ tarafı da akis.* olan satırlar — gerçek hesaba dokunmaz)
  delete from blocks  where blocker = any(hepsi) and blocked = any(hepsi);
  delete from reports where reporter_id = any(hepsi) and target_id = any(hepsi);

  -- Cüzdanlar (kredi kaydı tek satır: açılış bakiyesi)
  insert into credit_ledger (user_id, delta, reason, balance_after, note)
  select h.id, h.kredi, 'seed8', h.kredi, 'SEED8 açılış bakiyesi'
    from tezgah.seed8_hesap h where h.kredi > 0;

  -- ── §4 · İLANLAR ────────────────────────────────────────────────────
  select id, name into l_ist, ad_ist from lounges where airport_code = 'IST' and name = 'Primeclass Lounge' order by id limit 1;
  if l_ist is null then
    select id, name into l_ist, ad_ist from lounges where airport_code = 'IST' and name ilike 'Primeclass%'
     and name not like '%(%' order by id limit 1;
  end if;
  select id, name into l_ayt, ad_ayt from lounges where airport_code = 'AYT' and name = 'Primeclass Lounge' order by id limit 1;
  if l_ist is null then raise exception 'SEED8: IST Primeclass salonu bulunamadı'; end if;

  -- Nehir — IST, yarın. Her ilan tek bir akış durumunu taşıyor.
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active)
  values (nehir, l_ist, 'IST', ad_ist, yarin, '10:00', '13:00', 3, 0, 'TK1979', 'TK', 'Public', true) returning id into n1;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
  values (nehir, l_ist, 'IST', ad_ist, yarin, '13:30', '15:30', 1, 0, 'TK', 'Public', true) returning id into n2;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
  values (nehir, l_ist, 'IST', ad_ist, yarin, '16:00', '17:30', 2, 0, 'TK', 'Public', true) returning id into n3;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
  values (nehir, l_ist, 'IST', ad_ist, yarin, '18:00', '19:30', 2, 0, 'TK', 'Public', true) returning id into n4;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
  values (nehir, l_ist, 'IST', ad_ist, yarin, '20:00', '21:30', 2, 0, 'TK', 'Public', true) returning id into n5;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
  values (nehir, l_ist, 'IST', ad_ist, yarin, '07:00', '09:30', 2, 0, 'TK', 'Public', true) returning id into n6;

  -- Tuna — IST (yarın) + AYT (3 gün sonra)
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
  values (tuna, l_ist, 'IST', ad_ist, yarin, '11:00', '12:30', 2, 0, 'TK', 'Public', true) returning id into t1;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
  values (tuna, l_ist, 'IST', ad_ist, yarin, '12:45', '14:00', 2, 0, 'TK', 'Public', true) returning id into t2;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
  values (tuna, l_ist, 'IST', ad_ist, yarin, '14:15', '16:00', 2, 0, 'TK', 'Public', true) returning id into t3;
  if l_ayt is not null then
    insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active)
    values (tuna, l_ayt, 'AYT', ad_ayt, current_date + 3, '10:00', '12:00', 2, 0, 'TK', 'Public', true) returning id into t4;
  end if;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, carrier, visibility, active, min_trust)
  values (tuna, l_ist, 'IST', ad_ist, yarin, '16:30', '18:30', 1, 0, 'TK', 'Public', true, 90) returning id into t5;

  -- Seyahatler. Arda yarın bütün gün IST'de (TK1979 → Nehir'in N1'iyle
  -- "Aynı uçuş" rozeti). AYT için seyahati YOK — "Seyahat ekle" durumu.
  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number, carrier_code, purpose, party_size)
  values (arda, 'IST', 'LHR', yarin, '06:30', '23:30', 'TK1979', 'TK', 'business', 1),
         (bora, 'IST', 'AMS', yarin, '09:00', '16:00', null, null, 'business', 1),
         (cem,  'IST', 'FRA', yarin, '09:30', '13:30', null, null, 'conference', 1),
         (duru, 'IST', 'CDG', yarin, '12:00', '16:00', null, null, 'leisure', 1),
         (can_, 'IST', 'BER', yarin, '13:00', '17:00', null, null, 'leisure', 1),
         (mina, 'IST', 'MUC', yarin, '13:00', '17:00', null, null, 'leisure', 1);

  -- ── §4b · AKIŞLAR — HER BİRİ GERÇEK FONKSİYONLA, O KİŞİ ADINA ───────
  -- R1 · Bora → N1 · BEKLİYOR   (Nehir KABUL etmeyi deneyecek)
  perform tezgah.olarak(bora);
  j := public.create_request(n1, 'lounge', 'Merhaba! 11 gibi salonda olurum, kahve?', null); r1 := (j->>'id')::uuid;
  -- R2 · Cem → N1 · BEKLİYOR    (Nehir REDDETMEYİ deneyecek)
  perform tezgah.olarak(cem);
  j := public.create_request(n1, 'lounge', 'Konferans öncesi biraz sohbet iyi olur.', null); r2 := (j->>'id')::uuid;
  -- R5 · Bora → N2 · BEKLİYOR — ama N2 birazdan DOLACAK (kapasite testi)
  perform tezgah.olarak(bora);
  j := public.create_request(n2, 'lounge', 'Öğleden sonra da müsaitim.', null); r5 := (j->>'id')::uuid;
  -- R4 · Duru → N2 · KABUL → N2 doldu (1/1)
  perform tezgah.olarak(duru);
  j := public.create_request(n2, 'lounge', 'Aynı saatlerdeyiz, görüşelim mi?', null); r4 := (j->>'id')::uuid;
  perform tezgah.olarak(nehir);
  perform public.respond_request(r4, 'accept');

  -- R3 · Arda → N1 · KABUL, sohbet açık, oturum HENÜZ başlamadı
  perform tezgah.olarak(arda);
  j := public.create_request(n1, 'lounge', 'Aynı uçuştayız (TK1979) — salonda kahve?', null); r3 := (j->>'id')::uuid;
  perform tezgah.olarak(nehir);
  j := public.respond_request(r3, 'accept'); ch := (j->>'channel_id')::uuid;
  perform tezgah.olarak(nehir);
  insert into messages (channel_id, from_id, body, created_at) values (ch, nehir, 'Merhaba Arda! Primeclass girişinde buluşalım mı? 10:30 gibi oradayım.', now() - interval '25 minutes');
  perform tezgah.olarak(arda);
  insert into messages (channel_id, from_id, body, created_at) values (ch, arda, 'Harika, güvenlikten geçince yazarım.', now() - interval '22 minutes');
  perform tezgah.olarak(nehir);
  insert into messages (channel_id, from_id, body, created_at) values (ch, nehir, 'Bir de biniş kartını hazır tut — kapıda soruyorlar.', now() - interval '20 minutes');
  perform tezgah.olarak(arda);
  insert into messages (channel_id, from_id, body, created_at) values (ch, arda, 'Tamamdır 👍', now() - interval '18 minutes');

  -- R6 · Arda → N3 · KABUL + Nehir "Oturumu Başlat"a BASTI (yarım başlama)
  perform tezgah.olarak(arda);
  j := public.create_request(n3, 'lounge', 'Öğleden sonra da buradayım.', null); r6 := (j->>'id')::uuid;
  perform tezgah.olarak(nehir);
  j := public.respond_request(r6, 'accept'); ch := (j->>'channel_id')::uuid;
  insert into messages (channel_id, from_id, body, created_at) values (ch, nehir, 'Salondayım, pencere tarafı. Oturumu başlattım, sen de başlat.', now() - interval '3 minutes');
  j := public.start_session_request(r6);
  if j->>'status' <> 'pending' then raise exception 'SEED8: R6 yarım başlama bekleniyordu, gelen %', j; end if;
  -- 301 · "Gelmedi mi?" denenebilsin diye Nehir'in basışı 20 dk öncesine
  -- çekiliyor (zamanı ileri saramayız; bu tek satır ZAMAN, kural değil).
  -- Nehir sohbete girince "Karşı taraf bekleniyor · 20 dk" + "Gelmedi mi? Bildir".
  update sessions set host_started_at = now() - interval '20 minutes'
   where request_id = r6 and status = 'pending';

  -- R7 · Arda → N4 · OTURUM SÜRÜYOR + Nehir "Tamamla"ya BASTI
  perform tezgah.olarak(arda);
  j := public.create_request(n4, 'lounge', 'Akşam uçuşundan önce görüşelim.', null); r7 := (j->>'id')::uuid;
  perform tezgah.olarak(nehir);
  j := public.respond_request(r7, 'accept'); ch := (j->>'channel_id')::uuid;
  insert into messages (channel_id, from_id, body, created_at) values (ch, nehir, 'Kapıda buluştuk, iyi sohbetti!', now() - interval '2 minutes');
  perform public.start_session_request(r7);
  perform tezgah.olarak(arda);
  j := public.start_session_request(r7);
  if j->>'status' <> 'active' then raise exception 'SEED8: R7 çift onayla aktif olmadı: %', j; end if;
  s7 := (j->>'id')::uuid;
  perform tezgah.olarak(nehir);
  j := public.confirm_session(s7);
  if (j->>'completed')::boolean then raise exception 'SEED8: R7 tek onayla tamamlanmamalıydı'; end if;

  -- R8 · Arda → N5 · TAMAMLANDI, puanlanmadı
  perform tezgah.olarak(arda);
  j := public.create_request(n5, 'lounge', 'Son bir kahve?', null); r8 := (j->>'id')::uuid;
  perform tezgah.olarak(nehir);
  j := public.respond_request(r8, 'accept'); ch := (j->>'channel_id')::uuid;
  insert into messages (channel_id, from_id, body, created_at) values (ch, nehir, 'Keyifliydi, iyi uçuşlar!', now() - interval '1 minute');
  perform public.start_session_request(r8);
  perform tezgah.olarak(arda);
  j := public.start_session_request(r8); s8 := (j->>'id')::uuid;
  perform public.confirm_session(s8);
  perform tezgah.olarak(nehir);
  j := public.confirm_session(s8);
  if not (j->>'completed')::boolean then raise exception 'SEED8: R8 çift onayla tamamlanmadı: %', j; end if;

  -- R9 · Arda → T1 · Tuna REDDETTİ (kredi iade)
  perform tezgah.olarak(arda);
  j := public.create_request(t1, 'lounge', 'Merhaba, uygunsan görüşelim.', null); r9 := (j->>'id')::uuid;
  perform tezgah.olarak(tuna);
  perform public.respond_request(r9, 'decline');

  -- R10 · Arda → T2 · BEKLİYOR (Arda İPTAL etmeyi deneyecek)
  perform tezgah.olarak(arda);
  j := public.create_request(t2, 'lounge', 'Öğle arası müsait misin?', null); r10 := (j->>'id')::uuid;

  -- DAVET · Nehir → Arda · N6 · BEKLİYOR (Arda kabul/ret deneyecek)
  -- (soğuk davet yasak: Nehir, Arda'yı R3'te kabul ettiği için davet edebilir)
  perform tezgah.olarak(nehir);
  perform public.send_invite(arda, n6, 'Sabah da salondayım, yanımda yer var — gelir misin?');

  perform tezgah.olarak(null);

  -- ── §5 · BAŞVURU KURALLARI — ÖLÇEREK ────────────────────────────────
  delete from tezgah.harita;

  -- Arda'nın kendi kapıları (hepsi ÖLÇÜLÜYOR, tahmin değil)
  v_sira := v_sira + 1; insert into tezgah.harita values (v_sira, 'akis.misafir', 'Başvuru AÇIK ilan',
    'IST · yarın 14:15 · Tuna H.', 'başvurabilmelisin', tezgah.basvuru_dene(arda, t3),
    'Keşfet → Tuna H. 14:15 → İstek gönder → "Gönderildi"');
  v_sira := v_sira + 1; insert into tezgah.harita values (v_sira, 'akis.misafir', 'DOLU ilan (1/1)',
    'IST · yarın 13:30 · Nehir A.', 'fully_booked', tezgah.basvuru_dene(arda, n2),
    'Kart "Dolu", İstek butonu kapalı');
  v_sira := v_sira + 1; insert into tezgah.harita values (v_sira, 'akis.misafir', 'Seyahatin YOK (AYT)',
    'AYT · 3 gün sonra · Tuna H.', 'no_matching_trip',
    case when t4 is null then 'AYT salonu yok — atlandı' else tezgah.basvuru_dene(arda, t4) end,
    'Kartta "Seyahat ekle" — ekleyince başvurabilirsin');
  v_sira := v_sira + 1; insert into tezgah.harita values (v_sira, 'akis.misafir', 'Güven eşiği 90 (seninki 60)',
    'IST · yarın 16:30 · Tuna H.', 'guven_esigi_altinda', tezgah.basvuru_dene(arda, t5),
    'Bu ilanı Keşfet''te GÖRMEMELİSİN');
  v_sira := v_sira + 1; insert into tezgah.harita values (v_sira, 'akis.misafir', 'Aynı ilana İKİNCİ başvuru',
    'IST · yarın 12:45 · Tuna H.', 'already_requested (300 sonrası)', tezgah.basvuru_dene(arda, t2),
    'Kart "Gönderildi" — ikinci istek butonu yok');
  v_sira := v_sira + 1; insert into tezgah.harita values (v_sira, 'akis.kredisiz', 'Kredisi 0',
    'IST · yarın 14:15 · Tuna H.', 'insufficient_credits', tezgah.basvuru_dene(can_, t3),
    'İstek gönderince "kredin yetersiz" + kredi al yönlendirmesi');
  v_sira := v_sira + 1; insert into tezgah.harita values (v_sira, 'akis.dogrulanmamis', 'İletişim doğrulanmamış',
    'IST · yarın 14:15 · Tuna H.', 'contact_not_verified', tezgah.basvuru_dene(mina, t3),
    'İstek gönderince telefon/e-posta doğrulamaya yönlendirme');

  -- Ela · KURAL MOTORU. Eski SEED'lerin (tazelenmiş) ilanlarında her
  -- ilan × her yolcu profili denenir; her SONUÇ SINIFINDAN bir tane
  -- seçilir. Ela'nın seyahatleri aynı havalimanı+günde çakışmasın diye
  -- seçim açgözlü: çakışan aday atlanır.
  for k in
    with aday as (
      select a.id, a.airport_code, a.avail_date, a.time_from, a.time_to, a.lounge_name,
             p.name as host_adi, a.slots, a.filled
        from availabilities a
        join users hu on hu.id = a.host_id
        join profiles p on p.user_id = a.host_id
       where a.active and a.avail_date >= current_date + 1
         and public.seed_test_hesabi(hu.email)
         and hu.email not like 'akis.%'
         and coalesce(a.min_trust, 0) <= 58
         and coalesce(a.visibility::text, 'Public') = 'Public'
    ), profil as (
      select * from (values
        (1, 1, null::int[], null::text, 'tek kişi'),
        (2, 3, null::int[], null::text, '3 kişilik grup'),
        (3, 2, array[5],    null::text, 'yanında 5 yaşında çocuk'),
        (4, 1, null::int[], 'PC',       'Pegasus biletli')
      ) x(pno, kisi, cocuk, tasiyici, etiket)
    )
    select aday.*, profil.* from aday cross join profil
     order by aday.avail_date, aday.airport_code, aday.time_from, aday.id, profil.pno
  loop
    -- aynı havalimanı+günde Ela'nın çakışan seyahati var mı?
    continue when exists (select 1 from visits v where v.user_id = ela
                           and v.airport_code = k.airport_code and v.visit_date = k.avail_date
                           and v.time_from < k.time_to and k.time_from < v.time_to);
    insert into visits (user_id, airport_code, visit_date, time_from, time_to, carrier_code, purpose, party_size, child_ages)
    values (ela, k.airport_code, k.avail_date, k.time_from, k.time_to, k.tasiyici, 'leisure', k.kisi, k.cocuk)
    returning id into v_vis;

    v_sonuc := tezgah.basvuru_dene(ela, k.id);
    v_sinif := case
      when v_sonuc = 'GECER' then
        'GECER/' || coalesce(public.lounge_access_decision_v6(k.id, null, k.tasiyici, v_vis) ->> 'guest_policy', '?')
      else v_sonuc end;

    if v_sinif = any(v_alinan) or v_sonuc like 'rate_limit%' then
      delete from visits where id = v_vis;           -- bu sınıf zaten var
      continue;
    end if;
    v_alinan := v_alinan || v_sinif;
    v_dec := public.lounge_access_decision_v6(k.id, null, k.tasiyici, v_vis);
    v_sira := v_sira + 1;
    insert into tezgah.harita values (v_sira, 'akis.kural',
      'Kural: ' || coalesce(v_dec ->> 'guest_policy', '?') || ' · ' || k.etiket,
      k.airport_code || ' · ' || to_char(k.avail_date, 'DD.MM') || ' ' || to_char(k.time_from, 'HH24:MI')
        || ' · ' || k.host_adi || ' · ' || coalesce(k.lounge_name, ''),
      coalesce(nullif(v_dec ->> 'headline', ''), v_dec ->> 'guest_policy'),
      v_sonuc,
      case when v_sonuc = 'GECER' then 'İstek gönder AÇIK — gönder ve "Gönderildi"yi gör'
           when v_sonuc = 'fully_booked' then 'Kart "Dolu"'
           else 'İstek butonu KAPALI ya da gönderince bu sebep yazılı' end);
  end loop;

  -- Beklenen sınıfların hangileri bulunamadı? (sessiz geçmiyoruz)
  select string_agg(s, ', ') into v_eksik
    from unnest(array['GECER/included','GECER/paid','guests_not_allowed','party_too_big']) s
   where not (s = any(v_alinan));
  if v_eksik is not null then
    raise notice 'SEED8 §5: kural haritasında bulunamayan sınıf: % (eski SEED ilanları eksik olabilir)', v_eksik;
  end if;

  -- ── §6 · DOĞRULAMA — beklenen durumlar gerçekten kuruldu mu? ────────
  if (select status from requests where id = r1) <> 'pending'   then raise exception 'SEED8: R1'; end if;
  if (select status from requests where id = r2) <> 'pending'   then raise exception 'SEED8: R2'; end if;
  if (select status from requests where id = r3) <> 'accepted'  then raise exception 'SEED8: R3'; end if;
  if (select status from requests where id = r4) <> 'accepted'  then raise exception 'SEED8: R4'; end if;
  if (select status from requests where id = r5) <> 'pending'   then raise exception 'SEED8: R5'; end if;
  if (select status from requests where id = r8) <> 'completed' then raise exception 'SEED8: R8'; end if;
  if (select status from requests where id = r9) <> 'declined'  then raise exception 'SEED8: R9'; end if;
  if (select status from requests where id = r10) <> 'pending'  then raise exception 'SEED8: R10'; end if;
  if (select filled from availabilities where id = n2) <> 1     then raise exception 'SEED8: N2 dolmadı'; end if;
  if (select status from sessions where request_id = r6) <> 'pending' then raise exception 'SEED8: S6'; end if;
  if (select status from sessions where id = s7) <> 'active'    then raise exception 'SEED8: S7'; end if;
  if (select status from sessions where id = s8) <> 'completed' then raise exception 'SEED8: S8'; end if;
  if not exists (select 1 from invites where host_id = nehir and guest_id = arda and status = 'pending') then
    raise exception 'SEED8: davet kurulmadı';
  end if;
  -- Nehir'in kapasite testi GERÇEKTEN kırmızı mı? (kabul etmeyi dene, ölç, geri al)
  perform tezgah.olarak(nehir);
  begin
    perform public.respond_request(r5, 'accept');
    raise exception 'TEZGAH_KABUL_GECTI';
  exception when others then v_sonuc := sqlerrm; end;
  perform tezgah.olarak(null);
  v_sira := v_sira + 1; insert into tezgah.harita values (v_sira, 'akis.host', 'Dolu ilana KABUL',
    'IST · yarın 13:30 · Bora E.', 'fully_booked', v_sonuc,
    'Kabul Et''e basınca "ilan dolu" hatası; istek BEKLİYOR''da kalır');
  if v_sonuc <> 'fully_booked' then raise exception 'SEED8: kapasite kapısı açık! (%)', v_sonuc; end if;

  -- ── §6b · TEST DIŞI HESAPLARA DOKUNULDU MU? ─────────────────────────
  create temp table seed8_sonra on commit drop as
  select 'requests' as tablo, count(*) as n from requests r join users g on g.id=r.guest_id join users h on h.id=r.host_id
                        where not public.seed_test_hesabi(g.email) or not public.seed_test_hesabi(h.email)
  union all select 'requests_durum', coalesce(sum(hashtext(r.id::text || r.status::text)::bigint),0)
                        from requests r join users g on g.id=r.guest_id join users h on h.id=r.host_id
                        where not public.seed_test_hesabi(g.email) or not public.seed_test_hesabi(h.email)
  union all select 'availabilities', count(*) + coalesce(sum(hashtext(a.id::text||a.avail_date::text||a.filled::text||a.active::text)::bigint),0)
                        from availabilities a join users u on u.id=a.host_id where not public.seed_test_hesabi(u.email)
  union all select 'visits',    count(*) + coalesce(sum(hashtext(v.id::text||v.visit_date::text)::bigint),0)
                        from visits v join users u on u.id=v.user_id where not public.seed_test_hesabi(u.email)
  union all select 'credit',    count(*) + coalesce(sum(c.delta),0)
                        from credit_ledger c join users u on u.id=c.user_id where not public.seed_test_hesabi(u.email)
  union all select 'messages',  count(*) from messages m join users u on u.id=m.from_id where not public.seed_test_hesabi(u.email)
  union all select 'sessions',  count(*) + coalesce(sum(hashtext(s.id::text||s.status::text)::bigint),0)
                        from sessions s join requests r on r.id=s.request_id join users g on g.id=r.guest_id join users h on h.id=r.host_id
                        where not public.seed_test_hesabi(g.email) or not public.seed_test_hesabi(h.email)
  union all select 'invites',   count(*) from invites i join users g on g.id=i.guest_id join users h on h.id=i.host_id
                        where not public.seed_test_hesabi(g.email) or not public.seed_test_hesabi(h.email)
  union all select 'notifications', count(*) from notifications n join users u on u.id=n.user_id where not public.seed_test_hesabi(u.email)
  union all select 'profiles',  count(*) + coalesce(sum(hashtext(coalesce(p.name,'')||coalesce(p.show_on_discovery::text,''))::bigint),0)
                        from profiles p join users u on u.id=p.user_id where not public.seed_test_hesabi(u.email);

  select count(*) into v_n from tezgah.seed8_once o join seed8_sonra s using (tablo) where o.n is distinct from s.n;
  if v_n > 0 then
    raise exception 'SEED8: TEST DIŞI HESAPLARDA % tabloda değişim ölçüldü — HER ŞEY GERİ ALINDI (%)', v_n,
      (select string_agg(o.tablo, ', ') from tezgah.seed8_once o join seed8_sonra s using (tablo) where o.n is distinct from s.n);
  end if;

  delete from rate_limits where user_id = any(hepsi);   -- uygulamada deneyince sınıra takılma
  perform set_config('ll.test_mode', '', true);
  raise notice 'SEED8: akış dünyası kuruldu · test dışı hesaplara dokunulmadı (10 tablo ölçüldü)';
end $akis$;

-- ── Keşfet ne gösteriyor? (Arda'nın gözünden, GERÇEK keşif sorgusu) ─────
-- >>> kod_metni (üretildi: uretec/seed8_metin_uret.py — ELLE DEĞİŞTİRME)
-- Kullanıcının TÜRKÇE ekranda gördüğü cümle (mapErr · src/i18n.js). 223 kod.
create or replace function tezgah.kod_metni(p text) returns text language sql immutable as $$
  select case p
    when 'access_source_required' then 'En az bir erişim kaynağı seç.'
    when 'account_banned' then 'Bu hesap askıya alındı. İtiraz için destek@loungelink.co adresine yaz.'
    when 'account_deleted' then 'Bu hesabın silinmesi talep edildi; yazma işlemleri kapalı.'
    when 'acik_istek_tavani' then 'Aynı anda açabileceğin istek sayısına ulaştın. Bekleyen isteklerinden biri sonuçlanınca yenisini gönderebilirsin — üst planda daha fazlası olur.'
    when 'active_session_exists' then 'Devam eden bir oturumun var. Bu bağlantıyı ancak oturum tamamlandıktan sonra kaldırabilirsin.'
    when 'agirlayarak_kazanilan_kredi_yetersiz' then 'Yalnız ağırlayarak kazandığın haklar hediye edilebilir; satın alınan kredi devredilemez.'
    when 'airport_required' then 'Havalimanı seçmen gerekiyor.'
    when 'already_decided' then 'Bu istek zaten yanıtlandı.'
    when 'already_host' then 'Zaten ilan açabiliyorsun.'
    when 'already_on_plan' then 'Zaten bu plandasın.'
    when 'already_rated' then 'Bu oturumu zaten puanladın.'
    when 'already_requested' then 'Bu ilana zaten istek gönderdin — yanıtı bekleniyor.'
    when 'already_responded' then 'Zaten yanıtladın.'
    when 'already_reviewed' then 'Zaten değerlendirdin.'
    when 'already_settled' then 'Bu talep zaten sonuçlanmış.'
    when 'application_not_found' then 'Başvuru bulunamadı.'
    when 'application_pending' then 'Başvurun zaten inceleniyor.'
    when 'availability_expired' then 'Bu ilan süresi doldu.'
    when 'availability_inactive' then 'Bu ilan artık yayında değil.'
    when 'availability_not_found' then 'İlan bulunamadı.'
    when 'ayni_saatte_seyahatin_var' then 'Aynı gün ve saatte bu havalimanında zaten bir seyahatin var.'
    when 'bad_phone_format' then 'Telefon biçimi geçersiz.'
    when 'bad_purpose' then 'Seyahat amacı geçersiz. Listeden bir amaç seç.'
    when 'bad_score' then 'Geçersiz puan.'
    when 'bad_visibility' then 'Geçersiz görünürlük.'
    when 'baglanti_kabul_edilmedi' then 'Sohbet, karşı taraf isteği kabul edince açılır.'
    when 'baglanti_soguma' then 'Bu kişiye kısa süre önce istek gönderdin ve olumsuz yanıtlandı. Yeni istek için 7 gün beklemen gerekiyor.'
    when 'baglanti_yok' then 'Misafir hakkını yalnız bağlantılarına hediye edebilirsin.'
    when 'baskasinin_verisi' then 'Bu veri sana ait değil.'
    when 'bilinmeyen_durum' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'bilinmeyen_is' then 'Bu işlemi tanımadık. Uygulamayı güncelle; sorun sürerse bize yaz.'
    when 'blocked_pair' then 'Bu kullanıcıyla iletişim kapalı.'
    when 'bos_adres' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'cabin_required' then 'Bu hak bilet sınıfından geliyor; host ekonomi uçtuğu için salon hakkı yok.'
    when 'campaign_not_found_or_ended' then 'Kampanya bulunamadı veya sona erdi.'
    when 'cannot_block_self' then 'Kendini engelleyemezsin.'
    when 'cannot_cancel' then 'Bu iptal edilemez.'
    when 'cannot_report_self' then 'Kendini bildiremezsin.'
    when 'capacity_required' then 'Kapasite gerekli.'
    when 'child_ages_invalid' then 'Çocuk yaşları 0–17 arasında olmalı ve kişi sayısından az olmalı.'
    when 'children_not_allowed' then 'Bu salon yanındaki çocuğu almıyor. Başka bir salon ya da host seç.'
    when 'cinsiyet_degistirilemez' then 'Cinsiyet beyanı bir kez yapılır. Değiştirmek için destekle iletişime geç.'
    when 'closed' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'code_already_used' then 'Bu kod zaten kullanıldı.'
    when 'code_limit_reached' then 'Kod kullanım sınırına ulaşıldı.'
    when 'cold_invite_blocked' then 'Tanımadığın kişiye toplu davet gönderemezsin.'
    when 'connection_exists' then 'Zaten bağlısınız.'
    when 'connection_not_found' then 'Bağlantı bulunamadı.'
    when 'consent_missing' then 'Yayınlanması için önce izin vermen gerekiyor.'
    when 'contact_not_verified' then 'Devam etmek için telefonunu veya e-postanı doğrulaman gerekiyor.'
    when 'cuzdan_sahibi_degil' then 'Bu cüzdan senin değil.'
    when 'date_in_future' then 'Tarih gelecekte olamaz.'
    when 'date_in_past' then 'Tarih geçmişte olamaz.'
    when 'date_required' then 'Tarih gerekli.'
    when 'delta_must_be_positive' then 'Değer pozitif olmalı.'
    when 'delta_zero' then 'Değer sıfır olamaz.'
    when 'description_required' then 'Açıklama gerekli.'
    when 'display_name_required' then 'Görünecek bir ad yaz — soyadını kısaltabilirsin.'
    when 'dispute_already_open' then 'Bu buluşma için zaten açık bir bildirimin var. Ekibimiz inceliyor.'
    when 'dispute_not_found' then 'İtiraz bulunamadı.'
    when 'dispute_reason_invalid' then 'Bir sebep seçmelisin.'
    when 'dispute_window_closed' then 'Bildirim süresi doldu. Yine de yazmak istersen destek@loungelink.co.'
    when 'eksik_parametre' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'email_invalid' then 'Geçersiz e-posta.'
    when 'email_not_confirmed' then 'E-postan henüz onaylanmamış. Gönderdiğimiz koddaki adımı tamamla.'
    when 'email_required' then 'E-posta gerekli.'
    when 'email_taken' then 'Bu e-posta zaten kayıtlı.'
    when 'empty_phone' then 'Telefon numarası boş olamaz.'
    when 'empty_status' then 'Durum boş olamaz.'
    when 'fully_booked' then 'Bu ilanın tüm slotları dolu. Başka bir ilana ya da başka bir güne bak.'
    when 'gecersiz_adet' then 'Bir seferde en fazla 3 hak hediye edebilirsin.'
    when 'gecersiz_cinsiyet' then 'Geçerli bir seçim yap.'
    when 'gecersiz_deger' then 'Girilen değer geçersiz. Listeden bir seçenek seç.'
    when 'gecersiz_durum' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'gecersiz_eposta' then 'Geçerli bir e-posta adresi gir.'
    when 'gecersiz_gun' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'gecersiz_karar' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'gecersiz_maliyet' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'gecersiz_politika' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'gecersiz_rol' then 'Geçersiz rol seçimi.'
    when 'gecersiz_sebep' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'gecersiz_yontem' then 'Doğrulama yöntemi tanınmadı.'
    when 'gelmedi_erken' then 'Karşı tarafı biraz daha bekle — "Gelmedi mi?" bildirimi bekleme süresi dolunca açılır.'
    when 'gelmedi_once_baslat' then 'Önce sen oturumu başlatmalısın; bildirim yalnız bekleyen taraf için.'
    when 'guest_carrier_mismatch' then 'Bu host''un kartı yalnız kendi havayoluyla uçan misafiri alıyor. Senin uçuşun uymuyor — kapıda reddedilirdin, o yüzden istek gönderilmedi.'
    when 'guest_same_slot' then 'Aynı saatte hem host hem misafir olamazsın.'
    when 'guests_not_allowed' then 'Bu ilan misafir kabul etmiyor — bu salon yalnız kart sahibini alıyor.'
    when 'gunluk_hediye_tavani' then 'Günde en fazla 3 hediye gönderebilirsin.'
    when 'guven_esigi_altinda' then 'Bu ilan için gereken güven skoruna henüz ulaşmadın. Kimliğini doğrulayarak ve oturum tamamlayarak yükseltebilirsin.'
    when 'has_accepted_requests' then 'Kabul edilmiş isteği olan bir ilan silinemez — önce isteği iptal et.'
    when 'has_sessions_cannot_hard_delete' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'hediye_yok' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'hosting_same_slot' then 'Aynı saatte kendi ilanın var. Önce ilanını kaldır veya farklı bir saat seç.'
    when 'insufficient_credits' then 'Yetersiz kredi.'
    when 'insufficient_points' then 'Yetersiz puan.'
    when 'invalid_cabin' then 'Kabin seçimi geçersiz — Economy, Business ya da First seç.'
    when 'invalid_code' then 'Geçersiz kod.'
    when 'invalid_email' then 'E-posta adresi geçersiz.'
    when 'invalid_field' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'invalid_guest_capacity' then 'Misafir kapasitesi 0 ile 6 arasında olmalı.'
    when 'invalid_min_trust' then 'Güven eşiği 0 ile 100 arasında olmalı.'
    when 'invalid_or_expired_code' then 'Bu kod geçersiz veya süresi dolmuş.'
    when 'invalid_outcome' then 'Bildirim sonucu seçilmedi.'
    when 'invalid_phone' then 'Telefon numarası geçerli görünmüyor. Ülke koduyla yaz (örn. +90 5xx xxx xx xx).'
    when 'invalid_quota_period' then 'Hak dönemi geçersiz — yıllık veya ziyaret başına seç.'
    when 'invalid_referral_code' then 'Bu davet kodu geçersiz veya süresi dolmuş.'
    when 'invalid_slots' then 'Kontenjan 1 ile 6 arasında olmalı.'
    when 'invalid_time_range' then 'Bitiş saati başlangıçtan sonra olmalı.'
    when 'invalid_token_format' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'invalid_visibility' then 'Geçersiz görünürlük seçimi.'
    when 'invite_not_found' then 'Bu davet bulunamadı veya geri çekilmiş.'
    when 'kabul_edilmis_basvuru_var' then 'Bu ilanı kabul edilmiş bir misafir bekliyor. Tarih, saat ve salon değiştirilemez — kontenjanı artırabilir, uçuş numarasını düzeltebilirsin.'
    when 'kapatilamaz_kategori' then 'Bu bildirim türü kapatılamıyor — istek, oturum ve güvenlik bildirimleri zorunlu.'
    when 'karsi_taraf_geldi' then 'Karşı taraf da oturumu başlattı — buluşma başladı.'
    when 'kart_yok' then 'Bu kart cüzdanında bulunamadı. Önce kartını tanıt.'
    when 'kendi_ilanlarin_cakisiyor' then 'Aynı saatte başka bir ilanın var. Önce onu kaldır ya da saatleri ayır.'
    when 'kendine_hediye_olmaz' then 'Kendine hediye gönderemezsin.'
    when 'kontenjan_azaltilamaz' then 'Kabul edilmiş misafir varken kontenjan düşürülemez.'
    when 'kontenjan_dolulugun_altinda' then 'Kontenjan, dolu koltuk sayısının altına indirilemez.'
    when 'kullanici_yok' then 'Bu kullanıcı bulunamadı — hesabı kapatılmış olabilir.'
    when 'kyc_already_approved' then 'Kimliğin zaten doğrulanmış.'
    when 'kyc_already_submitted' then 'Belgen zaten incelemede; sonucu bekle.'
    when 'kyc_path_invalid' then 'Belge yolu geçersiz.'
    when 'location_off' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'makbuz_kimligi_bos' then 'Satın alma makbuzu okunamadı. Mağaza işlemini tekrar dene.'
    when 'marketplace_closed' then 'İstek gönderme şu an geçici olarak kapalı. Kısa süre içinde tekrar dene.'
    when 'net_yanit_tablosu_yok' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'no_access_declared' then 'Önce lounge erişim kaynağını beyan et.'
    when 'no_access_source' then 'Önce lounge erişim kaynağını seç (Profil › Lounge Erişim Kurulumu).'
    when 'no_listing' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'no_matching_trip' then 'Bu ilana istek göndermek için aynı havalimanı ve tarihte örtüşen bir seyahatin olmalı.'
    when 'not_a_host' then 'İlan açabilmek için önce host olman gerekiyor. Planım → Host ol adımından lounge hakkını beyan et.'
    when 'not_a_participant' then 'Bu oturumun tarafı değilsin.'
    when 'not_active' then 'Bu oturum artık aktif değil — sayfayı yenile.'
    when 'not_admin' then 'Bu işlem için yönetici yetkisi gerekiyor.'
    when 'not_authenticated' then 'Oturum açman gerekiyor.'
    when 'not_authorized' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'not_completed' then 'Oturum henüz tamamlanmadı.'
    when 'not_found' then 'Kayıt bulunamadı. Sayfayı yenileyip tekrar dene.'
    when 'not_found_or_not_yours' then 'Bu kart sende kayıtlı değil — sayfayı yenileyip tekrar dene.'
    when 'not_guest' then 'Bu isteği yalnızca gönderen misafir iptal edebilir.'
    when 'not_host' then 'Bu isteği yalnızca ilanı açan kişi yanıtlayabilir.'
    when 'not_host_of_session' then 'Bu oturumu sen ağırlamamışsın.'
    when 'not_open' then 'Bu istek zaten yanıtlanmış.'
    when 'not_owner' then 'Bu kayıt sana ait değil, o yüzden değiştiremezsin.'
    when 'not_participant' then 'Katılımcı değilsin.'
    when 'not_party' then 'Bu oturum sana ait değil — yalnız host ve misafir görebilir.'
    when 'not_pending' then 'Bu istek artık beklemede değil; başka biri ya da sen daha önce yanıtlamışsın.'
    when 'not_recipient' then 'Alıcı sen değilsin.'
    when 'not_your_availability' then 'Bu ilan sana ait değil.'
    when 'not_your_connection' then 'Bu bağlantı senin değil.'
    when 'not_your_session' then 'Bu oturum sana ait değil.'
    when 'not_your_visit' then 'Bu seyahat sana ait değil.'
    when 'odul_fiyati_maliyetin_altinda' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'odul_maliyeti_yazilmamis' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'odul_yok' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'otp_bypass_locked' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'out_of_stock' then 'Stokta yok.'
    when 'paket_abonelikten_ucuz' then 'Bu paket, en ucuz abonelikten daha ucuza kredi veriyor. Paket bir takviyedir, aboneliğin alternatifi değil — fiyatı yükselt ya da kredi adedini düşür.'
    when 'paket_yok' then 'Bu paket artık satışta değil. Güncel paketleri cüzdanından görebilirsin.'
    when 'party_size_invalid' then 'Kişi sayısı 1 ile 6 arasında olmalı.'
    when 'party_too_big' then 'Bu host''un hakkı seninle gelenlerin hepsine yetmiyor. Seyahatindeki kişi sayısını düşür ya da başka bir host seç.'
    when 'pg_net_yok' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'phone_invalid' then 'Geçersiz telefon.'
    when 'phone_not_verified' then 'Önce telefonunu doğrula.'
    when 'phone_taken' then 'Bu telefon zaten kayıtlı.'
    when 'plan_pasif_veya_yok' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'quota_exhausted' then 'Host''un bu dönem misafir hakkı bitmiş. Başka bir host seç.'
    when 'quota_used_exceeds_total' then 'Kullanılan hak sayısı, toplam hakkından fazla olamaz.'
    when 'rate_limited' then 'Çok sık denedin — bu işlem için hakkın geçici olarak doldu.'
    when 'rate_limited_request' then 'Çok hızlı istek gönderdin. Saatlik istek hakkın doldu.'
    when 'rate_limited_waitlist' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'redemption_not_found' then 'Talep bulunamadı.'
    when 'ref_required' then 'Teslim referansı boş olamaz.'
    when 'referral_already_used' then 'Davet kodu zaten kullanıldı.'
    when 'refund_exceeds_hold' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'request_not_accepted' then 'İstek henüz kabul edilmedi.'
    when 'request_not_found' then 'İstek bulunamadı.'
    when 'ret_notu_zorunlu' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'reward_fulfillment_undefined' then 'Bu ödülün teslim koşulu tanımlı değil — şu an alınamaz.'
    when 'reward_inactive' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'reward_not_found' then 'Ödül bulunamadı.'
    when 'reward_unavailable' then 'Bu ödül şu an mağazada değil.'
    when 'rule_ask_daily_limit' then 'Günde en fazla 5 host''a soru gönderebilirsin. Yarın tekrar dene.'
    when 'rule_ask_not_applicable' then 'Bu ilanda soracak bir şey yok — kuralı resmî kaynaktan doğruladık.'
    when 'scope_mismatch' then 'Salon, uçuşunun olduğu tarafta değil (iç hat / dış hat). Pasaport kontrolünün öbür yanına geçilemez.'
    when 'self_connect_blocked' then 'Kendine bağlantı gönderemezsin.'
    when 'self_referral_blocked' then 'Kendi kodunu kullanamazsın.'
    when 'self_request_blocked' then 'Kendine istek gönderemezsin.'
    when 'server' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'session_active' then 'Oturum zaten aktif.'
    when 'session_closed' then 'Bu oturum kapanmış.'
    when 'session_not_active' then 'Oturum aktif değil.'
    when 'session_not_completed' then 'Bu oturum henüz tamamlanmadı.'
    when 'session_not_found' then 'Oturum bulunamadı.'
    when 'session_started' then 'Oturum başladı; iptali oturum ekranından yapabilirsin.'
    when 'seyahat_silinemez_basvuru_var' then 'Bu seyahate dayanan bir başvurun var. Seyahati silmeden önce başvuruyu iptal et.'
    when 'seyahate_bagli_basvuru_var' then 'Bu seyahate dayanan aktif bir başvurun var. Havalimanı ve tarih kilitli; saat ve uçuş bilgisini değiştirebilirsin.'
    when 'slots_exceed_capacity' then 'Seçtiğin misafir sayısı, kartının verdiği hakkı aşıyor. Profil › Lounge Erişim''den hakkını güncelleyebilirsin.'
    when 'sms_not_configured' then 'SMS doğrulaması henüz aktif değil. E-posta ile doğrulayabilirsin.'
    when 'story_not_found' then 'Bu cümle bulunamadı.'
    when 'sure_doldu' then 'Bu bildirim için süre doldu (oturumdan sonraki ilk saatler içinde yapılabiliyor).'
    when 'talep_araligi_uzun' then 'En fazla 60 günlük bir aralık bırakabilirsin.'
    when 'talep_bulunamadi' then 'Bu kayıt bulunamadı — kaldırılmış olabilir.'
    when 'talep_kayit_tavani' then 'Aynı anda tutabileceğin haber-ver kaydı sayısına ulaştın. Önce eskilerden birini kaldır.'
    when 'target_not_found' then 'Aradığın kayıt bulunamadı — silinmiş ya da süresi geçmiş olabilir.'
    when 'tarih_zorunlu' then 'Tarih seçmelisin.'
    when 'too_many_active_requests' then 'Aynı anda çok fazla açık isteğin var. Önce mevcut isteklerinden birini iptal et ya da yanıt bekle.'
    when 'too_many_attempts' then 'Çok fazla deneme. Sonra tekrar dene.'
    when 'too_many_cards' then 'Bu programdan en fazla 4 kart ekleyebilirsin. Kullanmadığın bir kartı kaldırıp yeniden dene.'
    when 'too_many_requests' then 'Çok fazla istek. Sonra tekrar dene.'
    when 'unknown_action' then 'Bu işlem tanınmadı. Uygulamayı güncellemen gerekebilir.'
    when 'unknown_airport' then 'Havalimanı kodu tanınmadı.'
    when 'unknown_program' then 'Bu programı tanımıyoruz. Listeden seçersen kuralını da gösterebiliriz.'
    when 'user_not_found' then 'Kullanıcı bulunamadı.'
    when 'verification_not_found' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'visit_not_found' then 'Seyahat bulunamadı.'
    when 'would_go_negative' then 'Bu işlem için yeterli kredin yok.'
    when 'yonetici_degil' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'zaten_aktif_hediye_var' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    when 'zaten_bildirildi' then 'Bunu zaten bildirdin — ekibimiz inceliyor.'
    when 'zaten_dogrulandi' then 'Bu biniş kartı başka bir hesapta doğrulanmış. Kendi biniş kartını kullan ya da doğrulamayı atla.'
    when 'zaten_kapali' then 'Bir şeyler ters gitti. Lütfen tekrar dene.'
    else 'Bir şeyler ters gitti. Lütfen tekrar dene.' end
$$;
-- <<< kod_metni

create table if not exists tezgah.rapor (
  sira int primary key, hesap text, senaryo text, nerede text,
  beklenen text, sunucu text, ekranda text
);
delete from tezgah.rapor;

do $rapor$
declare v_top int; v_ist int; v_bas int; v_arda uuid;
begin
  select id into v_arda from tezgah.seed8_hesap where email = 'akis.misafir@seed.loungelink.test';
  perform tezgah.olarak(v_arda);
  select count(*), count(*) filter (where airport_code = 'IST'), count(*) filter (where not blocks_request)
    into v_top, v_ist, v_bas
    from public.discover_availabilities(null, null, null, null);
  perform tezgah.olarak(null);

  insert into tezgah.rapor values (0, 'KEŞFET (Arda gözüyle)', 'gerçek keşif sorgusu', '',
    v_top || ' ilan · IST ' || v_ist || ' · başvurulabilir ' || v_bas,
    case when v_top > 0 then 'DOLU ✓' else 'BOŞ ✗ — bu satırı bana gönder' end,
    'Şifre (hepsi): Seed1234!');

  insert into tezgah.rapor
  select 100 + x.n, x.hesap, x.senaryo, x.nerede, x.beklenen, 'AKIŞ', x.ekranda from (values
    (1,  'akis.host (Nehir)',    'Gelen istek → KABUL ET',       'IST yarın 10:00 · Bora E.',  'Kabul → sohbet açılır',               'İlanlarım → Bekleyen → Bora → Kabul et'),
    (2,  'akis.host (Nehir)',    'Gelen istek → REDDET',         'IST yarın 10:00 · Cem D.',   'Ret → Cem''e kredi iadesi',           'İlanlarım → Bekleyen → Cem → Reddet'),
    (3,  'akis.host (Nehir)',    'Dolu ilana kabul',             'IST yarın 13:30 · Bora E.',  'fully_booked hatası',                 'Kabul et → "ilan dolu"'),
    (4,  'akis.misafir (Arda)',  'Kabul edildi → OTURUM BAŞLAT', 'IST yarın 10:00 · Nehir A.', 'İki taraf da basınca başlar',         'Sohbet (4 mesaj) → Oturumu Başlat · sonra Nehir de basar'),
    (5,  'akis.misafir (Arda)',  'Nehir başlattı → sen de başlat','IST yarın 16:00 · Nehir A.','Sen basınca oturum SÜRÜYOR olur',     'Sohbet → Oturumu Başlat'),
    (6,  'akis.misafir (Arda)',  'Oturum sürüyor → TAMAMLA',     'IST yarın 18:00 · Nehir A.', 'Nehir onayladı; sen onaylayınca biter','Sohbet → Oturumu tamamla → puanlama'),
    (7,  'akis.misafir (Arda)',  'Tamamlandı → PUANLA',          'IST yarın 20:00 · Nehir A.', '1–5 yıldız + yorum',                  'Sohbet ya da Değerlendirmeler → puanla'),
    (8,  'akis.misafir (Arda)',  'Bekleyen isteği İPTAL ET',     'IST yarın 12:45 · Tuna H.',  'İptal → kredi iadesi',                'Keşfet → Tuna 12:45 "Gönderildi" → İptal'),
    (9,  'akis.misafir (Arda)',  'Reddedilmiş istek',            'IST yarın 11:00 · Tuna H.',  'Kart "reddedildi" der',               'Keşfet → Tuna 11:00'),
    (10, 'akis.misafir (Arda)',  'Gelen DAVET → kabul/ret',      'IST yarın 07:00 · Nehir A.', 'Kabul → sohbet + oturum',             'Bildirimler / Ana sayfa → Davet'),
    (11, 'akis.misafir (Arda)',  'SOHBET gerçek zamanlı',        'Nehir ile 10:00 sohbeti',    'Mesaj anında karşıya düşer',          'Arda yazar → çıkış → Nehir ile gir → mesaj orada'),
    (12, 'akis.host (Nehir)',    'Misafir GELMEDİ → bildir (301)','IST yarın 16:00 · Arda K.', '20 dk bekliyorsun → buluşma kapanır, Arda''nın güveni düşer', 'Sohbet (Arda) → "Gelmedi mi? Bildir" → Evet  ⚠ yaparsan 5. satır biter — önce 5''i dene'),
    (13, 'akis.misafir4 (Duru)', 'BİLDİR + ENGELLE (301)',       'Tuna H. profili',            'Tuna Keşfet''ten kaybolur; engel listende görünür', 'Keşfet → Tuna → profil → Bildir → "Bu kişiyi de engelle" · sonra Profil → Güvenlik → Engellenen Kullanıcılar → Engeli kaldır'),
    (14, 'Gerçek hesabın',       'Test dünyası SANA açık (302)', 'Keşfet · Tanış',             'akis.* ilanlarını görürsün; diğer gerçek kullanıcılar görmez', 'Görmüyorsan uygulamadaki e-postan farklıdır: BO → Kullanıcılar → hesabın → "Test hesaplarını görsün"')
  ) x(n, hesap, senaryo, nerede, beklenen, ekranda);

  insert into tezgah.rapor
  select 200 + h.sira, h.hesap, h.senaryo, h.nerede, h.beklenen,
         case when h.sunucu = 'GECER' then 'GEÇER ✓' else h.sunucu end, h.ekranda
    from tezgah.harita h;
end $rapor$;

commit;

-- ════════════════════════════════════════════════════════════════════════
-- SONUÇ — hangi hesapla gir, ne göreceksin
--   sunucu_kodu: "GEÇER ✓" ya da sunucunun GERÇEKTEN döndürdüğü TEKNİK kod (kullanıcı görmez)
--   uygulamada_gorunen: o kodun kullanıcıya Türkçe ekranda gösterilen cümlesi
-- ════════════════════════════════════════════════════════════════════════
-- `sunucu` TEKNİK koddur (tezgâh ölçüsü) — kullanıcı onu GÖRMEZ.
-- Kullanıcının gördüğü cümle `uygulamada_gorunen` sütununda (TR sözlükten).
select sira, hesap, senaryo, nerede, beklenen, sunucu as sunucu_kodu,
       case when sira < 200 or sunucu like 'GEÇER%' then '—' else tezgah.kod_metni(sunucu) end as uygulamada_gorunen,
       ekranda
  from tezgah.rapor order by sira;
