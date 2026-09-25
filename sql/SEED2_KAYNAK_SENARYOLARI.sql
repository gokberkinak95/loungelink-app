-- ============================================================
-- LoungeLink · SEED2_KAYNAK_SENARYOLARI.sql
-- "AYNI SALON, FARKLI KAYNAK, FARKLI CEVAP" — GÖZLE GÖRÜLSÜN
--
-- ⚠️ BU BİR MIGRATION DEĞİL, TEST VERİSİDİR. En sonda çalıştır.
-- `SEED_KURAL_SENARYOLARI.sql`i BOZMAZ, ONA DOKUNMAZ: kendi
-- kullanıcılarını yaratır (kaynak1..kaynak6). İkisi birlikte de,
-- ayrı ayrı da çalışır.
--
-- ============================================================
-- NEDEN İKİNCİ BİR SEED GEREKTİ
-- ============================================================
-- Birinci seed 18 senaryoyla kural motorunun dokuz dalını kapsıyor ve
-- hâlâ geçerli. Ama ÖLÇTÜM ve şunu gördüm — bu turda eklenen ürün
-- ekseni orada HİÇ YOK:
--
--   select p.code, count(distinct e.user_id)
--     from host_entitlements e ... where u.email like '%seed%'
--   → PRIORITY_PASS 1 · LOUNGEKEY 1 · DRAGONPASS 1  (kademe: HEPSİ BOŞ)
--
--   select u.email, count(*) from host_entitlements ... having count(*)>1
--   → 0 satır
--
-- İki eksik, ikisi de bu turun kalbi:
--
--   1) HİÇBİR HOST'UN BİRDEN FAZLA KARTI YOK.
--      Oysa `hangi_kartimi_kullanayim` (216) tam olarak "cebinde birkaç
--      kart var, hangisini kullanmalısın" sorusu için yazıldı. Sıfır
--      senaryoyla test edilen bir özellik, test edilmemiş özelliktir.
--
--   2) KART AĞI KADEMELERİ BOŞ (`host_entitlements.tier` = null).
--      Priority Pass'in cevabı Standard'da da Prestige'de de aynı
--      (misafir 30 EUR) — ama bunu GÖSTEREBİLMEK için kademe lazım.
--      Ürünün en güçlü cümlesi buradan çıkıyor: "459 EUR ödeyen bile
--      misafirini ücretsiz alamıyor."
--
-- Bir de üçüncüsü var ve en pahalısı o:
--
--   3) DRAGONPASS'İN "AYNI UÇUŞ" ŞARTI SAHNEDE YOK.
--      DragonPass 7.15.7 misafirin üyeyle AYNI UÇUŞTA olmasını şart
--      koşuyor. LoungeLink'te host ve misafir ÇOĞU ZAMAN farklı
--      uçuşta — yani bu şart, eşleşmeyi tam kapıda bozan türden.
--      Motorda kodlu, seed'de görünmüyordu.
--
-- Hesaplar: kaynak1..kaynak6@seed.loungelink.test · şifre Seed1234!
-- Misafir : kmisafir9@seed.loungelink.test
-- ============================================================


-- ---- 0) auth kullanicilari ----
insert into auth.users (id, email)
select x.id::uuid, x.email
  from (values
    ('22220001-0000-4000-8000-000000000001','kaynak1@seed.loungelink.test'),
    ('22220002-0000-4000-8000-000000000002','kaynak2@seed.loungelink.test'),
    ('22220003-0000-4000-8000-000000000003','kaynak3@seed.loungelink.test'),
    ('22220004-0000-4000-8000-000000000004','kaynak4@seed.loungelink.test'),
    ('22220005-0000-4000-8000-000000000005','kaynak5@seed.loungelink.test'),
    ('22220006-0000-4000-8000-000000000006','kaynak6@seed.loungelink.test'),
    ('22220009-0000-4000-8000-000000000009','kmisafir9@seed.loungelink.test')
  ) as x(id, email)
 where not exists (select 1 from auth.users a where a.email = x.email);

