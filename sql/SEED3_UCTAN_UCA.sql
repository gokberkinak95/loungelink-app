-- ============================================================================
-- LoungeLink · SEED3_UCTAN_UCA.sql                        (19 Ağustos 2026)
--
-- İKİ HOST, İKİ MİSAFİR — HER AKIŞ TEK OTURUMDA GÖRÜLSÜN
--
-- Gökberk: "en azından 2 host ve 2 guestten tüm akışları tüm seçenekleri
-- tüm kuralları vs doğrudan gözlemleyip doğrulayabilmeliyim."
--
-- ── MEVCUT SEED'LER NEDEN YETMİYORDU ────────────────────────────────
-- SEED_KURAL_SENARYOLARI  → 18 ayrı hesap, her biri TEK kuralı gösteriyor.
--                           Kural motorunu ölçmek için mükemmel, ÜRÜNÜ
--                           gezmek için kullanışsız: her senaryo için
--                           çıkış yapıp başka hesapla girmek gerekiyor.
-- SEED2_KAYNAK_SENARYOLARI → aynı biçim, 7 hesap daha.
--
-- İkisi de "kural doğru mu" sorusunu yanıtlıyor. Bu seed "ürün çalışıyor
-- mu" sorusunu yanıtlıyor — ve o soru YALNIZCA az sayıda hesapla, akışın
-- İKİ TARAFINI birden görerek yanıtlanır. Dört hesap: iki host, iki
-- misafir. Hepsi birbirine bağlı, her ekranda dolu veri var.
--
-- 🔴 ESKİ SEED'LERE DOKUNMUYORUM. Bu dosya onların yerine geçmiyor,
-- yanlarına ekleniyor: kural nöbetçileri (rule_matrix_test, e2e testleri)
-- onların verisine bakıyor. Silseydim 18 senaryonun nöbetçisi kör kalırdı.
--
-- ── HESAPLAR ────────────────────────────────────────────────────────
--   host1@seed.loungelink.test    şifre: Seed1234!   "her şeyi olan host"
--   host2@seed.loungelink.test    şifre: Seed1234!   "kısıtlı host"
--   guest1@seed.loungelink.test   şifre: Seed1234!   "deneyimli misafir"
--   guest2@seed.loungelink.test   şifre: Seed1234!   "yeni misafir"
--
-- ── HANGİ HESAPTAN NE GÖRÜLÜR ───────────────────────────────────────
--   host1  · CÜZDAN dolu (TK M&S Elite Plus + Priority Pass Prestige)
--          · üç ilan: ücretsiz misafirli / ücretli misafirli / dolu
--          · gelen istek (bekleyen), kabul edilmiş istek, aktif oturum
--          · tamamlanmış + puanlanmış oturum, reddedilmiş istek
--          · ücretli plan (Sık Uçan) → plan ekranı dolu
--   host2  · tek kart (DragonPass Classic) → kısıtlı hak
--          · "misafir hakkı görünmüyor" ilanı → guest'te HOST'A SOR butonu
--          · charter ilanı → charter kapısı
--          · ücretsiz plan (Yolcu)
--   guest1 · host1 ilanlarıyla eşleşen seyahatler, 6 kredi
--          · bekleyen istek + aktif oturum + tamamlanmış oturum
--          · host1 ile bağlantı ve sohbet
--   guest2 · host2'nin kapalı ilanıyla eşleşen seyahat → kapalı kapı
--          · host1'in ücretli ilanıyla eşleşen seyahat → ücret akışı
--          · 3 kredi, hiç oturumu yok → "ilk kez" hâli
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- 0) HESAPLAR
-- ════════════════════════════════════════════════════════════════════════
insert into auth.users (id, email)
select x.id::uuid, x.email
  from (values
    ('33330001-0000-4000-8000-000000000001','host1@seed.loungelink.test'),
    ('33330002-0000-4000-8000-000000000002','host2@seed.loungelink.test'),
    ('33330003-0000-4000-8000-000000000003','guest1@seed.loungelink.test'),
    ('33330004-0000-4000-8000-000000000004','guest2@seed.loungelink.test')
  ) as x(id, email)
 where not exists (select 1 from auth.users a where a.email = x.email);

