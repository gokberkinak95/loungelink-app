-- ============================================================
-- LoungeLink · 156_official_alignment_and_scope.sql
-- RESMİ KAYNAK HİZALAMASI + İÇ/DIŞ HAT BOYUTU (12 Ağu 2026)
--
-- ⚠️ Uygulamayı ETKİLER (kural çözümleme merkezi güncellenir).
-- KAYNAKLAR (hepsi 12 Ağu 2026'da okundu):
--   turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar
--   turkishairlines.com/tr-tr/ucak-bileti/ucus-deneyimi/yurt-ici-lounge
--   flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge
--   prioritypass.com + dragonpass.com üyelik planı ekran görüntüleri
--
-- ------------------------------------------------------------
-- 🔴 KAYNAKLA KARŞILAŞTIRINCA ÜÇ GERÇEK BOŞLUK ÇIKTI
-- ------------------------------------------------------------
-- 1. CLASSIC PLUS İÇ/DIŞ HATTA FARKLI — BİZDE TEK KURALDI.
--    İç hat sayfası açık: "Elite ve Classic Plus üyesi yolcularımız
--    Miles&Smiles Lounge'dan ÜCRETSİZ yararlanabilirler."
--    Ama Tablo-2 (dış hat) ve Tablo-4 (IST dış hat M&S bölümü) kart
--    listelerinde CLPL HİÇ YOK. Yani dış hatta Classic Plus'ın
--    tanımlı bir salon hakkı yoktur. Bizim tek kuralımız "yalnız
--    kendin girersin" diyordu — dış hatta bu bile fazla iyimserdi.
--    Sessizce iyimser varsaymak bu üründe en tehlikeli davranış.
--
-- 2. YURT DIŞI ANLAŞMALI SALONLARDA AİLE HAKKI YOK (Tablo-5).
--    THY'nin KENDİ yurt dışı salonunda ELPL/Elite/M&S EC "aile veya
--    bir misafir" alır (Tablo-2). Ama yurt dışındaki ANLAŞMALI veya
--    Star Alliance markalı salonda aynı kartlar yalnız "BİR MİSAFİR"
--    alır — aile hakkı düşer. Bizde bu ayrım yoktu; yurt dışına salon
--    eklediğimiz an (Vnukovo aday) aileye "girebilirsin" der ve
--    kapıda geri çevrilirlerdi.
--
-- 3. PEGASUS'UN SOMUT TARİFESİ YOKTU.
--    Kuralımız doğruydu ("herkes kişi başı öder") ama SAYI yoktu.
--    Resmi sayfa net: SAW Plaza Premium iç 49 / dış 63 EUR (KDV
--    dahil, 3 saat, 0-6 yaş ücretsiz) · Primeclass ADB/ESB/BJV
--    27 EUR+KDV (0-2 ücretsiz) · COV Çelebi Platinum iç 1.260 TL /
--    dış 49,5 EUR (0-6 ücretsiz). "Ücretli" demek yetmez — host
--    kapıda ödeyeceği rakamı ilan açmadan önce görmeli.
--
-- DOĞRULANAN VE DEĞİŞMEYENLER (yeniden yazmıyoruz — oku, teyit et,
-- dokunma): 146'nın THY matrisi bugünkü resmi tabloyla birebir
-- (tarife dahil) · 154'ün PP seviyeleri (Standard 89 EUR/yıl, üye
-- ziyareti 30 EUR, misafir 30 EUR · Prestige 459 EUR/yıl sınırsız)
-- ve DP seviyeleri (Classic 96 EUR/yıl 1 ziyaret · Preferential
-- 249 EUR/yıl 8 ziyaret · ek üye VEYA misafir ziyareti 36 EUR)
-- ekran görüntüleriyle birebir · AJet 4 kart kuralı birebir.
-- ============================================================

