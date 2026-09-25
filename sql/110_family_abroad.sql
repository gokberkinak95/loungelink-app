-- ============================================================
-- LoungeLink · 110_family_abroad.sql
-- AILE HAKKI YURT DISINDA GECERLI DEGIL
--
-- ⚠️ Uygulamayi ETKILER (veri). Sema degisikligi YOK.
--
-- turkishairlines.com/miles-and-smiles/uyelik-statuleri okundu.
-- Sayfa 104'te kodladigim kart tipi matrisini DOGRULADI:
--   · Classic Plus: "Ic hatlarda ozel yolcu salonundan yararlanabilme"
--     -> ic hat, misafir hakki yok. ✓ dogru kodlanmis
--   · Elite / Elite Plus: "es ile cocuklar VEYA bir misafirle" ✓
--
-- 🔴 AMA BIR DIPNOT EKLIYOR:
--   "Yurt disindaki ortakligimiza ait olmayan ANLASMALI salonlarda
--    YALNIZCA 1 MISAFIR giris hakki bulunmaktadir."
--
-- Yani aile hakki (es + 25 yas alti cocuklar) yalniz THY'nin KENDI
-- salonlarinda gecerli. Yurt disindaki anlasmali salonlarda Elite Plus
-- bile yalniz 1 misafir goturebiliyor.
--
-- LoungeLink icin BUGUN pratik etkisi sinirli (kapsamimiz Turkiye), ama
-- iki sebeple simdi yaziyoruz:
--   1. Yurt disi salonlar zaten katalogda (LHR, CDG, DXB, AMS, DOH...)
--      ve host oralarda ilan acabilir.
--   2. "Ailemle giriyorum, misafirim de aile sayilir" yanilgisi tam da
--      kapida cozulen turden bir yanlis anlama.
-- ============================================================

update lounge_guest_rules r
   set family_allowed = false,
       notes = coalesce(r.notes,'')
            || ' [110] YURT DISI ISTISNASI: THY''nin kendi salonlari disindaki '
            || 'ANLASMALI salonlarda aile hakki YOKTUR — yalniz 1 misafir. '
            || 'Kaynak: Miles&Smiles Uyelik Statuleri, Elite dipnotu.'
  from lounge_programs p
 where r.program_id = p.id and p.code = 'TK_MS'
   and r.card_tier in ('ELPL','ELITE','MS_EC')
   and r.venue_id in (
     select v.id from lounge_venues v
      where v.airport_code not in ('IST','SAW','ESB','ADB','AYT','BJV','DLM','COV','DIY',
                                   'ASR','GZT','HTY','TZX','RZV','ADA'));

-- Program duzeyindeki kural Turkiye icin gecerli; yurt disi salonlarina
-- AYRI satir aciyoruz ki karar motoru salonu gorunce dogru olani secsin.
insert into lounge_guest_rules
  (program_id, venue_id, carrier, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, notes, effective_from)
select p.id, v.id, 'TK', t.tier, 1, false, true,
       'Yurt disindaki anlasmali salon: ' || t.tier || ' icin YALNIZ 1 MISAFIR. '
       || 'Aile hakki (es + 25 yas alti cocuklar) burada GECERLI DEGIL — o hak '
       || 'THY''nin kendi salonlarina ozgudur.',
       current_date
  from lounge_programs p
  cross join (values ('ELPL'),('ELITE'),('MS_EC')) as t(tier)
  join lounge_venues v on v.active
   and v.airport_code not in ('IST','SAW','ESB','ADB','AYT','BJV','DLM','COV','DIY',
                              'ASR','GZT','HTY','TZX','RZV','ADA')
 where p.code = 'TK_MS'
   and not exists (select 1 from lounge_guest_rules x
                    where x.program_id = p.id and x.venue_id = v.id
                      and x.card_tier = t.tier);

select p.code, coalesce(r.card_tier,'-') as kart,
       case when r.venue_id is null then 'PROGRAM (Turkiye)' else 'yurt disi salon' end as kapsam,
       r.guest_allowance, r.family_allowed, count(*) as satir
  from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
 where p.code = 'TK_MS' and (r.effective_to is null or r.effective_to >= current_date)
 group by 1,2,3,4,5 order by 3,2;

select '110 OK - aile hakki yurt disi anlasmali salonlarda kaldirildi' as sonuc;
