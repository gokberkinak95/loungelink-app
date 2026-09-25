# web_sahne/ — GERÇEK REACT AĞACINDAN, GERÇEK VERİYLE EKRAN GÖRÜNTÜSÜ

## Neden var (3 Eylül)

Gökberk cihaz ekran görüntülerini gönderdi: ikonlar yer tutucu, ana sayfada
çift "LOUNGELINK", düz siyah bant, beş kutulu Akışım. Oysa "önizleme"
(`onizleme.py` / `ekran_uret.py`) bunların hiçbirini göstermiyordu — çünkü
önizleme PIL ile ÇİZİLİYORDU, uygulama kaynağından RENDER edilmiyordu.

> 🆕 SINIF: "KAYNAĞI OKUYUP ÇİZEN BİR ÖNİZLEME, KAYNAĞIN NE YAPTIĞINI DEĞİL
> BENİM KAYNAKTAN NE ANLADIĞIMI GÖSTERİR — RENDER ETMEYEN ÖNİZLEME, ÖNİZLEME
> DEĞİL RESİMDİR."

Bu klasör uygulamayı **react-native-web + Chromium** ile GERÇEKTEN çiziyor ve
veriyi **yerel Postgres**'ten (319 migration + sahne fikstürü) GERÇEK RPC
gövdeleri ve GERÇEK RLS ile alıyor.

## Parçalar

| dosya | ne |
|---|---|
| `../metro.config.js` | `LL_SAHNE=1` iken `src/supabase.js` → `supabase_sahte.js`, `App.js` → `Galeri.js`; notifications/device/datetimepicker taklitleri |
| `Galeri.js` | fontları web'e yükler, `?sahne=&kim=` okur, gerçek `App`i çizer |
| `supabase_sahte.js` | `rpc()`/`from()` çağrılarını köprüye gönderen istemci (PostgREST alt kümesi) |
| `pg_kopru.py` | yerel `ll` veritabanında `set role authenticated` + `request.jwt.claims` ile koşturan mini PostgREST |
| `sahne_seed.sql` | tasarımın dünyası: Gökberk (misafir), Deniz K. / Mert A. / Selin B. (host), sohbet, oturum, bildirimler |
| `cek.py` | her sahneyi 390×844 @3x açar, uygulamanın KENDİ düğmelerine dokunarak gezer, PNG+JSON yazar |
| `karsilastir.py` | SOL onaylanan tasarım (`ekranlar_render/`) · SAĞ gerçek render |

## Çalıştırma (yalnız yerel Postgres olan makinede)

```
psql -d ll -f web_sahne/sahne_seed.sql
npm run sahne:export
npm run sahne
```

Çıktı: `web_sahne/out/_karsilastirma.png` ve `out/_cift_<sahne>.png`.

## Ne ölçer, ne ölçmez

Ölçer: bileşen yapısı, font ailesi/kesiti, renk, ikon, yerleşim sırası,
gerçek veriyle metin. Ölçmez: cihazın yazı motoru (satır kırma ±), durum
çubuğu/çentik, dokunma hissi. Bu yüzden cihazdan gelen görüntü hâlâ son söz;
ama artık "cihazda görünen ≠ önizleme" sınıfı hatalar burada yakalanıyor.
