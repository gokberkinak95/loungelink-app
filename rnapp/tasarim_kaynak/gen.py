# -*- coding: utf-8 -*-
import io
B64 = open('bant_b64.txt').read().strip()
FOTO = "data:image/jpeg;base64," + B64

def ik(d, boy=20, renk="currentColor", sw=1.8):
    return ('<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="%s" '
            'stroke-linecap="round" stroke-linejoin="round">%s</svg>') % (boy,boy,renk,sw,d)

I = dict(
 radar='<circle cx="12" cy="12" r="3"/><path d="M12 3a9 9 0 0 1 9 9M12 6.5a5.5 5.5 0 0 1 5.5 5.5"/><path d="M12 21a9 9 0 0 1-9-9M12 17.5A5.5 5.5 0 0 1 6.5 12"/>',
 pass_='<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><path d="M2.5 10.5h19M7 14.5h3"/>',
 mesaj='<path d="M4 5.5h16v11H9l-5 4z"/>',
 profil='<circle cx="12" cy="8" r="3.4"/><path d="M5.2 19.5c0-3.6 3-5.9 6.8-5.9s6.8 2.3 6.8 5.9"/>',
 kalkan='<path d="M12 3 5 6v5.5c0 4.3 3 8.1 7 9.5 4-1.4 7-5.2 7-9.5V6z"/><path d="m9 12 2 2 4-4"/>',
 saat='<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 1.8"/>',
 ucus='<path d="M20.5 15 3.8 10.2l2.7-1.8 3.7.9 3.7-4.2 1.9.5-1.9 4.7 3.7.9.9 2.3z"/>',
 sag='<path d="m9.5 5.5 6.5 6.5-6.5 6.5"/>',
 sol='<path d="m14.5 5.5-6.5 6.5 6.5 6.5"/>',
 arti='<path d="M12 5v14M5 12h14"/>',
 kisi='<circle cx="12" cy="8" r="3.2"/><path d="M5.5 19.5c0-3.4 2.9-5.6 6.5-5.6s6.5 2.2 6.5 5.6"/>',
 kapi='<path d="M14.5 3.5H6v17h8.5"/><path d="M11 12h9m0 0-3-3m3 3-3 3"/>',
)

# ══════════════════════════════════════════════════════════════════
# EKRAN PARÇALARI
# ══════════════════════════════════════════════════════════════════
def tel(ic, ad, not_=""):
    n = ('<p class="tel-not">'+not_+'</p>') if not_ else ''
    return ('<figure class="tel"><div class="cerceve"><div class="ekran">'+ic+'</div></div>'
            '<figcaption><span class="tel-ad">'+ad+'</span>'+n+'</figcaption></figure>')

def durum():
    return ''   # sahte durum çubuğu YOK — gerçek cihaz kendi çubuğunu çizer

def tabbar(aktif):
    ogeler=[("radar","Keşfet",I['radar']),("pass","Planım",I['pass_']),
            ("mesaj","Sohbet",I['mesaj']),("profil","Profil",I['profil'])]
    h=""
    for k,ad,d in ogeler:
        a = " on" if k==aktif else ""
        h += ('<div class="tb'+a+'"><i class="tb-ind"></i>'+ik(d,21,"currentColor",1.7)
              +'<span>'+ad+'</span></div>')
    return '<nav class="tabbar">'+h+'</nav>'

def rozet(m, tur="notr"):
    return '<span class="roz '+tur+'">'+m+'</span>'

def kalkan_roz():
    return '<span class="kalkan">'+ik(I['kalkan'],11,"currentColor",2.1)+'</span>'

def geri_sayim(m):
    return ('<span class="sayac">'+ik(I['saat'],12,"currentColor",2)+'<b>'+m+'</b></span>')

def altin_dugme(m, ok=True):
    o = ik(I['sag'],16,"currentColor",2.2) if ok else ''
    return '<button class="btn-altin">'+m+o+'</button>'

def cizgi_dugme(m):
    return '<button class="btn-cizgi">'+m+'</button>'

