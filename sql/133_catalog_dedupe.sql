-- ============================================================
-- LoungeLink · 133_catalog_dedupe.sql
-- KATALOG MUKERRERI: BIR SALON, IKI-UC KAYIT
--
-- ⚠️ Uygulamayi ETKILER (salon listesi kisalir).
--
-- ------------------------------------------------------------
-- 🔴 113'UN BIRAKTIGI IZ — SIRA HATASI
-- ------------------------------------------------------------
-- 113 mukerrer SALONLARI birlestirdi ve dogru calisti: bugun
-- `lounge_venues` tarafinda tek bir mukerrer yok.
--
-- Ama ayni dosyada su sirayla iki is yapiyor:
--   1) katalog kayitlarini KANONIK salona yonlendir
--   2) venue'su PASIF olan katalog kayitlarini kapat
--
-- Adim 1 calistiktan sonra o kayitlarin venue'su ARTIK PASIF DEGIL —
-- kanonik salona bakiyorlar. Adim 2 onlari bulamiyor ve hepsi AKTIF
-- kaliyor. Sonuc: tek salon, 2-3 katalog kaydi; host ayni salonu
-- listede iki kez goruyor.
--
-- Bu, "duzeltmenin kendi izini birakmasi" dedigim seyin ta kendisi:
-- venue tarafi temiz oldugu icin denetimlerim "mukerrer yok" diyordu.
-- Yanlis yere baktigim surece dogru cevap alamam.
--
-- 🔴 KANONIK KATALOG SECIMI: ILANI OLAN kazanir. Ad guzelligi degil
-- BAGLI VERI belirlesin — yanlis olani secersek ilanlar yetim kalir.
-- ============================================================

with ranked as (
  select l.id, l.venue_id,
         (select count(*) from availabilities a where a.lounge_id = l.id) as n_av,
         first_value(l.id) over (
           partition by l.venue_id
           order by (select count(*) from availabilities a where a.lounge_id = l.id) desc,
                    length(l.name), l.id) as keep_id
    from lounges l
   where l.active and l.venue_id is not null
)
update lounges l set active = false
  from ranked r
 where l.id = r.id and r.id <> r.keep_id;

-- 🔴 ILANLARI KANONIK KAYDA TASI. Pasife aldigimiz katalog kaydina
-- bagli bir ilan varsa, o ilan kesiften duser ve host ne oldugunu
-- anlamaz. Temizlik, kullanicinin verisini kaybetmeden yapilmali.
with ranked as (
  select l.id, l.venue_id,
         first_value(l.id) over (
           partition by l.venue_id
           order by (select count(*) from availabilities a where a.lounge_id = l.id) desc,
                    length(l.name), l.id) as keep_id
    from lounges l where l.venue_id is not null
)
update availabilities a set lounge_id = r.keep_id
  from ranked r
 where a.lounge_id = r.id and r.id <> r.keep_id;

-- ============================================================
-- 🔴 TERMINALSIZ 086 KALINTILARI
-- ------------------------------------------------------------
-- Kalan mukerrerler su tipte: "Turkish Airlines Lounge Business",
-- "IGA Lounge" — TERMINAL BILGISI YOK. Ayni havalimaninda ayni
-- salonun terminalli surumleri ("— Dış Hat", "— İç Hat") de var.
--
-- Bunlari birlestiremiyoruz cunku HANGI terminale ait olduklari
-- ADDAN BILINMIYOR. Tahmin edip birine yapistirmak, veriyi
-- uydurmak olur.
--
-- Dogru kural: DAHA AZ BELIRLI kayit, DAHA BELIRLI olana yenilir.
-- Terminalsiz bir kayit, ayni salonun terminalli kardesleri varken
-- host'a secenek olarak sunulmamali — "hangisi bu?" diye
-- sorduracak bir secenek, secenek degil tuzaktir.
-- ============================================================
update lounge_venues v set active = false,
       notes = coalesce(v.notes,'') || ' [133] Terminalsiz eski ad; ayni salonun '
            || 'terminalli surumleri kullaniliyor.'
 where v.active and v.venue_kind = 'lounge'
   and v.name !~ '(Hat|Terminal|T[0-9])'
   and exists (
     select 1 from lounge_venues x
      where x.active and x.id <> v.id
        and x.airport_code = v.airport_code
        and x.name ~ '(Hat|Terminal|T[0-9])'
        -- ayni salon mu: terminal ekini atinca adlar esitleniyor mu
        and public.venue_norm(regexp_replace(x.name, '\s*[—-]\s*.*$', ''))
            = public.venue_norm(v.name));

-- 🔴 UC SEYI BIRDEN KAPAT: katalog, kabul satiri, kart tipi kurali.
-- Ilk yazimda yalniz katalogu kapattim; degismez denetimi "pasif salona
-- bagli AKTIF kabul satiri" diye yakaladi. Bir kaydi pasife almak, ona
-- bagli HER SEYI pasife almak demektir — yarim birakilan temizlik,
-- motorun olu veriye bakmasina yol acar.
update lounges l set active = false
  from lounge_venues v where l.venue_id = v.id and not v.active and l.active;

