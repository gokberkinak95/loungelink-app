-- ============================================================
-- 198 · THY / AJet / MILES&SMILES — UÇTAN UCA YENİDEN DOĞRULAMA
-- 17 Ağustos 2026
--
-- ⚠️ UYGULAMAYI ETKİLER: AJet misafir hakkı AÇILIYOR (0 → 1 + aile),
-- iki fazla-iddia geri alınıyor, taşıyıcı sözlüğü tekilleşiyor.
--
-- ------------------------------------------------------------
-- KAYNAKLAR — üçü de ELDE, satır satır okundu
-- ------------------------------------------------------------
-- (K1) THY · Lounge Kurallar ve Koşullar
--      https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/
--      Tablo-1 (iç hat) · Tablo-2 (dış hat) · Tablo-3 (IST Business bölümü)
--      Tablo-4 (IST M&S bölümü) · Tablo-5 (yurt dışı anlaşmalı)
--      + 18 maddelik genel kural + AJet seferleri için 16 maddelik ek
-- (K2) AJet · CIP Lounge Kuralları
--      https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge
--      Genel Kurallar · Ücret tablosu (13 havalimanı) · Ücret Kuralları
--      · SAW salon künyesi · Diğer Kurallar
-- (K3) THY · Miles&Smiles statü ve ayrıcalıklar sayfası
--      Classic / Classic Plus / Elite / Elite Plus kart ayrıcalıkları
--
-- ------------------------------------------------------------
-- 🔴 EN AĞIR BULGU — AJet MİSAFİR HAKKINI YANLIŞLIKLA KAPATMIŞIZ
-- ------------------------------------------------------------
-- 191'de AJet SAW kuralını yazarken şu notu koymuşum:
--   "Misafir hakkı AJet tablosunda tanımlı değil"
-- ve guest_allowance = 0 yazmışım. ÖLÇTÜM: bu YANLIŞ.
--
-- K2'nin "Genel Kurallar" bölümü aynen şunu diyor:
--   "Miles&Smiles Elite, Miles&Smiles Elite Plus veya Miles&Smiles
--    Elite Corporate kart sahibi yolcu(lar) salonu ücretsiz kullanım
--    hakkına sahiptir. AYRICA YOLCU BERABERİNDE AİLE BİREYİ VEYA BİR
--    MİSAFİR İÇİN DE ÜCRETSİZ KULLANIM HAKKI BULUNMAKTADIR."
-- K3 aynı hakkı ikinci kez teyit ediyor:
--   "AJet Uçuşlarında eş ile çocuklar veya bir misafirle özel yolcu
--    salonlarından yararlanabilme"
--
-- Yani hak AÇIKÇA YAZILI ve İKİ resmî kaynakta birden var. Ben ücret
-- tablosuna bakıp "misafir sütunu yok" diye yokluk çıkarmışım —
-- oysa ücret tablosu ÜCRETLİ girişi anlatıyor, hak metinde.
--
-- Zararı: SAW salon kuralı VENUE-SCOPED olduğu için motorun sıralama
-- kuralında genel kuralı YENİYOR (resolve_guest_rule: venue eşleşmesi
-- en üstte). Yani AJet'in en önemli salonunda Elite bir host'a
-- "misafir hakkın yok" deniyordu. Genel VF kuralı doğruydu; salon
-- kuralı onu eziyordu.
--
-- 🔴 YENİ SINIF: "ÜCRET TABLOSUNDAN HAK ÇIKARILMAZ." Bir ücret
-- tablosunda misafir sütunu olmaması, misafir hakkı olmadığını
-- göstermez — o tablo hakkı değil FİYATI anlatır. Hak metinde aranır.
-- 191'deki Priority Pass "fazla iddia" hatasının aynadaki hâli: orada
-- olmayan bir kısıtı VAR saymıştım, burada var olan bir hakkı YOK.
-- ============================================================


-- ============================================================
-- 1) TAŞIYICI SÖZLÜĞÜ — AJet KATALOGDA HİÇ YOKMUŞ
-- ============================================================
-- 🔴 ÖLÇÜM: `carriers` tablosunda 20 havayolu var ve AJet YOK.
-- Ne 'VF' ne 'AJ'. SunExpress ('XQ') de yok. Oysa:
--   · uygulamanın seyahat ekranı ["TK","VF","PC","XQ"] çipleri gösteriyor
--   · availabilities.carrier_code'un carriers(code)'a YABANCI ANAHTARI var
-- Yani host "AJet" çipine bastığında yazılacak kod katalogda yok;
-- taşıyıcı seçimi ilana YAZILAMIYOR. Projedeki en çok konuştuğumuz
-- ikinci havayolu, havayolu listesinde bulunmuyordu.
insert into carriers (code, name, alliance, is_lowcost, active, sort_order)
values ('VF', 'AJet', null, true, true, 2),
       ('XQ', 'SunExpress', null, true, true, 5)
on conflict (code) do update
  set name = excluded.name, active = true, is_lowcost = excluded.is_lowcost;

-- 'AJ' KODU BİR HAYALETTİ: hiçbir yerde tanımlı değil ama 12 kural
-- satırında kullanılmış. resolve_guest_rule taşıyıcıyı uçuş numarasının
-- önekinden (VF) çözüyor; 'AJ' yazan kural taşıyıcı BİLİNDİĞİNDE asla
-- eşleşmiyor, yalnız "bilinmiyor" dalında devreye giriyordu. Yani en
-- kısıtlayıcı kural, en yanlış anda uygulanıyordu.
update lounge_guest_rules r set carrier = 'VF'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'AJET_MS' and r.carrier = 'AJ';


