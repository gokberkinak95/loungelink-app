-- ============================================================
-- 217 · MİSAFİR ÜCRETİ GERİ — 214'ÜN HATASI
-- 18 Ağustos 2026
--
-- 🔴 BU DOSYA BİR DÜZELTME DEĞİL, BİR GERİ ALMA.
-- 214'te şunu yazdım ve YANLIŞTI:
--
--     "Her iki ağın da KENDİ sözleşmesini baştan sona okudum. İkisinde
--      de misafir ücreti tutarı GEÇMİYOR. Sayıyı siliyorum; yerine
--      'değişkendir, bankandan teyit et' cümlesi koyuyorum."
--
-- Gökberk plan sayfalarını gönderdi. Tutarlar orada, ilan panosu gibi:
--
--   PRIORITY PASS · prioritypass.com/tr-TR/join-prioritypass (İkamet: Türkiye)
--     STANDARD       89 EUR/yıl · 30 EUR üye ziyareti · 30 EUR KONUK ziyareti
--     STANDARD PLUS 289 EUR/yıl · 10 ücretsiz, sonra 30 EUR · 30 EUR KONUK
--     PRESTIGE      459 EUR/yıl · üye ziyaretleri TAMAMEN ÜCRETSİZ · 30 EUR KONUK
--     (+ 10 EUR teslimat ücreti)
--
--   DRAGONPASS · dragonpassgo.com/membership-plan (EUR)
--     Classic       96 EUR/yıl · 1 ücretsiz ziyaret · ek üye VEYA KONUK 36 EUR
--     Preferential 249 EUR/yıl · 8 ücretsiz ziyaret · ek üye VEYA KONUK 36 EUR
--
-- HATAM NEREDE: sözleşme (Kullanım Koşulları) ile FİYAT SAYFASI iki ayrı
-- belgedir. Sözleşmede tutar yazmaz — orada "kartı veren kurumun bildirdiği
-- oranlar" yazar, çünkü sözleşme FATURALAMANIN KİME yapıldığını anlatır,
-- FİYATI değil. Ben sözleşmeyi okuyup "fiyat yok" sonucuna vardım ve
-- KATALOGDA ZATEN DOĞRU OLAN sayıyı sildim.
--
-- ⚠️ HATA SINIFI 23 — "KAYNAĞI BULAMAMAK, KAYNAĞIN OLMADIĞI DEĞİLDİR."
-- Bu proje boyunca kuralım "kaynaksız veri yazma"ydı ve doğruydu. Ama
-- ters yönü hiç yazmamıştım: ELİMDEKİ KAYNAK SUSUYORSA, VERİ YANLIŞ
-- DEMEK DEĞİLDİR. Doğru refleks silmek değil, "bu kaynak bu soruyu
-- cevaplamıyor" diye işaretleyip DOĞRU KAYNAĞI ARAMAKTI.
-- Silmek geri alınabilir bir hata oldu çünkü veri `lounge_guest_rules`
-- kademe satırlarında duruyordu — orayı silseydim geri alınamazdı.
--
-- 🔴 ÜRÜN AÇISINDAN ASIL BULGU — VE BU 214'TE DE KAÇMIŞTI:
-- Priority Pass'in EN PAHALI planı (Prestige, 459 EUR/yıl) üyenin kendi
-- girişlerini SINIRSIZ ÜCRETSİZ yapıyor ama MİSAFİR YİNE 30 EUR.
-- DragonPass'te de aynı: hangi planı alırsan al, misafir 36 EUR.
-- Yani kart ağlarında misafir hakkı SATIN ALINAMIYOR.
-- LoungeLink'in tek cümlesi tam burada duruyor: 459 EUR ödeyen biri bile
-- misafirini ücretsiz alamıyor; ama misafir hakkı OLAN birinin yanında
-- ücretsiz girebiliyor.
-- ============================================================


-- ============================================================
-- (1) PROGRAM SEVİYESİ — SAYILAR GERİ, KAYNAĞIYLA
-- ============================================================
update lounge_programs
   set typical_guest_fee  = 30,
       guest_fee_currency = 'EUR',
       source_url         = 'https://www.prioritypass.com/tr-TR/join-prioritypass',
       checked_at         = date '2026-08-18',
       notes = coalesce(notes || ' · ', '')
            || '217: 214 bu tutari KAYNAKSIZ sanip silmisti — hataliydi. Plan sayfasi (ikamet: Turkiye) uc planin UCUNDE de '
            || '"30 EUR Konuk ziyaret ucreti" yaziyor. Sozlesmede tutar yazmamasi, tutarin OLMADIGI anlamina gelmiyordu; '
            || 'sozlesme faturalamanin KIME yapildigini anlatir, fiyati degil.'
 where code = 'PRIORITY_PASS';

