# -*- coding: utf-8 -*-
"""
push_check.py — TELEFONA BİLDİRİM GERÇEKTEN GİDER Mİ?

============================================================================
🔴 NEDEN VAR
28 Ağustos, Gökberk: "bu bildirimlerdeki logo bizim logo değil ki…
Bildirim konusunda eksik bir durum var mı kontrol ettin mi, tüm altyapı
hazır ve doğru mu, şu an bildirim gider mi?"

Logoyu kataloğumda yanlış çizmiştim — ama asıl soru doğruydu ve
BAKINCA ÜRÜNDE DE AYNI SINIFTAN İKİ HATA ÇIKTI:

  1. `app.json`daki `expo-notifications` eklentisi YALNIZ `color`
     alıyordu, `icon` ALMIYORDU. Üst düzey `expo.notification.icon` ise
     SDK 48'den beri eklenti lehine bırakılmış bir alan. Sonuç: EAS ile
     üretilen pakette Android bildirim ikonu bizim işaretimiz değil,
     uygulama ikonunun beyaz siluetiydi — yani kullanıcının kilit
     ekranında beyaz bir leke.

  2. `getExpoPushTokenAsync()` argümansız çağrılıyordu. Kütüphane proje
     kimliğini kendi çözmeye çalışır; çözemezse FIRLATIR. Bizde o hata
     yutulup "izin verildi ama token yok" durumuna dönüşüyordu — yani
     kullanıcı izin veriyor, biz yine ulaşamıyoruz ve sebebi hiçbir
     yerde yazmıyor.

🆕 SINIF: "BİR BİLDİRİM ÖZELLİĞİ 'ÇALIŞIYOR' DEMEK, İZNİN ALINDIĞI
DEĞİL GLİFİN, KANALIN, KİMLİĞİN VE DOKUNUŞUN HEPSİNİN DOĞRU OLDUĞU
ANLAMINA GELİR — ZİNCİRİN HER HALKASI AYRI AYRI SESSİZCE KOPAR."

============================================================================
NE ÖLÇÜYOR — ALTI HALKA

  1 · Eklenti `icon` taşıyor mu (Android silueti)
  2 · `notification-icon.png` Android'in istediği biçimde mi
      (beyaz-üstü-saydam; renkli bir PNG siyah bir kareye döner)
  3 · `projectId` yapılandırmada var mı ve KODA veriliyor mu
  4 · Kanal adı sunucunun gönderdiğiyle aynı mı
      (SQL `'channelId','default'` yolluyor; app `default` kanalını
       kurmuyorsa Android bildirimi düşük öncelikli varsayılana atar)
  5 · Dokunuş dinleyicisi var mı (bildirim bir yere GÖTÜRÜYOR mu)
  6 · İzin penceresini açan tek yer hâlâ `pushIzniIste` mi
      (açılışta izin istemek, ömür boyu tek kullanımlık kartı harcar)
"""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(KOK, "src")


def kod(s):
    s = re.sub(r"/\*[\s\S]*?\*/", "", s)
    s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
    s = re.sub(r"[ \t]*//[^\"'\n]*$", "", s, flags=re.M)
    return s


