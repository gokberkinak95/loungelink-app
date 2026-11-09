# -*- coding: utf-8 -*-
"""
LoungeLink · duzelt_349_uret.py   (9 Kasım 2026)

348'in "olması gereken" kaynağı, pg_run'ın İKİNCİ geçişinden SONRA alınmış bir veritabanıydı;
o geçiş bazı fonksiyonları eski hâline yazıyordu. Sonuç: 348 canlıda create_availability'yi
(ve başka gövde/yetkileri) geriletti. Bu betik, ikinci geçiş OLMADAN 001-347 kurulmuş yerel
veritabanından (LL_TEKRAR_ATLA=1, 127.0.0.1:5432) DOĞRU hâli okur ve 348'in dokunduğu her
nesne için 348 sonrası canlı ≠ doğru olanları geri yazan 349'u üretir.
"""
import os, re, subprocess, sys

PSQL = os.path.expanduser(r"~\AppData\Roaming\Python\Python312\site-packages\pgserver\pginstall\bin\psql.exe")
KOK = os.path.dirname(os.path.abspath(__file__))

# 348'in canlıya yazdığı (= ilk DENETIM_TAM "beklenen_iz") — charter_note 348'in Türkçe sürümü.
CANLI_SIMDI = {
    "bo_plan_hediyeleri(p_durum text)": "5b1cb6016416d0283caa27d469e271e6:D:--",
    "card_advice_for_airport(p_airport text)": "be48466bf6645b283901ddc6a37f0671:D:-u",
    "charter_note(p_avail_id uuid)": "41c6553407d7e2764b12514d03f03ee1:D:-u",
    "create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text)": "423b4191c603523939f8cff4b6b92329:D:-u",
    "discover_availabilities_ham(p_airport text, p_sector text, p_flight text, p_date date)": "5bdac4e371b191c2bc780bd3707a08d2:D:-u",
    "host_requests()": "fe23603a880d2eb1f9934b37d854ba21:D:-u",
    "istegin_acik_oturumu_var_mi(p_req uuid)": "30a5cffae595ffefb14674777b6d5c60:D:-u",
    "plan_kredisi_kalan(p_user uuid)": "a9e09465c748a83239ff5e09f8601e93:D:-u",
    "plan_ucretli(p_plan text)": "994351f4977fc984672768d6e982331b:D:-u",
    "profil_dogrulandi_hesapla(p_user uuid)": "f4f34231e4d8b7b3e8b3fb8b34710162:D:-u",
    "push_kanali(p_category notif_category)": "d8a61aec201d25ff0a0ca4613172c688:I:-u",
    "push_kanali(p_category text)": "9feb08d0e624e7c66babe253e60c3b39:I:-u",
    "request_credit_cost(p_user uuid, p_avail uuid)": "cf212b4ec7ecc582e53ea35b6480284b:D:--",
    "seed_test_hesabi(p_email text)": "a7e379b130b62d19b1c5ddbc32ce87e9:I:-u",
    "sogu_baslangic_ozeti(p_airport text)": "7f311329cd0149b71b469f52b6fcda71:D:-u",
    "telefon_kanonik(p_phone text)": "494fe8061a8cd3ce8ec9cbfc8c54e57f:I:-u",
    "trg_bakiye_negatife_dusemez()": "a85157a102d2376edbc3185b03f14da1:I:--",
    "trg_cinsiyet_kilidi()": "9680901ee5a4af893f6c8aa615916e73:D:--",
    "trg_huni_istek()": "eef8e54bad64622bdbb089f1bf0193a2:D:--",
    "trg_huni_oturum()": "473941a4ca4a589b6395d87dff465dce:D:--",
    "trg_iade_tutulani_asamaz()": "4dbbb921b2f6e37da905c2c2c1340d88:I:--",
    "trg_kisit_gozden_gecir()": "da9fc9ba649a7e62c5b421d61aa30017:D:--",
    "trg_kredi_paketi_kapisi()": "de494d38e5062d1c73e83ce903aa7879:I:--",
    "trg_mesaj_bildirimi()": "a11da468af76b013b1fa90edf9406d15:D:--",
    "trg_puan_negatife_dusemez()": "2c94287d32c4d0eb4964179468d410a4:I:--",
    "trg_sohbet_suzgeci()": "a8e23e29e8302725a561251793d5293a:D:--",
    "trg_soru_bildirimi_host()": "7be8dad318e40dfe2fd602007e6e5195:D:--",
    "trg_soru_metni()": "36d7578ec8e63da5fad0302725bcb798:D:--",
    "tutma_sebepleri()": "87247daf7f26e5292d51d1ac9bb5eb26:I:-u",
    "tutma_varsayim_esigi()": "a654f00eb3cb09aeaf81827aca220da4:I:-u",
    "tutulan_kredi(p_req uuid)": "948c6b92f35668560605738cfaa4861d:I:-u",
    "ucus_hatti(p_origin text, p_dest text)": "0ef624bbbc16250e608672038cfcd29e:I:-u",
    "yerel_an(p_date date, p_time time without time zone, p_airport text)": "c864768f1bc5cfeb8412fa13b46d0b59:D:au",
    "yerel_gun(p_airport text)": "cb482e33a49b284716f1b02cf7c90f01:D:au",
    "yerel_saat(p_airport text)": "a62ee57d373702fe4aa3710c4aff703a:D:au",
    "yonetici_kapisi()": "31841154bbff903d19ba2cf3328643d3:D:--",
}
# 348 öncesi canlı (ilk DENETIM_TAM "canli_iz") — karşılaştırma için
CANLI_ONCE = {
    "bo_plan_hediyeleri(p_durum text)": "148a7074565b7120378b0d3b586fe9da:D:--",
    "card_advice_for_airport(p_airport text)": "780fa2ba50c771535f37dd7a8fd522c3:D:-u",
    "charter_note(p_avail_id uuid)": "5a0e637d63942fa4e1ac42d9e47d6f22:D:-u",
    "create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text)": "ed18e0e5cc9021d34e441b4432b18bb0:D:-u",
    "discover_availabilities_ham(p_airport text, p_sector text, p_flight text, p_date date)": "bfc942ce22d73880dff1cb04a384105e:D:-u",
    "host_requests()": "3fb98e72045b4de559e78b77469b44ba:D:-u",
    "request_credit_cost(p_user uuid, p_avail uuid)": "85e997543926aea7fd79cf8ecf6b7264:D:--",
    "trg_soru_bildirimi_host()": "40de8b989f16467a0805c034fecff939:D:--",
    "trg_soru_metni()": "77cba74e7dd8df229112ff18dce99f50:D:--",
}

