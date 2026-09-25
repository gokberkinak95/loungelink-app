-- ============================================================
-- LoungeLink · 150_network_rules_and_guard.sql
-- KART AGLARININ KENDI KURALLARI + BULASMA KORUMASI
--
-- ⚠️ Uygulamayi ETKILER.
--
-- ------------------------------------------------------------
-- 🔴 146'DA KARTEZYEN CARPIM YAPMISIM
-- ------------------------------------------------------------
-- `from lounge_programs p, (values ...)` yazip WHERE koymayi
-- unutmusum. Sonuc: THY kurallari TUM programlara yazildi.
-- Priority Pass'in kural listesinde "THY seferinde aile veya bir
-- misafir" yaziyordu.
--
-- 🔴 DENETIMLERIM BUNU KACIRDI ve sebebi ogretici: mukerrer DEGILDI.
-- Her program icin TEK satir vardi — ama YANLIS programa aitti.
-- **Dogru sayida yanlis veri, sayim denetiminden gecer.**
-- Bu yuzden asagida ICERIK denetimi ekliyorum: bir programin
-- kuralinda BASKA bir programin metni geciyorsa yakala.
--
-- ------------------------------------------------------------
-- Temizlik sonrasi kart aglari KURALSIZ kaldi. Onlarin da kendi
-- kurallari olmali — bosluk birakmak, bulasmadan iyi ama yeterli degil.
-- ============================================================

insert into lounge_guest_rules
  (program_id, card_tier, guest_allowance, family_allowed,
   guest_must_match_carrier, notes, effective_from)
select p.id, null, x.n, false, x.same, x.note, current_date
  from lounge_programs p
  join (values
  -- 🔴 MISAFIR SAYISI 0, POLITIKA 'paid'.
  -- Ilk yazimda 1 yazmistim ve E2E gerileme yakaladi: kural notu
  -- "cogu seviyede misafir UCRETLIDIR" derken sayi 1 (ucretsiz hak)
  -- diyordu. Iki sinyal celisiyordu ve motor sayiyi okuyup ucret
  -- akisini atliyordu.
  --
  -- Dogrusu: kart aglarinda misafir UCRETSIZ HAK DEGIL. Salon
  -- kabul satiri `guest_policy='paid'` diyor; kural da 0 demeli.
  -- Ucret akisi kabul satirindan yurur, kural ondan once konusmamali.
  ('PRIORITY_PASS', 0::smallint, false,
   'Misafir hakkı ÜYELİK SEVİYENE bağlıdır (Standart / Plus / Prestige). Çoğu seviyede misafir ÜCRETLİDİR ve ücret senin kartından çekilir. Kartını veren kurumdan teyit et.'),
  ('LOUNGEKEY',     0::smallint, false,
   'Misafir hakkı kartını veren BANKANIN anlaşmasına bağlıdır; çoğu pakette misafir ücretlidir ve senin kartından çekilir.'),
  ('DRAGONPASS',    0::smallint, true,
   'Misafir hakkı üyelik paketine bağlıdır ve genelde ücretlidir. Bazı paketlerde misafirin SENİNLE AYNI UÇUŞTA olması istenir.'),
  ('DREAMFOLKS',    0::smallint, false,
   'Koşulları doğrulanmadı. Girişten önce kartını veren kurumdan teyit et.'),
  ('ONPASS',        0::smallint, false,
   'Koşulları doğrulanmadı. Girişten önce teyit et.'),
  ('EVERYLOUNGE',   0::smallint, false,
   'Koşulları doğrulanmadı. Girişten önce teyit et.'),
  ('HIGHPASS',      0::smallint, false,
   'Koşulları doğrulanmadı. Girişten önce teyit et.'),
  ('LOUNGEME',      0::smallint, false,
   'Koşulları doğrulanmadı. Girişten önce teyit et.'),
  ('IGA_PASS',      0::smallint, false,
   'İGA Pass kişiye özeldir; misafir hakkı yoktur. Misafirin kendi kartı ya da kapıda ödeme ile girer.'),
  ('ST_PASS',       0::smallint, false,
   'Koşulları doğrulanmadı. Girişten önce teyit et.'),
  ('PGS_PAID',      0::smallint, false,
   'Pegasus''ta misafir kavramı yoktur; herkes kişi başı öder. Pegasus biniş kartıyla indirimli tarife uygulanır.'),
  -- Star Alliance Gold FARKLI: misafir hakki UCRETSIZ ve resmi
  -- kaynakta net (Tablo-2). Onu 0 yapmak yanlis olurdu.
  ('STAR_GOLD',     1::smallint, true,
   'Star Alliance Gold: bir misafir. 03.05.2021''den beri misafirin SENİNLE AYNI UÇAKTA olması zorunludur.')
  ) as x(code, n, same, note) on x.code = p.code
 where not exists (
   select 1 from lounge_guest_rules r
    where r.program_id = p.id and r.card_tier is null and r.venue_id is null
      and (r.effective_to is null or r.effective_to >= current_date));

-- ============================================================
-- 🔴 BULASMA DENETIMI — SAYIM DEGIL ICERIK
-- ------------------------------------------------------------
-- Bir programin kural notunda BASKA bir programin imzasi geciyorsa,
-- o kural yanlis programa yazilmistir. "THY seferinde" ifadesi
-- Priority Pass kuralinda ne ariyor?
--
-- Sayim denetimleri bunu goremez cunku sayi DOGRU. Yalniz icerik
-- bakarak anlasilir.
-- ============================================================
create or replace function public.rule_contamination_check()
returns table (program text, kart text, sorun text, ornek text)
language sql stable security definer set search_path = public as $$
  select p.name, coalesce(r.card_tier,'(genel)'),
         'Kural notu BAŞKA bir programa ait görünüyor',
         left(r.notes, 70)
    from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where (r.effective_to is null or r.effective_to >= current_date)
     and (
       (p.code not in ('TK_MS','AJET_MS') and r.notes ~* '(THY seferinde|AJet seferinde|Miles&Smiles bölüm)')
       or (p.code <> 'PGS_PAID'     and r.notes ~* 'Pegasus biniş kartı')
       or (p.code <> 'PRIORITY_PASS' and r.notes ~* 'Priority Pass üyelik')
       or (p.code <> 'IGA_PASS'     and r.notes ~* 'İGA Pass kişiye')
     );
$$;
grant execute on function public.rule_contamination_check() to authenticated;

select 'bulasma' as kontrol, count(*)::text as adet from public.rule_contamination_check();

select p.code, count(r.id) as kural
  from lounge_programs p
  left join lounge_guest_rules r on r.program_id = p.id
   and (r.effective_to is null or r.effective_to >= current_date)
 where p.active group by p.code order by 2 desc, 1;

select '150 OK - kart aglarinin kendi kurallari + bulasma denetimi' as sonuc;
