# -*- coding: utf-8 -*-
import io, gen
from css import CSS

C = CSS.replace('url("FOTO")', 'url("'+gen.FOTO+'")')

JETON = [
 ("#100E12","--gece","Zemin","Ana uygulama zemini. Saf siyah değil — hafif mor kaydırılmış gece; fotoğrafın sıcaklığı üstüne oturuyor."),
 ("#1C1820","--yuzey","Yüzey","Kart, sayfa, sohbet balonu. Zeminden 1.5 kademe açık; derinliği gölge değil bu fark kuruyor."),
 ("#E0BE7A","--altin","Altın","Birincil eylem, sayaç, aktif sekme. Markanın #B8943A altını koyu zeminde okunmuyordu; ışığa doğru açıldı."),
 ("#3BD4B4","--guven","Güven","Doğrulanmış kalkan, uyum yüzdesi, sağlanan şart. Yalnız KANITLANMIŞ şeyler bu rengi alır."),
 ("#E8A33D","--uyari","Uyarı","Ücretli giriş, doğrulanmamış uçuş. Engel değil — dikkat."),
 ("#F6F1E8","--bulut","Mürekkep","Metin. Saf beyaz değil, sıcak kırık beyaz: gece ekranında beyaz keskin ve ucuz durur."),
]

KARARLAR = [
 ("01","Koyu zemin, çünkü ürün gece ve terminalde kullanılıyor",
  "Referans sistemin ilk kararı buydu ve doğru: alacakaranlık bir terminalde parlak beyaz bir ekran hem göz yorar hem ucuz durur. Ama onların lacivertini almadım — LoungeLink'in elindeki fotoğraf gün batımı, sıcak. Zemin bu yüzden mor-siyah: fotoğrafın sıcağı üstüne oturuyor, çakışmıyor."),
 ("02","Altın dolgu geri geldi — ama yalnız TEK yerde",
  "Bir önceki turda kahverengi dolguyu kaldırmıştım. Fazla ileri gitmişim: koyu zeminde altın dolgu ucuz değil, tersine tek doğru vurgu. Kural şu: ekranda aynı anda bir tane altın dolgu var. İkinci eylem çizgili, üçüncüsü düz metin."),
 ("03","Sayılar ayrı bir fontta",
  "Geri sayım, uyum yüzdesi, kredi, saat — hepsi JetBrains Mono. Sebebi estetik değil mekanik: orantılı bir fontta 02:41:08 her saniye genişlik değiştirir ve satır zıplar. Referans sistemin de aynı kararı almış."),
 ("04","Kalkan rozeti doğrulanmışın üstünde, profilin yanında değil",
  "Güven işareti avatarın kendisine gömülü. Ayrı bir satırda yazan 'doğrulanmış' etiketi okunmaz; kişinin yüzüne değen bir işaret okunur."),
 ("05","Aktif sekme ikonun ÜSTÜNDE 3px altın çizgi",
  "Sadece rengi değiştirmek yetmiyor — altın ile gri arasındaki fark yürürken bakılan bir ekranda kaçar. Çizgi konumu da bildiriyor."),
 ("06","Cormorant kaldı, ama tek görevde",
  "Marka serifi yalnız isim ve eşleşme anında. Gerisi Plus Jakarta Sans: yüksek x-yüksekliği, sarsıntılı ortamda (servis aracı, yürüyen bant) okunurluğu serifin üstünde. Marka DNA'sı duruyor, işlevi bozmuyor."),
]

def jetonlar():
    h=""
    for hexk, ad, baslik, acik in JETON:
        h += ('<div><div class="swatch" style="background:'+hexk+'"></div>'
              '<code>'+ad+' · '+hexk+'</code><div class="ad">'+baslik+'</div>'
              '<p class="aciklama">'+acik+'</p></div>')
    return '<div class="jeton">'+h+'</div>'

def kararlar():
    h=""
    for no, bas, met in KARARLAR:
        h += '<div class="karar"><span class="no">'+no+'</span><h3>'+bas+'</h3><p>'+met+'</p></div>'
    return '<div class="kararlar">'+h+'</div>'

