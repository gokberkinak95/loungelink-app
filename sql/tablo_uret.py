# -*- coding: utf-8 -*-
"""
tablo_uret.py — imzalar.json'dan KURULUM_TABLOSU.sql uretir.

Ciktisi Supabase SQL Editor'e yapistirilip TEK sonuc tablosu verir:
her migration dosyasi icin  KOSTU / KOSMADI / BILINMIYOR.

🔴 SUPABASE SQL EDITOR YALNIZ SON SONUC KUMESINI GOSTERIR (20 Agustos
dersi: KURULUM_DURUMU.sql iki `select` iceriyordu, Gokberk yalnizca
ikincisini gordu ve asil tabloyu hic gormedi). Bu yuzden cikti TEK
sorgudur; ozet de ayni tablonun icinde satir olarak yer alir.
"""
import json, os, re
import re as _re

SQL = os.path.dirname(os.path.abspath(__file__))
imzalar = json.load(open(os.path.join(SQL, 'imzalar.json'), encoding='utf-8'))

def q(s):
    return "'" + str(s).replace("'", "''") + "'"

# 🔴 SEED DOSYALARI DA TABLODA. Migration degiller (test verisi) ama
# Gokberk'in "hangilerini calistirdim" sorusu onlari da kapsiyor —
# ve SEED4 calismadiginda kural vitrini bos kaliyor, bu da bir eksik.
# Imzalar OLCULDU: bos veritabanina sirayla kurup fark bakildi.
#   SEED1 → kmisafir1 hesabi          SEED2 → kaynak1 hesabi
#   SEED3 → host1 hesabi (3 ilan)     SEED4 → host1'in ilani 3 → 14
#   SEED5 → guest3 hesabi
SEEDLER = [
    ('SEED_KURAL_SENARYOLARI.sql',  'satir', 'users.email=kmisafir1@seed.loungelink.test'),
    ('SEED2_KAYNAK_SENARYOLARI.sql','satir', 'users.email=kaynak1@seed.loungelink.test'),
    ('SEED3_UCTAN_UCA.sql',         'satir', 'users.email=host1@seed.loungelink.test'),
    ('SEED4_KURAL_VITRINI.sql',     'sayi',
     # ⚠️ TEK tirnak. Ilk yazimda '' yazdim (SQL kacisi zannederek) ama
     # asagidaki q() zaten bir kez kaciriyor; cift kacis `''host1@...''`
     # uretip sorguyu patlatiyordu → SEED4 kurulu oldugu halde "KOSMADI"
     # goruniyordu. Kendi yanlis negatifimi kendi mutasyon testimde
     # yakaladim.
     "availabilities|host_id in (select id from users where email = 'host1@seed.loungelink.test')|10"),
    ('SEED5_BASVURU_AKISLARI.sql',  'satir', 'users.email=guest3@seed.loungelink.test'),
    # 🔴 SEED6 LİSTEDE YOKTU — 5 Eylül'de yazıldı, bu tablo 22 Ağustos'ta
    # üretilmişti ve bir daha üretilmedi. Yani "hangi seed koştu" sorusunun
    # cevabında EN YENİ seed hiç görünmüyordu.
    # 🆕 SINIF: "ÜRETİLMİŞ BİR RAPOR, ÜRETİLDİĞİ GÜNÜN GERÇEĞİDİR —
    # YENİDEN ÜRETİLMEDİKÇE HER GEÇEN GÜN DAHA ÇOK YALAN SÖYLER."
    # İzi kurgu kişilerin e-posta alanı: `@sahne.loungelink.test` yalnız
    # SEED6'da geçiyor (ölçüldü: diğer 5 seed'de 0 satır).
    ('SEED6_TEST_DUNYASI.sql',      'satir', 'users.email=deniz@sahne.loungelink.test'),
    # 🔴 21 EYLUL — SEED7 (test tezgahi). Izi: KABUL EDILMIS davet.
    # Olctum: SEED..SEED6 kurulu bir veritabaninda `invites` tablosunda
    # yalniz `pending` satir var (2 adet); `accepted` YOK. Yani bu iz
    # SEED7'ye ozgu ve baska hicbir seed onu uretmiyor.
    ('SEED7_TEZGAH.sql',            'sayi', "invites|status = 'accepted'|1"),
    # 🔴 23 EYLUL — SEED8 (akis tezgahi). Izi: akis.host hesabi. Olctum:
    # SEED..SEED7'de `akis.` onekli tek bir e-posta yok.
    ('SEED8_AKIS_TEZGAHI.sql',      'satir', 'users.email=akis.host@seed.loungelink.test'),
    ('SEED9_AKIS_GENIS.sql',        'satir', 'users.email=akis.host3@seed.loungelink.test'),
]

