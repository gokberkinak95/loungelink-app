-- ============================================================================
-- LoungeLink · SEED4_KURAL_VITRINI.sql                     (20 Ağustos 2026)
--
-- "KURAL MOTORUNUN TAMAMI, İKİ HOST'UN İLANLARINDA, MİSAFİRİN GÖZÜNDEN"
--
-- Gökberk: "seed verin hala çok zayıf. Seed1'de bana inanılmaz veriler
-- sunmuştunuz. İstediğim her şeyi rahatça görebiliyordum. Şimdi birkaç ilan
-- arasında ve hatalı verilerle tıkılı kaldım. Doğru verilerle dolu dolu ve
-- her şeyi test edebileceğim özellikle de kural senaryolarını doğru ve
-- detaylı kontrol edebileceğim bir seed verisi de sun."
--
-- ── ÖNCEKİ SÜRÜM NEDEN ZAYIFTI (ÖLÇÜLDÜ, TAHMİN DEĞİL) ───────────────
-- Önceki SEED4 "motora sor, kovaya koy, yeni kova ise ilanı bırak"
-- yapıyordu. Kovanın anahtarı (guest_policy, family, charter, carrier_ok)
-- idi. `lounge_access_decision(uuid,text)` çıktısında `carrier_ok` ANAHTARI
-- HİÇ YOK; kova bu yüzden 4 alanın 2'siyle hesaplanıyordu. Ölçtüm: 2810
-- (salon × taşıyıcı × charter) denemesinin tamamı YALNIZCA 4 kova üretti —
-- yani 80 salonu tarayan döngü, motorun dallarının çok küçük bir kısmını
-- gösteriyordu. Üstelik seçilen salonlar rastgeleydi: keşfette yan yana
-- duran ilanların yarısından çoğu "misafir alınmıyor" oluyordu, kullanıcı
-- da haklı olarak "hatalı veri" diyordu.
--
-- ── ASIL KIRILMA: DAL ÇEŞİTLİLİĞİ SALONDAN DEĞİL, HAKTAN GELİYOR ────
-- Ölçüm (bu dosyayı yazarken, canlı şemada):
--   · host1'in 5 programlık hakkıyla tüm salonlar tarandığında  →  6 dal
--   · programı İLANA SABİTLEYİP (availabilities.program_id) 20 programın
--     tamamı denendiğinde                                        → 49 dal
-- Yani kural dalını açan şey salon değil, HOST'UN HANGİ HAKKI BEYAN
-- ETTİĞİ. `trg_avail_program_fill` program_id yazılmışsa onu 'beyan'
-- kabul edip aynen kullanıyor — vitrinin dayanağı bu.
--
-- ── BU DOSYA NE YAPIYOR ─────────────────────────────────────────────
-- 1) host1 = GENİŞ HAKLI host (M&S Elite Plus + PP + DragonPass + ...)
--    host2 = KISITLI host (M&S Classic Plus + Business bileti + ...)
--    İkisi bilerek zıt: aynı salon, iki farklı cevap. Kademe kuralını
--    (ELPL girer / CLPL giremez) tek ekranda yan yana görmenin tek yolu.
-- 2) 22 satırlık SABİT senaryo matrisi. Her satır BİR kural dalı ve
--    hangi dalı hedeflediği yorumda yazıyor. Programı ilana sabitliyor,
--    böylece dal tesadüfe kalmıyor.
-- 3) guest1/guest2'ye o ilanlarla ÖRTÜŞEN seyahatler; bir kısmı AYNI
--    UÇUŞ, bir kısmı FARKLI TAŞIYICI, bir kısmı hiç yok — üç rozet de
--    görünsün diye.
-- 4) Seed1 (SEED_KURAL_SENARYOLARI) ve 173 vitrin hesapları ZATEN
--    kurulmuşsa, onların ilanları da guest1/guest2'ye seyahatle
--    bağlanıyor. O veri doğru ve zengin; siliyor değil, GÖRÜNÜR kılıyor.
-- 5) NÖBETÇİ: guest1'in KENDİ gözünden `discover_availabilities()` +
--    `discovery_rule_badges()` çağırıp kapsamı ÖLÇÜYOR ve yetersizse
--    `raise exception` ile duruyor.
--
-- 🔴 SIRA UYARISI — ÖLÇÜLDÜ:
-- Harness `sorted(f for f in os.listdir if f.startswith('SEED'))` diyor.
-- Python sıralamasında '4' (0x34) < '_' (0x5F), yani gerçek sıra:
--   SEED2 → SEED3 → SEED4 → SEED_KURAL_SENARYOLARI
-- Seed1 SEED4'ten SONRA koşuyor. Bu yüzden SEED4 seed1'in ilanlarına
-- BEL BAĞLAYAMAZ: ilk kurulumda onlar henüz yoktur. Vitrin bu yüzden
-- kendi ayakları üzerinde duruyor; seed1 varsa ÜSTÜNE ekleniyor.
-- (Harness'in "TEKRAR KURULUM" turunda seed1 artık vardır — nöbetçi
-- her iki durumda da geçmek zorunda ve iki turda da ölçülüyor.)
--
-- ⚠️ ÖNCE SEED3 ÇALIŞTIRILMIŞ OLMALI (host1/host2/guest1/guest2 oradan
-- geliyor). Bu dosya onları SİLMEZ, ÜSTÜNE EKLER.
--
-- 🔴 TEKRAR ÇALIŞTIRILABİLİRLİK: bu dosyanın ürettiği her satırın
-- KİMLİĞİ SABİT (availabilities '44440000-…', visits '44450000-…').
-- Silip yeniden yazmak yerine `on conflict (id) do update` kullanılıyor.
-- Neden: seed1'de tam olarak bunun eksikliği yüzünden ikinci kurulum
-- `requests_visit_id_fkey` ihlaliyle düşüyordu — bağlı istek varken
-- satırı silmek mümkün değil, ama GÜNCELLEMEK her zaman mümkün.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- 0) ÖN KOŞUL + HESAPLARIN KEŞFETTE GÖRÜNEBİLİRLİĞİ
-- ════════════════════════════════════════════════════════════════════════
do $s4_hesap$
declare
  v_h1 uuid; v_h2 uuid; v_g1 uuid; v_g2 uuid;
