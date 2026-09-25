-- ============================================================
-- 190 · SALON TEKİLLEŞTİRME + İÇ/DIŞ HAT MİMARİSİ
-- 17 Ağustos 2026
--
-- 🔴 GÖKBERK: "Loungelarda duplicate olmamaya dikkat et, iç hat dış hat
-- ayrımına ve bunların lounge modalındaki sekmelere doğru şekilde
-- yansımasına özen göster. Aynı isimde hem iç hat hem dış hat lounge'ı
-- olabilir, bu durumda duplicate olmamış olur ama onları doğru yerlere
-- yerleştirmelisin."
--
-- 🔴 HAKLI — 188 YENİ BİR DUPLICATE KATMANI YARATTI. ÖLÇÜM:
--   IST'te aynı salon iki adla yan yana duruyordu:
--     "Turkish Airlines Lounge — Dış Hat (Business)"          [THY, 1 kural]
--     "İstanbul Havalimanı dış hatlar özel yolcu salonu — Business Lounge"
--                                              [Turkish Airlines, 0 kural]
--   16 (havalimanı × kapsam × bölüm) grubunda çift kayıt:
--     ADB ASR AYT BKK COV ESB GZT HTY IST(×2) MIA NBO RZV SAW TZX VKO
--   Ayrıca lounges_for_airport('IST') XpresSpa / iGA Shower / iGA Sleepod
--   döndürüyordu — 161 bunları katalogdan çıkarmıştı, 188'in katalog
--   eklemesi venue_kind kontrolü yapmadığı için geri geldiler (3 kayıt).
--
-- 🔴 KENDİ HATAMIN DERSİ: 188 "mevcut veriye dokunmaz, her ekleme
-- idempotenttir" diye yazılmıştı ve DOĞRUYDU — ama idempotanlık
-- YALNIZ KENDİ ANAHTARINA göreydi (airport, name, section). Kaynak
-- aynı salona FARKLI BİR AD verdiğinde anahtar tutmaz ve "eklemedim,
-- güncelledim" sanırken YENİ SATIR açılır. Envanter yüklerken
-- idempotanlık isim eşitliğiyle değil VARLIK KİMLİĞİYLE kurulmalı.
--
-- 🔴 AYRIM (Gökberk'in vurguladığı): AYNI İSİMDE İKİ SALON DUPLICATE
-- DEĞİLDİR — "Plaza Premium Lounge — İç Hat" ile "— Dış Hat" iki AYRI
-- salondur. Duplicate ölçütü isim değil, (havalimanı × KAPSAM × BÖLÜM
-- × TERMİNAL) dörtlüsüdür. Bu dosya o dörtlüyü esas alır.
-- ============================================================


-- ============================================================
-- 1 · venue_kind BACKFILL — 188'in kayıtları tipsiz geldi
-- ============================================================
-- ÖLÇÜM: venue_kind dağılımı → (null) 248 · lounge 57 · spa 1 · shower 1 · sleep 1
-- 188'in eklediği her satır THY'nin LOUNGE listelerinden geldi; hepsi
-- salondur. Tipsiz bırakmak, katalog filtresini (venue_kind='lounge')
-- işlemez hâle getiriyordu.
update lounge_venues
   set venue_kind = 'lounge'
 where active and venue_kind is null;


-- ============================================================
-- 2 · SCOPE'U OTORİTE YAP — sekmelerin gerçek kaynağı
-- ============================================================
-- 🔴 KÖK SEBEP: app'in LoungePicker'ı sekmeyi `termOf()` ile
-- İSİM/TERMİNAL METNİNDEN türetiyor (screens.js:7324):
--     if (/dis hat|international|dis$/.test(t)) return "int";
-- Yani salonun adında "Dış Hat" yazmıyorsa sekme YANLIŞ. Bu, v2.34'te
-- Türkçe "İ" yüzünden bir kez zaten kırılmıştı. Veri katmanında
-- `scope` kolonu VAR ve RPC onu DÖNDÜRÜYOR — app okumuyordu.
-- "Türetilmiş bilgi, metinden değil VERİDEN gelmeli."
--
-- Burada scope'u her aktif salonda DOLU ve DOĞRU hâle getiriyoruz ki
-- app metne düşmek zorunda kalmasın.

-- 2a) scope null kalmışsa terminal/isimden bir kez türet (son çare)
update lounge_venues v
   set scope = case
     when v.terminal ~* '(dış|dis) *hat|international|uluslararası' then 'international'
     when v.terminal ~* '(iç|ic) *hat|domestic|yurt *içi'           then 'domestic'
     when v.name     ~* '(dış|dis) *hat|international'              then 'international'
     when v.name     ~* '(iç|ic) *hat|domestic'                     then 'domestic'
     else 'both' end
 where v.active and v.scope is null;