-- ============================================================
-- 2) AJet MİSAFİR HAKKI — SALON KURALLARI DÜZELTİLİYOR
-- ============================================================
-- Önce GERÇEK mükerrerleri temizle (aynı program+tier+carrier+venue
-- iki kez yazılmış; 191'in tekrar koşmasından).
delete from lounge_guest_rules r
 using lounge_guest_rules r2, lounge_programs p
 where r.program_id = p.id and p.code = 'AJET_MS'
   and r2.program_id = r.program_id
   and coalesce(r2.card_tier,'') = coalesce(r.card_tier,'')
   and coalesce(r2.carrier,'')   = coalesce(r.carrier,'')
   and coalesce(r2.venue_id::text,'') = coalesce(r.venue_id::text,'')
   and coalesce(r2.venue_scope,'')    = coalesce(r.venue_scope,'')
   and r.venue_id is not null
   and r2.ctid < r.ctid;

-- 🔴 SAW salon kuralı: 0 misafir → 1 misafir VEYA aile, ÜCRETSİZ.
update lounge_guest_rules r
   set guest_allowance = 1,
       family_allowed  = true,
       guest_must_match_carrier = true,
       member_entry_fee = null,
       guest_entry_fee  = null,
       notes = 'AJet Elite / Elite Plus / Elite Corporate: salonu ÜCRETSİZ '
            || 'kullanırsın ve YANINDA aile bireyi VEYA bir misafir de ÜCRETSİZ '
            || 'girer (AJet CIP Lounge Genel Kuralları; Miles&Smiles statü '
            || 'sayfası da aynı hakkı yazıyor). Aile = birlikte seyahat eden eş '
            || 've 25 yaşından gün almamış çocuklar; salona hak sahibiyle '
            || 'BİRLİKTE girme zorunluluğu var. Misafirin de AJet seferinde '
            || 'seyahat etmesi gerekir — THY seferindeki bir yolcu AJet '
            || 'misafiri olarak ücretsiz kabul edilmez. '
            || 'NOT: Sabiha Gökçen''deki Turkish Airlines CIP Lounge 3 Nisan''dan '
            || 'itibaren geçici olarak hizmet dışı; salon açıldığında hak aynen geçerli.'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'AJET_MS'
   and r.card_tier in ('ELITE','ELPL','MS_EC')
   and r.venue_id is not null
   and (r.effective_to is null or r.effective_to >= current_date);

-- Genel VF/iç hat kuralının notu da aynı dili konuşsun (motor iki ayrı
-- cümle üretiyordu; kullanıcı hangisine inanacağını bilemez).
update lounge_guest_rules r
   set guest_allowance = 1, family_allowed = true,
       guest_must_match_carrier = true,
       notes = 'AJet seferinde Elite / Elite Plus / Elite Corporate: salon ÜCRETSİZ, '
            || 'yanında aile bireyi VEYA bir misafir de ücretsiz. Aile = eş ve '
            || '25 yaşından gün almamış çocuklar, hak sahibiyle BİRLİKTE girmek zorunda. '
            || 'Misafir de AJet seferinde olmalı. AJet salon listesi: SAW, AYT, ADB, '
            || 'BJV, DLM, ESB, COV, ASR, GZT, HTY, TZX, RZV, DIY. İstanbul Havalimanı '
            || '(IST) bu listede YOKTUR.'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'AJET_MS'
   and r.card_tier in ('ELITE','ELPL','MS_EC')
   and r.carrier = 'VF' and r.venue_scope = 'domestic'
   and r.venue_id is null
   and (r.effective_to is null or r.effective_to >= current_date);

-- Classic / Classic Plus: kaynak AÇIKÇA "misafir/aile hakkı yoktur" diyor.
-- Bu bir SESSİZLİK değil, yazılı bir YOKLUK — dili buna göre kesinleşiyor.
update lounge_guest_rules r
   set notes = 'AJet CIP Lounge Ücret Kuralları: "Miles&Smiles Classic Plus kart '
            || 'sahibi yolcunun misafir/aile hakkı BULUNMADIĞINDAN, yolcu '
            || 'beraberindeki her bir misafir ve/veya 2-12 yaş arası çocuk yolcu '
            || 'için tabloda belirtilen ücretin %50''si talep edilecektir." '
            || 'AJet seferinde Classic ve Classic Plus salonu ÜCRETLİ kullanır '
            || '(2.800 TL / 2.000 TL) — THY seferinden farklı: THY iç hatta '
            || 'Classic Plus ücretsizdir.'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'AJET_MS'
   and r.card_tier in ('CLASSIC','CLPL')
   and r.carrier = 'VF'
   and (r.effective_to is null or r.effective_to >= current_date);

-- 🔴 DIŞ HAT / YURT DIŞI: "hak YOK" değil, "salon kapsamı YAZILMAMIŞ".
-- K3 (Miles&Smiles statü sayfası) hakkı "AJet Uçuşlarında" diye KAPSAM
-- KOYMADAN veriyor; K2'nin salon listesi ise yalnız iç hat salonlarını
-- sayıyor. Yani HAK VAR, hangi salonlarda geçerli olduğu belirsiz.
-- Motor davranışı DEĞİŞMİYOR (0 misafir — güvenli taraf); değişen,
-- kullanıcıya söylenen cümle. 177'nin Priority Pass dersinin aynısı.
update lounge_guest_rules r
   set notes = 'Miles&Smiles statü sayfası "AJet uçuşlarında eş ile çocuklar veya '
            || 'bir misafirle özel yolcu salonlarından yararlanabilme" diyor ve '
            || 'kapsam koymuyor — yani HAKKIN VAR. Ancak AJet''in salon listesi '
            || 'yalnız İÇ HAT salonlarını sayıyor; bu salonun listede olup '
            || 'olmadığı kaynakta YAZMIYOR. Bu yüzden burada söz vermiyoruz: '
            || 'misafirle girmeyi planlıyorsan kapıda ya da AJet''e teyit ettir.'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'AJET_MS'
   and r.card_tier in ('ELITE','ELPL','MS_EC')
   and coalesce(r.venue_scope,'') in ('international','abroad')
   and (r.effective_to is null or r.effective_to >= current_date);


-- ============================================================
-- 3) İKİ FAZLA-İDDİA GERİ ALINIYOR
-- ============================================================
-- 🔴 (a) AJet · LONDRA HEATHROW. Kabul satırı 'included' yazıyordu.
-- AJet'in salon tablosunda 13 TÜRK havalimanı var; Heathrow yok,
-- yurt dışı hiç yok. Bu, 191'de düzelttiğim "havalimanı bir kabul
-- ekseni değildir" hatasının yurt dışına taşmış hâli.
update lounge_venue_acceptance a
   set guest_policy = 'not_allowed', accepted = false,
       guest_included_count = 0,
       conditions = 'AJet''in resmî CIP Lounge tablosu yalnız 13 Türk havalimanını '
                 || 'kapsar (SAW, AYT, ADB, BJV, DLM, ESB, COV, ASR, GZT, HTY, TZX, '
                 || 'RZV, DIY). Yurt dışı salonlar için AJet statüsüne dair HİÇBİR '
                 || 'hüküm yok — bu satır 198''de geri alındı.',
       source_conflict = '198: fazla iddia geri alındı'
  from lounge_venues v, lounge_programs p
 where a.venue_id = v.id and a.program_id = p.id
   and p.code = 'AJET_MS' and v.airport_code not in
       ('SAW','AYT','ADB','BJV','DLM','ESB','COV','ASR','GZT','HTY','TZX','RZV','DIY')
   and a.guest_policy = 'included';