-- ⚠️ ŞİFRE BİRİNCİ SEED'İN YOLUYLA. Kendi hash'imi yazmıyorum:
-- iki seed iki farklı şifre kurgusu taşırsa hangisinin geçerli olduğu
-- belirsizleşir ve canlı testte "şifre çalışmıyor" diye saat kaybedilir.
update auth.users u
   set encrypted_password = (select encrypted_password from auth.users
                              where email = 'kural1@seed.loungelink.test'),
       email_confirmed_at = coalesce(u.email_confirmed_at, now())
 where u.email like 'k%9@seed.loungelink.test' or u.email like 'kaynak%@seed.loungelink.test';
-- Birinci seed hiç çalışmadıysa yukarıdaki alt sorgu null döner; o hâlde
-- şifreyi burada kuruyoruz (pgcrypto `extensions` şemasında — 203'ün dersi).
update auth.users
   set encrypted_password = extensions.crypt('Seed1234!', extensions.gen_salt('bf'))
 where (email like 'kaynak%@seed.loungelink.test' or email = 'kmisafir9@seed.loungelink.test')
   and encrypted_password is null;

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

insert into users (id, email, role)
select a.id, a.email, 'guest'
  from auth.users a
 where (a.email like 'kaynak%@seed.loungelink.test' or a.email = 'kmisafir9@seed.loungelink.test')
   and not exists (select 1 from users u where u.id = a.id);

insert into profiles (user_id, name, profession, guest_capacity, show_on_discovery)
select u.id,
       case u.email
         when 'kaynak1@seed.loungelink.test' then 'Kaynak Bir · üç kartlı'
         when 'kaynak2@seed.loungelink.test' then 'Kaynak İki · PP Prestige'
         when 'kaynak3@seed.loungelink.test' then 'Kaynak Üç · DragonPass'
         when 'kaynak4@seed.loungelink.test' then 'Kaynak Dört · LoungeKey'
         when 'kaynak5@seed.loungelink.test' then 'Kaynak Beş · Elite + PP'
         when 'kaynak6@seed.loungelink.test' then 'Kaynak Altı · belirsiz salon'
         else 'Misafir Dokuz' end,
       'Test', 1, true
  from users u
 where (u.email like 'kaynak%@seed.loungelink.test' or u.email = 'kmisafir9@seed.loungelink.test')
   and not exists (select 1 from profiles p where p.user_id = u.id);

insert into verifications (user_id, email_verified, email_verified_at, phone_verified)
select u.id, true, now(), true
  from users u
 where (u.email like 'kaynak%@seed.loungelink.test' or u.email = 'kmisafir9@seed.loungelink.test')
on conflict (user_id) do update set email_verified = true, phone_verified = true;


-- ============================================================
-- 1) HAKLAR — KADEMESİYLE BİRLİKTE
-- ============================================================
-- 🔴 KADEME (`tier`) BURADA ŞART. Birinci seed kart ağı haklarını
-- kademesiz yazıyor ve o hâlde `salon_misafir_karsilastirmasi`
-- "bende var" sütununu DOLDURAMIYOR: kademe eşleşmesi
-- `upper(e.tier) = upper(g.card_tier)` üzerinden kuruluyor.
-- Kademesiz bir hak, ekranda "bu kart sende yok" gibi görünür.
do $$
declare r record; v_pid uuid;
begin
  for r in select * from (values
      -- kaynak1: ÜÇ KART BİRDEN — "hangi kartımı kullanayım"ın tek gerçek senaryosu
      ('kaynak1@seed.loungelink.test','TK_MS',        'ELITE'),
      ('kaynak1@seed.loungelink.test','PRIORITY_PASS','PP_STANDARD'),
      ('kaynak1@seed.loungelink.test','DRAGONPASS',   'DP_CLASSIC'),
      -- kaynak2: en pahalı PP planı — "hak satın alınamıyor"un kanıtı
      ('kaynak2@seed.loungelink.test','PRIORITY_PASS','PP_PRESTIGE'),
      -- kaynak3: DragonPass tek başına — AYNI UÇUŞ şartı sahneye çıksın
      ('kaynak3@seed.loungelink.test','DRAGONPASS',   'DP_PREFERENTIAL'),
      -- kaynak4: LoungeKey — tutarı bankaya bağlı olan tek ağ
      ('kaynak4@seed.loungelink.test','LOUNGEKEY',    null),
      -- kaynak5: ücretsiz hak + ücretli hak yan yana → sıralama testi
      ('kaynak5@seed.loungelink.test','TK_MS',        'ELPL'),
      ('kaynak5@seed.loungelink.test','PRIORITY_PASS','PP_STANDARD_PLUS'),
      -- kaynak6: DragonPass, kaynağı BELİRSİZ salonda (AYT/DLM CIP)
      ('kaynak6@seed.loungelink.test','DRAGONPASS',   'DP_CLASSIC')
    ) as t(mail, prog, kademe)
  loop
    select id into v_pid from lounge_programs where code = r.prog;
    if v_pid is null then
      raise exception 'SEED2: % programi yok — kart agi migrationlari (211/214) calismamis olabilir', r.prog;
    end if;
    insert into host_entitlements (user_id, program_id, tier, verified, self_reported_at)
    select u.id, v_pid, r.kademe, true, now()
      from users u where u.email = r.mail
       and not exists (select 1 from host_entitlements e
                        where e.user_id = u.id and e.program_id = v_pid);
  end loop;