begin
  select id into v_h1 from users where email = 'host1@seed.loungelink.test';
  select id into v_h2 from users where email = 'host2@seed.loungelink.test';
  select id into v_g1 from users where email = 'guest1@seed.loungelink.test';
  select id into v_g2 from users where email = 'guest2@seed.loungelink.test';

  if v_h1 is null or v_h2 is null or v_g1 is null or v_g2 is null then
    raise exception 'SEED4: host1/host2/guest1/guest2 eksik — once SEED3_UCTAN_UCA.sql calistir';
  end if;

  -- 041/074: ekip hesabı sayılan kullanıcı keşifte GÖRÜNMEZ. Seed hesabı
  -- oraya takılırsa vitrin boş ekran verir; bu tuzağa seed1'de düşülmüştü.
  update users set is_staff = false where id in (v_h1, v_h2, v_g1, v_g2);
  -- 🔴 `role` bir ENUM (user_role); `coalesce(role,'')` yazınca boş metin
  -- enum'a çevrilemiyor ve 22P02 alıyorsun (ilk denememde aldım).
  -- Karşılaştırma enum'un KENDİ değeriyle yapılır, metne düşürülmez.
  update users set role = 'host'::user_role
   where id in (v_h1, v_h2) and role is distinct from 'host'::user_role;

  update profiles set show_on_discovery = true, profile_visibility = 'Everyone',
                      updated_at = now()
   where user_id in (v_h1, v_h2, v_g1, v_g2);

  -- `discover_availabilities_base` içinde `v_my_trust >= a.min_trust` var.
  -- İlanlarımızda min_trust=0 yazıyoruz ama misafirin güven puanı yoksa
  -- diğer seed'lerin ilanları da elenir; satırı garantiye alıyoruz.
  insert into trust_scores (user_id, score)
  select x.uid, 60 from (values (v_h1),(v_h2),(v_g1),(v_g2)) x(uid)
   where not exists (select 1 from trust_scores t where t.user_id = x.uid);

  update verifications set phone_verified = true, id_verified = true
   where user_id in (v_h1, v_h2, v_g1, v_g2);

  raise notice 'SEED4 · hesaplar hazir: host1=% host2=% guest1=% guest2=%',
    v_h1, v_h2, v_g1, v_g2;
end $s4_hesap$;


-- ════════════════════════════════════════════════════════════════════════
-- 1) HAKLAR — İKİ HOST BİLEREK ZIT
--
-- 🔴 `uq_he` (user_id, program_id, coalesce(tier,''), coalesce(card_label,''))
-- olduğu için aynı programın iki kademesi YAN YANA durabilir. Durursa
-- kademe çözücü ikisinden birini seçer ve "CLPL giremez" senaryosu
-- sessizce ELPL'e döner. Bu yüzden TK_MS'te host başına TEK satır
-- bırakıyoruz: host1 → ELPL, host2 → CLPL.
--
-- origin CHECK: declared|parsed|verified|admin ('seed' YOK — kısıt okundu).
-- ════════════════════════════════════════════════════════════════════════
do $s4_hak$
declare
  r record; v_pid uuid; v_uid uuid; v_n int := 0;