def psql(sql):
    r = subprocess.run([PSQL, "-h", "127.0.0.1", "-p", "5432", "-U", "postgres", "-d", "postgres",
                        "-At", "-v", "ON_ERROR_STOP=1", "-c", sql],
                       capture_output=True, text=True, encoding="utf-8",
                       env={**os.environ, "PGCLIENTENCODING": "UTF8"})
    if r.returncode != 0:
        sys.exit("psql hata: " + r.stderr[:1500])
    return r.stdout

def oid(imza):
    ad, arg = imza.split("(", 1)
    return (f"(select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
            f"where n.nspname = 'public' and p.proname = '{ad}' "
            f"and pg_get_function_identity_arguments(p.oid) = '{arg[:-1]}')")

def iz(imza):
    o = oid(imza)
    return psql(f"select md5(regexp_replace(pg_get_functiondef({o}), '\\s+', '', 'g')) || ':' || "
                f"case when (select prosecdef from pg_proc where oid = {o}) then 'D' else 'I' end || ':' || "
                f"case when has_function_privilege('anon', {o}, 'execute') then 'a' else '-' end || "
                f"case when has_function_privilege('authenticated', {o}, 'execute') then 'u' else '-' end").strip()

TR_METIN = [  # 348'de Türkçeleştirilen charter_note metinleri (doğru gövdeye yeniden uygulanır)
    ("Bu salona giris HAVAYOLU statusune degil ", "Bu salona giriş havayolu statüsüne değil "),
    ("'UYELIGE bagli oldugu icin charter olmasi sorun degildir — gecerli '", "'üyeliğe bağlı olduğu için charter olması sorun değildir; geçerli '"),
    ("'binis karti yeterlidir.'", "'biniş kartı yeterlidir.'"),
]

def main():
    govde, yetki, rapor = [], [], []
    for imza, simdi in CANLI_SIMDI.items():
        dogru = iz(imza)
        if not dogru:
            sys.exit("yerelde yok: " + imza)
        dg, ds, dy = dogru.split(":"); sg, ss, sy = simdi.split(":")
        once = CANLI_ONCE.get(imza, "")
        ad = "public." + imza
        if dg != sg and not imza.startswith("charter_note"):
            tanim = psql(f"select pg_get_functiondef({oid(imza)})").rstrip().replace("CREATE OR REPLACE FUNCTION", "create or replace function")
            on = "drop function if exists public.host_requests();\n" if imza == "host_requests()" else ""
            govde.append(f"-- {imza}  (348 sonrası {sg[:8]} → doğru {dg[:8]}; 348 öncesi canlı {once[:8] or '?'})\n{on}{tanim};\n")
            rapor.append(f"GOVDE {imza[:60]} : simdi {sg[:8]} dogru {dg[:8]} once {once[:8]}")
        if dy != sy or (dg != sg and not imza.startswith("charter_note")):
            satir = [f"revoke execute on function {ad} from public, anon, authenticated;",
                     f"grant execute on function {ad} to service_role;"]
            if dy[0] == "a": satir.append(f"grant execute on function {ad} to anon;")
            if dy[1] == "u": satir.append(f"grant execute on function {ad} to authenticated;")
            yetki.append(f"-- {imza}  ({sy} → {dy})\n" + "\n".join(satir))
            if dy != sy: rapor.append(f"YETKI {imza[:60]} : {sy} -> {dy}")
    open(os.path.join(KOK, "_349_govde.sql"), "w", encoding="utf-8", newline="\n").write("\n".join(govde))
    open(os.path.join(KOK, "_349_yetki.sql"), "w", encoding="utf-8", newline="\n").write("\n\n".join(yetki) + "\n")
    print("\n".join(rapor)); print("govde", len(govde), "yetki", len(yetki))

if __name__ == "__main__":
    main()