end $$;


-- ============================================================
-- ----------------------------------------------------------------------------
-- 1b) VİTRİN SALONUNU ADIYLA DEĞİL, YAPTIĞI İŞLE SEÇ
-- ----------------------------------------------------------------------------
-- 🔴 İKİNCİ HATA, BİRİNCİ DÜZELTMEMİN SONUCU (22 Ağustos, akşam):
--   ERROR: SEED2: ucretsiz secenek varken "Misafir alinabilir ama UCRETLI" onerildi
--
-- Sabah salon adını toleranslı hale getirdim: bulunamazsa benzerine
-- düşüyordu. Koşu tamamlandı ama SAHNE BOZULDU — çünkü senaryonun
-- ihtiyacı "iGA Lounge" adı değil, o salonun VERDİĞİ CEVAPtı:
-- kaynak1'in üç kartından en az birinin orada ÜCRETSİZ misafir hakkı
-- vermesi. Başka bir salona düşünce o özellik kayboldu ve nöbetçi —
-- haklı olarak — kırmızı yandı.
--
-- 🆕 SINIF: **"BİR SAHNEYİ AYAKTA TUTAN ŞEY DEKORUN ADI DEĞİL, OYNADIĞI
-- ROLDÜR. ADI ESNEK YAPIP ROLÜ SABİT SANMAK, İKİSİNİ DE KAYBETMEKTİR."**
--
-- Doğrusu: salonu ADIYLA değil, TAŞIMASI GEREKEN ÖZELLİKLE seç.
--   (1) kaynak1'e ÜCRETSİZ misafir hakkı öneriyor mu
--   (2) aynı salonda kaynağa göre EN AZ 3 farklı cevap çıkıyor mu
-- Ad yalnızca EŞİTLİK BOZUCU: özelliği taşıyan salonlar arasında
-- 'iGA Lounge — Dış Hat' varsa o tercih edilir, sahne bugünküyle
-- birebir aynı kalır.
create table if not exists seed2_sahne (venue_id uuid primary key, nasil text);
delete from seed2_sahne;
-- 241/242'nin kuralı bu tablo için de geçerli: Supabase yeni tabloyu
-- anon/authenticated'a AÇIK doğurur. Kendi koyduğum kuralı kendi
-- ürettiğim tabloda çiğnemeyeyim.
revoke all on public.seed2_sahne from anon, authenticated;
alter table public.seed2_sahne enable row level security;

