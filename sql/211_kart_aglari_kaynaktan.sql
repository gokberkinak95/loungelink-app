-- ============================================================
-- 211 · KART AĞLARI — KAYNAKTAN KAPSAM (PP · LoungeKey · DragonPass)
-- 17 Ağustos 2026
--
-- 🔴 GOKBERK HAKLIYDI: "elinde nasıl kaynak yok anlamadım."
-- Bir önceki turda "Priority Pass'in belirli bir salonu kabul edip
-- etmediği kaynağı olan bir olgudur, elimde o kaynak yok" demiştim ve
-- kapsamı genişletmeyi reddetmiştim. Kaynak GELDİ: üç ağın kendi
-- Türkiye sayfalarının ekran görüntüleri (7 Ağustos 2026).
--
-- Bu dosya o kaynağı VERİYE çeviriyor. Üç iş yapıyor ve üçü de
-- ölçümle doğrulandı:
--
--   (1) 190'IN DÖRT YANLIŞ BİRLEŞTİRMESİNİ GERİ ALIYOR
--   (2) Kaynağın söylediği kabul satırlarını YAZIYOR
--   (3) Kaynağın söylemediği kabul satırlarını GERİ ÇEKİYOR
--
-- ============================================================
-- (1) 190 NEYİ YANLIŞ BİRLEŞTİRDİ — VE NEDEN ÖNEMLİ
-- ============================================================
-- SQL 190 salon tekilleştirmesi yaparken adları normalize edip
-- benzer olanları birleştirdi. Dört tanesi YANLIŞTI ve dördü de
-- kaynakla kanıtlandı:
--
--   iGA Pop-up Lounge  → iGA Lounge'a birleştirilmiş
--       Ama PP ve LoungeKey İKİSİ DE "Pop up Lounge"u AYRI kart
--       olarak, AYNI terminalde listeliyor. Farklı salonlar.
--   iGA Sleepod        → iGA Lounge'a birleştirilmiş  (uyku kapsülü!)
--   iGA Shower         → iGA Lounge'a birleştirilmiş  (duş!)
--   Plaza Premium Marmara → Plaza Premium Bosphorus'a birleştirilmiş
--       PP ve LK ikisi de Marmara ile Bosphorus'u AYRI listeliyor.
--
-- SOMUT SONUÇ: misafir "iGA Lounge"a yönlendiriliyor ama host'un
-- kartı aslında Pop-up'ta geçerli olabilir; ya da kişi bir uyku
-- kapsülüne "lounge" diye gönderiliyor. Kapıda yaşanır.
--
-- KÖK SEBEP: ad normalizasyonu KİMLİK DEĞİLDİR. "iGA Pop-up Lounge"
-- ile "iGA Lounge" birbirine benziyor diye aynı yer olmaz. 190'ın
-- doğru birleştirdiği sekiz kayıt (uzun resmî adların kısa adla
-- eşleşmesi) olduğu gibi kalıyor — hepsini geri almıyorum, yalnız
-- kaynağın YANLIŞ dediği dördünü.
-- ============================================================

