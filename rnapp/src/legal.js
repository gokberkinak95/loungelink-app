// ============================================================
// LoungeLink · Hukuki metinler (TEK KAYNAK)
//
// ⚠️ Bunlar AVUKAT ONAYINDAN GEÇMEMİŞ taslaklardır. KVKK (6698), GDPR ve
// 6563 sayılı E-Ticaret Kanunu'nun beklediği başlıkları LoungeLink'in
// GERÇEK veri akışına göre yazdım (başka bir şirketin metni kopyalanmadı).
// Yayın öncesi bir avukatın gözden geçirmesi önerilir.
//
// 15 Ekim 2026 — BİREYSEL YAPI. Şirket kurulumu ertelendi (Gökberk); uygulama
// App Store ve Google Play'e BİREYSEL geliştirici hesabından yüklenecek. Veri
// sorumlusu bu yüzden bir GERÇEK KİŞİDİR. Mağazalarda satıcı adı olarak da aynı
// ad görünür; metinlerdeki ad ile mağazadaki ad AYNI olmalı (inceleme bunu arar).
// Şirket kurulduğunda yalnız aşağıdaki üç sabit değişir.
//
// AYNI METİN backoffice'te ve sitede de yayınlanır (public URL) çünkü Google
// Play ve App Store, mağaza listesinde ERİŞİLEBİLİR BİR GİZLİLİK POLİTİKASI
// URL'İ ister — uygulama içi ekran tek başına yetmez.
//
// KOPYALAMA YÖNÜ (değiştirdikten sonra):
//     rnapp/src/legal.js  →  backoffice/lib/legal.js
//     rnapp/src/legal.js  →  website/lib/legal-source.js
// Tek yönlü; asla tersi. (`node check.js` yer tutucu kalmadığını denetler.)
// ============================================================

export const LEGAL_VERSION = "2026-10-19";

// Veri sorumlusu: gerçek kişi (bireysel geliştirici). Mağaza hesabındaki ad ile aynı.
const COMPANY = "Gökberk İnak";
const ADDRESS = "İstanbul, Türkiye — APA GIZ PLAZA";
// Tek alan adı (loungelink.co) — üç kopya (app · site · BO) aynı adresi taşır.
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
Veri sorumlusu: ${COMPANY}, ${ADDRESS}. İletişim: ${CONTACT} · ${SITE}

2) LOUNGELINK LOUNGE ERİŞİMİ SATMAZ
Uygulama, lounge girişi satmaz ve lounge işletmecisi adına hareket etmez.
Host'un halihazırda sahip olduğu misafir hakkının paylaşılmasına aracılık
eder. Bu, hangi verileri neden işlediğimizi doğrudan belirler.

3) İŞLEDİĞİMİZ VERİLER
a) Hesap verileri: ad-soyad, e-posta, telefon numarası, şifre (yalnızca
   geri döndürülemez şekilde şifrelenmiş özet olarak; düz metin şifre
   hiçbir yerde tutulmaz). Apple veya Google ile giriş yaparsan bu
   sağlayıcının bize ilettiği ad ve e-posta (Apple'ın "e-postamı gizle"
   adresi dahil).
b) Profil verileri: meslek/sektör, biyografi, konuşulan diller, profil
   fotoğrafı, LinkedIn adresi, cinsiyet (yalnızca kadın güvenlik modunun
   çalışması için).
c) Seyahat verileri: havalimanı, tarih, saat aralığı, uçuş numarası,
   seyahat amacı.
d) Host verileri: lounge erişim kaynağı beyanı (ör. Priority Pass),
   misafir hakkı sayısı, açılan ilanlar, host başvurusu.
e) Doğrulama verileri: kimlik doğrulamayı seçersen yüklediğin kimlik
   belgesi ve selfie. Bunlar yalnızca bir yetkilinin elle incelemesi için
   kullanılır, biyometrik eşleştirme yapılmaz ve karar verildikten sonra
   silinir; yalnızca "doğrulandı / doğrulanmadı" sonucu saklanır. Biniş
   kartı barkodu cihazında okunur; görüntü cihazından çıkmaz, yalnızca
   okunan uçuş bilgisi doğrulama için kullanılır.
f) Etkileşim verileri: istekler, davetler, bağlantılar, oturum kayıtları,
   sohbet mesajları, puanlar ve yorumlar.
g) Güven ve güvenlik verileri: güven puanı bileşenleri, doğrulama
   durumları, şikayet, engelleme ve itiraz kayıtları.
