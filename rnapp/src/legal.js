// ============================================================
// LoungeLink · Hukuki metinler (TEK KAYNAK)
//
// ⚠️ Bunlar AVUKAT ONAYINDAN GEÇMEMİŞ taslaklardır. KVKK (6698), GDPR ve
// 6563 sayılı E-Ticaret Kanunu'nun beklediği başlıkları LoungeLink'in
// GERÇEK veri akışına göre yazdım (başka bir şirketin metni kopyalanmadı).
// Yayın öncesi bir avukatın gözden geçirmesi ŞART.
//
// {{ }} içindeki alanlar şirket bilgileri netleşince doldurulacak:
//   {{SIRKET_UNVAN}}  {{ADRES}}  {{MERSIS}}  {{KEP}}
// Bunlar doldurulmadan mağaza yayınına çıkılmamalı.
//
// AYNI METİN backoffice'te de yayınlanır (public URL) çünkü Google Play
// ve App Store, mağaza listesinde ERİŞİLEBİLİR BİR GİZLİLİK POLİTİKASI
// URL'İ ister — uygulama içi ekran tek başına yetmez.
// ============================================================

export const LEGAL_VERSION = "2026-08-03";

// ============================================================
// 🔴 BURAYI DOLDUR — TEK YAPMAN GEREKEN İŞ BU (v2.82)
// ------------------------------------------------------------
// Gökberk: "legal.js placeholder'ları — nasıl yapacağım anlamadım."
//
// Aşağıdaki ÜÇ satırı kendi bilgilerinle değiştir, başka hiçbir yere
// dokunma. Bu dosya TEK KAYNAK; app, backoffice ve website aynı metni
// buradan alıyor.
//
// ŞİRKET HENÜZ KURULMADIYSA da boş bırakma — KVKK "veri sorumlusu"nun
// kim olduğunu sormak zorunda ve cevabı bir GERÇEK KİŞİ de olabilir.
// Şahıs olarak yürütüyorsan şöyle yaz:
//     const COMPANY = "Gökberk İnak";
//     const ADDRESS = "İstanbul, Türkiye — ayrıntılı adres talep üzerine";
// Şirket kurulduğunda ünvan ve tam adresle değiştir, üç yüzeye de
// kopyala (aşağıdaki not).
//
// 🔴 DOLDURULMADAN YAYINA ÇIKAMAZSIN: `node check.js` yer tutucu
// kalırsa KIRMIZI yanıyor. Eskiden yanmıyordu — "{{SIRKET_UNVAN}}"
// yazan bir gizlilik politikası mağazaya gidebilirdi ve bu hem
// güven kaybı hem mağaza reddi sebebidir.
//
// KOPYALAMA YÖNÜ (değiştirdikten sonra):
//     rnapp/src/legal.js  →  backoffice/lib/legal.js
//     rnapp/src/legal.js  →  website/lib/legal-source.js
// Tek yönlü; asla tersi. (`node check.js` üçünün aynı olduğunu da
// kontrol ediyor.)
// ============================================================
const COMPANY = "LoungeLink";
const ADDRESS = "İstanbul, Türkiye — APA GIZ PLAZA";
// Tek alan adı (loungelink.co) — üç kopya (app · site · BO) aynı adresi taşır.
const CONTACT = "kvkk@loungelink.co";


