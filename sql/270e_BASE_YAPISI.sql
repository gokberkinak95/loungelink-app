-- ============================================================================
-- 270e — `discover_availabilities_base` NEDEN GEÇİRİYOR?   (SALT OKUNUR)
--
-- 🔴 270d KESİNLEŞTİRDİ: sızıntı EN ALT katmanda, `_base`in kendisinde
-- başlıyor. Kapılar metinde var ama satırları elemiyorlar.
--
-- ⚠️ VE 270d'nin "taşıdığı kapılar" SÜTUNU GÜVENİLMEZ: `pg_get_functiondef`
-- çıktısında düz metin araması yapıyor, YORUMLARI AYIKLAMIYOR. Yani
-- `-- and a.active = true` diye YORUMA ALINMIŞ bir satır da "kapı var"
-- diye sayılır. Bu turda aynı hatayı iki kez daha yaptım (send_otp'un
-- yorumundaki `pg_net`, ikon denetiminin kendi doküman satırları).
--
-- 🆕 SINIF: "KAYNAK METNİNDE DESEN ARAYAN HER DENETİM, YORUMLARI
-- ÇIKARMADAN ÇALIŞIRSA, DEVRE DIŞI BIRAKILMIŞ BİR KORUMAYI ÇALIŞIYOR
-- SANAR — VE EN ÇOK TAM O DURUMDA YANILIR."
--
-- Bu dosya gövdeyi YORUMSUZ okuyup üç şeyi gösteriyor:
--   §1  Kapılar GERÇEKTEN etkin mi (yorumda mı, kodda mı)
--   §2  Kaç ayrı satır kaynağı var (UNION / ikinci `from availabilities`)
--   §3  İlgili satırların kendisi — okunacak metin
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════
-- §1 + §2 — YAPI ÖZETİ (yorumlar ayıklanmış hâlde)
-- ════════════════════════════════════════════════════════════════════════
with g as (
  select pg_get_functiondef(p.oid) as ham
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'discover_availabilities_base'
   limit 1
),
temiz as (
  -- Blok yorumu ve satır yorumu ÇIKARILIYOR. Konum korunsun diye
  -- boşlukla değiştiriliyor.
  select regexp_replace(
           regexp_replace(ham, '/\*.*?\*/', ' ', 'gs'),
           '--[^\n]*', ' ', 'g') as kod,
         ham
    from g
)
select
  (length(ham) - length(kod))                                     as "yorum karakteri",
  (select count(*) from regexp_matches(kod, 'from\s+availabilities', 'gi')) as "kaç ayrı `from availabilities`",
  (select count(*) from regexp_matches(kod, '\munion\M', 'gi'))   as "UNION sayısı",
  (kod ~* 'a\.active\s*=\s*true')                                 as "aktif kapısı ETKİN",
  (kod ~* 'avail_date\s*>=\s*current_date')                       as "tarih kapısı ETKİN",
  (kod ~* 'is_staff')                                             as "staff kapısı ETKİN",
  (kod ~* 'is_visible')                                           as "is_visible ETKİN",
  length(kod)                                                     as "kod uzunluğu"
from temiz;


-- ════════════════════════════════════════════════════════════════════════
-- §3 — İLGİLİ SATIRLAR: gövdeden okunacak metin
--
-- Kapı satırlarının BAŞINDA `--` varsa yorumdadır. `union` görürsen
-- ikinci bir satır kaynağı var ve kapılar yalnız birine uygulanıyordur.
-- ════════════════════════════════════════════════════════════════════════
with g as (
  select pg_get_functiondef(p.oid) as ham
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'discover_availabilities_base'
   limit 1
),
satirlar as (
  select row_number() over () as no, s as metin
    from g, regexp_split_to_table(replace(g.ham, E'\\n', E'\n'), E'\n') s
)
select no as "satır", btrim(metin) as "içerik"
  from satirlar
 where metin ~* '(from\s+availabilities|union|a\.active|avail_date\s*>=|is_staff|is_visible|where)'
 order by no;