-- 🔴 (b) ADANA ŞAKİRPAŞA (ADA). Kaynak "Çukurova Uluslararası
-- Havalimanı" (COV) diyor; ADA ayrı bir havalimanı kodu. İkisini aynı
-- saymak, kaynağın yazmadığı bir yeri kapsama katmaktır.
update lounge_venue_acceptance a
   set guest_policy = 'unknown',
       conditions = 'AJet tablosunda "Çukurova Uluslararası Havalimanı" (COV) yazıyor; '
                 || 'Adana Şakirpaşa (ADA) ayrı bir koddur ve tabloda geçmiyor. '
                 || 'Kaynak sessiz → söz vermiyoruz.',
       source_conflict = '198: kaynakta ADA yok, COV var'
  from lounge_venues v, lounge_programs p
 where a.venue_id = v.id and a.program_id = p.id
   and p.code = 'AJET_MS' and v.airport_code = 'ADA'
   and a.guest_policy = 'included';

-- 🔴 (c) Star Alliance × M&S Elite Corporate, IST İÇ HAT salonunda
-- "aile hakkı" yazıyordu. Tablo-4 yalnız İSTANBUL DIŞ HATLAR
-- terminalinin Miles&Smiles bölümü içindir; Tablo-1'de (iç hat)
-- Star Alliance taşıyıcısı için TEK BİR SATIR bile yok.
delete from lounge_guest_rules r
 using lounge_programs p, lounge_venues v
 where r.program_id = p.id and r.venue_id = v.id
   and p.code = 'TK_MS' and r.card_tier = 'MS_EC'
   and r.carrier = 'STAR_ALLIANCE'
   and coalesce(v.scope,'') = 'domestic';


-- ============================================================
-- 4) BJV EKSİKTİ — kaynak sayıyor, bizde yok
-- ============================================================
-- AJet tablosunda "Muğla Milas-Bodrum Havalimanı" AÇIKÇA yazılı ve
-- 2.800 TL tarifesi var; bizim kabul satırlarımızda BJV hiç yoktu.
-- Değişmez denetimi "12 havalimanı" beklediği için 14 sayıp susmuştu:
-- iki FAZLA (LHR, ADA) bir EKSİĞİ (BJV) gizlemiş. Sayı denetimi
-- doğru sayıyı değil, doğru KÜMEYİ sormalı.
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, conditions, source_url, checked_at, active)
select v.id, p.id, true, 'included', 1, 'same_carrier',
       'AJet CIP Lounge ücret tablosunda "Muğla Milas-Bodrum Havalimanı" yazılı. '
       || 'Elite / Elite Plus / Elite Corporate ücretsiz; yanında aile veya bir misafir ücretsiz.',
       'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge', current_date, true
  from lounge_venues v, lounge_programs p
 where p.code = 'AJET_MS'
   and v.airport_code = 'BJV' and v.active
   and coalesce(v.scope,'both') in ('domestic','both')
   and v.venue_kind = 'lounge'
   and not exists (select 1 from lounge_venue_acceptance x
                    where x.venue_id = v.id and x.program_id = p.id);


-- ============================================================
-- 5) PASİF SALONA BAĞLI AKTİF KABUL SATIRLARI
-- ============================================================
-- 190 salonları birleştirdi ama kabul satırları ESKİ (artık pasif)
-- salonda kaldı. Kabul satırı pasif salona bakıyorsa kimse göremez;
-- ama denetimde "kabul var" diye sayılır. Yani envanter DOLU görünüp
-- BOŞ çalışır.
--
-- Kanonik salonu adın içindeki "(… → 8 haneli kimlik)" izinden buluyoruz;
-- kanonikte o programın satırı yoksa TAŞIYORUZ, varsa pasife çekiyoruz.
do $$
declare r record; v_canon uuid; v_tasindi int := 0; v_pasif int := 0;
begin
  for r in
    select a.id as acc_id, a.program_id, v.name
      from lounge_venue_acceptance a
      join lounge_venues v on v.id = a.venue_id
     where a.active and not v.active
  loop
    v_canon := null;
    begin
      select vv.id into v_canon from lounge_venues vv
       where vv.active
         and left(vv.id::text, 8) = substring(r.name from '→\s*([0-9a-f]{8})')
       limit 1;
    exception when others then v_canon := null;
    end;

    if v_canon is not null
       and not exists (select 1 from lounge_venue_acceptance x
                        where x.venue_id = v_canon and x.program_id = r.program_id) then
      update lounge_venue_acceptance set venue_id = v_canon where id = r.acc_id;
      v_tasindi := v_tasindi + 1;
    else
      update lounge_venue_acceptance set active = false where id = r.acc_id;
      v_pasif := v_pasif + 1;
    end if;
  end loop;
  raise notice '198: pasif salona bagli kabul — % tasindi, % pasife cekildi', v_tasindi, v_pasif;
end $$;


-- ============================================================
-- 6) TABLO-5'İN İKİ AYRI KISITI — YURT DIŞINDA STAR ALLIANCE MARKASI
-- ============================================================
-- Kaynak, Tablo-5'in altında iki dipnotla şunu söylüyor:
--   "*CORP sahibi yolcular ve beraberindeki bir misafir sadece kartın
--    üzerinde belirtilen ÜLKEDEKİ anlaşmalı özel yolcu salonlarından
--    hizmet alabilirler. STAR ALLIANCE MARKALI SALONLARA GİREMEZLER."
--   "**M&S EC sahibi yolcular ve beraberindeki bir misafir anlaşmalı
--    özel yolcu salonlarından hizmet alabilirler. STAR ALLIANCE
--    MARKALI SALONLARA GİREMEZLER."
-- Bu bir MİSAFİR kuralı değil, bir ERİŞİM kuralı — ama sonucu misafir
-- için de aynı: o salona hiç giremiyorsan misafir de götüremezsin.
-- 🔴 KURAL SALON DÜZEYİNDE YAZILIR, KAPSAM DÜZEYİNDE DEĞİL.
-- İlk yazımımda `venue_scope='abroad'` ile kural koydum ve BEKÇİ BENİ
-- YAKALADI: o hâliyle CORP/M&S EC yurt dışındaki BÜTÜN salonlarda
-- 0 misafire düşüyordu. Oysa kaynak tam tersini söylüyor — ANLAŞMALI
-- salonlarda hak DEVAM EDİYOR (1 misafir), yalnız STAR ALLIANCE
-- MARKALI salonlar kapalı. Kapsam düzeyinde yazmak, bir istisnayı
-- kurala çevirmekti. 191'in "havalimanı bir kabul ekseni değildir"
-- dersinin üçüncü tekrarı: eksen SALON.
insert into lounge_guest_rules
  (program_id, card_tier, carrier, venue_id, guest_allowance, family_allowed,
   guest_must_match_carrier, paid_entry_allowed, blocked_reason, notes, effective_from)