export const LEGAL_DOCS = {
  gizlilik: {
    title: "Gizlilik ve Veri Yönetimi Politikası",
    short: "Hangi veriyi neden tutuyoruz, ne kadar süreyle saklıyoruz",
    body: `Son güncelleme: ${LEGAL_VERSION}

1) BİZ KİMİZ
LoungeLink, havalimanı lounge erişimi olan yolcular (host) ile lounge'a
misafir olarak girmek isteyen yolcuları (misafir) buluşturan bir eşleştirme
platformudur. Veri sorumlusu ${COMPANY}, adres: ${ADDRESS}.

2) LOUNGELINK LOUNGE ERİŞİMİ SATMAZ
Platform, lounge girişi satmaz ve lounge işletmecisi adına hareket etmez.
Host'un halihazırda sahip olduğu misafir hakkının paylaşılmasına aracılık
eder. Bu, hangi verileri neden işlediğimizi doğrudan belirler.

3) İŞLEDİĞİMİZ VERİLER
a) Hesap verileri: ad-soyad, e-posta, telefon numarası, şifre (yalnızca
   geri döndürülemez şekilde şifrelenmiş özet olarak; düz metin şifre
   hiçbir yerde tutulmaz).
b) Profil verileri: meslek/sektör, biyografi, konuşulan diller, profil
   fotoğrafı, LinkedIn adresi, cinsiyet (yalnızca kadın güvenlik modunun
   çalışması için).
c) Seyahat verileri: havalimanı, tarih, saat aralığı, uçuş numarası,
   seyahat amacı.
d) Host verileri: lounge erişim kaynağı beyanı (ör. Priority Pass),
   misafir hakkı sayısı, açılan ilanlar.
e) Etkileşim verileri: istekler, davetler, bağlantılar, oturum kayıtları,
   sohbet mesajları, puanlar ve yorumlar.
f) Güven ve güvenlik verileri: güven puanı bileşenleri, doğrulama
   durumları, şikayet ve itiraz kayıtları.
g) Teknik veriler: cihaz/uygulama sürümü, hata kayıtları, bildirim izni
   için cihaz jetonu.

4) NEDEN İŞLİYORUZ (hukuki sebep)
· Sözleşmenin kurulması ve ifası: hesap açma, eşleştirme, sohbet, oturum
  yönetimi, kredi/puan işlemleri.
· Meşru menfaat: dolandırıcılık ve kötüye kullanımın önlenmesi, güven
  puanının hesaplanması, hizmetin iyileştirilmesi, hata takibi.
· Açık rıza: profil fotoğrafının keşif ekranında gösterilmesi, konum
  temelli olmayan bildirimler, pazarlama iletileri (varsa).
· Hukuki yükümlülük: talep halinde yetkili mercilere bilgi verilmesi.

5) KİMLERLE PAYLAŞIYORUZ
· Karşı taraf: bir istek/davet kabul edildiğinde adın, profilin ve seyahat
  bilgilerinin görünen kısmı karşı tarafa açılır.
· Hizmet sağlayıcılar: barındırma ve veritabanı (Supabase — AB/Frankfurt),
  bildirim altyapısı. Bunlar veri işleyendir; kendi amaçları için
  kullanamaz.
· Lounge işletmecileri: kimlik verisi PAYLAŞILMAZ. Yalnızca kimliksiz ve
  toplulaştırılmış talep istatistikleri (ör. "IST'te salı 14:00-18:00
  aralığında X kişi") paylaşılabilir; bir kişiye indirgenemeyecek eşiğin
  altındaki gruplar hiç raporlanmaz.
· Yetkili merciler: yasal talep halinde, talep sınırında.

6) YURT DIŞINA AKTARIM
Veriler AB bölgesindeki sunucularda (Frankfurt) barındırılır. Bildirim
gönderimi gibi hizmetler için sınırlı teknik veri, KVKK'nın öngördüğü
güvenceler çerçevesinde yurt dışına aktarılabilir.

7) SAKLAMA SÜRELERİ
· Hesap ve profil verileri: hesabın açık olduğu süre boyunca.
· Sohbet ve oturum kayıtları: uyuşmazlık ve güvenlik incelemeleri için
  oturumun bitiminden itibaren 24 ay.
· Şikayet/itiraz kayıtları: 5 yıl.
· Hata kayıtları: 12 ay.
Hesabını sildiğinde profilin ve seyahatlerin kaldırılır; yukarıdaki yasal
ve güvenlik amaçlı kayıtlar süresi dolana kadar erişimi kısıtlı biçimde
saklanır.

8) HAKLARIN (KVKK m.11)
Verilerine erişme, düzeltme, silme, işlemeye itiraz etme, aktarım
bilgisini isteme ve rızanı geri alma hakların vardır. Başvuru:
${CONTACT}. En geç 30 gün içinde yanıtlarız.

9) GÜVENLİK
Veritabanı satır bazlı erişim kurallarıyla korunur; ayrıcalıklı işlemler
yalnızca sunucu tarafı fonksiyonlarla yapılır. Şifreler geri
döndürülemez özet olarak saklanır. Yine de hiçbir sistem %100 güvenli
değildir; şüpheli bir durumda ${CONTACT} adresine bildir.

10) ÇOCUKLAR
Platform 18 yaş altına yönelik değildir ve 18 yaşından küçüklerin hesap
açmasına izin verilmez.`,
  },

  aydinlatma: {
    title: "Aydınlatma Metni",
    short: "KVKK m.10 kapsamında kısa bilgilendirme",
    body: `Son güncelleme: ${LEGAL_VERSION}

Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu'nun 10. maddesi
uyarınca, veri sorumlusu sıfatıyla ${COMPANY} tarafından hazırlanmıştır.

VERİ SORUMLUSU
${COMPANY}, ${ADDRESS}. İletişim: ${CONTACT}

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
· Etkileşim ve oturum kayıtları, sohbet: hizmetin ifası, uyuşmazlık
  çözümü, kötüye kullanımın önlenmesi.
· Teknik kayıtlar: hata takibi ve güvenlik.

TOPLAMA YÖNTEMİ VE HUKUKİ SEBEP
Veriler doğrudan senin uygulamaya girdiğin bilgilerden ve kullanım
sırasında otomatik olarak oluşan kayıtlardan toplanır. Hukuki sebepler:
sözleşmenin ifası, meşru menfaat, hukuki yükümlülük ve — fotoğrafın
gösterimi gibi hallerde — açık rıza.

AKTARIM
Karşı tarafa (eşleştiğin kişiye), barındırma ve bildirim hizmeti
sağlayıcılarına, yasal talep halinde yetkili mercilere aktarılabilir.
Lounge işletmecileriyle yalnızca kimliksiz ve toplulaştırılmış
istatistikler paylaşılır.

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

4) TOPLULAŞTIRILMIŞ TALEP İSTATİSTİKLERİ
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
Bu kayıtları uygulamayı silerek veya çıkış yaparak temizleyebilirsin.

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
    title: "Platform Sözleşmesi",
    short: "Kullanım koşulları, kredi/escrow kuralları, yasaklar",
    body: `Son güncelleme: ${LEGAL_VERSION}

1) TARAFLAR VE KONU
Bu sözleşme, ${COMPANY} ("LoungeLink") ile uygulamayı kullanan kişi
("kullanıcı") arasındadır. Konusu, host ile misafirin havalimanı
lounge'larında buluşmasına aracılık eden platformun kullanımıdır.

2) LOUNGELINK'İN ROLÜ
LoungeLink bir ARACIDIR; lounge erişimi satmaz, lounge işletmecisi ya da
seyahat acentesi değildir. Lounge'a giriş kararı her zaman lounge
işletmecisine ve o lounge'un kurallarına aittir. Host'un misafir hakkının
geçerliliğinden ve lounge kurallarına uygunluğundan host sorumludur.