-- 🔴 20 AĞUSTOS — ŞİFRE ARTIK BAŞKA BİR SEED'DEN KOPYALANMIYOR.
--
-- Eski kurgu hash'i `kural1@seed.loungelink.test`ten alıyordu ve gerekçesi
-- "iki seed iki farklı hash kurmasın" idi. Ama bu iki sorun üretiyordu:
--   (1) SEED3'ü BAĞIMLI kılıyordu — birinci seed atılmamışsa fallback'e
--       düşüyor, atılmışsa o hesabın şifresi neyse o oluyordu.
--   (2) İkinci update `where encrypted_password is null` diyordu; yani bir
--       kez yanlış hash yazıldıysa BİR DAHA DÜZELTİLEMİYORDU.
-- Şifre hepsinde aynı sabit (`Seed1234!`) olduğuna göre "kopyalamak"
-- zaten gereksizdi: aynı şifreden üretilen iki farklı bcrypt hash de
-- doğrular. SEED3 artık kendi kendine yeter.
--
-- 🔴 crypt() Supabase'de `extensions` şemasında; bazı kurulumlarda arama
-- yolunda olmayabilir. Dinamik çözümleme (birinci seed'in dersi).
do $sifre$
declare v_sql text;
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where p.proname = 'crypt' and n.nspname = 'extensions') then
    v_sql := 'update auth.users set encrypted_password = extensions.crypt($1, extensions.gen_salt(''bf''))';
  elsif exists (select 1 from pg_proc where proname = 'crypt') then
    v_sql := 'update auth.users set encrypted_password = crypt($1, gen_salt(''bf''))';
  else
    raise exception 'SEED3: pgcrypto YOK — sifre yazilamaz. Supabase -> Database -> Extensions -> pgcrypto';
  end if;
  execute v_sql || ' where email in (''host1@seed.loungelink.test'',''host2@seed.loungelink.test'','
                || '''guest1@seed.loungelink.test'',''guest2@seed.loungelink.test'')'
    using 'Seed1234!';
end $sifre$;

update auth.users
   set email_confirmed_at = coalesce(email_confirmed_at, now())
 where email in ('host1@seed.loungelink.test','host2@seed.loungelink.test',
                 'guest1@seed.loungelink.test','guest2@seed.loungelink.test');

-- 🔴 20 AĞUSTOS — GoTrue KABLOLAMASI BURADA EKSİKTİ.
-- Yalnız `encrypted_password` yazmak GİRİŞ İÇİN YETMEZ. Supabase üç şey
-- ister: hash + GoTrue alanları (aud/role/instance_id/token kolonları)
-- + `auth.identities` satırı (provider='email'). Üçüncüsü yoksa şifre
-- doğru olsa bile "Invalid login credentials" döner — Gökberk tam olarak
-- bunu aldı. Doğrusu birinci seed'de zaten yazılıydı; buraya
-- kopyalanmamıştı. Ayrıntı ve nöbetçi: 227_seed_giris_onarimi.sql
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
  execute 'update auth.users set ' || v_set || ' where email like ''%@seed.loungelink.test''';
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
     where u.email like '%@seed.loungelink.test'
       and not exists (select 1 from auth.identities i
                        where i.user_id=u.id and i.provider='email');
  end if;
end $kimlik$;

insert into users (id, email, role, plan)
select a.id, a.email,
       (case when a.email like 'host%' then 'host' else 'guest' end)::user_role,
       -- Plan ekranının DOLU görünmesi için biri ücretli, biri ücretsiz.
       case when a.email = 'host1@seed.loungelink.test' then 'sik_ucan'::plan_type
            else 'yolcu'::plan_type end
  from auth.users a
 where a.email in ('host1@seed.loungelink.test','host2@seed.loungelink.test',
                   'guest1@seed.loungelink.test','guest2@seed.loungelink.test')
   and not exists (select 1 from users u where u.id = a.id);

-- ════════════════════════════════════════════════════════════════════════
-- 🔴 20 AĞUSTOS — "APP'TE HİÇ İLAN GÖREMİYORUM" — SEBEBİ BU SATIRLARDI
--
-- Yukarıdaki insert `and not exists (...)` ile korunuyor. Ama
-- `auth.users`'a yazınca `on_auth_user_created` TETİKLEYİCİSİ ateşleniyor
-- ve `public.users` satırını KENDİSİ oluşturuyor — VARSAYILAN rolle:
--     users.role DEFAULT 'guest'
-- Yani insert'e sıra geldiğinde satır ZATEN VAR, `not exists` false,
-- insert ATLANIYOR ve host1/host2 **'guest' olarak kalıyor**.
--
-- Sonuç ölçüldü: `discover_availabilities_base` şu kapıyı uyguluyor —
--     and (hu.role = 'host' or <onayli host_application>)
-- host1/host2 'guest' olduğu için ilanları KEŞİFTE HİÇ GÖRÜNMÜYOR.
-- 7 ilan veritabanında duruyordu ve uygulamada hiçbiri yoktu.
--
-- 🔴 Doğrusunu birinci seed yine yapmış: `update users set role='host'
-- where email like 'kural%'`. SEED3'e insert kopyalanmış, DÜZELTME
-- kopyalanmamış. Giriş hatasıyla AYNI SINIF: "kopyalarken neyi
-- kopyaladığını söylemek, kopyaladığını kanıtlamaz."
--
-- Çözüm: rol ve plan KOŞULSUZ update ile yazılır. Tetikleyici ne
-- yazmış olursa olsun üstüne geçer.
-- ════════════════════════════════════════════════════════════════════════
update users set role = 'host'::user_role
 where email in ('host1@seed.loungelink.test','host2@seed.loungelink.test');
update users set role = 'guest'::user_role
 where email in ('guest1@seed.loungelink.test','guest2@seed.loungelink.test');
update users set plan = 'sik_ucan'::plan_type where email = 'host1@seed.loungelink.test';
update users set plan = 'yolcu'::plan_type
 where email in ('host2@seed.loungelink.test','guest1@seed.loungelink.test',
                 'guest2@seed.loungelink.test');

-- 🔴 `gender` PROFILES'TA DEĞİL USERS'TA. İlk yazımda profiles'a koydum
-- ve kurulum "column gender of relation profiles does not exist" dedi.
-- Şema: 001_initial_schema.sql:26 → users.gender user_gender.
-- Kadın host filtresi (`womenOnly`) bu kolonu okuyor.
update users u set gender = (case
    when u.email in ('host1@seed.loungelink.test','guest1@seed.loungelink.test')
    then 'female' else 'male' end)::user_gender
 where u.email in ('host1@seed.loungelink.test','host2@seed.loungelink.test',
                   'guest1@seed.loungelink.test','guest2@seed.loungelink.test')
   and u.gender is null;