-- ---- 1) KURALLARA SALON KAPSAMI BOYUTU ----
-- 🔴 NEDEN KOLON, NEDEN venue_id DEĞİL: "dış hattaki TÜM THY
-- salonları" için venue başına satır kopyalamak, salon eklendikçe
-- sessizce eksik kalan kural demektir. Kapsam bir SINIF, tek tek
-- salon değil.
-- Değerler: domestic = Türkiye iç hat · international = Türkiye
-- dış hat terminali · abroad = YURT DIŞI ülkedeki salon.
-- (international ≠ abroad — IST dış hat Türkiye'dedir, Tablo-2/4
-- oraya bakar; Tablo-5 yalnız yurt dışı ülkeye bakar.)
alter table lounge_guest_rules add column if not exists venue_scope text
  check (venue_scope in ('domestic','international','abroad'));
comment on column lounge_guest_rules.venue_scope is
  'Kuralın geçtiği salon sınıfı: domestic (TR iç hat) / international (TR dış hat) / abroad (yurt dışı ülke). NULL = hepsi.';

-- ---- 2) resolve_guest_rule: kapsamı İÇERİDE türet ----
-- 🔴 İMZA BİLEREK AYNI BIRAKILDI. Parametre eklemek yeni bir
-- AŞIRI YÜKLEME yaratır: eski 5 parametreli sürüm ayakta kalır,
-- best_entitlement ve karar fonksiyonları ESKİYİ çağırmaya devam
-- eder ve değişiklik sessizce hiç uygulanmamış olur. Kapsam,
-- p_venue_id'den fonksiyonun İÇİNDE türetilir; hiçbir çağıran
-- değişmez. (create or replace aynı imzada gövde değiştirir —
-- 42P13 riski yok, dönüş tipi aynı.)
create or replace function public.resolve_guest_rule(
  p_program_id uuid,
  p_venue_id   uuid    default null,
  p_tier       text    default null,
  p_carrier    text    default null,
  p_cabin      text    default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r lounge_guest_rules%rowtype; p lounge_programs%rowtype;
        v_alliance text; v_eff text; v_scope text;
begin
  select * into p from lounge_programs where id = p_program_id;
  if not found then return jsonb_build_object('found', false); end if;

  -- Taşıyıcı Star Alliance üyesi mi? (146/Tablo-2)
  select c.alliance into v_alliance from carriers c where c.code = p_carrier;
  v_eff := case
    when p_carrier is null then null
    when p_carrier = 'TK' then 'TK'
    when p_carrier = 'VF' then 'VF'
    when v_alliance = 'star_alliance' then 'STAR_ALLIANCE'
    else p_carrier end;

  -- 🔴 SALON KAPSAMI: yurt dışı ülke HER ŞEYİ ezer (Tablo-5 ayrı
  -- rejim); Türkiye'deyse venue.scope okunur. 'both' ve NULL scope
  -- kapsam eşleşmesine girmez (v_scope NULL kalır) — kural satırı
  -- kapsam istiyorsa eşleşmez, istemiyorsa (NULL) her yerde geçer.
  if p_venue_id is not null then
    select case
             when coalesce(a.country,'') not in ('','TR','Türkiye','Turkiye','Turkey') then 'abroad'
             when v.scope in ('domestic','international') then v.scope
             else null end
      into v_scope
      from lounge_venues v join airports a on a.code = v.airport_code
     where v.id = p_venue_id;
  end if;

  select * into r from lounge_guest_rules x
   where x.program_id = p_program_id
     and (x.venue_id is null or x.venue_id = p_venue_id)
     and (x.venue_scope is null or x.venue_scope = v_scope)
     and (x.card_tier is null or x.card_tier = p_tier)
     and (x.carrier is null or x.carrier = v_eff)
     and (x.cabin_class is null or x.cabin_class = p_cabin)
     and (x.effective_to is null or x.effective_to >= current_date)
   order by
     -- 🔴 coalesce ŞART (144/145 dersi): NULL, DESC'te başa çıkar.
     -- Spesifiklik: somut salon > kart > taşıyıcı > kapsam > kabin.
     coalesce(x.venue_id = p_venue_id, false) desc,
     coalesce(x.card_tier = p_tier, false) desc,
     coalesce(x.carrier = v_eff, false) desc,
     coalesce(x.venue_scope = v_scope, false) desc,
     coalesce(x.cabin_class = p_cabin, false) desc,
     x.created_at desc
   limit 1;

  if not found then
    return jsonb_build_object(
      'found', false, 'program', p.name,
      'guest_allowance', case p.guest_default when 'included' then coalesce(p.guest_included_count,1) else 0 end,
      'family_allowed', false,
      'note', 'Bu kart tipi için özel kural bulunamadı; program varsayılanı uygulandı.');
  end if;

  return jsonb_build_object(
    'found', true,
    'program', p.name,
    'tier', public.card_tier_label(r.card_tier),
    'carrier_scope', r.carrier,
    'venue_scope', r.venue_scope,
    'guest_allowance', coalesce(r.guest_allowance, 0),
    'family_allowed', coalesce(r.family_allowed, false),
    'paid_entry_allowed', coalesce(r.paid_entry_allowed, false),
    'same_flight_required', coalesce(r.guest_must_match_carrier, false),
    'member_fee', nullif(r.member_entry_fee,''),
    'guest_fee', nullif(r.guest_entry_fee,''),
    'note', r.notes,
    'headline', case
      when coalesce(r.guest_allowance,0) > 0 and coalesce(r.family_allowed,false)
        then 'Ailen veya bir misafir götürebilirsin'
      when coalesce(r.guest_allowance,0) > 0
        then coalesce(r.guest_allowance,0)::text || ' misafir götürebilirsin'
      when coalesce(r.paid_entry_allowed,false)
        then 'Ücret ödeyerek girersin — misafir hakkın yok'
      else 'Girebilirsin ama misafir götüremezsin' end);
end $$;

-- ---- 3) CLASSIC PLUS: İÇ HAT ≠ DIŞ HAT ----
-- Mevcut tek satır iç hata daraltılır; dış hat için yeni satır.
update lounge_guest_rules r set venue_scope = 'domestic',
       notes = 'İÇ HATTA yalnız kendin ücretsiz girersin — misafir ve aile hakkı YOKTUR. Yanındaki 3-12 yaş aile çocuğu için ücretin %50''si alınır. (Kaynak: Tablo-1 + yurt içi lounge sayfası.)'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'TK_MS'
   and r.card_tier = 'CLPL' and r.carrier = 'TK' and r.venue_scope is null
   and (r.effective_to is null or r.effective_to >= current_date);

