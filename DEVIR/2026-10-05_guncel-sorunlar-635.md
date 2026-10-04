# DEVIR — 5 Ekim 2026 · "güncel sorunlar" turu · app 6.3.5

Gökberk'in 11 maddesi (güncel sorunlar.zip) + kendi denetimlerim.

## Değişenler
**App (rnapp) 6.3.5 · versionCode 284 · buildNumber 278**
- `src/ekranlar_yalin.js` (Chat)
  - md.1: "Oturum tamamlandı" anı yalnız puanlanmamış oturumda çıkar, oturum başına BİR kez
    (`ll_an_tamam_<sid>` AsyncStorage).
  - md.9: "Puanı gönder" busy/çift dokunuş kilidi; yıldız seçilmediyse cümle gösterir; `already_rated` → puanlandı sayılır.
- `src/MomentScreen.js` (md.2 · md.8): ikincil düğme v7'de koyu cam (beyaz zemin üstünde görünmez beyaz yazı bitti).
- `src/HostWallet.js` + `src/screens.js`: "Sıra sende" anından anlamsız "KARŞILIK" kaldırıldı; başlık + kredi cümlesi i18n'de.
- `src/ekranlar_ana.js`
  - md.3: istek gönderildi bildirimi karttan ayrıldı.
  - md.7 (onaylı önizleme): Sohbet/İstek/Davet/Soru şeridine gölge.
  - Keşfet kartında ham "PRIORITY_PASS" program etiketi düzeltildi.
  - Oturum Geçmişi sekmeleri ve düğmelerine erişilebilirlik rolü verildi.
- `src/screens.js`
  - md.6: İlanı düzenle / seyahat düzenle / Yayın & Davet'teki negatif boşluklar (çakışmalar) giderildi.
  - md.10 (onaylı önizleme): "Hangi ilan için" kartları premium; varsayılan seçim dolu ilanı atlar;
    uzun salon adı 2 satır (SE 320'de taşma vardı).
- Erişilebilirlik: rolsüz 107 dokunmatiğe `accessibilityRole="button"` eklendi
  (TalkBack/VoiceOver "düğme" der; e2e de onları bulur).
- `src/i18n.js`: `momentReciprocityTitle`/`Body`, `ratePickStars`, `meetChipAll` (TR+EN).

**SQL**
- `331_soru_kendi_kaydinda.sql` (md.4 · md.5): sorular `kural_sorulari` tablosunda.
  - İlk temas → bağlantı isteği + soru.
  - Bekleyen istek → yalnız soru.
  - Bağlı → yalnız soru, sohbete de düşer.
  - Her soru Gönderdiğim + Gelen listelerinde görünür.

**md.11 (slot/kredi):** ölçüldü, hata yok. Yeni test `web_sahne/akis_e2e_b9_slot.py` (9 adım + oturum iptali).

**Testler (yeni):** `akis_e2e_b4_kurallar.py` › `sorular`, `akis_e2e_b9_slot.py` › `slotlar`, `akis_e2e_b10_puan.py` › `puan`.
Ham kod nöbetçisi büyük harfli kodları da yakalar.

## Supabase'de koşulacak (sırayla)
1. `330_bo_hesabi_geri_al.sql` (koşulmadıysa)
2. `331_soru_kendi_kaydinda.sql`

## Koşulan testler
- Web sahne e2e (gerçek App.js + yerel Postgres): tam regresyon **188/188**.
  - Bölümler: tarama, giris, ana, kesfet, kurallar, bo, ekranlar, rol, hesap, sorular, slotlar, puan.
  - İlk koşu 186/188 verdi: 2 kırmızı tohum kaynaklıydı (sabit ilan kimliği, tohumun bugünkü soruları günlük sınırı dolduruyordu, isteksiz seyahat kalmamıştı).
  - Testler sorguyla ilan bulacak şekilde düzeltildi; iki bölüm yeniden koşuldu: 17/17.
- puan (yeni): 2/2.
  - Bağlantı sohbetinde puanlama yok.
  - "Oturum tamamlandı" 1 kez; puan 0→1 tek dokunuşta; sonra bir daha istenmiyor.
- npm run render: 39/39 · yönlendirme 18/18 · sosyal giriş 5/5.
- npm run be: yetki taraması 0 bulgu · 151 hata kodu, TR+EN eksik 0.
- node check.js temiz.
- npm run verify: ilk tam koşu 12 kırmızı → düzeltildi.
  - Renk sızıntısı, ritim, inici harf, dokunma hedefi, ham kod tavanı (330'un 3 BO kodu errMap'e eklendi), kurulum tablosu (315-331 elle eklendi, yerelde 315-331 hepsi KOSTU).
  - 331 için allow-replace işareti (dönüş tipi 314 ile aynı).
  - Denetleyici çökmesi: akis_e2e.json liste.
  - Kalan tek kırmızı: marka_check (bu makinede cairo kütüphanesi yok, ortam).
- Düğme seçim bütçesi 11→12: onaylı "Hangi ilan için" kartı, Secim bileşeninin karşılamadığı düzen.

## Açık kalanlar
- Keşfet 30 ilan için `availability_rule_snapshot` çağırıyor (perf notu, değiştirilmedi).
- BO bu turda değişmedi (1.96.4 geçerli).