-- 2b) Yurt dışındaki salonlarda scope 'both' olmalı — oradaki bir
--     yolcu için "iç hat/dış hat" ayrımı Türkiye'ye göre tanımlı
--     değildir. resolve zaten kapsamı airports.country'den TÜRETİR
--     (172:58) ve orada 'abroad' der; venue.scope yalnız SEKME içindir.
update lounge_venues v
   set scope = 'both'
  from airports a
 where a.code = v.airport_code and v.active
   and coalesce(a.country,'') not in ('','TR','Türkiye','Turkiye','Turkey')
   and v.scope is distinct from 'both';

-- BEKÇİ: scope'suz aktif salon kalmasın (sekme sessizce boşalmasın)
do $$
declare v_bad int;
begin
  select count(*) into v_bad from lounge_venues where active and scope is null;
  if v_bad > 0 then
    raise exception '190: % aktif salonun scope''u YOK — sekme yanlis calisir', v_bad;
  end if;
  raise notice '190: her aktif salonun kapsami tanimli';
end $$;


-- ============================================================
-- 3 · DUPLICATE BİRLEŞTİRME — anahtar: havalimanı × kapsam × bölüm
--     × MARKA × terminal-jetonu
-- ============================================================
-- 🔴 İLK YAZIMIM YANLIŞTI VE ÖLÇÜM YAKALADI. Anahtarda MARKA yoktu:
--   IST iç hatta {Turkish Airlines Lounge, iGA Lounge — İç Hat} aynı
--   gruba düştü, THY kurallı olduğu için kanonik seçildi ve
--   **iGA Lounge yok edildi**. IST 14 salondan 6''ya indi.
--   Aynı havalimanında aynı kapsamda İKİ FARKLI İŞLETMECİNİN salonu
--   OLMASI NORMALDİR — duplicate değil, rekabettir.
--
--   İkinci eksik: terminal. MIA''da Concourse E ve Concourse H aynı
--   markanın İKİ AYRI salonu. Terminal jetonu anahtarda olmazsa
--   biri yok olur.
--
-- DOĞRU ANAHTAR: (havalimanı, kapsam, bölüm, normalize-marka,
--                 terminal-jetonu)
-- Bu dörtlü aynıysa iki kayıt AYNI SALONDUR.
--
-- KANONİK SEÇİMİ: en çok kurala sahip olan (ürün ona bağlanmış),
-- eşitlikte en çok kabul satırı, eşitlikte en eski kayıt.

-- Yardımcı: marka normalizasyonu. 'THY' ve 'Turkish Airlines' AYNI
-- markadır — 188 farklı yazdığı için ayrı görünüyorlardı.
create or replace function public.brand_key(p_operator text, p_name text)
returns text language sql immutable set search_path = public as $$
  select case
    when coalesce(p_operator,'') ~* 'turkish|thy'      then 'thy'
    when coalesce(p_operator,'') ~* 'iga'              then 'iga'
    when coalesce(p_operator,'') ~* 'primeclass'       then 'primeclass'
    when coalesce(p_operator,'') ~* 'plaza'            then 'plaza'
    when coalesce(p_operator,'') <> ''                 then lower(btrim(p_operator))
    when coalesce(p_name,'')     ~* 'turkish|thy'      then 'thy'
    when coalesce(p_name,'')     ~* 'iga'              then 'iga'
    when coalesce(p_name,'')     ~* 'primeclass'       then 'primeclass'
    when coalesce(p_name,'')     ~* 'plaza'            then 'plaza'
    else lower(regexp_replace(coalesce(p_name,''), '[^a-zA-Z0-9]+', '', 'g'))
  end
$$;

-- Yardımcı: terminal ayırt edici jetonu (Concourse E ≠ Concourse H)
create or replace function public.terminal_key(p_terminal text)
returns text language sql immutable set search_path = public as $$
  select coalesce(
    (regexp_match(lower(coalesce(p_terminal,'')), '(concourse\s*[a-z0-9]+)'))[1],
    (regexp_match(lower(coalesce(p_terminal,'')), '\b(t[0-9])\b'))[1],
    '')