3) HESAP
Hesap açan kişi 18 yaşını doldurmuş olmalı, gerçek ad-soyadını kullanmalı
ve bilgilerinin doğruluğundan sorumlu olmalıdır. Hesabını başkasına
devredemezsin.

4) HOST'UN YÜKÜMLÜLÜKLERİ
· Yalnızca gerçekten sahip olduğu misafir hakkı kadar slot açar.
· İlan açtığı tarih/saatte lounge'da bulunmayacaksa ilanı iptal eder.
· Misafirini lounge kurallarına uygun şekilde ağırlar.

5) MİSAFİRİN YÜKÜMLÜLÜKLERİ
· Kabul edilen oturuma zamanında gelir; gelemeyeceğini önceden bildirir.
· Lounge, havayolu ve havalimanı kurallarına uyar.

6) KREDİ VE ESCROW
· İstek gönderirken hesabından 1 kredi tutulur (escrow).
· İstek reddedilir veya iptal edilirse kredi anında iade edilir.
· İstek kabul edilirse kredi kullanılmış sayılır.
· LoungePuan (ödül puanı) bir para birimi değildir; nakde çevrilemez,
  devredilemez ve kampanya koşullarına göre değişebilir.

7) PLATFORM DIŞI ÖDEME KESİNLİKLE YASAKTIR
Lounge girişi karşılığında birbirinize para, hediye kartı veya benzeri
bir bedel teklif etmek/ almak yasaktır. Bu, hem bu sözleşmenin ihlali hem
de çoğu lounge programının kurallarının ihlalidir ve hesabın kalıcı
olarak kapatılmasıyla sonuçlanır.

8) YASAK DAVRANIŞLAR
Sahte kimlik/kimlik hırsızlığı, taciz, ayrımcılık, tehdit, ticari
tanıtım/spam, başka kullanıcıların verilerinin toplanması, güvenlik
önlemlerinin aşılması, otomatik araçlarla erişim.

9) GÜVENLİK ARAÇLARI
Şikayet, engelleme, itiraz ve kadın güvenlik modu her kullanıcıya açıktır.
Şikayetler incelenir; ihlal halinde uyarı, kısıtlama veya hesap kapatma
uygulanabilir. Kararlara ${CONTACT} üzerinden itiraz edebilirsin.

10) SORUMLULUK
LoungeLink, kullanıcıların birbirine karşı davranışlarından, lounge
girişinin gerçekleşmemesinden veya lounge işletmecisinin kararlarından
sorumlu değildir. Platformun kesintisiz çalışacağı garanti edilmez.
Bu hükümler, tüketici mevzuatının emredici koruma hükümlerini
sınırlamaz.

11) FESİH
Hesabını istediğin an kapatabilirsin. LoungeLink, bu sözleşmenin ağır
ihlali halinde hesabı askıya alabilir veya kapatabilir.

12) DEĞİŞİKLİKLER
Sözleşmede önemli bir değişiklik olursa uygulama içinde bildirilir ve
yürürlük tarihinden önce görürsün.

13) UYGULANACAK HUKUK
Türkiye Cumhuriyeti hukuku uygulanır; uyuşmazlıklarda tüketici hakem
heyetleri ve tüketici mahkemeleri yetkilidir.`,
  },
};

// Giriş/kayıt ekranının altındaki satırın sırası (MVP referansı)
export const LEGAL_ORDER = ["gizlilik", "acikRiza", "cerez", "aydinlatma", "platform"];