def main():
    print("=" * 70)
    print("PUSH ZİNCİRİ — telefona bildirim gider mi?")
    print("=" * 70)
    hata = 0

    with open(os.path.join(KOK, "app.json"), encoding="utf-8") as f:
        cfg = json.load(f)["expo"]
    push_src = kod(open(os.path.join(SRC, "push.js"), encoding="utf-8").read())
    app_src = kod(open(os.path.join(KOK, "App.js"), encoding="utf-8").read())

    # ── 1 · EKLENTİ İKONU ─────────────────────────────────────────────
    ek = None
    for p in cfg.get("plugins", []):
        if isinstance(p, list) and p and p[0] == "expo-notifications":
            ek = p[1] if len(p) > 1 else {}
    print("\n1 · ANDROID BİLDİRİM İKONU")
    if ek is None:
        print("   ✗ `expo-notifications` eklentisi app.json'da YOK.")
        hata += 1
    elif not ek.get("icon"):
        print("   ✗ Eklentide `icon` YOK — Android uygulama ikonunun")
        print("     BEYAZ SİLUETİNİ çizer. Üst düzey `expo.notification.icon`")
        print("     SDK 48'den beri eklenti lehine bırakıldı; oradaki değer")
        print("     EAS paketinde uygulanmayabilir.")
        hata += 1
    else:
        print("   ✓ icon: %s" % ek["icon"])
        if not ek.get("color"):
            print("   ⚠ `color` yok — Android işareti gri çizer.")

    # ── 2 · İKON DOSYASININ BİÇİMİ ────────────────────────────────────
    # 🔴 Android bildirim ikonunu SİLUET olarak çizer: yalnız ALFA
    # kanalını kullanır, rengi kendisi verir. Renkli/opak bir PNG
    # koyarsan kilit ekranında DOLU BİR KARE görürsün.
    print("\n2 · İKON DOSYASI")
    yol = os.path.join(KOK, (ek or {}).get("icon", "").lstrip("./")) if ek else ""
    if not yol or not os.path.exists(yol):
        print("   ✗ İkon dosyası bulunamadı: %s" % ((ek or {}).get("icon") or "—"))
        hata += 1
    else:
        try:
            from PIL import Image
            im = Image.open(yol).convert("RGBA")
            w, h = im.size
            px = list(im.convert("RGBA").tobytes())
            px = [tuple(px[i:i+4]) for i in range(0, len(px), 4)]
            saydam = sum(1 for p in px if p[3] == 0)
            renkli = sum(1 for p in px if p[3] > 0 and not (p[0] > 235 and p[1] > 235 and p[2] > 235))
            print("   · %dx%d · saydam %%%d" % (w, h, 100 * saydam / len(px)))
            if w != h:
                print("   ✗ Kare değil — Android ölçekleyince bozar.")
                hata += 1
            if saydam == 0:
                print("   ✗ HİÇ SAYDAM PİKSEL YOK: Android bunu DOLU BİR KARE çizer.")
                hata += 1
            elif renkli > len(px) * 0.02:
                print("   ✗ Opak piksellerin %%%d'i beyaz DEĞİL. Android yalnız"
                      % (100 * renkli / max(1, len(px) - saydam)))
                print("     alfa kanalını kullanır; renk kaybolur, şekil bozulur.")
                hata += 1
            else:
                print("   ✓ Beyaz-üstü-saydam — Android siluet kuralına uygun.")
        except ImportError:
            print("   · Pillow yok, biçim kontrolü atlandı.")

    # ── 3 · PROJE KİMLİĞİ ─────────────────────────────────────────────
    print("\n3 · PROJE KİMLİĞİ (token alımı)")
    pid = (cfg.get("extra", {}).get("eas", {}) or {}).get("projectId")
    if not pid:
        print("   ✗ `extra.eas.projectId` YOK — token hiç alınamaz.")
        hata += 1
    else:
        print("   ✓ extra.eas.projectId var.")
    if "getExpoPushTokenAsync(" not in push_src:
        print("   ✗ `getExpoPushTokenAsync` çağrısı bulunamadı — nöbetçi kör.")
        hata += 1
    elif not re.search(r"getExpoPushTokenAsync\(\s*\)", push_src) is None:
        # Argümansız çağrı VAR
        print("   ✗ `getExpoPushTokenAsync()` ARGÜMANSIZ çağrılıyor.")
        print("     Kütüphane kimliği kendi çözmeye çalışır; çözemezse")
        print("     FIRLATIR ve hata yutulup 'izin var, token yok'a döner.")
        hata += 1
    elif "projectId" not in push_src:
        print("   ✗ Kodda `projectId` hiç geçmiyor — kimlik verilmiyor.")
        hata += 1
    else:
        print("   ✓ projectId çağrıya AÇIKÇA veriliyor.")

    # ── 4 · KANAL ADI: APP ile SUNUCU AYNI MI ─────────────────────────
    # 🔴 SINIRLARI AŞAN TEK KURAL. Sunucu `'channelId','default'`
    # yolluyor; app o kanalı kurmuyorsa Android bildirimi kendi
    # varsayılanına düşürür — sesi ve önceliği DEĞİŞİR ve kimse fark etmez.
    print("\n4 · BİLDİRİM KANALI (app ↔ sunucu)")
    # 🔴 30 Ağu · 6. tur — KANAL ARTIK BİRDEN ÇOK.
    # Bu desen yalnız `setNotificationChannelAsync("default", …)` gibi
    # DÜZ YAZILMIŞ bir kimlik görüyordu. Kanallar bir listeden döngüyle
    # kurulunca hiçbirini göremedi ve "app hiçbir kanal kurmuyor" dedi —
    # yani DAHA İYİ bir yapıyı kusur olarak raporladı.
    #
    # 🆕 SINIF: "BİR NÖBETÇİ TEK BİR YAZIM BİÇİMİNİ TANIYORSA, O BİÇİMİ
    # BIRAKMAK KODU DEĞİL NÖBETÇİYİ BOZAR — VE NÖBETÇİ HATAYI KENDİNDE
    # DEĞİL KODDA ARAR."
    kanallar = set(re.findall(r'setNotificationChannelAsync\(\s*["\'](\w+)["\']', push_src))
    kanallar |= set(re.findall(r'^\s*\[\s*"(\w+)"\s*,', push_src, re.M))
    app_kanal = "default" if "default" in kanallar else (sorted(kanallar)[0] if kanallar else None)
    sql_kanal = None
    sql_dizin = os.path.join(os.path.dirname(KOK), "sql")
    if os.path.isdir(sql_dizin):
        for f in sorted(os.listdir(sql_dizin), reverse=True):
            if not f.endswith(".sql"):
                continue
            g = open(os.path.join(sql_dizin, f), encoding="utf-8", errors="replace").read()
            mm = re.search(r"'channelId',\s*'(\w+)'", g)
            if mm:
                sql_kanal = mm.group(1)
                break
    if not app_kanal:
        print("   ✗ App hiçbir kanal kurmuyor — Android 8+ bildirimi DÜŞÜRÜR.")
        hata += 1
    elif sql_kanal and sql_kanal not in kanallar:
        print("   ✗ KANAL AYRIŞMIŞ: sunucu '%s' yolluyor, app o kanalı kurmuyor."
              % sql_kanal)
        print("     app'te kurulu: %s" % ", ".join(sorted(kanallar)))
        hata += 1
    else:
        print("   ✓ %d kanal kurulu (%s) — sunucunun yolladığı kanal karşılanıyor."
              % (len(kanallar), ", ".join(sorted(kanallar))))
    if (ek or {}).get("defaultChannel") and ek["defaultChannel"] != app_kanal:
        print("   ⚠ Eklentideki `defaultChannel` (%s) app kanalıyla aynı değil."
              % ek["defaultChannel"])

    # ── 5 · DOKUNUŞ ───────────────────────────────────────────────────
    print("\n5 · BİLDİRİME DOKUNUŞ")
    dinleyici = "addNotificationResponseReceivedListener" in app_src
    kapali = "getLastNotificationResponseAsync" in app_src
    if not dinleyici:
        print("   ✗ Dokunuş dinleyicisi YOK — bildirime dokunan kullanıcı")
        print("     ANA SAYFAYA düşer, bildirimin bağlamı kaybolur.")
        hata += 1
    elif not kapali:
        print("   ✗ `getLastNotificationResponseAsync` yok — uygulama KAPALIYKEN")
        print("     dokunulan bildirim hedefine gitmez.")
        hata += 1
    else:
        print("   ✓ Açıkken ve kapalıyken dokunuş yakalanıyor.")
    if dinleyici and "bildirim_hedefi" not in app_src:
        print("   ⚠ Hedef sunucudan (`bildirim_hedefi`) okunmuyor — ikinci bir")
        print("     yönlendirme tablosu doğmuş olabilir.")

    # ── 6 · İZİN PENCERESİ ────────────────────────────────────────────
    # 🔴 v2.98'de düzeltilmişti: pencereyi açan tek yer kullanıcı dokunuşu.
    # iOS bu pencereyi ÖMÜR BOYU BİR KEZ gösterir.
    print("\n6 · İZİN PENCERESİ")
    acan = re.findall(r"requestPermissionsAsync", push_src)
    govde = re.search(r"export async function pushIzniIste[\s\S]*?\n\}", push_src)
    if len(acan) > (1 if govde and "requestPermissionsAsync" in govde.group(0) else 0):
        print("   ✗ İzin penceresi `pushIzniIste` DIŞINDA da açılıyor.")
        hata += 1
    else:
        print("   ✓ Pencereyi yalnız `pushIzniIste` açıyor.")

    print("\n" + "=" * 70)
    if hata:
        print("✗ %d push bulgusu." % hata)
        return 1
    print("✓ Push zinciri app tarafında eksiksiz.")
    print("  (Sunucu tarafı için: sql/264_push_ve_api_saglik_raporu.sql)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