h) Satın alma verileri: satın aldığın kredi paketi veya abonelik, tarihi,
   tutarı ve mağaza işlem numarası. Ödemeyi Apple (App Store) veya Google
   (Google Play) alır; kart ve ödeme bilgilerin bize HİÇ ulaşmaz.
i) Teknik veriler: cihaz/uygulama sürümü, hata kayıtları, bildirim izni
   için cihaz jetonu.
Reklam amaçlı takip yapmıyoruz; verilerini reklam ağlarıyla paylaşmıyor ve
satmıyoruz.

4) NEDEN İŞLİYORUZ (hukuki sebep)
· Sözleşmenin kurulması ve ifası: hesap açma, eşleştirme, sohbet, oturum
  yönetimi, kredi/puan işlemleri, satın alınan kredinin ve aboneliğin
  hesabına tanımlanması.
· Meşru menfaat: dolandırıcılık ve kötüye kullanımın önlenmesi, güven
  puanının hesaplanması, hizmetin iyileştirilmesi, hata takibi.
· Açık rıza: profil fotoğrafının keşif ekranında gösterilmesi, isteğe
  bağlı kimlik doğrulaması, pazarlama iletileri (varsa).
· Hukuki yükümlülük: vergi ve muhasebe kayıtları, talep halinde yetkili
  mercilere bilgi verilmesi.

5) KİMLERLE PAYLAŞIYORUZ
· Karşı taraf: bir istek/davet kabul edildiğinde adın, profilin ve seyahat
  bilgilerinin görünen kısmı karşı tarafa açılır.
· Hizmet sağlayıcılar (veri işleyen; verini kendi amaçları için
  kullanamaz):
  – Supabase: veritabanı, kimlik doğrulama ve dosya depolama (AB/Frankfurt)
  – Expo ve Apple / Google bildirim servisleri: anlık bildirim gönderimi
  – Apple ve Google: uygulama mağazası, ödeme ve "ile giriş yap" hizmetleri
  – RevenueCat: mağaza satın alımlarının doğrulanması ve abonelik durumu
    (yalnızca hesap kimliğin ve satın alma kaydın; adın ve e-postan
    gönderilmez)
  – Resend: hesap e-postalarının (doğrulama, şifre sıfırlama) gönderimi
  – Cloudflare: alan adı, DNS ve e-posta yönlendirme
  – Vercel: web sitesi ve yönetim panelinin barındırılması
· Lounge işletmecileri: kimlik verisi PAYLAŞILMAZ. Yalnızca kimliksiz ve
  toplulaştırılmış talep istatistikleri (ör. "IST'te salı 14:00-18:00
  aralığında X kişi") paylaşılabilir; bir kişiye indirgenemeyecek eşiğin
  altındaki gruplar hiç raporlanmaz.
· Yetkili merciler: yasal talep halinde, talep sınırında.

6) YURT DIŞINA AKTARIM
Ana veritabanı AB bölgesindeki sunucularda (Frankfurt) barındırılır.
Yukarıdaki hizmet sağlayıcıların bir kısmı (bildirim, mağaza, satın alma
doğrulama, e-posta gönderimi) ABD'de veya başka ülkelerde sunucu kullanır.
Bu aktarımlar, KVKK m.9'un öngördüğü güvenceler (standart sözleşme)
çerçevesinde ve yalnızca hizmetin gerektirdiği veriyle sınırlı yapılır.

7) SAKLAMA SÜRELERİ
· Hesap ve profil verileri: hesabın açık olduğu süre boyunca.
· Sohbet ve oturum kayıtları: uyuşmazlık ve güvenlik incelemeleri için
  oturumun bitiminden itibaren 24 ay.
· Şikayet/itiraz kayıtları: 5 yıl.
· Satın alma kayıtları: vergi mevzuatının öngördüğü süre (10 yıl).
· Kimlik belgesi ve selfie: yalnızca inceleme süresince; kararla birlikte
  silinir.
· Hata kayıtları: 12 ay.
HESABINI SİLMEK: Uygulamada Profil › Ayarlar › Hesabı Sil adımından ya da
${SITE}/hesap-sil sayfasından istediğin an silebilirsin. Silme talebiyle
hesabın hemen kapanır; 14 gün içinde ${SUPPORT} adresine yazarak
vazgeçersen geri açılabilir. 14 günün
sonunda profilin, fotoğrafların ve seyahatlerin kaldırılır, hesabın
anonimleştirilir. Yukarıdaki yasal ve güvenlik amaçlı kayıtlar süresi
dolana kadar kimliğinle eşleştirilmeden, erişimi kısıtlı biçimde saklanır.
Mağazadan aldığın aboneliği hesabını silmeden önce mağaza ayarlarından
iptal etmelisin; hesabını silmek mağaza aboneliğini kendiliğinden
durdurmaz.