insert into profiles (user_id, name, profession, bio, guest_capacity, show_on_discovery)
select u.id,
       case u.email
         when 'host1@seed.loungelink.test'  then 'Deniz A.'
         when 'host2@seed.loungelink.test'  then 'Kerem B.'
         when 'guest1@seed.loungelink.test' then 'Selin Y.'
         else 'Mert K.' end,
       case u.email
         when 'host1@seed.loungelink.test'  then 'Ürün Yönetimi'
         when 'host2@seed.loungelink.test'  then 'Mimarlık'
         when 'guest1@seed.loungelink.test' then 'Yatırım Bankacılığı'
         else 'Yazılım' end,
       case u.email
         when 'host1@seed.loungelink.test'  then 'Ayda 3-4 kez uçuyorum, sohbet etmeyi severim.'
         when 'host2@seed.loungelink.test'  then 'Kısa aktarmalarda kahve içmeye vaktim olur.'
         when 'guest1@seed.loungelink.test' then 'Uzun aktarmalarda iyi bir sohbet aranıyor.'
         else 'İlk kez deniyorum.' end,
       2, true
  from users u
 where u.email in ('host1@seed.loungelink.test','host2@seed.loungelink.test',
                   'guest1@seed.loungelink.test','guest2@seed.loungelink.test')
   and not exists (select 1 from profiles p where p.user_id = u.id);

-- 🔴 TELEFON DOĞRULAMASI ŞART. `create_request` ve `ilan_kurali_sor`
-- doğrulanmamış telefonda kapıyı kapatıyor; doğrulamadan bırakırsam
-- Gökberk hiçbir akışı deneyemez ve sebebini de göremez.
insert into verifications (user_id, email_verified, email_verified_at, phone_verified, phone_verified_at)
select u.id, true, now(), true, now()
  from users u
 where u.email in ('host1@seed.loungelink.test','host2@seed.loungelink.test',
                   'guest1@seed.loungelink.test','guest2@seed.loungelink.test')
on conflict (user_id) do update set
  email_verified = true, phone_verified = true,
  phone_verified_at = coalesce(verifications.phone_verified_at, now());


-- ════════════════════════════════════════════════════════════════════════
-- 1) KARTLAR — her biri BAŞKA bir kural dalını açıyor
-- ════════════════════════════════════════════════════════════════════════
do $$
declare r record; v_pid uuid;
begin
  for r in
    select * from (values
      -- host1: iki kart → "hangi kartımı kullanayım" (216) anlamlı olsun
      ('host1@seed.loungelink.test','TK_MS','ELPL','Miles&Smiles Elite Plus'),
      ('host1@seed.loungelink.test','PRIORITY_PASS','PP_PRESTIGE','Priority Pass Prestige'),
      -- host2: tek kart, kısıtlı → kapalı kapı senaryosu
      ('host2@seed.loungelink.test','DRAGONPASS','DP_CLASSIC','DragonPass Classic'),
      -- guest1 de host olabilsin (çift rol ürünün özü)
      ('guest1@seed.loungelink.test','TK_MS','ELITE','Miles&Smiles Elite')
    ) as t(mail, kod, kademe, etiket)
  loop
    select id into v_pid from lounge_programs where code = r.kod;
    continue when v_pid is null;
    insert into host_entitlements (user_id, program_id, tier, card_label, verified, self_reported_at)
    select u.id, v_pid, r.kademe, r.etiket, true, now()
      from users u where u.email = r.mail
       and not exists (select 1 from host_entitlements e
                        where e.user_id = u.id and e.program_id = v_pid
                          and coalesce(e.tier,'') = coalesce(r.kademe,''));
  end loop;
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- 2) İLANLAR
--
-- 🔴 SALON SEÇİMİ TESADÜFE BIRAKILMIYOR. Birinci seed'in en pahalı dersi:
-- `order by length(name)` tek başına belirsiz, `venue_id is null` olan
-- salonlar kural motorunu devre dışı bırakıyor. Aynı sıralama kalıbı
-- burada da kullanılıyor (kopyalıyorum çünkü ORTAK BİR FONKSİYONA
-- çıkarmak seed'lerin kurulum sırasını değiştirirdi — borç olarak not
-- düşüyorum, sessizce farklı yazmıyorum).
-- ════════════════════════════════════════════════════════════════════════
insert into availabilities
  (host_id, lounge_id, airport_code, avail_date, time_from, time_to, slots, filled,
   flight_number, carrier, visibility, is_charter, carrier_code)
select u.id,
       (select l.id from lounges l
         where l.airport_code = x.ap and l.active and l.venue_id is not null
           and lower(l.name) like '%' || lower(x.lounge) || '%'
         order by (select count(*) from lounge_venue_acceptance a2
                     join host_entitlements he2
                       on he2.program_id = a2.program_id and he2.user_id = u.id
                    where a2.venue_id = l.venue_id and a2.active and a2.accepted
                      and coalesce(a2.guest_policy,'') <> 'not_allowed') desc,
                  length(l.name), l.id limit 1),
       x.ap::char(3), current_date + x.gun, x.t1::time, x.t2::time, x.slots, x.dolu,
       x.fl, x.cr, 'Public'::availability_visibility, x.charter, x.cr
  from (values
   -- host1 · A) ücretsiz misafirli — mutlu yol
   ('host1@seed.loungelink.test','IST','turkish airlines lounge — dış hat', 2,'12:00','18:00',2,0,'TK712','TK',false),
   -- host1 · B) ücretli misafirli (Priority Pass salonu) → 1 kredi teşekkür akışı
   ('host1@seed.loungelink.test','IST','iga lounge — dış hat',              2,'10:00','16:00',2,0,'TK1980','TK',false),
   -- host1 · C) SLOTLARI DOLU → "dolu" durumu ekranda görünsün
   ('host1@seed.loungelink.test','ESB','primeclass lounge — dış hat',       3,'09:00','12:00',1,1,'TK2104','TK',false),
   -- host2 · D) misafir hakkı görünmüyor + doğrulanmadı → HOST'A SOR butonu
   ('host2@seed.loungelink.test','ADB','primeclass lounge — dış hat',       2,'11:00','15:00',1,0,'PC2034','PC',false),
   -- host2 · E) charter → charter kapısı
   ('host2@seed.loungelink.test','IST','turkish airlines lounge — dış hat', 2,'08:00','11:00',1,0,'TK9001','TK',true)
  ) as x(mail, ap, lounge, gun, t1, t2, slots, dolu, fl, cr, charter)
  join users u on u.email = x.mail
 where not exists (
   select 1 from availabilities a
    where a.host_id = u.id and a.airport_code = x.ap::char(3)
      and a.avail_date = current_date + x.gun and a.time_from = x.t1::time);