do $sahne$
declare v_host uuid; v_v uuid; v_nasil text; v_tanik text;
begin
  select id into v_host from users where email='kaynak1@seed.loungelink.test';
  if v_host is null then raise exception 'SEED2: kaynak1 hesabi yok'; end if;

  select v.id,
         case when v.airport_code='IST' and v.name='iGA Lounge — Dış Hat'
              then 'adiyla (tercih edilen)' else 'ozelligiyle secildi' end
    into v_v, v_nasil
    from lounge_venues v
   where v.active
     and (public.hangi_kartimi_kullanayim(v.id, v_host) -> 'oneri' ->> 'misafir_hakki')
         = 'Ucretsiz misafir hakki var'
     and (select count(distinct misafir_hakki)
            from public.salon_misafir_karsilastirmasi(v.id)) >= 3
   order by (v.airport_code='IST' and v.name='iGA Lounge — Dış Hat') desc,
            (v.airport_code='IST') desc, v.name, v.id
   limit 1;

  if v_v is null then
    -- Sahne kurulamıyorsa SESSİZCE geçmiyoruz. Ama hangi salonun neden
    -- düştüğünü de söylüyoruz — "olmadı" demek teşhis değildir.
    select string_agg(x.satir, E'\n' order by x.satir) into v_tanik from (
      select v.airport_code || ' · ' || v.name || ' → oneri: '
             || coalesce(public.hangi_kartimi_kullanayim(v.id, v_host) -> 'oneri' ->> 'misafir_hakki','(yok)')
             || ' · farkli cevap: '
             || (select count(distinct misafir_hakki) from public.salon_misafir_karsilastirmasi(v.id))::text as satir
        from lounge_venues v
       where v.active and v.airport_code in ('IST','SAW','ESB','ADB','AYT')
       limit 12) x;
    raise exception E'SEED2: kaynak1 icin UCRETSIZ misafir hakki veren ve kaynaga gore 3+ farkli cevap ureten salon YOK.\nKatalogda bulduklarim:\n%', coalesce(v_tanik,'(hic salon yok)');
  end if;

  insert into seed2_sahne (venue_id, nasil) values (v_v, v_nasil);
  raise notice 'SEED2 · vitrin salonu: "%" (%)',
    (select airport_code || ' · ' || name from lounge_venues where id=v_v), v_nasil;
end $sahne$;

-- 2) İLANLAR — HEPSİ ÇOK KAYNAKLI SALONLARDA
-- ============================================================
-- Salon seçimi TESADÜFE BIRAKILMIYOR. Birinci seed'in en pahalı dersi
-- buydu: `order by length(l.name)` beraberlik bırakıyordu ve seed her
-- koşuda başka salona ilan bağlıyordu; test beş koşuda dört geçiyordu
-- ve ben haftalarca "motor belirsiz" sanmıştım.
-- Burada salon ADIYLA seçiliyor ve bulunamazsa HATA veriyor.
do $$
declare r record; v_l uuid; v_ap text; v_gun date := current_date + 21;
        v_nasil text;