8) HAKLARIN (KVKK m.11)
Verilerine erişme, düzeltme, silme, işlemeye itiraz etme, aktarım
bilgisini isteme ve rızanı geri alma hakların vardır. Başvuru:
${CONTACT} (uygulamaya kayıtlı e-posta adresinden). En geç 30 gün içinde
yanıtlarız. Yanıtımızdan memnun kalmazsan Kişisel Verileri Koruma
Kurulu'na şikâyette bulunabilirsin.

9) GÜVENLİK
Veritabanı satır bazlı erişim kurallarıyla korunur; ayrıcalıklı işlemler
yalnızca sunucu tarafı fonksiyonlarla yapılır. Şifreler geri
döndürülemez özet olarak saklanır. Yine de hiçbir sistem %100 güvenli
değildir; şüpheli bir durumda ${CONTACT} adresine bildir.

10) ÇOCUKLAR
Uygulama 18 yaş altına yönelik değildir ve 18 yaşından küçüklerin hesap
açmasına izin verilmez.

11) DEĞİŞİKLİKLER
Bu politikada önemli bir değişiklik olursa uygulama içinde bildirilir.
Güncel metin her zaman ${SITE}/gizlilik adresindedir.`,
  },

  aydinlatma: {
    title: "Aydınlatma Metni",
    short: "KVKK m.10 kapsamında kısa bilgilendirme",
    body: `Son güncelleme: ${LEGAL_VERSION}

Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu'nun 10. maddesi
uyarınca, veri sorumlusu sıfatıyla ${COMPANY} tarafından hazırlanmıştır.

VERİ SORUMLUSU
${COMPANY} (gerçek kişi; LoungeLink uygulamasının geliştiricisi ve
işleteni), ${ADDRESS}. İletişim: ${CONTACT}

HANGİ VERİLER, HANGİ AMAÇLA
· Kimlik ve iletişim (ad-soyad, e-posta, telefon): hesabın oluşturulması,
  doğrulama, bildirimler.
· Profil (meslek, biyografi, diller, fotoğraf, LinkedIn): eşleştirme
  kalitesi ve karşı tarafın güven kararı.
· Cinsiyet: yalnızca kadın güvenlik modunun işlemesi için; bu alan
  eşleştirme sıralamasında kadın kullanıcı lehine güvenlik amacıyla
  kullanılır.
· Seyahat (havalimanı, tarih, saat, uçuş no): host-misafir eşleşmesi.
· Lounge erişim beyanı ve misafir hakkı: host'un ilan açabilmesi.
· Kimlik belgesi ve selfie (yalnızca isteğe bağlı doğrulamada): elle
  inceleme; kararla birlikte silinir.
· Etkileşim ve oturum kayıtları, sohbet: hizmetin ifası, uyuşmazlık
  çözümü, kötüye kullanımın önlenmesi.
· Satın alma kayıtları: satın alınan kredinin/aboneliğin hesabına
  tanımlanması, iade ve vergi yükümlülükleri. Ödeme bilgilerin bize
  ulaşmaz; ödemeyi Apple veya Google alır.
· Teknik kayıtlar: hata takibi ve güvenlik.

TOPLAMA YÖNTEMİ VE HUKUKİ SEBEP
Veriler doğrudan senin uygulamaya girdiğin bilgilerden, Apple/Google ile
giriş yaptığında bu sağlayıcıların ilettiği bilgilerden ve kullanım
sırasında otomatik olarak oluşan kayıtlardan elektronik ortamda toplanır.
Hukuki sebepler: sözleşmenin ifası, meşru menfaat, hukuki yükümlülük ve —
fotoğrafın gösterimi ile kimlik doğrulaması gibi hallerde — açık rıza.

AKTARIM
Karşı tarafa (eşleştiğin kişiye), barındırma, bildirim, ödeme doğrulama
ve e-posta hizmeti sağlayıcılarına (Supabase, Expo, Apple, Google,
RevenueCat, Resend, Cloudflare, Vercel), yasal talep halinde yetkili
mercilere aktarılabilir. Bu sağlayıcıların bir kısmı yurt dışındadır;
aktarım KVKK m.9'daki güvencelerle yapılır. Lounge işletmecileriyle
yalnızca kimliksiz ve toplulaştırılmış istatistikler paylaşılır.