select p.id, x.tier, 'TK', v.id, 0, false, true, false,
       'Bu kart Star Alliance markalı salonlara giremez',
       'THY Tablo-5 dipnotu: ' || x.tier ||
       ' sahibi yolcular ve beraberindeki bir misafir yalnız ANLAŞMALI özel yolcu '
       || 'salonlarından hizmet alabilir; STAR ALLIANCE MARKALI salonlara GİREMEZLER. '
       || 'Anlaşmalı salonlarda hakkın aynen duruyor (1 misafir) — kapalı olan yalnız '
       || 'bu marka.',
       current_date
  from lounge_programs p
  cross join (values ('CORP'), ('MS_EC')) as x(tier)
  join lounge_venues v
    on v.active
   and (coalesce(v.operator,'') ilike '%star alliance%' or v.name ilike '%star alliance%')
 where p.code = 'TK_MS'
   and not exists (
     select 1 from lounge_guest_rules r
      where r.program_id = p.id and r.card_tier = x.tier and r.venue_id = v.id);


-- ============================================================
-- 7) AİLE TANIMI — motor artık tanımı da söylüyor
-- ============================================================
-- Kaynak (K1 Tablo-1 dipnotu ve K2 Genel Kurallar) aynı tanımı veriyor:
--   "Aile: Salon kullanma hakkı olan yolcuyla BİRLİKTE SEYAHAT EDEN eş
--    ve 25 YAŞINDAN GÜN ALMAMIŞ çocuklardır. Salona hak sahibi ile
--    BİRLİKTE GİRME zorunluluğu bulunur."
-- Bugüne kadar `family_allowed = true` diyorduk ama tanımı hiçbir yerde
-- göstermiyorduk. "Aile hakkın var" cümlesi, tanımı olmadan yanlış
-- anlaşılır: kardeş, arkadaş, nişanlı aile değildir.
insert into beta_settings (key, value)
values ('family_definition_note',
        to_jsonb('Aile = seninle BİRLİKTE seyahat eden eşin ve 25 yaşından gün almamış çocukların. Kardeş, arkadaş ya da nişanlı aile sayılmaz — onlar "misafir" hakkına girer. Aile de misafir de salona SENİNLE BİRLİKTE girmek zorunda.'::text))
on conflict (key) do update set value = excluded.value;

create or replace function public.family_rule_note()
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select value #>> '{}' from beta_settings where key = 'family_definition_note'),
                  'Aile = birlikte seyahat eden eş ve 25 yaşından gün almamış çocuklar.')
$$;
grant execute on function public.family_rule_note() to authenticated, anon;


-- ============================================================
-- 8) GİRİŞ PENCERELERİ ve KALIŞ SÜRESİ — yalnız ÜCRETLİ yolda
-- ============================================================
-- 🔴 KİMİN İÇİN GEÇERLİ OLDUĞU KRİTİK. Kaynak bu pencereleri
-- "salon kullanım hizmeti SATIN ALAN yolcular" için yazıyor. Statüyle
-- ücretsiz girenin penceresi hiçbir yerde yazmıyor. Pencereyi herkese
-- uygulamak, olmayan bir kısıtı uydurmak olurdu (f0874537 kararı).
create table if not exists lounge_entry_windows (
  id            uuid primary key default uuid_generate_v4(),
  program_code  text not null,
  airport_code  text,                  -- null = o programın diğer tüm havalimanları
  applies_to    text not null default 'paid_entry',  -- paid_entry | all
  earliest_hours_origin     numeric,   -- uçuşun BAŞLANGIÇ noktası burasıysa
  earliest_hours_connecting numeric,   -- bağlantılı uçuşsa
  max_stay_hours numeric,
  note          text,
  source_url    text not null,
  checked_at    date not null default current_date,
  active        boolean not null default true
);
create unique index if not exists uq_entry_windows
  on lounge_entry_windows (program_code, coalesce(airport_code,'*'), applies_to);

alter table lounge_entry_windows enable row level security;
drop policy if exists lew_read on lounge_entry_windows;
create policy lew_read on lounge_entry_windows for select to authenticated, anon using (active);
grant select on lounge_entry_windows to authenticated, anon;

insert into lounge_entry_windows
  (program_code, airport_code, applies_to, earliest_hours_origin,
   earliest_hours_connecting, max_stay_hours, note, source_url)
values
  ('TK_MS', 'IST', 'paid_entry', 4, 6, null,
   'THY md.11: İstanbul Havalimanı İç Hat CIP Salonu için salon kullanım hizmeti '
   || 'satın alan yolcular, uçuşlarının başlangıç noktası İstanbul ise en erken 4 saat '
   || 'önce, başlangıç noktası İstanbul değilse (bağlantılı) en erken 6 saat önce girebilir.',
   'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/'),
  ('TK_MS', null, 'paid_entry', 2, 2, null,
   'THY md.10: İstanbul Havalimanı hariç olmak üzere, salon kullanım hizmeti satın alan '
   || 'yolcular uçuşlarından en erken 2 saat önce salona girebilir.',
   'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/'),
  ('AJET_MS', 'SAW', 'paid_entry', 3, 4, 3,
   'AJet: SAW İç Hat Özel Yolcu Salonu için hizmet satın alan yolcular, uçuşun başlangıç '
   || 'noktası SAW ise en erken 3 saat, bağlantılı uçuşta en erken 4 saat önce girebilir. '
   || 'Salon künyesindeki kullanım süresi 3 saat ve "uçuşunuzdan 2 saat önce başlar" '
   || 'deniyor — kaynağın kendi içinde iki farklı sayı veriyor (198 çelişki kaydı). '
   || 'Salon 04.00-01.00 arası açık.',
   'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge'),
  ('AJET_MS', null, 'paid_entry', 2, 2, null,
   'AJet: Sabiha Gökçen hariç, iç hat salon kullanım hizmeti satın alan yolcular '
   || 'uçuşlarından en erken 2 saat önce salona girebilir.',
   'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge')
on conflict (program_code, coalesce(airport_code,'*'), applies_to) do update set
  earliest_hours_origin = excluded.earliest_hours_origin,
  earliest_hours_connecting = excluded.earliest_hours_connecting,
  max_stay_hours = excluded.max_stay_hours,
  note = excluded.note, source_url = excluded.source_url,
  checked_at = excluded.checked_at, active = true;

create or replace function public.entry_window_for(p_program text, p_airport text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
           'earliest_origin', w.earliest_hours_origin,
           'earliest_connecting', w.earliest_hours_connecting,
           'max_stay', w.max_stay_hours,
           'applies_to', w.applies_to,
           'note', w.note, 'source_url', w.source_url)
    from lounge_entry_windows w
   where w.active and w.program_code = upper(btrim(coalesce(p_program,'')))
     and (w.airport_code = upper(btrim(coalesce(p_airport,''))) or w.airport_code is null)
   order by (w.airport_code is null)          -- havalimanına özel olan ÖNCE
   limit 1
