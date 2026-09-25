-- ============================================================
-- LoungeLink · 051_beta_visibility_reset_and_diagnoz.sql
--
-- İKİ KÖK NEDEN (Gokberk: "ilanımı kimse göremiyor"):
-- 1) App'teki hızlı ilan formu RPC yerine DOĞRUDAN insert atıyordu —
--    RLS/korumalara takılıp HİÇ yazmıyordu (v1.32'de RPC'ye çevrildi).
-- 2) Müsaitlik Ekle'nin varsayılanı 'trusted' = min_trust 55 idi —
--    beta hesaplarının güveni 10-18; ilan OLUŞSA BİLE onlara görünmezdi.
--
-- Bu dosya: (a) beta sıfırlaması — mevcut ilanların eşiğini 0'a çeker
-- (ağ boşken kimseyi eşiğe kurban etme), (b) TANI: her ilan için hangi
-- kuralın geçtiğini/takıldığını satır satır gösterir.
-- ============================================================

-- (a) BETA SIFIRLAMASI — yalnız eşik; host'un Hidden/Connections seçimi korunur
update availabilities set min_trust = 0 where min_trust > 0;

-- (b) TANI — çıktıyı oku: hangi ilan, hangi kuralda takılıyor?
select
  a.id, a.airport_code, a.avail_date, a.active,
  p.name as host_name,
  hu.role as host_role,
  (a.active)                                          as kural_aktif,
  (a.avail_date >= current_date)                      as kural_tarih_gelecek,
  (a.visibility <> 'Hidden')                          as kural_gizli_degil,
  coalesce(pr.show_on_discovery, true)                as kural_kesifte_gorunur,
  (coalesce(hu.is_staff,false) = false)               as kural_staff_degil,
  (hu.deleted_at is null)                             as kural_silinmemis,
  a.min_trust                                         as esik_min_trust,
  (hu.role = 'host' or exists (select 1 from host_applications ha
      where ha.user_id = a.host_id and ha.status = 'approved')) as kural_rol_uygun,
  coalesce(pr.women_safety_mode, false)               as kadin_guvenlik_modu
from availabilities a
join users hu on hu.id = a.host_id
left join profiles pr on pr.user_id = a.host_id
left join profiles p  on p.user_id  = a.host_id
order by a.created_at desc
limit 20;
