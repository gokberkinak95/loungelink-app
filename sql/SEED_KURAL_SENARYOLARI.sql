-- ============================================================
-- LoungeLink · SEED_KURAL_SENARYOLARI.sql
-- KURAL MOTORUNU GÖZLE GÖRMEK İÇİN TEST VERİSİ
--
-- ⚠️ BU BİR MIGRATION DEĞİL, TEST VERİSİDİR. 102'den SONRA çalıştır.
-- Temizlik: en alttaki TEMIZLIK bloğu (yorumda) yeterli.
--
-- NEDEN: kural motorunda dokuz farklı yol var (tier engeli, AJet'in
-- İstanbul istisnası, kart ağı ücreti, aynı-uçuş şartı, charter,
-- kalış süresi, slot çakışması, bilinmeyen kural, banka kartı).
-- Bunları TEK TEK üretmeden "çalışıyor" demek, çalıştığını
-- varsaymaktır. Her senaryo için bir host + bir ilan var; keşifte
-- yan yana görünce hangi rozetin ne zaman çıktığı bir bakışta anlaşılır.
--
-- Hesaplar: kural1..kural18@seed.loungelink.test · şifre Seed1234!
-- Misafirler: kmisafir1..3@seed.loungelink.test
-- ============================================================

-- ---- 0) auth kullanicilari ----
insert into auth.users (id, email)
select x.id::uuid, x.email
  from (values
    ('11110001-0000-4000-8000-000000000001','kural1@seed.loungelink.test'),
    ('11110002-0000-4000-8000-000000000002','kural2@seed.loungelink.test'),
    ('11110003-0000-4000-8000-000000000003','kural3@seed.loungelink.test'),
    ('11110004-0000-4000-8000-000000000004','kural4@seed.loungelink.test'),
    ('11110005-0000-4000-8000-000000000005','kural5@seed.loungelink.test'),
    ('11110006-0000-4000-8000-000000000006','kural6@seed.loungelink.test'),
    ('11110007-0000-4000-8000-000000000007','kural7@seed.loungelink.test'),
    ('11110008-0000-4000-8000-000000000008','kural8@seed.loungelink.test'),
    ('11110009-0000-4000-8000-000000000009','kural9@seed.loungelink.test'),
    ('1111000a-0000-4000-8000-00000000010a','kural10@seed.loungelink.test'),
    ('1111000b-0000-4000-8000-00000000010b','kural11@seed.loungelink.test'),
    ('1111000c-0000-4000-8000-00000000010c','kural12@seed.loungelink.test'),
    ('1111000d-0000-4000-8000-00000000010d','kural13@seed.loungelink.test'),
    ('1111000e-0000-4000-8000-00000000010e','kural14@seed.loungelink.test'),
    ('1111000f-0000-4000-8000-00000000010f','kural15@seed.loungelink.test'),
    ('11110010-0000-4000-8000-000000000110','kural16@seed.loungelink.test'),
    ('11110011-0000-4000-8000-000000000111','kural17@seed.loungelink.test'),
    ('11110012-0000-4000-8000-000000000112','kural18@seed.loungelink.test'),
    ('2222000a-0000-4000-8000-00000000000a','kmisafir1@seed.loungelink.test'),
    ('2222000b-0000-4000-8000-00000000000b','kmisafir2@seed.loungelink.test'),
    ('2222000c-0000-4000-8000-00000000000c','kmisafir3@seed.loungelink.test')
  ) as x(id, email)
on conflict (id) do nothing;

-- ---- 0b) SIFRE: Seed1234! ----
-- 🔴 crypt() Supabase'de `extensions` semasinda ve arama yolunda
-- OLMAYABILIR. Statik yazarsak "function crypt does not exist" ile
-- PATLAR ve hesaplara GIRILEMEZ. Dinamik SQL ile once extensions.crypt,
-- olmazsa crypt deniyoruz; ikisi de yoksa sessizce geciyoruz.
do $$
declare v_sql text; v_where text;
begin
  v_where := ' where email like ''kural%@seed.loungelink.test'' or email like ''kmisafir%@seed.loungelink.test'' ';
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where p.proname='crypt' and n.nspname='extensions') then
    v_sql := 'update auth.users set encrypted_password = extensions.crypt($1, extensions.gen_salt(''bf''))';
  elsif exists (select 1 from pg_proc p where p.proname='crypt') then
    v_sql := 'update auth.users set encrypted_password = crypt($1, gen_salt(''bf''))';
  else
    raise notice 'pgcrypto yok - sifre atanamadi, Supabase panelinden elle belirle.';
    return;
  end if;
  execute v_sql || v_where using 'Seed1234!';
