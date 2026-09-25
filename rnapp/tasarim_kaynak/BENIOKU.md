# tasarim_kaynak/ — onaylanan gece sisteminin KAYNAĞI

Bu klasör `C:\LoungeLink\tasarim\` klasörünün **denetim için gereken**
parçalarının kopyası.

## Neden burada?

`tasarim_yapi_check.py` ve `tasarim_olcu_check.py`, tasarımın kendi
CSS'inden iddia ve sayı çıkarıp uygulamada arıyor. İkisi de
`../tasarim/css.py` yolunu okuyordu.

**O yol yalnız benim makinemde vardı.** Yani `node verify.js`
sende çalıştırıldığında bu iki kapı kırmızı yanacak, sen de "45
denetimin hepsi temiz" satırını hiç görmeyecektin.

> 🆕 **"BENİM MAKİNEMDE GEÇEN AMA SENİN MAKİNENDE ÇALIŞAMAYAN BİR
> KAPI, KAPI DEĞİL — BENİM İÇİN YAZILMIŞ BİR NOTTUR."**

Denetimler artık ÖNCE bu klasöre bakıyor, yoksa `../tasarim/`e düşüyor.

## İçindekiler

| dosya | ne |
|---|---|
| `css.py` | tasarımın tüm ölçüleri ve renkleri |
| `gen.py` | beş ekranın yapısı |
| `yap.py` | ekran sırası ve notlar |
| `ref/*.png` | tasarımın GERÇEK TARAYICIDA çizilmiş hâli (390×844 @3x) |

`ref/` klasörü `tasarim/tasarim_render.py` ile üretildi (Playwright +
Chromium). Uygulamanın önizlemesini bunlarla yan yana koyarak
karşılaştırıyorum — `teslim/tasarim_vs_app.png`.
