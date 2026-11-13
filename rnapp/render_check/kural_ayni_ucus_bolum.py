# -*- coding: utf-8 -*-
"""
LoungeLink · render_check/kural_ayni_ucus_bolum.py   (13 Kasım 2026 · SQL 359)

kural_motoru_tam_e2e.py içinden exec edilir (q, chk, secim, ilan, hedef aynı ad alanında).

C · AYNI UÇUŞ ŞARTI (DragonPass md.7.15.7) — Gökberk'in kararı:
    "iki uçuş numarası da biliniyor ve farklıysa kesin engel; uçuş numarası girilmemişse
     eskisi gibi uyarı + onay."
Her senaryo DÖRT katmanda ölçülür: kart (rozet), gönderme ekranı (ön kontrol), kural satırı,
sunucu (create_request). Senaryo alt işlemde koşar, geri alınır.
"""
q(r"""
create or replace function public.ucus_kos(p_g uuid, p_av uuid, p_host_flight text, p_guest_flight text,
  p_dest text, p_cache jsonb, p_dil text)
returns jsonb language plpgsql set search_path = public as $uk$
declare a availabilities%rowtype; v_out jsonb; v_pre jsonb; v_rz jsonb; v_kk jsonb; v_srv text; v6 jsonb; v_vid uuid;
  c jsonb;
begin
  select * into a from availabilities where id = p_av;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_g, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_g::text, true);
    perform public.dili_ayarla(p_dil);
    update availabilities set flight_number = p_host_flight where id = p_av;
    delete from requests where guest_id = p_g;
    delete from visits where user_id = p_g and visit_date = a.avail_date;
    for c in select * from jsonb_array_elements(coalesce(p_cache, '[]'::jsonb)) loop
      insert into flight_cache (flight_no, flight_date, codeshared, operating_iata, airline_iata)
      values (c ->> 'no', a.avail_date, c -> 'cs', c ->> 'op', c ->> 'al')
      on conflict (flight_no, flight_date) do update set codeshared = excluded.codeshared,
        operating_iata = excluded.operating_iata, airline_iata = excluded.airline_iata;
    end loop;
    insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number, carrier_code, party_size)
    values (p_g, a.airport_code, p_dest, a.avail_date, a.time_from, a.time_to, p_guest_flight,
            public.carrier_from_flight(p_guest_flight), 1)
    returning id into v_vid;
    v6 := public.lounge_access_decision_v6(p_av, p_guest_flight, public.carrier_from_flight(p_guest_flight), v_vid);
    v_pre := public.request_precheck(p_av);
    select to_jsonb(b) into v_rz from public.discovery_rule_badges(array[p_av]) b limit 1;
    select to_jsonb(k) into v_kk from public.kural_kosullari(p_av) k where k.kod = 'ucus_bagi';
    begin
      perform public.create_request(p_av, 'lounge', null, null);
      v_srv := 'ok';
    exception when others then v_srv := split_part(sqlerrm, ' ', 1);
    end;
    v_out := jsonb_build_object('v6', v6, 'pre', v_pre, 'rozet', v_rz, 'kk', v_kk, 'srv', v_srv);
    raise exception 'MAT_GERI';
  exception when others then
    if sqlerrm <> 'MAT_GERI' then v_out := jsonb_build_object('hata', left(sqlerrm, 300)); end if;
  end;
  perform public.dili_ayarla('tr');
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  return v_out;
end $uk$;
""")

print("\n=== C · AYNI UÇUŞ ŞARTI (359) ===")
dp = q("""select a.id::text, a.airport_code::text, a.host_id::text from availabilities a
           where a.active and a.avail_date > current_date and a.visibility <> 'Hidden'
             and public.lounge_access_decision_v6(a.id, null, null, null) ->> 'flight_coupling' = 'same_flight'
           order by a.airport_code, a.id""")
print(f"  aynı uçuş şartlı ilan: {len(dp)}")
chk("test dünyasında aynı uçuş şartlı (DragonPass) ilan var", len(dp) > 0)

# temel: aynı uçuşla sunucunun KABUL ettiği (ilan, misafir, varış) üçlüsünü bul — diğer boyutlar engel olmasın
temel = None
for (avid, ap, host) in dp:
    for m in secim:
        if m[0] == host:
            continue
        for dest in [x for x in hedef.get(ap, (None, None)) if x] + [None]:
            j = q("select public.ucus_kos(%s,%s,'TK1985','TK1985',%s,null,'tr')", (m[0], avid, dest))[0][0]
            if j and j.get("srv") == "ok":
                temel = (avid, m[0], dest); break
        if temel: break
    if temel: break
chk("aynı uçuşta sunucunun kabul ettiği bir DragonPass ilanı bulundu", temel is not None)

