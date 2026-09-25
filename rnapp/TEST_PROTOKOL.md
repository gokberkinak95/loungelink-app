# LoungeLink · İki-Hesap Canlı Test Protokolü

Bu, uçtan uca happy-path'i bir kez gerçek cihazlarda doğrulamak için adım adım
kontrol listesi. Her build sonrası (ya da en azından beta öncesi) bir kez çalıştır.
İki hesap gerekir: **H** (host) ve **G** (guest). İki cihaz ya da bir cihaz +
tarayıcı/emülatör.

## 0. Hazırlık
- [ ] SQL sırası çalıştı mı? (…055→056→057)
- [ ] BO'da her iki hesap da `is_staff = false` mı? (staff hesabı keşiften gizlenir)
- [ ] H ve G'nin telefonu doğrulanmış mı? (istek atmak için şart)
- [ ] G'nin en az 1 kredisi var mı? (BO → Kredi Defteri / CreditTools)

## 1. Arz (H tarafı)
- [ ] H, Yayın/İlanlarım'dan aynı havalimanı+tarih için ilan açar
- [ ] İlan açar açmaz H'nin rolü `host` oldu mu? (BO → Kullanıcılar)
- [ ] **056 kontrolü:** G'nin o havalimanında uyumlu seyahati varsa, G'ye
      "Havalimanında host var! başvur" bildirimi düştü mü?
- [ ] **057 kontrolü:** H ilan açarken "seni bekleyen N yolcu var" banner'ı gördü mü?
- [ ] İlan BO → İlanlar'da "✓ görünür" mü?

## 2. Talep (G tarafı)
- [ ] G, Host Bul / Keşfet'te H'nin ilanını görüyor mu?
- [ ] G'nin uyumlu seyahati + doğrulanmış telefonu varken "İstek/Başvur" butonu aktif mi?
- [ ] G istek atar → H'ye "Yeni istek" bildirimi gitti mi?
- [ ] G'nin 1 kredisi escrow'a alındı mı? (BO → Kredi Defteri: hold satırı)

## 3. Kabul + Sohbet
- [ ] H, gelen isteği görüyor (fit halkası + profil)
- [ ] H "Kabul et" → G'ye "İstek kabul edildi 🎉" bildirimi
- [ ] Her iki tarafta da "Sohbeti Aç" görünüyor
- [ ] Sohbet gerçek-zamanlı çalışıyor (mesaj iki tarafta anında)

## 4. Oturum (KRİTİK — çift onay)
- [ ] Sohbette **yalnız H'de** "Oturumu Başlat" görünüyor; G'de "⏳ Host başlatınca…"
- [ ] H başlatır → oturum aktif, timer başlıyor
- [ ] H "Tamamla" basar → durumu "⏳ bekleniyor" (tek taraf yetmez)
- [ ] G "Tamamla" basar → oturum "completed", **iki tarafa da** "Oturum tamamlandı 🎉"
- [ ] G'nin escrow kredisi harcanmış olarak kaldı (iade YOK)

## 5. Puanlama (karşılıklı)
- [ ] H, G'yi puanlar → H +500 LoungePuan
- [ ] G, H'yi puanlar → G +200 LoungePuan
- [ ] Aynı kişi ikinci kez puanlayamıyor (buton kapanıyor / hata)
- [ ] Her iki tarafın rating ortalaması güncellendi (Profil orta stat)

## 6. Oturumdan bağlan (#post-session)
- [ ] Tamamlandı ekranında "🤝 Bağlantıda kal?" kartı çıkıyor
- [ ] H "Bağlan" → G'ye "Yeni bağlantı isteği" bildirimi
- [ ] G kabul → iki tarafta da "✓ Bağlantı aktif"; Bağlantılarım'da görünüyor
- [ ] **#6 kontrolü:** puanlama sonrası "🎁 arkadaşını davet et" CTA çıkıyor mu?

## 7. Host motivasyon (#7)
- [ ] H'nin ana sayfasında "BU AY N misafir · +P LoungePuan · sıradaki kademeye…" kartı

## 8. Negatif senaryolar (kırılma testleri)
- [ ] G kredisi 0 iken istek → "yetersiz kredi" hatası (TR)
- [ ] H kendi ilanına istek atamaz → "kendine istek" engeli
- [ ] Telefonu doğrulanmamış G → istek butonu kapalı + sebep
- [ ] Aynı slotta H hem host hem guest olamaz → "aynı slotta hosting" engeli

## 9. Görünüm (v3.2 · koyu tema)
Bu bölüm cihazda yapılmak ZORUNDA: kaynak denetimleri renkleri ölçer, ama
"gerçekten koyu görünüyor mu" sorusunu yalnız ekran yanıtlar.

- [ ] Ayarlar → GÖRÜNÜM → Tema: **Sistem / Açık / Koyu** üçlüsü görünüyor
- [ ] **Koyu**'ya bas → sayfa, kartlar, düğmeler, rozetler ANINDA değişiyor
      (uygulamayı kapatıp açmak gerekmiyor)
- [ ] **Sistem**'e bas → telefonun kendi ayarını izliyor; telefonu koyuya
      alınca uygulama da koyuya geçiyor (uygulama açıkken)
- [ ] Uygulamayı tamamen kapat, yeniden aç → seçim HATIRLANIYOR ve ilk
      karede zaten doğru tema var (beyaz flaş YOK)
- [ ] Koyu temada **durum çubuğu** (saat, pil) OKUNUYOR — açık ikon
- [ ] Koyu temada şu ekranlarda beyaz kalan bir kutu ARAMA: Keşfet · Tanış ·
      Seyahatler · Cüzdan · Ayarlar · Bildirimler · Sohbet · Profil
- [ ] Koyu temada **hata** kutusu (pembe metin) ile **başarı** kutusu (yeşil
      metin) birbirinden ayırt ediliyor
- [ ] Ayarlar → GÖRÜNÜM → **Sade görünüm** açılıyor; arka plan dokusu kayboluyor
      ve seçim uygulama kapanıp açılınca duruyor

---
**Bir madde ✗ ise:** ekranı/logu Claude'a ilet — mantık hatasıysa `flow_check.py`
değişmezine, UI hatasıysa ilgili ekrana bakılır. Bu protokol geçilmeden beta AÇILMAZ.