$$;

do $$
declare r record; v_kanon uuid; v_merged int := 0; v_grup int := 0;
begin
  for r in
    select v.airport_code ap, v.scope sc, coalesce(v.section,'') sec,
           public.brand_key(v.operator, v.name) brand,
           public.terminal_key(v.terminal) tkey,
           count(*) n
      from lounge_venues v where v.active
     group by 1,2,3,4,5 having count(*) > 1
  loop
    v_grup := v_grup + 1;

    select v.id into v_kanon
      from lounge_venues v
     where v.active and v.airport_code = r.ap and v.scope = r.sc
       and coalesce(v.section,'') = r.sec
       and public.brand_key(v.operator, v.name) = r.brand
       and public.terminal_key(v.terminal) = r.tkey
     order by (select count(*) from lounge_guest_rules g where g.venue_id = v.id) desc,
              (select count(*) from lounge_venue_acceptance x where x.venue_id = v.id) desc,
              v.created_at
     limit 1;
    if v_kanon is null then continue; end if;

    -- Bağlı her şey kanoniğe taşınır; hiçbir veri kaybolmaz.
    update lounge_venue_acceptance a set venue_id = v_kanon
     where a.venue_id in (select v.id from lounge_venues v
        where v.active and v.airport_code = r.ap and v.scope = r.sc
          and coalesce(v.section,'') = r.sec
          and public.brand_key(v.operator, v.name) = r.brand
          and public.terminal_key(v.terminal) = r.tkey and v.id <> v_kanon)
       and not exists (select 1 from lounge_venue_acceptance b
                        where b.venue_id = v_kanon and b.program_id = a.program_id);

    update lounge_guest_rules g set venue_id = v_kanon
     where g.venue_id in (select v.id from lounge_venues v
        where v.active and v.airport_code = r.ap and v.scope = r.sc
          and coalesce(v.section,'') = r.sec
          and public.brand_key(v.operator, v.name) = r.brand
          and public.terminal_key(v.terminal) = r.tkey and v.id <> v_kanon);

    update availabilities a set venue_id = v_kanon
     where a.venue_id in (select v.id from lounge_venues v
        where v.active and v.airport_code = r.ap and v.scope = r.sc
          and coalesce(v.section,'') = r.sec
          and public.brand_key(v.operator, v.name) = r.brand
          and public.terminal_key(v.terminal) = r.tkey and v.id <> v_kanon);

    -- Kanonikte eksik bilgiyi kopyadan al (uzun terminal metni bilgi taşır)
    update lounge_venues k
       set terminal = coalesce(nullif(k.terminal,''), d.terminal),
           notes    = coalesce(nullif(k.notes,''), d.notes),
           operator = coalesce(k.operator, d.operator)
      from (select v.* from lounge_venues v
             where v.active and v.airport_code = r.ap and v.scope = r.sc
               and coalesce(v.section,'') = r.sec
               and public.brand_key(v.operator, v.name) = r.brand
               and public.terminal_key(v.terminal) = r.tkey and v.id <> v_kanon
             order by length(coalesce(v.terminal,'')) desc limit 1) d
     where k.id = v_kanon;

    -- ARŞİVLE, SİLME. 161''in dersi: arşiv adı benzersizleştirilmeli.
    update lounge_venues v
       set active = false,
           -- 🔴 26 AĞUSTOS — TEKRAR ÇALIŞTIRMA GÜVENLİĞİ. Arşiv adı
           -- ikinci kez eklenirse `uq_lounge_venue` ihlal ediliyordu:
           -- KURULUM_SIRASI.md "hepsi tekrar çalıştırılabilir" diyor
           -- ve bu dosya o sözü tutmuyordu. Zaten arşivlenmiş adı
           -- bir daha etiketlemiyoruz.
           name = case when v.name like '%(190 birleştirildi %' then v.name
                  else v.name || ' (190 birleştirildi → ' || left(v.id::text, 8) || ')' end
     where v.active and v.airport_code = r.ap and v.scope = r.sc
       and coalesce(v.section,'') = r.sec
       and public.brand_key(v.operator, v.name) = r.brand
       and public.terminal_key(v.terminal) = r.tkey and v.id <> v_kanon;

    v_merged := v_merged + (r.n - 1);
  end loop;
  raise notice '190: % grupta % mukerrer kayit birlestirildi', v_grup, v_merged;