end $$;

-- GoTrue'nun bekledigi alanlar (073 ile ayni yama; bu dosya kendi kendine yeter)
update auth.users set
  instance_id                = coalesce(instance_id,'00000000-0000-0000-0000-000000000000'::uuid),
  aud = coalesce(aud,'authenticated'), role = coalesce(role,'authenticated'),
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  created_at = coalesce(created_at, now()), updated_at = coalesce(updated_at, now()),
  raw_app_meta_data = coalesce(raw_app_meta_data,'{"provider":"email","providers":["email"]}'::jsonb),
  confirmation_token = coalesce(confirmation_token,''), recovery_token = coalesce(recovery_token,''),
  email_change = coalesce(email_change,''), email_change_token_new = coalesce(email_change_token_new,''),
  email_change_token_current = coalesce(email_change_token_current,''),
  phone_change = coalesce(phone_change,''), phone_change_token = coalesce(phone_change_token,''),
  reauthentication_token = coalesce(reauthentication_token,''), is_sso_user = coalesce(is_sso_user,false)
where email like 'kural%@seed.loungelink.test' or email like 'kmisafir%@seed.loungelink.test';

do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='auth' and table_name='identities' and column_name='provider_id') then
    insert into auth.identities (user_id, provider_id, identity_data, provider,
                                 last_sign_in_at, created_at, updated_at)
    select u.id, u.id::text,
           jsonb_build_object('sub',u.id::text,'email',u.email,'email_verified',true,'phone_verified',false),
           'email', now(), now(), now()
      from auth.users u
     where (u.email like 'kural%@seed.loungelink.test' or u.email like 'kmisafir%@seed.loungelink.test')
       and not exists (select 1 from auth.identities i where i.user_id=u.id and i.provider='email');
  end if;
end $$;

-- ---- 1) profiller + roller ----
update users set role='host' where email like 'kural%@seed.loungelink.test';
update users set role='guest' where email like 'kmisafir%@seed.loungelink.test';