HAKLARIN
KVKK m.11 kapsamındaki tüm haklarını ${CONTACT} adresine yazarak
kullanabilirsin.`,
  },

  acikRiza: {
    title: "Açık Rıza Metni",
    short: "Yalnızca rızaya bağlı işlemler — istediğin an geri alabilirsin",
    body: `Son güncelleme: ${LEGAL_VERSION}

Aşağıdaki işlemler hizmetin çalışması için ZORUNLU DEĞİLDİR; yalnızca
açık rızanla yapılır ve rızanı istediğin an geri alabilirsin. Rızanı geri
alman, hesabını kullanmanı engellemez — yalnızca ilgili özellik kapanır.

1) PROFİL FOTOĞRAFININ GÖSTERİLMESİ
Yüklediğin fotoğrafın keşif ekranında ve profilinde diğer kullanıcılara
gösterilmesine rıza veriyorsun. "Fotoğrafım yalnızca bağlantılarıma
görünsün" ayarıyla bu gösterimi daraltabilir, fotoğrafı silerek tamamen
kaldırabilirsin.

2) BİLDİRİMLER
Sana uygun bir host ilan açtığında, isteğine yanıt geldiğinde veya
oturumun başladığında bildirim göndermemize rıza veriyorsun. Cihaz
ayarlarından kapatabilirsin.

3) TANITIM VE KAMPANYA İLETİLERİ
Yeni özellikler, kampanyalar ve davet ödülleri hakkında e-posta/bildirim
almayı kabul ediyorsun. Bu rıza tamamen isteğe bağlıdır ve her iletide
çıkış bağlantısı bulunur.

4) KİMLİK DOĞRULAMASI
Kimlik doğrulamayı seçersen yüklediğin kimlik belgesi ve selfie'nin,
"doğrulanmış" rozeti verilmesi amacıyla bir yetkili tarafından elle
incelenmesine rıza veriyorsun. Biyometrik eşleştirme yapılmaz; belge ve
selfie kararla birlikte silinir.

5) TOPLULAŞTIRILMIŞ TALEP İSTATİSTİKLERİ
Seyahat bilgilerinin, KİMLİĞİNE ULAŞILAMAYACAK biçimde toplulaştırılarak
lounge işletmecileriyle talep istatistiği olarak paylaşılmasına rıza
veriyorsun. Kişi sayısı belirli bir eşiğin altındaysa o veri hiç
paylaşılmaz.

Rızanı geri almak için: Profil → Ayarlar → Gizlilik veya ${CONTACT}.`,
  },

  cerez: {
    title: "Çerez Politikası",
    short: "Mobil uygulamada ve web sitesinde hangi izler tutuluyor",
    body: `Son güncelleme: ${LEGAL_VERSION}

MOBİL UYGULAMA
Mobil uygulamada klasik anlamda tarayıcı çerezi kullanılmaz. Bunun yerine
cihazının yerel depolamasında şu bilgiler tutulur:
· Oturum jetonu: her açılışta tekrar giriş yapmaman için (zorunlu).
· Dil tercihi ve tanıtım turunu görüp görmediğin (zorunlu-işlevsel).
· Bildirim jetonu: bildirim gönderebilmek için (rızaya bağlı).
Uygulama reklam kimliği (IDFA/AAID) okumaz ve seni uygulamalar arasında
takip etmez. Bu kayıtları uygulamayı silerek veya çıkış yaparak
temizleyebilirsin.

WEB SİTESİ / YÖNETİM PANELİ
· Zorunlu çerezler: oturum ve güvenlik. Bunlar olmadan site çalışmaz.
· İşlevsel çerezler: dil ve arayüz tercihleri.
· Ölçümleme: yalnızca kimliksiz sayfa görüntüleme sayıları (kullanılıyorsa
  ilk girişte sorulur; reddedebilirsin).
Reklam veya profil çıkarma amaçlı üçüncü taraf takip çerezi
KULLANMIYORUZ.

TERCİHLERİNİ DEĞİŞTİRME
Tarayıcı ayarlarından çerezleri silebilir veya engelleyebilirsin; zorunlu
çerezleri engellersen oturum açman mümkün olmaz.`,
  },

  platform: {
    title: "Platform Sözleşmesi ve Kullanım Koşulları",
    short: "Kullanım koşulları, kredi ve abonelik kuralları, yasaklar",
    body: `Son güncelleme: ${LEGAL_VERSION}