-- ---- 2b) ÜCRETLİ MİSAFİR İLANI — SALON ADIYLA DEĞİL, KARARLA SEÇİLİYOR
--
-- 🔴 İLK YAZIMDA SALON ADI YAZDIM VE ÖLÇÜM BENİ YALANLADI.
-- "iGA Lounge — Dış Hat, Priority Pass'li host → misafir ücretli" diye
-- kurdum; karar motoru `not_allowed` dedi. Sebebi kovaladım:
--     resolve_guest_rule(PP, iGA, 'PP_PRESTIGE') → allowance=0, paid=true
--     resolve_guest_rule(PP, iGA,  null)         → allowance=0, paid=true
-- yani KURAL aynı, ama kademesi yazılı host'ta karar `not_allowed`,
-- kademesi boş host'ta (kural5) `paid` çıkıyor. Bu bir SEED sorunu değil,
-- motorda ayrı bakılması gereken bir davranış — teslim notuna açık
-- madde olarak yazdım, burada sessizce üstünü örtmüyorum.
--
-- Seed'in işi kuralı zorlamak değil, ürünü gezilebilir kılmak. O yüzden
-- salonu ADIYLA değil ÖZELLİĞİYLE seçiyorum: adayları tek tek deneyip
-- karar motoru gerçekten "paid" diyen ilki bırakıyorum. Bu, bu projenin
-- en pahalı ders sınıfının (nöbetçiyi kendi verine göre ayarlamak)
-- tersi: nöbetçi değil, VERİ karara uyduruluyor.
do $$
declare
  r record; v_h uuid; v_id uuid; d jsonb; v_mail text; v_bulundu boolean;
begin
  foreach v_mail in array array['host1@seed.loungelink.test','host2@seed.loungelink.test']
  loop
    select id into v_h from users where email = v_mail;
    continue when v_h is null;

    -- Bu host'un zaten ücretli bir ilanı varsa tekrar aramıyoruz.
    if exists (select 1 from availabilities a where a.host_id = v_h and a.active
                 and (public.lounge_access_decision(a.id, null) ->> 'guest_policy') = 'paid') then
      continue;
    end if;

    v_bulundu := false;
    for r in
      select l.id lid, l.airport_code ap
        from lounges l
        join host_entitlements he on he.user_id = v_h
        join lounge_venue_acceptance ac
          on ac.venue_id = l.venue_id and ac.program_id = he.program_id
         and ac.active and ac.accepted and ac.guest_policy = 'paid'
       where l.active and l.venue_id is not null
       order by l.airport_code, l.id
       limit 60
    loop
      insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                  time_from, time_to, slots, filled, visibility)
      values (v_h, r.lid, r.ap, current_date + 4, '13:00', '17:00', 2, 0, 'Public')
      returning id into v_id;

      d := public.lounge_access_decision(v_id, null);
      if (d ->> 'guest_policy') = 'paid' then
        v_bulundu := true;
        raise notice 'SEED3: % icin UCRETLI misafir ilani kuruldu → %', v_mail, r.ap;
        -- Misafirin eşleşebilmesi için seyahat de açıyoruz.
        insert into visits (user_id, airport_code, visit_date, time_from, time_to, purpose)
        select u.id, r.ap, current_date + 4, '12:30'::time, '17:30'::time, 'leisure'
          from users u where u.email = 'guest2@seed.loungelink.test'
           and not exists (select 1 from visits v where v.user_id = u.id
                            and v.airport_code = r.ap and v.visit_date = current_date + 4);
        exit;
      end if;
      delete from availabilities where id = v_id;
    end loop;

    if not v_bulundu then
      raise warning 'SEED3: % icin UCRETLI misafir cikaran salon bulunamadi (60 aday denendi)', v_mail;
    end if;
  end loop;
end $$;


-- ---- 2c) "HOST'A SOR" İLANI — yine ÖZELLİKLE seçiliyor
--
-- 🔴 222 BU SENARYOYU KAZAYLA YUTTU VE ÖLÇÜM GÖSTERDİ.
-- 222'den önce host2'nin ADB ilanı `not_allowed` + doğrulanmamış idi,
-- yani "Host'a sor" butonu çıkıyordu. 222 ücretli dalı onarınca aynı ilan
-- `paid` oldu (doğrusu bu) ve seed'in kapsam ölçümü şunu yazdı:
--     ucretsiz=2 ucretli=2 kapali=1 hostasorulabilir=0
-- Yani bir düzeltme, bir test senaryosunu sessizce yok etti. Kapsam
-- ölçümü olmasaydı bunu Gökberk cihazda "buton yok" diye bulacaktı.
--
-- Bu yüzden burada da salonu ADIYLA değil ÖZELLİĞİYLE seçiyorum:
-- `kural_sorusu_uygun_mu()` gerçekten true diyen ilk salonu bırakıyorum.
do $$
declare
  r record; v_h uuid; v_id uuid; v_bulundu boolean := false;