begin
  for r in select * from (values
      -- (mail, salon adi, havalimani, saat)
      ('kaynak1@seed.loungelink.test','iGA Lounge — Dış Hat','IST', time '09:00', time '13:00'),
      ('kaynak2@seed.loungelink.test','iGA Lounge — Dış Hat','IST', time '13:00', time '17:00'),
      ('kaynak3@seed.loungelink.test','iGA Lounge — İç Hat', 'IST', time '09:00', time '13:00'),
      ('kaynak4@seed.loungelink.test','Plaza Premium Lounge — İç Hat','SAW', time '10:00', time '14:00'),
      ('kaynak5@seed.loungelink.test','Turkish Airlines Lounge — Dış Hat (Miles&Smiles)','IST', time '17:00', time '21:00'),
      ('kaynak6@seed.loungelink.test','CIP Lounge — Dış Hat (T2)','AYT', time '10:00', time '14:00')
    ) as t(mail, salon, ap, s1, s2)
  loop
    -- ════════════════════════════════════════════════════════════════
    -- 🔴 22 AĞUSTOS (v2) — BU BLOK GÖKBERK'İN VERİTABANINDA PATLADI:
    --   ERROR: SEED2: "iGA Lounge — İç Hat" salonu IST'de bulunamadi
    --
    -- Harness'te o salon VAR. Yani hata SEED'in değil, VARSAYIMIN:
    -- katalog adlarının her veritabanında birebir aynı olduğunu
    -- varsaymıştım. Katalog 188/133/160 gibi dosyalarla birleştirilip
    -- tekilleştiriliyor ve sonuç, o dosyalar koştuğunda ORTAMDA NE
    -- OLDUĞUNA bağlı — yani ad, sabit değil TÜREV.
    --
    -- 🆕 SINIF: **"BİR SABİTİ KODA YAZMAK, ONU SABİT YAPMAZ."**
    --
    -- SEED4'te bu tolerans zaten vardı (üç kademeli çözücü); SEED2'de
    -- yoktu. Aynı sınıfın bir örneğini düzeltip sınıfı kapatmamışım.
    -- Artık dört kademe var ve HİÇBİRİ SESSİZ DEĞİL: ad birebir
    -- bulunamazsa hangi salona düşüldüğü NOTICE ile yazılır.
    -- ════════════════════════════════════════════════════════════════
    v_l := null; v_nasil := null;

    -- (0) Vitrin salonu: senaryonun ROLÜNÜ taşıyan salon yukarıda
    -- seçildi. Adı 'iGA Lounge — Dış Hat' olan satırlar oraya bağlanır ki
    -- app ekranı ile nöbetçi AYNI sahneye baksın.
    if r.salon = 'iGA Lounge — Dış Hat' then
      select ss.venue_id into v_l from seed2_sahne ss limit 1;
      if v_l is not null then
        select l.id into v_l from lounges l
         where l.venue_id = v_l and l.active order by l.id limit 1;
        if v_l is not null then v_nasil := 'birebir'; end if;
      end if;
    end if;

    -- (1) Birebir ad
    if v_l is null then
      select l.id into v_l
        from lounges l join lounge_venues v on v.id = l.venue_id
       where l.active and v.active and v.airport_code = r.ap and v.name = r.salon
       order by l.id limit 1;
      if v_l is not null then v_nasil := 'birebir'; end if;
    end if;

    -- (2) Normalize edilmiş ad: büyük/küçük, Türkçe harf, tire çeşidi,
    -- parantez ve boşluk farklarını yok say. (`lower()` kullanmıyorum —
    -- 'İ' harfinde yerel ayara göre iki karaktere açılıyor.)
    if v_l is null then
      select l.id into v_l
        from lounges l join lounge_venues v on v.id = l.venue_id
       where l.active and v.active and v.airport_code = r.ap
         and regexp_replace(translate(v.name,'İIıŞşĞğÜüÖöÇç','IIiSsGgUuOoCc'),'[^a-zA-Z0-9]','','g')
           = regexp_replace(translate(r.salon,'İIıŞşĞğÜüÖöÇç','IIiSsGgUuOoCc'),'[^a-zA-Z0-9]','','g')
       order by l.id limit 1;
      if v_l is not null then v_nasil := 'normalize ad'; end if;
    end if;

    -- (3) Marka + iç/dış hat. Önce ikisi birden, sonra sırayla marka,
    -- sonra hat. Sıralama rastgele değil: senaryo açısından "aynı marka"
    -- ve "aynı hat" en çok bilgi taşıyan iki özellik.
    if v_l is null then
      select l.id, case when v.name ilike '%' || btrim(split_part(r.salon,'—',1)) || '%'
                         and v.name ilike '%' || btrim(split_part(split_part(r.salon,'—',2),'(',1)) || '%'
                        then 'marka+hat'
                        when v.name ilike '%' || btrim(split_part(r.salon,'—',1)) || '%'
                        then 'ayni marka'
                        else 'ayni hat' end
        into v_l, v_nasil
        from lounges l join lounge_venues v on v.id = l.venue_id
       where l.active and v.active and v.airport_code = r.ap
         and (v.name ilike '%' || btrim(split_part(r.salon,'—',1)) || '%'
           or v.name ilike '%' || btrim(split_part(split_part(r.salon,'—',2),'(',1)) || '%')
       order by
         (case when v.name ilike '%' || btrim(split_part(r.salon,'—',1)) || '%' then 0 else 1 end)
       + (case when v.name ilike '%' || btrim(split_part(split_part(r.salon,'—',2),'(',1)) || '%' then 0 else 1 end),
         length(v.name), l.id
       limit 1;
    end if;

    -- (4) YEDEK: o havalimanındaki BELİRLENİMCİ ilk salon. Rastgele
    -- değil — ada göre sıralı, yani her koşuda aynı. Senaryonun
    -- havalimanı korunur, salon adı değişir.
    if v_l is null then
      select l.id into v_l
        from lounges l join lounge_venues v on v.id = l.venue_id
       where l.active and v.active and v.airport_code = r.ap
       order by v.name, l.id limit 1;
      if v_l is not null then v_nasil := 'YEDEK — havalimanindaki ilk salon'; end if;
    end if;

    if v_l is null then
      raise exception 'SEED2: %''de HIC aktif salon yok. Katalog kurulmamis olabilir — '
                      '188_salon_envanteri.sql kostu mu? Mevcut havalimanlari: %',
        r.ap,
        (select string_agg(distinct airport_code, ', ' order by airport_code)
           from lounge_venues where active);
    end if;

    if v_nasil <> 'birebir' then
      raise notice 'SEED2 · "%" (%) birebir bulunamadi → % ile "%" secildi',
        r.salon, r.ap, v_nasil,
        (select v.name from lounges l join lounge_venues v on v.id=l.venue_id where l.id=v_l);
    end if;

    insert into availabilities (host_id, lounge_id, airport_code, avail_date, time_from, time_to,
                                slots, filled, active, visibility)
    -- ⚠️ `availability_visibility` ENUM'unun degerleri: Public / Connections /
    -- Hidden. 'all' YOK. Uygulamanin form durumunda 'all' geciyor ama o
    -- RPC icinde cevriliyor; SEED tabloya DOGRUDAN yazdigi icin enum'un
    -- kendi degerini kullanmak zorunda. Enum degerini varsaymak, bu turda
    -- ucuncu kez isirdi.
    select u.id, v_l, r.ap, v_gun, r.s1, r.s2, 2, 0, true, 'Public'::availability_visibility
      from users u where u.email = r.mail
       and not exists (select 1 from availabilities a
                        where a.host_id = u.id and a.avail_date = v_gun and a.lounge_id = v_l);
  end loop;
