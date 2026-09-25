-- ============================================================
-- LoungeLink · 128_iga_lounge_and_conflicts.sql
-- iGA LOUNGE KURALLARI + IKI BIRINCIL KAYNAK CELISIYOR
--
-- ⚠️ Uygulamayi ETKILER (veri + yeni programlar + celiski isareti).
--
-- ------------------------------------------------------------
-- 🔴 CELISKI: LOUNGEKEY
-- ------------------------------------------------------------
-- iGA'nin KENDI sayfasi (istairport.com) iGA Lounge'a hangi travel
-- programlariyla girilebildigini sayiyor:
--   IC HAT : Priority Pass, Dragon Pass
--   DIS HAT: Priority Pass, Dragon Pass, Dreamfolks, High Pass, LoungeMe
-- LoungeKey IKISINDE DE YOK.
--
-- Ama Gokberk'in gonderdigi LoungeKey dizini ekranlarinda iGA Lounge
-- GORUNUYORDU ve ben 099'da o kaynaga dayanarak satir yazmistim.
--
-- IKI BIRINCIL KAYNAK CELISIYOR. Uc secenek vardi:
--   (a) iGA'ya guven, LoungeKey satirini SIL
--   (b) LoungeKey'e guven, iGA listesini eksik say
--   (c) CELISKIYI KAYDET ve kullaniciya soyle
--
-- (c)'yi seciyorum. Gerekcesi: ikisi de kendi alaninda birincil ve
-- ikisinin de hakli olabilecegi bir aciklama var — LoungeKey ve
-- Priority Pass AYNI SIRKETIN (Collinson) iki markasi; iGA sayfasi
-- muhtemelen ikisini "Priority Pass" basligi altinda topluyor.
--
-- Celiskiyi kendi kafamiza gore cozup TEK bir cevap uretmek,
-- kullaniciya sahte bir kesinlik satmak olurdu. Bilmediğimiz sey
-- "hangisi dogru" degil, "ikisi de dogru olabilir" — ve kapida
-- bunu bilmek isteyen kisi kullanicinin kendisi.
-- ============================================================

alter table lounge_venue_acceptance
  add column if not exists source_conflict text;
comment on column lounge_venue_acceptance.source_conflict is
  'Iki birincil kaynak celistiginde doldurulur. Celiskiyi gizlemek yerine '
  'kullaniciya soyleriz; kesinlik uydurmaktansa belirsizligi dogru anlatmak yeglenir.';

update lounge_venue_acceptance a
   set source_conflict =
       'Kaynaklar çelişiyor: LoungeKey''in kendi salon dizini bu salonu listeliyor, '
    || 'ama havalimanının (iGA) kendi sayfası kabul edilen programlar arasında '
    || 'LoungeKey''i saymıyor — yalnız Priority Pass ve Dragon Pass yazıyor. '
    || 'İkisi de birincil kaynak. LoungeKey ile Priority Pass aynı şirketin '
    || '(Collinson) markaları olduğu için iGA''nın ikisini tek başlıkta topluyor '
    || 'olması muhtemel. Girişten önce kartını veren kurumdan teyit et.',
       enforcement = 'warn',
       conditions = coalesce(a.conditions,'') || ' ⚠ KAYNAK ÇELİŞKİSİ — açıklamaya bak.'
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code = 'LOUNGEKEY' and v.airport_code = 'IST'
   and lower(v.name) like '%iga%' and v.active;

-- ---- iGA'nin KENDI programi ve yeni travel programlari ----
insert into lounge_programs
  (code, name, kind, entitlement_model, guest_default, guest_included_count,
   guest_flight_coupling, fee_payer, enforcement, coverage_status, notes, source_url, checked_at)