end $$;


-- ============================================================
-- 3b · TERMİNAL JETONU BOŞ OLAN KAYIT — az bilgili kopya
-- ============================================================
-- ÖLÇÜM (3. blok sonrası kalan iki grup):
--   BKK · thy · both · "-" → 2 kayıt
--        "Turkish Airlines"        terminal "Uluslararası Terminal"   jeton ""
--        "Turkish Airlines Lounge" terminal "Concourse D, D8 …"       jeton "concourse d"
--        → AYNI salon; ikincisi daha ayrıntılı yazılmış.
--   MIA · thy · both · "-" → 2 kayıt, jetonlar "concourse e" ve
--        "concourse h" → GERÇEKTEN İKİ AYRI SALON, dokunulmaz.
--
-- KURAL: bir grupta jetonsuz TEK kayıt ve jetonlu TEK AYRI jeton
-- varsa, jetonsuz olan az bilgili kopyadır → birleştir.
-- İki farklı jeton varsa jetonsuz olanın hangisine ait olduğunu
-- BİLEMEYİZ → dokunmayız. Belirsizlikte susmak esas.
do $$
declare r record; v_kanon uuid; v_merged int := 0;
begin
  for r in
    select v.airport_code ap, v.scope sc, coalesce(v.section,'') sec,
           public.brand_key(v.operator, v.name) brand,
           count(*) filter (where public.terminal_key(v.terminal) = '') bos,
           count(distinct nullif(public.terminal_key(v.terminal), '')) jeton
      from lounge_venues v where v.active
     group by 1,2,3,4
    having count(*) > 1
       and count(*) filter (where public.terminal_key(v.terminal) = '') = 1
       and count(distinct nullif(public.terminal_key(v.terminal), '')) = 1
  loop
    select v.id into v_kanon from lounge_venues v
     where v.active and v.airport_code = r.ap and v.scope = r.sc
       and coalesce(v.section,'') = r.sec
       and public.brand_key(v.operator, v.name) = r.brand
       and public.terminal_key(v.terminal) <> ''
     order by (select count(*) from lounge_guest_rules g where g.venue_id = v.id) desc,
              length(coalesce(v.terminal,'')) desc
     limit 1;
    if v_kanon is null then continue; end if;

    update lounge_venue_acceptance a set venue_id = v_kanon
     where a.venue_id in (select v.id from lounge_venues v
        where v.active and v.airport_code = r.ap and v.scope = r.sc
          and coalesce(v.section,'') = r.sec
          and public.brand_key(v.operator, v.name) = r.brand
          and public.terminal_key(v.terminal) = '')
       and not exists (select 1 from lounge_venue_acceptance b
                        where b.venue_id = v_kanon and b.program_id = a.program_id);

    update lounge_guest_rules g set venue_id = v_kanon
     where g.venue_id in (select v.id from lounge_venues v
        where v.active and v.airport_code = r.ap and v.scope = r.sc
          and coalesce(v.section,'') = r.sec
          and public.brand_key(v.operator, v.name) = r.brand
          and public.terminal_key(v.terminal) = '');

    update availabilities a set venue_id = v_kanon
     where a.venue_id in (select v.id from lounge_venues v
        where v.active and v.airport_code = r.ap and v.scope = r.sc
          and coalesce(v.section,'') = r.sec
          and public.brand_key(v.operator, v.name) = r.brand
          and public.terminal_key(v.terminal) = '');

    update lounge_venues v
       set active = false,
           -- 🔴 26 AĞUSTOS — TEKRAR ÇALIŞTIRMA GÜVENLİĞİ. Arşiv adı
           -- ikinci kez eklenirse `uq_lounge_venue` ihlal ediliyordu:
           -- KURULUM_SIRASI.md "hepsi tekrar çalıştırılabilir" diyor
           -- ve bu dosya o sözü tutmuyordu. Zaten arşivlenmiş adı
           -- bir daha etiketlemiyoruz.
           name = case when v.name like '%(190 birleştirildi %' then v.name
                  else v.name || ' (190 birleştirildi → ' || left(v.id::text, 8) || ')' end
     where v.active and v.airport_code = r.ap and v.scope = r.sc
       and coalesce(v.section,'') = r.sec
       and public.brand_key(v.operator, v.name) = r.brand
       and public.terminal_key(v.terminal) = '';

    v_merged := v_merged + 1;
  end loop;
  raise notice '190: jetonsuz az-bilgili kopya birlestirildi: %', v_merged;