end $$;

-- Misafir seyahati — ÜÇ havalimanına birden, çünkü senaryolar IST/SAW/AYT'ye yayılı.
insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number, carrier_code)
select u.id, x.ap, current_date + 21, time '08:00', time '22:00', x.ucus, x.tas
  from users u,
       (values ('IST','TK1980','TK'), ('SAW','PC2010','PC'), ('AYT','TK2400','TK')) as x(ap, ucus, tas)
 where u.email = 'kmisafir9@seed.loungelink.test'
   and not exists (select 1 from visits v
                    where v.user_id = u.id and v.airport_code = x.ap and v.visit_date = current_date + 21);


-- ============================================================
-- 3) SONUÇ TABLOSU — SEED'İN ASIL ÇIKTISI
-- ============================================================
-- Bir seed'in işi veri yazmak değil, SORUYU CEVAPLATMAK. Aşağıdaki üç
-- sorgu, bu turda eklenen üç şeyin gerçekten çalıştığını GÖZLE gösterir.

-- 3a) AYNI SALON, FARKLI KAYNAK — ürünün tek cümlesi
-- Beklenen: aynı satırda TK_MS Elite "ücretsiz", Priority Pass "ücretli",
-- DragonPass "ücretli + AYNI UÇUŞ", DreamFolks "alınamaz".
select (select v.airport_code || ' · ' || v.name from lounge_venues v
          join seed2_sahne ss on ss.venue_id = v.id) as salon,
       k.program, coalesce(k.kart_tipi,'—') as kart, k.misafir_hakki, k.ucret, k.ucusa_bagli
  from public.salon_misafir_karsilastirmasi((select venue_id from seed2_sahne)) k
 where k.program in ('TK_MS','PRIORITY_PASS','DRAGONPASS','LOUNGEKEY','DREAMFOLKS')
 order by k.program, k.kart_tipi;

