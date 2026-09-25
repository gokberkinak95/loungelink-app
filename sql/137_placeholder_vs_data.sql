-- ============================================================
-- LoungeLink · 137_placeholder_vs_data.sql
-- YER TUTUCU ILE VERIYI AYIR + PEGASUS FAZLA YAYILMIS
--
-- ⚠️ Uygulamayi ETKILER (kapsam daralir, uyarilar azalir).
--
-- ------------------------------------------------------------
-- 🔴 SORUN 1: YER TUTUCU, VERI GIBI DURUYOR
-- ------------------------------------------------------------
-- 096'nin otomatik doldurmasi bosluklari 'unknown' satirlarla
-- kapatti — dogru bir karardi: motor sessizce hata vermek yerine
-- uyariyor. Ama o satirlar `lounge_venue_acceptance` icinde
-- ARASTIRILMIS satirlardan AYIRT EDILEMIYOR:
--   · kaynak URL yok
--   · checked_at yok  -> "90 gunden eski dogrulama" uyarisi SONSUZA
--     kadar yaniyor ve gercek bayat satirlari GOLGELIYOR
--
-- Yani denetim her kostugunda ayni 40 satiri gosteriyor, kimse
-- bakmiyor, ve o listenin icindeki GERCEK bayat satir kayboluyor.
-- Gurultu, denetimi oldurur.
--
-- Cozum: yer tutucuyu ISARETLE. Ayni veri, farkli sinif — ve BO'da
-- "doldurulmayi bekleyen is listesi" olarak gorunsun.
-- ============================================================

alter table lounge_venue_acceptance
  add column if not exists is_placeholder boolean not null default false;
comment on column lounge_venue_acceptance.is_placeholder is
  'true = 096 otomatik doldurmasindan gelen YER TUTUCU, arastirilmis veri DEGIL. '
  'Denetimler bunlari bayat saymaz; BO''da yapilacak is listesi olarak gorunur.';

update lounge_venue_acceptance a
   set is_placeholder = true
 where a.active
   and coalesce(a.source_url,'') = ''
   and a.checked_at is null
   and a.guest_policy = 'unknown';

-- ------------------------------------------------------------
-- 🔴 SORUN 2: PEGASUS OLMAYAN SALONLARDA "GECERLI" GORUNUYOR
-- ------------------------------------------------------------
-- 109 Pegasus ucretlerini resmi listedeki 5 havalimanina sinirladi
-- ama KABUL SATIRLARINI birakti. Sonuc: "Ahlan Lounge"a Pegasus
-- tarifesiyle girilebilirmis gibi gorunuyor — oysa Pegasus'un
-- resmi listesinde o salon YOK.
--
-- Ucreti kaldirip satiri birakmak yarim duzeltmeydi: kullanici
-- rakami gormuyor ama "bu programla girilir" iddiasini goruyor.
-- Iddianin kendisi yanlissa, rakami silmek yetmez.
-- 🔴 ILK DENEMEMDE SATIRI KAPATTIM VE BIR SORUNU BASKASIYLA TAKAS ETTIM:
-- o salonlarin TEK kural satiri buydu; kapatinca "hic kurali olmayan
-- salon" haline geldiler ve motor onlar icin hicbir sey soyleyemez oldu.
-- Yanlis bir iddiayi silmek dogru; yerine BOSLUK birakmak degil.
--
-- Dogrusu: iddiayi kaldir, KAPSAMI koru. Satir yer tutucuya donuyor —
-- "burada bir salon var ama Pegasus tarifesi gecerli degil, kuralini
-- bilmiyoruz" diyor. Kullanici genel uyariyi goruyor, yanlis bilgi degil.
update lounge_venue_acceptance a
   set guest_policy = 'unknown',
       guest_fee_amount = null, guest_fee_currency = null,
       is_placeholder = true,
       enforcement = 'warn',
       conditions = 'Bu salon Pegasus''un resmi salon listesinde YOK. Buradaki '
                 || 'giris kosullarini dogrulayamadik — girisi kapida teyit et.'
  from lounge_programs p, lounge_venues v
 where a.program_id = p.id and a.venue_id = v.id
   and p.code = 'PGS_PAID' and a.active
   and v.airport_code not in ('SAW','BJV','ADB','ESB','COV');

-- ---- Denetimler yer tutucuyu bayat saymasin ----
create or replace function public.lounge_rules_health()
returns table (alan text, sorun text, ayrinti text, agirlik int)
language sql stable security definer set search_path = public as $$
  select v.airport_code || ' · ' || v.name, 'kabul matrisi bos',
         'Bu salon icin hicbir program kabul satiri yok', 1
    from lounge_venues v
   where v.active and v.section_of is null and not exists (
         select 1 from lounge_venue_acceptance a where a.venue_id = v.id)
  union all
  -- 🔴 Yer tutucular BAYAT sayilmaz: hic dogrulanmadilar ki eskisinler.
  -- Onlar ayri bir is listesi (asagida).
  select v.airport_code || ' · ' || v.name, 'kabul dogrulanmadi',
         p.name || ' — son dogrulama ' || coalesce(a.checked_at::text, 'yok'), 2
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
   where a.active and not a.is_placeholder
     and (a.checked_at is null or a.checked_at < current_date - 90)
  union all
  select v.airport_code || ' · ' || v.name, 'yer tutucu — arastirilmayi bekliyor',
         p.name || ' — 096 otomatik doldurmasindan geldi', 3
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
   where a.active and a.is_placeholder
  union all
  select p.name, 'tarife bitiyor',
         coalesce(r.card_tier,'tum kartlar') || ' — ' || r.effective_to::text, 1
    from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
   where r.effective_to is not null and r.effective_to <= current_date + 45
  union all
  select p.name, 'kaynak yok', 'Resmi kaynak URL girilmemis', 3
    from lounge_programs p where p.active and coalesce(p.source_url,'') = ''
  union all
  select p.name, 'takma ad yok', 'Host beyanindan bu program hicbir zaman eslesmez', 2
    from lounge_programs p
   where p.active and not exists (
         select 1 from lounge_program_aliases a where a.program_id = p.id)
  union all
  select p.name, 'kim oduyor belirsiz',
         'fee_payer bos — misafire ne diyecegimizi bilmiyoruz', 2
    from lounge_programs p
   where p.active and p.guest_default = 'paid' and p.fee_payer is null
  union all
  select l.airport_code || ' · ' || l.name, 'salon eslesmedi',
         'lounges kaydinin lounge_venues karsiligi yok', 1
    from lounges l where l.venue_id is null and l.active;
$$;
grant execute on function public.lounge_rules_health() to authenticated;

select is_placeholder, count(*) from lounge_venue_acceptance
 where active group by 1;

select sorun, count(*) from public.lounge_rules_health() group by 1 order by 2 desc limit 6;

select '137 OK - yer tutucu ayrildi, Pegasus kapsami duzeltildi' as sonuc;