begin
  select id into v_h from users where email = 'host2@seed.loungelink.test';
  if v_h is null then return; end if;

  if exists (select 1 from availabilities a
              where a.host_id = v_h and a.active and public.kural_sorusu_uygun_mu(a.id)) then
    raise notice 'SEED3: host2 icin HOST''A SOR ilani zaten var';
    return;
  end if;

  for r in
    select l.id lid, l.airport_code ap
      from lounges l
      join host_entitlements he on he.user_id = v_h
      join lounge_venue_acceptance ac
        on ac.venue_id = l.venue_id and ac.program_id = he.program_id and ac.active
     where l.active and l.venue_id is not null
       and coalesce(ac.guest_policy,'') <> 'paid'      -- 222 onarimi devreye girmesin
     order by l.airport_code, l.id
     limit 80
  loop
    insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                time_from, time_to, slots, filled, visibility)
    values (v_h, r.lid, r.ap, current_date + 5, '09:00', '13:00', 1, 0, 'Public')
    returning id into v_id;

    if public.kural_sorusu_uygun_mu(v_id) then
      v_bulundu := true;
      raise notice 'SEED3: HOST''A SOR ilani kuruldu → %', r.ap;
      insert into visits (user_id, airport_code, visit_date, time_from, time_to, purpose)
      select u.id, r.ap, current_date + 5, '08:30'::time, '13:30'::time, 'leisure'
        from users u where u.email = 'guest2@seed.loungelink.test'
         and not exists (select 1 from visits v where v.user_id = u.id
                          and v.airport_code = r.ap and v.visit_date = current_date + 5);
      exit;
    end if;
    delete from availabilities where id = v_id;
  end loop;

  if not v_bulundu then
    raise warning 'SEED3: HOST''A SOR senaryosu kurulamadi (80 aday denendi)';
  end if;
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- 3) SEYAHATLER — misafirler ilanlarla GERÇEKTEN eşleşsin
--
-- 🔴 `create_request` "no_matching_trip" ile reddediyor: aynı havalimanı,
-- aynı gün ve ÇAKIŞAN saat aralığı şart. Seyahat saatlerini ilanların
-- içine alacak şekilde yazıyorum; birini kaydırırsam Gökberk "buton
-- çalışmıyor" görür ve sebebi ekranda yazmaz.
-- ════════════════════════════════════════════════════════════════════════
insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number, carrier_code, purpose)
select u.id, x.ap::char(3), current_date + x.gun, x.t1::time, x.t2::time, x.fl, x.cr, x.amac
  from (values
   -- guest1 → host1'in A ve B ilanlarıyla çakışıyor
   ('guest1@seed.loungelink.test','IST', 2,'11:30','18:30','TK712','TK','business'),
   ('guest1@seed.loungelink.test','ESB', 3,'08:30','12:30','TK2104','TK','conference'),
   -- guest2 → host2'nin kapalı ilanıyla (ADB) ve host1'in ücretli ilanıyla (IST)
   ('guest2@seed.loungelink.test','ADB', 2,'10:30','15:30','PC2034','PC','leisure'),
   ('guest2@seed.loungelink.test','IST', 2,'09:30','16:30','TK1980','TK','connecting'),
   -- host'ların da seyahati olsun: çift rol denenebilsin
   ('host1@seed.loungelink.test','IST',  2,'11:00','19:00','TK712','TK','business'),
   ('host2@seed.loungelink.test','ADB',  2,'10:00','16:00','PC2034','PC','leisure')
  ) as x(mail, ap, gun, t1, t2, fl, cr, amac)
  join users u on u.email = x.mail
 where not exists (
   select 1 from visits v
    where v.user_id = u.id and v.airport_code = x.ap::char(3)
      and v.visit_date = current_date + x.gun and v.time_from = x.t1::time);


-- ════════════════════════════════════════════════════════════════════════
-- 4) KREDİ
--
-- 219 ile teşekkür kredisi 1'e indi; toplam maliyet 2 kredi (1 emanet +
-- 1 teşekkür). guest1'e 6, guest2'ye 3 veriyorum: ikisi de birkaç istek
-- gönderebilsin ama "kredin bitti" ekranı da denenebilsin.
-- ════════════════════════════════════════════════════════════════════════
insert into credit_ledger (user_id, delta, reason, balance_after)
select u.id, x.n, 'seed3_baslangic', x.n
  from (values
   ('guest1@seed.loungelink.test', 6),
   ('guest2@seed.loungelink.test', 3),
   ('host1@seed.loungelink.test',  4),
   ('host2@seed.loungelink.test',  2)
  ) as x(mail, n)
  join users u on u.email = x.mail
 where not exists (select 1 from credit_ledger c
                    where c.user_id = u.id and c.reason = 'seed3_baslangic');


-- ════════════════════════════════════════════════════════════════════════
-- 5) AKIŞ DURUMLARI — her ekranda dolu veri
--
-- İstekleri RPC ile değil doğrudan tabloya yazıyorum: RPC'ler auth.uid()
-- istiyor ve seed'in oturumu yok. Karşılığında slot sayaçlarını ELLE
-- tutmam gerekiyor — aşağıdaki `filled` güncellemesi bu yüzden var.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_h1 uuid; v_h2 uuid; v_g1 uuid; v_g2 uuid;
  v_ilanA uuid; v_ilanB uuid;
  v_req_bekleyen uuid; v_req_kabul uuid; v_req_ret uuid; v_req_tamam uuid;
  v_sess_aktif uuid; v_sess_tamam uuid;