-- Geri alma: adı temizle, tipini düzelt, yeniden aktif et.
do $$
declare r record; v_n int := 0;
begin
  for r in
    -- 🔴 BIRLESTIRME YONUNU VARSAYMA — 18 Agustos 2026.
    -- Bu liste "Marmara" diyordu ama "Bosphorus" demiyordu, cunku temiz
    -- kurulumda birlestirme HEP Marmara → Bosphorus yonunde oluyor.
    -- Gokberk'in veritabaninda ters yonde olmus ve sonuc:
    --     ERROR: 211: SAW Marmara ya da Bosphorus bulunamadi
    -- Yani geri alma, kurtarmasi gereken kaydi listesinde bulamadi.
    -- Ikisi de yazili artik; hangisi pasifse o geri geliyor.
    --
    -- Ek etiket de genellendi: 190 yalniz "(190 birleştirildi → x)"
    -- yazmiyor, "(birleştirildi x)" ve "(arşiv x)" bicimleri de var
    -- (bu turda 190'a arsivleme eklendi). Uceni de temizliyoruz, yoksa
    -- kayit "Plaza Premium Bosphorus Lounge (arşiv 7a4c)" adiyla
    -- aktif olur ve katalogda oyle gorunurdu.
    select id, name, airport_code,
           regexp_replace(
             regexp_replace(name, '\s*\((190 )?birleştirildi( →)? [0-9a-f]+\)$', ''),
             '\s*\(arşiv [0-9a-f]+\)$', '') as temiz
      from lounge_venues
     where not active
       and (name like '%birleştirildi%' or name like '%arşiv %')
       and (name ilike '%Pop-up%' or name ilike '%Sleepod%'
            or name ilike '%Shower%' or name ilike '%Marmara%'
            or name ilike '%Bosphorus%')
  loop
    -- Temiz ad BASKA bir kayitta duruyorsa dokunma: o salon zaten var,
    -- burasi gercekten fazlalik. (uq_lounge_venue pasif satirlari da
    -- kapsiyor — 190'da bugun tam bu yuzden 23505 aldik.)
    if exists (select 1 from lounge_venues o
                where o.id <> r.id and o.airport_code = r.airport_code
                  and o.name = r.temiz) then
      raise notice '211: "%" zaten var — geri alinmadi', r.temiz;
      continue;
    end if;
    update lounge_venues
       set name = r.temiz,
           active = true,
           venue_kind = case
             when r.temiz ilike '%sleepod%' then 'sleep'
             when r.temiz ilike '%shower%'  then 'shower'
             else 'lounge' end,
           notes = coalesce(notes || ' · ', '')
                   || '211: 190 yanlis birlestirmisti; kart agi kaynaklari ayri salon oldugunu gosterdi.'
     where id = r.id;
    v_n := v_n + 1;
  end loop;
  raise notice '211: % yanlis birlestirme geri alindi', v_n;
end $$;

-- Tip düzeltmesi: spa ve uyku tesisleri "lounge" değildir.
update lounge_venues set venue_kind = 'spa'
 where active and name ilike '%xpresspa%' and coalesce(venue_kind,'') <> 'spa';
update lounge_venues set venue_kind = 'sleep'
 where active and (name ilike '%sleepod%' or name ilike '%kepler%') and coalesce(venue_kind,'') <> 'sleep';
update lounge_venues set venue_kind = 'shower'
 where active and name ilike '%shower%' and coalesce(venue_kind,'') <> 'shower';

-- ============================================================
-- (2) KAYNAK TABLOSU — ekran görüntülerinden okunan HER SATIR
-- ============================================================
-- 🔴 Veriyi doğrudan `lounge_venue_acceptance`e yazmıyorum. Önce
-- KAYNAK olarak duruyor; eşleştirme ayrı bir adım ve eşleşmeyen satır
-- GÖRÜNÜR kalıyor. Doğrudan yazsaydım eşleşmeyenler sessizce
-- kaybolurdu — bu projede en pahalı hata türü.
--
-- ⚠️ `kart_no` NEDEN VAR — İKİNCİ TURDA YAKALANDI:
-- İlk sürümde benzersiz indeks (network, airport, venue_name, scope)
-- idi ve `on conflict do nothing` vardı. DragonPass ADB/ESB/BJV/IST
-- sayfalarında AYNI ADLA İKİ KART var (ör. "Primeclass Lounge" ×2 =
-- iç hat + dış hat; DragonPass hangisi olduğunu yazmıyor). Bu dört
-- çiftin ikinci satırı SESSİZCE düşüyordu: 19 DragonPass satırı
-- yazılıyor sanıyordum, tabloda 15 vardı. Sayıyı ölçene kadar
-- göremedim. `kart_no` sayfadaki kart sırasıdır ve kimliğin parçası.
create table if not exists card_network_source (
  id          uuid primary key default gen_random_uuid(),
  network     text not null,
  airport     text not null,
  venue_name  text not null,
  scope       text not null check (scope in ('domestic','international','bilinmiyor')),
  terminal    text,
  kart_no     int  not null default 1,
  tesis_tipi  text not null default 'lounge'
              check (tesis_tipi in ('lounge','sleep','spa','shower','fasttrack')),
  source_url  text not null,
  checked_at  date not null default date '2026-08-07',
  venue_id    uuid references lounge_venues(id),
  match_note  text,
  created_at  timestamptz not null default now()
);
alter table card_network_source add column if not exists kart_no int not null default 1;
alter table card_network_source add column if not exists tesis_tipi text not null default 'lounge';
drop index if exists uq_cns;
create unique index if not exists uq_cns on card_network_source (network, airport, venue_name, scope, kart_no);

delete from card_network_source;
insert into card_network_source
  (network, airport, venue_name, scope, terminal, kart_no, tesis_tipi, source_url) values
  -- ---------- PRIORITY PASS (9 havalimanı) ----------
  ('PRIORITY_PASS','IST','Pop up Lounge','international','International Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','IST','IGA Lounge','international','International Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','IST','IGA Lounge','domestic','Domestic Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  -- PP'nin IST sayfasında "Deneyimler" bölümü: uyku kapsülü ve spa.
  -- Bunlar salon DEĞİL ama kart ağının kapsamına GİRİYOR; katalogda
  -- da ayrı tesis tipiyle duruyorlar (211 bölüm 1, tip düzeltmesi).
  ('PRIORITY_PASS','IST','IGA Sleepod','international','Dış Hatlar Terminali',1,'sleep','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','IST','XpresSpa','international','Dış Hatlar Terminali',1,'spa','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','DIY','CIP Lounge','bilinmiyor','Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','ESB','Primeclass Lounge','international','International Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','ESB','Primeclass Lounge','domestic','Domestic Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','DLM','CIP lounge International','international','Terminal 2',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','DLM','CIP Lounge Domestic','domestic','Terminal 2',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','ADB','Primeclass Lounge','domestic','Domestic Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','ADB','Primeclass Lounge','international','International Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','BJV','Primeclass Lounge','domestic','Domestic Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','BJV','Primeclass Lounge','international','International Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','AYT','CIP Lounge Domestic','domestic','Domestic Terminal 3',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','AYT','Comfort Lounge','international','International Terminal 2',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','COV','Çelebi Platinum Dış Hatlar Lounge','international','Dış Hatlar Terminali',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','COV','Çelebi Platinum İç Hatlar Lounge','domestic','İç Hatlar Terminali',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  -- 🔴 KENDİ HATAM, ÖLÇÜMLE YAKALANDI: bu üç satırı önce 'IST' diye
  -- yazmıştım. Kaynak JSON'da bu havalimanının `kod` alanı "okunamadi"
  -- (IATA kodu ekran görüntüsünün üst kenarında kırpılmış) ama `ad`
  -- alanı açıkça "Istanbul Sabiha Gokcen Uluslararasi Havalimani"
  -- diyor — yani SAW. Kod okunamadı diye şehir adını görmezden gelip
  -- İstanbul'un ÖBÜR havalimanına yazmışım.
  -- Belirti: PP'nin üç Plaza Premium satırı "aday YOK" ile eşleşmedi,
  -- çünkü IST'te Plaza Premium salonu yok — SAW'da var.
  ('PRIORITY_PASS','SAW','Plaza Premium Lounge - Marmara','international','International Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','SAW','Plaza Premium Bosphorus Lounge','international','International Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),
  ('PRIORITY_PASS','SAW','Plaza Premium Lounge','domestic','Domestic Terminal',1,'lounge','https://www.prioritypass.com/tr-TR/lounges'),

  -- ---------- LOUNGEKEY (9 havalimanı) ----------
  ('LOUNGEKEY','ESB','Primeclass Lounge','international','Dış Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','ESB','Primeclass Lounge','domestic','İç Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','AYT','Elite Lounge','international','Dış Hatlar Terminali 1',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','AYT','CIP Lounge (Dış Hatlar)','international','Dış Hatlar Terminali 2',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','AYT','CIP Lounge (İç Hatlar)','domestic','İç Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','BJV','Primeclass Lounge','international','Dış Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','BJV','Primeclass Lounge','domestic','İç Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','DLM','CIP Lounge Domestic','domestic','Terminal 2',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','DLM','CIP lounge International','international','Terminal 2',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','DIY','CIP Lounge','domestic',null,1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','IST','IGA Lounge','international','Dış Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','IST','Pop up Lounge','international','Dış Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','IST','IGA Lounge','domestic','İç Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','IST','IGA Sleepod','international','Dış Hatlar Terminali',1,'sleep','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','IST','XpresSpa','international','Dış Hatlar Terminali',1,'spa','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','SAW','Kepler Club','international','Dış Hatlar Terminali',1,'sleep','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','SAW','Plaza Premium Bosphorus Lounge','international','Dış Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','SAW','Plaza Premium Lounge - Marmara','international','Dış Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','SAW','Plaza Premium Lounge','domestic','İç Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','ADB','Primeclass Lounge','international','Dış Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','ADB','Primeclass Lounge','domestic','İç Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','COV','Çelebi Platinum Dış Hatlar Lounge','international','Dış Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),
  ('LOUNGEKEY','COV','Çelebi Platinum İç Hatlar Lounge','domestic','İç Hatlar Terminali',1,'lounge','https://www.loungekey.com/tr/lounge-finder'),

  -- ---------- DRAGONPASS (9 havalimanı) ----------
  -- ⚠️ DragonPass sayfalarında IATA KODU ve TERMİNAL BİLGİSİ YOK.
  -- Kodlar havalimanı ADINDAN türetildi (hepsi tekil ve şüphesiz);
  -- kapsam 'bilinmiyor' bırakıldı — uydurmak yerine boş bırakmak.
  ('DRAGONPASS','ADB','Primeclass Lounge','bilinmiyor',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','ADB','Primeclass Lounge','bilinmiyor',null,2,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','AYT','CIP Lounge','bilinmiyor',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','AYT','FTA Comfort Lounge','bilinmiyor',null,2,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','COV','Platinum Lounge (International)','international',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','COV','Platinum Lounge (Domestic)','domestic',null,2,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','DLM','CIP Lounge','bilinmiyor',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','DLM','DLM Lounge','bilinmiyor',null,2,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','DIY','CIP Lounge','bilinmiyor',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','ESB','Primeclass Lounge','bilinmiyor',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','ESB','Primeclass Lounge','bilinmiyor',null,2,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','IST','iGA Lounge','bilinmiyor',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','IST','iGA Pop-up Lounge','bilinmiyor',null,2,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','IST','iGA Lounge','bilinmiyor',null,5,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','IST','iGA Shower','bilinmiyor',null,3,'shower','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','IST','iGA Sleepod','bilinmiyor',null,4,'sleep','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','BJV','Primeclass Lounge','bilinmiyor',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','BJV','Primeclass Lounge','bilinmiyor',null,2,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','SAW','Plaza Premium Marmara Lounge','bilinmiyor',null,1,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','SAW','Plaza Premium Lounge Marmara','bilinmiyor',null,2,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','SAW','Plaza Premium Lounge','bilinmiyor',null,3,'lounge','https://www.dragonpass.com/airport-lounges'),
  ('DRAGONPASS','SAW','Kepler Club','bilinmiyor',null,4,'sleep','https://www.dragonpass.com/airport-lounges');


-- ============================================================
-- (2b) KATALOĞUN KENDİ MÜKERRERİ — KANITLA BİRLEŞTİR, YOKSA KUYRUĞA
-- ============================================================
-- 🔴 GÖKBERK'İN ŞARTI: "duplicate olma, bu kritik."
-- Ölçüm: eşleştirme ilk koşusunda 21 kaynak satırı "N aday — belirsiz"
-- dedi. Sebebi kaynak değil, KATALOĞUN KENDİSİ: aynı havalimanında
-- aynı markadan iki nesil kayıt var —
--   eski nesil: scope='both', terminal İngilizce ("Int. Terminal")
--   yeni nesil: scope ayrık, terminal Türkçe ("Dış Hat")
--
-- 190'ın dersi: benzerlik kimlik değildir, körlemesine birleştirme
-- gerçek salon kaybettirir. Bu yüzden kural ŞU:
--   BİRLEŞTİRME yalnız İKİ BAĞIMSIZ KAYNAK o havalimanında o markanın
--   TAM SAYISINI aynı söylüyorsa ve katalogda FAZLA kayıt varsa yapılır.
--   Diğer bütün şüpheler SİLİNMEZ, İNCELEME KUYRUĞUNA girer.
create table if not exists venue_review_queue (
  id         uuid primary key default gen_random_uuid(),
  venue_id   uuid not null references lounge_venues(id) on delete cascade,
  konu       text not null,
  gerekce    text not null,
  durum      text not null default 'acik' check (durum in ('acik','ayri_salon','birlestirildi','kapali')),
  karar_veren uuid references users(id),
  karar_at   timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists uq_vrq on venue_review_queue (venue_id, konu);
alter table venue_review_queue enable row level security;

-- Birleştirme yardımcısı: bağlı HER ŞEYİ taşır, sonra arşivler.
-- Silmez — bu projede silme yasak; arşiv adı benzersizleştirilir.
create or replace function public.cns_merge_venue(p_kaynak uuid, p_hedef uuid, p_gerekce text)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  if p_kaynak is null or p_hedef is null or p_kaynak = p_hedef then return; end if;

  update lounge_venue_acceptance a set venue_id = p_hedef
   where a.venue_id = p_kaynak
     and not exists (select 1 from lounge_venue_acceptance b
                      where b.venue_id = p_hedef and b.program_id = a.program_id);
  delete from lounge_venue_acceptance where venue_id = p_kaynak;

  update lounge_guest_rules set venue_id = p_hedef where venue_id = p_kaynak;
  update availabilities      set venue_id = p_hedef where venue_id = p_kaynak;
  -- ⚠️ `lounges` (katalog kaydı) taşınırken TEKİLLEŞTİRİLMELİ.
  -- İlk sürümde taşıdım ama tekilleştirmedim: hedef salonun iki aktif
  -- katalog kaydı oldu ve "Bir salona bağlı BİRDEN ÇOK aktif katalog
  -- kaydı" değişmezi kırmızıya döndü. Ürün karşılığı: host, keşifte
  -- AYNI salonu iki kez görürdü — Gökberk'in "duplicate olma" dediği
  -- şeyin tam olarak kendisi, üstelik birleştirme işleminin YAN ETKİSİ.
  update lounges set venue_id = p_hedef where venue_id = p_kaynak;
  update lounges l set active = false,
         name = l.name || ' (211 kopya)'
   where l.venue_id = p_hedef and l.active
     and l.id <> (select x.id from lounges x
                   where x.venue_id = p_hedef and x.active
                   -- `lounges`te created_at YOK (id, airport_code, name,
                   -- terminal, access_types, active, venue_id). Kanoniği
                   -- kullanım sayısı, sonra id belirler.
                   order by (select count(*) from availabilities a where a.lounge_id = x.id) desc, x.id
                   limit 1);
  -- ⚠️ Benzersizlik (venue_id, scope, partner_kind, partner_name);
  -- `partner_id` diye bir sütun YOK. Şemayı okumadan sütun adı
  -- uydurmanın bedeli 42703. Çakışanı taşımıyorum, arşivde kalıyor.
  update lounge_venue_partners p set venue_id = p_hedef
   where p.venue_id = p_kaynak
     and not exists (select 1 from lounge_venue_partners q
                      where q.venue_id = p_hedef and q.scope = p.scope
                        and q.partner_kind = p.partner_kind
                        and q.partner_name = p.partner_name);
  update lounge_venue_partners set active = false where venue_id = p_kaynak;

  update lounge_venues set active = false,
         name  = name || ' (211 birleştirildi → ' || left(p_hedef::text, 8) || ')',
         notes = coalesce(notes || ' · ', '') || '211: ' || p_gerekce
   where id = p_kaynak;
end $fn$;

-- KANITLI TEK BİRLEŞTİRME — ESB Primeclass
-- Priority Pass ESB sayfası: "2 Deneyimler", iki Primeclass kartı
--   (International Terminal + Domestic Terminal).
-- LoungeKey ESB sayfası: "2", iki Primeclass kartı (Dış + İç Hatlar).
-- İki bağımsız ağ AYNI SAYIYI söylüyor: ESB'de iki Primeclass var.
-- Katalogda ÜÇ vardı: "Primeclass Lounge — İç Hat", "— Dış Hat" ve
-- eski nesil "Primeclass CIP Lounge" (scope=both, "Int. Terminal").
-- Üçüncüsü dış hat kaydının kopyası; dış hattakine birleştiriliyor.
do $$
declare v_eski uuid; v_hedef uuid;
begin
  select id into v_eski   from lounge_venues
   where active and airport_code='ESB' and name = 'Primeclass CIP Lounge';
  select id into v_hedef  from lounge_venues
   where active and airport_code='ESB' and name = 'Primeclass Lounge — Dış Hat';
  if v_eski is not null and v_hedef is not null then
    perform public.cns_merge_venue(v_eski, v_hedef,
      'PP ve LoungeKey ESB''de iki Primeclass listeliyor; katalogda uc kayit vardi.');
    raise notice '211: ESB "Primeclass CIP Lounge" → "Primeclass Lounge — Dis Hat" (iki bagimsiz kaynak)';
  end if;
end $$;

-- KANITSIZ ŞÜPHELER — silmiyorum, KUYRUĞA alıyorum ki BO'da karara bağlansın.
insert into venue_review_queue (venue_id, konu, gerekce)
select v.id, 'eski-nesil-kopya-suphesi', g.gerekce
  from (values
    ('IST','Primeclass Lounge',
     'IST iGA tarafindan isletiliyor ve UC kart agi da (PP, LoungeKey, DragonPass) IST sayfasinda Primeclass listelemiyor. Kayit buyuk olasilikla Ataturk donemi artigi. Kanit "listelenmiyor" seviyesinde kaldigi icin BIRLESTIRILMEDI: bir ag ile anlasma olmamasi salonun yok oldugu anlamina gelmez.'),
    ('SAW','Primeclass Lounge',
     'SAW dis hat terminalinde kaynaklarin gosterdigi salonlar Plaza Premium (Bosphorus + Marmara). Uc agin hicbiri SAW''da Primeclass listelemiyor. Ayni gerekceyle birlestirilmedi.'),
    ('AYT','Antalya Airport CIP Lounge',
     'Terminali "T1 International". LoungeKey AYT T1 dis hatta ELITE LOUNGE listeliyor, CIP listelemiyor. Ayni odanin iki adi olabilir; olmayabilir de. Iki bagimsiz kaynak sarti saglanmadi.'),
    ('AYT','Antalya Havalimanı dış hatlar özel yolcu salonu (FTA CIP Salonları)',
     'Bu bir ODA degil, THY kural tablosundaki SEMSIYE ifade ("ucus operasyonunun yapildigi terminaldeki FTA CIP salonlari"). Katalogda artik kesin odalar var (Elite T1, CIP T2, Comfort T2). Semsiye kaydi host''a secim ekraninda belirsizlik yaratiyor.'),
    ('AYT','Primeclass Lounge',
     'AYT icin uc agin hicbiri Primeclass listelemiyor; kayit scope=both ve terminal "Dis Hat". Comfort/Elite/CIP odalari ayri ayri duruyor.'),
    ('ESB','Anatolia Lounge',
     'scope=both, terminal "Dom. Terminal". Ic hat tarafinda ayrica "Primeclass Lounge — Ic Hat" var. Ayri salon olabilir; kaynak yok.'),
    ('SAW','Aeroport Lounge',
     'scope=both, terminal "Dom. Terminal". Ic hat tarafinda ayrica "Plaza Premium Lounge — Ic Hat" var. Ayri salon olabilir; kaynak yok.'),
    ('DLM','DLM Lounge — Terminal 2',
     'DragonPass DLM sayfasi "CIP Lounge" ve "DLM Lounge" diye IKI AYRI kart gosteriyor — yani ayri salon olma ihtimali YUKSEK. Kuyruga yalnizca scope=both oldugu icin alindi: ic mi dis mi belirsiz.')
  ) as g(ap, ad, gerekce)
  join lounge_venues v on v.active and v.airport_code = g.ap and v.name = g.ad
on conflict (venue_id, konu) do update set gerekce = excluded.gerekce;

create or replace function public.venue_review_list()
returns table (id uuid, havalimani text, salon text, konu text, gerekce text, durum text)
language sql stable security definer set search_path = public as $fn$
  select q.id, v.airport_code::text, v.name, q.konu, q.gerekce, q.durum
    from venue_review_queue q join lounge_venues v on v.id = q.venue_id
   order by q.durum, v.airport_code, v.name;
$fn$;
grant execute on function public.venue_review_list() to service_role;


-- ============================================================
-- (3) EŞLEŞTİRME — kaynak satırı hangi salona denk geliyor?
-- ============================================================
-- 🔴 İLK SÜRÜM 59 SATIRIN 21'İNİ EŞLEŞTİREMEDİ. Sebep tek bir kaba
-- kuraldı: "havalimanı + marka + kapsam tek adaya inmezse vazgeç."
-- Ölçünce üç ayrı kök sebep çıktı ve üçü de çözülebilir:
--
--   (i)  `cns_brand` "Turkish Airlines CIP Lounge"u 'cip' sayıyordu.
--        Bir kart ağının "CIP Lounge"u HİÇBİR ZAMAN THY salonu
--        değildir; havayolu salonu rakip adaydı ve her seferinde
--        belirsizlik üretiyordu. Havayolu kontrolü 'cip'ten ÖNCE.
--   (ii) Kapsamı KESİN olan kaynak satırı, scope='both' eski nesil
--        kayıtla yarışıyordu. Kesin kapsam eşleşmesi öncelikli olmalı.
--   (iii)DragonPass kapsam yazmıyor ama KART SAYISI yazıyor. Aynı
--        markadan iki kart + katalogda o markadan tam iki salon =
--        ikisi de o ağa açık demektir. Bu bir tahmin değil, sayım.
--
-- KADEMELER (her kademe bir öncekinden daha zayıf kanıt, sırayla):
--   K1  kapsam AYNI + terminal jetonu AYNI          → tek aday
--   K2  kapsam AYNI                                  → tek aday
--   K3  kapsam AYNI ∪ 'both'                         → tek aday
--   K4  kapsam serbest (kaynak 'bilinmiyor' dediyse) → tek aday
--   K5  SAYI DENKLİĞİ: (ağ,havalimanı,marka) satır sayısı = aday
--       sayısı → hepsi eşleşir (kapsam sırasına göre birebir)
-- Hiçbiri tutmazsa satır EŞLEŞMEZ ve `match_note` sebebi yazar.
create or replace function public.cns_brand(p text)
returns text language sql immutable as $fn$
  select case
    -- ⚠️ HAVAYOLU SALONU EN ÜSTTE. "Turkish Airlines CIP Lounge"
    -- 'cip' değildir; kart ağının CIP'i ile yarışırsa her AYT/DLM/DIY
    -- satırını belirsizleştirir. Bu, ilk koşudaki 21 eşleşmeyenin
    -- en büyük tek sebebiydi.
    when p ilike '%turkish airlines%' or p ilike '%thy %' then 'havayolu-tk'
    when p ilike '%pegasus%'           then 'havayolu-pgs'
    when p ilike '%ajet%'              then 'havayolu-ajet'
    when p ilike '%pop%up%'            then 'pop-up'
    when p ilike '%sleepod%'           then 'sleepod'
    when p ilike '%shower%'            then 'shower'
    when p ilike '%xpresspa%'          then 'xpresspa'
    when p ilike '%kepler%'            then 'kepler'
    when p ilike '%bosphorus%'         then 'plaza-bosphorus'
    when p ilike '%marmara%'           then 'plaza-marmara'
    when p ilike '%plaza premium%'     then 'plaza'
    when p ilike '%primeclass%'        then 'primeclass'
    when p ilike '%çelebi%' or p ilike '%celebi%' or p ilike '%platinum%' then 'celebi-platinum'
    when p ilike '%comfort%'           then 'comfort'
    when p ilike '%elite%'             then 'elite'
    when p ilike '%anatolia%'          then 'anatolia'
    when p ilike '%aeroport%'          then 'aeroport'
    when p ilike '%dlm lounge%'        then 'dlm'
    when p ilike '%iga%'               then 'iga'
    when p ilike '%cip%'               then 'cip'
    else lower(btrim(p)) end;
$fn$;

-- Terminal JETONU: "Dış Hatlar Terminali 2" · "Terminal 2" ·
-- "T1 International" · "Dış Hat (T2)" hepsinden 1/2/3 çıkarır.
-- "Int. Terminal" gibi numarasızlarda null döner (jeton yok = kıyas yok).
create or replace function public.cns_term(p text)
returns text language sql immutable as $fn$
  select (regexp_match(coalesce(p,''), '(?:t|terminal[iı]?)\s*\(?\s*([123])', 'i'))[1];
$fn$;

-- Aday kümesi: aynı havalimanı, aynı marka, aynı TESİS TİPİ.
-- Tesis tipi neden şart: PP'nin "IGA Sleepod"u bir uyku kapsülü;
-- onu "iGA Lounge"a eşlemek 190'ın hatasının aynısı olurdu.
create or replace function public.cns_adaylar(
  p_airport text, p_brand text, p_kind text, p_scopes text[])
returns uuid[] language sql stable as $fn$
  select coalesce(array_agg(v.id order by coalesce(v.scope,'both'), v.id), '{}'::uuid[])
    from lounge_venues v
   where v.active
     and v.airport_code = p_airport
     and public.cns_brand(v.name) = p_brand
     and coalesce(v.venue_kind,'lounge') = p_kind
     and (p_scopes is null or coalesce(v.scope,'both') = any (p_scopes));
$fn$;

do $$
declare
  r record; a uuid[]; b uuid[]; v_marka text; v_kademe text;
  v_esles int := 0; v_bos int := 0;
begin
  -- --- K1..K4: satır satır ---
  for r in select * from card_network_source order by network, airport, kart_no loop
    v_marka := public.cns_brand(r.venue_name);
    v_kademe := null;

    -- K1: kapsam kesin + terminal jetonu aynı
    if r.scope <> 'bilinmiyor' and public.cns_term(r.terminal) is not null then
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, array[r.scope]);
      select coalesce(array_agg(x), '{}'::uuid[]) into b
        from unnest(a) x join lounge_venues v on v.id = x
       where public.cns_term(v.terminal) = public.cns_term(r.terminal);
      if array_length(b,1) = 1 then v_kademe := 'K1 kapsam+terminal'; a := b; end if;
    end if;

    -- K2: kapsam kesin
    if v_kademe is null and r.scope <> 'bilinmiyor' then
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, array[r.scope]);
      if array_length(a,1) = 1 then v_kademe := 'K2 kapsam'; end if;
    end if;

    -- K3: kapsam kesin ∪ 'both'
    if v_kademe is null and r.scope <> 'bilinmiyor' then
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, array[r.scope,'both']);
      if array_length(a,1) = 1 then v_kademe := 'K3 kapsam|both'; end if;
    end if;

    -- K4: kaynak kapsam yazmamış → kapsam serbest
    if v_kademe is null and r.scope = 'bilinmiyor' then
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, null);
      if array_length(a,1) = 1 then v_kademe := 'K4 kapsamsiz'; end if;
    end if;

    if v_kademe is not null then
      update card_network_source set venue_id = a[1], match_note = v_kademe where id = r.id;
      v_esles := v_esles + 1;
    else
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, null);
      -- 🔴 NOTA ADAYLARIN KAPSAMINI DA YAZ. Eskiden yalniz "3 aday"
      -- yaziyordu ve BO'da karar verecek kisi neyin neden eslesmedigini
      -- goremiyordu. En sik sebep kapsam uyusmazligi: kaynak
      -- "international" diyor, katalogdaki tek salon "domestic".
      update card_network_source
         set match_note = format('bekliyor — %s aday (kaynak kapsam=%s · adaylar: %s)',
               coalesce(array_length(a,1),0), coalesce(r.scope,'?'),
               coalesce((select string_agg(v.name || '[' || coalesce(v.scope,'-') || ']', ' , ')
                           from unnest(a) x join lounge_venues v on v.id = x), '-'))
       where id = r.id;
    end if;
  end loop;

  -- --- K5: SAYI DENKLİĞİ (grup grup) ---
  -- DragonPass "Primeclass Lounge ×2" diyor ve katalogda ADB'de tam
  -- iki Primeclass var (iç + dış). Hangisinin hangisi olduğunu
  -- bilmiyoruz ama İKİSİNİN DE o ağa açık olduğunu biliyoruz —
  -- kabul satırı (salon × program) çifti olduğu için bu yeterli.
  for r in
    select s.network, s.airport, public.cns_brand(s.venue_name) marka, s.tesis_tipi,
           count(*)::int n, array_agg(s.id order by s.kart_no) satirlar
      from card_network_source s
     where s.venue_id is null
     group by 1,2,3,4
  loop
    a := public.cns_adaylar(r.airport, r.marka, r.tesis_tipi, null);
    if coalesce(array_length(a,1),0) = r.n and r.n > 1 then
      for i in 1 .. r.n loop
        update card_network_source
           set venue_id = a[i],
               match_note = format('K5 sayi denkligi (%s kart = %s salon)', r.n, r.n)
         where id = (r.satirlar)[i];
      end loop;
      v_esles := v_esles + r.n;
    end if;
  end loop;

  select count(*) into v_bos from card_network_source where venue_id is null;
  raise notice '211: eslestirme → % eslesti, % eslesmedi', v_esles, v_bos;
end $$;

-- ============================================================
-- (4) KABUL SATIRLARINI YAZ
-- ============================================================
-- Kaynak ne diyorsa o. `is_placeholder` false: bu artık tahmin değil,
-- kaynağı olan bir kayıt.
-- ⚠️ MÜKERRER KAYNAK SATIRI — kullanıcının "duplicate olma, bu kritik"
-- dediği şeyin ta kendisi, ve ilk koşuda beni ısırdı:
--
--   ERROR: ON CONFLICT DO UPDATE command cannot affect row a second time
--
-- Ölçüm: SAW · Plaza Premium Marmara için ÜÇ kaynak satırı tek salona
-- düşüyor — DragonPass listesi aynı salonu iki kez yazmış
-- ("Plaza Premium Marmara Lounge" ve "Plaza Premium Lounge Marmara":
-- aynı kelimeler, farklı sıra), üstüne LoungeKey'in satırı geliyor.
-- `uq_lva` (venue_id, program_id) olduğu için iki DragonPass satırı
-- TEK anahtara çarpıyor.
--
-- Hata mesajını susturmak için `do nothing` demek yanlış olurdu: o
-- zaman mükerrer KAYBOLUR ve bir daha görünmez. Doğrusu ikisi:
--   (a) yazarken (venue_id, program_id) üzerinde tekilleştir,
--   (b) çöken satırı `match_note`a YAZ ki mükerrer görünür kalsın.
update card_network_source s
   set match_note = s.match_note || format(' · MUKERRER: ayni salona dusen %s kaynak satiri', k.n)
  from (select venue_id, network, count(*) n
          from card_network_source
         where venue_id is not null
         group by 1,2 having count(*) > 1) k
 where s.venue_id = k.venue_id and s.network = k.network;

insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, source_url, checked_at, active, is_placeholder)
select distinct on (s.venue_id, p.id)
       s.venue_id, p.id, true,
       -- ⚠️ `guest_policy` bir ENUM DEĞİL, kısıtlı TEXT
       -- (`lva_guest_policy_chk`: included|paid|not_allowed|unknown).
       -- Var olmayan bir tipe cast etmek 42704 verir; şemayı okumadan
       -- tip adı uydurmanın bir başka biçimi.
       --
       -- Misafir politikası ağın KENDİ kuralı; salon bazlı değil.
       -- PP/LoungeKey/DragonPass'te misafir ÜCRETLİDİR (196'daki plan
       -- verisi: PP 30 €, DragonPass 36 €).
       'paid',
       s.source_url, s.checked_at, true, false
  from card_network_source s
  join lounge_programs p on p.code = s.network
 where s.venue_id is not null
 order by s.venue_id, p.id, s.checked_at desc, s.id