satirlar = []
for i, (dosya, tip, ad) in enumerate(imzalar, start=1):
    satirlar.append("  (%d, %s, %s, %s)" % (i, q(dosya), q(tip or ''), q(ad or '')))
for j, (dosya, tip, ad) in enumerate(SEEDLER, start=1):
    satirlar.append("  (%d, %s, %s, %s)" % (900 + j, q(dosya), q(tip), q(ad)))

VALUES = ",\n".join(satirlar)

# 🔴 20 EYLUL — BASLIK SATIRI ELLE YAZILIYORDU VE BAYATLAMISTI.
# Uretilen dosyanin ikinci satiri "(13 Eylul 2026 · 294'e kadar guncel)"
# diyordu; oysa dosya 299'a kadar uretilmisti. Yani tablonun KENDISI
# guncel, KIMLIGI bayatti — ve Gokberk once kimligi okuyor.
#
# 🆕 SINIF: "BIR CIKTININ 'NE KADAR GUNCEL' OLDUGUNU ELLE YAZMAK, ONU
# URETILDIGI ANDA BAYATLATIR — TARIHI DE KAPSAMI DA URETIMDEN TURET."
import datetime as _dt
_son = max((d for d, _t, _a in imzalar if _re.match(r'^\d{3}', d)),
           key=lambda d: (d[:3], d))
BASLIK = "(%s uretildi · %s dosya · son: %s)" % (
    _dt.date.today().isoformat(), len(imzalar) + len(SEEDLER), _son[:3])