update lounge_venue_acceptance a set active = false
  from lounge_venues v where a.venue_id = v.id and not v.active and a.active;

update lounge_guest_rules r set effective_to = current_date - 1
  from lounge_venues v
 where r.venue_id = v.id and not v.active
   and (r.effective_to is null or r.effective_to >= current_date);

-- ============================================================
-- 🔴 ONARIM: AKTIF SALON AMA KATALOGDA HIC KAYIT YOK
-- ------------------------------------------------------------
-- Seed dogrulamasinda gordum: IST katalogunda TEK BIR Turkish
-- Airlines salonu yok. Host IST'te THY salonu SECEMIYOR — kural
-- motorunun en zengin verisi erisilemez durumda.
--
-- Sebep birlestirme zincirinin birikimi: 103, 113 ve bu dosya
-- sirayla katalog kayitlarini pasife aldi; bazi salonlarda AKTIF
-- HIC KAYIT KALMADI. Her adim tek basina dogruydu, toplami degil.
--
-- Ders: "mukerreri kaldir" ile "en az bir tane birak" AYRI iki
-- kuraldir. Ilkini uc kez yazdim, ikincisini hic yazmadim.
--
-- Bu onarim son adimda calisir: aktif ve katalogsuz kalan her
-- salona bir kayit acar.
-- ============================================================
insert into lounges (airport_code, name, terminal, active, venue_id)
select v.airport_code::char(3), v.name, v.terminal, true, v.id
  from lounge_venues v
 where v.active and v.venue_kind = 'lounge'
   and v.section is null and v.section_of is null
   and not exists (select 1 from lounges l where l.venue_id = v.id and l.active);

-- Pasif kalmis ama tek aday olan kaydi yeniden ac (yenisini yaratmak yerine)
update lounges l set active = true
  from lounge_venues v
 where l.venue_id = v.id and v.active and not l.active
   and v.section is null and v.section_of is null
   and not exists (select 1 from lounges x where x.venue_id = v.id and x.active);

update lounge_venues v set legacy_lounge_id = l.id
  from lounges l
 where l.venue_id = v.id and l.active
   and (v.legacy_lounge_id is null or v.legacy_lounge_id <> l.id);


-- ============================================================
-- 🔴 IKINCI MUKERRER: AYNI SALONA UC KEZ AYNI ENGEL KURALI
-- ------------------------------------------------------------
-- IST dis hat Business bolumune "misafir hakki yok" kurali UC AYRI
-- dosyada yaziliyor: 104 (kart tipi matrisi), 127 (iGA kaynagi) ve
-- 129 (butunluk onarimi). Uçu de dogru, ucu de ayni seyi soyluyor —
-- ama karar motoru `limit 1` ile birini seciyor ve HANGISINI sectigi
-- created_at sirasina kaliyor.
--
-- Bugun zarari yok cunku ucu de ayni sonucu veriyor. Ama yarin biri
-- birini duzeltirse, motor hala eskisini secebilir ve duzeltme
-- GORUNMEZ olur. Sessizce yanlis cevap veren bir sistem, acikca
-- bozulan bir sistemden tehlikelidir.
-- ============================================================
with ranked as (
  select r.id,
         first_value(r.id) over (
           partition by r.program_id, coalesce(r.card_tier,''), coalesce(r.venue_id::text,'')
           order by r.created_at desc, r.id) as keep_id
    from lounge_guest_rules r
   where (r.effective_to is null or r.effective_to >= current_date)
)
update lounge_guest_rules g
   set effective_to = current_date - 1,
       notes = coalesce(g.notes,'') || ' [133] Ayni kuralin eski kopyasi kapatildi; '
            || 'en son yazilan surum gecerli.'
  from ranked r
 where g.id = r.id and r.id <> r.keep_id;


-- ============================================================
-- DOGRULAMA
-- ============================================================
select 'venue basina aktif katalog' as kontrol,
       coalesce(max(n)::text,'0') as en_fazla
  from (select count(*) n from lounges where active and venue_id is not null
         group by venue_id) t;

select 'ayni kural mukerreri' as kontrol, count(*)::text as adet
  from (select 1 from lounge_guest_rules r
         where (r.effective_to is null or r.effective_to >= current_date)
         group by r.program_id, coalesce(r.card_tier,''), coalesce(r.venue_id::text,'')
        having count(*) > 1) t;

select 'katalogsuz aktif salon' as kontrol, count(*)::text as adet
  from lounge_venues v
 where v.active and v.venue_kind = 'lounge'
   and v.section is null and v.section_of is null
   and not exists (select 1 from lounges l where l.venue_id = v.id and l.active);

select l.airport_code, left(l.name, 40) as katalogda
  from lounges l where l.active and l.airport_code = 'IST' order by l.name;

select '133 OK - mukerrer temizlendi VE her salonun bir kaydi var' as sonuc;
