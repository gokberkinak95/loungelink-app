# -*- coding: utf-8 -*-
"""
LoungeLink · esitle_uret.py   (9 Kasım 2026)

DENETIM_TAM canlıda fark verdi. Bu betik, 001..son dosyaların yerelde kurduğu
"olması gereken" veritabanından (127.0.0.1:5432; YALNIZ `LL_TEKRAR_ATLA=1 python pg_run.py --keep` ile — ikinci geçiş fonksiyonları geriletiyordu, 349 notu) şu farkları kapatan bir SQL üretir:
  · gövdesi farklı fonksiyonlar → yerel tanımın birebir kopyası (create or replace)
  · yetkisi farklı fonksiyonlar → anon / authenticated çalıştırma yetkisi yereldeki gibi
Çıktı: sql/348_canli_esitleme.sql (elle eklenen bölümlerle birlikte).
"""
import os, subprocess, sys

PSQL = os.path.expanduser(r"~\AppData\Roaming\Python\Python312\site-packages\pgserver\pginstall\bin\psql.exe")
KOK = os.path.dirname(os.path.abspath(__file__))

GOVDE = [  # DENETIM_TAM: gövde özeti farklı (canlı ≠ dosyalar)
    "bo_plan_hediyeleri(p_durum text)",
    "card_advice_for_airport(p_airport text)",
    "charter_note(p_avail_id uuid)",
    "create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text)",
    "discover_availabilities_ham(p_airport text, p_sector text, p_flight text, p_date date)",
    "host_requests()",
    "request_credit_cost(p_user uuid, p_avail uuid)",
    "trg_soru_bildirimi_host()",
    "trg_soru_metni()",
]
YETKI = [  # DENETIM_TAM: yalnız yetki farklı (+ gövdesi farklı olanlar da yeniden eşitlenir)
    "istegin_acik_oturumu_var_mi(p_req uuid)", "plan_kredisi_kalan(p_user uuid)", "plan_ucretli(p_plan text)",
    "profil_dogrulandi_hesapla(p_user uuid)", "push_kanali(p_category notif_category)", "push_kanali(p_category text)",
    "seed_test_hesabi(p_email text)", "sogu_baslangic_ozeti(p_airport text)", "telefon_kanonik(p_phone text)",
    "trg_bakiye_negatife_dusemez()", "trg_cinsiyet_kilidi()", "trg_huni_istek()", "trg_huni_oturum()",
    "trg_iade_tutulani_asamaz()", "trg_kisit_gozden_gecir()", "trg_kredi_paketi_kapisi()", "trg_mesaj_bildirimi()",
    "trg_puan_negatife_dusemez()", "trg_sohbet_suzgeci()", "tutma_sebepleri()", "tutma_varsayim_esigi()",
    "tutulan_kredi(p_req uuid)", "ucus_hatti(p_origin text, p_dest text)",
    "yerel_an(p_date date, p_time time without time zone, p_airport text)", "yerel_gun(p_airport text)",
    "yerel_saat(p_airport text)", "yonetici_kapisi()",
]


def psql(sql):
    r = subprocess.run([PSQL, "-h", "127.0.0.1", "-p", "5432", "-U", "postgres", "-d", "postgres",
                        "-At", "-v", "ON_ERROR_STOP=1", "-c", sql],
                       capture_output=True, text=True, encoding="utf-8",
                       env={**os.environ, "PGCLIENTENCODING": "UTF8"})
    if r.returncode != 0:
        sys.exit("psql hata: " + r.stderr[:1500])
    return r.stdout


def oid_sorgusu(imza):
    ad, arg = imza.split("(", 1)
    arg = arg[:-1]
    return (f"select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
            f"where n.nspname = 'public' and p.proname = '{ad}' "
            f"and pg_get_function_identity_arguments(p.oid) = '{arg}'")


def main():
    parcalar = []
    for imza in GOVDE:
        tanim = psql(f"select pg_get_functiondef(({oid_sorgusu(imza)})::oid)").rstrip()
        if not tanim:
            sys.exit("yerelde yok: " + imza)
        parcalar.append(f"-- {imza}\n{tanim};\n")
    yetki = []
    for imza in GOVDE + YETKI:
        r = psql(f"select has_function_privilege('anon', o, 'execute'), has_function_privilege('authenticated', o, 'execute') "
                 f"from ({oid_sorgusu(imza)}) x(o)").strip()
        if not r:
            sys.exit("yerelde yok: " + imza)
        a, u = r.split("|")
        ad = "public." + imza
        satir = [f"revoke execute on function {ad} from public, anon, authenticated;",
                 f"grant execute on function {ad} to service_role;"]
        if a == "t":
            satir.append(f"grant execute on function {ad} to anon;")
        if u == "t":
            satir.append(f"grant execute on function {ad} to authenticated;")
        yetki.append(f"-- {imza} → anon {'açık' if a == 't' else 'kapalı'} · authenticated {'açık' if u == 't' else 'kapalı'}\n" + "\n".join(satir))
    open(os.path.join(KOK, "_348_govde.sql"), "w", encoding="utf-8", newline="\n").write("\n".join(parcalar))
    open(os.path.join(KOK, "_348_yetki.sql"), "w", encoding="utf-8", newline="\n").write("\n\n".join(yetki) + "\n")
    print("govde", len(parcalar), "yetki", len(yetki))


if __name__ == "__main__":
    main()