update profiles p set name = x.nm, profession = x.pr, guest_capacity = x.cap,
       access_source = x.src, guest_fee_expected = x.fee,
       bio = 'Kural motoru test hesabi. Senaryo: ' || x.sen, updated_at = now()
  from (values
   ('kural1@seed.loungelink.test','Elif Elite Plus','Teknoloji',1,'Miles&Smiles Elite Plus',false,'TK Elite Plus — hak VAR'),
   ('kural2@seed.loungelink.test','Burak Classic Plus','Finans',1,'Miles&Smiles Classic Plus',false,'TK Classic Plus — MISAFIR HAKKI YOK'),
   ('kural3@seed.loungelink.test','Ceren AJet IST','Hukuk',1,'AJet Miles&Smiles Elite Plus',false,'AJet @ IST — hak YOK'),
   ('kural4@seed.loungelink.test','Deniz AJet ESB','Egitim',1,'AJet Miles&Smiles Elite Plus',false,'AJet @ ESB — hak VAR'),
   ('kural5@seed.loungelink.test','Emre Priority Pass','Saglik',1,'Priority Pass',true,'PP — misafir UCRETLI, host kartindan'),
   ('kural6@seed.loungelink.test','Funda DragonPass','Medya',1,'DragonPass',true,'DragonPass — AYNI UCUS sarti'),
   ('kural7@seed.loungelink.test','Gokay Banka Karti','Insaat',1,'Kredi Kartı Avantajı',null,'Banka karti — GENEL UYARI'),
   ('kural8@seed.loungelink.test','Hakan Charter','Turizm',1,'Miles&Smiles Elite Plus',false,'Charter — hak YOK'),
   ('kural9@seed.loungelink.test','Irem Uzun Ilan','Danismanlik',3,'Miles&Smiles Elite Plus',false,'3 slot + uzun sure — cakisma uyarisi'),
   ('kural10@seed.loungelink.test','Jale Star Gold','Havacilik',1,'Star Alliance Gold',false,'Star Gold — 1 misafir, AILE YOK'),
   ('kural11@seed.loungelink.test','Kerem Classic','Lojistik',1,'Miles&Smiles Classic',true,'TK Classic — UCRETLI giris, misafir hakki yok'),
   ('kural12@seed.loungelink.test','Leyla Pegasus','Perakende',1,'Pegasus ucretli lounge',true,'Pegasus — kapida odenen ucretli giris'),
   ('kural13@seed.loungelink.test','Murat LoungeKey','Bankacilik',1,'LoungeKey',true,'LoungeKey — ucret HOST kartindan'),
   ('kural14@seed.loungelink.test','Nazli Business','Danismanlik',1,'Business Class bileti',false,'Business bileti — kartsiz, misafir hakki YOK'),
   ('kural15@seed.loungelink.test','Ozan Corporate','Kurumsal',1,'Turkish Airlines Corporate Club',false,'CORP — ayni bilet sarti'),
   ('kural16@seed.loungelink.test','Pinar ABD Karti','Finans',1,'Miles&Smiles ABD Kredi Karti',false,'MS_US_CC — misafir hakki YOK'),
   ('kural17@seed.loungelink.test','Rana Aile','Egitim',1,'Miles&Smiles Elite Plus',false,'Aile hakki — es + 25 yas alti'),
   ('kural18@seed.loungelink.test','Sinan Privia','Bankacilik',1,'Privia Black',true,'Banka anlasmasi — ayda 1, 1 misafir'),
   ('kmisafir1@seed.loungelink.test','Kaan Misafir','Yazilim',null,null,null,'TK712 ile ayni ucus'),
   ('kmisafir2@seed.loungelink.test','Lale Misafir','Pazarlama',null,null,null,'AJ1876 — farkli tasiyici'),
   ('kmisafir3@seed.loungelink.test','Mert Misafir','Muhendislik',null,null,null,'Ucus numarasi YOK')
  ) as x(em, nm, pr, cap, src, fee, sen)
  join users u on u.email = x.em
 where p.user_id = u.id;

-- 🔴 Kesifte GORUNSUNLER: 074 ekip hesaplarini gizliyor; seed hesaplari
-- o kapiya takilirsa ilanlar hic listelenmez ve test bos ekran verir.
update users u set is_staff = false
 where u.email like 'kural%@seed.loungelink.test'
    or u.email like 'kmisafir%@seed.loungelink.test';
update profiles p set show_on_discovery = true, profile_visibility = 'Everyone'
  from users u where p.user_id = u.id
   and (u.email like 'kural%@seed.loungelink.test'
        or u.email like 'kmisafir%@seed.loungelink.test');

-- ============================================================
-- SEYAHAT TARZI (132) — UYUM MATRISININ HER DALI TEST EDILSIN
--
-- 🔴 Dagilimi rastgele degil KASITLI seciyorum:
--   · kural1 social + kmisafir1 social  -> +12, "ikiniz de sohbete aciksiniz"
--   · kural5 zen    + kmisafir1 social  -> -10, UYARI cikmali
--   · kural6 foodie + kmisafir2 explorer-> +8,  uyumlu
--   · kural9 BOS                        ->  0,  ceza YOK, not YOK
-- Rastgele doldurursam matrisin negatif dali hic calismaz ve
-- "uyari cikiyor mu" sorusu cevapsiz kalir.
-- ============================================================
update profiles p set travel_style = x.st
  from (values
   ('kural1@seed.loungelink.test','social'),
   ('kural2@seed.loungelink.test','zen'),
   ('kural4@seed.loungelink.test','explorer'),
   ('kural5@seed.loungelink.test','zen'),
   ('kural6@seed.loungelink.test','foodie'),
   ('kural10@seed.loungelink.test','social'),
   ('kural11@seed.loungelink.test','foodie'),
   ('kural17@seed.loungelink.test','social'),
   ('kmisafir1@seed.loungelink.test','social'),
   ('kmisafir2@seed.loungelink.test','explorer'),
   ('kmisafir3@seed.loungelink.test','zen')
   -- kural9, kural18 vd. BOS birakildi: bos birakanin cezalandirilmadigini
   -- de test etmek gerek.
  ) as x(em, st)
  join users u on u.email = x.em
 where p.user_id = u.id;

