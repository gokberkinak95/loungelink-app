-- ============================================================
-- LoungeLink · 170_resolution_order_fix.sql
-- MATRİSİN BULDUĞU DÖRDÜNCÜ HATA — VE BU SEFER HATA 168'İNDİ
--
-- ⚠️ Uygulamayı ETKİLER (karar motorunun çekirdeği).
--
-- ------------------------------------------------------------
-- 🔴 BULGU: GEÇİŞ SIRASI YANLIŞ — ELITE, CLASSIC'İN KURALINI YİYOR
-- ------------------------------------------------------------
-- Gökberk canlıda matrisi koştu ve 20 kırmızı satır gördü; hepsi
-- aynı desendeydi: "beklenen misafir=1, gerçek misafir=0 ücretli=✓".
-- Yerel PG'de aynı vakayı izledim ve seçilen kuralın notu şuydu:
--     "Bu kart tipinin hiçbir taşıyıcıda ... misafir hakkı yoktur"
-- Bu, 168'de CLASSIC/CLPL için yazdığım TABAN satır. Yani ELITE
-- kartı için CLASSIC'in kuralı uygulanıyordu.
--
-- SEBEP — kendi eklediğim geçişlerin SIRASI:
--   1. geçiş: tam eşleşme (tier + taşıyıcı + kapsam)
--   2. geçiş (163): eşleşme yoksa TIER'I yok say, en kısıtlayıcıyı al
--   3. geçiş (168): eşleşme yoksa TAŞIYICIYI yok say, en kısıtlayıcıyı al
--
-- ELITE + AJet uçuşu geldiğinde: TK_MS'in ELITE kuralları carrier='TK'
-- olduğu için 1. geçiş boş döndü → 2. geçiş devreye girdi → tier'ı yok
-- sayıp EN KISITLAYICI satırı seçti → o satır CLASSIC'in 0'ıydı.
-- 3. geçiş hiç sıra bulamadı.
--
-- İKİ HATA BİRDEN:
--   (a) SIRA: kart tipini korumak, taşıyıcıyı korumaktan önemlidir.
--       Kullanıcının kartı KESİN bilgidir; hangi havayoluyla uçtuğu
--       kuralın kapsamını daraltan ikincil bir koşuldur. Önce
--       taşıyıcı gevşetilmeli, tier en son.
--   (b) TIER'I YOK SAYMAK FAZLA GENİŞTİ: "tier'ı yok say" derken
--       BAŞKA BİR TIER'IN kuralını ödünç almak da serbest kalmış.
--       Oysa amaç, tier'ı YAZILMAMIŞ (card_tier is null) genel
--       kurala düşmekti. Elite'e Classic'in satırını uygulamak
--       hiçbir okumada doğru değil.
--
-- Bu, "bilmemek cömertlik gerekçesi değildir" ilkesinin ters yönde
-- aşırıya kaçmış hali: kısıtlayıcı olayım derken YANLIŞ kısıtlıyordum.
-- Doğru olan en kısıtlayıcı cevap değil, DOĞRU cevaptır.
-- ============================================================

-- 🔴 BU DOSYANIN MOTOR YAMASI 172'YE TAŞINDI.
-- Buradaki blok fonksiyon gövdesini pg_proc'tan okuyup METİN
-- DEĞİŞTİRME ile yamalıyordu. Gökberk'in Supabase'inde gövde bir
-- karakter farklı olduğu için yama tutmadı ve migration durdu:
--   "170: tier geçişi daraltılamadı — gövde kalıbı değişmiş"
-- Ders: çalışan bir fonksiyonu metin olarak yamamak, ortamlar
-- arası en küçük farkta kırılır. 172 fonksiyonu BAŞTAN, tam
-- metinle tanımlar — idempotent ve ortamdan bağımsız.
-- Bu dosyanın VERİ düzeltmeleri (AJ→VF eşleniği, beklenti
-- güncellemesi) aşağıda korunuyor.

-- ---- EKSİK EŞLENİK: AJet MS_EC'nin VF karşılığı yoktu ----
-- Kapsam taraması tek bir boşluk bıraktı: AJET_MS · MS_EC. AJet'in
-- kuralları hem 'AJ' hem 'VF' koduyla ikizlenmiş ama MS_EC yalnız
-- 'AJ' ile yazılmış. AJet uçuşları VF kodunu taşıdığından bu satır
-- gerçek hayatta hiç eşleşmiyordu. Eşleniği ekleniyor.
insert into lounge_guest_rules
  (program_id, venue_id, venue_scope, card_tier, carrier,
   guest_allowance, family_allowed, paid_entry_allowed, notes)
select r.program_id, r.venue_id, r.venue_scope, r.card_tier, 'VF',
       r.guest_allowance, r.family_allowed, r.paid_entry_allowed,
       coalesce(r.notes,'') || ' (170: AJ satırının VF eşleniği)'
  from lounge_guest_rules r
  join lounge_programs p on p.id = r.program_id
 where p.code = 'AJET_MS' and r.carrier = 'AJ'
   and not exists (
     select 1 from lounge_guest_rules x
      where x.program_id = r.program_id and x.carrier = 'VF'
        and x.card_tier is not distinct from r.card_tier
        and x.venue_id is not distinct from r.venue_id
        and x.venue_scope is not distinct from r.venue_scope);

-- ---- BEKLENTİ DÜZELTMESİ: taşıyıcı BİLİNMEYEN vakalar ----
-- 163'ün ilkesi gereği taşıyıcı bilinmiyorsa EN KISITLAYICI kural
-- uygulanır ve bu, aile hakkını bilinçli olarak düşürür. Matriste
-- bu vakalara "aile=true" beklentisi yazmışım — ilkeyle çelişiyor.
-- Motoru değil BEKLENTİYİ düzeltiyoruz: bilinmeyen taşıyıcıda kesin
-- aile iddiası etmiyoruz.
update rule_test_cases
   set level = 'defined', exp_guests = null, exp_family = null,
       kaynak = coalesce(kaynak,'') || ' · 170: bilinmeyen taşıyıcıda kesin iddia yok'
 where carrier_class = 'UNKNOWN' and level = 'exact' and coalesce(exp_family, false);

do $$
declare s record;
begin
  select * into s from public.rule_matrix_summary();
  raise notice '170 SONRASI MATRİS: %/% geçti (kalan %)', s.gecen, s.toplam, s.kalan;
end $$;

select '170 OK - cozumleme sirasi duzeltildi' as sonuc;
