# -*- coding: utf-8 -*-
"""
uret_306.py -> sql/306_kural_notlari_turkce_tamam.sql

290 kural notlarindaki Turkce harfleri geri koymustu ama (1) YALNIZ uc kolonu
tariyordu (lounge_guest_rules/programs/venues.notes) ve (2) sozlugu eksikti.
29 Eylul olcumu (yerel veritabani, 16 kullaniciya gorunen kolon):
  - asil bozuk kaynak lounge_venue_acceptance (conditions 5455, guest_fee_note
    2273, children_note 551 ASCII sozcuk) - 290 bu tabloyu HIC kapsamiyordu;
  - kural ekranindaki "UCUNDE ... KAZANILAMIYOR" cumlesi guest_fee_note'tan.

YONTEM 290 ile ayni: kor donusum YOK. Elle gozden gecirilmis sozluk, yalniz
sozcuk sinirinda (\\m..\\M), kucuk / Baslik / BUYUK uc cesit (Turkce buyuk harf:
i->I-noktali, i-noktasiz->I). Belirsiz sozcukler BILEREK disarida (asagida).
Idempotent: ikinci kosuda 0 satir.
"""
import io, os, re

KUCUK = """yalnizca yalnızca|ayni aynı|kapida kapıda|ucretsiz ücretsiz|capraz çapraz|hakki hakkı|tarafindan tarafından
karti kartı|uyenin üyenin|ucret ücret|degisir değişir|kisi kişi|basi başı|uyelik üyelik|basina başına|kartindan kartından
giris giriş|gore göre|ozel özel|salonlari salonları|planina planına|kartini kartını|binis biniş|yas yaş|yalniz yalnız
celebi çelebi|baglidir bağlıdır|almiyor almıyor|girisin girişin|cok çok|havalimanindaki havalimanındaki|salonlarini salonlarını
sec seç|gun gün|icin için|dis dış|cocuk çocuk|ucretli ücretli|uyeyle üyeyle|markali markalı|siniri sınırı|uctugu uçtuğu
kimligi kimliği|kabulu kabulü|ucreti ücreti|oder öder|acik açık|tutari tutarı|bagli bağlı|ic iç|yazmiyor yazmıyor
onayli onaylı|erisim erişim|araci aracı|girisi girişi|uyesi üyesi|sayfasi sayfası|ucmali uçmalı|odeme ödeme|olmasi olması
ucretlidir ücretlidir|kalis kalış|ustu üstü|uye üye|orn örn|yapi yapı|yuzden yüzden|erisimi erişimi|girisleri girişleri
cocuklardan çocuklardan|ucusta uçuşta|degildir değildir|planinin planının|sinirsiz sınırsız|pahali pahalı|planin planın
icindir içindir|kosullarini koşullarını|dogrulayamadik doğrulayamadık|havalimani havalimanı|sag sağ|bolumunde bölümünde
bazi bazı|altindaki altındaki|karari kararı|gecerli geçerli|ucusunda uçuşunda|sayfasindaki sayfasındaki|satiri satırı
onceden önceden|satin satın|sart şart|degil değil|sayi sayı|oldugu olduğu|sinirli sınırlı|dogrulanmadi doğrulanmadı
farkli farklı|ayri ayrı|once önce|kullanim kullanım|agu ağu|kaynagi kaynağı|dort dört|bagimsiz bağımsız|aylik aylık
cocuklar çocuklar|yoklugu yokluğu|etmedigi etmediği|anlamina anlamına|havalimaninda havalimanında|yaninda yanında
politikasi politikası|hakkin hakkın|ucakta uçakta|bolumu bölümü|bulusma buluşma|sayiyor sayıyor|giriste girişte
kaynaksiz kaynaksız|yasina yaşına|arasi arası|baska başka|sayfasinda sayfasında|tanimli tanımlı|yilda yılda
salonlarinda salonlarında|tum tüm|turkiye türkiye|bolumune bölümüne|diyarbakir diyarbakır|istisnasi istisnası|hakkini hakkını
okunamiyor okunamıyor|dogrula doğrula|uzerinden üzerinden|geciyor geçiyor|kaydi kaydı|anlasma anlaşma|odeyen ödeyen
cocugu çocuğu|bankacilik bankacılık|baglantili bağlantılı|kalkistan kalkıştan|gokcen gökçen|gosteriyor gösteriyor|odasi odası
yolcularina yolcularına|yetiskin yetişkin|yasindan yaşından|almamis almamış|uzeri üzeri|kosullari koşulları|kosulu koşulu
degisiyor değişiyor|olmadigi olmadığı|suresi süresi|ici içi|yolculari yolcuları|goturecek götürecek|baslangic başlangıç
noktasi noktası|verdigi verdiği|gecerlidir geçerlidir|diger diğer|ucan uçan|ayrimi ayrımı|dus duş|yaklasik yaklaşık
giristen girişten|ucusa uçuşa|kaldirildi kaldırıldı|degistirilemez değiştirilemez|duser düşer|gecici geçici|agi ağı
yillik yıllık|cikar çıkar|varlik varlık|sinira sınıra|kapali kapalı|kartlilar kartlılar|guncel güncel|sanip sanıp
yaziyor yazıyor|cozuldu çözüldü|aralik aralık|yazildi yazıldı|ucus uçuş|satisi satışı|tarafi tarafı|kapidan kapıdan
ucuslari uçuşları|kucuk küçük|bankanin bankanın|degisikligi değişikliği|kullanimi kullanımı|ucretin ücretin|adiyla adıyla
kullanilmayan kullanılmayan|yilin yılın|hakkindan hakkından|asilirsa aşılırsa|gecis geçiş|programi programı
anlasmali anlaşmalı|saglar sağlar|icinde içinde|sinifi sınıfı|islem işlem|kartin kartın|disi dışı|girisler girişler
gorebilir görebilir|ucretsizdir ücretsizdir|degerlendir değerlendir|kosul koşul|donemi dönemi|sarti şartı|kayit kayıt
yapildigi yapıldığı|vardi vardı|karsiligi karşılığı|gecmiste geçmişte|kartlari kartları|satir satır|ihtiyac ihtiyaç
cogu çoğu|henuz henüz|okunmadi okunmadı|aciliyor açılıyor|kartiyla kartıyla|bankasi bankası|kosuyor koşuyor|iceri içeri
alamazsin alamazsın|gercekten gerçekten|olculmus ölçülmüş|sozlesmede sözleşmede|fiyati fiyatı|yapilir yapılır
ucunde üçünde|uyelik üyelik|istanbul istanbul|onemsiz önemsiz"""

