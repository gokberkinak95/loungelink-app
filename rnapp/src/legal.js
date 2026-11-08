// ============================================================
// LoungeLink · Hukuki metinler (TEK KAYNAK)
//
// ⚠️ Avukat onayından geçmemiş taslaklardır. KVKK (6698) ve ikincil
// mevzuatı (Aydınlatma Yükümlülüğü Tebliği, Veri Sorumlusuna Başvuru
// Tebliği, Silme/İmha Yönetmeliği), 6563 sayılı E-Ticaret Kanunu, 6502
// sayılı Tüketici Kanunu ve Mesafeli Sözleşmeler Yönetmeliği'nin beklediği
// başlıklar LoungeLink'in GERÇEK veri akışına göre yazıldı.
//
// 8 Kasım 2026 (SQL 345 · Gökberk kararı) — KİMLİK BELGESİ / SELFIE KALKTI.
// "Biz basit bir eşleştirme uygulamasıyız": özel nitelikli veri riski taşıyan
// hiçbir şey işlenmez. Açık rıza YALNIZ pazarlama bildirimi için istenir
// (işaretsiz, ayrı kutu); diğer her işleme başka bir hukuki sebebe dayanır.
// Metindeki her saklama süresi `saklama_suresi_imha()` (her gece) ile uygulanır.
//
// 15 Ekim 2026 — BİREYSEL YAPI. Veri sorumlusu GERÇEK KİŞİDİR; mağazadaki
// satıcı adı ile metinlerdeki ad AYNI olmalı. Şirket kurulunca yalnız
// aşağıdaki sabitler değişir.
//
// AYNI METİN backoffice'te ve sitede de yayınlanır (mağazalar erişilebilir
// bir gizlilik politikası URL'i ister).
//
// KOPYALAMA YÖNÜ (değiştirdikten sonra):
//     rnapp/src/legal.js  →  backoffice/lib/legal.js
//     rnapp/src/legal.js  →  website/lib/legal-source.js
// Tek yönlü; asla tersi. (`node check.js` yer tutucu kalmadığını denetler.)
// ============================================================

export const LEGAL_VERSION = "2026-11-08";

// Veri sorumlusu: gerçek kişi (bireysel geliştirici). Mağaza hesabındaki ad ile aynı.
const COMPANY = "Gökberk İnak";
// 21 Ekim (Gökberk: bireysel hesap, adres yayınlanmıyor) — açık adres metinlerde yer almaz; posta
// yoluyla yazılı başvuru için adres İSTEK ÜZERİNE e-postayla bildirilir (başvuru kanalı kapanmaz).
const CONTACT = "kvkk@loungelink.co";
const SUPPORT = "destek@loungelink.co";
const SITE = "https://loungelink.co";