begin
  -- host1'de TK_MS yalnız ELPL, host2'de yalnız CLPL kalsın.
  delete from host_entitlements he
   using users u, lounge_programs p
   where he.user_id = u.id and he.program_id = p.id and p.code = 'TK_MS'
     and ((u.email = 'host1@seed.loungelink.test' and coalesce(he.tier,'') <> 'ELPL')
       or (u.email = 'host2@seed.loungelink.test' and coalesce(he.tier,'') <> 'CLPL'));

  for r in
    select * from (values
      -- host1 · GENİŞ HAKLI: dalların "olumlu" ve "ücretli" tarafı
      ('host1@seed.loungelink.test','TK_MS',        'ELPL', 2),
      ('host1@seed.loungelink.test','STAR_GOLD',    null,   1),
      ('host1@seed.loungelink.test','PRIORITY_PASS',null,   2),
      ('host1@seed.loungelink.test','DRAGONPASS',   null,   2),
      ('host1@seed.loungelink.test','LOUNGEKEY',    null,   2),
      ('host1@seed.loungelink.test','IGA_LOUNGE',   null,   1),
      -- host2 · KISITLI: dalların "engel" tarafı
      ('host2@seed.loungelink.test','TK_MS',          'CLPL', 1),
      ('host2@seed.loungelink.test','AJET_MS',        'ELPL', 1),
      ('host2@seed.loungelink.test','BUSINESS_TICKET',null,   1),
      ('host2@seed.loungelink.test','BANK_CARD',      null,   1),
      ('host2@seed.loungelink.test','PGS_PAID',       null,   1),
      ('host2@seed.loungelink.test','PRIMECLASS',     null,   1),
      ('host2@seed.loungelink.test','PLAZA_PREMIUM',  null,   1),
      ('host2@seed.loungelink.test','ST_PASS',        null,   1),
      ('host2@seed.loungelink.test','LOUNGEKEY',      null,   1)
    ) as t(mail, kod, kademe, kap)
  loop
    select id into v_pid from lounge_programs where code = r.kod;
    select id into v_uid from users where email = r.mail;
    continue when v_pid is null or v_uid is null;

    insert into host_entitlements (user_id, program_id, tier, guest_capacity,
                                   origin, self_reported_at, note)
    values (v_uid, v_pid, r.kademe, r.kap, 'declared', now(), 'SEED4-vitrin')
    on conflict (user_id, program_id, coalesce(tier,''), coalesce(card_label,''))
    do update set guest_capacity = excluded.guest_capacity,
                  self_reported_at = now(),
                  note = 'SEED4-vitrin';
    v_n := v_n + 1;
  end loop;

  if v_n = 0 then
    raise exception 'SEED4: hic hak yazilamadi — lounge_programs katalogu bos olabilir';
  end if;
  raise notice 'SEED4 · % hak satiri yazildi (host1=genis, host2=kisitli)', v_n;
end $s4_hak$;


-- ════════════════════════════════════════════════════════════════════════
-- 2) SENARYO MATRİSİ — 22 İLAN, HER BİRİ BİR KURAL DALI
--
-- Her satırın hedeflediği dal yorumda yazıyor. Hedefin TUTUP TUTMADIĞINI
-- iddia etmiyoruz: aşağıdaki döngü her ilanın kararını okuyup NOTICE'e
-- basıyor, nöbetçi de sonucu misafirin gözünden ölçüyor.
--
-- 🔴 GÜN OFSETLERİ BENZERSİZ (current_date+3 … +24). İki senaryo aynı
-- havalimanı+güne düşerse `discovery_rule_badges` misafirin uçuşunu
-- `limit 1` ile seçiyor ve "AYNI UÇUŞ" rozeti yanlış ilana yapışıyor.
-- Bunu tarih çakıştırarak öğrendik; artık her senaryonun kendi günü var.
--
-- 🔴 TARİH HER ZAMAN current_date + n. Sabit tarih yazılırsa seed birkaç
-- gün sonra yeniden koşulduğunda `a.avail_date >= current_date` süzgeci
-- ilanların hepsini eler ve keşif yine boş görünür.
-- ════════════════════════════════════════════════════════════════════════
do $s4_ilan$
declare
  r record;
  i int;
  v_uid uuid; v_pid uuid; v_lid uuid; v_ven uuid; v_aid uuid;
  v_g1 uuid; v_g2 uuid; v_gid uuid; v_vid uuid;
  v_atlanan text := '';
  v_n int := 0;
  v_sey int := 0;
  v_yedek int := 0;
  v_tarih date;
  v_ucus text;