if temel:
    AV, G, DEST = temel
    def kos(hf, gf, cache=None, dil='tr'):
        return q("select public.ucus_kos(%s,%s,%s,%s,%s,%s::jsonb,%s)",
                 (G, AV, hf, gf, DEST, json.dumps(cache) if cache else None, dil))[0][0] or {}

    def ozet(j):
        p = j.get("pre") or {}; r = j.get("rozet") or {}; k = j.get("kk") or {}; v = j.get("v6") or {}
        return dict(durum=v.get("same_flight_state"), kesin=v.get("same_flight_block"), sev=v.get("severity"),
                    can=p.get("can_request"), ack=p.get("needs_ack"), bas=p.get("headline"), det=p.get("detail"),
                    rozet_engel=r.get("blocks_request"), rozet=r.get("label"), satir=(k.get("durum"), k.get("metin")),
                    srv=j.get("srv"), hata=j.get("hata"))

    S = {}
    S["ayni"]        = ozet(kos("TK1985", "TK1985"))
    S["yazim"]       = ozet(kos("TK 1985", "tk01985"))
    S["farkli_ayni_hy"] = ozet(kos("TK1985", "TK2000"))
    S["farkli_hy"]   = ozet(kos("TK1985", "PC2010"))
    S["misafir_yok"] = ozet(kos("TK1985", None))
    S["host_yok"]    = ozet(kos(None, "TK1985"))
    S["ikisi_yok"]   = ozet(kos(None, None))
    # önbellek: misafirin LH6543'ü TK1985'in kod paylaşımı → aynı sefer
    S["kod_paylasimi"] = ozet(kos("TK1985", "LH6543", [
        {"no": "LH6543", "cs": {"airline_iata": "TK", "flight_iata": "TK1985", "flight_number": "1985"}, "op": "TK", "al": "LH"}]))
    # önbellek iki seferi de biliyor, ikisi de kendi uçağı → kesin farklı
    S["onbellek_farkli"] = ozet(kos("TK1985", "PC2010", [
        {"no": "TK1985", "cs": None, "op": "TK", "al": "TK"}, {"no": "PC2010", "cs": None, "op": "PC", "al": "PC"}]))
    # önbellekte yalnız host'un seferi var: aynı havayolu farklı numara yine kesin farklı
    S["tek_onbellek_ayni_hy"] = ozet(kos("TK1985", "TK2000", [{"no": "TK1985", "cs": None, "op": "TK", "al": "TK"}]))
    # önbellekte yalnız host'un seferi var, misafir başka havayolu: kod paylaşımı olabilir → uyarı
    S["tek_onbellek_farkli_hy"] = ozet(kos("TK1985", "LH6543", [{"no": "TK1985", "cs": None, "op": "TK", "al": "TK"}]))
    # ICAO yazımı (THY1985): havayolu kodu çözülemez → engel YOK, uyarı
    S["icao"] = ozet(kos("TK1985", "THY1985"))
    S["en_farkli"]   = ozet(kos("TK1985", "TK2000", dil='en'))
    S["en_belirsiz"] = ozet(kos("TK1985", "PC2010", dil='en'))
    for k_, v_ in S.items():
        print(f"  {k_:16} {json.dumps(v_, ensure_ascii=False, default=str)[:330]}")

    hatasiz = [k_ for k_, v_ in S.items() if v_.get("hata")]
    chk("C senaryoları hatasız koştu", not hatasiz, [(k_, S[k_]["hata"]) for k_ in hatasiz])

    def acik(v, ack=None):   # dört katman "başvurabilir" diyor
        return (v["can"] is True and v["srv"] == "ok" and not v["rozet_engel"] and v["satir"][0] != "yok"
                and (ack is None or bool(v["ack"]) == ack))

    def kapali(v):          # dört katman "başvuramaz" diyor
        return v["can"] is False and v["srv"] == "blocked_by_rule" and v["rozet_engel"] is True and v["satir"][0] == "yok"

    chk("aynı uçuş (TK1985 = TK1985): dört katman açık, satır 'ok'", acik(S["ayni"]) and S["ayni"]["satir"][0] == "ok", S["ayni"])
    chk("yazım farkı (TK 1985 = tk01985): aynı uçuş sayılır, açık, satır 'ok'",
        acik(S["yazim"]) and S["yazim"]["durum"] == "ayni" and S["yazim"]["satir"][0] == "ok", S["yazim"])
    chk("aynı havayolu farklı numara (TK1985 ↔ TK2000): dört katman KAPALI", kapali(S["farkli_ayni_hy"]), S["farkli_ayni_hy"])
    chk("kesin engelde başlık sebebi söyler (TR)",
        S["farkli_ayni_hy"]["bas"] == "Aynı uçuşta değilsiniz" and "TK1985" in (S["farkli_ayni_hy"]["det"] or "")
        and "TK2000" in (S["farkli_ayni_hy"]["det"] or ""), S["farkli_ayni_hy"])
    chk("kesin engelde kart rozeti sebebi söyler", S["farkli_ayni_hy"]["rozet"] == "Aynı uçuşta değilsiniz", S["farkli_ayni_hy"]["rozet"])
    chk("farklı havayolu, önbellek bilmiyor (TK1985 ↔ PC2010): açık + onay kutusu, uyarı metni",
        acik(S["farkli_hy"], ack=True) and S["farkli_hy"]["durum"] == "belirsiz"
        and S["farkli_hy"]["bas"] == "Uçuş numaralarınız farklı" and S["farkli_hy"]["satir"][0] == "bilinmiyor", S["farkli_hy"])
    chk("misafirin uçuşu yok: açık + onay kutusu, 'uçuş numaranı ekle' der",
        acik(S["misafir_yok"], ack=True) and "uçuş numaranı ekle" in (S["misafir_yok"]["det"] or ""), S["misafir_yok"])
    chk("host'un uçuşu yok: açık + onay kutusu, 'Host uçuşunu girmedi' der",
        acik(S["host_yok"], ack=True) and "Host uçuşunu girmedi" in (S["host_yok"]["det"] or ""), S["host_yok"])
    chk("iki uçuş da yok: açık + onay kutusu", acik(S["ikisi_yok"], ack=True), S["ikisi_yok"])
    chk("kod paylaşımı (LH6543 = TK1985 seferi, önbellekten): aynı uçuş, açık",
        acik(S["kod_paylasimi"]) and S["kod_paylasimi"]["durum"] == "ayni", S["kod_paylasimi"])
    chk("önbellek iki seferi de biliyor ve farklı: dört katman KAPALI", kapali(S["onbellek_farkli"]), S["onbellek_farkli"])
    chk("önbellekte yalnız host var, aynı havayolu farklı numara: KAPALI", kapali(S["tek_onbellek_ayni_hy"]), S["tek_onbellek_ayni_hy"])
    chk("önbellekte yalnız host var, başka havayolu: açık + onay (kod paylaşımı olabilir)",
        acik(S["tek_onbellek_farkli_hy"], ack=True) and S["tek_onbellek_farkli_hy"]["durum"] == "belirsiz", S["tek_onbellek_farkli_hy"])
    chk("ICAO yazımı (THY1985): engellenmez, açık + onay", acik(S["icao"], ack=True), S["icao"])
    chk("EN: kesin engel başlığı İngilizce", S["en_farkli"]["bas"] == "You're not on the same flight"
        and S["en_farkli"]["rozet"] == "Not on the same flight" and kapali(S["en_farkli"]), S["en_farkli"])
    chk("EN: belirsiz uyarı İngilizce", S["en_belirsiz"]["bas"] == "Your flight numbers differ" and acik(S["en_belirsiz"], ack=True),
        S["en_belirsiz"])
    tr_ham = [k_ for k_, v_ in S.items() if any(re.search(r"\b[a-z]+_[a-z_]+\b", str(v_.get(f) or "")) for f in ("bas", "det", "rozet"))]
    chk("ekrana giden metinlerde ham kod yok", not tr_ham, tr_ham)
    uzun = [(k_, len(v_["det"] or "")) for k_, v_ in S.items()
            if len(v_.get("det") or "") > 140 or (v_.get("det") or "").endswith("…")]
    chk("açıklama 140 karakteri aşmıyor (kırpılmıyor)", not uzun, uzun)

    # Kesin engelde sunucunun döndürdüğü kod uygulamada TR+EN çevriliyor (yeni sürüm gerekmez)
    i18n_ = open(ROOT / "src" / "i18n.js", encoding="utf-8").read()
    chk("'blocked_by_rule' uygulamanın errMap'inde TR+EN var", i18n_.count('"blocked_by_rule":') >= 2)

    # Aynı uçuş şartı OLMAYAN ilanlar 359'dan etkilenmedi: same_flight_state boş
    diger_ = q("""select count(*) from availabilities a
                   where a.active and a.avail_date > current_date
                     and coalesce(public.lounge_access_decision_v6(a.id, 'TK1985', 'TK', null) ->> 'flight_coupling','') <> 'same_flight'
                     and public.lounge_access_decision_v6(a.id, 'TK1985', 'TK', null) ->> 'same_flight_state' is not null""")[0][0]
    chk("aynı uçuş şartı olmayan ilanlarda yeni alan boş (başka kurala dokunulmadı)", diger_ == 0, diger_)