values
  ('IGA_PASS','İGA Pass','operator','paid_entry','not_allowed', 0, 'any',
   'guest_at_door','warn','verified',
   'iGA''nin kendi kart programi: Plus, Extra, Premium ve Daily Pass. '
   || 'Listede "ve 1 misafiri" ifadesi GECMIYOR — bu salonda MISAFIR HAKKI YOK, '
   || 'herkes kendi karti ya da kendi odemesiyle girer. Deskten, dijital kanaldan '
   || 'ya da Meet & Greet ile de satin alinabiliyor.',
   'https://www.istairport.com/ucuslar/havalimani-rehberleri/giden-yolcu-rehberi/hizmetler/ozel-yolcu-hizmetleri/lounge',
   current_date),
  ('HIGHPASS','High Pass','card_program','card_membership','unknown', 0, 'any',
   null,'warn','unknown',
   'iGA DIS HAT Lounge kabul listesinde var. Kosullari DOGRULANMADI.',
   'https://www.istairport.com/', current_date),
  ('LOUNGEME','LoungeMe','card_program','card_membership','unknown', 0, 'any',
   null,'warn','unknown',
   'iGA DIS HAT Lounge kabul listesinde var. Akbank Wings kartlarinda da bu '
   || 'uygulama uzerinden uyelik aciliyor. Kosullari DOGRULANMADI.',
   'https://www.istairport.com/', current_date)
on conflict (code) do update set
  notes = excluded.notes, source_url = excluded.source_url, checked_at = excluded.checked_at;

insert into lounge_program_aliases (program_id, alias, weight)
select p.id, a.alias, a.w from lounge_programs p, (values
  ('IGA_PASS','iga pass',96), ('IGA_PASS','iga premium',90),
  ('IGA_PASS','iga plus',90), ('IGA_PASS','iga extra',90),
  ('HIGHPASS','high pass',95), ('HIGHPASS','highpass',95),
  ('LOUNGEME','loungeme',95), ('LOUNGEME','lounge me',92)
) as a(code, alias, w) where p.code = a.code
on conflict do nothing;

-- ---- iGA Lounge kabul satirlari: IC HAT ve DIS HAT FARKLI ----
-- 🔴 Ic hatta yalniz PP ve DP; dis hatta bes program. Ayni salon adi,
-- farkli liste — SAW Plaza Premium'daki desenin aynisi.
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, fee_payer, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'not_allowed', 0, 'any', 'guest_at_door', 'warn',
       'iGA''nin kendi sayfasindaki kabul listesinden. Bu salonda MISAFIR HAKKI '
       || 'tanimlanmamis: herkes kendi karti ya da kendi odemesiyle girer.',
       'https://www.istairport.com/ucuslar/havalimani-rehberleri/giden-yolcu-rehberi/hizmetler/ozel-yolcu-hizmetleri/lounge',
       current_date
  from lounge_venues v
  join lounge_programs p on p.code = any (
    case when coalesce(v.scope,'') = 'domestic'
         then array['IGA_PASS','PRIORITY_PASS','DRAGONPASS']
         else array['IGA_PASS','PRIORITY_PASS','DRAGONPASS','DREAMFOLKS','HIGHPASS','LOUNGEME'] end)
 where v.airport_code = 'IST' and v.active and lower(v.name) like '%iga lounge%'
on conflict (venue_id, program_id) do update set
  conditions = excluded.conditions, source_url = excluded.source_url,
  checked_at = excluded.checked_at;

-- ---- DOGRULAMA ----
select left(v.name,30) salon, coalesce(v.scope,'-') kapsam, p.code,
       coalesce(a.source_conflict,'') <> '' as celiski
  from lounge_venue_acceptance a
  join lounge_venues v on v.id = a.venue_id
  join lounge_programs p on p.id = a.program_id
 where v.airport_code = 'IST' and v.active and lower(v.name) like '%iga lounge%'
 order by v.name, p.code;

select '128 OK - iGA listesi girildi, LoungeKey celiskisi ISARETLENDI (gizlenmedi)' as sonuc;