on conflict (venue_id, program_id) do update set
  accepted     = true,
  source_url   = excluded.source_url,
  checked_at   = excluded.checked_at,
  active       = true,
  is_placeholder = false,
  updated_at   = now();


-- ============================================================
-- (5) KAYNAĞIN SÖYLEMEDİĞİNİ GERİ ÇEK
-- ============================================================
-- 🔴 BU BÖLÜM EKLEMEK KADAR ÖNEMLİ. Ölçtüm ve iki FAZLA İDDİA çıktı:
--
--   PP · AYT · CIP Lounge — Dış Hat (T2)   → kaynakta YOK
--   PP · AYT · Elite Lounge — Dış Hat (T1) → kaynakta YOK
--
-- Priority Pass'in AYT sayfası "2 Deneyimler" diyor ve yalnız
-- CIP Lounge Domestic (T3) ile Comfort Lounge (International T2)
-- listeliyor. Ekran görüntüsünü kendim açıp doğruladım.
--
-- İki satırın da `source_url`i BOŞTU — yani kaynaksız yazılmışlardı.
-- Kaynaksız bir kabul satırı, kullanıcıyı kapıda reddettiren
-- şeydir; ürünün tek cümlesi "kapıda ne olacağını biliyoruz".
--
-- ⚠️ KAPSAM DAR TUTULUYOR: yalnız bu üç ağ ve yalnız kaynağın
-- kapsadığı dokuz havalimanı. Başka havalimanına dokunmuyorum —
-- kaynağım orayı kapsamıyor, "yok" diyemem.
update lounge_venue_acceptance a
   set accepted = false,
       active = false,
       guest_fee_note = coalesce(guest_fee_note || ' · ', '')
         || '211: 7 Agu 2026 kaynagi bu salonu listelemiyor; fazla iddia geri cekildi.',
       updated_at = now()
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id
   and a.venue_id = v.id
   and p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
   and v.airport_code in ('IST','SAW','ESB','ADB','AYT','BJV','DLM','DIY','COV')
   and a.accepted
   and a.active
   and not exists (
     select 1 from card_network_source s
      where s.venue_id = a.venue_id and s.network = p.code);


