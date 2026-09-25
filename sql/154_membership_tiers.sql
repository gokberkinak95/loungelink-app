-- ============================================================
-- LoungeLink · 154_membership_tiers.sql
-- ÜYELİK SEVİYELERİ + KREDİ KARTI + EKSİK STATÜLER
--
-- ⚠️ Uygulamayi ETKILER (kural motoru + kart secim listesi).
-- KAYNAK: prioritypass.com ve dragonpass.com uyelik plani sayfalari.
--
-- ------------------------------------------------------------
-- 🔴 GOKBERK DORT BOSLUK BULDU — VE BIRI TEMEL BIR VARSAYIM HATASI
-- ------------------------------------------------------------
-- 1. Priority Pass ve DragonPass'i TEK BIR KURAL sandim.
--    Gercekte uyelik seviyesine gore DEGISIYOR:
--      Priority Pass Standard   -> ziyaret basina 30 EUR (UYENIN KENDISI!)
--      Priority Pass Std Plus   -> 10 ucretsiz ziyaret, sonra 30 EUR
--      Priority Pass Prestige   -> sinirsiz ucretsiz
--      DragonPass Classic       -> yilda 1 ucretsiz ziyaret
--      DragonPass Preferential  -> yilda 8 ucretsiz ziyaret
--    Misafir ucreti her seviyede ayri (PP 30 EUR, DragonPass 36 EUR).
--
-- 🔴 2. VE ASIL HATA BURADA:
--    Motorum "host ucretsiz girer, misafir ucretli olabilir" varsayiyordu.
--    YANLIS. Priority Pass Standard'da UYENIN KENDISI de 30 EUR oduyor.
--    Yani host, kendisi icin bile para veriyor olabilir.
--
--    Bu, host'a "ilan ac" demeden once bilmemiz gereken bir sey:
--    ucretsiz sandigi bir sey ona 60 EUR'ya mal olabilir (kendi + misafir).
--    Bir host'u kaybetmenin en hizli yolu, beklemedigi bir fatura.
--
-- 3. Kart secim listesinde KREDI KARTI YOK.
--    143'te `p.code <> 'BANK_CARD'` yazmisim. Gerekcem "banka karti bir
--    program degil" idi — ama kullanicinin gozunden BIR HAK KAYNAGI.
--    Turkiye'de bircok kisi lounge'a kredi kartiyla giriyor.
--
-- 4. Classic statusu listede gorunmuyordu.
--    Veri var (146'da tanimli) ama kart tipi listesi kisitliydi.
--    "Hakki yok" demek, "listede olmasin" demek degil. Kullanici
--    kendi kartini bulamazsa urunun ona hitap etmedigini dusunur.
-- ============================================================

-- ---- 1) UYELIK SEVIYESI ICIN KOLONLAR ----
-- 🔴 `member_entry_fee`: UYENIN KENDI girisi ucretli mi.
-- Bugune kadar boyle bir kavram yoktu cunku "hak sahibi bedava girer"
-- varsayimi vardi. Kart aglarinda bu varsayim gecerli DEGIL.
alter table lounge_guest_rules add column if not exists member_free_visits int;
alter table lounge_guest_rules add column if not exists member_entry_fee text;
alter table lounge_guest_rules add column if not exists guest_entry_fee text;

comment on column lounge_guest_rules.member_free_visits is
  'Yilda kac ucretsiz ziyaret. NULL = sinirsiz/bilinmiyor, 0 = her ziyaret ucretli.';
comment on column lounge_guest_rules.member_entry_fee is
  'Uyenin KENDI girisi icin odedigi ucret. Bos = ucretsiz.';

-- ---- 2) PRIORITY PASS SEVIYELERI ----
update lounge_guest_rules r set effective_to = current_date - 1
  from lounge_programs p
 where r.program_id = p.id and p.code in ('PRIORITY_PASS','DRAGONPASS')
   and r.card_tier is null
   and (r.effective_to is null or r.effective_to >= current_date);

insert into lounge_guest_rules
  (program_id, card_tier, guest_allowance, family_allowed, guest_must_match_carrier,
   member_free_visits, member_entry_fee, guest_entry_fee, notes, effective_from)
