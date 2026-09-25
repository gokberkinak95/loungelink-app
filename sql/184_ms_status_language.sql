-- ============================================================
-- LoungeLink · 184_ms_status_language.sql
-- "MILES&SMILES KARTI" DEĞİL, "MILES&SMILES STATÜSÜ"
--
-- ⚠️ Uygulamayı ETKİLER (kullanıcıya görünen etiketler).
--
-- ------------------------------------------------------------
-- 🔴 GÖKBERK'İN İKİ TESPİTİ (madde 5 ve 7)
-- ------------------------------------------------------------
-- 1. "Miles&Smiles ABD Kredi Kartı" YANLIŞ AD. Doğrusu
--    "Miles&Smiles Amex". Yanlış ad, kural doğru olsa bile ürünün
--    konuya hâkim olmadığını düşündürür — bizim tek satış
--    argümanımız kurallara hâkim olmak.
--
-- 2. "Miles&Smiles kartı" ifadesi KAVRAM HATASI. Miles&Smiles bir
--    KART değil, THY ve AJet'i kapsayan bir STATÜ programıdır.
--    "Kart" denince kullanıcı kredi kartı anlıyor. Üstelik bu
--    karışıklık gerçek bir soruyu gizliyor: statü ortak olsa da
--    salona girişi UÇULAN HAVAYOLU belirler — AJet biletiyle THY
--    salonuna misafir olarak girilemez (SQL 177'de kurala,
--    182'de keşfet uyarısına bağlandı).
--
-- Etiketler motorda tek yerde (card_tier_label) üretiliyor; app ve
-- BO oradan okuyor. Düzeltme burada yapılınca her yüzeyde düzelir.
-- ============================================================

-- sqlcheck: allow-replace card_tier_label  (dönüş tipi AYNI — text)
create or replace function public.card_tier_label(p_tier text)
returns text language sql immutable as $$
  select case p_tier
    when 'ELPL'     then 'Elite Plus'
    when 'ELITE'    then 'Elite'
    when 'CLPL'     then 'Classic Plus'
    when 'CLASSIC'  then 'Classic'
    when 'CORP'     then 'Corporate Club'
    when 'MS_EC'    then 'Elite Corporate'
    when 'SAG'      then 'Star Alliance Gold'
    when 'PLM'      then 'Program Üyesi'
    -- 🔴 184: "ABD Kredi Kartı" yanlış addı; doğrusu Amex.
    when 'MS_US_CC' then 'Miles&Smiles Amex'
    when 'PP_STANDARD'      then 'Priority Pass Standard'
    when 'PP_STANDARD_PLUS' then 'Priority Pass Standard Plus'
    when 'PP_PRESTIGE'      then 'Priority Pass Prestige'
    when 'DP_CLASSIC'       then 'DragonPass Classic'
    when 'DP_PREFERENTIAL'  then 'DragonPass Preferential'
    else p_tier
  end;
$$;

-- Program adı da statü dilini konuşsun: kullanıcı "kart seç"
-- ekranında kredi kartı aramasın.
update lounge_programs
   set name = 'Miles&Smiles (THY & AJet statüsü)'
 where code = 'TK_MS' and coalesce(name,'') <> 'Miles&Smiles (THY & AJet statüsü)';

update lounge_programs
   set name = 'Miles&Smiles — AJet seferleri'
 where code = 'AJET_MS' and coalesce(name,'') <> 'Miles&Smiles — AJet seferleri';

-- ---- KANIT ----
do $$
declare v text;
begin
  v := public.card_tier_label('MS_US_CC');
  if v <> 'Miles&Smiles Amex' then
    raise exception '184: MS_US_CC etiketi hâlâ "%"', v;
  end if;
  if public.card_tier_label('ELPL') <> 'Elite Plus' then
    raise exception '184: mevcut etiketler bozuldu';
  end if;
  raise notice '184: statü dili uygulandı ✓';
end $$;

select '184 OK - miles&smiles statu dili' as sonuc;