-- ============================================================
-- (6) MÜKERRER ŞÜPHESİ — SİLMİYORUM, GÖSTERİYORUM
-- ============================================================
-- Katalogda aynı havalimanında aynı marka + aynı kapsamda birden çok
-- aktif salon var (ör. ESB'de "Primeclass CIP Lounge" ve "Primeclass
-- Lounge — Dış Hat"). Bunları SİLMİYORUM: biri gerçekten ayrı bir
-- salon olabilir ve yanlış silmek, var olan bir salonu ürüne
-- kaybettirmek demektir. 190 tam bu yüzden dört hata yaptı.
--
-- Onun yerine ŞÜPHE listesi. Kaynak geldikçe elle karara bağlanır.
create or replace function public.venue_duplicate_suspects()
returns table (havalimani text, marka text, kapsam text, adet int, adlar text)
language sql stable security definer set search_path = public as $fn$
  select v.airport_code::text, public.cns_brand(v.name), coalesce(v.scope,'both')::text,
         count(*)::int, string_agg(v.name, ' | ' order by v.name)
    from lounge_venues v
   where v.active and coalesce(v.venue_kind,'lounge') = 'lounge'
   group by v.airport_code, public.cns_brand(v.name), coalesce(v.scope,'both')
  having count(*) > 1;
$fn$;

grant execute on function public.venue_duplicate_suspects() to service_role;


-- ============================================================
-- (7) KAPSAM RAPORU GÜNCEL Mİ
-- ============================================================
do $$
declare v jsonb;
begin
  v := public.coverage_gaps('Türkiye');
  raise notice '211: kapsam → % / % havalimani · eksik % salon',
    v ->> 'kart_agi_kapsanan', v ->> 'havalimani', v ->> 'eksik_salon';
end $$;



-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) DÖRT BİRLEŞTİRME GERİ ALINDI MI
do $$
declare v_n int;
begin
  select count(*) into v_n from lounge_venues
   where active and (name ilike '%pop-up%' or name ilike '%sleepod%'
                     or name ilike '%shower%' or name ilike '%marmara%')
     and airport_code in ('IST','SAW');
  if v_n < 4 then
    raise exception '211: geri alinan salon sayisi % (4 bekleniyor) — Pop-up/Sleepod/Shower/Marmara', v_n;
  end if;
  if exists (select 1 from lounge_venues where active and name like '%190 birleştirildi%') then
    raise exception '211: aktif bir salonun adinda hala "190 birlestirildi" etiketi var';
  end if;
  raise notice '211: dort yanlis birlestirme geri alindi, adlar temiz';