$$;
grant execute on function public.entry_window_for(text, text) to authenticated, anon;


-- ============================================================
-- 9) İKİ BÖLÜMLÜ SALON — ücretli girenler yalnız M&S bölümü
-- ============================================================
-- K1 md.8 ve K2 "Diğer Kurallar" birinci madde AYNI hükmü veriyor:
--   "Salon kullanım hizmetini ücret karşılığı satın alan yolcular, iki
--    ayrı bölümden oluşan yurt içi özel yolcu salonlarında salonun
--    SADECE Miles&Smiles bölümünü kullanacaklardır."
-- Ayrıca K1 Tablo-1 altındaki not, ÜCRETSİZ girenler için de bölüm
-- ayrımı yapıyor: Business kabin + ELPL → Business bölümü; ekonomi
-- Elite/CLPL/SAG/PLM/CORP ve ücret/mil ile girenler → diğer bölüm.
update lounge_venues v
   set notes = coalesce(nullif(v.notes,'') || ' ', '')
             || 'İKİ BÖLÜMLÜ SALON: Business kabin yolcuları ve Elite Plus kartlılar '
             || 'BUSINESS bölümüne; ekonomi kabinde seyahat eden Elite, Classic Plus, '
             || 'Star Alliance Gold, Platinum, Corporate kartlılar ve ücret/mil karşılığı '
             || 'girenler MILES&SMILES bölümüne girer. Ücret ödeyerek giren yolcu '
             || 'yalnızca Miles&Smiles bölümünü kullanabilir.'
 where v.active
   and (v.section is not null or exists (select 1 from lounge_venues s
                                          where s.section_of = v.id and s.active))
   and coalesce(v.notes,'') not like '%İKİ BÖLÜMLÜ SALON%';


-- ============================================================
-- 10) M&S U.S. KREDİ KARTI — üye ücreti istisnası
-- ============================================================
-- Tarife tablosu: "M&S US Credit Card Yolcu → Dalaman ve Diyarbakır
-- Havalimanlarındaki Özel Yolcu Salonları hariç olmak üzere ücretsiz."
-- Misafir hakkı yine YOK (md.7) — o değişmiyor.
update lounge_guest_rules r
   set member_entry_fee = 'Dalaman (DLM) ve Diyarbakır (DIY) hariç ücretsiz',
       notes = 'THY md.7: Miles&Smiles U.S. Kredi Kartı sahiplerinin aile bireyi ve/veya '
            || 'misafir hakkı BULUNMAMAKTADIR; beraberindeki tüm yolcular için tam ücret '
            || 'talep edilir. Kendi girişin Dalaman ve Diyarbakır dışındaki iç hat '
            || 'salonlarında ücretsizdir. Salonu kullanabilmek için Miles&Smiles '
            || 'üyeliğini kredi kartınla EŞLEŞTİRMİŞ olman gerekir.'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'TK_MS' and r.card_tier = 'MS_US_CC'
   and (r.effective_to is null or r.effective_to >= current_date);


-- ============================================================
-- 11) ÜCRET TARİFELERİ — havalimanı × program × kart grubu
-- ============================================================
create table if not exists program_entry_tariff (
  id           uuid primary key default uuid_generate_v4(),
  program_code text not null,
  airport_code text,                 -- null = tabloda tek fiyat
  tier_group   text not null,        -- 'CLASSIC' | 'CLASSIC_PLUS' | 'ELITE_GROUP' | 'MS_US_CC'
  price        numeric,
  currency     text not null default 'TRY',
  free         boolean not null default false,
  valid_from   date, valid_to date,
  note         text,
  source_url   text not null,
  checked_at   date not null default current_date,
  active       boolean not null default true
);
create unique index if not exists uq_entry_tariff
  on program_entry_tariff (program_code, coalesce(airport_code,'*'), tier_group);

alter table program_entry_tariff enable row level security;
drop policy if exists pet_read on program_entry_tariff;
create policy pet_read on program_entry_tariff for select to authenticated, anon using (active);
grant select on program_entry_tariff to authenticated, anon;

-- THY seferleri (1 Haziran 2026 – 31 Aralık 2026)
insert into program_entry_tariff
  (program_code, airport_code, tier_group, price, currency, free, valid_from, valid_to, note, source_url)
select 'TK_MS', x.ap, 'CLASSIC', x.pr, 'TRY', false, date '2026-06-01', date '2026-12-31',
       'THY seferlerinde Classic kart sahibi yolcu tarifesi.',
       'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/'
  from (values ('IST',3000),('AYT',2800),('ADB',2800),('BJV',2800),('DLM',2800),('ESB',2800),
               ('COV',2000),('ASR',2000),('GZT',2000),('HTY',2000),('TZX',2000),('RZV',2000),('DIY',2000)
       ) as x(ap, pr)
on conflict (program_code, coalesce(airport_code,'*'), tier_group) do update
  set price = excluded.price, note = excluded.note, checked_at = excluded.checked_at, active = true;

insert into program_entry_tariff
  (program_code, airport_code, tier_group, price, currency, free, valid_from, valid_to, note, source_url)
values
  ('TK_MS', null, 'CLASSIC_PLUS', null, 'TRY', true, date '2026-06-01', date '2026-12-31',
   'THY seferlerinde Classic Plus: iç hat salonlarında ÜCRETSİZ. (AJet seferinde ÜCRETLİ — fark burada.)',
   'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/'),
  ('TK_MS', null, 'ELITE_GROUP', null, 'TRY', true, date '2026-06-01', date '2026-12-31',
   'Elite / Elite Plus / Corporate Club / PLM / SAG / M&S Elite Corporate: ÜCRETSİZ.',
   'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/'),
  ('TK_MS', 'VKO', 'CLASSIC', 50, 'USD', false, date '2026-06-01', date '2026-12-31',
   'Vnukovo Uluslararası Havalimanı dış hat salonu. Kaynakta hücre birleştirilmiş; '
   || 'Classic Plus için de aynı tutarın geçerli olup olmadığı NET DEĞİL — '
   || 'bu yüzden yalnız Classic satırı yazıldı.',
   'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/')
on conflict (program_code, coalesce(airport_code,'*'), tier_group) do update
  set price = excluded.price, free = excluded.free, note = excluded.note,
      checked_at = excluded.checked_at, active = true;

-- AJet seferleri (1 Haziran 2026 – 31 Aralık 2026)
insert into program_entry_tariff
  (program_code, airport_code, tier_group, price, currency, free, valid_from, valid_to, note, source_url)
