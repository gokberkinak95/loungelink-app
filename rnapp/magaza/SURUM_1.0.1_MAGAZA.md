# LoungeLink 1.0.1 — mağaza metinleri ve elle yapılacaklar (12 Kasım 2026)

## App Store Connect › 1.0.1 (yeni sürüm)
Ad, alt başlık ve anahtar kelimeler yalnız yeni sürümle değişir.

### Türkçe
- **Ad (30):** `LoungeLink: Lounge Arkadaşı`
- **Alt başlık (30):** `Lounge'a misafir olarak gir`
- **Anahtar kelimeler (100, virgülle, boşluksuz):**
  `havalimanı,cip,salonu,bekleme,yolcu,uçuş,aktarma,seyahat,tanışma,networking,kart,ayrıcalık,statü`
  (Ad ve alt başlıktaki kelimeler — lounge, misafir, arkadaş — tekrar yazılmaz; Apple onları zaten sayar.)
- **Promotional Text:** değişmedi.

### English (U.S.)
- **Name:** `LoungeLink: Lounge Companion` (değişmedi)
- **Subtitle:** `Join a lounge as a guest`
- **Keywords:** `airport,vip,cip,waiting,layover,traveler,flight,travel,networking,card,perk,status,priority`

### Sürüm notu (What's New)
TR:
```
• Seyahatini artık doğrudan seyahat kartından iptal edebilirsin.
• Satın aldığın plan, onay gecikse bile ekrana kendiliğinden yansıyor.
• Dil düğmesi artık bulunduğun dili gösteriyor.
• Stokta kalmayan ödüller "Tükendi" olarak görünüyor.
• İzin pencerelerindeki bozuk karakterler düzeltildi.
• Küçük düzeltmeler ve iyileştirmeler.
```
EN:
```
• Cancel a trip right from its card.
• Purchased plans now appear on screen on their own, even if confirmation is delayed.
• The language button now shows your current language.
• Rewards that are out of stock are marked "Sold out".
• Permission prompts now display correctly in English and Turkish.
• Minor fixes and improvements.
```

### Ekran görüntüsü
- `ekran/34_host_ol.jpg` artık olmayan bir vaadi gösteriyor → mağaza setinden çıkar ya da yeni çekimle değiştir.

### App Review notu (Notes) — inceleme hesabı
```
Sign in with: inceleme@loungelink.co (password in the review account fields).
The network is new; the review account has a current trip and open host listings
(Istanbul IST) so the request flow can be tested. Purchases use the sandbox.
```
Göndermeden önce inceleme hesabının seyahatinin GELECEK tarihli olduğunu kontrol et
(Supabase'de: select visit_date from visits v join auth.users u on u.id=v.user_id where u.email='inceleme@loungelink.co').

## Google Play
- versionCode 308 → kapalı test (Alpha) kanalına. Sürüm notu: yukarıdaki TR metni.