end $$;


-- ============================================================
-- 4 · İSİM TUTARLILIĞI — aynı salonun bölümleri aynı dili konuşsun
-- ============================================================
-- ÖLÇÜM: IST iç hatta aynı salonun iki bölümü İKİ FARKLI DİLLE yazılı:
--   "Turkish Airlines Lounge — İç Hat"                        (M&S bölümü)
--   "İstanbul Havalimanı iç hatlar özel yolcu salonu — Business Lounge"
-- Kullanıcı bunların aynı yerin iki bölümü olduğunu anlayamaz.
--
-- KANONİK BİÇİM:  <Marka> — <İç Hat|Dış Hat> (<Bölüm>)
-- Bölüm eki yalnız bölümlü salonlarda. Kapsam eki, aynı adın iki
-- kapsamda geçtiği durumda ayırt edici — Gökberk'in dediği gibi
-- "aynı isimde hem iç hat hem dış hat lounge'ı olabilir".

-- ── 🔴 ÖNCE: KANONİK ADI TUTAN **PASİF** KAYITLARI ARŞİVLE ──────────
-- 18 Ağustos 2026 · Gökberk canlıda şu hatayı aldı:
--   ERROR 23505: duplicate key value violates unique constraint "uq_lounge_venue"
--   DETAIL: Key (airport_code, name, COALESCE(section,''))
--           =(IST, Turkish Airlines Lounge — Dış Hat (Business), business)
--
-- Sebebi aşağıdaki UPDATE'in nöbetçisiydi: "aynı ada düşecek başka kayıt
-- varsa dokunma" derken yalnız `o.active` satırlara bakıyordu. Oysa
--     create unique index uq_lounge_venue on lounge_venues
--            (airport_code, name, coalesce(section,''))
-- KISMİ DEĞİL — pasif satırları da kapsıyor. Yani kanonik adı pasif bir
-- kayıt tutuyorsa nöbetçi onu GÖREMİYOR ve UPDATE indekse tosluyor.
--
-- Temiz kurulumda o adı tutan kayıt aktif kaldığı için hata çıkmıyor;
-- bu yüzden harness altı tur boyunca yeşil yandı. Hatayı üretebilmek için
-- 001-189'u kurup o kaydı pasifleştirdim ve AYNI hata, AYNI anahtarla,
-- bu dosyanın aynı satırında çıktı.
--
-- Doğru davranış "vazgeç" değil: pasif kayıt zaten ARŞİV. Kanonik adı
-- tutmaya devam etmesinin bir gerekçesi yok. Dosyanın başka yerinde
-- kullanılan "(arşiv <id8>)" biçimiyle kenara çekiliyor — silinmiyor,
-- adı serbest bırakılıyor.
update lounge_venues o
   set name = o.name || ' (arşiv ' || left(o.id::text, 8) || ')'
 where not o.active
   and o.name not like '%(arşiv %'
   and exists (
     select 1 from lounge_venues v
      where v.active
        and v.airport_code = o.airport_code
        and public.brand_key(v.operator, v.name) = 'thy'
        and v.section is not null
        and coalesce(o.section,'') = coalesce(v.section,'')
        and o.name = ('Turkish Airlines Lounge — '
              || case v.scope when 'domestic' then 'İç Hat'
                              when 'international' then 'Dış Hat'
                              else 'Terminal' end
              || case v.section when 'business' then ' (Business)'
                                when 'miles_smiles' then ' (Miles&Smiles)'
                                else '' end)
   );