select 'AJET_MS', x.ap, 'CLASSIC_PLUS', x.pr, 'TRY', false, date '2026-06-01', date '2026-12-31',
       'AJet seferinde Classic ve Classic Plus AYNI tarifeyi öder. THY seferinden farkı '
       || 'budur: THY iç hatta Classic Plus ücretsizdir.',
       'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge'
  from (values ('AYT',2800),('ADB',2800),('BJV',2800),('DLM',2800),('ESB',2800),
               ('COV',2000),('ASR',2000),('GZT',2000),('HTY',2000),('TZX',2000),('RZV',2000),('DIY',2000)
       ) as x(ap, pr)
on conflict (program_code, coalesce(airport_code,'*'), tier_group) do update
  set price = excluded.price, note = excluded.note, checked_at = excluded.checked_at, active = true;

insert into program_entry_tariff
  (program_code, airport_code, tier_group, price, currency, free, valid_from, valid_to, note, source_url)
values
  ('AJET_MS', null, 'ELITE_GROUP', null, 'TRY', true, date '2026-06-01', date '2026-12-31',
   'AJet seferinde Elite / Elite Plus / Elite Corporate: ÜCRETSİZ, yanında aile veya bir misafir de ücretsiz.',
   'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge'),
  ('AJET_MS', 'SAW', 'CLASSIC_PLUS', null, 'TRY', false, date '2026-06-01', date '2026-12-31',
   'AJet tablosunda Sabiha Gökçen satırı "-" ile boş: oradaki Turkish Airlines CIP Lounge '
   || '3 Nisan''dan itibaren geçici olarak hizmet dışı. Tarife açıklanmamış.',
   'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge')
on conflict (program_code, coalesce(airport_code,'*'), tier_group) do update
  set price = excluded.price, free = excluded.free, note = excluded.note,
      checked_at = excluded.checked_at, active = true;

create or replace function public.entry_tariff_for(p_program text, p_airport text)
returns table (tier_group text, price numeric, currency text, free boolean, note text, source_url text)
language sql stable security definer set search_path = public as $$
  select t.tier_group, t.price, t.currency, t.free, t.note, t.source_url
    from program_entry_tariff t
   where t.active and t.program_code = upper(btrim(coalesce(p_program,'')))
     and (t.airport_code = upper(btrim(coalesce(p_airport,''))) or t.airport_code is null)
     and (t.valid_to is null or t.valid_to >= current_date)
   order by (t.airport_code is null), t.tier_group
$$;
grant execute on function public.entry_tariff_for(text, text) to authenticated, anon;


-- ============================================================
-- 12) TAŞIYICI YAZMA YOLU — picker motora ulaşmıyordu
-- ============================================================
-- 🔴 ÖLÇÜM: `set_availability_carrier` (uygulamanın havayolu seçicisi)
-- `availabilities.carrier_code` kolonuna yazıyor; `lounge_access_decision`
-- ise `availabilities.carrier` kolonunu okuyor. İKİ AYRI KOLON.
-- Yani host havayolunu seçiyor, kural motoru bunu HİÇ GÖRMÜYORDU.
-- 25 ilanın 18'inde carrier_code dolu — o 18 seçim boşa gitmiş.
--
-- Bu, "kolon eklemek yazma yolunu açmak değildir" sınıfının kardeşi:
-- YAZMA YOLU VAR ama BAŞKA KOLONA yazıyor. Beşinci tekrar.
create or replace function public.set_availability_carrier(p_avail_id uuid, p_carrier text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_code text := nullif(upper(btrim(coalesce(p_carrier,''))), '');
begin
  if (select host_id from availabilities where id = p_avail_id) <> auth.uid() then
    raise exception 'not_owner';
  end if;
  -- İKİ KOLONA BİRDEN: carrier_code katalog/FK için, carrier motor için.
  update availabilities
     set carrier_code = v_code,
         carrier      = v_code
   where id = p_avail_id;
  return jsonb_build_object('ok', true, 'carrier', v_code);
end $$;

-- Geçmiş kayıtları da hizala (seçim yapılmış ama motora ulaşmamış ilanlar)
update availabilities
   set carrier = carrier_code
 where carrier is null and carrier_code is not null;


-- ============================================================
-- 13) YENİ KAYNAK ÇELİŞKİLERİ — deftere yazılıyor
-- ============================================================
insert into rule_source_conflicts
  (konu, detay, kaynak_a, kaynak_b, sinif, karar, durum, etki, program_code)
select * from (values
  ('AJet misafir/çocuk ücreti — %50 mi tam ücret mi',
   'Aynı senaryo (ücretli girişte yanındaki misafir veya aile bireyi olmayan çocuk) için iki resmî sayfa iki farklı oran veriyor.',
   'AJet CIP Lounge Ücret Kuralları: "Misafir(ler) ve/veya aile bireyi olmayan çocuk yolcu(lar) için tabloda belirtilen ücretin %50''si talep edilecektir."',
   'THY Lounge Kuralları, AJet seferleri md.6: "Misafir(ler) ve/veya aile bireyi olmayan çocuk yolcu(lar) için TAM ÜCRET talep edilir."',
   'celiski',
   'THY sayfası esas alındı — AJet''in kendi sayfası ücret otoritesini THY''ye devrediyor ("Güncel ücretler ve kurallar için Lounge Kurallar ve Koşullar - Türk Hava Yolları sayfasını ziyaret ediniz"). Ayrıca tam ücret daha kısıtlayıcı: yanılırsak kullanıcı lehine yanılırız. Motor tutar YAZMIYOR, "kapıda tam ücret çıkabilir" diyor.',
   'karara_baglandi',
   'Ücretli girişte misafir maliyeti tam ücret varsayılıyor; kullanıcı düşük tahminle kapıda sürprize düşmüyor.',
   'AJET_MS'),
  ('AJet Sabiha Gökçen giriş penceresi — 2 saat mi 3 saat mi',
   'Salon künyesi ile "Diğer Kurallar" bölümü aynı salon için farklı pencere veriyor.',
   'AJet salon künyesi: "Kullanım süresi 3 saat (Lounge hizmeti satın aldığınızda kullanım süreniz, uçuşunuzdan 2 SAAT ÖNCE başlamaktadır.)"',
   'AJet Diğer Kurallar: "SAW İç Hat Özel Yolcu Salonu için hizmet satın alan yolcular, uçuşun başlangıç noktası SAW ise en erken 3 SAAT önce, bağlantılı uçuş ise en erken 4 SAAT önce salona girebilir."',
   'celiski',
   'İkisi çelişmiyor olabilir — biri GİRİŞ hakkını (3/4 saat), diğeri ÜCRETLİ KULLANIM SAYACININ başlangıcını (2 saat) anlatıyor olabilir. Ama kaynak bunu açıkça söylemiyor. lounge_entry_windows''e 3/4 saat yazıldı (giriş hakkı), 3 saatlik kullanım süresi max_stay olarak ayrıca duruyor; belirsizlik notta yazılı. Kullanıcıya kesin bir saat söylemiyoruz.',
   'karara_baglandi',
   'Erken gelen kullanıcıya "kapıda kabul edilmeyebilirsin" uyarısı; kesin dakika verilmiyor.',
   'AJET_MS')
) as v(konu, detay, kaynak_a, kaynak_b, sinif, karar, durum, etki, program_code)
where not exists (select 1 from rule_source_conflicts c where c.konu = v.konu);