begin
  select id into v_h1 from users where email = 'host1@seed.loungelink.test';
  select id into v_h2 from users where email = 'host2@seed.loungelink.test';
  select id into v_g1 from users where email = 'guest1@seed.loungelink.test';
  select id into v_g2 from users where email = 'guest2@seed.loungelink.test';
  if v_h1 is null or v_g1 is null then
    raise notice 'SEED3: hesaplar kurulamadi — atlaniyor'; return;
  end if;

  select id into v_ilanA from availabilities
   where host_id = v_h1 and airport_code = 'IST' and avail_date = current_date + 2
     and time_from = '12:00'::time limit 1;
  select id into v_ilanB from availabilities
   where host_id = v_h1 and airport_code = 'IST' and avail_date = current_date + 2
     and time_from = '10:00'::time limit 1;
  if v_ilanA is null then
    raise notice 'SEED3: host1 ilanlari kurulamadi (salon bulunamadi) — akislar atlaniyor'; return;
  end if;

  -- (a) BEKLEYEN istek: guest2 → host1 ücretli ilan
  if v_ilanB is not null and not exists (
       select 1 from requests where guest_id = v_g2 and avail_id = v_ilanB) then
    insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score)
    values (v_g2, v_h1, v_ilanB, 'pending', 'standard'::request_type, 'lounge',
            'Merhaba, aynı gün IST''teyim. Aktarmam uzun, sohbet iyi olur.', 78)
    returning id into v_req_bekleyen;
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_h1, 'requests', 'Yeni misafir isteği ◈',
            'Mert K. ilanına istek gönderdi.', 'request', v_req_bekleyen);
  end if;

  -- (b) KABUL EDİLMİŞ istek + AKTİF oturum: guest1 → host1 ücretsiz ilan
  if not exists (select 1 from requests where guest_id = v_g1 and avail_id = v_ilanA) then
    insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score)
    values (v_g1, v_h1, v_ilanA, 'accepted', 'standard'::request_type, 'lounge',
            'Aynı uçuştayız galiba — TK712.', 92)
    returning id into v_req_kabul;

    insert into sessions (request_id, status, host_confirmed, guest_confirmed, started_at)
    values (v_req_kabul, 'active', false, false, now() - interval '20 minutes')
    returning id into v_sess_aktif;

    -- 🔴 SLOT SAYACI ELLE. RPC atlandığı için `filled` kendiliğinden
    -- artmıyor; artırmazsam ilan "2 slot açık" der ama biri doludur ve
    -- ekranla veri ayrışır.
    update availabilities set filled = least(slots, coalesce(filled,0) + 1) where id = v_ilanA;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_g1, 'requests', 'İsteğin kabul edildi ✓',
            'Deniz A. isteğini kabul etti. Sohbet açıldı.', 'request', v_req_kabul);
  end if;

  -- (c) TAMAMLANMIŞ + PUANLANMIŞ oturum: guest1 ↔ host1 (geçmiş)
  -- Aynı çakışma riski burada da vardı (bu blokta da `r record` yok ama
  -- ileride eklenirse sessizce bozulurdu) — takma ad baştan `rq`.
  if not exists (select 1 from requests rq join sessions s on s.request_id = rq.id
                  where rq.guest_id = v_g1 and rq.host_id = v_h1 and s.status = 'completed') then
    insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score, created_at)
    values (v_g1, v_h1, v_ilanA, 'completed', 'standard'::request_type, 'lounge',
            'Geçen ayki buluşma.', 88, now() - interval '30 days')
    returning id into v_req_tamam;

    insert into sessions (request_id, status, host_confirmed, guest_confirmed, started_at, completed_at)
    values (v_req_tamam, 'completed', true, true,
            now() - interval '30 days', now() - interval '30 days' + interval '2 hours')
    returning id into v_sess_tamam;

    -- Çift puanlama: karşılıklı puan ekranı dolu görünsün
    insert into ratings (session_id, rater_id, rated_id, score, comment)
    values (v_sess_tamam, v_g1, v_h1, 5, 'Çok kibar, kapıda hiç sorun çıkmadı.'),
           (v_sess_tamam, v_h1, v_g1, 5, 'Keyifli sohbet, teşekkürler.')
    on conflict do nothing;

    insert into points_ledger (user_id, delta, reason, ref_id)
    values (v_h1, 500, 'session_reward', v_sess_tamam),
           (v_g1, 200, 'session_reward', v_sess_tamam)
    on conflict do nothing;
  end if;

  -- (d) REDDEDİLMİŞ istek: guest2 → host2'nin charter ilanı (geçmiş)
  if not exists (select 1 from requests where guest_id = v_g2 and host_id = v_h2) then
    insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score, created_at)
    select v_g2, v_h2, a.id, 'declined', 'standard'::request_type, 'lounge',
           'Merhaba, uygun musunuz?', 41, now() - interval '5 days'
      from availabilities a where a.host_id = v_h2 and a.is_charter limit 1;
  end if;

  -- (e) BAĞLANTI + SOHBET: guest1 ↔ host1 kabul edilmiş bağlantı
  if not exists (select 1 from connection_requests
                  where (from_id = v_g1 and to_id = v_h1) or (from_id = v_h1 and to_id = v_g1)) then
    insert into connection_requests (from_id, to_id, intent, intro, status)
    values (v_g1, v_h1, 'connect', 'Geçen ay tanışmıştık, bağlantı kuralım.', 'accepted');
  end if;

  raise notice 'SEED3: akis durumlari kuruldu';
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- 6) DOĞRULAMA — seed "kuruldu" demek yetmez, AKIŞLAR GÖRÜLÜYOR MU
--
-- 🔴 BU BÖLÜM OLMASAYDI SEED SESSİZCE YARIM KALIRDI.
-- Bu turda bir kez tam olarak bu tuzağa düştüm: hiçbir şey ölçmeyen bir
-- test yeşil yandı. Aşağısı satır SAYAR ve sıfırsa BAĞIRIR.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_h1 uuid; v_h2 uuid; v_g1 uuid; v_g2 uuid;
  n_ilan int; n_seyahat int; n_istek int; n_oturum int;
  n_kapali int; n_sorulabilir int; n_ucretli int; n_ucretsiz int;
  v_eksik text := '';
  r record; d jsonb;