insert into lounge_guest_rules
  (program_id, carrier, card_tier, venue_scope, guest_allowance, family_allowed,
   guest_must_match_carrier, paid_entry_allowed, notes, effective_from)
select p.id, 'TK', 'CLPL', 'international', 0::smallint, false, true, false,
  'DIŞ HAT salonlarında Classic Plus''ın tanımlı bir ücretsiz giriş hakkı YOKTUR (resmi Tablo-2 ve Tablo-4 kart listelerinde yer almaz). İç hatta kendin ücretsiz girersin. En kötü durumu varsayıyoruz — kapıda sürpriz yaşama.',
  current_date
  from lounge_programs p where p.code = 'TK_MS'
 and not exists (select 1 from lounge_guest_rules r
                  where r.program_id = p.id and r.card_tier='CLPL'
                    and r.venue_scope='international'
                    and (r.effective_to is null or r.effective_to >= current_date));

-- ---- 4) YURT DIŞI ANLAŞMALI SALONLAR (Tablo-5) ----
-- TK ile uçarken bile yurt dışı salonda AİLE HAKKI YOK — bir misafir.
-- CORP ve M&S EC ek kısıt: Star Alliance MARKALI salona giremez;
-- bu salon-türü ayrımı katalogda operator ile işaretlenecek, kural
-- notu şimdiden söylüyor.
insert into lounge_guest_rules
  (program_id, carrier, card_tier, venue_scope, guest_allowance, family_allowed,
   guest_must_match_carrier, notes, effective_from)