update lounge_venues v
   set name = 'Turkish Airlines Lounge — '
              || case v.scope when 'domestic' then 'İç Hat'
                              when 'international' then 'Dış Hat'
                              else 'Terminal' end
              || case v.section when 'business' then ' (Business)'
                                when 'miles_smiles' then ' (Miles&Smiles)'
                                else '' end
 where v.active
   and public.brand_key(v.operator, v.name) = 'thy'
   and v.section is not null
   and v.name <> ('Turkish Airlines Lounge — '
              || case v.scope when 'domestic' then 'İç Hat'
                              when 'international' then 'Dış Hat'
                              else 'Terminal' end
              || case v.section when 'business' then ' (Business)'
                                when 'miles_smiles' then ' (Miles&Smiles)'
                                else '' end)
   -- 🔴 `o.active` KALDIRILDI. Indeks pasif satirlari da kapsiyor;
   -- nobetci yalniz aktiflere bakinca kor kaliyordu (23505, 18 Agu).
   -- Ayni ada düşecek BAŞKA HERHANGİ bir kayıt varsa DOKUNMA.
   and not exists (
     select 1 from lounge_venues o
      where o.id <> v.id and o.airport_code = v.airport_code
        and o.name = ('Turkish Airlines Lounge — '
              || case v.scope when 'domestic' then 'İç Hat'
                              when 'international' then 'Dış Hat'
                              else 'Terminal' end
              || case v.section when 'business' then ' (Business)'
                                when 'miles_smiles' then ' (Miles&Smiles)'
                                else '' end)
        and coalesce(o.section,'') = coalesce(v.section,''));

-- Katalog adı venue adını takip etmeli, yoksa iki yerde iki isim olur
update lounges l set name = v.name, terminal = coalesce(v.terminal, l.terminal)
  from lounge_venues v
 where v.id = l.venue_id and l.active and v.active and l.name is distinct from v.name;


-- ============================================================
-- 5 · KATALOG TEMİZLİĞİ — salon olmayan şey salon listesinde durmasın
-- ============================================================
-- ÖLÇÜM: lounges_for_airport('IST') XpresSpa · iGA Shower · iGA Sleepod
-- döndürüyordu. Bunlar spa/duş/uyku kapsülü — 161 katalogdan çıkarmıştı,
-- 188 geri getirdi. Host bunlardan birini seçerse kural motoru
-- misafir hakkını hesaplayamaz; ürünün çekirdek vaadi sessizce düşer.
update lounges l
   set active = false
  from lounge_venues v
 where v.id = l.venue_id and l.active
   and coalesce(v.venue_kind, 'lounge') <> 'lounge';

-- Arşivlenen venue'ların katalog karşılıkları da kapanmalı
update lounges l
   set active = false
  from lounge_venues v
 where v.id = l.venue_id and l.active and not v.active;

-- Kanonik kalan her aktif salonun katalog karşılığı OLMALI
insert into lounges (airport_code, name, terminal, access_types, venue_id, active)
select v.airport_code::char(3), v.name, v.terminal, '{}'::text[], v.id, true
  from lounge_venues v
 where v.active and coalesce(v.venue_kind,'lounge') = 'lounge'
   and not exists (select 1 from lounges l where l.venue_id = v.id and l.active);