begin
  select id into v_h1 from users where email = 'host1@seed.loungelink.test';
  select id into v_h2 from users where email = 'host2@seed.loungelink.test';
  select id into v_g1 from users where email = 'guest1@seed.loungelink.test';
  select id into v_g2 from users where email = 'guest2@seed.loungelink.test';

  if v_h1 is null or v_h2 is null or v_g1 is null or v_g2 is null then
    raise exception 'SEED3: dort hesabin hepsi kurulamadi';
  end if;

  select count(*) into n_ilan from availabilities where host_id in (v_h1, v_h2) and active;
  select count(*) into n_seyahat from visits where user_id in (v_g1, v_g2);
  select count(*) into n_istek from requests where guest_id in (v_g1, v_g2);
  -- 🔴 TAKMA AD `r` DEĞİL `rq`. İlk yazımda `join requests r` yazdım ve
  -- kurulum şunu dedi:
  --     ERROR: record "r" is not assigned yet
  -- Sebep: bu bloğun DEĞİŞKEN listesinde de `r record` var. PL/pgSQL
  -- `r.guest_id`'yi tablo takma adı değil DEĞİŞKEN sanıyor ve değişken
  -- henüz atanmadığı için patlıyor. SQL'i doğru yazmak yetmiyor —
  -- gövdedeki adlarla çakışmamak da gerekiyor.
  select count(*) into n_oturum from sessions s join requests rq on rq.id = s.request_id
   where rq.guest_id in (v_g1, v_g2);

  if n_ilan   < 4 then v_eksik := v_eksik || format('ilan=%s(<4) ', n_ilan); end if;
  if n_seyahat< 4 then v_eksik := v_eksik || format('seyahat=%s(<4) ', n_seyahat); end if;
  if n_istek  < 3 then v_eksik := v_eksik || format('istek=%s(<3) ', n_istek); end if;
  if n_oturum < 2 then v_eksik := v_eksik || format('oturum=%s(<2) ', n_oturum); end if;

  -- Kural dallarının HEPSİ temsil ediliyor mu — karar motoruna sorarak
  n_kapali := 0; n_sorulabilir := 0; n_ucretli := 0; n_ucretsiz := 0;
  for r in select id from availabilities where host_id in (v_h1, v_h2) and active loop
    d := public.lounge_access_decision(r.id, null);
    if (d ->> 'guest_policy') = 'not_allowed' then n_kapali := n_kapali + 1; end if;
    if (d ->> 'guest_policy') = 'paid'        then n_ucretli := n_ucretli + 1; end if;
    if (d ->> 'guest_policy') = 'included'    then n_ucretsiz := n_ucretsiz + 1; end if;
    if public.kural_sorusu_uygun_mu(r.id)     then n_sorulabilir := n_sorulabilir + 1; end if;
  end loop;

  raise notice 'SEED3 KAPSAM: ilan=% seyahat=% istek=% oturum=% | kural: ucretsiz=% ucretli=% kapali=% hostasorulabilir=%',
    n_ilan, n_seyahat, n_istek, n_oturum, n_ucretsiz, n_ucretli, n_kapali, n_sorulabilir;

  if v_eksik <> '' then
    raise exception 'SEED3: kapsam EKSIK → %', v_eksik;
  end if;
  v_eksik := '';   -- ikinci tur kontrol icin temizle

  -- 🔴 DÖRT DALIN DÖRDÜ DE TEMSİL EDİLMELİ — VE BU BİR HATA, UYARI DEĞİL.
  -- İlk yazımda uyarı bırakmıştım. Sonra 222 (ücretli dal onarımı) geldi
  -- ve "host'a sor" senaryosunu SESSİZCE yuttu: kapsam
  --     ucretsiz=2 ucretli=2 kapali=1 hostasorulabilir=0
  -- oldu ve kurulum yine yeşil yandı. Yani seed, test edilemez hâle
  -- geldiğini kendi söyleyemedi. Uyarı, okunmayan bir dipnottur.
  --
  -- Artık dal düşerse kurulum DURUR. Katalog değişip bir dal gerçekten
  -- imkânsız hâle gelirse burası kırmızı yanar ve seed'i güncelleriz —
  -- sessizce eksik bir seed dağıtmaktan iyidir.
  if n_ucretsiz     = 0 then v_eksik := v_eksik || 'UCRETSIZ-dal-yok '; end if;
  if n_ucretli      = 0 then v_eksik := v_eksik || 'UCRETLI-dal-yok '; end if;
  if n_kapali       = 0 then v_eksik := v_eksik || 'KAPALI-dal-yok '; end if;
  if n_sorulabilir  = 0 then v_eksik := v_eksik || 'HOSTA-SOR-dal-yok '; end if;
  if v_eksik <> '' then
    raise exception 'SEED3: kural dallari EKSIK → % (ilan=%)', v_eksik, n_ilan;
  end if;
end $$;

-- ════════════════════════════════════════════════════════════════════════
-- 🔴 NÖBETÇİ · "BU HESAPLA GİRİŞ YAPILABİLİR Mİ"
--
-- 20 Ağustos'ta Gökberk dört hesabın hiçbirine giremedi: "e-posta veya
-- şifre hatalı". Seed "OK" diyordu çünkü ilan/seyahat/oturum sayıyordu —
-- GİRİŞİN KENDİSİNİ hiç ölçmüyordu. Bir test hesabı üretip giriş
-- yapılabildiğini doğrulamamak, hesabı hiç üretmemekle aynı sonucu verir.
--
-- Üç şey ayrı ayrı ölçülür; biri bile tutmazsa SEED DURUR:
--   (a) hash gerçekten 'Seed1234!' ile doğrulanıyor mu (bcrypt round-trip)
--       — `encrypted_password` DOLU olmak şifrenin DOĞRU olduğunu göstermez
--   (b) aud/role dolu mu (GoTrue bunlarsız kullanıcıyı reddeder)
--   (c) auth.identities'te provider='email' satırı var mı (asıl eksik olan)
-- ════════════════════════════════════════════════════════════════════════
do $giris$
declare
  v_kripto text; v_kotu text := ''; r record; v_ok boolean; v_n int := 0;