select p.id, 'TK', x.tier, 'abroad', 1::smallint, false, true, x.note, current_date
  from lounge_programs p, (values
  ('ELPL',  'Yurt dışındaki anlaşmalı/Star Alliance salonlarında: BİR misafir. THY''nin kendi salonundan farklı olarak AİLE HAKKI YOKTUR (Tablo-5).'),
  ('ELITE', 'Yurt dışı anlaşmalı salonda bir misafir; aile hakkı yoktur (Tablo-5).'),
  ('SAG',   'Yurt dışı anlaşmalı salonda bir misafir (Tablo-5).'),
  ('CORP',  'Yurt dışında yalnız kartında yazan ÜLKEDEKİ anlaşmalı salonlar; Star Alliance MARKALI salonlara giremezsin (Tablo-5 dipnotu). Bir misafir.'),
  ('MS_EC', 'Yurt dışında anlaşmalı salonlara girersin, Star Alliance MARKALI salonlara giremezsin (Tablo-5 dipnotu). Bir misafir; aile hakkı yoktur.')
  ) as x(tier, note)
 where p.code = 'TK_MS'
   and not exists (select 1 from lounge_guest_rules r
                    where r.program_id = p.id and r.card_tier = x.tier
                      and r.venue_scope = 'abroad'
                      and (r.effective_to is null or r.effective_to >= current_date));

-- ---- 5) IST DIŞ HAT M&S BÖLÜMÜ İSTİSNASI (Tablo-4) ----
-- Star Alliance taşıyıcısında genel kural "bir misafir, aile yok"
-- ama IST dış hat Miles&Smiles bölümünde M&S EC için "aile veya bir
-- misafir" yazıyor. Venue'ya sabitlenmiş tek istisna satırı.
insert into lounge_guest_rules
  (program_id, venue_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, notes, effective_from)
select p.id, v.id, 'STAR_ALLIANCE', 'MS_EC', 1::smallint, true, true,
  'İstanbul dış hat Miles&Smiles bölümü İSTİSNASI: Star Alliance taşıyıcısında da M&S EC için aile VEYA bir misafir (Tablo-4).',
  current_date
  from lounge_programs p
  join lounge_venues v on v.airport_code = 'IST' and v.section = 'miles_smiles'
                      and v.operator = 'THY' and v.active
 where p.code = 'TK_MS'
   and not exists (select 1 from lounge_guest_rules r
                    where r.program_id = p.id and r.venue_id = v.id
                      and r.card_tier = 'MS_EC' and r.carrier = 'STAR_ALLIANCE'
                      and (r.effective_to is null or r.effective_to >= current_date));

-- ---- 6) PEGASUS SOMUT TARİFE (resmi sayfa, 12 Ağu 2026) ----
update lounge_guest_rules r
   set notes = 'Pegasus''ta ücretsiz salon hakkı YOKTUR (BolBol dahil); Pegasus biniş kartıyla İNDİRİMLİ ücretli giriş yaparsın. SAW Plaza Premium: iç hat 49 EUR / dış hat 63 EUR (KDV dahil, 3 saat, 0-6 yaş ücretsiz). Primeclass ADB/ESB/BJV: 27 EUR+KDV (0-2 ücretsiz, 3 saat). Çukurova Çelebi Platinum: iç 1.260 TL / dış 49,5 EUR (0-6 ücretsiz). Misafir kavramı yoktur; herkes kişi başı öder.',
       member_entry_fee = 'salona göre 27-63 EUR',
       guest_entry_fee  = 'misafir kavramı yok — herkes kişi başı öder'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'PGS_PAID'
   and (r.effective_to is null or r.effective_to >= current_date);