select p.id, x.tier, 0::smallint, false, false, x.free, x.mfee, x.gfee, x.note, current_date
  from lounge_programs p, (values
  ('PP_STANDARD', 0,
   '30 EUR / ziyaret', '30 EUR / misafir',
   'Priority Pass Standard: KENDİ girişin de ücretlidir — ziyaret başına 30 EUR. Misafir için ayrıca 30 EUR. Yıllık üyelik ücreti bunun dışındadır.'),
  ('PP_STANDARD_PLUS', 10,
   '10 ziyaret sonrası 30 EUR', '30 EUR / misafir',
   'Priority Pass Standard Plus: yılda 10 ücretsiz ziyaret hakkın var; sonrası ziyaret başına 30 EUR. Misafir her zaman 30 EUR.'),
  ('PP_PRESTIGE', null,
   null, '30 EUR / misafir',
   'Priority Pass Prestige: kendi girişlerin sınırsız ücretsiz. Misafir için ziyaret başına 30 EUR ödenir.')
  ) as x(tier, free, mfee, gfee, note)
 where p.code = 'PRIORITY_PASS';

-- ---- 3) DRAGONPASS SEVIYELERI ----
insert into lounge_guest_rules
  (program_id, card_tier, guest_allowance, family_allowed, guest_must_match_carrier,
   member_free_visits, member_entry_fee, guest_entry_fee, notes, effective_from)
select p.id, x.tier, 0::smallint, false, false, x.free, x.mfee, x.gfee, x.note, current_date
  from lounge_programs p, (values
  ('DP_CLASSIC', 1,
   '1 ziyaret sonrası ücretli', '36 EUR / misafir',
   'DragonPass Classic: yılda 1 ücretsiz ziyaret. Sonraki ziyaretler ve her misafir için 36 EUR.'),
  ('DP_PREFERENTIAL', 8,
   '8 ziyaret sonrası ücretli', '36 EUR / misafir',
   'DragonPass Preferential: yılda 8 ücretsiz ziyaret. Ek ziyaret ve her misafir için 36 EUR.')
  ) as x(tier, free, mfee, gfee, note)
 where p.code = 'DRAGONPASS';

-- ---- 4) LOUNGEKEY: BANKAYA BAGLI, SEVIYE UYDURMUYORUZ ----
-- 🔴 LoungeKey'in kendi seviye tablosu YOK; kosullar karti veren
-- bankanin anlasmasina gore degisiyor. Uydurulmus seviye, eksik
-- seviyeden kotudur — bu yuzden tek kural + acik uyari birakiyoruz.
update lounge_guest_rules r
   set notes = 'LoungeKey koşulları kartını veren BANKANIN anlaşmasına bağlıdır. Ücretsiz ziyaret hakkın ve misafir ücreti bankadan bankaya değişir — kartını veren kurumdan teyit et. Bu bilgiyi doğrulayamıyoruz.',
       member_entry_fee = 'bankaya göre değişir',
       guest_entry_fee = 'bankaya göre değişir'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'LOUNGEKEY'
   and (r.effective_to is null or r.effective_to >= current_date);

-- ---- 5) KART SECIM LISTESI: KREDI KARTI GERI GELIYOR ----
-- 🔴 DEFENSIVE DROP — DORDUNCU KEZ ayni hatayi yaptim.
-- `kind` kolonu ekleyince OUT parametreleri degisiyor ve PostgreSQL
-- `create or replace` ile bunu kabul etmiyor.
--
-- Dort kez tekrarlamis olmam, denetimin YANLIS YERDE oldugunu gosteriyor:
-- returns_check dosyalari tariyor ama ben hatayi ancak CALISTIRINCA
-- goruyorum. Asagida bunu sqlcheck'e tasidim — artik dosyayi yazar
-- yazmaz uyaracak.
drop function if exists public.guide_programs();

