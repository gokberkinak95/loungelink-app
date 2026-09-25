-- ============================================================================
-- 270b — O 4 İLAN NEDEN GEÇİYOR?   (SALT OKUNUR)
--
-- 🔴 ELDEKİ ÇELİŞKİ
-- 270a şunu döndürdü:
--     host: burak.k@seed…  is_staff: true  is_visible(): false
--     tarih: 2026-08-05 / 08-09 / 08-10 / 08-13     (BUGÜN 29 AĞUSTOS)
--
-- `discover_availabilities_base` içinde `and a.avail_date >= current_date`
-- var. Geçmiş tarihli bir ilan oradan GEÇEMEZ. Geçtiğine göre üç ihtimal:
--
--   (A) `discover_availabilities` AŞIRI YÜKLENMİŞ — argümansız çağrı,
--       kapıları olmayan ESKİ bir sürüme gidiyor. (261'de `create_availability`
--       ile birebir aynısını yaşadık: 215 sarmalayıcı koymuş, 055 eski
--       imzayı geri getirmişti.)
--   (B) Zincirdeki bir ara fonksiyon (`_ham` / `_prerank`) `_base`i
--       atlıyor ya da kendi kaynağından okuyor.
--   (C) 270a'nın kendi ölçümü tutarsız (aşağıda §0'da itiraf var).
--
-- 🆕 SINIF: "BİRBİRİYLE ÇELİŞEN İKİ ÖLÇÜM VARSA, ÜÇÜNCÜSÜNÜ ARAMA —
-- ÖLÇÜM ALETİNİN KENDİSİNİ SORGULA."
--
-- ----------------------------------------------------------------------------
-- §0 — ÖNCE KENDİ HATAMI SÖYLEYEYİM
--
-- 270a'da `is_visible()` sütunu YANILTICI. Sızan satırları geçici tabloya
-- yazarken bakan kişiyi "normal kullanıcı" yapıyordum; ama son SELECT
-- çalışırken o ayarı GERİ ALMIŞTIM, yani `is_visible()` NULL bakanla
-- hesaplandı. İki farklı koşulda ölçülmüş iki değeri yan yana koyup
-- karşılaştırılabilirmiş gibi gösterdim.
--
-- 🆕 SINIF: "İKİ SÜTUNU YAN YANA KOYMAK, İKİSİNİN AYNI KOŞULDA ÖLÇÜLDÜĞÜ
-- ANLAMINA GELMEZ — RAPOR, ÖLÇÜM KOŞULUNU DA TAŞIMALIDIR."
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════
-- §1 — AŞIRI YÜKLEME VAR MI? (en olası sebep)
-- ════════════════════════════════════════════════════════════════════════
select
  p.oid::regprocedure::text                       as "imza",
  pg_get_function_arguments(p.oid)                as "parametreler",
  length(pg_get_functiondef(p.oid))               as "gövde uzunluğu",
  (pg_get_functiondef(p.oid) like '%avail_date >= current_date%')  as "tarih kapısı var",
  (pg_get_functiondef(p.oid) like '%is_staff%')                    as "staff kapısı var",
  (pg_get_functiondef(p.oid) like '%is_visible%')                  as "is_visible çağırıyor"
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname like 'discover_availabilities%'
order by p.proname, pg_get_function_arguments(p.oid);


-- ════════════════════════════════════════════════════════════════════════
-- §2 — O 4 İLANI KAPI KAPI SINA
--
-- Her sütun `discover_availabilities_base`in WHERE'indeki BİR koşul.
-- `false` olan sütun, o ilanın oradan geçemeyeceğini söyler. Hepsi
-- `false` çıkarsa ilan o fonksiyondan GELMİYOR demektir — yani §1'deki
-- aşırı yükleme ihtimali doğrulanır.
-- ════════════════════════════════════════════════════════════════════════
select
  u.email                                       as "host",
  a.avail_date                                  as "tarih",
  (a.avail_date >= current_date)                as "tarih ✓",
  a.active                                      as "aktif ✓",
  (u.role = 'host'
    or exists (select 1 from host_applications ha
                where ha.user_id=a.host_id and ha.status='approved'))
                                                as "rol ✓",
  (coalesce(u.is_staff,false) = false)          as "staff değil ✓",
  coalesce(p.show_on_discovery,true)            as "keşifte göster ✓",
  public.is_visible(a.host_id)                  as "is_visible ✓",
  (coalesce(a.visibility,'Public') <> 'Hidden') as "gizli değil ✓",
  a.id                                          as "ilan id"
from availabilities a
join users u    on u.id = a.host_id
join profiles p on p.user_id = a.host_id
where a.id in (
  '8ea6c495-a7cb-4ce0-abe5-a4aecaaa853b',
  'd770cc1a-e652-4fed-a967-a413bbbd6629',
  '8bf70984-0368-4236-b230-a4d3e2b72d05',
  '197a86aa-6c31-4b46-883b-cd9c6f6a3536'
)
order by a.avail_date;


-- ════════════════════════════════════════════════════════════════════════
-- §3 — SON KONTROL: bu 4 ilan GERÇEKTEN discovery'den mi geliyor?
--
-- Bakan kişiyi normal kullanıcı yapıp doğrudan soruyoruz. `evet` çıkarsa
-- sızıntı gerçek ve §1/§2 sebebi gösterir; `hayir` çıkarsa 270a'nın
-- geçici tablosu bayat bir durumdan üretilmiş demektir.
-- ════════════════════════════════════════════════════════════════════════
do $s270b$
declare v_normal uuid; v_eski text; n int;
begin
  v_eski := current_setting('request.jwt.claims', true);
  select id into v_normal from users u
   where u.deleted_at is null and not coalesce(u.is_staff,false)
     and not exists (select 1 from availabilities a where a.host_id=u.id and a.active)
   limit 1;
  perform set_config('request.jwt.claims',
    json_build_object('sub', coalesce(v_normal::text,''))::text, true);

  select count(*) into n from public.discover_availabilities() d
   where d.id in ('8ea6c495-a7cb-4ce0-abe5-a4aecaaa853b',
                  'd770cc1a-e652-4fed-a967-a413bbbd6629',
                  '8bf70984-0368-4236-b230-a4d3e2b72d05',
                  '197a86aa-6c31-4b46-883b-cd9c6f6a3536');

  perform set_config('request.jwt.claims', coalesce(v_eski,''), true);
  raise notice '270b §3: bu 4 ilandan % tanesi SU AN normal kullaniciya gorunuyor.', n;
  if n = 0 then
    raise notice '270b §3: sizinti YOK — 270a bayat bir olcumdu.';
  end if;
end $s270b$;


-- ⚠️ SONUÇ TABLOSU — §3'ün cevabı `raise notice`ta kalıyordu, görünmüyordu.
-- (Kesin karar için 270c_KARAR.sql daha okunaklı; bu satır dosyanın kendi
--  kuralına uyması için.)
select 'Şüpheli 4 ilanın kaçı ŞU AN görünüyor' as "soru",
       (select count(*) from public.discover_availabilities() d
         where d.id in ('8ea6c495-a7cb-4ce0-abe5-a4aecaaa853b',
                        'd770cc1a-e652-4fed-a967-a413bbbd6629',
                        '8bf70984-0368-4236-b230-a4d3e2b72d05',
                        '197a86aa-6c31-4b46-883b-cd9c6f6a3536'))::text as "cevap";