begin
  select id into v_g1 from users where email = 'guest1@seed.loungelink.test';
  select id into v_g2 from users where email = 'guest2@seed.loungelink.test';

  for r in
    select * from (values
      -- n | host | program | kademe | apt | salon (katalog adı) | taşıyıcı | uçuş | charter | slot | dolu | gün | başlangıç | bitiş | g1 uçuşu | g2 uçuşu
      -- ── host1 · GENİŞ HAKLI ────────────────────────────────────────
      -- Tablo-4: M&S Elite Plus, dış hat M&S bölümü → 1 misafir ÜCRETSİZ.
      -- guest1 AYNI UÇUŞTA → "AYNI UÇUŞ" rozeti + serbest başvuru.
      ( 1,1,'TK_MS','ELPL','IST','Turkish Airlines Lounge — Dış Hat (Miles&Smiles)','TK','TK1953',false,2,0, 3,'10:00','14:00','=',   null),
      -- Aynı salonun BUSINESS bölümü: Business yolcusu girer ama misafir
      -- hakkı yoktur → "misafir alınmıyor" + HOST'A SOR butonu.
      ( 2,1,'TK_MS','ELPL','IST','Turkish Airlines Lounge — Dış Hat (Business)','TK','TK1955',false,2,0, 4,'09:00','13:00','TK1955', null),
      -- Priority Pass: misafir ÜCRETLİ, ücret host'un kartından düşer.
      ( 3,1,'PRIORITY_PASS',null,'ADB','Primeclass Lounge — Dış Hat','TK','TK2312',false,2,0, 5,'15:00','19:00','=',   null),
      -- DragonPass: kapıda tahsil edilen misafir ücreti (tutar görünür).
      ( 4,1,'DRAGONPASS',null,'SAW','Plaza Premium Bosphorus Lounge — Dış Hat','PC','PC2034',false,2,0, 6,'10:00','14:00',null, '='),
      -- Star Alliance Gold: 1 misafir var, AİLE hakkı yok.
      ( 5,1,'STAR_GOLD',null,'ESB','Turkish Airlines Lounge','TK','TK2106',false,2,0, 7,'08:00','12:00','=',   null),
      -- CHARTER: hak ne olursa olsun salon kapalı. Host'a sorulamaz da —
      -- engel misafirin kendi uçuşundan doğuyor (221'in kapısı).
      ( 6,1,'TK_MS','ELPL','IST','Turkish Airlines Lounge — Dış Hat (Miles&Smiles)','TK','TK9001',true,2,0, 8,'07:00','11:00','=',   null),
      -- Priority Pass'ın GEÇMEDİĞİ salon → "bu salonda geçerli değil".
      ( 7,1,'PRIORITY_PASS',null,'ADB','Turkish Airlines Lounge','TK','TK2314',false,2,0, 9,'12:00','16:00',null, null),
      -- SLOTLARI DOLU: karar "misafir hakkı var" ama başvuru kapalı.
      ( 8,1,'TK_MS','ELPL','AYT','Turkish Airlines Lounge|Primeclass Lounge','TK','TK2402',false,1,1,10,'13:00','17:00','=',   null),
      -- Kuralı DOĞRULANMAMIŞ salon → "henüz doğrulanmadı" (unknown).
      ( 9,1,'IGA_LOUNGE',null,'IST','iGA Lounge — Dış Hat','TK','TK1980',false,2,0,11,'12:00','16:00','TK1980', null),
      -- LoungeKey: kapıda tahsil edilen misafir ücreti.
      (10,1,'LOUNGEKEY',null,'ESB','Primeclass Lounge — İç Hat|Primeclass CIP Lounge|Primeclass Lounge','TK','TK2104',false,2,0,12,'10:00','14:00',null, '='),
      -- UZUN KALIŞ + 3 slot: süre/kapasite uyarılarının göründüğü ilan.
      (11,1,'TK_MS','ELPL','IST','Turkish Airlines Lounge — Dış Hat (Miles&Smiles)','TK','TK1957',false,3,0,13,'06:00','13:00',null, null),
      -- ── host2 · KISITLI ────────────────────────────────────────────
      -- KADEME ENGELİ: aynı salon, Classic Plus → misafir hakkı YOK.
      -- 1 numaralı ilanla yan yana durduğunda kural tek bakışta anlaşılır.
      (12,2,'TK_MS','CLPL','IST','Turkish Airlines Lounge — Dış Hat (Miles&Smiles)','TK','TK1959',false,2,0,14,'11:00','15:00','=',   null),
      -- AJet İSTİSNASI · İÇ HAT tarafı: ESB'de hak VAR.
      (13,2,'AJET_MS','ELPL','ESB','Turkish Airlines Lounge','VF','VF2210',false,2,0,15,'09:00','12:00','=',   'TK2110'),
      -- AJet İSTİSNASI · İSTANBUL: aynı hak, IST'te YOK.
      (14,2,'AJET_MS','ELPL','IST','Turkish Airlines Lounge — Dış Hat (Miles&Smiles)','VF','VF1876',false,2,0,16,'14:00','18:00',null, 'TK1877'),
      -- Business bileti: kartsız giriş, misafir hakkı yok.
      (15,2,'BUSINESS_TICKET',null,'IST','Turkish Airlines Lounge — Dış Hat (Business)','TK','TK1961',false,2,0,17,'16:00','20:00','TK1961', null),
      -- Banka kartı ayrıcalığı: program belirsiz → genel uyarı dalı.
      (16,2,'BANK_CARD',null,'ADB','Primeclass Lounge — Dış Hat','TK','TK2316',false,2,0,18,'15:00','19:00',null, null),
      -- Pegasus indirimli ücretli giriş: kapıda ödenen tutar.
      (17,2,'PGS_PAID',null,'SAW','Plaza Premium Lounge — İç Hat','PC','PC1102',false,2,0,19,'13:00','16:00','=',   null),
      -- Primeclass (TAV) operatör programı: kapıda ödeme.
      (18,2,'PRIMECLASS',null,'ESB','Primeclass Lounge — Dış Hat|Primeclass CIP Lounge|Primeclass Lounge','TK','TK2108',false,2,0,20,'07:00','11:00',null, '='),
      -- Aynı program, BAŞKA salon → BAŞKA ücret (49 EUR vs 63 EUR).
      -- Ücretin salona göre değiştiğini tek kartta göstermenin yolu bu.
      (19,2,'PGS_PAID',null,'SAW','Plaza Premium Bosphorus Lounge — Dış Hat','PC','PC1204',false,2,0,21,'14:00','18:00','=',  null),
      -- LoungeKey'in GEÇMEDİĞİ salon → "bu salonda geçerli değil".
      (20,2,'LOUNGEKEY',null,'ADB','Turkish Airlines Lounge','TK','TK2318',false,2,0,22,'09:00','13:00',null, null),
      -- DOLU + kısıtlı hak: iki engelin üst üste bindiği ilan.
      (21,2,'TK_MS','CLPL','DLM','Turkish Airlines CIP Lounge','TK','TK2404',false,1,1,23,'12:00','15:00','=',   null),
      -- Kuralı henüz doğrulanmamış salon, host2 tarafında da olsun:
      -- "bilmiyorum" ile "hayır" ekranda ayrı görünmeli.
      -- 🔴 Burada önce AYT 'Antalya Airport CIP Lounge' yazıyordu. ÖLÇTÜM:
      -- aynı migration kümesinin iki ayrı kurulumunda AYT kataloğu FARKLI
      -- çıkıyor — bir kurulumda 'Antalya Airport CIP Lounge', diğerinde
      -- 'Elite Lounge — Dış Hat (T1)' hayatta kalıyor (tekilleştirme
      -- belirsiz). O ada bağlı senaryo kurulumların bir kısmında sessizce
      -- düşüyordu. Artık iki kurulumda da bulunan bir salon kullanılıyor.
      (22,2,'ST_PASS',null,'SAW','Plaza Premium Bosphorus Lounge — Dış Hat','PC','PC2406',false,2,0,24,'10:00','14:00',null, '=')
    ) as t(n, host, kod, kademe, apt, salon, tsy, ucus, charter, slot, dolu, gun, t1, t2, g1f, g2f)
    order by t.n
  loop
    select id into v_uid from users
     where email = case r.host when 1 then 'host1@seed.loungelink.test'
                               else 'host2@seed.loungelink.test' end;
    select id into v_pid from lounge_programs where code = r.kod;

    -- 🔴 SALON SEÇİMİ TESADÜFE BIRAKILMIYOR (seed1'in en pahalı dersi) —
    -- ama TEK ADA da bağlanmıyor. ÖLÇTÜM: aynı migration kümesi üç kez
    -- kurulduğunda katalog ÜÇ KEZ AYNI ÇIKMADI. Tekilleştirme (161/190/211)
    -- birleşen iki kayıttan hangisinin hayatta kalacağını belirlemiyor:
    --   ESB → bir kurulumda 'Primeclass Lounge — Dış Hat' aktif,
    --         ötekinde 'Primeclass CIP Lounge' aktif, diğeri "(211 kopya)"
    --   AYT → 'Antalya Airport CIP Lounge' ↔ 'Elite Lounge — Dış Hat (T1)'
    -- İkisi de AYNI venue'ya bakıyor, yani kural aynı; değişen yalnız ad.
    -- Bu yüzden `salon` alanı '|' ile ayrılmış EŞDEĞER AD LİSTESİ olabilir.
    -- (Bu belirsizlik migration tarafında; burada yalnız tolere ediliyor.)
    select l.id, l.venue_id into v_lid, v_ven
      from lounges l
      join unnest(string_to_array(r.salon, '|')) with ordinality as ad(nm, sira)
        on l.name = ad.nm
     where l.airport_code = r.apt and coalesce(l.active, true)
       and l.venue_id is not null
     order by ad.sira, l.id limit 1;

    if v_lid is null then
      select l.id, l.venue_id into v_lid, v_ven
        from lounges l
       where l.airport_code = r.apt and coalesce(l.active, true)
         and l.venue_id is not null
         and lower(l.name) like '%' || lower(split_part(r.salon,'|',1)) || '%'
       order by length(l.name), l.id limit 1;
    end if;

    -- İKİNCİ YEDEK: adı bulamadıysak, EN AZINDAN bu programı kabul eden
    -- bir salona bağla. Hedeflenen dalın korunma ihtimali en yüksek olan
    -- seçim bu; rastgele salona düşmekten belirgin şekilde iyi.
    if v_lid is null then
      select l.id, l.venue_id into v_lid, v_ven
        from lounges l
        join lounge_venue_acceptance a2
          on a2.venue_id = l.venue_id and a2.program_id = v_pid
         and coalesce(a2.active,true) and coalesce(a2.accepted,true)
       where l.airport_code = r.apt and coalesce(l.active, true)
         and l.venue_id is not null
       order by l.name, l.id limit 1;
      if v_lid is not null then
        v_yedek := v_yedek + 1;
        raise notice 'SEED4 ⚠ #% : "%" (%) katalogda yok — programi kabul eden '
                     'baska salona baglandi', r.n, split_part(r.salon,'|',1), r.apt;
      end if;
    end if;

    -- 🔴 SON BASAMAK: SESSİZ DÜŞMEK YOK.
    -- Ölçtüm: aynı migration kümesi iki kez kurulduğunda salon kataloğu
    -- birebir aynı çıkmıyor (AYT'de tekilleştirme belirsiz). Adı bulunamayan
    -- senaryoyu `continue` ile atlamak, vitrinden bir dalın HABERSİZ
    -- eksilmesi demekti — kurulumun birinde 22, ötekinde 19 ilan çıkıyordu.
    -- Artık aynı havalimanındaki başka bir aktif salona bağlanıyor ve bu
    -- YEDEK kullanım hem sayılıyor hem ekrana basılıyor. Hedeflenen dal
    -- kaymış olabilir; o yüzden aşağıdaki rapor bloğu kararı OKUYUP yazıyor.
    if v_lid is null then
      select l.id, l.venue_id into v_lid, v_ven
        from lounges l
       where l.airport_code = r.apt and coalesce(l.active, true)
         and l.venue_id is not null
       order by l.name, l.id limit 1;
      if v_lid is not null then
        v_yedek := v_yedek + 1;
        raise notice 'SEED4 ⚠ #% : "%" (%) katalogda yok ve programi kabul eden '
                     'salon da yok — havalimanindaki ilk salon kullanildi',
          r.n, split_part(r.salon,'|',1), r.apt;
      end if;
    end if;

    if v_uid is null or v_pid is null or v_lid is null then
      v_atlanan := v_atlanan || format('#%s(%s/%s) ', r.n, r.apt, r.kod);
      continue;
    end if;

    v_aid   := ('44440000-0000-4000-8000-' || lpad(r.n::text, 12, '0'))::uuid;
    v_tarih := current_date + r.gun;

    insert into availabilities
      (id, host_id, airport_code, lounge_name, lounge_id, venue_id, program_id,
       program_source, avail_date, time_from, time_to, slots, filled,
       visibility, active, min_trust, flight_number, carrier, carrier_code, is_charter)
    values
      (v_aid, v_uid, r.apt::char(3),
       (select l.name from lounges l where l.id = v_lid), v_lid, v_ven, v_pid,
       'beyan', v_tarih, r.t1::time, r.t2::time, r.slot::smallint, r.dolu::smallint,
       'Public'::availability_visibility, true, 0::smallint,
       r.ucus, r.tsy, r.tsy, r.charter)
    on conflict (id) do update set
       host_id = excluded.host_id, airport_code = excluded.airport_code,
       lounge_name = excluded.lounge_name, lounge_id = excluded.lounge_id,
       venue_id = excluded.venue_id, program_id = excluded.program_id,
       program_source = excluded.program_source,
       avail_date = excluded.avail_date, time_from = excluded.time_from,
       time_to = excluded.time_to, slots = excluded.slots,
       -- 🔴 `filled` KOŞULLU YAZILIR. Bu ilana kabul edilmiş bir istek
       -- varsa sayacı seed'in beyanına geri çekmek, slot bütünlüğünü
       -- (166) bozar: kabul edilmiş misafir sayısı ile sayaç ayrışır.
       -- Yalnız kimsenin kabul edilmediği ilanda seed'in değeri geçerli.
       filled = case when exists (select 1 from requests q
                                   where q.avail_id = availabilities.id
                                     and q.status in ('accepted','completed'))
                     then availabilities.filled else excluded.filled end,
       visibility = excluded.visibility, active = true, min_trust = 0,
       flight_number = excluded.flight_number, carrier = excluded.carrier,
       carrier_code = excluded.carrier_code, is_charter = excluded.is_charter,
       updated_at = now();

    v_n := v_n + 1;

    -- ── MİSAFİR SEYAHATLERİ ────────────────────────────────────────
    -- '=' → ilanla AYNI UÇUŞ (aynı-uçuş rozeti)
    -- metin → FARKLI uçuş/taşıyıcı (taşıyıcı uyuşmazlığı notu)
    -- null → o misafirin o günde seyahati YOK (rozetsiz hal de görünsün)
    -- Pencere ilanı 1'er saat aşıyor ki örtüşme kesin olsun.
    for i in 1..2 loop
      v_gid  := case i when 1 then v_g1 else v_g2 end;
      v_ucus := case i when 1 then r.g1f else r.g2f end;
      v_vid  := ('44450000-0000-4000-8000-' || lpad((r.n * 2 - 2 + i)::text, 12, '0'))::uuid;

      if v_ucus is null then
        -- Bir önceki koşudan kalmış olabilir: bağlı isteği yoksa temizle.
        delete from visits v
         where v.id = v_vid
           and not exists (select 1 from requests q where q.visit_id = v.id);
        continue;
      end if;

      if v_ucus = '=' then v_ucus := r.ucus; end if;

      insert into visits (id, user_id, airport_code, visit_date, time_from, time_to,
                          flight_number, carrier_code, purpose)
      values (v_vid, v_gid, r.apt::char(3), v_tarih,
              greatest(time '00:00', r.t1::time - interval '1 hour')::time,
              least(time '23:59', r.t2::time + interval '1 hour')::time,
              v_ucus, public.carrier_from_flight(v_ucus),
              case when i = 1 then 'business' else 'leisure' end)
      on conflict (id) do update set
         user_id = excluded.user_id, airport_code = excluded.airport_code,
         visit_date = excluded.visit_date, time_from = excluded.time_from,
         time_to = excluded.time_to, flight_number = excluded.flight_number,
         carrier_code = excluded.carrier_code, purpose = excluded.purpose;
      v_sey := v_sey + 1;
    end loop;
  end loop;

  raise notice 'SEED4 · % senaryo ilani + % misafir seyahati yazildi · yedek salon=% %',
    v_n, v_sey, v_yedek,
    case when v_atlanan = '' then '' else 'ATLANAN: ' || v_atlanan end;

  -- Matris 22 satır; 20'nin altına düşmek "bir dal sessizce kayboldu"
  -- demektir ve vitrinin varlık sebebini ortadan kaldırır.
  if v_n < 20 then
    raise exception 'SEED4: 22 senaryonun yalnizca % tanesi yazilabildi (atlanan: %) — '
                    'salon katalogu beklenenden farkli', v_n, coalesce(nullif(v_atlanan,''),'yok');
  end if;
end $s4_ilan$;


-- ════════════════════════════════════════════════════════════════════════
-- 3) MEVCUT VİTRİNİ GÖRÜNÜR KIL — SEED1 VE 173 VERİSİ SİLİNMİYOR
--
-- SEED_KURAL_SENARYOLARI (seed1) 18 ayrı host ile 18 ayrı kural dalını
-- zaten kuruyor ve o veri DOĞRU. Eksik olan tek şey, misafirin o
-- ilanlarla kesişen bir seyahatinin olmaması: ilan listede çıkıyor ama
-- "seyahatinle örtüşüyor" bağı, uçuş bağlı rozetler ve eşleşme puanı
-- ölü kalıyordu. Burada o bağı kuruyoruz.
--
-- 🔴 SIRA GERÇEĞİ: seed1 harness'te SEED4'ten SONRA koşuyor (dosya
-- başındaki ölçüm). Yani bu blok İLK kurulumda 0 satır yazabilir ve bu
-- BEKLENEN bir durumdur — nöbetçi buna bel bağlamıyor. İkinci turda
-- (ve Gökberk'in elle kurduğu sırada) seed1 ilanları hazır olur.
--
-- 🔴 SEED4'ün kendi ilanlarına DOKUNMUYOR: onların seyahat kurgusu
-- (aynı uçuş / farklı taşıyıcı / seyahatsiz) bilerek seçildi; buradaki
-- toptan doldurma onu bozardı.
-- ════════════════════════════════════════════════════════════════════════
do $s4_kopru$
declare
  r record; g record; v_n int := 0; v_bakilan int := 0;
begin
  for g in select id, email from users
            where email in ('guest1@seed.loungelink.test','guest2@seed.loungelink.test')
  loop
    for r in
      select a.id, a.airport_code, a.avail_date, a.time_from, a.time_to, a.flight_number
        from availabilities a
        join users hu on hu.id = a.host_id
       where a.active = true
         and a.avail_date >= current_date
         and coalesce(a.visibility,'Public') <> 'Hidden'
         and coalesce(hu.is_staff,false) = false
         and hu.email not in ('host1@seed.loungelink.test','host2@seed.loungelink.test',
                              'guest1@seed.loungelink.test','guest2@seed.loungelink.test')
       order by a.avail_date, a.id
       limit 60
    loop
      v_bakilan := v_bakilan + 1;
      -- Aynı havalimanı+günde seyahati VARSA dokunma: ikinci satır
      -- `discovery_rule_badges`in `limit 1` uçuş seçimini belirsizleştirir.
      continue when exists (select 1 from visits v
                             where v.user_id = g.id and v.airport_code = r.airport_code
                               and v.visit_date = r.avail_date);

      insert into visits (user_id, airport_code, visit_date, time_from, time_to,
                          flight_number, carrier_code, purpose)
      values (g.id, r.airport_code, r.avail_date,
              greatest(time '00:00', r.time_from - interval '1 hour')::time,
              least(time '23:59', r.time_to + interval '1 hour')::time,
              r.flight_number, public.carrier_from_flight(r.flight_number),
              'leisure');
      v_n := v_n + 1;
    end loop;
  end loop;

  raise notice 'SEED4 · dis vitrin koprusu: % ilan tarandi, % yeni seyahat yazildi '
               '(0 ise seed1 henuz kurulmamis demektir — beklenen)', v_bakilan, v_n;
end $s4_kopru$;


-- ════════════════════════════════════════════════════════════════════════
-- 4) SENARYO MATRİSİNİN GERÇEK KARARLARI — İDDİA DEĞİL, ÇIKTI
--
-- Yukarıdaki her satırın yorumunda "hangi dalı hedeflediği" yazıyor.
-- O bir NİYET. Aşağısı motorun gerçekte ne dediği. İkisi ayrılırsa
-- burada görülür.
-- ════════════════════════════════════════════════════════════════════════
do $s4_rapor$
declare r record; d jsonb; v_sayi int := 0; v_dal text[] := '{}'; v_k text;
begin
  for r in
    select a.id, a.airport_code, a.lounge_name, p.code as prog, u.email as host
      from availabilities a
      join users u on u.id = a.host_id
      left join lounge_programs p on p.id = a.program_id
     where a.id::text like '44440000-0000-4000-8000-%'
     order by a.id
  loop
    d := public.lounge_access_decision(r.id, null);
    v_k := coalesce(d ->> 'guest_policy','?') || '/' || coalesce(d ->> 'severity','?');
    if not (v_k = any (v_dal)) then v_dal := v_dal || v_k; end if;
    v_sayi := v_sayi + 1;
    raise notice 'SEED4 · % % @ %  →  % · %',
      right(r.id::text, 2), coalesce(r.prog,'—'), r.airport_code,
      v_k, left(coalesce(d ->> 'headline','(basliksiz)'), 58);
  end loop;

  if v_sayi = 0 then
    raise exception 'SEED4: matris raporu HIC SATIR gormedi — ilanlar yazilmamis';
  end if;
  raise notice 'SEED4 · matris: % ilan, % farkli karar dali → %',
    v_sayi, array_length(v_dal,1), array_to_string(v_dal, ' · ');

  -- Matrisin tamamı tek bir dala düşmüşse vitrin yoktur, liste vardır.
  if coalesce(array_length(v_dal,1),0) < 4 then
    raise exception 'SEED4: matris yalnizca % karar dali uretti (%) — beklenen >=4 '
                    '(included / paid / not_allowed / unknown)',
                    coalesce(array_length(v_dal,1),0), array_to_string(v_dal, ' · ');
  end if;
end $s4_rapor$;


-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ · MİSAFİRİN KENDİ GÖZÜNDEN ÖLÇÜM
--
-- 🔴 BU DOSYANIN VAR OLMA SEBEBİ. Önceki turda tam olarak şu hata
-- yapıldı: seed "OK" yazdı ama misafirin ekranını hiç sorgulamadı,
-- Gökberk uygulamayı açtı ve boş ekran gördü. Bu yüzden burada
-- ölçülen şey ilanların tablodaki varlığı DEĞİL, guest1 kimliğiyle
-- `discover_availabilities()` çağrısının döndürdüğü satırlar.
--
-- 🔴 SIFIR SATIR = BAŞARISIZLIK. Döngü hiç dönmezse ya da sorgu boş
-- gelirse nöbetçi YEŞİL YANMAZ; "olcum yapilamadi" diye durur. Hiçbir
-- şey ölçmeden geçen nöbetçi, nöbetçi değildir.
-- ════════════════════════════════════════════════════════════════════════
do $s4_nobetci$
declare
  r record;
  v_olculen int := 0;
  v_hata text := '';
  v_ilan int; v_pol int; v_rozet int;
  v_ucretsiz int; v_ucretli int; v_engel int; v_dolu int; v_sor int;
  v_seyahatli int; v_ayniucus int;
begin
  for r in select id, email from users
            where email in ('guest1@seed.loungelink.test','guest2@seed.loungelink.test')
            order by email
  loop
    v_olculen := v_olculen + 1;

    -- Kimliğe bürün: RPC'ler `auth.uid()` üzerinden çalışıyor.
    perform set_config('request.jwt.claims',
                       json_build_object('sub', r.id::text)::text, true);

    select
      count(*),
      count(distinct v.guest_policy),
      count(distinct coalesce(v.rsev,'-') || '|' || coalesce(v.rlabel,'-')),
      count(*) filter (where v.guest_policy = 'included'
                         and not coalesce(v.blocks_request,false)
                         and not coalesce(v.fully_booked,false)),
      count(*) filter (where v.guest_policy = 'paid'),
      count(*) filter (where v.guest_policy = 'not_allowed'
                          or v.block_reason = 'blocked_by_rule'),
      count(*) filter (where coalesce(v.fully_booked,false)),
      count(*) filter (where coalesce(v.can_ask_host,false)),
      count(*) filter (where coalesce(v.has_trip,false)),
      count(*) filter (where coalesce(v.same_flight,false))
    into v_ilan, v_pol, v_rozet, v_ucretsiz, v_ucretli, v_engel, v_dolu, v_sor,
         v_seyahatli, v_ayniucus
    from (
      select d.guest_policy, d.blocks_request, d.block_reason, d.fully_booked,
             d.has_trip, d.same_flight,
             b.severity as rsev, b.label as rlabel, b.can_ask_host
        from public.discover_availabilities() d
        left join lateral public.discovery_rule_badges(array[d.id]) b on true
    ) v;

    raise notice 'SEED4 KAPSAM · % → ilan=% · karar_dali=% · rozet_cesidi=% · '
                 'ucretsiz=% · ucretli=% · engelli=% · dolu=% · hosta_sor=% · '
                 'seyahatli=% · ayni_ucus=%',
      r.email, v_ilan, v_pol, v_rozet, v_ucretsiz, v_ucretli, v_engel, v_dolu,
      v_sor, v_seyahatli, v_ayniucus;

    -- 🔴 SERT EŞİK YALNIZ guest1'DE. guest2 ölçülüyor ve basılıyor ama
    -- eşiği yok: onun kurgusunda bilerek daha az seyahat var (seyahatsiz
    -- hal de test edilebilsin diye). İkisine aynı eşiği koymak, o farkı
    -- yok etmek zorunda bırakırdı.
    if r.email = 'guest1@seed.loungelink.test' then
      if v_ilan = 0 then
        v_hata := v_hata || 'guest1 HIC ILAN GORMUYOR(olcum=0); ';
      else
        if v_ilan   < 15 then v_hata := v_hata || format('ilan=%s(<15); ', v_ilan); end if;
        if v_rozet  <  5 then v_hata := v_hata || format('rozet_cesidi=%s(<5); ', v_rozet); end if;
        if v_ucretsiz = 0 then v_hata := v_hata || 'ucretsiz-misafirli-basvurulabilir ilan YOK; '; end if;
        if v_ucretli  = 0 then v_hata := v_hata || 'ucretli-misafir ilani YOK; '; end if;
        if v_engel    = 0 then v_hata := v_hata || 'engelli/not_allowed ilan YOK; '; end if;
        if v_dolu     = 0 then v_hata := v_hata || 'slotu DOLU ilan YOK; '; end if;
        if v_sor      = 0 then v_hata := v_hata || '"hosta sorulabilir" ilan YOK; '; end if;
      end if;
    end if;
  end loop;

  perform set_config('request.jwt.claims', '', true);

  if v_olculen = 0 then
    raise exception 'SEED4: OLCUM YAPILAMADI — guest1/guest2 bulunamadi, '
                    'dongu sifir satir dondu. Bu bir BASARISIZLIKTIR.';
  end if;

  if v_hata <> '' then
    raise exception 'SEED4: VITRIN YETERSIZ → %  (beklenen: guest1 icin >=15 ilan, '
                    '>=5 rozet cesidi ve ucretsiz/ucretli/engelli/dolu/hosta-sor '
                    'durumlarinin HER BIRINDEN en az 1 tane)', v_hata;
  end if;

  raise notice 'SEED4 · nobetci % misafiri olctu, esikler tuttu', v_olculen;
end $s4_nobetci$;

select 'SEED4 OK — kural vitrini guest1/guest2 gozunden OLCULDU' as sonuc;