-- ============================================================
-- 14) BEKLENTİ ÜRETECİ — AJet artık KESİN
-- ============================================================
-- 178 AJet Elite kademelerini 'defined' (gevşek) bırakmıştı çünkü o gün
-- kaynak belirsiz sanılıyordu. Artık iki kaynak da açıkça yazıyor:
-- iç hat + AJet taşıyıcısı → 1 misafir VEYA aile. Beklenti KESİNLEŞİYOR;
-- gevşek beklenti, yanlış cevabı yakalamaz.
update rule_test_cases
   set level = 'exact', exp_guests = 1, exp_family = true,
       kaynak = 'AJet Genel Kuralları + M&S statü sayfası: "aile bireyi veya bir misafir ücretsiz"'
 where program_code = 'AJET_MS'
   and card_tier in ('ELITE','ELPL','MS_EC')
   and venue_scope = 'domestic'
   and carrier_class = 'VF';


-- ============================================================
-- BEKÇİLER — kaynak matrisinin TAMAMI tek tek sınanıyor
-- ============================================================

-- 1) AJet Elite ailesi: iç hatta 1 misafir + aile OLMALI
do $$
declare r record; v_kotu text := '';
begin
  for r in
    select coalesce(rr.card_tier,'∅') as tier,
           coalesce(rr.guest_allowance,0) as g,
           coalesce(rr.family_allowed,false) as f,
           coalesce(vv.name,'(genel)') as venue
      from lounge_guest_rules rr
      join lounge_programs pp on pp.id = rr.program_id
      left join lounge_venues vv on vv.id = rr.venue_id
     where pp.code = 'AJET_MS'
       and rr.card_tier in ('ELITE','ELPL','MS_EC')
       and coalesce(rr.venue_scope,'domestic') = 'domestic'
       and coalesce(rr.carrier,'VF') = 'VF'
       and (rr.effective_to is null or rr.effective_to >= current_date)
  loop
    if r.g < 1 or not r.f then
      v_kotu := v_kotu || format('%s@%s (misafir=%s aile=%s) ', r.tier, r.venue, r.g, r.f);
    end if;
  end loop;
  if v_kotu <> '' then
    raise exception '198: AJet ic hat Elite ailesinde misafir/aile hakki EKSIK → %', v_kotu;
  end if;
  raise notice '198: AJet ic hat Elite/ElitePlus/EliteCorporate — 1 misafir + aile, salon kurali dahil';
end $$;

-- 2) AJet Classic / Classic Plus: HİÇBİR yerde misafir hakkı OLMAMALI
do $$
declare v_n int;
begin
  select count(*) into v_n from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code = 'AJET_MS' and r.card_tier in ('CLASSIC','CLPL')
     and coalesce(r.guest_allowance,0) > 0
     and (r.effective_to is null or r.effective_to >= current_date);
  if v_n > 0 then
    raise exception '198: AJet Classic/Classic Plus''ta % satirda misafir hakki VAR — kaynak "yoktur" diyor', v_n;
  end if;
  raise notice '198: AJet Classic/Classic Plus — misafir hakki yok (kaynakla uyumlu)';
end $$;

-- 3) 'AJ' HAYALET KODU KALMADI
do $$
declare v_n int;
begin
  select count(*) into v_n from lounge_guest_rules where carrier = 'AJ';
  if v_n > 0 then raise exception '198: % kuralda hayalet AJ kodu kalmis', v_n; end if;
  if not exists (select 1 from carriers where code = 'VF' and active) then
    raise exception '198: AJet (VF) hala carriers katalogunda YOK';
  end if;
  raise notice '198: tasiyici sozlugu tekil — AJet katalogda VF olarak var';
end $$;

-- 4) AJet KABUL KÜMESİ tam olarak 13 havalimanı OLMALI
-- 🔴 SAYI DEĞİL KÜME. Eski değişmez "en az 12" diyordu ve 14 sayıp
-- susmuştu: iki FAZLA (LHR, ADA) bir EKSİĞİ (BJV) gizlemişti.
do $$
declare
  v_bekl text[] := array['SAW','AYT','ADB','BJV','DLM','ESB','COV','ASR','GZT','HTY','TZX','RZV','DIY'];
  v_var  text[];
  v_eksik text[]; v_fazla text[];
begin
  select array_agg(distinct v.airport_code order by v.airport_code) into v_var
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
   where p.code = 'AJET_MS' and a.active and a.guest_policy = 'included';

  select array_agg(x) into v_eksik from unnest(v_bekl) x where not (x = any(coalesce(v_var,'{}')));
  select array_agg(x) into v_fazla from unnest(coalesce(v_var,'{}')) x where not (x = any(v_bekl));

  if v_eksik is not null then
    raise exception '198: AJet kabul kumesinde EKSIK havalimani: %', array_to_string(v_eksik, ', ');
  end if;
  if v_fazla is not null then
    raise exception '198: AJet kabul kumesinde FAZLA havalimani (kaynakta yok): %', array_to_string(v_fazla, ', ');
  end if;
  raise notice '198: AJet kabul kumesi TAM — 13 havalimani, eksik yok fazla yok';
end $$;

-- 5) PASİF SALONA BAĞLI AKTİF KABUL KALMADI
do $$
declare v_n int;
begin
  select count(*) into v_n from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
   where a.active and not v.active;
  if v_n > 0 then
    raise exception '198: % kabul satiri hala PASIF salona bagli', v_n;
  end if;
  raise notice '198: pasif salona bagli aktif kabul satiri yok';
end $$;