begin
  v_kripto := case when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                                 where p.proname='crypt' and n.nspname='extensions')
                   then 'extensions.crypt' else 'crypt' end;
  for r in select id, email, encrypted_password, aud, role from auth.users
            where email in ('host1@seed.loungelink.test','host2@seed.loungelink.test',
                            'guest1@seed.loungelink.test','guest2@seed.loungelink.test')
            order by email
  loop
    v_n := v_n + 1;
    execute format('select ($1 = %s($2, $1))', v_kripto)
      into v_ok using r.encrypted_password, 'Seed1234!';
    if not coalesce(v_ok, false) then
      v_kotu := v_kotu || r.email || '(sifre-dogrulanmadi) '; continue;
    end if;
    if coalesce(r.aud,'') <> 'authenticated' or coalesce(r.role,'') <> 'authenticated' then
      v_kotu := v_kotu || r.email || '(aud/role-eksik) '; continue;
    end if;
    if exists (select 1 from information_schema.tables
                where table_schema='auth' and table_name='identities')
       and not exists (select 1 from auth.identities i
                        where i.user_id = r.id and i.provider='email') then
      v_kotu := v_kotu || r.email || '(kimlik-satiri-yok) ';
    end if;
  end loop;

  if v_n <> 4 then
    raise exception 'SEED3: 4 hesap bekleniyordu, % bulundu — olcum gecersiz', v_n;
  end if;
  if v_kotu <> '' then
    raise exception 'SEED3: SU HESAPLARLA GIRIS YAPILAMAZ -> % (cozum: 227_seed_giris_onarimi.sql)', v_kotu;
  end if;
  raise notice 'SEED3: 4 hesabin dordu de giris icin hazir (sifre + GoTrue alanlari + kimlik satiri)';
end $giris$;

-- ════════════════════════════════════════════════════════════════════════
-- 🔴 NÖBETÇİ · "MİSAFİR EKRANINDA GERÇEKTEN İLAN VAR MI"
--
-- 20 Ağustos: "app'i kontrol ettiğimde hiç ilan göremiyorum."
-- Seed "KAPSAM: ilan=7 seyahat=5 istek=4" diyordu ve DOĞRUYDU — ilanlar
-- tabloda vardı. Ama KEŞİFTE görünmüyorlardı, çünkü host1/host2 rolü
-- 'guest' kalmıştı. Yani seed VERİYİ sayıyordu, GÖRÜNÜRLÜĞÜ değil.
--
-- Ders: bir seed'in işi satır üretmek değil, EKRANI DOLDURMAKTIR.
-- Bu nöbetçi misafirin gözünden bakar — `discover_availabilities`'i
-- gerçekten çağırır ve şunları arar:
--   · toplam kaç ilan görüyor
--   · bunların kaçı host1/host2'nin (yani bu seed'in kurduğu senaryolar)
--   · en az birine BAŞVURABİLİYOR mu (dolu değil + rozet engellemiyor)
--   · en az iki FARKLI rozet görüyor mu (kural çeşitliliği)
-- ════════════════════════════════════════════════════════════════════════
do $kesif$
declare
  r record; v_uid uuid; v_toplam int; v_seed int; v_basvurulabilir int; v_rozet int;
  v_kotu text := '';
begin
  for r in select id, email from users
            where email in ('guest1@seed.loungelink.test','guest2@seed.loungelink.test')
            order by email
  loop
    perform set_config('request.jwt.claims',
                       json_build_object('sub', r.id::text)::text, true);

    select count(*) into v_toplam from public.discover_availabilities();

    select count(*) into v_seed
      from public.discover_availabilities() d
      join availabilities a on a.id = d.id
      join users hu on hu.id = a.host_id
     where hu.email in ('host1@seed.loungelink.test','host2@seed.loungelink.test');

    select count(*) into v_basvurulabilir
      from public.discover_availabilities() d
      left join lateral public.discovery_rule_badges(array[d.id]) b on true
     where d.fully_booked = false
       and coalesce(b.blocks_request, false) = false;

    select count(distinct b.severity) into v_rozet
      from public.discover_availabilities() d
      join lateral public.discovery_rule_badges(array[d.id]) b on true;

    if v_toplam < 3 then
      v_kotu := v_kotu || r.email || '(kesifte ' || v_toplam || ' ilan) ';
    elsif v_seed < 2 then
      v_kotu := v_kotu || r.email || '(host1/host2 ilani ' || v_seed || ') ';
    elsif v_basvurulabilir < 1 then
      v_kotu := v_kotu || r.email || '(basvurabilecegi ilan YOK) ';
    else
      raise notice 'SEED3 KESIF · %: toplam=% · host1/host2=% · basvurulabilir=% · farkli rozet=%',
        r.email, v_toplam, v_seed, v_basvurulabilir, v_rozet;
    end if;
  end loop;

  perform set_config('request.jwt.claims', '', true);

  if v_kotu <> '' then
    raise exception 'SEED3: MISAFIR EKRANI BOS/YETERSIZ -> %  '
                    '(ilan tabloda olabilir ama kesifte gorunmuyor; '
                    'en sik sebep: host rolu ''guest'' kalmis)', v_kotu;
  end if;
end $kesif$;

select 'SEED3 OK — host1/host2/guest1/guest2 · sifre Seed1234! · giris dogrulandi' as sonuc;