# Yalniz BUYUK yazimda bozuk olanlar (kucuk hali zaten dogru; ASCII buyukte
# noktali I kaybolmus): MISAFIR -> MİSAFİR vb. Olculen listeden, elle.
BUYUK = """MISAFIR MİSAFİR|BIR BİR|AILE AİLE|KENDI KENDİ|KENDISI KENDİSİ|ONEMSIZ ÖNEMSİZ|TIPINE TİPİNE|YINE YİNE
EDILMEZ EDİLMEZ|ISTANBUL İSTANBUL|BILET BİLET|GIRER GİRER|BELIRSIZ BELİRSİZ|SILINMEDI SİLİNMEDİ|BIRLIKTE BİRLİKTE
ICERMIYOR İÇERMİYOR|GORULMEDI GÖRÜLMEDİ|DIYARBAKIR DİYARBAKIR|ISTISNASI İSTİSNASI|UYENIN ÜYENİN|VERILMEZ VERİLMEZ"""

# BILEREK DISARIDA (belirsiz / zaten dogru / kisaltma): yani, ise (dogru yazim);
# cip/CIP (salon turu), is, suit (Ingilizce olabilir); uc (uc/üç), asil, es, mi, ucu
# (baglama gore); nin/in/un/si (tek basina ek - unlu uyumu baglamsiz cozulemez).
# Havalimani kodlari ve kisaltmalar (THY, IGA, KDV, EUR...) dokunulmaz.

KOLONLAR = [
    ("lounge_guest_rules", "notes"), ("lounge_guest_rules", "paid_entry_price_note"), ("lounge_guest_rules", "blocked_reason"),
    ("lounge_programs", "notes"), ("lounge_venues", "notes"),
    ("lounge_venue_acceptance", "conditions"), ("lounge_venue_acceptance", "guest_fee_note"),
    ("lounge_venue_acceptance", "children_note"), ("lounge_venue_acceptance", "source_conflict"),
    ("lounge_card_products", "conditions"), ("lounge_card_products", "condition_note"),
    ("lounge_venue_partners", "note"), ("venue_prices", "note"), ("program_entry_tariff", "note"),
    ("lounge_entry_windows", "note"), ("card_network_source", "match_note"),
]

def tr_ust(s):
    return s.replace("i", "İ").replace("ı", "I").upper()

def ciftler():
    out = []
    gor = set()
    # 290'in 154 maddelik sozlugu da dahil: canlida 290 hic kosmamis olabilir.
    import re
    k290 = io.open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "290_kural_notlari_turkce.sql"), encoding="utf-8").read()
    for x, y in re.findall(r"array\['([^']+)','([^']+)'\]", k290):
        if x != y and x not in gor:
            gor.add(x); out.append((x, y))
    for parca in KUCUK.replace(chr(10), "|").split("|"):
        a, b = parca.split()
        for x, y in ((a, b), (a[:1].upper() + a[1:], tr_ust(b[:1]) + b[1:]), (a.upper(), tr_ust(b))):
            if x != y and x not in gor:
                gor.add(x); out.append((x, y))
    for parca in BUYUK.replace(chr(10), "|").split("|"):
        a, b = parca.split()
        if a != b and a not in gor:
            gor.add(a); out.append((a, b))
    return out