-- 3b) "HANGİ KARTIMI KULLANAYIM" — üç kartlı host için
-- Beklenen: kaynak1'e Miles&Smiles Elite önerilmeli (ücretsiz),
-- Priority Pass ve DragonPass değil (ücretli).
select u.email,
       public.hangi_kartimi_kullanayim((select venue_id from seed2_sahne), u.id) as oneri
  from users u
 where u.email in ('kaynak1@seed.loungelink.test','kaynak2@seed.loungelink.test',
                   'kaynak3@seed.loungelink.test','kaynak5@seed.loungelink.test')
 order by u.email;

-- 3c) MİSAFİR HAKKI SATIN ALINABİLİYOR MU
-- Beklenen: ikisinde de `misafir_ucretsiz_olan_plan_var_mi = false`.
-- Yani en pahalı plan bile misafiri ücretsiz yapmıyor — LoungeLink'in
-- varlık sebebi tek satırda.
select public.misafir_hakki_satin_alinabilir_mi('PRIORITY_PASS') as pp,
       public.misafir_hakki_satin_alinabilir_mi('DRAGONPASS')    as dp;

-- 3d) KARAR MOTORU — v5 ile (birinci seed hâlâ v4 kullanıyor; ikisi de
-- geçerli, ama yeni eksenler v5'te). Her ilan için ne çıkıyor?
select pr.name as host, v.airport_code, left(v.name, 34) as salon,
       (public.lounge_access_decision_v5(a.id, null) ->> 'severity')     as sonuc,
       (public.lounge_access_decision_v5(a.id, null) ->> 'guest_policy') as misafir,
       left(public.lounge_access_decision_v5(a.id, null) ->> 'headline', 52) as baslik
  from availabilities a
  join users u on u.id = a.host_id
  join profiles pr on pr.user_id = u.id
  join lounges l on l.id = a.lounge_id
  join lounge_venues v on v.id = l.venue_id
 where u.email like 'kaynak%@seed.loungelink.test'
 order by u.email;

-- 3e) KAYNAĞI BELİRSİZ SALON — uyarı gerçekten çıkıyor mu
-- kaynak6 AYT'de DragonPass ile ilan açtı. DragonPass'in AYT sayfası tek
-- bir "CIP Lounge" listeliyor ve hangisi olduğunu YAZMIYOR; 214 bunu
-- `enforcement='warn'` + "KAYNAK BELIRSIZ" notuyla işaretledi.
-- Beklenen: aşağıdaki sorgu EN AZ BİR satır döndürmeli.
select v.airport_code, left(v.name,30) as salon, a.enforcement,
       left(a.conditions, 90) as not
  from lounge_venue_acceptance a
  join lounge_venues v on v.id = a.venue_id
  join lounge_programs p on p.id = a.program_id
 where p.code = 'DRAGONPASS' and a.conditions ilike '%KAYNAK BELIRSIZ%'
 order by v.airport_code;