-- ============================================================
-- 6 · IST İÇ HAT — BÖLÜMSÜZ KAYIT + BÖLÜMLÜ KARDEŞLER
-- ============================================================
-- ÖLÇÜM: IST domestic'te 1 bölümsüz (11 kurallı, eski) + 2 bölümlü
-- (188'den: business ve miles_smiles) kayıt YAN YANA duruyor.
-- Farklı bölüm oldukları için 3. blok bunları birleştirmedi — DOĞRU
-- davranış, ama kullanıcı aynı salonun üç satırını görüyor.
--
-- 🔴 BURADA BİR ÇIKARIM YAPIYORUM VE GEREKÇESİNİ YAZIYORUM:
--   (a) IST DIŞ HAT tarafı ZATEN bölümlü modellenmiş (161): Business
--       ve Miles&Smiles ayrı venue. İç hat için kaynak aynı yapıyı
--       söylüyor ama 161 bunu bölmemiş — eski kayıt EKSİK.
--   (b) Kaynak: "misafir hakkı biletten değil KART TİPİNDEN gelir;
--       misafirle girmek isteyen Business yolcu M&S BÖLÜMÜNE gitmeli."
--       Yani misafir taşıyan bölüm M&S'tir.
--   → Bölümsüz kaydın misafir kuralları M&S bölümüne aittir.
--
-- Çıkarım olduğu için TEK YÖNLÜ ve GERİ ALINABİLİR yapıyorum: eski
-- kayıt M&S bölümü olarak İŞARETLENİR (silinmez), 188'in M&S kaydı
-- ona birleşir, Business kaydı olduğu gibi kalır.
do $$
declare v_eski uuid; v_yeni_ms uuid; v_n int;
begin
  select v.id into v_eski from lounge_venues v
   where v.active and v.airport_code = 'IST' and v.scope = 'domestic'
     and v.section is null
     and exists (select 1 from lounge_guest_rules g where g.venue_id = v.id)
   limit 1;
  if v_eski is null then
    raise notice '190: IST ic hat bolumsuz kayit yok — atlandi'; return;
  end if;

  select v.id into v_yeni_ms from lounge_venues v
   where v.active and v.airport_code = 'IST' and v.scope = 'domestic'
     and v.section = 'miles_smiles' and v.id <> v_eski
   limit 1;

  -- Eski kaydı M&S bölümü yap
  update lounge_venues
     set section = 'miles_smiles',
         notes = coalesce(notes,'') ||
           case when coalesce(notes,'') = '' then '' else ' · ' end ||
           '[190] Bölüm M&S olarak işaretlendi: kaynak "misafirle girmek '
           'isteyen Business yolcu M&S bölümüne gitmeli" diyor, yani misafir '
           'hakkını taşıyan bölüm burasıdır. Dış hat tarafı zaten böyle modelli.'
   where id = v_eski;

  if v_yeni_ms is not null then
    update lounge_venue_acceptance a set venue_id = v_eski
     where a.venue_id = v_yeni_ms
       and not exists (select 1 from lounge_venue_acceptance b
                        where b.venue_id = v_eski and b.program_id = a.program_id);
    update lounge_venues
       set active = false,
           name = case when name like '%(190 birleştirildi %' then name
                  else name || ' (190 birleştirildi → ' || left(id::text, 8) || ')' end
     where id = v_yeni_ms;
    update lounges set active = false where venue_id = v_yeni_ms;
  end if;

  select count(*) into v_n from lounge_venues
   where active and airport_code = 'IST' and scope = 'domestic';
  raise notice '190: IST ic hat bolumlendi — % aktif salon kaldi', v_n;
end $$;


-- ============================================================
-- 7 · lounges_for_airport → BÖLÜM + KAPSAM DÖNDÜRSÜN
-- ============================================================
-- App'in modal sekmeleri bugün İSİMDEN türetiliyor (screens.js:7324).
-- Veriden türetebilmesi için RPC'nin `section`ı da vermesi gerekiyor.
-- Dönüş TİPİ değişiyor → drop şart (42P13 aksi hâlde).
--
-- Ayrıca `display_name`: aynı havalimanında aynı adı taşıyan iki salon
-- varsa (iç hat + dış hat) kullanıcı listede ayırt edebilmeli. Sekme
-- zaten ayırıyor ama "Tümü" sekmesinde ayrım kaybolur.
drop function if exists public.lounges_for_airport(text);
create or replace function public.lounges_for_airport(p_airport text)
returns table (
  id uuid, name text, terminal text, access_types text[],
  scope text, accepts_guests boolean, note text,
  section text, display_name text
) language plpgsql stable security definer set search_path = public as $$
declare v_ap text := upper(btrim(coalesce(p_airport, '')));
begin
  return query
  with c as (
    select l.id, l.name, l.terminal, l.access_types,
           v.scope, v.section, v.id as vid,
           exists (select 1 from lounge_venue_acceptance a
                    where a.venue_id = v.id and a.active and a.accepted
                      and coalesce(a.guest_policy,'') <> 'not_allowed') as ag
      from lounges l
      join lounge_venues v on v.id = l.venue_id and v.active
                          and coalesce(v.venue_kind,'lounge') = 'lounge'
     where l.active and upper(btrim(l.airport_code)) = v_ap
  ), n as (
    select c.*, count(*) over (partition by lower(c.name)) as ayni_ad from c
  )
  select n.id, n.name, n.terminal, n.access_types, n.scope, n.ag, null::text,
         n.section,
         -- Aynı ad birden çok kez geçiyorsa kapsam/bölüm ekiyle ayır.
         case when n.ayni_ad > 1 then
                n.name || ' — ' ||
                case n.scope when 'domestic' then 'İç Hat'
                             when 'international' then 'Dış Hat'
                             else 'Tüm Terminaller' end ||
                case when n.section = 'business' then ' (Business)'
                     when n.section = 'miles_smiles' then ' (Miles&Smiles)'
                     else '' end
              else n.name end
    from n
   -- 🔴 coalesce ŞART: NULL karşılaştırma DESC'te en başa çıkar (145).
   order by coalesce(n.scope = 'domestic', false) desc, n.name;

  if not found then
    -- YEDEK YOL: katalog o havalimanı için boşsa doğrudan venue'dan üret.
    return query
    select v.id, v.name, v.terminal, null::text[], v.scope,
           exists (select 1 from lounge_venue_acceptance a
                    where a.venue_id = v.id and a.active and a.accepted
                      and coalesce(a.guest_policy,'') <> 'not_allowed'),
           null::text, v.section, v.name
      from lounge_venues v
     where v.active and upper(btrim(v.airport_code)) = v_ap
       and coalesce(v.venue_kind, 'lounge') = 'lounge'
     order by coalesce(v.scope = 'domestic', false) desc, v.name;
  end if;
end $$;
grant execute on function public.lounges_for_airport(text) to authenticated, anon;


-- ============================================================
-- 8 · BEKÇİLER
-- ============================================================

-- 8a) Aynı (havalimanı, kapsam, bölüm, terminal-jetonu) tek olmalı
do $$
declare r record; v_bad int := 0;
begin
  for r in
    select v.airport_code ap, v.scope sc, coalesce(v.section,'-') sec,
           coalesce((regexp_match(lower(coalesce(v.terminal,'')), '(concourse\s*[a-z0-9]+)'))[1], '') tok,
           count(*) n, string_agg(left(v.name, 40), ' ++ ') adlar
      from lounge_venues v where v.active
     group by 1,2,3,4 having count(*) > 1
  loop
    -- İki AYRI salon meşru olabilir (farklı marka/işletmeci). Yalnız
    -- AYNI markadan iki kayıt kalmışsa şikayet et.
    if (select count(distinct coalesce(operator,''))
          from lounge_venues v2
         where v2.active and v2.airport_code = r.ap and v2.scope = r.sc
           and coalesce(v2.section,'-') = r.sec) = 1 then
      raise warning '190: % / % / % icinde ayni isletmeciden % kayit: %',
        r.ap, r.sc, r.sec, r.n, r.adlar;
      v_bad := v_bad + 1;
    end if;
  end loop;
  if v_bad > 0 then
    raise warning '190: % supheli grup kaldi — elle bak (migration durdurulmadi)', v_bad;
  else
    raise notice '190: ayni isletmeciden mukerrer salon yok';
  end if;