1) TARAFLAR VE KONU
Bu sözleşme, LoungeLink uygulamasını geliştiren ve işleten ${COMPANY}
(gerçek kişi; bundan sonra "LoungeLink") ile uygulamayı kullanan kişi
("kullanıcı") arasındadır. Konusu, host ile misafirin havalimanı
lounge'larında buluşmasına aracılık eden uygulamanın kullanımıdır.
İletişim: ${SUPPORT}

2) LOUNGELINK'İN ROLÜ
LoungeLink bir ARACIDIR; lounge erişimi satmaz, lounge işletmecisi ya da
seyahat acentesi değildir. Lounge'a giriş kararı her zaman lounge
işletmecisine ve o lounge'un kurallarına aittir. Host'un misafir hakkının
geçerliliğinden ve lounge kurallarına uygunluğundan host sorumludur.

3) HESAP
Hesap açan kişi 18 yaşını doldurmuş olmalı, gerçek ad-soyadını kullanmalı
ve bilgilerinin doğruluğundan sorumlu olmalıdır. Hesabını başkasına
devredemezsin. Hesabını istediğin an uygulama içinden silebilirsin.

4) HOST'UN YÜKÜMLÜLÜKLERİ
· Yalnızca gerçekten sahip olduğu misafir hakkı kadar slot açar.
· İlan açtığı tarih/saatte lounge'da bulunmayacaksa ilanı iptal eder.
· Misafirini lounge kurallarına uygun şekilde ağırlar.

5) MİSAFİRİN YÜKÜMLÜLÜKLERİ
· Kabul edilen oturuma zamanında gelir; gelemeyeceğini önceden bildirir.
· Lounge, havayolu ve havalimanı kurallarına uyar.

6) KREDİ
· Kredi, bir host'a istek gönderme hakkıdır; lounge girişi satın almaz.
· İstek gönderirken hesabından 1 kredi tutulur.
· İstek reddedilir, iptal edilir veya 72 saat yanıtsız kalırsa kredi iade
  edilir. Kabul edilen buluşmada kapıda içeri alınmazsan da iade edilir.
· İstek kabul edilirse kredi kullanılmış sayılır.
· Kredi; abonelik planının aylık payından gelir, uygulama içinden paket
  olarak satın alınabilir ya da ağırlayarak kazanılır. Kredi nakde
  çevrilemez, devredilemez, hesap silindiğinde sona erer.
· Ağırlama kredisi: Sık Uçan ve Jetset planlarında tamamlanan her
  ağırlama 1 kredi kazandırır. Ücretsiz Yolcu planında yalnız ilk
  ağırlamada bir kez 1 kredi verilir; 30 gün içinde 3 kişi ağırlayan
  host'a Sık Uçan 30 gün ücretsiz açılır. Aynı kişilerle
  kısa sürede tekrarlanan buluşmalar ve günlük üst sınır kredi
  kazandırmaz.
· Abonelik planının aylık kredisi o ay içindir; kullanılmayan kısmı bir
  sonraki aya devretmez. Satın alınan paket kredisi ve ağırlayarak
  kazanılan kredi süresizdir.
· Ücretsiz Yolcu planında kayıtta 1 kredi verilir; aylık kredi yoktur.
· Bağlantı (Tanış) istekleri plana göre haftalık sınırlıdır: Yolcu 3,
  Sık Uçan 15, Jetset sınırsız. Son 7 gün içinde gönderilen istekler
  sayılır; 7 günü dolan istek hakkı geri açar.
· Aynı uçuş için birden fazla host'a başvurduysan, biri kabul edince
  aynı havalimanı ve gün için bekleyen diğer isteklerin kendiliğinden
  geri çekilir ve kredileri iade edilir.
· LoungePuan (ödül puanı): tamamlanan her buluşmada iki taraf da kendi
  planına göre puan kazanır (Yolcu 100, Sık Uçan 250, Jetset 500).
  LoungePuan bir para birimi değildir; nakde çevrilemez, devredilemez;
  ödüllerin puan karşılığı ve stokları değişebilir.

7) UYGULAMA İÇİ SATIN ALMA VE ABONELİK
· Kredi paketleri ve abonelik planları (Sık Uçan, Jetset) yalnızca App
  Store veya Google Play üzerinden, mağazanın ödeme sistemiyle satın
  alınır. Fiyat, satın alma ekranında mağazanın gösterdiği tutardır.