TASLAK = r"""-- ============================================================================
-- LoungeLink · KURULUM_TABLOSU.sql        __BASLIK__
--
-- "HANGİ SQL'LERİ ÇALIŞTIRDIM?" — TEK SORGU, TAM LİSTE
--
-- Gökberk: "bana şu ana kadar hangi sql'leri çalıştırdığımı görebildiğim
-- bir sql kodu verir misin? Çalıştırdığım çalıştırmadığım tüm sql'leri
-- versin bana tabloda çalışıyor çalışmıyor diye."
--
-- ════════════════════════════════════════════════════════════════════════
-- ÖNCE DÜRÜST OLMAM GEREKEN ŞEY: BU PROJEDE MİGRATION DEFTERİ YOK
-- ════════════════════════════════════════════════════════════════════════
-- Dosyalar SQL Editor'e elle yapıştırılıyor ve hangisinin koştuğunu
-- söyleyen HİÇBİR KAYIT tutulmamış. Yani "çalıştı mı?" sorusunun cevabını
-- ancak dosyanın BIRAKTIĞI İZDEN çıkarabiliyorum.
--
-- 🔴 VE BAZI DOSYALAR İZ BIRAKMIYOR. Yalnızca daha önce tanımlanmış bir
-- fonksiyonu yeniden yazan dosya, veritabanında ayırt edilebilir bir şey
-- bırakmayabilir. Bunları "ÇALIŞMADI" diye işaretlemek YALAN olurdu.
--
-- 🆕 SINIF: **"TESPİT EDİLEMEYEN ŞEYİ 'YOK' DİYE RAPORLAMAK, ÖLÇMEDEN
-- TEŞHİS VERMEKTİR."** Tabloda üçüncü bir durum var: **BİLİNMİYOR**.
--
-- ÖLÇÜM: __TOPLAM__ dosyanın __IMZALI__ tanesi için ayırt edici imza
-- bulundu (%__YUZDE__). Kalan __TESPITSIZ__ tanesi BİLİNMİYOR olarak
-- raporlanıyor.
--
-- ════════════════════════════════════════════════════════════════════════
-- 13 EYLÜL · BU TABLONUN İKİ KEZ YALAN SÖYLEDİĞİ YER KAPATILDI
-- ════════════════════════════════════════════════════════════════════════
-- 22 Ağustos sürümü bir imzayı "TAM KURULU veritabanında ayakta kalıyor
-- mu" diye seçiyordu. Bu YETMİYOR. 285'e kadar kurulu bir veritabanında
-- denedim ve ÜÇ DOSYA "koştu" dedi — üçü de kurulu değildi:
--   · 286 → izi `discover_people_prebfilter`; o fonksiyon zaten vardı.
--   · 287 → izi `my_plan` gövdesindeki bir satır; eski gövdede de vardı.
--   · 290 → izi "notlarda Türkçe harf var"; öncesinde de 91 satırda vardı.
-- Bir tablonun yapabileceği EN KÖTÜ hata budur: KURULMAMIŞ bir dosyaya
-- "kuruldu" demek. Sen o dosyayı atlarsın, hata günler sonra başka bir
-- yerden çıkar.
--
-- 🆕 SINIF: "BİR İZİN YENİ OLDUĞUNA KAYNAK KODA BAKARAK KARAR VERMEK
-- ÇIKARIMDIR; İZ OLDUĞUNU ANCAK DOSYADAN ÖNCE YOK, SONRA VAR OLDUĞUNU
-- ÖLÇEREK BİLİRSİN."
--
-- Artık her imza 330 dosya TEK TEK kurulurken ÜÇ NOKTADA ölçülüyor:
--     ÖNCE  → yok olmalı   ·  SONRA → var olmalı  ·  SON → hâlâ var olmalı
-- Üçünü birden geçmeyen aday imza sayılmıyor. Bu eleme 222 sahte adayı
-- düşürdü.
--
-- VE BU TABLO ÜÇ DURUMDA SINANDI (`tablo_sina.py`):
--   A · tam kurulu (330 dosya + 6 seed) → 0 «KOSMADI»   ✓
--   B · 285'e kadar kurulu              → 286..294'ün DOKUZU da «KOSMADI»,
--                                         «BURADAN DEVAM ET» = 286        ✓
--   C · bomboş veritabanı               → patlamadan 001'den başlatıyor   ✓
--
-- ════════════════════════════════════════════════════════════════════════
-- NASIL OKUNUR
-- ════════════════════════════════════════════════════════════════════════
--   ✅ KOSTU      → izi veritabanında bulundu
--   ❌ KOSMADI    → izi aranmalıydı, YOK. Bu dosyayı çalıştır.
--   ⬜ BILINMIYOR → ayırt edici iz bırakmıyor; sırası gereği koşmuş olmalı
--
-- 🔴 ASIL BAKACAĞIN SATIR EN ÜSTTE: `>>> BURADAN DEVAM ET <<<`
-- Migration'lar SIRALIDIR. İlk ❌'in olduğu yerden itibaren dosyaları
-- sırayla çalıştır.
--
-- ⚠️ BU DOSYA HİÇBİR ŞEYİ DEĞİŞTİRMEZ — tek yaptığı okumak ve bir
-- DEFTER kurmak (aşağıda). Kaç kez çalıştırırsan çalıştır zararsız.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) BUNDAN SONRASI İÇİN GERÇEK DEFTER
-- ----------------------------------------------------------------------------
-- 🔴 Yukarıdaki tahmin işini bir daha yapmak zorunda kalmayalım diye.
-- Bu tablo bugünden itibaren gerçeği tutar; imza tahmini yalnız GEÇMİŞ
-- için gerekli.
create table if not exists schema_migrations (
  dosya       text primary key,
  kosuldu_at  timestamptz not null default now(),
  kaynak      text default 'tespit'      -- tespit | beyan | dosya
);

-- ----------------------------------------------------------------------------
-- 2) İMZA OKUYUCU
-- ----------------------------------------------------------------------------
-- Her imza tipi için tek bir kontrol. `exception when others then false`
-- BİLEREK: erken bir dosya koşmadıysa aradığımız TABLO bile yoktur ve
-- sorgu patlar — patlaması gereken şey rapor değil, o dosyanın kendisi.
create or replace function public.kurulum_imzasi_var(p_tip text, p_ad text)
returns boolean language plpgsql stable security definer set search_path = public as $kiv$
declare v boolean := false; a text; b text;
begin
  if coalesce(p_tip,'') = '' then return null; end if;
  a := split_part(p_ad, '.', 1);
  b := split_part(p_ad, '.', 2);
  begin
    case p_tip
      when 'tablo' then
        v := to_regclass('public.' || p_ad) is not null;
      when 'tip' then
        v := exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace
                      where n.nspname='public' and t.typname = p_ad);
      when 'enum_degeri' then
        v := exists (select 1 from pg_type t join pg_enum e on e.enumtypid=t.oid
                      where t.typname = a and e.enumlabel = b);
      when 'kolon' then
        v := exists (select 1 from information_schema.columns
                      where table_schema='public' and table_name = a and column_name = b);
      when 'kisit' then
        v := exists (select 1 from pg_constraint where conname = p_ad);
      when 'indeks' then
        v := exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
                      where n.nspname='public' and c.relkind='i' and c.relname = p_ad);
      when 'politika' then
        -- 🔴 `schemaname='public'` KOŞULU 024'Ü GÖRÜNMEZ YAPIYORDU: onun
        -- politikaları `storage.objects` üzerinde. Politika adı zaten
        -- tablo başına benzersiz; şemayı şart koşmak kanıt eklemiyor,
        -- yalnız kapsamı daraltıyordu.
        v := exists (select 1 from pg_policies
                      where tablename = split_part(p_ad,'|',1)
                        and policyname = split_part(p_ad,'|',2));
        if not v then   -- `on storage.objects` yazımında tablo adı `objects`
          v := exists (select 1 from pg_policies
                        where policyname = split_part(p_ad,'|',2)
                          and schemaname = split_part(p_ad,'|',1));
        end if;
      when 'tetikleyici' then
        v := exists (select 1 from pg_trigger where tgname = p_ad and not tgisinternal);
      when 'ayar' then
        v := exists (select 1 from beta_settings where key = p_ad);
      when 'ayar_deger' then
        v := exists (select 1 from beta_settings
                      where key = split_part(p_ad,'=',1)
                        and (value #>> '{}') = split_part(p_ad,'=',2));
      when 'rpc_yuzeyi' then
        v := exists (select 1 from rpc_client_surface where fn_name = p_ad);
      when 'fonksiyon' then
        v := exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where n.nspname='public' and p.proname = p_ad);
      when 'govde' then
        -- 🔴 ÖNCE `like '%…%'` İDİ. LIKE'ta `_` TEK KARAKTER JOKERİDİR ve
        -- bizim izlerimiz `trust_scores ts`, `min_trust` gibi alt çizgi
        -- dolu kod parçaları. Yani iz, olduğundan GEVŞEK eşleşiyordu.
        -- 🆕 SINIF: "JOKER İÇEREN BİR EŞLEŞME, KANIT DEĞİL BENZERLİKTİR."
        v := exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where n.nspname='public' and p.proname = split_part(p_ad,'|',1)
                        and strpos(p.prosrc, split_part(p_ad,'|',2)) > 0);
      when 'desen_yok' then
        -- Biçim: `tablo|kolon|regex` — desen KALMAMIŞ olmalı.
        -- 🔴 290'IN İZİ BUYDU VE İLK SEÇTİĞİM OLUMLU DESEN SAHTEYDİ:
        -- "notlarda Türkçe harf var" dedim; 290'dan ÖNCE de 91 satırda
        -- vardı (ölçüm: 91/262). 290'ın gerçekten yaptığı şey ASCII'ye
        -- düşmüş biçimleri BİTİRMEK: `UCRETSIZ` 17 satırdan 0'a iniyor.
        -- 🆕 SINIF: "BİR DOSYA BİR ŞEYİ SİLİYORSA, İZİ O ŞEYİN VARLIĞI
        -- DEĞİL YOKLUĞUDUR — OLUMLU İZ ARAMAK YANLIŞ YERE BAKMAKTIR."
        -- 🔴 `split_part(p_ad,'|',3)` DESENİ KESİYORDU. Ayraç `|`, regex
        -- alternasyonu da `|` — «(UCRETSIZ|YURTDISI|ANLASMALI)» deseni
        -- «(UCRETSIZ» olarak okunuyordu ve 290 kurulu olduğu hâlde
        -- "koşmadı" görünüyordu. (Aynı sınıf `satir` tipinde de bir kez
        -- ödenmişti: `tablo.kolon=deger` ayrıştırması.)
        -- 🆕 SINIF: "AYRAÇ, AYIRDIĞI VERİNİN ALFABESİNDE GEÇİYORSA
        -- AYRAÇ DEĞİL TUZAKTIR — SON PARÇAYI BÖLME, GERİ KALANI AL."
        execute format('select not exists (select 1 from public.%I where %I ~ %L)',
                       split_part(p_ad,'|',1), split_part(p_ad,'|',2),
                       substr(p_ad, strpos(p_ad,'|')
                                    + strpos(substr(p_ad, strpos(p_ad,'|')+1), '|') + 1)) into v;
      when 'desen' then
        -- Biçim: `tablo|kolon|regex`. Şemayı değil VERİYİ onaran dosyalar
        -- için (290: not metinlerindeki Türkçe harfler geri konuyor).
        -- Ayraç-güvenli: son parça bölünmez (bkz. `desen_yok` notu).
        execute format('select exists (select 1 from public.%I where %I ~ %L)',
                       split_part(p_ad,'|',1), split_part(p_ad,'|',2),
                       substr(p_ad, strpos(p_ad,'|')
                                    + strpos(substr(p_ad, strpos(p_ad,'|')+1), '|') + 1)) into v;
      when 'satir' then
        -- 🔴 Biçim: `tablo.kolon=deger`. İlk yazımda `a`/`b`yi noktadan
        -- ayırıp `b`yi kolon sandım — ama `b` hâlâ `kolon=deger`
        -- taşıyordu ve sorgu boş dönüyordu. Tam kurulu veritabanında
        -- "KOSMADI" diyen yanlış negatiflerden biri buydu.
        execute format('select exists (select 1 from public.%I where %I::text = %L)',
                       split_part(p_ad, '.', 1),
                       split_part(split_part(p_ad, '.', 2), '=', 1),
                       split_part(p_ad, '=', 2)) into v;
      when 'sayi' then
        -- Biçim: `tablo|kosul|asgari`. SEED4 gibi "satır SAYISI artıyor"
        -- diye anlaşılan dosyalar için: tek bir ad aramak yetmez.
        execute format('select (select count(*) from public.%I where %s) >= %s',
                       split_part(p_ad,'|',1), split_part(p_ad,'|',2), split_part(p_ad,'|',3)) into v;
      when 'kural_notu' then
        -- 🔴 290 NOTLARI TÜRKÇELEŞTİRDİ VE İZLERİ BİÇİM DEĞİŞTİRDİ:
        -- «IC HAT» → «İÇ HAT». Not aynı satır, aynı anlam — ama `=`
        -- tutmuyordu. İki taraf da ASCII'ye katlanarak karşılaştırılıyor.
        -- 🆕 SINIF: "VERİYİ İZ SAYIYORSAN, O VERİNİN BİÇİMİNİ SONRADAN
        -- DEĞİŞTİREN HER DOSYA SENİN İZİNİ DE SİLER."
        execute format(
          'select exists (select 1 from public.%I'
          ' where translate(notes, %L, %L) = translate(%L, %L, %L))',
          split_part(p_ad,'|',1),
          'çğıöşüÇĞİÖŞÜ', 'cgiosuCGIOSU',
          split_part(p_ad,'|',2),
          'çğıöşüÇĞİÖŞÜ', 'cgiosuCGIOSU') into v;
      else
        v := null;
    end case;
  exception when others then
    -- Tablo/kolon henüz yoksa "iz yok" demektir — hata değil, cevap.
    v := false;
  end;
  return v;
end $kiv$;

-- `satir` tipinde ad biçimi `tablo.kolon=deger`; yukarıdaki split_part
-- zinciri onu ayırıyor. Ayrı bir yardımcı yazmak yerine tek yerde
-- tutuluyor ki iki kopya bayatlamasın.

-- ----------------------------------------------------------------------------
-- 3) DEFTERİ TESPİTLE DOLDUR (yalnız eksik olanları; var olanı ezmez)
-- ----------------------------------------------------------------------------
insert into schema_migrations (dosya, kaynak)
select z.dosya, 'tespit'
  from (
    values
__VALUES__
  ) as z(sira, dosya, tip, ad)
 where public.kurulum_imzasi_var(z.tip, z.ad) is true
on conflict (dosya) do nothing;

-- ----------------------------------------------------------------------------
-- 4) TEK SORGU · TEK TABLO
-- ----------------------------------------------------------------------------
with imza(sira, dosya, tip, ad) as (
  values
__VALUES__
),
ham as (
  select i.sira, i.dosya, i.tip, i.ad,
         case when i.tip = 'eslikci' then null
              else public.kurulum_imzasi_var(i.tip, i.ad) end as var
    from imza i
),
-- 🔴 `PRE_drop` dosyaları iz BIRAKMAZ, çünkü işleri SİLMEK. Ama her biri
-- bir sonraki ana dosyanın ön koşuludur (024a olmadan 024 → 42P13). Yani
-- 024 koştuysa 024a da koşmuştur. Uydurmuyoruz, EŞİTLİYORUZ.
cozum as (
  select h.sira, h.dosya, h.tip, h.ad,
         case when h.tip = 'eslikci'
              then (select h2.var from ham h2 where h2.dosya = h.ad)
              else h.var end as var
    from ham h
),
ham_etiket as (
  select c.*,
         case
           -- 🔵 EN GÜÇLÜ KANIT: dosya KENDİSİ deftere yazmış (SQL 253'ten
           -- itibaren her migration bunu yapıyor). Tespite gerek yok.
           when exists (select 1 from schema_migrations m
                         where m.dosya = c.dosya and coalesce(m.kaynak,'') <> 'tespit')
                then '✅ KOSTU'
           when c.var is true then '✅ KOSTU'
           when c.var is false then '❌ KOSMADI'
           else '⬜ BILINMIYOR' end as durum
    from cozum c
),
-- 🔴 SIRALI ÇIKARIM — BU BİR ÖLÇÜM DEĞİL, ÇIKARIMDIR VE ÖYLE İŞARETLENİR.
--
-- Migration'lar sırayla çalıştırılır ve çoğu bir öncekine bağlıdır.
-- Bir dosya ayırt edici iz bırakmıyorsa (BİLİNMİYOR) ama KENDİSİNDEN
-- SONRAKİ bir dosyanın koştuğu ÖLÇÜLDÜYSE, o dosya da koşmuş olmalıdır —
-- aksi hâlde sonraki dosya hata verirdi.
--
-- Bu ayrım önemli: "bilinmiyor" 57 dosyaydı ve zincirin ortasındaki bir
-- boşluk "en son nerede kaldım?" sorusunu cevapsız bırakıyordu. Çıkarım
-- o boşlukları kapatıyor ama İDDİA olarak değil, ayrı bir etiketle.
--
-- 🆕 SINIF: "BİR ÇIKARIMI ÖLÇÜMLE AYNI ETİKETLE SUNMAK, ÖLÇÜMÜN
-- İTİBARINI ÇIKARIMA ÖDÜNÇ VERMEKTİR."
son_olculen as (
  select max(sira) as s from ham_etiket where durum = '✅ KOSTU' and sira < 900
),
etiketli as (
  select h.sira, h.dosya, h.tip, h.ad,
         case when h.durum = '⬜ BILINMIYOR'
                   and h.sira < coalesce((select s from son_olculen), -1)
              then '🟩 KOSTU (sirali cikarim)'
              else h.durum end as durum
    from ham_etiket h
),
-- Kaldığın yer: KOSMADI işaretli EN KÜÇÜK sıra.
ilk_eksik as (
  select min(sira) as s from etiketli where durum = '❌ KOSMADI'
),
son_kosan as (
  select max(sira) as s from etiketli where durum like '✅%' or durum like '🟩%'
)
select * from (
  -- ÖZET SATIRLARI (sıra 0 ve negatif → en üstte)
  select -3 as sira,
         '>>> BURADAN DEVAM ET <<<' as dosya,
         coalesce((select e.dosya from etiketli e, ilk_eksik f where e.sira = f.s),
                  'EKSIK YOK — hepsi kurulu görünüyor') as durum,
         '' as tip, '' as imza
  union all
  select -2, '>>> EN SON KOSAN <<<',
         coalesce((select e.dosya from etiketli e, son_kosan g where e.sira = g.s), '-'),
         '', ''
  union all
  select -1, '>>> OZET <<<',
         (select count(*) filter (where durum='✅ KOSTU')::text || ' olculdu · '
               || count(*) filter (where durum like '🟩%')::text || ' sirali cikarim · '
               || count(*) filter (where durum='❌ KOSMADI')::text || ' KOSMADI · '
               || count(*) filter (where durum='⬜ BILINMIYOR')::text || ' hala bilinmiyor · '
               || count(*)::text || ' toplam'
            from etiketli),
         '', ''
  union all
  select 0, '>>> NOT <<<',
         '✅ = olculdu (iz bulundu) · 🟩 = iz yok ama SONRASI kurulu oldugu icin kosmus olmali (CIKARIM) · ⬜ = hala bilinmiyor (yalniz zincirin SONUNDA kalir) · ❌ = izi ARANDI, YOK. Ilk ❌ ten itibaren sirayla calistir.',
         '', ''
  union all
  select e.sira, e.dosya, e.durum, e.tip, e.ad from etiketli e
) t
order by sira;
"""

toplam = len(imzalar)
imzali = sum(1 for _, tip, _ in imzalar if tip)
tespitsiz = toplam - imzali

out = (TASLAK
       .replace('__BASLIK__', BASLIK)
       .replace('__VALUES__', VALUES)
       .replace('__TOPLAM__', str(toplam))
       .replace('__IMZALI__', str(imzali))
       .replace('__TESPITSIZ__', str(tespitsiz))
       .replace('__YUZDE__', str(round(100 * imzali / toplam))))

with open(os.path.join(SQL, 'KURULUM_TABLOSU.sql'), 'w', encoding='utf-8') as f:
    f.write(out)
print(f"KURULUM_TABLOSU.sql yazildi · {toplam} dosya · {imzali} imzali · {tespitsiz} bilinmiyor")