update verifications v set phone_verified=true, id_verified=true
  from users u where v.user_id=u.id
   and (u.email like 'kural%@seed.loungelink.test' or u.email like 'kmisafir%@seed.loungelink.test');

insert into credit_ledger (user_id, delta, reason, balance_after)
select u.id, 10, 'kural-seed', 10 from users u
 where u.email like 'kmisafir%@seed.loungelink.test'
   and not exists (select 1 from credit_ledger c where c.user_id=u.id and c.reason='kural-seed');

-- ---- 2) HOST HAKLARI (kart tipi dahil — asil test bu) ----
delete from host_entitlements he using users u
 where he.user_id=u.id and u.email like 'kural%@seed.loungelink.test';

insert into host_entitlements (user_id, program_id, tier, guest_capacity, origin, self_reported_at, note)
select u.id, p.id, x.tier, 1, 'declared', now(), 'kural-seed'
  from (values
   ('kural1@seed.loungelink.test','TK_MS','ELPL'),
   ('kural2@seed.loungelink.test','TK_MS','CLPL'),
   ('kural3@seed.loungelink.test','AJET_MS','ELPL'),
   ('kural4@seed.loungelink.test','AJET_MS','ELPL'),
   ('kural5@seed.loungelink.test','PRIORITY_PASS',null),
   ('kural6@seed.loungelink.test','DRAGONPASS',null),
   ('kural7@seed.loungelink.test','BANK_CARD',null),
   ('kural8@seed.loungelink.test','TK_MS','ELPL'),
   ('kural9@seed.loungelink.test','TK_MS','ELPL'),
   ('kural10@seed.loungelink.test','STAR_GOLD',null),
   ('kural11@seed.loungelink.test','TK_MS','CLASSIC'),
   ('kural12@seed.loungelink.test','PGS_PAID',null),
   ('kural13@seed.loungelink.test','LOUNGEKEY',null),
   ('kural14@seed.loungelink.test','BUSINESS_TICKET',null),
   ('kural15@seed.loungelink.test','TK_MS','CORP'),
   ('kural16@seed.loungelink.test','TK_MS','MS_US_CC'),
   ('kural17@seed.loungelink.test','TK_MS','ELPL'),
   ('kural18@seed.loungelink.test','PLAZA_PREMIUM',null)
  ) as x(em, code, tier)
  join users u on u.email = x.em
  join lounge_programs p on p.code = x.code;

-- ============================================================
-- KART URUNU SECIMI (114) — GUVEN DERECESI EKRANDA GORUNSUN
--
-- 🔴 Iki host, iki farkli guven derecesi:
--   · kural5 -> QNB Private (VERIFIED, misafir AYNI havuzdan duser)
--   · kural13 -> ikincil kaynakli bir kart (⚠ dogrulanmadi)
-- Boylece hem yesil hem amber rozet ayni ekranda gorulebilir ve
-- "dogrulanmamis kart secilince uyari cikiyor mu" test edilir.
-- ============================================================
update host_entitlements he set card_product_id = cp.id
  from users u, lounge_card_products cp, lounge_issuers i
 where he.user_id = u.id and cp.issuer_id = i.id
   and u.email = 'kural5@seed.loungelink.test'
   and i.code = 'QNB' and cp.confidence = 'verified';

update host_entitlements he set card_product_id = cp.id
  from users u, lounge_card_products cp, lounge_issuers i
 where he.user_id = u.id and cp.issuer_id = i.id
   and u.email = 'kural13@seed.loungelink.test'
   and i.code = 'TEB' and cp.confidence = 'secondary';

-- ---- 3) İLANLAR — her senaryo bir satir ----
delete from availabilities a using users u
 where a.host_id=u.id and u.email like 'kural%@seed.loungelink.test';

insert into availabilities
  (host_id, lounge_id, airport_code, avail_date, time_from, time_to, slots, filled,
   flight_number, carrier, visibility, is_charter, carrier_code)
