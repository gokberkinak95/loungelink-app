-- ============================================================================
-- 271 — KEŞFET'İN SON KAPISI: AKTİF OLMAYAN / TARİHİ GEÇMİŞ İLAN ÇIKAMAZ
--
-- ----------------------------------------------------------------------------
-- 🔴 KANITLANMIŞ DURUM (270c)
-- Gerçek bir kullanıcı (gzmdmz@gmail.com) Keşfet'te 4 ilan görüyor.
-- O 4 ilanın tablodaki hâli (270b §2):
--     aktif ✓ : false        ← ilan KAPALI
--     tarih ✓ : false        ← tarihi GEÇMİŞ (2026-08-05 … 08-13)
--
-- `discover_availabilities_base` bu iki koşulu zaten arıyor. Demek ki
-- zincirin bir yerinde o kapı devreye girmiyor. Kök neden 270d ile
-- aranıyor — AMA SIZINTI CANLIDA VE BEKLEYEMEZ.
--
-- ⚠️ BU DOSYA KÖK NEDENİ ÇÖZMÜYOR. En dış fonksiyona ikinci bir süzgeç
-- koyuyor. Kök neden bulunduğunda o da düzeltilecek; bu satır KALACAK,
-- çünkü iki bağımsız kapı, tek kapıdan iyidir.
--
-- 🆕 SINIF: "KÖK NEDEN BULUNANA KADAR SIZINTIYI AÇIK BIRAKMAK BİR TİTİZLİK
-- DEĞİL BİR TERCİHTİR — DIŞ KAPIYI ŞİMDİ KAP, İÇ KAPIYI SONRA ONAR."
--
-- ----------------------------------------------------------------------------
-- VE BU ZATEN ÜRÜNÜN KURALI
-- Gökberk: "Aktif olmayan/tarihi geçmiş ilan da keşfet ekranında zaten
-- görünebilir olmamalı mantıken."
-- Doğru. Bir ilan kapandığında ya da günü geçtiğinde o ilan bir teklif
-- değildir; gösterilmesi kullanıcıya var olmayan bir şeyi vaat etmektir.
-- ============================================================================

begin;

-- ⚠️ İLK DENEMEM `returns table(...)` LİSTESİNİ KATALOGDAN YENİDEN
-- KURMAYA ÇALIŞTI VE PATLADI: `relation "record" does not exist`.
-- Fonksiyonun dönüş tipi bir tablo değil bir `record` kümesi; onu
-- `regclass`a çevirmek mümkün değil.
--
-- Gereksiz zekaydı. Doğrusu: imzaya HİÇ DOKUNMA, yalnız gövdedeki
-- kaynak ifadeyi süz.
-- 🆕 SINIF: "BİR İMZAYI YENİDEN ÜRETMEYE ÇALIŞMAK, ONU DEĞİŞTİRMEDEN
-- BIRAKMAKTAN HER ZAMAN DAHA RİSKLİDİR."
do $k271$
declare
  v_eski text; v_yeni text;
  v_ara constant text :=
    'from public.discover_availabilities_ham(p_airport, p_sector, p_flight, p_date) h';
  v_yer constant text :=
    'from (select z.* '
    || 'from public.discover_availabilities_ham(p_airport, p_sector, p_flight, p_date) z '
    || 'join public.availabilities a271 on a271.id = z.id '
    || 'where a271.active = true and a271.avail_date >= current_date) h';
begin
  select pg_get_functiondef(p.oid) into v_eski
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'discover_availabilities';
  if v_eski is null then
    raise exception '271: discover_availabilities YOK.';
  end if;

  if v_eski like '%a271%' then
    raise notice '271: son kapi zaten var — dokunulmadi.';
    return;
  end if;

  if position(v_ara in v_eski) = 0 then
    raise warning '271: beklenen kaynak ifade BULUNAMADI. Govde:';
    raise warning '%', left(v_eski, 600);
    raise exception '271 DURDU: sarmalayici govdesi beklenenden farkli — elle bakilmali.';
  end if;

  v_yeni := replace(v_eski, v_ara, v_yer);
  execute v_yeni;
  raise notice '271: son kapi kuruldu — aktif olmayan/tarihi gecmis ilan cikamaz. ✓';
end $k271$;

commit;

-- ----------------------------------------------------------------------------
-- SONUÇ TABLOSU  (bu projede her soru soran dosya cevabını TABLOYLA verir)
-- ----------------------------------------------------------------------------
select
  (select count(*) from public.discover_availabilities() d
     join availabilities a on a.id = d.id
    where not a.active or a.avail_date < current_date)      as "kapıdan sızan (0 olmalı)",
  (select count(*) from public.discover_availabilities())   as "Keşfet'te toplam ilan",
  (select count(*) from availabilities
    where active and avail_date >= current_date)            as "tabloda yayına uygun ilan";
