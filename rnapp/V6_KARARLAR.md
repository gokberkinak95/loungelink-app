# v6.0.0 · KİLİTLENEN BEŞ KARAR

**Tarih:** 20 Eylül 2026 · **Onay:** Gökberk ("en doğru kararları vererek uygula")
**Kaynak dosya:** Obsidyen Protokol (kuzey yıldızı sunumu)

Bu dosya bir öneri değil bir **kayıt**. v6 sütunları yazılırken buradaki
değerler tartışılmaz; değişmesi gerekiyorsa gerekçesi buraya yazılır.

---

## 1 · PALET — sevk edilen korunur

| Rol | KARAR | Reddedilen | Gerekçe |
|---|---|---|---|
| Sayfa zemini | `#0B0A0B` | `#12100E` | Aralarındaki kontrast **1.04** — gözle ayırt edilemez. Değişiklik bedava değil (53 sahne yeniden çekilir), kazanç sıfır. |
| Marka altını | `#C9B693` | — | ⚠️ **20 EYLÜL · DÜZELTME.** Önce "sevk edilen `#D6C3A0`, brief'in `#C9B693`'ü kontrastı 11.46→9.97 düşürür, RED" yazmıştım. **Yanlıştı.** `theme.js` `KOYU.gold`u ÜÇ KEZ atıyor (806 `#D6C3A0` · 1371 `#D0B268` · 1444 `#C9B693`) ve **son atama kazanıyor**. App zaten `#C9B693` taşıyordu — yani brief'in değeri ile sevk edilen değer AYNIYDI; reddedecek bir şey yoktu. Karar özü değişmiyor (sevk edileni koru) ama gerekçem ölü bir satırı okumaktan geliyordu. `olu_jeton_check.py` bu sınıfı kapattı. |
| Fildişi mürekkep | `#F4EFE6` | `#EDE7DB` | 17.26 → 16.05. İkisi de geçer, ama sevk edilen `kontrast_check` eşiklerine göre ölçülmüş. |
| Kılcal ışık | `rgba(232,214,182,0.10)` | `rgba(244,239,230,0.06)` | Ton farkı, işlev aynı. Değiştirmek için sebep yok. |

**Kural:** v6'da yeni bir renk değeri ancak `kontrast_check` ölçümüyle
birlikte önerilir. "Daha lüks görünüyor" bir gerekçe değildir.

---

## 2 · AMBİYANS — amber değil şampanya

Şafak uçuşlarında zemine sızan sıcaklık:

```js
// src/atmosfer.js
const SAFAK_HALE = "rgba(214,195,160,0.05)";   // ✔ şampanya
// const SAFAK_HALE = "rgba(217,119,6,0.08)";  // ✘ amber — YASAK
```

**İki gerekçe:**
1. `website/palet_check.py` amber'i tavan 0 ile yasaklıyor. Nöbetçiye
   istisna yazmıyoruz — bir nöbetçiye açılan ilk istisna, ikincisinin
   gerekçesi olur.
2. Markanın zaten bir sıcak tonu var. İkincisini eklemek birincisini
   ucuzlatır.

---

## 3 · ZARAFET PROTOKOLÜ — her bypass bir sayaçtır

Briefte yoktu; eklendi. Ölçülmeyen bir kaçış yolu bir süre sonra **asıl
yol** olur.

```sql
alter table sessions
  add column if not exists dogrulama_atlandi boolean not null default false,
  add column if not exists dogrulama_atlama_sebebi text;

-- BO'da tek satır: "bu hafta atlanan doğrulama: 41 / 380  (%10.8)"
create or replace function public.bo_dogrulama_atlama_orani(p_gun int default 7)
returns jsonb ...
```

**Eşik: %20.** Bu oranı geçerse bozuk olan tarayıcıdır, kullanıcılar değil —
ve o hafta tarayıcı işi öncelik listesinin başına alınır.