end $$;

-- 2) POP-UP ve MARMARA GERÇEKTEN AYRI SALON MU (kaynağın iddiası)
-- 🔴 Bu nöbetçi ürünün en somut kullanıcı vaadini koruyor: misafiri
-- yanlış kapıya göndermemek.
do $$
declare v_pop uuid; v_iga uuid; v_mar uuid; v_bos uuid;
begin
  select id into v_pop from lounge_venues where active and airport_code='IST' and name ilike '%pop-up%' limit 1;
  select id into v_iga from lounge_venues where active and airport_code='IST' and name ilike 'iGA Lounge%' and scope='international' limit 1;
  select id into v_mar from lounge_venues where active and airport_code='SAW' and name ilike '%marmara%' limit 1;
  select id into v_bos from lounge_venues where active and airport_code='SAW' and name ilike '%bosphorus%' limit 1;

  if v_pop is null or v_iga is null then raise exception '211: IST Pop-up ya da iGA Lounge bulunamadi'; end if;
  if v_mar is null or v_bos is null then
    -- 🔴 HANGISININ eksik oldugunu ve SAW'da NE VAR oldugunu yaz.
    -- Supabase `raise notice`/`warning` gostermiyor; bilgi exception
    -- mesajinin icinde olmazsa teshis icin ayri bir tur gerekiyor.
    raise exception '211: SAW % bulunamadi. SAW Plaza kayitlari: %',
      case when v_mar is null and v_bos is null then 'Marmara VE Bosphorus'
           when v_mar is null then 'Marmara' else 'Bosphorus' end,
      coalesce((select string_agg(name || ' [aktif=' || active::text || ']', ' || '
                                  order by name)
                  from lounge_venues
                 where airport_code = 'SAW'
                   and (name ilike '%plaza%' or name ilike '%marmara%'
                        or name ilike '%bosphorus%')), '(hic kayit yok)');
  end if;
  if v_pop = v_iga then raise exception '211: Pop-up ile iGA Lounge HALA ayni kayit'; end if;
  if v_mar = v_bos then raise exception '211: Marmara ile Bosphorus HALA ayni kayit'; end if;
  raise notice '211: Pop-up≠iGA ve Marmara≠Bosphorus — dort ayri salon';