# ── 1 · KEŞFET ────────────────────────────────────────────────────
def ekran_kesfet():
    def kart(harf, ad, mert, salon, term, kalan, roz_html, uyum, vurgu=False):
        return ('<article class="kart'+(' one' if vurgu else '')+'">'
          '<header class="kart-ust">'
          '<div class="avatar">'+harf+kalkan_roz()+'</div>'
          '<div class="kart-kim"><div class="kart-ad">'+ad+'</div>'
          '<div class="kart-mert">'+mert+'</div></div>'
          '<div class="uyum"><b>'+str(uyum)+'</b><span>uyum</span></div></header>'
          '<div class="kart-salon">'+salon+'</div>'
          '<div class="kart-term">'+term+'</div>'
          '<div class="roz-sira">'+roz_html+'</div>'
          '<div class="kart-alt">'+geri_sayim(kalan)+altin_dugme("İstek gönder")+'</div>'
          '</article>')
    r1 = rozet("Misafir ücretsiz","iyi")+rozet("TK1978")+rozet("Aynı uçuş","bilgi")
    r2 = rozet("Ücretli giriş","uyari")+rozet("PC2210")
    return (durum()+
      '<header class="ust mesh">'
      '<div class="ust-sira"><div class="marka">LOUNGELINK</div>'
      '<div class="ust-eylem">'+ik(I['radar'],19,"currentColor",1.7)+'</div></div>'
      '<div class="dugum">İSTANBUL · IST</div>'
      '<h1 class="ust-h1">Terminal A</h1>'
      '<div class="ust-alt">Kalkışına 3 sa 12 dk · 6 host yayında</div>'
      '</header>'
      '<div class="govde">'
      + kart("D","Deniz K.","Elite Plus · Star Alliance Gold","TAV Primeclass","Dış hatlar · Kapı A12","14:20 içinde", r1, 84, True)
      + kart("M","Mert A.","Miles&Smiles Classic","Comfort Lounge","İç hatlar · Kapı B4","09:00 içinde", r2, 71)
      + '</div>' + tabbar("radar"))

# ── 2 · İSTEK / KURAL KARARI ──────────────────────────────────────
def ekran_kural():
    def sart(m, ok=True):
        d = '<path d="m5 12 5 5 9-10"/>' if ok else '<path d="M6 6l12 12M18 6 6 18"/>'
        return ('<li class="'+('ok' if ok else 'yok')+'">'+ik(d,15,"currentColor",2.4)+'<span>'+m+'</span></li>')
    return (durum()+
      '<header class="ust sade">'
      '<div class="ust-sira"><div class="ust-eylem">'+ik(I['sol'],20,"currentColor",1.9)+'</div>'
      '<div class="marka">LOUNGELINK</div><div style="width:20px"></div></div>'
      '<div class="dugum" style="margin-top:26px">KURAL MOTORU</div>'
      '<h1 class="ust-h1" style="font-size:34px">Bu eşleşme<br>neden %84?</h1>'
      '</header>'
      '<div class="govde">'
      '<div class="kutu"><div class="kutu-bas">Kart · Elite Plus</div>'
      '<ul class="sartlar">'
      + sart("Misafir hakkı var · 2 kişilik") + sart("Aynı havayolu · TK")
      + sart("Birlikte varış şartı sağlanıyor") + sart("Kabin sınıfı şartı yok")
      + sart("Uçuş numarası doğrulanmadı", False)
      + '</ul></div>'
      '<p class="not">Son karar her zaman salona aittir. Kapıda alınmazsan kredin iade edilir.</p>'
      '<div class="eylem-yig">'+altin_dugme("Lounge isteği gönder")+cizgi_dugme("Salon kurallarını oku")+'</div>'
      '</div>')

# ── 3 · EŞLEŞME ANI ───────────────────────────────────────────────
def ekran_eslesme():
    return (durum()+
      '<div class="an mesh-yogun">'
      '<div class="an-ic">'
      '<div class="an-ikiz"><div class="an-av">G</div><div class="an-cizgi"></div><div class="an-av alt">D</div></div>'
      '<div class="dugum" style="margin-top:34px">EŞLEŞTİNİZ</div>'
      '<h1 class="an-h1">Deniz seni<br>içeri alıyor</h1>'
      '<p class="an-alt">TAV Primeclass · Dış hatlar<br>Buluşma: Kapı A12 önü, 14:20</p>'
      '<div class="an-sayac">'+ik(I['saat'],14,"currentColor",2)+'<b>02:41:08</b><span>kalkışa</span></div>'
      '</div>'
      '<div class="an-eylem">'+altin_dugme("Sohbeti aç")+
      '<button class="btn-sessiz">Oturumu görüntüle</button></div>'
      '</div>')