EKRANLAR = [
 (gen.ekran_kesfet(), "Keşfet", "Ana ekran. Kart yoğun — premium dilin en zorlandığı yer burası. Kalkan doğrulanmışta, uyum yüzdesi mono ve iri (kararı o veriyor), geri sayım eylemin yanında."),
 (gen.ekran_ana(), "Ana Sayfa", "Cüzdan üstte, tek satırda: kredi · puan · güven. Akış sayaçları dört kutucuk, hepsi tek bakışta. Ekranda tek altın dolgu var."),
 (gen.ekran_kural(), "Kural kararı", "Ürünün gerçek farkı bu ekran. Şartlar tek tek işaretli; sağlanmayan kırmızı değil AMBER — engel değil, eksik. Altta sorumluluk cümlesi."),
 (gen.ekran_eslesme(), "Eşleşme anı", "Tek an, tek cümle. İki avatar bir çizgiyle bağlanıyor. Arka planda fotoğraf en yoğun burada — çünkü burada okunacak veri yok."),
 (gen.ekran_sohbet(), "Sohbet", "Başlıkta donmuş şerit: kalkışa kalan süre + buluşma noktası. Klavyenin üstünde hazır çipler — yürürken yazmak zor."),
]

def galeri():
    return '<div class="galeri">'+''.join(gen.tel(ic,ad,not_) for ic,ad,not_ in EKRANLAR)+'</div>'

HTML = ('<title>LoungeLink Gece Sistemi</title>\n'
 '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
 '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
 '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
 'family=Plus+Jakarta+Sans:wght@400;500;600;700&family=Cormorant+Garamond:wght@300;400;600&'
 'family=JetBrains+Mono:wght@400;500;600&display=swap">\n'
 '<style>'+C+'</style>\n'
 '<main class="sf">'
 '<div class="bas"><div class="kicik">Tasarım önerisi · 30 Ağustos</div>'
 '<h1>Gece uçuşu için<br><em>bir arayüz</em></h1>'
 '<p>Önceki iki denemem uygulamanın bugünkü hâlini yeniden çizmekten ibaretti — haklı olarak reddettin. '
 'Bu sefer sistemi baştan kurdum: koyu zemin, tek altın vurgu, mono sayılar, gerçek boyutta beş ekran. '
 'Aşağıdaki telefonlar 390×844 — yani cihazdaki hâli.</p></div>'
 '<div class="ayrac"></div>'
 '<div class="blm-bas"><h2>Beş ekran</h2>'
 '<p>Yana kaydır. Her ekranın altında ne yaptığını ve neden yaptığını yazdım.</p></div>'
 + galeri() +
 '<div class="ayrac"></div>'
 '<div class="blm-bas"><h2>Renk sistemi</h2>'
 '<p>Altı jeton. Hepsinin bir işi var; süs için konmuş tek renk yok.</p></div>'
 + jetonlar() +
 '<div class="ayrac"></div>'
 '<div class="blm-bas"><h2>Altı karar</h2>'
 '<p>Her biri tartışmaya açık. Katılmadığını söyle, o kararı ayrı çalışayım.</p></div>'
 + kararlar() +
 '<div class="ayrac"></div>'
 '<div class="blm-bas"><h2>Referanstan aldıklarım — ve almadıklarım</h2></div>'
 '<div class="kararlar">'
 '<div class="karar"><span class="no">ALDIM</span><h3>Yapı ve mekanik</h3>'
 '<p>Koyu zemin stratejisi · atmosferik mesh arka plan (yalnız kahraman alanlarda, liste ekranlarında değil) · '
 '48dp dokunma tabanı · mono sayaçlar · güven kalkanı · aktif sekmede 3px gösterge · 12–14px yarıçap · '
 'klavye üstü hazır çipler. Bunlar marka değil, zanaat — alınır.</p></div>'
 '<div class="karar"><span class="no">ALMADIM</span><h3>Renk kimliği</h3>'
 '<p>Lacivert <code style="color:var(--sessiz)">#0B132B</code> ve sarı <code style="color:var(--sessiz)">#FFBE0B</code> '
 'onların markası. Birebir alsaydık LoungeLink, LoungeSurf\'ün Türkçe kopyası gibi görünürdü — üstelik elimizdeki '
 'gün batımı fotoğrafı laciverte oturmuyor, sıcak. Zemin mor-siyaha, altın da senin <code style="color:var(--sessiz)">#B8943A</code>\'nın '
 'koyu zeminde okunan hâline (<code style="color:var(--sessiz)">#E0BE7A</code>) çekildi.</p></div>'
 '</div>'
 '</main>')

io.open('loungelink-gece-sistemi.html','w',encoding='utf-8').write(HTML)
print('yazildi', len(HTML)//1024, 'KB')