select u.id,
       (select l.id from lounges l
         where l.airport_code = x.ap and l.active
           and lower(l.name) like '%' || lower(x.lounge) || '%'
         -- 🔴 KIRILGANLIGIN KOK NEDENI BURASIYDI.
         -- "en kisa adi al (belirsizligi tesadufe birakma)" diye yazmisim
         -- ama `order by length(l.name)` TEK BASINA belirsizdir: iki salon
         -- ayni uzunluktaysa PostgreSQL istedigini secer.
         --
         -- Sonuc: seed her kosuda FARKLI salona ilan bagliyordu. Bazen
         -- Priority Pass kabul eden salona, bazen etmeyene. two_account
         -- testi bes kosuda dort kez geciyor, bir kez dusuyordu — ve ben
         -- bunu haftalarca "motor belirsiz" saydim.
         --
         -- Hata kural motorunda DEGIL, TESTIN KENDI VERISINDEYDI.
         -- Kirilgan bir test, kovaladigim hatanin ta kendisiydi.
         --
         -- `l.id` benzersizdir; en sona koyunca beraberlik kesin biter.
         -- 🔴 VE `venue_id is not null` SART.
         -- `l.id` eklemek beraberligi bitirdi ama yetmedi: aday
         -- salonlardan bazilarinin `venue_id`'si YOK ve kural motoru
         -- venue uzerinden calisiyor. Seed bazen o salonu seciyordu
         -- ve test "kural bulunamadi" diye dusuyordu.
         --
         -- Yani iki ayri belirsizlik ust uste binmis: siralama
         -- beraberligi VE venue'suz salonlar. Ilkini duzeltince
         -- ikincisi gorunur oldu — kirilgan testler boyle katmanlidir.
           and l.venue_id is not null
         -- 🔴 v161: ÜÇÜNCÜ BELİRSİZLİK KATMANI. Katalog tekilleşince
         -- "turkish airlines lounge — dış hat" filtresi İKİ bölüme birden
         -- uyar oldu: (Business) ve (Miles&Smiles). `length(l.name)` kısa
         -- olanı (Business) seçti ve ELPL senaryosu düştü — oysa Tablo-4'ün
         -- aile istisnası M&S BÖLÜMÜNE ait. Ad uzunluğu keyfi bir ölçüttü.
         -- Artık önce ANLAMLI ölçüt: host'un kartının misafirle kabul
         -- edildiği bölüm tercih edilir (gerçek bir ilan da böyle açılır).
         order by (select count(*) from lounge_venue_acceptance a2
                     join host_entitlements he2
                       on he2.program_id = a2.program_id and he2.user_id = u.id
                    where a2.venue_id = l.venue_id and a2.active and a2.accepted
                      and coalesce(a2.guest_policy,'') <> 'not_allowed') desc,
                  length(l.name), l.id limit 1),
       x.ap::char(3), current_date + 2, x.t1::time, x.t2::time, x.slots, 0,
       -- 🔴 'all' DEGIL 'Public'. Uygulama create_availability RPC'sini
       -- cagiriyor ve o fonksiyon 'all' -> 'Public' cevirisini kendi yapiyor
       -- (SQL 071). Bu seed RPC'yi ATLAYIP dogrudan tabloya yazdigi icin
       -- enum'un KENDI degerini kullanmak zorunda:
       -- availability_visibility = Public | Connections | Hidden
       x.fl, x.cr, 'Public'::availability_visibility, x.charter,
       -- 117: tasiyici artik ACIK alan; ucus numarasindan tahmin degil.
       -- 'AJ' yazimini VF'ye ceviriyoruz (AJet'in gercek IATA kodu VF).
       case x.cr when 'AJ' then 'VF' else x.cr end
  from (values
   ('kural1@seed.loungelink.test','IST','turkish airlines lounge — dış hat','13:00','16:00',1,'TK712','TK',false),
   ('kural2@seed.loungelink.test','IST','turkish airlines lounge — dış hat','13:30','16:30',1,'TK714','TK',false),
   ('kural3@seed.loungelink.test','IST','turkish airlines lounge — dış hat','14:00','17:00',1,'AJ1876','AJ',false),
   ('kural4@seed.loungelink.test','ESB','turkish airlines cip lounge','09:00','11:00',1,'AJ2210','AJ',false),
   ('kural5@seed.loungelink.test','IST','iga lounge — dış hat','12:00','15:00',1,'TK1980','TK',false),
   ('kural6@seed.loungelink.test','SAW','plaza premium lounge — marmara — dış hat','10:00','12:00',1,'PC2034','PC',false),
   ('kural7@seed.loungelink.test','ADB','primeclass lounge — dış hat','15:00','18:00',1,'TK2312','TK',false),
   ('kural8@seed.loungelink.test','IST','turkish airlines lounge — dış hat','08:00','11:00',1,'TK9001','TK',true),
   ('kural9@seed.loungelink.test','IST','turkish airlines lounge — dış hat','06:00','13:00',3,'TK716','TK',false),
   ('kural10@seed.loungelink.test','IST','turkish airlines lounge — dış hat','11:00','14:00',1,'LH1302','LH',false),
   ('kural11@seed.loungelink.test','IST','turkish airlines lounge — dış hat','09:00','12:00',1,'TK720','TK',false),
   ('kural12@seed.loungelink.test','SAW','plaza premium lounge','13:00','15:00',1,'PC1102','PC',false),
   ('kural13@seed.loungelink.test','ESB','primeclass lounge — dış hat','10:00','12:00',1,'TK2104','TK',false),
   ('kural14@seed.loungelink.test','IST','turkish airlines lounge — dış hat','16:00','19:00',1,'TK724','TK',false),
   ('kural15@seed.loungelink.test','IST','turkish airlines lounge — dış hat','07:00','10:00',1,'TK726','TK',false),
   ('kural16@seed.loungelink.test','DLM','cip lounge','12:00','14:00',1,'TK2402','TK',false),
   ('kural17@seed.loungelink.test','ESB','turkish airlines cip lounge','08:00','10:00',1,'TK2106','TK',false),
   ('kural18@seed.loungelink.test','SAW','plaza premium lounge','14:00','16:00',1,'PC1204','PC',false)
  ) as x(em, ap, lounge, t1, t2, slots, fl, cr, charter)
  join users u on u.email = x.em
 where exists (select 1 from airports a where a.code = x.ap);