end $$;

-- 3) EŞLEŞMEYEN KAYNAK SATIRI KALDI MI
-- Eşleşmeyen satır bir hata değil ama SESSİZ kalmamalı: kaynağın
-- gördüğü bir salonu katalogda bulamıyorsak katalog eksiktir.
-- 🔴 ÖLÇÜM (17 Ağu): 66 kaynak satırının 64'ü eşleşti. Kalan İKİSİ
-- gerçekten belirsiz ve uydurmuyorum:
--   DRAGONPASS · AYT · "CIP Lounge"  → katalogda 4 CIP odası var
--   DRAGONPASS · DLM · "CIP Lounge"  → katalogda 2 CIP odası var
-- DragonPass sayfası terminal de kapsam da yazmıyor; "en olasısını"
-- seçmek yanlış odaya kabul yazmak olurdu. İkisi de BO'da kuyrukta.
-- Bu nöbetçi SAYIYA BAĞLI: 2'yi aşarsa yeni bir regresyon var demektir.
-- 🔴 SABIT ESIK KALDIRILDI — 18 Agustos 2026.
-- Eski hali "2'den fazla eslesmeyen varsa dur" diyordu ve o 2 sayisi
-- BENIM verimden geliyordu. Gokberk'te 12 cikti ve kurulum durdu.
-- Bu, bugun `limit 25` (192) ve `limit 30` (192) ile ayni kusur:
-- kapsami/esigi kendi ortamima gore ayarlamisim. Dosyanin kendi yorumu
-- bile "Bu nobetci SAYIYA BAGLI" diyordu — dogru teshis, yanlis kabul.
--
-- DOGRU AYRIM, sayida degil NITELIKTE:
--   · aday sayisi 0  → salon KATALOGDA HIC YOK. Bu bir veri bosluğu,
--                      kart agi kapsami eksik kalir. DURDURUR.
--   · aday sayisi ≥1 → hangisi oldugu BELIRSIZ. Bu bir KARAR isi,
--                      hata degil. `cns_bekleyenler()` yuzeyinde
--                      birikir, BO'da karara baglanir. DURDURMAZ.
--
-- Neden "tek aday varsa otomatik esles" DEMIYORUM: kaynak "dis hat"
-- diyorsa ve katalogdaki tek salon "ic hat" ise, o ikisini eslestirmek
-- "bu ag bu salonu kabul ediyor" diye OLMAYAN bir veri yazmaktir.
-- Misafiri yanlis kapiya gondermek, eksik veriden pahalidir.
--
-- Sayisal regresyon sinyali kayboluyor mu? Hayir — yeri degisti:
-- pg_run'daki degismezler bekleyen satir sayisini HER KOSUDA basiyor.
-- Ortama gore kalibre edilmis bir sayinin yeri migration degil, harness.
do $$
declare v_n int; v_liste text; v_yok int; v_yok_liste text;
begin
  select count(*), string_agg(network || '/' || airport || '/' || venue_name || ' (' || coalesce(match_note,'?') || ')', ' · ')
    into v_n, v_liste
    from card_network_source where venue_id is null;

  -- Adayi HIC OLMAYANLAR: katalogda o marka/tip hic yok demektir.
  select count(*), string_agg(network || '/' || airport || '/' || venue_name, ' · ')
    into v_yok, v_yok_liste
    from card_network_source s
   where s.venue_id is null
     and coalesce(array_length(
           public.cns_adaylar(s.airport, public.cns_brand(s.venue_name),
                              s.tesis_tipi, null), 1), 0) = 0;

  if v_yok > 0 then
    raise exception '211: % kaynak satirinin katalogda HIC ADAYI YOK — salon eksik: %',
      v_yok, left(v_yok_liste, 500);
  end if;

  if v_n > 0 then
    raise notice '211: % kaynak satiri karara bagli (hepsinin adayi VAR) — cns_bekleyenler() ile BO''da gorunur: %',
      v_n, left(v_liste, 400);
  end if;
  raise notice '211: % / % kaynak satiri eslesti; bekleyen: %',
    (select count(*) from card_network_source where venue_id is not null),
    (select count(*) from card_network_source), coalesce(v_liste,'yok');