**Metin** (brief'ten, tek değişiklikle):

> Dijital biniş kartı doğrulaması sistem şartlarından dolayı tamamlanamadı.
> Lütfen turnike geçişi esnasında salon kurallarına manuel olarak
> **uyduğundan** emin ol.

("uyduğunuzdan" → "uyduğundan": ürünün her yeri sen diliyle konuşuyor.
Tek bir yerde siz'e geçmek o cümlenin otomatik üretildiğini haber verir.)

---

## 4 · İKON — Kemer · D varyantı (Işık Huzmesi)

Mevcut swoosh **atılmıyor, terfi ediyor.** Kemerin açıklığına kırpılmış
bir ışık huzmesi olarak yaşıyor: eşikten içeri düşen aydınlık.

**Denenen ve elenen harmanlar:**

| Varyant | Neden elendi |
|---|---|
| A · Dekal (swoosh kemerin ortasında) | İki kahraman tek karede. Swoosh kemerin iç kenarına çarpıyor, 60pt'de leke. |
| B · Eşik (swoosh taban çubuğunun yerine) | 300pt'de güzel, ama sol uç çerçeveden taşıyor ve kompozisyon sola kayıyor. |
| C · Kilit taşı (swoosh kemerin tepesinde) | Çatlak gibi okunuyor. Kabartma değil hasar hissi. |
| **D · Işık huzmesi** | **SEÇİLDİ.** Kırpıldığı için taşamaz; E'nin boş iç panelini doldurur; markanın jesti korunur. |
| E · Sade kemer | İyi ama iç açıklık ölü alan. D onu çözüyor. |

**20 Eylül · oran düzeltmesi (Gökberk'in iki tespiti):**

1. **Swoosh sığmıyordu.** 128 birim genişlikte çizilmişti ama kemerin
   açıklığı 100 birim — kırpılması kaçınılmazdı. Oranlar referanstan
   yeniden türetildi: kemer dış `x 44..176` (%60), açıklık `100×130`,
   swoosh `gen 62`, merkez `(107, 132)`.
   Merkez 110 değil **107**: eğrinin kütlesi sağda, uçları solda; kutu
   merkezine hizalanırsa göz onu sağa kaymış görür.
2. **Tepedeki siyah delik kaldırıldı.** "Biniş kartı yırtma çentiği"
   detayıydı. Açıklama gerektiren bir detay çalışmıyor demektir; 60pt'de
   baskı hatası gibi okunuyordu. Rivet alternatifi de denendi, düştü.

🆕 SINIF: "BİR DETAYIN NE OLDUĞU SORULUYORSA, O DETAY ANLATMIYOR —
DİKKAT ÇEKİYOR. İKİSİ AYNI ŞEY DEĞİLDİR."

**Üretim:** `brand/build_kemer.py` — ikon kaynaktan yeniden üretilebilir,
dokunulamaz bir PNG değil. Swoosh izi `brand/swoosh_izi.npy` (mevcut
`assets/icon.png`den `cv2.findContours` ile çıkarıldı; `--izle` ile
yeniden alınabilir).

**Üretilen varlıklar** (`ikon_kemer/`): `icon.png` 1024, `adaptive-icon.png`
(şeffaf, %70 güvenli ölçek), `adaptive-zemin.png`, `monochrome-icon.png`,
`notification-icon.png` 256, `favicon.png` 64, `kemer.svg`.

**20 Eylül · UYGULANDI.** Gökberk "5 karar kısmındaki kararlarını tüm
app'e uygula" dedi; karar 4 bu. Eskiler `assets/arsiv_ikon_v5/` altına
arşivlendi (silinmedi). Geri almak tek komut:
`cp assets/arsiv_ikon_v5/* assets/`

**İki mağaza kuralı `marka_check.py` tarafından yakalandı ve uyuldu:**
`adaptive-icon.png` OPAK olmalı (Android maskeliyor — saydam ön plan
cihazdan cihaza farklı davranıyor), `notification-icon.png` 96px olmalı
(yanlış boyutta Android beyaz kare basıyor). İlk üretimimde ikisi de
ihlaldeydi.

**Tek üretici:** ikon `brand/build_kemer.py`de çizilir,
`brand/build_brand.py` ona DEVREDER. İkinci bir üretici eklemek
üreticisizlikten tehlikelidir — hangisinin doğru olduğunu kimse bilmez.

---

## 5 · SIRA — 3 → 1 → 2

| # | Sütun | Neden bu sırada |
|---|---|---|
| 1. | **FIDS sohbet şeridi** | En düşük risk, en görünür kazanç. Yeni tablo yok, yeni izin yok. Tek bağımlılığı `yerel_an()` — o da kurulu. |
| 2. | **Zaman-asimetrik doğrulama** | `bcbp.js` hazır; eksik olan buzlu cam sayfası. FIDS'in kurduğu başlık mimarisine yaslanır. |
| 3. | **Zarafet Protokolü** | Ancak doğrulama varken anlamlı. Doğrulamadan önce yazılırsa neyin kurtarıldığı belirsiz kalır. |

---

## BAĞLI ÖLÇÜMLER (19 Eylül, yerel replika)

```
src/bcbp.js                 221 satır · kalkis [30,33] · varis okunur, SAKLANMAZ
src/BinisKarti.js:67        FS_.deleteAsync(uri, { idempotent: true })
grep -rc "Gradient" src/    0        · expo-linear-gradient bağımlılıkta DEĞİL
theme.js                    temaUygula("koyu") — uygulama zaten obsidyen
time without time zone      8 kolon  · hepsi KASITLI (duvar saati)
yerel_an() tüketicisi       4 fonksiyon
website/palet_check.py      amber yasak · tavan 0
```

**Açık borç:** `yerel_an()`'ı 4 fonksiyon kullanıyor. FIDS geri sayımı da
oraya bağlanmalı — cihaz saatine bağlanırsa Türkiye dışındaki telefonda
şerit yalan söyler.


---

## 20 EYLÜL · TEMANIN APP GENELİNE UYGULANMASI

Gökberk: "obsidyen protokoldeki kararları tüm app'e eksiksiz uygula."
Ölçerek tarandı; **paletin dışında kalan her yer kapatıldı.**

| Ne | Ölçüm | Ne yapıldı |
|---|---|---|
| `assets/bant.jpg` (splash + İÇ EKRAN BAŞLIKLARI + MomentScreen — **üçü aynı dosya**) | C* p95 36.6 · hue 41° | maskeli derecelendirme → p95 23.3 · hue 76° · `brand/build_bant_derece.py` |
| `atmosfer.js` gün batımı rampası (10 durak) | kroma **48**'e kadar · hue 340°-71° | şampanyaya çekildi, **L\* birebir korundu** → kroma ≤17 · hue 59-84° |
| `BTN.gold` / `BTN.rose` | beyaz metin **1.65:1** / 3.12:1 | `C.onGold` (#17120B) → **11.32:1** / 5.97:1 |
| `app.json userInterfaceStyle` | `"light"` — ama `SECENEKLER = ["koyu"]` | `"dark"` |
| `app.json splash.backgroundColor` | `#F8F6F1` (beyaz flaş) | `#0B0A0B` |
| `app.json adaptiveIcon.backgroundColor` | `#FFFDF9` | `#0B0A0B` |
| `assets/splash.png` | krem zemin + eski çiğ altın swoosh | obsidyen + Kemer |
| `#2E3647` (mağaza rozeti) | hue **277°** menekşe-mavi | `C.pasifRozet` #3A332C · hue 73° · **aynı L\*** |
| `rgba(224,190,122,…)` ×2 | #E0BE7A · C* 38.9 (reddedilen çiğ altın) | `C.altinIz03` |
| `rgba(217,119,6,0.30)` | ham amber C* 73.4 | `C.amberLine` (paletin amberi) |
| `rgba(184,148,58,0.08)` | açık temanın altını | `C.goldBg` |

### Bu turda yazılan üç kapı

| Kapı | Neyi yakalıyor | Tavan |
|---|---|---|
| `dugme_kontrast_check.py` | Düğme ARAMA TABLOSUNDAKİ `{bg,fg}` çiftleri. `yuzey_kontrast_check.py` satır içi stil nesnelerini tarıyor — tablo onun kör noktasıydı. | 0 |
| `gorsel_palet_check.py` | Görsellerin **alfa maskeli** kroma/hue değeri. Maskesiz ölçüm saydam pikselleri sayıp doğru bir varlığı bozuk gösteriyordu. | 0 |
| `tema_sizinti_check.py` | `theme.js` dışında sabit yazılmış, sıcak bandın (45-120°) dışında ya da C* 28'i aşan her renk. | 0 |

**Zincir: 69/69 · 53 sahne · 55 e2e · 52 ekran · 37 render · 0 ikiz.**

### Kendi hatalarım (kayıt için)

1. `bant_hale.png`i "306° mor" diye raporladım — **alfa kanalını yok saymıştım.**
   Maskeli doğru değer hue 83°, yani zaten uyumlu. Az kalsın doğru bir
   varlığı "düzeltiyordum". Dosyaya dokunulmadı.
2. `tema_sizinti_check.py`nin tavanını önce mevcut 12 bulguya kalibre
   ettim. Sonra hepsine tek tek baktım: **onikisi de gerçek sızıntıydı.**
   Tavanı mevcut hâle kalibre etmek, o hâli doğru saymaktır.
3. İkonu `assets/`e elle kopyalayıp `build_brand.py`yi güncellemedim —
   projede iki üretici oldu. `marka_check.py` altı varlıkta da ayrışma
   raporladı ve haklıydı.

### Açık kalan tek madde

`brand/lockup/lockup-*.png` hâlâ ESKİ kanat markasını taşıyor (pazarlama
kolaterali, uygulamada dağıtılmıyor). Kemer'e çevrilmesi ayrı bir karar.


---

## 20 EYLÜL · İKİNCİ TUR — SİTE, LOCKUP, ÖLÜ JETONLAR

### Beni yanıltan sınıf: ölü jeton ataması

`theme.js`in 96 KOYU jetonunun **21'i** birden fazla kez atanıyor; **36
ölü atama** var. Ben nesne literalini okuyup `gold: "#D6C3A0"` gördüm ve
üstüne bir analiz kurdum. Gerçek değer 638 satır sonra atanan `#C9B693`.

Sonuçları: (a) Gökberk'e verdiğim palet gerekçesi ölü bir satıra
dayanıyordu, (b) siteyi "bir altın geride" sanıp `--gold`unu
değiştirdim — **site doğruydu**, `site_paleti.py` ile app'ten türetiliyor;
ben onu app'ten UZAKLAŞTIRDIM. Sitenin kendi denetimi beni yakaladı ve
geri aldım.

**Silmedim, İŞARETLEDİM.** Ölü satırların yanındaki yorumlar gerçek bir
tarih taşıyor; silmek o tarihi silmek olurdu. Her biri artık
`⛔ ÖLÜ ATAMA — geçerli değer satır N` taşıyor ve `olu_jeton_check.py`
işaretsiz bırakılmasını engelliyor. Palet çıktısı birebir aynı kaldı
(doğrulandı).

🆕 SINIF: "ÖLÜ DEĞER, YANLIŞ DEĞERDEN TEHLİKELİDİR: YANLIŞ DEĞER HATA
VERİR, ÖLÜ DEĞER İKNA EDER."

### Sitenin görselleri

Palet jetonları tek kaynaktan geliyordu ama GÖRSELLER gelmiyordu:

| Dosya | Ölçüm | Ne yapıldı |
|---|---|---|
| `public/bant.jpg` | derecelendirme ÖNCESİ (C* 36.6 · hue 41°) | app'ten kopyalandı |
| `public/og.jpg` | hue **281°** menekşe + açık tema maketi | `build_og.py` ile yeniden üretildi — obsidyen, Kemer, sitenin KENDİ cümlesi, GERÇEK güncel ekran |
| `public/icon.png` · `favicon.png` | iki tur geride | app'ten kopyalandı |
| `public/lockup.png` | eski kanat markası | **karar bekliyor** |

`og.jpg` bir bağlantı paylaşıldığında görünen TEK karedir — markayı ilk
gören insanların çoğu ürünü değil onu görür.

### Sitenin denetim zinciri

Sitenin beş Python denetimi **hiçbir zincire bağlı değildi**; yalnız
`check.js` koşuyordu. Bu turda hatırlanmadıkları ortaya çıktı (yukarıdaki
dört bayat görsel). `website/verify.js` yazıldı, `npm run verify` bağlandı.

🆕 SINIF: "BİR DENETİM ZİNCİRE BAĞLI DEĞİLSE VAR DEĞİLDİR."

### Açık madde

`brand/lockup/lockup-*.png` + `website/public/lockup.png` — Kemer lockup'ı
üç varyant hâlinde önizlendi, Gökberk'in seçimi bekleniyor.
