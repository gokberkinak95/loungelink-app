# -*- coding: utf-8 -*-
"""301'i üretir — canlı tanımın ÜSTÜNE yama (299/A2 dersi). Çapa yoksa durur."""
import subprocess, sys, os
DB = os.environ.get("LLDB", "ll")
def tanim(ad):
    r = subprocess.run(["psql","-U","postgres","-d",DB,"-Atc",
        f"select pg_get_functiondef(p.oid) from pg_proc p where proname='{ad}' and pronamespace='public'::regnamespace"],
        capture_output=True, text=True)
    if r.returncode or not r.stdout.strip(): sys.exit(f"tanım okunamadı: {ad}")
    if "301/" in r.stdout: sys.exit(f"{ad}: zaten 301 yamalı — 301 öncesi DB'de koş (LLDB=...)")
    return r.stdout.rstrip() + ";\n"
def yama(m, eski, yeni, ad):
    n = m.count(eski)
    if n != 1: sys.exit(f"ÇAPA {ad}: {n} kez")
    return m.replace(eski, yeni)

iv = tanim("is_visible")
iv = yama(iv, "  select not coalesce(", "  -- 301/§3: test hesapları gerçek kullanıcıya görünmez (BO flag: test_hesaplarini_gizle)\n  select not public.test_hesabi_gizli_mi(p_user) and not coalesce(", "iv")

hn = tanim("havalimani_nabzi")
hn = yama(hn, "       and a.visibility <> 'Hidden'\n", "       and a.visibility <> 'Hidden'\n       and not public.test_hesabi_gizli_mi(a.host_id)   -- 301/§3\n", "hn-arz")
hn = yama(hn, "     where v.visit_date between current_date and v_son\n", "     where v.visit_date between current_date and v_son\n       and not public.test_hesabi_gizli_mi(v.user_id)   -- 301/§3\n", "hn-sey")

ca = tanim("create_availability")
ca = yama(ca, "    raise exception 'not_a_host';\n  end if;\n",
"""    raise exception 'not_a_host';
  end if;
  -- 🔴 301/§5: KENDİ İLANIYLA ÇAKIŞAN İLAN açılabiliyordu (tam akış testi,
  -- 10–13 varken 12–15 GEÇTİ). `update_availability` bunu 'kendi_ilanlarin_
  -- cakisiyor' ile zaten reddediyordu — açma yolu reddetmiyordu. Aynı kişi
  -- aynı saatte iki salonda olamaz; ikinci ilana kabul edilen misafir kapıda kalır.
  if exists (select 1 from availabilities a
              where a.host_id = auth.uid() and a.active
                and a.avail_date = p_date
                and a.time_from < p_to and p_from < a.time_to) then
    raise exception 'kendi_ilanlarin_cakisiyor'
      using hint = 'Bu saatte başka bir ilanın var. Önce onu kaldır ya da saatleri ayır.';
  end if;
""", "ca")

ys = tanim("seyahat_sil")
ys = yama(ys, "  if public.seyahate_bagli_basvuru(p_id) then",
"""  -- 🔴 301/§8: fonksiyon SAYI döndürüyor; `if <sayı> then` 0/1 için
  -- tesadüfen çalışıyor ('0'/'1' geçerli boolean metni), 2+ açık başvuruda
  -- "invalid input syntax for type boolean: \"2\"" ile patlıyordu (tam akış testi).
  if public.seyahate_bagli_basvuru(p_id) > 0 then""", "ys")

bg = tanim("blok_gecmisi_kapat")
bg = yama(bg, """  update requests set status = 'cancelled', responded_at = now()
   where status = 'pending'
     and ((guest_id = new.blocker and host_id = new.blocked)
       or (guest_id = new.blocked and host_id = new.blocker));
""", """  -- 🔴 301/§9: 204'ten beri bekleyen istek KAPANIYOR ama tutulan kredi
  -- İADE EDİLMİYORDU (tam akış testi: defterde yalnız `request_hold:-1`).
  -- Engelleme uygulamadan yapılamadığı için bu hiç görünmemişti; 301 §1
  -- engellemeyi açınca canlı hataya dönüşecekti. Artık her kapanan istek
  -- iade yolundan geçiyor (tekrar iadeyi `istek_kredisi_iade` kendisi önler).
  declare v_r record;
  begin
    for v_r in
      update requests set status = 'cancelled', responded_at = now()
       where status = 'pending'
         and ((guest_id = new.blocker and host_id = new.blocked)
           or (guest_id = new.blocked and host_id = new.blocker))
      returning id
    loop
      perform public.istek_kredisi_iade(v_r.id, 'request_refund');
    end loop;
  end;
""", "bg")

d = os.path.dirname(__file__)
out = open(os.path.join(d, "301_bas.sql"), encoding="utf-8").read()
for b, g in [("§3b · is_visible", iv), ("§3c · havalimani_nabzi", hn), ("§5 · create_availability", ca), ("§8 · seyahat_sil", ys), ("§9 · blok_gecmisi_kapat", bg)]:
    out += "-- " + "─"*70 + "\n-- " + b + " (canlı tanım + 301 yaması)\n-- " + "─"*70 + "\n" + g + "\n"
out += open(os.path.join(d, "301_son.sql"), encoding="utf-8").read()
open(sys.argv[1], "w", encoding="utf-8").write(out)
print("301 üretildi")
