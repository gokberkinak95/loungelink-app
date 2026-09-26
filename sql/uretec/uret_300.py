# -*- coding: utf-8 -*-
"""
300'ü üretir: canlı tanımı veritabanından OKUR, üstüne EKLER.
(299/A2 dersi: "gövdeyi yeniden yazma — eldeki tanımın üstüne ekle".)
Her yama bir ÇAPA arar; çapa bulunamazsa üretim DURUR (sessiz geçmez).
"""
import subprocess, sys, os

def tanim(ad):
    r = subprocess.run(["psql", "-U", "postgres", "-d", os.environ.get("LLDB", "ll"), "-Atc",
        f"select pg_get_functiondef(p.oid) from pg_proc p where proname='{ad}' and pronamespace='public'::regnamespace"],
        capture_output=True, text=True)
    if r.returncode or not r.stdout.strip():
        sys.exit(f"tanım okunamadı: {ad}\n{r.stderr}")
    if "300/" in r.stdout:
        sys.exit(f"{ad}: tanım ZATEN 300 yamasını taşıyor — üretici 300 ÖNCESİ veritabanında koşmalı "
                 "(LLDB=ll_yedek). 300_uctan_uca_denetim.sql dosyasının kendisi tekrar koşulabilir.")
    return r.stdout.rstrip() + ";\n"

def yama(metin, eski, yeni, ad):
    n = metin.count(eski)
    if n != 1:
        sys.exit(f"ÇAPA {ad}: {n} kez bulundu (1 bekleniyordu):\n{eski}")
    return metin.replace(eski, yeni)

# ── respond_request ─────────────────────────────────────────────
rr = tanim("respond_request")
rr = yama(rr, "    if not found then raise exception 'availability_not_found'; end if;\n",
"""    if not found then raise exception 'availability_not_found'; end if;
    -- 🔴 300/B1: süresi geçmiş ya da kaldırılmış ilana KABUL yok.
    -- Eskiden host buluşma saati geçtikten sonra da kabul edebiliyordu:
    -- misafirin kredisi tutuluyor, sohbet açılıyor, ama buluşma imkânsız.
    if not coalesce(v_av.active, true)
       or public.yerel_an(v_av.avail_date, v_av.time_to, v_av.airport_code) < now() then
      raise exception 'availability_expired';
    end if;
""", "rr-accept")
rr = yama(rr, "s.status in ('pending','active')) then\n      raise exception 'session_started';",
"""s.status in ('pending','active')
                 -- 🔴 300/B2: HİÇ BAŞLATILMAMIŞ boş 'pending' oturum engel değil.
                 -- 293'ten beri davet kabulü böyle bir satır açıyor; misafir
                 -- iptal edemiyor, süpürge de görmüyordu → kredi + slot kilitli.
                 and not (s.status = 'pending' and s.host_started_at is null
                          and s.guest_started_at is null)) then
      raise exception 'session_started';""", "rr-cancel")
rr = yama(rr, "     where id = v_req.id;\n\n    perform public.istek_kredisi_iade(v_req.id, 'request_refund');",
"""     where id = v_req.id;

    -- 300/B2: geride kalan boş oturumu da kapat (yetim kalmasın).
    update sessions set status = 'cancelled', completed_at = now(),
           cancelled_by = v_uid, cancel_reason = 'not_started'
     where request_id = v_req.id and status = 'pending'
       and host_started_at is null and guest_started_at is null;

    perform public.istek_kredisi_iade(v_req.id, 'request_refund');""", "rr-empty")

# ── confirm_session: hesap kapısı ───────────────────────────────
cs = tanim("confirm_session")
cs = yama(cs, "  if v_uid is null then raise exception 'not_authenticated'; end if;\n",
"""  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);   -- 300/B3: yasaklı hesap oturum kapatamaz (diğer akış fonksiyonlarıyla aynı)
""", "cs")

# ── expire_stale_sessions (a): boş pending oturumlar ───────────
es = tanim("expire_stale_sessions")
es = yama(es, "     where r.status = 'accepted' and s.id is null\n",
"""     where r.status = 'accepted'
       -- 🔴 300/B2: `s.id is null` davet kabulünün açtığı BOŞ oturumu
       -- görmüyordu (293). Hiç kimse başlatmadıysa, oturum yok sayılır.
       and (s.id is null
            or (s.status = 'pending' and s.host_started_at is null
                and s.guest_started_at is null))
""", "es-a")
es = yama(es, "  get diagnostics v_req = row_count;\n",
"""  get diagnostics v_req = row_count;
  -- 300/B2: iptal edilen isteğin arkasındaki boş oturum → 'expired' (no_show DEĞİL).
  update sessions s set status = 'expired', completed_at = now(), cancel_reason = 'not_started'
    from requests r
   where r.id = s.request_id and r.status = 'cancelled'
     and s.status = 'pending' and s.host_started_at is null and s.guest_started_at is null;
""", "es-a2")

# ── bayat_istekleri_iade_et: yerel saat ────────────────────────
bi = tanim("bayat_istekleri_iade_et")
bi = yama(bi, "       and (a.avail_date < current_date\n",
"""       -- 🔴 300/B4: UTC tarihi değil, havalimanının yerel saati. Eskiden
       -- saati geçmiş bir ilanın bekleyen isteği ertesi UTC gününe kadar
       -- açık kalıyordu (kredi tutulu, host cevap veremez).
       and (public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now()
""", "bi")