-- ============================================================
-- 4) NÖBETÇİ — SEED KENDİ İDDİASINI DOĞRULUYOR
-- ============================================================
-- Bir seed "veri yazdım" deyip geçerse, yazdığının DOĞRU sahneyi kurup
-- kurmadığı bilinmez. Bu blok üç iddiayı da ölçüyor.
do $$
declare v_venue uuid; v_cok int; v_farkli int; v_oneri jsonb; v_belirsiz int;
begin
  -- Nöbetçi de vitrin salonunu ADIYLA değil, SEÇİLMİŞ HALİYLE okur.
  -- Aksi hâlde sahne bir salonda kurulup başka salonda ölçülür.
  select venue_id into v_venue from seed2_sahne limit 1;
  if v_venue is null then raise exception 'SEED2: vitrin salonu secilmedi (1b blogu kosmamis)'; end if;

  -- (1) birden çok kartı olan host GERÇEKTEN var mı
  select count(*) into v_cok from (
    select e.user_id from host_entitlements e join users u on u.id = e.user_id
     where u.email like 'kaynak%@seed.loungelink.test'
     group by e.user_id having count(*) > 1) x;
  if v_cok = 0 then
    raise exception 'SEED2: birden cok karti olan host YOK — "hangi kartimi kullanayim" yine sahnesiz';
  end if;

  -- (2) aynı salon farklı cevap veriyor mu
  select count(distinct misafir_hakki) into v_farkli
    from public.salon_misafir_karsilastirmasi(v_venue);
  if v_farkli < 3 then
    raise exception 'SEED2: ayni salonda yalnizca % farkli cevap var — kaynaga gore degisim gorunmuyor', v_farkli;
  end if;

  -- (3) üç kartlı host'a ÜCRETSİZ olan öneriliyor mu (sıralama doğru mu)
  select public.hangi_kartimi_kullanayim(v_venue, u.id) into v_oneri
    from users u where u.email = 'kaynak1@seed.loungelink.test';
  if (v_oneri ->> 'oneri') is null then
    raise exception 'SEED2: uc karti olan host icin oneri URETILMEDI → %', left(v_oneri::text, 300);
  end if;
  if (v_oneri -> 'oneri' ->> 'misafir_hakki') <> 'Ucretsiz misafir hakki var' then
    raise exception 'SEED2: ucretsiz secenek varken "%" onerildi', v_oneri -> 'oneri' ->> 'misafir_hakki';
  end if;

  -- (4) belirsiz kaynak uyarısı sahnede mi
  select count(*) into v_belirsiz from lounge_venue_acceptance a
    join lounge_programs p on p.id = a.program_id
   where p.code='DRAGONPASS' and a.conditions ilike '%KAYNAK BELIRSIZ%';
  if v_belirsiz = 0 then
    raise notice 'SEED2: ⚠ "kaynak belirsiz" uyarili satir yok — 214 calismamis olabilir';
  end if;

  raise notice 'SEED2: sahne kuruldu — % cok kartli host, salonda % farkli cevap, oneri "%"',
    v_cok, v_farkli, v_oneri -> 'oneri' ->> 'program_adi';
end $$;

select 'SEED2 OK - kaynak senaryolari kuruldu (kaynak1..6 + kmisafir9, sifre Seed1234!)' as sonuc;

-- ============================================================
-- TEMİZLİK (canlıdan silmek istersen — yorumu kaldır)
-- ============================================================
-- delete from availabilities where host_id in
--   (select id from users where email like 'kaynak%@seed.loungelink.test');
-- delete from visits where user_id in
--   (select id from users where email = 'kmisafir9@seed.loungelink.test');
-- delete from host_entitlements where user_id in
--   (select id from users where email like 'kaynak%@seed.loungelink.test');
-- delete from verifications where user_id in
--   (select id from users where email like '%@seed.loungelink.test' and email like 'k%9%');
-- delete from profiles where user_id in
--   (select id from users where email like 'kaynak%@seed.loungelink.test'
--                            or email = 'kmisafir9@seed.loungelink.test');
-- delete from users     where email like 'kaynak%@seed.loungelink.test' or email = 'kmisafir9@seed.loungelink.test';
-- delete from auth.users where email like 'kaynak%@seed.loungelink.test' or email = 'kmisafir9@seed.loungelink.test';