end $$;

-- Bekleyen kaynak satırları BO'dan görülebilsin — "bir denetim
-- görünmüyorsa yoktur".
create or replace function public.cns_bekleyenler()
returns table (ag text, havalimani text, salon text, kapsam text, kart_no int,
               tesis_tipi text, durum text, aday_sayisi int, adaylar text)
language sql stable security definer set search_path = public as $fn$
  select s.network, s.airport, s.venue_name, s.scope, s.kart_no, s.tesis_tipi,
         coalesce(s.match_note,'?'),
         coalesce(array_length(public.cns_adaylar(s.airport, public.cns_brand(s.venue_name), s.tesis_tipi, null),1),0),
         coalesce((select string_agg(v.name, ' | ' order by v.name) from lounge_venues v
                    where v.id = any (public.cns_adaylar(s.airport, public.cns_brand(s.venue_name), s.tesis_tipi, null))), '-')
    from card_network_source s
   where s.venue_id is null
   order by s.network, s.airport;
$fn$;
grant execute on function public.cns_bekleyenler() to service_role;

create or replace function public.cns_kapsam_haritasi()
returns table (havalimani text, salon text, tesis_tipi text, kapsam text, aglar text)
language sql stable security definer set search_path = public as $fn$
  select v.airport_code::text, v.name, coalesce(v.venue_kind,'lounge')::text,
         coalesce(v.scope,'both')::text, string_agg(p.code, ', ' order by p.code)
    from lounge_venue_acceptance a
    join lounge_programs p on p.id = a.program_id
    join lounge_venues   v on v.id = a.venue_id
   where a.accepted and a.active
     and p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
   group by 1,2,3,4
   order by 1,2;
$fn$;
grant execute on function public.cns_kapsam_haritasi() to service_role;