update lounge_programs
   set typical_guest_fee  = 36,
       guest_fee_currency = 'EUR',
       source_url         = 'https://www.dragonpassgo.com/membership-plan',
       checked_at         = date '2026-08-18',
       notes = coalesce(notes || ' · ', '')
            || '217: 214 bu tutari KAYNAKSIZ sanip silmisti — hataliydi. Plan sayfasi iki planin ikisinde de '
            || '"Additional member or guest visits for EUR 36" yaziyor.'
 where code = 'DRAGONPASS';

-- LOUNGEKEY FARKLI VE ÖYLE KALIYOR. LoungeKey'in halka açık bir plan
-- sayfası YOK: banka markalı dağıtılıyor (ekran görüntülerindeki sürüm
-- "yapikredicrystal"). Tutarı kartı veren banka belirler. Burada
-- "değişken" demek TAHMİN değil, ÖLÇÜLMÜŞ bir farktır — ve PP/DragonPass
-- ile aynı kefeye koymamak gerekiyor.
update lounge_programs
   set notes = coalesce(notes || ' · ', '')
            || '217: LoungeKey''in halka acik plan sayfasi YOK (banka markali dagitiliyor). PP ve DragonPass''ten farkli olarak '
            || 'misafir ucreti gercekten karti veren bankaya baglidir; burada "degisken" demek tahmin degil olculmus farktir.'
 where code = 'LOUNGEKEY';


-- ============================================================
-- (2) SALON KABUL SATIRLARI — TUTAR GERİ
-- ============================================================
update lounge_venue_acceptance a
   set guest_fee_amount   = case p.code when 'PRIORITY_PASS' then 30 when 'DRAGONPASS' then 36 end,
       guest_fee_currency = 'EUR',
       guest_fee_note     = case p.code
         when 'PRIORITY_PASS' then
           'Misafir ziyareti 30 EUR (kisi basi, ziyaret basina). Uc uyelik planinin UCUNDE de ayni: Standard, Standard Plus ve '
           || 'Prestige. Prestige''de UYENIN kendi girisleri sinirsiz ucretsiz ama MISAFIR YINE 30 EUR — yani misafir hakki '
           || 'daha pahali plan alarak KAZANILAMIYOR. Ucret uyenin kartindan tahsil edilir.'
         when 'DRAGONPASS' then
           'Ek uye ya da misafir ziyareti 36 EUR (kisi basi). Iki planin ikisinde de ayni: Classic ve Preferential. '
           || 'Plandaki ucretsiz ziyaret hakki (Classic 1, Preferential 8) YALNIZ UYENIN KENDISI icindir; misafir her hâlukârda oder.'
         end,
       source_url = case p.code
         when 'PRIORITY_PASS' then 'https://www.prioritypass.com/tr-TR/join-prioritypass'
         when 'DRAGONPASS'    then 'https://www.dragonpassgo.com/membership-plan' end,
       checked_at = date '2026-08-18',
       updated_at = now()
  from lounge_programs p
 where p.id = a.program_id
   and p.code in ('PRIORITY_PASS','DRAGONPASS')
   and a.accepted and a.active;

-- LoungeKey satırlarındaki cümleyi de düzelt: "değişken" doğru ama SEBEBİ
-- yanlış yazılmıştı (PP/DragonPass ile aynı gerekçe gösteriliyordu).
update lounge_venue_acceptance a
   set guest_fee_note = 'Misafir ucretlidir. LoungeKey banka markali dagitildigi icin (orn. Yapi Kredi Crystal) tutari KARTI VEREN BANKA '
                     || 'belirler ve halka acik bir plan sayfasi yoktur — bu yuzden tek bir rakam yazmiyoruz. Banka sozlesmenden teyit et. '
                     || 'Misafirin KENDI ayni gun binis karti olmalidir.',
       updated_at = now()
  from lounge_programs p
 where p.id = a.program_id and p.code = 'LOUNGEKEY'
   and a.accepted and a.active;