insert into beta_settings (key, value) values
 ('pegasus_tariff_2026', '{
   "kaynak": "flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge",
   "okundu": "2026-08-12",
   "SAW_plaza_premium": {"ic_hat": "49 EUR", "dis_hat": "63 EUR", "kdv": "dahil", "sure": "3 saat", "cocuk": "0-6 yaş ücretsiz"},
   "primeclass_ADB_ESB_BJV": {"ucret": "27 EUR + KDV", "sure": "3 saat", "cocuk": "0-2 yaş ücretsiz"},
   "COV_celebi_platinum": {"ic_hat": "1.260 TL", "dis_hat": "49,5 EUR", "kdv": "dahil", "cocuk": "0-6 yaş ücretsiz"},
   "not": "Pegasus yolcusuna özel indirimli tarifedir; biniş kartı gösterilir, kapıda ödenir."
 }'::jsonb)
on conflict (key) do update set value = excluded.value;

-- ---- 7) ÜYELİK PLAN ÜCRETLERİ (rehber gösterimi için) ----
insert into beta_settings (key, value) values
 ('membership_prices_2026', '{
   "okundu": "2026-08-12",
   "priority_pass": {"standard": "89 EUR/yıl + ziyaret başına 30 EUR", "standard_plus": "yıllık ücret değişken — 10 ücretsiz ziyaret, sonrası 30 EUR", "prestige": "459 EUR/yıl — sınırsız ücretsiz", "misafir": "her seviyede 30 EUR"},
   "dragonpass": {"classic": "96 EUR/yıl — 1 ücretsiz ziyaret", "preferential": "249 EUR/yıl — 8 ücretsiz ziyaret", "ek_ziyaret": "üye VEYA misafir 36 EUR"}
 }'::jsonb)
on conflict (key) do update set value = excluded.value;