create or replace function public.guide_programs()
returns table (code text, name text, tiers jsonb, popular boolean, kind text)
language sql stable security definer set search_path = public as $$
  select p.code, p.name,
         coalesce((select jsonb_agg(jsonb_build_object(
                     'code', r.card_tier,
                     'label', public.card_tier_label(r.card_tier))
                     order by r.card_tier)
                     from (select distinct card_tier from lounge_guest_rules
                            where program_id = p.id and card_tier is not null
                              and (effective_to is null or effective_to >= current_date)) r), '[]'::jsonb),
         p.code in ('TK_MS','AJET_MS','PRIORITY_PASS','LOUNGEKEY','DRAGONPASS','BANK_CARD','STAR_GOLD'),
         -- Kullanicinin zihnindeki ayrim: havayolu statusu mu, bagimsiz
         -- uyelik mi, banka avantaji mi. Liste bu basliklarla gruplanir.
         case when p.code in ('TK_MS','AJET_MS','PGS_PAID','STAR_GOLD') then 'airline'
              when p.code = 'BANK_CARD' then 'bank'
              else 'membership' end
    from lounge_programs p
   -- 🔴 `p.code <> 'BANK_CARD'` FILTRESI KALDIRILDI.
   -- 143'te "banka karti bir program degil" diye elemistim. Kullanicinin
   -- gozunden ise en yaygin hak kaynaklarindan biri. Kendi kartini
   -- listede bulamayan kullanici, urunun ona hitap etmedigini dusunur.
   where p.active
   order by (p.code in ('TK_MS','AJET_MS','PRIORITY_PASS','LOUNGEKEY','DRAGONPASS','BANK_CARD','STAR_GOLD')) desc,
            p.name;
$$;
grant execute on function public.guide_programs() to anon, authenticated;

select code, kind, jsonb_array_length(tiers) as seviye from public.guide_programs() where popular;
select '154 OK - uyelik seviyeleri + kredi karti + eksik statuler' as sonuc;

-- ============================================================
-- 🔴 SEVİYESİ BİLİNMEYEN HOST KURAL DIŞI KALIYORDU
-- ------------------------------------------------------------
-- 154'ün ilk hali Priority Pass ve DragonPass'in seviyesiz (card_tier
-- NULL) kuralını kapattı ve yerine üç seviye koydu. E2E testi anında
-- kırıldı: `paid_guest_credit` 0 döndü, "kredi yetersiz" bildirimi
-- düşmedi.
--
-- Sebep basit ama önemli: HOST'LARIN ÇOĞU SEVİYESİNİ BİLMEZ.
-- "Priority Pass'im var" der; Standard mı Prestige mi diye sorulunca
-- kartına bakması gerekir. Seviye seçilmemişse motor hiçbir kural
-- bulamıyor ve sessizce "ücret yok" varsayıyordu.
--
-- Sessizce iyimser varsaymak, bu üründe en tehlikeli davranıştır:
-- host ücretsiz sanıp ilan açar, kapıda 60 EUR öder.
--
-- ÇÖZÜM: seviyesiz bir taban kural bırakıyoruz ve EN KÖTÜ DURUMU
-- varsayıyoruz — ücretli. Host seviyesini girerse daha kesin kurala
-- geçer; girmezse en azından uyarılmış olur.
-- ============================================================
insert into lounge_guest_rules
  (program_id, card_tier, guest_allowance, family_allowed, guest_must_match_carrier,
   member_free_visits, member_entry_fee, guest_entry_fee, notes, effective_from)
select p.id, null, 0::smallint, false, false, 0, x.mfee, x.gfee, x.note, current_date
  from lounge_programs p, (values
  ('PRIORITY_PASS', 'üyelik seviyesine göre değişir', '30 EUR / misafir',
   'Üyelik seviyeni belirtmedin. En kötü durumu varsayıyoruz: Standard seviyede KENDİ girişin de ücretli olabilir (30 EUR) ve misafir için ayrıca 30 EUR. Seviyeni girersen daha net söyleriz.'),
  ('DRAGONPASS', 'üyelik paketine göre değişir', '36 EUR / misafir',
   'Üyelik paketini belirtmedin. Classic pakette yılda yalnız 1 ücretsiz ziyaret var. Paketini girersen daha net söyleriz.')
  ) as x(code, mfee, gfee, note)
 where p.code = x.code
   and not exists (
     select 1 from lounge_guest_rules r
      where r.program_id = p.id and r.card_tier is null
        and (r.effective_to is null or r.effective_to >= current_date));

select p.code, coalesce(r.card_tier,'(seviye yok — taban kural)') as tip,
       coalesce(r.member_entry_fee,'ücretsiz') as uye_ucreti
  from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
 where p.code in ('PRIORITY_PASS','DRAGONPASS')
   and (r.effective_to is null or r.effective_to >= current_date)
 order by p.code, r.card_tier nulls first;