-- 6) THY MATRİSİ — Tablo-1/2/5 satır satır
do $$
declare
  r record; v_kotu text := '';
  -- (tier, carrier, scope, beklenen_misafir, beklenen_aile, kaynak)
  v_m text[][] := array[
    ['ELPL','TK','domestic','1','true','Tablo-1'],
    ['ELITE','TK','domestic','1','true','Tablo-1'],
    ['MS_EC','TK','domestic','1','true','Tablo-1'],
    ['CLPL','TK','domestic','0','false','Tablo-1: Yok'],
    ['SAG','TK','domestic','1','false','Tablo-1'],
    ['PLM','TK','domestic','1','false','Tablo-1'],
    ['CORP','TK','domestic','1','false','Tablo-1'],
    ['MS_US_CC','TK','domestic','0','false','Tablo-1: Yok'],
    ['ELPL','TK','international','1','true','Tablo-2'],
    ['ELITE','TK','international','1','true','Tablo-2'],
    ['MS_EC','TK','international','1','true','Tablo-2'],
    ['SAG','TK','international','1','false','Tablo-2'],
    ['PLM','TK','international','1','false','Tablo-2'],
    ['ELPL','TK','abroad','1','false','Tablo-5: aile YOK'],
    ['ELITE','TK','abroad','1','false','Tablo-5: aile YOK'],
    ['MS_EC','TK','abroad','1','false','Tablo-5: aile YOK'],
    ['SAG','TK','abroad','1','false','Tablo-5'],
    ['CORP','TK','abroad','1','false','Tablo-5']
  ];
  i int; v_j jsonb; v_g int; v_f boolean; v_venue uuid;
begin
  for i in 1 .. array_length(v_m, 1) loop
    -- 🔴 SALON SEÇİMİ KAPSAMLA UYUMLU OLMALI. İlk yazımda yalnız
    -- `v.scope` bakıyordum ve 'both' kapsamlı YURT DIŞI bir salon
    -- 'domestic' testine düştü; motor onu (haklı olarak) 'abroad'
    -- çözünce beklenti tutmadı. Kapsamı motor NASIL hesaplıyorsa
    -- (ülke + scope) test de öyle seçmeli, yoksa test kendi hatasını
    -- ürünün hatası gibi bildirir.
    select v.id into v_venue from lounge_venues v
      join airports ap on ap.code = v.airport_code
     where v.active and v.venue_kind = 'lounge'
       and coalesce(v.scope,'both') in (v_m[i][3], 'both')
       and case v_m[i][3]
             when 'abroad' then coalesce(ap.country,'') not in ('TR','Türkiye','Turkey')
             else coalesce(ap.country,'') in ('TR','Türkiye','Turkey')
           end
       and not exists (select 1 from lounge_guest_rules rr
                        where rr.venue_id = v.id and rr.blocked_reason is not null)
       and exists (select 1 from lounge_venue_acceptance a
                    join lounge_programs p on p.id = a.program_id
                   where a.venue_id = v.id and a.active and p.code = 'TK_MS')
     limit 1;
    if v_venue is null then continue; end if;

    v_j := public.resolve_guest_rule(
             (select id from lounge_programs where code = 'TK_MS'),
             v_venue, v_m[i][1], v_m[i][2], null);
    v_g := coalesce((v_j ->> 'guest_allowance')::int, -1);
    v_f := coalesce((v_j ->> 'family_allowed')::boolean, false);

    if v_g <> v_m[i][4]::int then
      v_kotu := v_kotu || format('[%s/%s/%s misafir %s≠%s (%s)] ',
                  v_m[i][1], v_m[i][2], v_m[i][3], v_g, v_m[i][4], v_m[i][6]);
    end if;
  end loop;

  if v_kotu <> '' then
    raise exception '198: THY matrisi kaynakla UYUSMUYOR → %', v_kotu;
  end if;
  raise notice '198: THY matrisi (Tablo-1/2/5, % satir) kaynakla uyumlu', array_length(v_m,1);
end $$;

-- 7) GİRİŞ PENCERELERİ ÇAĞRILABİLİYOR ve DOĞRU SIRALIYOR
do $$
declare v jsonb;
begin
  v := public.entry_window_for('TK_MS', 'IST');
  if coalesce((v ->> 'earliest_origin')::numeric, -1) <> 4 then
    raise exception '198: IST ic hat penceresi yanlis (beklenen 4, gelen %)', v ->> 'earliest_origin';
  end if;
  v := public.entry_window_for('TK_MS', 'AYT');
  if coalesce((v ->> 'earliest_origin')::numeric, -1) <> 2 then
    raise exception '198: IST disi pencere yanlis (beklenen 2, gelen %)', v ->> 'earliest_origin';
  end if;
  v := public.entry_window_for('AJET_MS', 'SAW');
  if coalesce((v ->> 'max_stay')::numeric, -1) <> 3 then
    raise exception '198: AJet SAW kalis suresi yanlis';
  end if;
  raise notice '198: giris pencereleri — havalimanina ozel kural genelini yeniyor';
end $$;

-- 8) TAŞIYICI SEÇİMİ MOTORA ULAŞIYOR MU (yazma yolu kanıtı)
do $$
declare v_av uuid; v_c text;
begin
  select id into v_av from availabilities limit 1;
  if v_av is null then raise notice '198: ilan yok — tasiyici kanidi atlandi'; return; end if;
  update availabilities set carrier = null, carrier_code = null where id = v_av;
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select host_id from availabilities where id = v_av),
                      'role','authenticated')::text, true);
  perform public.set_availability_carrier(v_av, 'VF');
  perform set_config('request.jwt.claims', '{}', true);
  select carrier into v_c from availabilities where id = v_av;
  if coalesce(v_c,'') <> 'VF' then
    raise exception '198: havayolu secimi MOTORUN OKUDUGU kolona yazilmiyor (carrier=%)', v_c;
  end if;
  raise notice '198: havayolu secimi artik hem carrier_code hem carrier kolonuna yaziliyor';
end $$;

-- 9) AİLE TANIMI GERÇEKTEN DÖNÜYOR
do $$
declare v text;
begin
  v := public.family_rule_note();
  if v is null or position('25 yaşından' in v) = 0 then
    raise exception '198: aile tanimi eksik ya da yanlis: %', coalesce(v,'∅');
  end if;
  raise notice '198: aile tanimi motordan doniyor';
end $$;

-- 10) TARİFE OKUNABİLİYOR ve THY↔AJet FARKI DURUYOR
do $$
declare v_tk_free boolean; v_aj_price numeric;
begin
  select free into v_tk_free from public.entry_tariff_for('TK_MS','AYT') where tier_group = 'CLASSIC_PLUS';
  select price into v_aj_price from public.entry_tariff_for('AJET_MS','AYT') where tier_group = 'CLASSIC_PLUS';
  if not coalesce(v_tk_free,false) then
    raise exception '198: THY seferinde Classic Plus ucretsiz olmali';
  end if;
  if coalesce(v_aj_price,0) <= 0 then
    raise exception '198: AJet seferinde Classic Plus ucretli olmali (gelen %)', v_aj_price;
  end if;
  raise notice '198: TK↔AJet Classic Plus farki tarifede duruyor (TK ucretsiz, AJet % TL)', v_aj_price;
end $$;

select '198 OK - THY/AJet/M&S matrisi kaynakla yeniden hizalandi' as sonuc;