-- ---- 8) MIX / EDGE / NEGATİF SENARYO TESTİ ----
-- 🔴 Her senaryonun BEKLENEN sonucu koda yazılıdır; test "çalıştı"
-- değil "doğru cevap verdi" der. (edge_flows 7. adım dersi: bir
-- adımın HANGİ sebeple geçtiği de doğrulanmalı.)
-- 🔴 SAVUNMACI DROP (sqlcheck kuralı): tablo döndüren fonksiyonun
-- kolonları ileride değişirse create or replace 42P13 verir.
drop function if exists public.mixed_case_check();
create or replace function public.mixed_case_check()
returns table (senaryo text, beklenen text, gercek text, sonuc text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_ic uuid; v_dis_ms uuid; v_dis_biz uuid; v_iga uuid;
  p_tk uuid; g jsonb; ok boolean;
begin
  select v.id into v_ic from lounge_venues v
   where v.airport_code='IST' and v.operator='THY' and v.scope='domestic' and v.active limit 1;
  select v.id into v_dis_ms from lounge_venues v
   where v.airport_code='IST' and v.operator='THY' and v.section='miles_smiles' and v.active limit 1;
  select v.id into v_dis_biz from lounge_venues v
   where v.airport_code='IST' and v.operator='THY' and v.section='business' and v.active limit 1;
  select v.id into v_iga from lounge_venues v
   where v.airport_code='IST' and v.name ilike '%iga%' and v.active limit 1;
  select id into p_tk from lounge_programs where code='TK_MS';

  -- (ad · venue · tier · carrier · cabin · beklenen_misafir · beklenen_aile)
  for senaryo, beklenen, gercek, ok in
    with t(ad, vid, tier, carrier, cabin, exp_g, exp_fam) as (values
      ('CLPL İÇ hat: kendisi girer, misafir yok',            v_ic,     'CLPL', 'TK', null::text, 0, false),
      ('CLPL DIŞ hat M&S: hak YOK',                          v_dis_ms, 'CLPL', 'TK', null, 0, false),
      ('ELPL TK iç hat: aile veya 1 misafir',                v_ic,     'ELPL', 'TK', null, 1, true),
      ('ELPL DIŞ hat M&S, TK: aile hakkı korunur',           v_dis_ms, 'ELPL', 'TK', null, 1, true),
      ('ELPL, LH (Star) DIŞ hat: 1 misafir, AİLE YOK',       v_dis_ms, 'ELPL', 'LH', null, 1, false),
      ('MS_EC, LH, IST M&S bölümü İSTİSNA: aile VAR',        v_dis_ms, 'MS_EC','LH', null, 1, true),
      ('SAG, TK: 1 misafir aile yok',                        v_dis_ms, 'SAG',  'TK', null, 1, false),
      ('Kartsız Business kabin: misafir yok',                v_dis_biz, null,  'TK', 'business', 0, false),
      ('Kartsız First (Star): 1 misafir',                    v_dis_biz, null,  'LH', 'first', 1, false),
      ('CLASSIC: ücretle girer, misafir yok',                v_ic,     'CLASSIC','TK', null, 0, false)
    )
    select t.ad,
           t.exp_g::text || case when t.exp_fam then '+aile' else '' end,
           coalesce((public.resolve_guest_rule(p_tk, t.vid, t.tier, t.carrier, t.cabin) ->> 'guest_allowance'),'?')
             || case when coalesce((public.resolve_guest_rule(p_tk, t.vid, t.tier, t.carrier, t.cabin) ->> 'family_allowed')::boolean,false) then '+aile' else '' end,
           coalesce((public.resolve_guest_rule(p_tk, t.vid, t.tier, t.carrier, t.cabin) ->> 'guest_allowance')::int,-1) = t.exp_g
           and coalesce((public.resolve_guest_rule(p_tk, t.vid, t.tier, t.carrier, t.cabin) ->> 'family_allowed')::boolean,false) = t.exp_fam
      from t
  loop
    sonuc := case when ok then '✓' else '✗ UYUŞMUYOR' end;
    return next;
  end loop;

  -- Çoklu hak mix'i: CLPL + Priority Pass
  g := public.best_entitlement(v_ic, array['TK_MS','PRIORITY_PASS'], 'CLPL', 'TK', null);
  senaryo := 'MIX: CLPL + PP, THY İÇ hat → TK_MS kazanır';
  beklenen := 'Miles&Smiles'; gercek := coalesce(g ->> 'program','?');
  sonuc := case when (g ->> 'program_code') = 'TK_MS' then '✓' else '✗ UYUŞMUYOR' end;
  return next;

  g := public.best_entitlement(v_iga, array['TK_MS','PRIORITY_PASS'], 'CLPL', 'TK', null);
  senaryo := 'MIX: CLPL + PP, iGA → PP kazanır (CLPL orada geçmez)';
  beklenen := 'Priority Pass'; gercek := coalesce(g ->> 'program','?');
  sonuc := case when (g ->> 'program_code') = 'PRIORITY_PASS' then '✓' else '✗ UYUŞMUYOR' end;
  return next;
end $$;
grant execute on function public.mixed_case_check() to authenticated;

-- ---- DOĞRULAMA ----
select * from public.mixed_case_check();

-- Test fonksiyonunun kendisi de denetlenir: UYUŞMAYAN satır varsa
-- migration'ı burada durdur (sessiz kırmızı bırakma).
do $$
declare n int;
begin
  select count(*) into n from public.mixed_case_check() where sonuc like '✗%';
  if n > 0 then
    raise exception '156: % senaryo beklenen sonucu vermedi — yukarıdaki tabloya bak', n;
  end if;
end $$;

select '156 OK - resmi kaynak hizalamasi + kapsam boyutu + mix testleri' as sonuc;