-- 4) ÜÇ AĞIN DA KABUL SATIRI VAR MI
-- 🔴 Önceki durumda DRAGONPASS için TEK BİR satır bile yoktu; ölçüm
-- olmasa fark etmezdim.
do $$
declare r record; v_eksik text := '';
begin
  for r in select code from lounge_programs where code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS') loop
    if not exists (
      select 1 from lounge_venue_acceptance a join lounge_programs p on p.id = a.program_id
       where p.code = r.code and a.accepted and a.active
    ) then v_eksik := v_eksik || r.code || ' '; end if;
  end loop;
  if v_eksik <> '' then raise exception '211: su aglarin HIC kabul satiri yok: %', v_eksik; end if;
  raise notice '211: uc agin da kabul satiri var';
end $$;

-- 5) FAZLA İDDİA GERİ ÇEKİLDİ Mİ (mutasyon)
-- Kaynakta olmayan bir kabul satırı uydurup geri çekilmesini
-- kanıtlıyorum; yoksa (5) bölümü hiç çalışmamış olabilir ve
-- bunu ancak canlıda fark ederdim.
do $$
declare v_v uuid; v_p uuid; v_aktif boolean;
begin
  select id into v_p from lounge_programs where code = 'DRAGONPASS';
  -- 4 Eylül: `limit 1` SIRASIZDI — bazen kaynağı OLAN bir AYT salonunu seçiyor,
  -- geri çekilmemesi doğru olduğu hâlde (5) bölümünü "çalışmıyor" sanıyordu
  -- (npm run e2e'de bir koşuda düştü, sonrakinde geçti). Kanıt için kaynağı
  -- olmayan bir salon seçilir; sıra sabit.
  select v.id into v_v from lounge_venues v
   where v.active and v.airport_code = 'AYT' and coalesce(v.venue_kind,'lounge')='lounge'
     and not exists (select 1 from card_network_source s where s.venue_id = v.id and s.network = 'DRAGONPASS')
   order by v.id limit 1;
  if v_v is null then raise notice '211: AYT salonu yok — atlandi'; return; end if;

  insert into lounge_venue_acceptance (venue_id, program_id, accepted, active, is_placeholder)
  values (v_v, v_p, true, true, false)
  on conflict (venue_id, program_id) do update set accepted = true, active = true;

  -- (5)'in sorgusunu tekrar çalıştır
  update lounge_venue_acceptance a set accepted = false, active = false
    from lounge_programs p, lounge_venues v
   where a.program_id = p.id and a.venue_id = v.id
     and p.code in ('PRIORITY_PASS','LOUNGEKEY','DRAGONPASS')
     and v.airport_code in ('IST','SAW','ESB','ADB','AYT','BJV','DLM','DIY','COV')
     and a.accepted and a.active
     and not exists (select 1 from card_network_source s
                      where s.venue_id = a.venue_id and s.network = p.code);

  select a.active into v_aktif from lounge_venue_acceptance a
   where a.venue_id = v_v and a.program_id = v_p;
  if coalesce(v_aktif, false) then
    raise exception '211: kaynaksiz kabul satiri geri CEKILMEDI — (5) bolumu calismiyor';
  end if;
  raise notice '211: kaynaksiz kabul satiri otomatik geri cekiliyor (mutasyonla kanitli)';
end $$;

-- 6) SPA ve UYKU TESİSİ "LOUNGE" SAYILMIYOR
do $$
declare v_n int;
begin
  select count(*) into v_n from lounge_venues
   where active and coalesce(venue_kind,'lounge') = 'lounge'
     and (name ilike '%xpresspa%' or name ilike '%sleepod%' or name ilike '%shower%');
  if v_n > 0 then
    raise exception '211: % spa/uyku/dus tesisi hala "lounge" tipinde', v_n;
  end if;
  raise notice '211: spa, uyku ve dus tesisleri lounge sayilmiyor';
end $$;

-- 7) MÜKERRER ŞÜPHESİ RAPORU ÇALIŞIYOR
do $$
declare v_n int; v_l text;
begin
  select count(*), string_agg(havalimani || '/' || marka, ', ') into v_n, v_l
    from public.venue_duplicate_suspects();
  raise notice '211: mukerrer suphesi % grup → %', coalesce(v_n,0), coalesce(left(v_l,300),'yok');
end $$;

-- 8) KAYNAĞIN KENDİ MÜKERRERLERİ GÖRÜNÜR MÜ
-- 🔴 Kullanıcının "duplicate olma, bu kritik" dediği yer. Kaynak
-- listesinin KENDİSİ aynı salonu iki kez yazabiliyor (DragonPass ·
-- SAW · Plaza Premium Marmara). Yazarken tekilleştiriyoruz ama
-- SUSMUYORUZ: çöken satır `match_note`ta duruyor. Bu nöbetçi o notun
-- gerçekten yazıldığını kanıtlıyor — yoksa tekilleştirme sessiz bir
-- veri kaybına dönüşürdü.
do $$
declare v_carpan int; v_notlu int; v_l text;
begin
  select count(*) into v_carpan from (
    select venue_id, network from card_network_source
     where venue_id is not null group by 1,2 having count(*) > 1) k;

  select count(*), string_agg(network || '/' || airport || '/' || venue_name, ' · ')
    into v_notlu, v_l
    from card_network_source where match_note like '%MUKERRER%';

  if v_carpan > 0 and v_notlu = 0 then
    raise exception '211: % mukerrer kaynak grubu var ama hicbiri match_note''a yazilmamis', v_carpan;
  end if;
  raise notice '211: kaynak mukerreri % grup / % satir isaretli → %',
    v_carpan, v_notlu, coalesce(left(v_l,300),'yok');
end $$;

-- 9) KABUL TABLOSUNDA MÜKERRER SATIR YOK
-- `uq_lva` zaten engelliyor; yine de ölçüyorum, çünkü kısıtın
-- var olduğunu VARSAYMAK ile ölçmek aynı şey değil.
do $$
declare v_n int;
begin
  select count(*) into v_n from (
    select venue_id, program_id from lounge_venue_acceptance
     group by 1,2 having count(*) > 1) k;
  if v_n > 0 then raise exception '211: kabul tablosunda % mukerrer (venue,program) cifti', v_n; end if;
  raise notice '211: kabul tablosunda mukerrer (salon,program) cifti yok';
end $$;

-- ⚠️ SINIR UYGULAMASI DOSYANIN EN SONUNDA — ÜÇÜNCÜ KEZ.
-- Bu turda yine yakalandı: `apply_rpc_surface()`i bölüm (7)'de
-- çağırmıştım, ama nöbetçilerin yanına eklediğim `cns_bekleyenler` ve
-- `cns_kapsam_haritasi` ONDAN SONRA yaratıldı — ikisi de istemciye
-- açık kaldı. Kural tek cümle: sınırı uygulayan çağrı, fonksiyon
-- yaratan HER satırdan sonra gelmeli. Nöbetçi olmasa göremezdim.
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '211: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '211 OK - kart agi kapsami kaynaktan yazildi, dort yanlis birlestirme geri alindi' as sonuc;