-- ---- 4) MİSAFİR SEYAHATLERİ (uçuş bağı testleri icin) ----
-- 🔴 20 AGUSTOS — TEKRAR KURULUMDA FK IHLALI VERIYORDU:
--   ERROR: update or delete on table "visits" violates foreign key
--          constraint "requests_visit_id_fkey" on table "requests"
-- Bu satir kmisafir seyahatlerini KOSULSUZ siliyor. Ilk kurulumda
-- zararsiz (henuz istek yok) ama tur ikinci kez kurulunca o seyahatlere
-- BAGLI istekler olusmus oluyor ve silme reddediliyor.
-- Yeni harness nobetcisi (pg_run TEKRAR KURULUM) bunu yakaladi; daha
-- once gorunmuyordu cunku harness hep BOS veritabanina kuruyordu.
-- Cozum: bagli istegi olan seyahate dokunma. Silinmeyen birkac satir,
-- kurulumun durmasindan iyidir; asagidaki insert zaten mukerrer
-- yazmiyor.
delete from visits v using users u
 where v.user_id=u.id and u.email like 'kmisafir%@seed.loungelink.test'
   and not exists (select 1 from requests r where r.visit_id = v.id);

insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number, carrier_code)
select u.id, x.ap::char(3), current_date + 2, x.t1::time, x.t2::time, x.fl,
       public.carrier_from_flight(x.fl)
  from (values
   ('kmisafir1@seed.loungelink.test','IST','12:00','18:00','TK712'),
   ('kmisafir2@seed.loungelink.test','IST','12:00','18:00','AJ1876'),
   ('kmisafir3@seed.loungelink.test','IST','12:00','18:00',null),
   -- 🔴 TEK HESAPTAN 18 SENARYONUN HEPSI GORULSUN.
   -- Ilk halde kmisafir1'in yalniz IST/SAW/ESB seyahati vardi; ilanlar ise
   -- 5 havalimanina dagilmisti (IST 10, ESB 3, SAW 3, ADB 1, DLM 1).
   -- Kesif havalimani filtreli calistigi icin 18'in ancak 10'u gorunuyordu
   -- ve "senaryolarin cogu yok" izlenimi doguyordu. Senaryolari IST'e
   -- toplamak COZUM DEGILDI: kural3 (AJet@IST engel) ile kural4 (AJet@ESB
   -- gecerli) FARKLI havalimaninda olmak ZORUNDA — testin anlami bu.
   -- Dogru cozum: misafire BES havalimaninda da seyahat vermek.
   ('kmisafir1@seed.loungelink.test','SAW','09:00','13:00','PC2034'),
   ('kmisafir1@seed.loungelink.test','ESB','08:00','12:00','AJ2210'),
   ('kmisafir1@seed.loungelink.test','ADB','14:00','19:00','TK2312'),
   ('kmisafir1@seed.loungelink.test','DLM','11:00','15:00','TK2402')
  ) as x(em, ap, t1, t2, fl)
  join users u on u.email = x.em
 where exists (select 1 from airports a where a.code = x.ap);