# ── create_request_impl: mükerrer + süresi geçmiş ──────────────
ci = tanim("create_request_impl")
ci = yama(ci, "        return public.create_request_impl_preflag(p_avail_id, p_type, p_intro, p_idem);",
"""        -- 🔴 300/B5: iki kapı, ikisi de ÖLÇÜLDÜ (SEED8 §5):
        --  · aynı ilana ikinci başvuru ham bir kısıt hatası döndürüyordu:
        --    "duplicate key value violates unique constraint …" — uygulama
        --    bunu "Bir şeyler ters gitti" diye gösteriyordu.
        --  · tarih bugünse ama SAAT geçmişse başvuru kabul ediliyordu.
        --  · 🔴 AYNI İLANA YENİDEN İSTEK SESSİZCE HİÇBİR ŞEY YAPMIYORDU.
        --    Uygulama tekrar-deneme anahtarını `uid:ilan` olarak üretiyor; iptal
        --    ettiğin (ya da reddedilen) isteğin anahtarı aynı kalıyordu. Yeni
        --    istek bu anahtarla gelince `preflag` ESKİ, KAPALI isteği
        --    `{"ok":true,"idempotent":true}` diye döndürüyordu — ekran "gönderildi"
        --    diyor, host hiçbir şey görmüyor. (Ölçüldü: ilk → iptal → tekrar =
        --    aynı id, durum `cancelled`.)
        --    Kapalı bir isteğin anahtarı artık serbest bırakılıyor: çift dokunuş
        --    korunur (açık istek), yeni deneme yeni istek olur.
        -- 🆕 SINIF: "BİR TEKRAR-DENEME ANAHTARI, KORUDUĞU İŞLEMDEN UZUN
        -- YAŞARSA, SONRAKİ HER GERÇEK İSTEĞİ BİR TEKRAR SANIR."
        if p_idem is not null then
          update requests set idempotency_key = null
           where idempotency_key = p_idem and guest_id = auth.uid()
             and status not in ('pending', 'accepted');
        end if;
        -- Tekrar deneme anahtarı (p_idem) ile gelen AÇIK istek dokunulmadan geçer.
        if p_idem is null or not exists (select 1 from requests
                                          where idempotency_key = p_idem and guest_id = auth.uid()) then
          if exists (select 1 from requests where guest_id = auth.uid() and avail_id = p_avail_id
                                              and status in ('pending','accepted')) then
            raise exception 'already_requested';
          end if;
          if exists (select 1 from availabilities a where a.id = p_avail_id
                      and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now()) then
            raise exception 'availability_expired';
          end if;
        end if;

        return public.create_request_impl_preflag(p_avail_id, p_type, p_intro, p_idem);""", "ci")

# ── bakiye tetikleyicisi: kredi kilidi ─────────────────────────
bt = tanim("trg_bakiye_negatife_dusemez")
bt = yama(bt, "  select coalesce(sum(delta), 0) into v_bal\n    from credit_ledger where user_id = new.user_id;",
"""  -- 🔴 300/B6: KİLİT TETİKLEYİCİNİN İÇİNDE. 299/B2 kilidi dört yola
  -- koymuştu; `misafir_hakki_hediye_et` beşinciydi ve kilitsizdi. İki
  -- eşzamanlı hediye aynı 3 krediyi iki kez harcayabiliyordu (ölçüldü:
  -- ikinci oturum birincinin commit'ini beklemeden geçti).
  -- Kilit burada olunca YOL SAYISI önemsizleşiyor: bakiyeyi eksilten her
  -- satır, aynı kullanıcının diğer eksiltmesini commit'e kadar bekler ve
  -- sonra GÜNCEL toplamı okur.
  perform pg_advisory_xact_lock(hashtextextended('kredi:' || new.user_id::text, 0));
  select coalesce(sum(delta), 0) into v_bal
    from credit_ledger where user_id = new.user_id;""", "bt")

# 300 kendi yeniden tanımladığı gövdede ASCII'leşmiş Türkçeyi de düzeltiyor
# (kural_metni_check aynı borcu ikinci kez saymasın — borç kopyalanmaz, ödenir).
bt = yama(bt, "'kullanici %s: bakiye %s, denenen %s (%s)'", "'kullanıcı %s: bakiye %s, denenen %s (%s)'", "bt-tr1")
bt = yama(bt, "'Bu satir bakiyeyi negatife dusururdu; 299/B1 reddetti.'", "'Bu satır bakiyeyi negatife düşürürdü; 299/B1 reddetti.'", "bt-tr2")

cikti = []
cikti.append(open(os.path.join(os.path.dirname(__file__), "300_bas.sql"), encoding="utf-8").read())
for baslik, govde in [
    ("§B1–B2 · respond_request", rr), ("§B3 · confirm_session", cs),
    ("§B2 · expire_stale_sessions", es), ("§B4 · bayat_istekleri_iade_et", bi),
    ("§B5 · create_request_impl", ci), ("§B6 · trg_bakiye_negatife_dusemez", bt)]:
    cikti.append("-- " + "─" * 70 + "\n-- " + baslik + "  (canlı tanım + 300 yaması)\n-- " + "─" * 70 + "\n" + govde + "\n")
cikti.append(open(os.path.join(os.path.dirname(__file__), "300_son.sql"), encoding="utf-8").read())
open(sys.argv[1], "w", encoding="utf-8").write("".join(cikti))
print("300 üretildi:", sys.argv[1])
