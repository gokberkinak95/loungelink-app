-- ============================================================================
-- 260 — SUNUCU TARAFI TOPLAMLAR (mutabakat · havayolu/salon kullanımı)
--
-- 🔴 NEDEN
-- 259 indeksleri `order by ... limit N` sayfalarını hızlandırdı. Ama üç sayfa
-- ondan da beter bir şey yapıyordu: SAYMAK ve TOPLAMAK için tabloyu olduğu
-- gibi indirip JavaScript'te döngüye sokuyorlardı.
--
--   app/finance         → `credit_ledger` tablosunun TAMAMI (iki kez!) +
--                          `requests` (status=pending, sınırsız)
--                          … yalnız 6 sayı üretmek için
--   app/manage/carriers → `availabilities` tablosunun TAMAMI
--                          … yalnız "bu havayolu kaç ilanda geçiyor" için
--   app/manage/lounges  → `availabilities` tablosunun TAMAMI
--                          … yalnız salon/havalimanı başına ilan sayısı için
--
-- Bunlar indeksle çözülmez: sorun satırların SIRALANMASI değil, hepsinin
-- 345 ms'lik bir bağlantıdan GEÇMESİ. 5.000 satırken fark edilmez,
-- 100.000 satırken sayfa açılmaz.
--
-- 🆕 SINIF: "TOPLAMAYI VERİTABANINDA YAPMAZSAN, TOPLAMAK İÇİN TÜM VERİYİ
-- AĞDAN GEÇİRİRSİN — VE O BEDELİ HER SAYFA AÇILIŞINDA ÖDERSİN."
--
-- ⚠️ BU DOSYA GÜVENLİ: yalnız fonksiyon oluşturur/değiştirir. Tablolara
-- dokunmaz, veri değiştirmez, iki kez çalıştırılabilir.
--
-- ⚠️ SIRA ÖNEMLİ DEĞİL AMA BAĞIMLILIK VAR: BO v1.90 bu fonksiyonlar
-- YOKKEN DE ÇALIŞIR — sayfalar RPC hata verirse eski (yavaş) yola düşüyor.
-- Yani bu SQL'i çalıştırana kadar hiçbir şey kırılmaz, yalnız hızlanmaz.
-- ============================================================================

-- ── 1) MUTABAKAT ÖZETİ ──────────────────────────────────────────────────
-- Altı sayı, tek gidiş-dönüş, sıfır satır transferi.
create or replace function bo_finance_ozet()
returns table (
  hold_adet     bigint,
  acik_istek    bigint,
  iade_adet     bigint,
  kapama_adet   bigint,
  verilen_kredi bigint,
  harcanan      bigint
)
language sql
security definer
set search_path = public
as $$
  select
    (select count(*) from credit_ledger where reason = 'request_hold'),
    (select count(*) from requests       where status = 'pending'),
    (select count(*) from credit_ledger where reason = 'request_refund'),
    (select count(*) from credit_ledger where reason = 'request_capture'),
    (select coalesce(sum(delta), 0)      from credit_ledger where delta > 0),
    (select coalesce(sum(abs(delta)), 0) from credit_ledger where delta < 0);
$$;

-- ── 2) HAVAYOLU KULLANIMI ───────────────────────────────────────────────
-- "Bu havayolu kaç ilanda geçiyor?" — grup sayısı kadar satır döner,
-- ilan sayısı kadar değil.
create or replace function bo_carrier_kullanim()
returns table (carrier_code text, adet bigint)
language sql
security definer
set search_path = public
as $$
  select a.carrier_code::text, count(*)
  from availabilities a
  where a.carrier_code is not null
  group by a.carrier_code;
$$;

-- ── 3) SALON / HAVALİMANI KULLANIMI ─────────────────────────────────────
-- `lounge_id` null olan ilanlar da havalimanı sayısına giriyor — sayfadaki
-- eski JavaScript mantığı da tam olarak böyle davranıyordu; sayılar
-- DEĞİŞMEMELİ, yalnız nerede hesaplandıkları değişiyor.
create or replace function bo_lounge_kullanim()
returns table (airport_code text, lounge_id uuid, adet bigint)
language sql
security definer
set search_path = public
as $$
  select a.airport_code::text, a.lounge_id, count(*)
  from availabilities a
  group by a.airport_code, a.lounge_id;
$$;

-- ── YETKİ ───────────────────────────────────────────────────────────────
-- BO servis anahtarıyla (service_role) çağırıyor. `security definer` +
-- sabit `search_path`, fonksiyonun çağıranın arama yoluna kaçırılmasını
-- engeller.
revoke all on function bo_finance_ozet()     from public, anon;
revoke all on function bo_carrier_kullanim() from public, anon;
revoke all on function bo_lounge_kullanim()  from public, anon;
grant execute on function bo_finance_ozet()     to service_role;
grant execute on function bo_carrier_kullanim() to service_role;
grant execute on function bo_lounge_kullanim()  to service_role;

-- ── NÖBETÇİ ─────────────────────────────────────────────────────────────
-- 🔴 "Fonksiyonu yazdım" ile "fonksiyon çağrılabiliyor" aynı şey değildir.
-- Bir kolon adı yanlışsa `create` başarılı olur, ÇAĞRI başarısız olur —
-- ve BO sessizce eski yavaş yola düşer, yani hatayı hiç görmezsin.
-- O yüzden nöbetçi fonksiyonu SADECE ARAMIYOR, ÇALIŞTIRIYOR.
--
-- 🆕 SINIF: "BİR FONKSİYONUN VAR OLDUĞUNU DOĞRULAMAK YETMEZ — ÇALIŞTIĞINI
-- DOĞRULA; YEDEK YOLU OLAN BİR SİSTEMDE BOZUK KOD SESSİZ KALIR."
do $$
declare
  v_a bigint; v_b bigint; v_c bigint;
begin
  select hold_adet into v_a from bo_finance_ozet();
  select count(*)  into v_b from bo_carrier_kullanim();
  select count(*)  into v_c from bo_lounge_kullanim();
  raise notice '260 NOBETCI OK: finance hold=%, carrier grup=%, lounge grup=%', v_a, v_b, v_c;
exception when others then
  raise exception '260 NOBETCI: fonksiyonlar calismadi -> %', sqlerrm;
end $$;