-- ============================================================
-- 5) SONUÇ TABLOSU — her senaryonun motordan ne aldığı
-- Beklenen sütunu, kuralın ne demesi GEREKTİĞİ. Sapma varsa hata.
-- ============================================================
select pr.name as host, v.airport_code, l.name as salon,
       he.tier, p.code as program,
       (public.lounge_access_decision_v4(a.id, null) ->> 'severity')     as sonuc,
       (public.lounge_access_decision_v4(a.id, null) ->> 'guest_policy') as misafir,
       left(public.lounge_access_decision_v4(a.id, null) ->> 'headline', 60) as baslik
  from availabilities a
  join users u  on u.id = a.host_id
  join profiles pr on pr.user_id = u.id
  left join lounges l on l.id = a.lounge_id
  left join lounge_venues v on v.id = l.venue_id
  left join host_entitlements he on he.user_id = u.id
  left join lounge_programs p on p.id = he.program_id
 where u.email like 'kural%@seed.loungelink.test'
 order by u.email;

-- Ucus bagi: ayni ucustaki misafir icin karar
select pr.name as host, 'TK712 ile' as misafir_ucusu,
       (public.lounge_access_decision_v4(a.id, 'TK712') ->> 'severity') as sonuc,
       (public.lounge_access_decision_v4(a.id, 'TK712') ->> 'fits')     as ucus_uyuyor
  from availabilities a join users u on u.id=a.host_id
  join profiles pr on pr.user_id=u.id
 where u.email in ('kural1@seed.loungelink.test','kural6@seed.loungelink.test');

-- ---- YENI OZELLIKLERIN DOGRULAMASI (130/131/132) ----
select 'seyahat tarzi' as ozellik,
       count(*) filter (where p.travel_style is not null) as dolu,
       count(*) filter (where p.travel_style is null) as bos_birakilan
  from profiles p join users u on u.id = p.user_id
 where u.email like 'k%@seed.loungelink.test';

-- Uyum matrisi: her dal calisiyor mu
select 'social+social' as cift, public.style_fit('social','social') as puan,
       public.style_note('social','social') as not
union all select 'zen+social', public.style_fit('zen','social'), public.style_note('zen','social')
union all select 'foodie+explorer', public.style_fit('foodie','explorer'), public.style_note('foodie','explorer')
union all select 'bos', public.style_fit(null,'social'), public.style_note(null,'social');

-- Olanaklar: ilanlarin bagli oldugu salonlarda olanak var mi
select v.airport_code, left(v.name,28) as salon,
       (select count(*) from jsonb_each(v.amenities)
         where jsonb_typeof(value) = 'boolean') as olanak_sayisi
  from availabilities a
  join users u on u.id = a.host_id
  join lounges l on l.id = a.lounge_id
  join lounge_venues v on v.id = l.venue_id
 where u.email like 'kural%@seed.loungelink.test'
 group by v.airport_code, v.name, v.amenities
 order by olanak_sayisi desc limit 6;

-- Kart danismani: engelli bir ilanda oneri cikiyor mu
select left(a.id::text,8) as ilan,
       (select count(*) from public.card_advice_for_lounge(a.lounge_id)) as kart_onerisi
  from availabilities a join users u on u.id = a.host_id
 where u.email in ('kural3@seed.loungelink.test','kural5@seed.loungelink.test');

-- Kart guven derecesi: host beyanlarinda gorunuyor mu
select split_part(u.email,'@',1) as host, i.name as banka, cp.name as kart, cp.confidence
  from host_entitlements he
  join users u on u.id = he.user_id
  join lounge_card_products cp on cp.id = he.card_product_id
  join lounge_issuers i on i.id = cp.issuer_id
 where u.email like 'kural%@seed.loungelink.test';