-- ============================================================
-- (3) PLAN EKONOMİSİ — YILLIK ÜCRET VE ÜCRETSİZ ZİYARET
-- ============================================================
-- Kademe satırları (`lounge_guest_rules`) zaten doğruydu — 196 bunu düzgün
-- yazmış, ben yalnız program seviyesini bozmuşum. Yine de plan sayfasında
-- görünen ve katalogda EKSİK olan iki şey var: yıllık ücret ve Prestige'in
-- "sınırsız" durumu. Bunlar "kaçırılan değer" hesabının girdisi:
-- host'a "bu hakkı satın alsaydın 459 EUR öderdin" diyebilmek için lazım.
alter table lounge_guest_rules add column if not exists yillik_ucret numeric;
alter table lounge_guest_rules add column if not exists yillik_para  text;
comment on column lounge_guest_rules.yillik_ucret is
  '217: uyelik planinin yillik ucreti. Kacirilan deger hesabi bunu kullanir: "bu hakki satin alsaydin ne oderdin".';

update lounge_guest_rules r
   set yillik_ucret = v.ucret, yillik_para = 'EUR'
  from (values
    ('PP_STANDARD',       89),
    ('PP_STANDARD_PLUS', 289),
    ('PP_PRESTIGE',      459),
    ('DP_CLASSIC',        96),
    ('DP_PREFERENTIAL',  249)
  ) as v(tier, ucret)
 where r.card_tier = v.tier;

-- Prestige'in "sınırsız" hâli: `member_free_visits` boştu ve boş bırakmak
-- "bilinmiyor" demek. Oysa biliniyor — sınırsız. -1 ile işaretliyorum ve
-- anlamını sütun yorumuna yazıyorum (sihirli sayıyı gizlemek, sihirli
-- sayıdan beterdir).
comment on column lounge_guest_rules.member_free_visits is
  '217: uyenin YILDA kac ucretsiz ziyareti var. -1 = SINIRSIZ (Priority Pass Prestige). null = bilinmiyor.';
update lounge_guest_rules
   set member_free_visits = -1
 where card_tier = 'PP_PRESTIGE' and member_free_visits is null;


-- ============================================================
-- (4) "MİSAFİR HAKKI SATIN ALINAMIYOR" — ÜRÜNÜN CÜMLESİ
-- ============================================================
-- Bu, plan sayfalarının söylediği ve LoungeLink'i haklı çıkaran tek
-- cümle. Veriyi yazmak yetmez (hata sınıfı 18): OKUNAN bir yere koyuyorum.
create or replace function public.misafir_hakki_satin_alinabilir_mi(p_program text)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'program', p_program,
    'en_pahali_plan',      (select r.card_tier from lounge_guest_rules r
                              join lounge_programs p on p.id = r.program_id
                             where p.code = p_program and r.yillik_ucret is not null
                             order by r.yillik_ucret desc limit 1),
    'en_pahali_yillik',    (select max(r.yillik_ucret) from lounge_guest_rules r
                              join lounge_programs p on p.id = r.program_id
                             where p.code = p_program),
    'para',                'EUR',
    -- Hiçbir kademede ücretsiz misafir yoksa: hak satın alınamıyor.
    'misafir_ucretsiz_olan_plan_var_mi',
      (select bool_or(coalesce(r.guest_allowance,0) > 0) from lounge_guest_rules r
         join lounge_programs p on p.id = r.program_id where p.code = p_program),
    'misafir_ucreti',      (select p.typical_guest_fee from lounge_programs p where p.code = p_program),
    'kaynak',              (select p.source_url from lounge_programs p where p.code = p_program),
    'kontrol',             (select p.checked_at  from lounge_programs p where p.code = p_program));
$fn$;
grant execute on function public.misafir_hakki_satin_alinabilir_mi(text) to authenticated, service_role;

insert into rpc_client_surface (fn_name, client, note) values
  ('misafir_hakki_satin_alinabilir_mi', 'app',
   'Kart aglarinda misafir hakki satin alinamiyor — LoungeLink''in varlik sebebi. Plan sayfasindan olculmus.')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) 🔴 TUTAR BİR DAHA SESSİZCE SİLİNEMESİN
-- 214'te olan tam olarak buydu: bir migration "kaynak bulamadım" deyip
-- doğru bir sayıyı null yaptı ve HİÇBİR NÖBETÇİ SES ÇIKARMADI. Sayının
-- yokluğu, varlığından daha az göze batıyor — sessiz silme en pahalı
-- düzenleme biçimi. Artık bu iki program için tutar ZORUNLU.
do $$
declare r record; v_eksik text := '';
begin
  for r in select code, typical_guest_fee, guest_fee_currency from lounge_programs
            where code in ('PRIORITY_PASS','DRAGONPASS')
  loop
    if r.typical_guest_fee is null or r.guest_fee_currency is null then
      v_eksik := v_eksik || r.code || ' ';
    end if;
  end loop;
  if v_eksik <> '' then
    raise exception '217: su programlarin misafir ucreti BOS: %. Plan sayfasinda yaziyor (PP 30 EUR / DragonPass 36 EUR); '
                    'kaynak bulunamamasi tutarin olmadigi anlamina gelmez.', v_eksik;
  end if;
  raise notice '217: PP ve DragonPass misafir ucreti yerinde (30 / 36 EUR)';