export const LEGAL_DOCS = {
  gizlilik: {
    title: "Gizlilik ve Veri Yönetimi Politikası",
    short: "Hangi veriyi neden tutuyoruz, ne kadar süreyle saklıyoruz",
    body: `Son güncelleme: ${LEGAL_VERSION}

1) BİZ KİMİZ
LoungeLink, havalimanı lounge erişimi olan yolcular (host) ile lounge'a
misafir olarak girmek isteyen yolcuları (misafir) buluşturan bir eşleştirme
uygulamasıdır. LoungeLink bir şirket değildir; ${COMPANY} tarafından gerçek
kişi sıfatıyla (bireysel geliştirici olarak) geliştirilir ve işletilir.
Veri sorumlusu: ${COMPANY}. İletişim: ${CONTACT} · ${SITE}

2) LOUNGELINK LOUNGE ERİŞİMİ SATMAZ
Uygulama lounge girişi satmaz; lounge işletmecisi, kart veren kurum ya da
lounge programı adına hareket etmez ve bunlarla bağlantılı değildir. Host'un
kendi kart veya üyelik koşullarının izin verdiği misafir hakkını kullanmak
isteyip istemediğine host karar verir; LoungeLink yalnızca iki yolcunun
tanışmasına aracılık eder.

3) İŞLEDİĞİMİZ VERİLER
a) Hesap verileri: ad-soyad, e-posta adresi, telefon numarası, şifre
   (yalnızca geri döndürülemez biçimde şifrelenmiş özet olarak). Apple veya
   Google ile giriş yaparsan bu sağlayıcının bize ilettiği ad ve e-posta
   (Apple'ın "e-postamı gizle" adresi dahil).
b) Profil verileri: meslek/sektör, biyografi, konuşulan diller, profil
   fotoğrafı, LinkedIn adresi ve cinsiyet. Cinsiyet yalnızca kadın
   kullanıcılara yönelik güvenlik seçenekleri için kullanılır ("Yalnızca
   kadınlar görsün" seçeneği ve yalnız kadın host'ları gösterme filtresi).
   Bu seçeneği açarsan profilinde "Kadın yolcu" ibaresi görünür.
c) Seyahat verileri: havalimanı, tarih, saat aralığı, uçuş numarası,
   seyahat amacı. "Bulunduğum havalimanı"na basarsan cihazının yaklaşık
   konumu yalnız o an, en yakın havalimanını cihazında bulmak için okunur;
   konumun bize gönderilmez ve saklanmaz.
d) Host verileri: lounge erişim kaynağı beyanı (ör. hangi kart veya
   program), misafir hakkı sayısı, açılan ilanlar, host başvurusu.
e) Doğrulama verileri: e-posta ve telefon doğrulama sonucu. "Doğrulanmış
   profil" rozeti, e-posta ve telefonun doğrulanmış, profil fotoğrafı ve
   mesleğin girilmiş olmasından otomatik olarak oluşur. KİMLİK BELGESİ,
   SELFIE YA DA BİYOMETRİK VERİ İSTEMİYOR VE İŞLEMİYORUZ. Biniş kartı
   barkodu cihazında okunur; görüntü cihazından çıkmaz. Sunucuya yalnızca
   uçuş bilgisi (havalimanı, tarih, uçuş kodu, kabin) ve rezervasyon
   kodunun geri döndürülemez özeti gönderilir.
f) Etkileşim verileri: istekler, davetler, bağlantılar, oturum kayıtları,
   sohbet mesajları, puanlar ve yorumlar.
g) Güven ve güvenlik verileri: güven puanı bileşenleri, şikayet, engelleme
   ve itiraz kayıtları.
h) Satın alma verileri: satın aldığın kredi paketi veya abonelik, tarihi,
   tutarı ve mağaza işlem numarası. Ödemeyi Apple (App Store) veya Google
   (Google Play) alır; kart ve ödeme bilgilerin bize HİÇ ulaşmaz.
i) Teknik veriler: cihaz/uygulama sürümü, hata kayıtları, bildirim için
   cihaz jetonu, uçuş sorgusu sayaçları.
j) Onay kayıtları: kabul ettiğin sözleşmeler, 18 yaş beyanı ve (verdiysen)
   pazarlama bildirimi izni; tarih ve metin sürümüyle.
Reklam amaçlı takip yapmıyoruz; verilerini reklam ağlarıyla paylaşmıyor ve
satmıyoruz. Uygulama reklam kimliği okumaz.

4) NEDEN İŞLİYORUZ (KVKK m.5 hukuki sebepleri)
· Sözleşmenin kurulması ve ifası (m.5/2-c): hesap açma, profil, eşleştirme,
  sohbet, oturum yönetimi, bildirimler, kredi ve puan işlemleri, satın
  alınan kredinin ve aboneliğin hesabına tanımlanması, senin açtığın
  güvenlik seçenekleri (cinsiyet dahil).
· Hukuki yükümlülük (m.5/2-ç): vergi ve muhasebe kayıtları, yetkili
  mercilerin talepleri, hukuka aykırı içeriğin kaldırılması.
· Bir hakkın tesisi, kullanılması veya korunması (m.5/2-e): uyuşmazlık,
  şikayet ve itirazlarda sohbet ve oturum kayıtlarının saklanması, onay
  kayıtları.
· Meşru menfaat (m.5/2-f): dolandırıcılık ve kötüye kullanımın önlenmesi,
  güven puanının hesaplanması, hata takibi, hizmetin güvenliği.
· Açık rıza (m.5/1): YALNIZCA kampanya ve duyuru bildirimleri. Bu izni
  vermek isteğe bağlıdır; vermezsen uygulamanın hiçbir özelliği kısılmaz.

5) KİMLERLE PAYLAŞIYORUZ
· Karşı taraf: bir istek/davet kabul edildiğinde adın, profilin ve seyahat
  bilgilerinin görünen kısmı karşı tarafa açılır. Keşif ekranında profilin,
  senin seçtiğin görünürlük ayarına göre görünür.
· Hizmet sağlayıcılar (veri işleyen; verini kendi amaçları için kullanamaz):
  – Supabase: veritabanı, oturum ve dosya depolama (AB/Frankfurt)
  – Google Firebase Authentication: telefon numarasının SMS koduyla
    doğrulanması (telefon numaran ve cihaz/uygulama doğrulama bilgisi)
  – Expo ve Apple / Google bildirim servisleri: anlık bildirim gönderimi
  – Apple ve Google: uygulama mağazası, ödeme ve "ile giriş yap" hizmetleri
  – RevenueCat: mağaza satın alımlarının doğrulanması ve abonelik durumu
    (yalnızca hesap kimliğin ve satın alma kaydın; adın ve e-postan
    gönderilmez)
  – Uçuş bilgisi sağlayıcısı (aviationstack): girdiğin uçuş numarası ve
    tarih; kimliğin gönderilmez
  – Resend: hesap e-postalarının (doğrulama, şifre sıfırlama) gönderimi
  – Cloudflare: alan adı, DNS ve e-posta yönlendirme
  – Vercel: web sitesi ve yönetim panelinin barındırılması
· Lounge işletmecileri: kişisel veri PAYLAŞILMAZ. Paylaşılabilecek tek şey,
  kimseye indirgenemeyecek biçimde toplulaştırılmış talep sayılarıdır (ör.
  "IST'te salı 14:00-18:00 aralığında X kişi"); küçük gruplar hiç
  raporlanmaz. Anonim veri kişisel veri değildir.
· Yetkili merciler: yasal talep halinde, talep sınırında.

6) YURT DIŞINA AKTARIM
LoungeLink'in kullandığı hizmet sağlayıcıların tamamı Türkiye dışındadır.
Ana veritabanı ve dosyalar Supabase'in AB (Frankfurt, Almanya) bölgesinde
tutulur. Telefon doğrulama (Google Firebase), bildirim (Expo, Apple,
Google), satın alma doğrulama (RevenueCat), uçuş bilgisi (aviationstack),
e-posta gönderimi (Resend), web barındırma (Vercel) ve alan adı/DNS
(Cloudflare) hizmetleri ABD'de veya başka ülkelerde sunucu kullanır. Bu
aktarımlar KVKK m.9 çerçevesinde, yalnızca hizmetin gerektirdiği veriyle
sınırlı olarak yapılır.

7) SAKLAMA SÜRELERİ
Aşağıdaki süreler dolduğunda kayıtlar her gece çalışan otomatik bir işle
silinir ya da anonimleştirilir.
· Hesap ve profil verileri: hesabın açık olduğu süre boyunca.
· Sohbet mesajları: gönderildiği tarihten itibaren 24 ay.
· Bildirimler, hata kayıtları, uçuş sorgu kayıtları: 12 ay.
· Şikayet ve itiraz kayıtları: 5 yıl.
· Satın alma kayıtları: vergi ve muhasebe mevzuatının öngördüğü süre boyunca
  (en çok 10 yıl).
· Onay kayıtları: hesap süresince ve hesap silindikten sonra 10 yıl
  (sözleşmeden doğan zamanaşımı süresi).
· Silinen hesabın e-posta adresinin geri döndürülemez özeti (adresin
  kendisi değil): 5 yıl. Kötüye kullanım nedeniyle kapatılan hesapların
  yeniden açılmasını ve hoş geldin kredisinin tekrar alınmasını önlemek
  için tutulur.
HESABINI SİLMEK: Uygulamada Profil › Ayarlar › Hesabı Sil adımından ya da
${SITE}/hesap-sil sayfasından istediğin an silebilirsin. Silme talebiyle
hesabın hemen kapanır ve profil fotoğrafı dosyan silinir; 14 gün içinde
${SUPPORT} adresine yazarak vazgeçersen hesabın geri açılabilir. 14 günün
sonunda adın, iletişim bilgilerin, cinsiyetin, biyografin, gelecek
seyahatlerin, bildirimlerin ve tercihlerin silinir, hesabın
anonimleştirilir. Karşı tarafın sohbet geçmişindeki mesajların ve geçmiş
oturum kayıtları adın olmadan, yukarıdaki süreler dolana kadar kalır.
Mağazadan aldığın aboneliği hesabını silmeden önce mağaza ayarlarından
iptal etmelisin; hesabını silmek mağaza aboneliğini kendiliğinden
durdurmaz.

8) HAKLARIN (KVKK m.11)
Kişisel verinin işlenip işlenmediğini öğrenme, işlenmişse bilgi isteme,
işlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme, yurt
içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme, eksik veya
yanlış işlenmişse düzeltilmesini, KVKK m.7 şartlarıyla silinmesini veya yok
edilmesini ve bu işlemlerin aktarılan üçüncü kişilere bildirilmesini
isteme, münhasıran otomatik sistemlerle analiz edilmesi sonucu aleyhine
bir sonuç çıkmasına itiraz etme ve kanuna aykırı işleme nedeniyle zarara
uğrarsan zararının giderilmesini talep etme hakların vardır.
Başvuru: uygulamaya kayıtlı e-posta adresinden ${CONTACT} adresine yaz.
Posta yoluyla yazılı başvurmak istersen posta adresimizi aynı adresten
iste; 7 gün içinde bildiririz. Başvurun en geç 30 gün içinde ücretsiz
yanıtlanır. Başvurun reddedilir, yanıtı yetersiz bulursan ya da süresinde
yanıt alamazsan, yanıtı öğrendiğin tarihten itibaren 30 gün ve her halde
başvuru tarihinden itibaren 60 gün içinde Kişisel Verileri Koruma
Kurulu'na şikâyette bulunabilirsin.

9) GÜVENLİK
Veritabanı satır bazlı erişim kurallarıyla korunur; ayrıcalıklı işlemler
yalnızca sunucu tarafı fonksiyonlarla yapılır. Şifreler geri döndürülemez
özet olarak saklanır; bağlantılar şifrelidir. Yine de hiçbir sistem %100
güvenli değildir; şüpheli bir durumda ${CONTACT} adresine bildir.

10) ÇOCUKLAR
Uygulama 18 yaş altına yönelik değildir; 18 yaşından küçüklerin hesap
açmasına izin verilmez.

11) DEĞİŞİKLİKLER
Bu politikada önemli bir değişiklik olursa uygulama içinde bildirilir.
Güncel metin her zaman ${SITE}/gizlilik adresindedir.`,
  },

  aydinlatma: {
    title: "Aydınlatma Metni",
    short: "KVKK m.10 kapsamında kısa bilgilendirme",
    body: `Son güncelleme: ${LEGAL_VERSION}

Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu'nun 10. maddesi ve
Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar
Hakkında Tebliğ uyarınca, veri sorumlusu sıfatıyla ${COMPANY} tarafından
hazırlanmıştır.

VERİ SORUMLUSU
${COMPANY} (gerçek kişi; LoungeLink uygulamasının geliştiricisi ve
işleteni). İletişim: ${CONTACT}. Posta yoluyla yazılı başvuru için posta
adresimizi bu adresten talep edebilirsin; 7 gün içinde bildirilir.

HANGİ VERİ, HANGİ AMAÇLA, HANGİ HUKUKİ SEBEPLE
· Kimlik ve iletişim (ad-soyad, e-posta, telefon): hesabın oluşturulması,
  doğrulama ve hizmet bildirimleri. Sebep: sözleşmenin ifası (m.5/2-c).
· Profil (meslek, biyografi, diller, fotoğraf, LinkedIn): eşleştirme ve
  karşı tarafın güven kararı. Sebep: sözleşmenin ifası (m.5/2-c).
· Cinsiyet: yalnızca kadın kullanıcılara yönelik güvenlik seçenekleri.
  Sebep: sözleşmenin ifası (m.5/2-c); seçenekleri sen açarsın.
· Seyahat (havalimanı, tarih, saat, uçuş no): host-misafir eşleşmesi.
  Sebep: sözleşmenin ifası (m.5/2-c).
· Lounge erişim beyanı ve misafir hakkı: host'un ilan açabilmesi.
  Sebep: sözleşmenin ifası (m.5/2-c).
· Etkileşim, oturum ve sohbet kayıtları: hizmetin ifası, uyuşmazlık çözümü,
  kötüye kullanımın önlenmesi. Sebep: sözleşmenin ifası (m.5/2-c), hakkın
  korunması (m.5/2-e), meşru menfaat (m.5/2-f).
· Satın alma kayıtları: kredinin/aboneliğin hesabına tanımlanması, iade ve
  vergi yükümlülükleri. Sebep: sözleşmenin ifası (m.5/2-c), hukuki
  yükümlülük (m.5/2-ç). Ödeme bilgilerin bize ulaşmaz.
· Teknik kayıtlar (hata, cihaz jetonu): hizmetin güvenliği ve hata takibi.
  Sebep: meşru menfaat (m.5/2-f).
· Pazarlama bildirimi izni: yalnızca izin verirsen kampanya ve duyuru
  bildirimleri. Sebep: açık rıza (m.5/1); istediğin an geri alabilirsin.
Kimlik belgesi, selfie, biyometrik veri veya başka bir özel nitelikli
kişisel veri istemiyor ve işlemiyoruz.

TOPLAMA YÖNTEMİ
Veriler doğrudan senin uygulamaya girdiğin bilgilerden, Apple/Google ile
giriş yaptığında bu sağlayıcıların ilettiği bilgilerden ve kullanım
sırasında otomatik oluşan kayıtlardan elektronik ortamda toplanır.

KİMLERE, HANGİ AMAÇLA AKTARILIR
Eşleştiğin kişiye (hizmetin ifası için); barındırma, telefon doğrulama,
bildirim, ödeme doğrulama, uçuş bilgisi ve e-posta hizmeti sağlayıcılarına
(Supabase, Google Firebase, Expo, Apple, Google, RevenueCat, aviationstack,
Resend, Cloudflare, Vercel) yalnızca bu hizmetleri sunabilmeleri için;
yasal talep halinde yetkili mercilere. Bu sağlayıcıların tamamı yurt
dışındadır; aktarım KVKK m.9 çerçevesinde yapılır. Lounge işletmecileriyle
kişisel veri paylaşılmaz.

HAKLARIN
KVKK m.11'deki haklarını (bilgi isteme, düzeltme, silme, itiraz, zararın
giderilmesi dahil) uygulamaya kayıtlı e-posta adresinden ${CONTACT}
adresine yazarak kullanabilirsin. Yazılı (posta) başvuru için posta
adresimizi aynı adresten isteyebilirsin. Ayrıntı: Gizlilik Politikası §8.`,
  },

  acikRiza: {
    title: "Açık Rıza Metni",
    short: "Yalnızca kampanya bildirimleri için — isteğe bağlı, geri alınabilir",
    body: `Son güncelleme: ${LEGAL_VERSION}

LoungeLink'te açık rızaya bağlı TEK bir işlem vardır. Uygulamanın geri
kalanı açık rızaya değil, Aydınlatma Metni'nde yazan diğer hukuki
sebeplere dayanır.

KAMPANYA VE DUYURU BİLDİRİMLERİ
İzin verirsen, yeni özellikler, kampanyalar, indirimler ve davet ödülleri
hakkında UYGULAMA BİLDİRİMİ gönderebiliriz. Bunun için hesabındaki ad ve
plan, havalimanı ve güven puanı gibi profil bilgileri, sana uygun duyuruyu
seçmek amacıyla kullanılır.
· Bu izin tamamen isteğe bağlıdır. Kayıtta ayrı ve işaretsiz bir kutuyla
  sorulur; vermezsen hiçbir özellik kısılmaz.
· Yalnız uygulama bildirimi kullanılır. Ticari SMS, arama ya da e-posta
  göndermiyoruz.
· İstek, oturum ve güvenlik bildirimleri pazarlama değildir; hizmetin
  parçası olarak bu izinden bağımsız gönderilir.
· İznini istediğin an Profil › Ayarlar › Bildirimler › "Kampanya ve
  duyurular" anahtarından ya da ${CONTACT} adresine yazarak geri
  alabilirsin. Her kampanya bildiriminde nasıl kapatılacağı yazar.
· İznin verildiği ve geri alındığı tarih, ispat amacıyla onay kaydı olarak
  saklanır.`,
  },

  cerez: {
    title: "Çerez Politikası",
    short: "Mobil uygulamada ve web sitesinde hangi izler tutuluyor",
    body: `Son güncelleme: ${LEGAL_VERSION}

MOBİL UYGULAMA
Mobil uygulamada tarayıcı çerezi kullanılmaz. Cihazının yerel depolamasında
yalnızca şunlar tutulur:
· Oturum jetonu: her açılışta yeniden giriş yapmaman için (zorunlu).
· Dil, tema ve tanıtım turunu görüp görmediğin (işlevsel).
· Bildirim jetonu: bildirim iznini verdiysen, bildirim gönderebilmek için.
Uygulama reklam kimliği (IDFA/AAID) okumaz ve seni uygulamalar arasında
takip etmez. Bu kayıtları çıkış yaparak ya da uygulamayı silerek
temizleyebilirsin.

WEB SİTESİ
· Site, reklam veya profil çıkarma amaçlı çerez KULLANMAZ.
· Ziyaret sayısını ölçmek için, kullanılıyorsa, çerez koymayan, IP adresi
  saklamayan ve seni tanımlamayan bir sayaç çalışır; kişisel veri
  işlenmediği için izin penceresi gösterilmez.

YÖNETİM PANELİ
Yalnızca LoungeLink ekibinin kullandığı yönetim panelinde oturum ve
güvenlik için zorunlu çerezler kullanılır.

TERCİHLERİNİ DEĞİŞTİRME
Tarayıcı ayarlarından çerezleri silebilir veya engelleyebilirsin.`,
  },

  platform: {
    title: "Platform Sözleşmesi ve Kullanım Koşulları",
    short: "Kullanım koşulları, kredi ve abonelik kuralları, yasaklar",
    body: `Son güncelleme: ${LEGAL_VERSION}

1) TARAFLAR VE KONU
Bu sözleşme, LoungeLink uygulamasını geliştiren ve işleten ${COMPANY}
(gerçek kişi; bundan sonra "LoungeLink") ile uygulamayı kullanan kişi
("kullanıcı") arasındadır. Konusu, aynı havalimanında bulunan yolcuların
tanışmasına aracılık eden uygulamanın kullanımıdır. İletişim: ${SUPPORT}

2) LOUNGELINK'İN ROLÜ
· LoungeLink bir tanışma ve eşleştirme ARACIDIR. Lounge erişimi satmaz,
  kiralamaz ya da devretmez; lounge işletmecisi, seyahat acentesi, kart
  veren kurum ya da lounge programı değildir ve bunlar adına hareket
  etmez.
· Uygulamada geçen lounge, kart, banka ve program adları sahiplerine
  aittir; yalnızca bilgi amacıyla anılır. LoungeLink bu kurumlarla
  bağlantılı değildir, onlar tarafından onaylanmamıştır.
· Uygulamadaki salon ve misafir kuralı bilgileri yol göstericidir;
  güncelliği garanti edilmez. Lounge'a giriş kararı her zaman lounge
  işletmecisine ve kartın/programın koşullarına aittir.

3) HESAP
Hesap açan kişi 18 yaşını doldurmuş olmalı, gerçek adını kullanmalı ve
bilgilerinin doğruluğundan sorumlu olmalıdır. Hesabını başkasına
devredemezsin. Hesabını istediğin an uygulama içinden silebilirsin.

4) HOST'UN YÜKÜMLÜLÜKLERİ
· Misafir hakkını yalnızca kendi kartının veya üyeliğinin koşullarının
  izin verdiği ölçüde kullanır. Kart/program misafir kabul etmiyorsa ya da
  hakkın bu şekilde kullanılmasını yasaklıyorsa ilan açmaz. Koşulları
  kartını veren kurumdan öğrenmek host'un sorumluluğundadır.
· Yalnızca gerçekten sahip olduğu misafir hakkı kadar yer açar.
· Misafirden para, hediye kartı, mil, puan ya da başka bir bedel istemez,
  kabul etmez.
· İlan açtığı tarih/saatte lounge'da bulunmayacaksa ilanı iptal eder.
· Misafirini lounge kurallarına uygun şekilde ağırlar.

5) MİSAFİRİN YÜKÜMLÜLÜKLERİ
· Kabul edilen buluşmaya zamanında gelir; gelemeyeceğini önceden bildirir.
· Host'a para veya başka bir bedel teklif etmez.
· Lounge, havayolu ve havalimanı kurallarına uyar; giriş kararının lounge
  işletmecisine ait olduğunu kabul eder.

6) KREDİ VE LOUNGEPUAN
· Kredi, LoungeLink'in eşleştirme hizmetinin bedelidir: bir host'un
  ilanına istek gönderme hakkıdır. Lounge girişinin bedeli değildir ve
  host'a aktarılmaz.
· İstek gönderirken hesabından 1 kredi tutulur.
· İstek reddedilir, iptal edilir veya 72 saat yanıtsız kalırsa kredi iade
  edilir. Kabul edilen buluşmada kapıda içeri alınmazsan da iade edilir.
· İstek kabul edilirse kredi kullanılmış sayılır.
· Kredi; abonelik planının aylık payından gelir, uygulama içinden paket
  olarak satın alınabilir ya da ağırlayarak kazanılır. Kredi nakde
  çevrilemez, devredilemez, hesap silindiğinde sona erer.
· Ağırlama kredisi ve LoungePuan, platformu kullanmanın katılım
  ödülleridir; misafir hakkının karşılığı ya da satış bedeli değildir.
· Ağırlama kredisi: Sık Uçan ve Jetset planlarında tamamlanan her
  ağırlama 1 kredi kazandırır. Ücretsiz Yolcu planında yalnız ilk
  ağırlamada bir kez 1 kredi verilir; 30 gün içinde 3 kişi ağırlayan
  host'a Sık Uçan 30 gün ücretsiz açılır. Aynı kişilerle kısa sürede
  tekrarlanan buluşmalar ve günlük üst sınır kredi kazandırmaz.
· Abonelik planının aylık kredisi o ay içindir; kullanılmayan kısmı bir
  sonraki aya devretmez. Satın alınan paket kredisi ve ağırlayarak
  kazanılan kredi süresizdir.
· Ücretsiz Yolcu planında kayıtta 1 kredi verilir; aylık kredi yoktur.
· Bağlantı (Tanış) istekleri plana göre haftalık sınırlıdır: Yolcu 3,
  Sık Uçan 15, Jetset sınırsız. Son 7 gün içinde gönderilen istekler
  sayılır; 7 günü dolan istek hakkı geri açar.
· Aynı uçuş için birden fazla host'a başvurduysan, biri kabul edince aynı
  havalimanı ve gün için bekleyen diğer isteklerin kendiliğinden geri
  çekilir ve kredileri iade edilir.
· LoungePuan: tamamlanan her buluşmada iki taraf da kendi planına göre
  puan kazanır (Yolcu 100, Sık Uçan 250, Jetset 500); kabul edilen her
  arkadaş davetinde iki tarafa 500 puan verilir. LoungePuan bir para
  birimi değildir; nakde çevrilemez, devredilemez; ödüllerin puan
  karşılığı ve stokları değişebilir.
· Plan ayrıcalıkları (ödüller): ücretli plan üyeleri ödülleri planlarının
  indirim oranı kadar daha az puanla alabilir; yeni ödüller bir süre yalnız
  ücretli plan üyelerine açık olabilir (erken erişim). Oranlar ve süreler
  mağazada ve plan ekranında yazar ve değişebilir; ödülü aldığın anda
  mağazada sana gösterilen puan düşülür.

7) UYGULAMA İÇİ SATIN ALMA, ABONELİK VE CAYMA HAKKI
· Kredi paketleri ve abonelik planları (Sık Uçan, Jetset) yalnızca App
  Store veya Google Play üzerinden, mağazanın ödeme sistemiyle satın
  alınır. Fiyat, satın alma ekranında mağazanın gösterdiği tutardır.
· Abonelik seçtiğin dönem (aylık ya da yıllık) için ücretlendirilir ve
  dönem bitiminden en az 24 saat önce iptal edilmezse aynı ücretle
  otomatik yenilenir. Aboneliği mağaza hesap ayarlarından yönetebilir ve
  iptal edebilirsin; iptal, içinde bulunduğun dönemin sonunda geçerli
  olur ve o güne kadar planın sürer.
· Kuruluş fiyatı: kuruluş fiyatı döneminde (plan ekranında yazılı tarihe
  kadar) abone olanlar, abonelikleri kesintisiz sürdükçe aynı fiyattan
  yenilenir. Abonelik iptal edilip sonradan yeniden başlatılırsa o günkü
  fiyat geçerli olur.
· Cayma hakkı: kredi paketleri ve abonelikler elektronik ortamda anında
  ifa edilen hizmet ve dijital içeriktir. Satın almayı onayladığında
  ifaya hemen başlanmasını kabul etmiş olursun; bu nedenle Mesafeli
  Sözleşmeler Yönetmeliği m.15/1-ğ uyarınca cayma hakkı kullanılamaz.
  Bu, mağazanın kendi iade süreçlerini ve tüketici mevzuatından doğan
  diğer haklarını sınırlamaz.
· İade talepleri mağazanın kendi süreciyle (Apple: reportaproblem.apple.com
  · Google Play: hesabındaki sipariş geçmişi) yapılır. Mağaza bir kredi
  paketini iade ederse, iade edilen kredi hesabından düşülür.
· App Store üzerinden indirilen uygulama için Apple'ın Standart Lisans
  Sözleşmesi (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
  de geçerlidir; çelişen bir hüküm olursa kullanıcı lehine olan uygulanır.

8) PARA VE BEDEL ALIŞVERİŞİ KESİNLİKLE YASAKTIR
Lounge girişi ya da misafir hakkı karşılığında kullanıcıların birbirine
para, hediye kartı, mil, puan veya herhangi bir bedel teklif etmesi ya da
alması yasaktır. Bu hem bu sözleşmenin hem de çoğu kart ve lounge
programının kurallarının ihlalidir; hesabın kalıcı olarak kapatılmasıyla
sonuçlanır. Böyle bir teklif alırsan uygulamadan bildir.

9) KULLANICI İÇERİĞİ VE BİLDİRİM-KALDIRMA
· Profil, sohbet, not ve yorumlarda taciz, tehdit, nefret söylemi,
  ayrımcılık, müstehcen veya cinsel içerik, şiddet, dolandırıcılık, spam ve
  başkasının kişisel verisini paylaşmak yasaktır; bunlara sıfır tolerans
  uygulanır.
· İçerikten onu paylaşan kullanıcı sorumludur. LoungeLink kullanıcı
  içeriğini önceden denetlemez.
· Hukuka aykırı olduğunu düşündüğün bir içeriği ya da kişiyi uygulamadaki
  "Bildir" ile ya da ${SUPPORT} adresine yazarak bildirebilirsin.
  Bildirimler en geç 24 saat içinde incelenir; hukuka aykırı içerik
  yayından kaldırılır ve ihlali yapan hesap uyarılır, kısıtlanır veya
  kalıcı olarak kapatılır. Yetkili mercilerin kararları ayrıca uygulanır.
· Her kullanıcı bir kişiyi uygulama içinden engelleyebilir.

10) YASAK DAVRANIŞLAR
Lounge girişini ya da misafir hakkını satmak, kiralamak, takas etmek;
sahte kimlik veya başkasının kimliğini kullanmak; taciz, ayrımcılık,
tehdit; ticari tanıtım ve spam; başka kullanıcıların verilerini toplamak;
güvenlik önlemlerini aşmak; otomatik araçlarla erişmek.

11) BİLDİRİMLER
İstek, oturum ve güvenlik bildirimleri hizmetin parçasıdır. Kampanya ve
duyuru bildirimleri yalnızca iznin varsa gönderilir ve Ayarlar'dan
kapatılabilir.

12) GÜVENLİK ARAÇLARI
Şikayet, engelleme, itiraz ve "Yalnızca kadınlar görsün" seçeneği her
uygun kullanıcıya açıktır. Kararlara ${SUPPORT} üzerinden itiraz
edebilirsin.

13) SORUMLULUK
LoungeLink, kullanıcıların birbirine karşı davranışlarından, lounge
girişinin gerçekleşmemesinden, kart veya program koşullarından ya da lounge
işletmecisinin kararlarından sorumlu değildir. Uygulamanın kesintisiz
çalışacağı garanti edilmez. Bu hükümler, tüketici mevzuatının emredici
koruma hükümlerini sınırlamaz.

14) FESİH
Hesabını istediğin an kapatabilirsin. LoungeLink, bu sözleşmenin ağır
ihlali halinde hesabı askıya alabilir veya kapatabilir.

15) DEĞİŞİKLİKLER
Sözleşmede önemli bir değişiklik olursa uygulama içinde bildirilir ve
yürürlük tarihinden önce görürsün. Güncel metin ${SITE}/kosullar
adresindedir.

16) UYGULANACAK HUKUK
Türkiye Cumhuriyeti hukuku uygulanır; uyuşmazlıklarda parasal sınırlara
göre tüketici hakem heyetleri ve tüketici mahkemeleri yetkilidir.`,
  },
};

// Giriş/kayıt ekranının altındaki satırın sırası (MVP referansı)
export const LEGAL_ORDER = ["gizlilik", "acikRiza", "cerez", "aydinlatma", "platform"];
