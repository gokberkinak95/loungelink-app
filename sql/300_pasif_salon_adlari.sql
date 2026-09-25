-- ============================================================================
-- 300 · PASİF SALON ADLARI — İÇ DURUM NOTU AD KOLONUNDAN ÇIKIYOR  (25 Eylül)
--
-- 🔴 NEDEN: 190 ve 214, pasife aldıkları salonların ADINA durum notu
-- ekledi: "(214 kaynaksız → pasif)", "(190 birleştirildi → 99635af7)".
-- Sebep teknikti: `uq_lounge_venue (airport_code, name, section)` benzersiz
-- ve birleştirilen kopya, yaşayan salonla AYNI adı taşıyamıyordu.
--
-- Ama `name` kullanıcıya görünen kolon. Geçmiş oturumu pasif bir salona
-- bağlı olan her kullanıcı, "Oturum Geçmişi"nde şunu okudu (web sahne
-- 25_oturum_gecmisi, gerçek render):
--     KAPIDA NE OLDU?  Primeclass Lounge (214 kaynaksız → pasif)
-- 25 satır etkileniyordu; hepsi `active = false`.
--
-- ÇÖZÜM: not `notes`e taşınır, ad temizlenir. Ölçüldü (yerel replika,
-- 333 dosya): ek silindiğinde `uq_lounge_venue` üzerinde ÇAKIŞMA 0 —
-- birleştirilen kopyalar yaşayan salondan `section` ile zaten ayrışıyor.
-- İndekse DOKUNULMUYOR: onu kısmi yapmak, `on conflict (airport_code,
-- name, …)` yazan her gelecek migration'ı kırardı.
-- Hiçbir satır SİLİNMİYOR; `legacy_lounge_id` ve geçmiş bağlar aynen kalır.
--
-- 🆕 SINIF: "BİR KISITI AŞMAK İÇİN KULLANICIYA GÖRÜNEN VERİYİ BOZMA —
-- KISITIN KAPSAMINI DOĞRU YERE ÇEK."
-- ============================================================================
begin;

update public.lounge_venues
   set notes = coalesce(notes || ' · ', '')
               || 'ad eki kaldırıldı (300): ' || substring(name from '\((\d{3} [^)]*→[^)]*)\)\s*$'),
       name  = regexp_replace(name, '\s*\(\d{3} [^)]*→[^)]*\)\s*$', '')
 where not active
   and name ~ '\(\d{3} [^)]*→[^)]*\)\s*$';

-- Bundan sonra pasif bir satırın adına durum eki yazılırsa geri çevir.
alter table public.lounge_venues drop constraint if exists ck_venue_ad_durum_eki_yok;
alter table public.lounge_venues
  add constraint ck_venue_ad_durum_eki_yok
  check (name !~ '\(\d{3} [^)]*→[^)]*\)\s*$');

commit;