end $$;

-- 2) TUTAR KARARDA GÖRÜNÜYOR MU (mutasyon)
-- Veriyi yazmak yetmez; kullanıcının gördüğü KARAR çıktısında olmalı.
do $$
declare v_v uuid; v_p uuid; v_dec jsonb;
begin
  select id into v_p from lounge_programs where code = 'PRIORITY_PASS';
  select a.venue_id into v_v from lounge_venue_acceptance a
   where a.program_id = v_p and a.accepted and a.active limit 1;
  if v_v is null then raise exception '217: PP kabul satiri yok — sinanamadi'; end if;

  v_dec := public.lounge_access_decision_v5(v_v, v_p, null, null, null);
  if coalesce(v_dec::text,'') not like '%30%' then
    raise exception '217: PP karari 30 EUR tutarini TASIMIYOR → %', left(v_dec::text, 400);
  end if;
  raise notice '217: misafir ucreti karar ciktisinda gorunuyor';
exception when undefined_function then
  -- Karar fonksiyonunun sürümü değişmiş olabilir; kabul satırından ölç.
  if not exists (select 1 from lounge_venue_acceptance a
                  where a.program_id = v_p and a.accepted and a.active
                    and a.guest_fee_amount = 30) then
    raise exception '217: PP kabul satirlarinda 30 EUR yok';
  end if;
  raise notice '217: misafir ucreti kabul satirlarinda yerinde (karar fonksiyonu imzasi degismis)';
end $$;

-- 3) EN PAHALI PLANDA BİLE MİSAFİR ÜCRETSİZ DEĞİL
-- Ürünün varlık sebebi. Bir gün biri "Prestige alırsan misafir bedava"
-- diye veri girerse, bu satır kırmızı yanmalı — çünkü plan sayfası
-- bunun tersini söylüyor.
do $$
declare v jsonb;
begin
  foreach v in array array[
    public.misafir_hakki_satin_alinabilir_mi('PRIORITY_PASS'),
    public.misafir_hakki_satin_alinabilir_mi('DRAGONPASS')]
  loop
    if coalesce((v ->> 'misafir_ucretsiz_olan_plan_var_mi')::boolean, false) then
      raise exception '217: % icin "ucretsiz misafir veren plan var" gorunuyor — plan sayfasi bunu SOYLEMIYOR → %',
        v ->> 'program', left(v::text, 300);
    end if;
    if (v ->> 'misafir_ucreti') is null then
      raise exception '217: % icin misafir ucreti bos', v ->> 'program';
    end if;
    raise notice '217: % — en pahali plan % EUR/yil, misafir yine % EUR (hak SATIN ALINAMIYOR)',
      v ->> 'program', v ->> 'en_pahali_yillik', v ->> 'misafir_ucreti';
  end loop;
end $$;

-- 4) KADEME SATIRLARI PLAN SAYFASIYLA UYUŞUYOR MU
do $$
declare r record; v_hata text := '';
begin
  for r in select * from (values
      ('PP_STANDARD',       89::numeric, 0),
      ('PP_STANDARD_PLUS', 289, 10),
      ('PP_PRESTIGE',      459, -1),
      ('DP_CLASSIC',        96, 1),
      ('DP_PREFERENTIAL',  249, 8)
    -- ⚠️ TAKMA AD LİSTESİNDE TİP YAZILMAZ (42601). Bu dersi 214'te
    -- öğrenip DOSYAYA YAZDIM, sonra burada aynısını tekrar yaptım.
    -- Yorumu okumak, refleksi değiştirmiyor.
    ) as t(tier, yillik, ucretsiz)
  loop
    if not exists (select 1 from lounge_guest_rules g
                    where g.card_tier = r.tier
                      and g.yillik_ucret = r.yillik
                      and coalesce(g.member_free_visits, -99) = r.ucretsiz)
    then v_hata := v_hata || r.tier || ' '; end if;
  end loop;
  if v_hata <> '' then
    raise exception '217: su kademeler plan sayfasiyla uyusmuyor: %', v_hata;
  end if;
  raise notice '217: bes kademenin de yillik ucreti ve ucretsiz ziyaret sayisi plan sayfasiyla ayni';
end $$;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '217: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '217 OK - misafir ucreti geri, kaynagiyla' as sonuc;