· Abonelik seçtiğin dönem (aylık ya da yıllık) için ücretlendirilir ve
  dönem bitiminden en az 24 saat önce iptal edilmezse aynı ücretle
  otomatik yenilenir. Aboneliği mağaza hesap ayarlarından yönetebilir ve
  iptal edebilirsin; iptal, içinde bulunduğun dönemin sonunda geçerli
  olur ve o güne kadar planın sürer.
· Kuruluş fiyatı: kuruluş fiyatı döneminde (uygulamadaki plan ekranında
  yazılı tarihe kadar) abone olanlar, abonelikleri kesintisiz sürdükçe
  aynı fiyattan yenilenir. Abonelik iptal edilip sonradan yeniden
  başlatılırsa o günkü fiyat geçerli olur.
· İade talepleri mağazanın kendi iade süreciyle (Apple: reportaproblem.
  apple.com · Google Play: hesabındaki sipariş geçmişi) yapılır. Mağaza
  bir kredi paketini iade ederse, iade edilen kredi hesabından düşülür.
· Dijital içerik anında ifa edildiğinden, satın aldığın kredi hesabına
  tanımlandıktan sonra cayma hakkı (6502 s.K. ve Mesafeli Sözleşmeler
  Yönetmeliği m.15/ğ) kullanılamaz; mağazanın iade hakları saklıdır.
· App Store üzerinden indirilen uygulama için Apple'ın Standart Lisans
  Sözleşmesi (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
  de geçerlidir; bu sözleşme ile çelişen bir hüküm olursa kullanıcı
  lehine olan uygulanır.

8) PLATFORM DIŞI ÖDEME KESİNLİKLE YASAKTIR
Lounge girişi karşılığında birbirinize para, hediye kartı veya benzeri
bir bedel teklif etmek/ almak yasaktır. Bu, hem bu sözleşmenin ihlali hem
de çoğu lounge programının kurallarının ihlalidir ve hesabın kalıcı
olarak kapatılmasıyla sonuçlanır.

9) KULLANICI İÇERİĞİ — SIFIR TOLERANS
Profil, sohbet, not ve yorumlarda kabul edilemez içeriğe ve kötüye
kullanıma SIFIR TOLERANS uygulanır: taciz, tehdit, nefret söylemi,
ayrımcılık, müstehcen veya cinsel içerik, şiddet, dolandırıcılık, spam,
başkasının kişisel verisini paylaşmak yasaktır. Her kullanıcı bir
kişiyi veya içeriği uygulama içinden bildirebilir ve engelleyebilir.
Bildirimler en geç 24 saat içinde incelenir; ihlal halinde içerik
kaldırılır ve ihlali yapan hesap uyarılır, kısıtlanır veya kalıcı olarak
kapatılır.

10) YASAK DAVRANIŞLAR
Sahte kimlik/kimlik hırsızlığı, taciz, ayrımcılık, tehdit, ticari
tanıtım/spam, başka kullanıcıların verilerinin toplanması, güvenlik
önlemlerinin aşılması, otomatik araçlarla erişim.

11) GÜVENLİK ARAÇLARI
Şikayet, engelleme, itiraz ve kadın güvenlik modu her kullanıcıya açıktır.
Kararlara ${CONTACT} üzerinden itiraz edebilirsin.

12) SORUMLULUK
LoungeLink, kullanıcıların birbirine karşı davranışlarından, lounge
girişinin gerçekleşmemesinden veya lounge işletmecisinin kararlarından
sorumlu değildir. Uygulamanın kesintisiz çalışacağı garanti edilmez.
Bu hükümler, tüketici mevzuatının emredici koruma hükümlerini
sınırlamaz.

13) FESİH
Hesabını istediğin an kapatabilirsin. LoungeLink, bu sözleşmenin ağır
ihlali halinde hesabı askıya alabilir veya kapatabilir.

14) DEĞİŞİKLİKLER
Sözleşmede önemli bir değişiklik olursa uygulama içinde bildirilir ve
yürürlük tarihinden önce görürsün. Güncel metin ${SITE}/kosullar
adresindedir.

15) UYGULANACAK HUKUK
Türkiye Cumhuriyeti hukuku uygulanır; uyuşmazlıklarda tüketici hakem
heyetleri ve tüketici mahkemeleri yetkilidir.`,
  },
};

// Giriş/kayıt ekranının altındaki satırın sırası (MVP referansı)
export const LEGAL_ORDER = ["gizlilik", "acikRiza", "cerez", "aydinlatma", "platform"];
