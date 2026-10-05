# DEVIR — 5 Ekim 2026 (b) · gezinti + boş durum turu · app 6.3.6

Gökberk'in 4 maddesi (ekran görüntüleriyle).

## Değişenler — App 6.3.6 · versionCode 285 · buildNumber 279
1. **"Salon ara" açılınca arkada ana sayfa görünüyordu** (`App.js`)
   - KÖK 1: çubuklu katman (Keşfet/Bildirimler) çubuğun ÜST kenarında bitiyordu. v7 çubuğunun
     üst 40pt'si saydam geçiş → orada ALTTAKİ sekme (ana sayfa) görünüyordu.
     Katman artık sekmeler gibi çubuğun 40pt arkasına uzanıyor; çubuk o sırada zIndex 51.
   - KÖK 2: ana sayfanın durum çubuğu perdesi (zIndex 30) Android'de görünüm düzleştirmesiyle
     katmanla (zIndex 20) kardeş olup Keşfet'in tepesine soluk şerit çiziyordu.
     Tam ekran katman zIndex 20 → 50 (sekme içindeki her z'den yüksek; hata bandı 90 üstte).
   - Ayrıca "Sıra sende" anındaki "Salon ara" yalnız kapatıyordu → artık Keşfet'i açıyor
     (`Hosting` `onDiscover`).
2. **Kaydırınca sağ üst düğme durum çubuğunun altında kalıyordu** (`src/ui.js` DaralanBant)
   - `daire` düğmesi `alignSelf:flex-start` ile kompakt çubuğun tepesine çıkıyordu (her daralan bantta).
   - Artık başlıkla aynı alt çizgide. Durum çubuğu yüksek cihazda (iOS, çentikli Android) sığmıyorsa
     kompakt hâlde çizilmiyor; yukarı kaydırınca bantta var.
3. **Tanış boş durumları çipe ve seyahat durumuna özgü** (`src/ekranlar_ana.js` Meet + i18n TR/EN)
   - Tümü / Uçuş / Salon / Rota × seyahati var / yok.
   - "Seyahat Ekle" yalnız seyahati olmayana gösteriliyor; çip seçiliyse "Tüm yolculara bak" var.
   - Seyahat eklenince Tanış yenileniyor (`Meet key=reload`).
4. **Bağlantılarım'daki "Tanış" düğmesi → "Yeni yolcularla tanış"** (`connsFindPeople`).

Yeni test: `web_sahne/akis_e2e_b11_gozlem.py` (`gozlem` bölümü, 4 kontrol).

## SQL
Yeni SQL yok. Önceki turdan: 330 (koşulmadıysa) + 331.

## Koşulan testler
- gozlem 4/4:
  - katman alt kenarı = çubuk düğmesi üstü (766/766);
  - kompakt Ayarlar üst=32 (durum çubuğu altında değil);
  - Uçuş boş mesajı + Tüm yolculara bak;
  - Yeni yolcularla tanış → Tanış listesi.
- node check.js temiz · render 39/39.
- Statik denetimler temiz: tema, satır, düğme, tasarım borcu, dokunma, ham kod, palet, cihaz parite.
- Tam regresyon (13 bölüm): 190/192. İki kırmızı tarama bölümünde `push_izni_bildir: Failed to fetch` (test köprüsü ağ hatası, bu turda dokunulmadı); tarama ayrıca yeniden koşuldu: TARAMA_BURAYA

## Notlar
- Web export bu makinede bellek yetmezliğiyle (OOM) düştü (boş RAM ~260 MB).
  `--max-workers 1` ile geçti; EAS build bundan etkilenmez.

## Açık kalanlar
- "Seyahat Ekle" yolu Tanış boş durumundan web'de uçtan uca koşulmadı (test kullanıcısının seyahati vardı).
  Düğme aynı `onAddTrip(null)` → AddVisit katmanı, bu yol önceki turlarda test edildi.