# ── 4 · SOHBET ────────────────────────────────────────────────────
def ekran_sohbet():
    def bal(m, ben=False, saat=""):
        return ('<div class="bal'+(' ben' if ben else '')+'"><p>'+m+'</p><time>'+saat+'</time></div>')
    cip = lambda m: '<button class="cip">'+m+'</button>'
    return (durum()+
      '<header class="ust ince-ust">'
      '<div class="ust-sira"><div class="ust-eylem">'+ik(I['sol'],20,"currentColor",1.9)+'</div>'
      '<div class="sohbet-kim"><div class="avatar sm">D'+kalkan_roz()+'</div>'
      '<div><div class="kart-ad" style="font-size:15px">Deniz K.</div>'
      '<div class="kart-mert">TAV Primeclass · Kapı A12</div></div></div>'
      '<div style="width:20px"></div></div>'
      '<div class="sabit-serit">'+ik(I['saat'],13,"currentColor",2)+'<b>02:41:08</b><span>kalkışa</span>'
      '<i></i>'+ik(I['kapi'],13,"currentColor",2)+'<span>Kapı A12 önü</span></div>'
      '</header>'
      '<div class="govde sohbet">'
      + bal("Merhaba! Uçuşun aynı, güzel. Salona 13:50 gibi geçmeyi düşünüyorum.","", "13:12")
      + bal("Harika, ben güvenlikten yeni çıktım. 13:50 bana da uyar.", True, "13:14")
      + bal("Kapının hemen solundaki kitapçının önünde buluşalım mı?","", "13:15")
      + '</div>'
      '<div class="cipler">'+cip("Güvenlikteyim")+cip("Salon girişindeyim")+cip("5 dk uzaktayım")+'</div>'
      '<div class="yazma"><span>Mesaj yaz…</span><div class="gonder">'+ik(I['sag'],16,"currentColor",2.2)+'</div></div>')

# ── 5 · ANA SAYFA ─────────────────────────────────────────────────
def ekran_ana():
    def sayi(n, lb, on=False):
        return ('<div class="sy'+(' on' if on else '')+'"><b>'+n+'</b><span>'+lb+'</span></div>')
    return (durum()+
      '<header class="ust mesh">'
      '<div class="ust-sira"><div class="marka">LOUNGELINK</div>'
      '<div class="ust-eylem">'+ik(I['profil'],19,"currentColor",1.7)+'</div></div>'
      '<div class="dugum" style="margin-top:30px">İYİ GÜNLER</div>'
      '<h1 class="ust-h1 serif">Gökberk</h1>'
      '<div class="cuzdan"><div><b>14</b><span>kredi</span></div><i></i>'
      '<div><b>200</b><span>LoungePuan</span></div><i></i>'
      '<div><b>44</b><span>güven</span></div></div>'
      '</header>'
      '<div class="govde">'
      '<div class="sy-sira">'+sayi("0","Sohbet")+sayi("1","İstek",True)+sayi("0","Davet")+sayi("2","Soru",True)+'</div>'
      '<article class="kart one" style="margin-top:16px">'
      '<div class="dugum" style="color:var(--dim)">BUGÜN</div>'
      '<div class="kart-salon" style="margin-top:10px">Esenboğa · 14 gün</div>'
      '<p class="kart-metin">Sıradaki uçuşunda <b>6 host</b> ve <b>17 açık slot</b> var. '
      'Seyahatine en uygun olanlar üstte.</p>'
      '<div class="kart-alt tek">'+altin_dugme("Salon ara")+'</div></article>'
      '<article class="kart" style="margin-top:12px">'
      '<div class="dugum" style="color:var(--dim)">KARTINDA DURAN HAK</div>'
      '<div class="kart-salon" style="margin-top:10px">3 misafir hakkı</div>'
      '<p class="kart-metin">31 Aralık\'ta siliniyor. Bir tanesi sana hakkın olmadığı bir salonda kapı açabilir.</p>'
      '<div class="kart-alt tek">'+cizgi_dugme("İlan aç")+'</div></article>'
      '</div>' + tabbar("radar"))