-- ---- GIRIS BILGILERI ----
select u.email as giris_epostasi, 'Seed1234!' as sifre, u.role,
       pr.name as gorunen_ad, left(pr.bio, 70) as senaryo
  from users u join profiles pr on pr.user_id = u.id
 where u.email like 'kural%@seed.loungelink.test'
    or u.email like 'kmisafir%@seed.loungelink.test'
 order by u.email;

select 'SEED OK - 18 host + 3 misafir (tarz/kart/olanak dahil) (kmisafir1 BES havalimaninda). Hepsi Seed1234! ile giris yapar.' as sonuc;

-- ============================================================
-- 🔴 v157 KARAR ZİNCİRİ BEKÇİSİ (12 Ağu 2026)
-- 156'nın 12/12'si MOTORU kanıtladı ama app resolve'u doğrudan
-- çağırmıyor — lounge_access_decision çağırıyor ve o TİER-KÖRDÜ
-- (CLPL host + dış hat ilanına fits:true diyordu). Bu blok, kural
-- verisinin KARAR fonksiyonuna gerçekten aktığını her seed
-- kurulumunda doğrular; uyuşmayan senaryo SEED'i DURDURUR.
-- ============================================================
select * from public.decision_chain_check();

-- 🔴 v163 KAPSAM DENETİMİ — kombinatoryal tarama her SEED kurulumunda.
-- "Kural motoru doğru mu?" sorusunun cevabı tek tek senaryolarla değil,
-- TÜM kabul kombinasyonlarının taranmasıyla verilir. Eşik aşılırsa durur.
select * from public.rule_coverage_audit();

do $$
declare r record; n int := 0; d text := '';
begin
  -- 🔴 166: ESKİ BEKÇİ CANLIDA PATLADI VE SEBEBİNİ SÖYLEMEDİ.
  -- İki düzeltme: (a) hangi kontrolün, hangi değerle patladığı hata
  -- mesajına yazılır (b) yalnız 'engine' sınıfı kurulumu DURDURUR —
  -- veri envanteri eksikleri (salonsuz havalimanı gibi) UYARIDIR.
  -- Motor yanlış cevap veriyorsa durmalıyız; katalog eksikse hayır.
  for r in select * from public.rule_coverage_audit() where sonuc not like '✓%' loop
    raise notice 'KAPSAM: % [%] = % (eşik %) → %', r.kontrol, r.sinif, r.deger, r.esik, r.sonuc;
    if r.sinif = 'engine' then
      n := n + 1;
      d := d || r.kontrol || ' = ' || r.deger || ' (eşik ' || r.esik || '); ';
    end if;
  end loop;
  if n > 0 then
    raise exception 'SEED/166: kural motorunda % boşluk — %', n, d;
  end if;
end $$;

do $$
declare n int;
begin
  select count(*) into n from public.decision_chain_check() where sonuc like '✗%';
  if n > 0 then
    raise exception 'SEED/157: % karar senaryosu beklenen sonucu vermedi — kural verisi karara akmıyor', n;
  end if;
end $$;


-- ============================================================
-- TEMIZLIK (gerektiginde tek tek calistir):
--   delete from visits            where user_id in (select id from users where email like 'kmisafir%@seed.loungelink.test');
--   delete from availabilities    where host_id in (select id from users where email like 'kural%@seed.loungelink.test');
--   delete from host_entitlements where user_id in (select id from users where email like 'kural%@seed.loungelink.test');
--   delete from credit_ledger     where reason = 'kural-seed';
--   delete from auth.users        where email like 'kural%@seed.loungelink.test' or email like 'kmisafir%@seed.loungelink.test';
-- ============================================================

-- v166: AKIŞ KAPILARI — "kullanıcı yapamaması gerekeni yapamıyor mu?"
-- Raporlar; SEED'i durdurmaz çünkü bazı senaryolar için uygun veri
-- her ortamda bulunmayabilir ('—' satırları). Kırmızı satır GERÇEK
-- bir açık kapı demektir ve elden geçirilmelidir.
select * from public.flow_gate_test();