def sql():
    c = ciftler()
    dizi = ",\n".join("    array['%s','%s']" % (a, b) for a, b in c)
    kol = ", ".join("('%s','%s')" % k for k in KOLONLAR)
    return f"""-- ════════════════════════════════════════════════════════════════════════
-- 306 · KURAL NOTLARINDAKİ TÜRKÇE HARFLER — TAMAMLAMA
--
-- 🔴 NEDEN VAR — GÖKBERK, 29 EYLÜL (6.2.1 cihaz görüntüsü):
--   "misafir hakki daha pahali plan alarak KAZANILAMIYOR. Ucret uyenin kartindan"
-- ÖLÇÜM (29 Eylül, 16 kullanıcıya görünen kolon):
--   · 290 yalnız üç kolonu tarıyordu; asıl bozuk kaynak lounge_venue_acceptance
--     (conditions · guest_fee_note · children_note) hiç kapsanmıyordu.
--   · 290'ın sözlüğü eksikti (ÜÇÜNDE, planının, pahalı, MİSAFİR …).
--   · Cihazda 290'ın düzelttiği sözcükler de bozuk → 290 canlıda koşmamış
--     olabilir. 306 290'ı KAPSAR: 290'ı ayrıca koşmak gerekmez.
--
-- YÖNTEM: 290 ile aynı — {len(c)} çiftlik elle gözden geçirilmiş sözlük, yalnız
-- sözcük sınırında, küçük / Başlık / BÜYÜK (Türkçe büyük harf kuralıyla).
-- Belirsiz sözcükler (yani, ise, uc, cip, mi, ek parçaları…) BİLEREK dışarıda.
-- ⚠️ ÜRETİLMİŞ DOSYA — elle düzenleme. Kaynak: sql/uretec/uret_306.py
-- Tekrar koşulabilir (idempotent): ikinci koşuda değişen satır 0.
-- ════════════════════════════════════════════════════════════════════════

do $$
declare
  v_tablo text; v_kolon text; v_n bigint; v_toplam bigint := 0; v_i int;
  -- Sozcuk siniri HARF SINIFIYLA: `\\m..\\M` C yerel ayarinda Turkce harfleri
  -- sozcuk disi sayiyor; 290'daki `resm -> resmî` her kosuda bir î daha
  -- ekliyordu (olculdu: resmîî). Harf sinifi yerel ayardan bagimsiz.
  v_on text := '(?<![A-Za-z0-9çğıöşüÇĞİÖŞÜâîûÂÎÛ])';
  v_son text := '(?![A-Za-z0-9çğıöşüÇĞİÖŞÜâîûÂÎÛ])';
  v_cift text[][] := array[
{dizi}
  ];
begin
  for v_tablo, v_kolon in
    select * from (values {kol}) t(a,b)
  loop
    if not exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = v_tablo and column_name = v_kolon) then
      raise notice '306: % . % yok, atlandi', v_tablo, v_kolon;
      continue;
    end if;
    for v_i in 1 .. array_length(v_cift, 1) loop
      execute format(
        'update public.%I set %I = regexp_replace(%I, %L, %L, %L) where %I ~ %L',
        v_tablo, v_kolon, v_kolon,
        v_on || v_cift[v_i][1] || v_son, v_cift[v_i][2], 'g',
        v_kolon, v_on || v_cift[v_i][1] || v_son);
      get diagnostics v_n = row_count;
      v_toplam := v_toplam + v_n;
    end loop;
  end loop;
  -- 290'in C yerel ayarli veritabaninda biraktigi yigilmis î'leri teke indir.
  for v_tablo, v_kolon in
    select * from (values ('lounge_guest_rules','notes'), ('lounge_programs','notes'),
                          ('lounge_venues','notes'), ('lounge_venue_acceptance','conditions')) t(a,b)
  loop
    execute format('update public.%I set %I = regexp_replace(%I, %L, %L, %L) where %I ~ %L',
      v_tablo, v_kolon, v_kolon, 'resmî{{2,}}', 'resmî', 'g', v_kolon, 'resmî{{2,}}');
    get diagnostics v_n = row_count;
    v_toplam := v_toplam + v_n;
  end loop;
  raise notice '306: % satir guncellendi (tekrar kosulursa 0 olur)', v_toplam;
end $$;

select '306 kuruldu' as sonuc;
"""

if __name__ == "__main__":
    yol = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "306_kural_notlari_turkce_tamam.sql")
    io.open(yol, "w", encoding="utf-8", newline="\n").write(sql())
    print(yol, len(ciftler()), "cift")
