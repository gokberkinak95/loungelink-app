# Instagram Reels üretimi (23 Ekim 2026)

Video tarayıcıda kare kare çizilir (HTML + SVG), ffmpeg ile MP4 olur. Ekranlar uygulamanın gerçek sahne çekimleri (`web_sahne/out`).

- `videoC3.html` — GÜNCEL (23 Ekim akşam): açılışta kalkış panosu (KAPI B12 · 3 SAAT VAR → LOUNGE'DA BULUŞALIM), iki pin
  (Misafir/Host) koridorları izleyip lounge'da buluşur, lounge kutusu telefona dönüşür (eşleşme kesmesi), HOST sahnesi,
  kapanışta tek marka anı (kalem yazısı) + Yakında + mağazalar + loungelink.co. ~48.2 sn. Reels güvenli alanı gözetildi.
- `videoC2.html` — önceki C revize: gün batımı göğü, açık renk kapaklı başlıklar, telefon bir kez girer ve
  sayfalar uygulamadaki gibi sağdan kayar; kanat yalnız harita sahnesinde ve kapanışta (kalem gibi "loungelink" yazar).
  Kapanışta cam pano: başlık "LOUNGELINK", kapaklar "LOUNGE'DA / BULUŞALIM". ~42.9 sn.
- `video.html?tema=A|B|C` — ilk üç seçenek (A kalem kanat, B kalkış panosu, C karışım).
- `render.py <tema> pano t1 t2 …` → anahtar kare panosu; `render.py <tema> video` → kareler + MP4.
  Tema `C2` → videoC2.html. MP4'ü Instagram için tv aralığına çevir:
  `ffmpeg -framerate 30 -i kare_C2/%04d.jpg -vf "scale=in_range=pc:out_range=tv,format=yuv420p" -c:v libx264 -crf 18 out.mp4`
- `veri.js` — kalem yolu (Hershey "cursive", tek çizgi), kanat yolu, App Store/Google Play simgeleri (simple-icons 13.21.0).
  Yeniden üretmek: `kalem_uret.py` (pip: Hershey-Fonts).
- İşaret kutuları (istek, sohbet, +100) ekran görüntüsünde ÖLÇÜLDÜ (528 px genişlikte): ekran değişirse yeniden ölç.
- Yayından sonra: sade simgeler yerine Apple/Google resmi rozetleri.