end $$;

-- 8b) Katalogda salon olmayan bir şey kalmasın
do $$
declare v_bad int;
begin
  select count(*) into v_bad
    from lounges l join lounge_venues v on v.id = l.venue_id
   where l.active and (not v.active or coalesce(v.venue_kind,'lounge') <> 'lounge');
  if v_bad > 0 then
    raise exception '190: katalogda % gecersiz kayit var (salon degil ya da arsiv)', v_bad;
  end if;
  raise notice '190: katalog temiz';
end $$;

-- 8c) Her TR havalimanında hem sekme sayıları hem liste dolu olmalı
do $$
declare r record; v_dom int; v_int int; v_top int; v_bos int := 0;
begin
  for r in
    select distinct v.airport_code ap from lounge_venues v
      join airports a on a.code = v.airport_code
     where v.active and a.country in ('Türkiye','Turkiye','TR','Turkey')
  loop
    select count(*), count(*) filter (where s.scope = 'domestic'),
           count(*) filter (where s.scope = 'international')
      into v_top, v_dom, v_int
      from public.lounges_for_airport(r.ap) s;
    if v_top = 0 then
      raise warning '190: % salon listesi BOS', r.ap; v_bos := v_bos + 1;
    end if;
  end loop;
  if v_bos > 0 then raise exception '190: % TR havalimaninda liste bos', v_bos; end if;
  raise notice '190: her TR havalimani salon donduruyor';
end $$;

-- 8d) RPC gerçekten çağrılabiliyor mu (186 dersi — var olmak yetmez)
do $$
declare v_n int;
begin
  select count(*) into v_n from public.lounges_for_airport('IST');
  if v_n = 0 then raise exception '190: lounges_for_airport(IST) BOS donuyor'; end if;
  select count(*) into v_n from public.lounges_for_airport('ist');  -- normalize
  if v_n = 0 then raise exception '190: kucuk harf havalimani kodu calismiyor'; end if;
  raise notice '190: lounges_for_airport calisiyor (buyuk/kucuk harf)';
end $$;

select '190 OK - salonlar tekillestirildi, kapsam otorite oldu' as sonuc;
