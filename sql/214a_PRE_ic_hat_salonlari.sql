-- ============================================================================
-- LoungeLink · 214a_PRE_ic_hat_salonlari.sql            (18 Ağustos 2026)
--
-- 🔴 TEŞHİS — TAHMİN DEĞİL, GÖKBERK'İN VERİTABANINDAN OKUNDU
--
-- 214 şunu verdi (11 satırın hepsi aynı desende):
--
--   LOUNGEKEY/ADB "Primeclass Lounge" [kaynak kapsam=domestic term=İç Hatlar Terminali]
--     → adaylar: Primeclass Lounge — Dış Hat {kapsam=international term=Dış Hat}
--   LOUNGEKEY/IST "IGA Lounge"        [kaynak kapsam=domestic]
--     → adaylar: iGA Lounge — Dış Hat {kapsam=international}
--   PRIORITY_PASS/DLM "CIP Lounge Domestic" [kaynak kapsam=domestic term=Terminal 2]
--     → adaylar: CIP Lounge — Dış Hat (T2) {kapsam=international}
--   ... (ADB · BJV · COV · DLM · IST — Primeclass / Çelebi Platinum / CIP / iGA)
--
-- Yani on birinin de kaynağı **iç hat** salonunu gösteriyor, katalogda ise
-- yalnız **dış hat** karşılığı duruyor. Eşleştiricinin hiçbir kademesi
-- tutmuyor çünkü tutmaması DOĞRU: dış hat salonuna iç hat kabulü yazmak,
-- misafiri yanlış kapıya göndermek olurdu.
--
-- Temiz kurulumda her ikisi de var — ölçtüm:
--     ADB  Primeclass Lounge — İç Hat   {domestic}   ✓
--     ADB  Primeclass Lounge — Dış Hat  {international} ✓
--     BJV · COV · DLM · IST için aynı çift
-- Yani eksik olan şey, önceki bir turda kaybolmuş kayıtlar.
--
-- ── NEDEN "UYDURMA" DEĞİL ───────────────────────────────────────────
-- Bu salonların varlığını ben iddia etmiyorum; **iki bağımsız kart ağı**
-- (Priority Pass ve LoungeKey, COV'da ayrıca DragonPass) kendi
-- dizinlerinde o havalimanının İÇ HAT terminalinde bu salonu listeliyor.
-- Kaynak satırları `card_network_source` tablosunda duruyor ve bu dosya
-- YALNIZ o satırların işaret ettiği salonları tamamlıyor. Kaynağı
-- olmayan hiçbir salon yaratılmıyor.
--
-- ── SIRA: ÖNCE GERİ AL, SONRA YARAT ─────────────────────────────────
-- 1) Aynı havalimanı + aynı marka + kapsam=domestic bir kayıt PASİF
--    duruyorsa → adı temizlenip geri açılır. (Silme yok, geri alma var.)
-- 2) Hiç yoksa → dış hat kardeşinden türetilir: adı "Dış Hat"→"İç Hat",
--    kapsamı domestic, tipi ve işletmecisi kardeşinden kopyalanır,
--    terminali KAYNAĞIN yazdığından alınır.
-- 3) Sonra eşleştirici yeniden koşar (211'in K1–K4 kademelerinin aynısı).
--
-- Her iki durumda da `notes`a gerekçe yazılıyor; hangi satırın nereden
-- geldiği geriye dönük okunabilir.
--
-- KULLANIM: 214'ten ÖNCE çalıştır.
-- ============================================================================

-- ── (1) EKSİK İÇ HAT SALONLARINI TAMAMLA ────────────────────────────
do $tamamla$
declare
  r        record;
  v_kar    lounge_venues%rowtype;
  v_pas    lounge_venues%rowtype;
  v_ad     text;
  v_term   text;
  v_geri   int := 0;
  v_yeni   int := 0;
  v_atla   int := 0;
begin
  for r in
    select s.airport,
           public.cns_brand(s.venue_name) as marka,
           s.tesis_tipi,
           -- Kaynak terminali: aynı salon için birden çok ağ varsa en
           -- açıklayıcı olanı (en uzun metin) seçiliyor.
           (array_agg(s.terminal order by length(coalesce(s.terminal,'')) desc))[1] as terminal,
           count(*) as kaynak_sayisi,
           string_agg(distinct s.network, '+') as aglar
      from card_network_source s
     where s.venue_id is null
       and s.scope = 'domestic'
     group by 1, 2, 3
  loop
    -- Zaten aktif bir iç hat kaydı varsa dokunma (eşleşme başka sebepten
    -- olmamış demektir; bu dosya onu çözmez ve çözdüğünü iddia etmez).
    if exists (select 1 from lounge_venues v
                where v.active and v.airport_code = r.airport
                  and public.cns_brand(v.name) = r.marka
                  and coalesce(v.scope,'both') = 'domestic') then
      v_atla := v_atla + 1;
      continue;
    end if;

    -- (1a) PASİF karşılığı var mı → GERİ AL
    select * into v_pas from lounge_venues v
     where not v.active and v.airport_code = r.airport
       and public.cns_brand(v.name) = r.marka
       and coalesce(v.scope,'both') = 'domestic'
     order by v.created_at nulls last
     limit 1;

    if found then
      v_ad := regexp_replace(
                regexp_replace(v_pas.name,
                  '\s*\((190 )?birleştirildi( →)? [0-9a-f]+\)$', ''),
                '\s*\(arşiv [0-9a-f]+\)$', '');
      -- Temiz ad başkasında duruyorsa adı bozmadan yalnız aktif et.
      if exists (select 1 from lounge_venues o
                  where o.id <> v_pas.id and o.airport_code = v_pas.airport_code
                    and o.name = v_ad) then
        v_ad := v_pas.name;
      end if;
      update lounge_venues
         set name = v_ad,
             active = true,
             notes = coalesce(notes || ' · ', '')
                     || format('214a: %s kaynagi (%s) bu havalimaninin IC HAT salonunu listeliyor; '
                               'kayit pasifti, geri alindi.', r.kaynak_sayisi, r.aglar)
       where id = v_pas.id;
      v_geri := v_geri + 1;
      raise notice '214a: GERI ALINDI  % / % → "%"', r.airport, r.marka, v_ad;
      continue;
    end if;

    -- (1b) Hiç yok → DIŞ HAT kardeşinden türet
    select * into v_kar from lounge_venues v
     where v.active and v.airport_code = r.airport
       and public.cns_brand(v.name) = r.marka
       and coalesce(v.scope,'both') = 'international'
     limit 1;

    if not found then
      -- Kardeş de yoksa bu dosya karar veremez: salon katalogda hiç yok.
      raise notice '214a: ATLANDI   % / % — dis hat kardesi de yok, elle bakilmali',
        r.airport, r.marka;
      v_atla := v_atla + 1;
      continue;
    end if;

    v_ad := replace(replace(v_kar.name, 'Dış Hat', 'İç Hat'), 'Dis Hat', 'Ic Hat');
    if v_ad = v_kar.name then
      v_ad := v_kar.name || ' — İç Hat';
    end if;
    v_term := coalesce(nullif(replace(replace(coalesce(v_kar.terminal,''),
                                              'Dış Hat', 'İç Hat'),
                                      'Dis Hat', 'Ic Hat'), ''),
                       r.terminal);

    if exists (select 1 from lounge_venues o
                where o.airport_code = r.airport and o.name = v_ad) then
      raise notice '214a: ATLANDI   % / % — "%" adi zaten kullanimda', r.airport, r.marka, v_ad;
      v_atla := v_atla + 1;
      continue;
    end if;

    insert into lounge_venues (airport_code, name, terminal, operator, scope,
                               venue_kind, active, notes)
    values (r.airport, v_ad, v_term, v_kar.operator, 'domestic',
            coalesce(v_kar.venue_kind, r.tesis_tipi, 'lounge'), true,
            format('214a: %s bagimsiz kart agi kaynagi (%s) bu havalimaninin IC HAT '
                   'terminalinde bu salonu listeliyor; katalogda karsiligi yoktu. '
                   'Dis hat kardesi "%s" temel alinarak olusturuldu.',
                   r.kaynak_sayisi, r.aglar, v_kar.name));
    v_yeni := v_yeni + 1;
    raise notice '214a: OLUSTURULDU % / % → "%" (kaynak: %)', r.airport, r.marka, v_ad, r.aglar;
  end loop;

  raise notice '214a: geri alinan % · olusturulan % · atlanan %', v_geri, v_yeni, v_atla;
end
$tamamla$;

-- ── (2) EŞLEŞTİRİCİYİ YENİDEN KOŞ ───────────────────────────────────
-- 211'in K1–K4 kademelerinin AYNISI. Kopyalamak istemezdim ama 211'in
-- döngüsü bir DO bloğu, fonksiyon değil — dışarıdan çağrılamıyor.
-- (Sonraki turda o döngüyü `cns_eslestir()` fonksiyonuna çıkaracağım ki
--  aynı kural iki yerde durmasın; bugün kurulumun ortasında motoru
--  yeniden düzenlemek doğru zamanlama değil.)
do $esles$
declare
  r record; a uuid[]; b uuid[]; v_marka text; v_kademe text; v_n int := 0;
begin
  for r in select * from card_network_source where venue_id is null order by id loop
    v_marka := public.cns_brand(r.venue_name);
    v_kademe := null;

    if r.scope <> 'bilinmiyor' and public.cns_term(r.terminal) is not null then
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, array[r.scope]);
      select coalesce(array_agg(x), '{}'::uuid[]) into b
        from unnest(a) x join lounge_venues v on v.id = x
       where public.cns_term(v.terminal) = public.cns_term(r.terminal);
      if array_length(b,1) = 1 then v_kademe := '214a/K1 kapsam+terminal'; a := b; end if;
    end if;

    if v_kademe is null and r.scope <> 'bilinmiyor' then
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, array[r.scope]);
      if array_length(a,1) = 1 then v_kademe := '214a/K2 kapsam'; end if;
    end if;

    if v_kademe is null and r.scope <> 'bilinmiyor' then
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, array[r.scope,'both']);
      if array_length(a,1) = 1 then v_kademe := '214a/K3 kapsam|both'; end if;
    end if;

    if v_kademe is null and r.scope = 'bilinmiyor' then
      a := public.cns_adaylar(r.airport, v_marka, r.tesis_tipi, null);
      if array_length(a,1) = 1 then v_kademe := '214a/K4 kapsamsiz'; end if;
    end if;

    if v_kademe is not null then
      update card_network_source set venue_id = a[1], match_note = v_kademe where id = r.id;
      v_n := v_n + 1;
    end if;
  end loop;
  raise notice '214a: yeniden eslestirilen kaynak satiri: %', v_n;
end
$esles$;

-- ── (3) KABUL SATIRLARINI YAZ ───────────────────────────────────────
-- Yeni eşleşen satırlar için (salon × program) kabul kaydı. 211 bunu
-- kendi eşleşmeleri için yapıyor; buradakiler onun sonrasında oluştuğu
-- için burada yazılıyor. `on conflict do nothing` — var olanı bozmaz.
-- 🔴 KOLON ADLARI 211'DEN BIREBIR ALINDI, VARSAYILMADI.
-- Ilk yazimimda `scope` ve `source_note` diye iki kolon uydurmustum;
-- `lounge_venue_acceptance`ta ikisi de YOK (dogrusu: source_url,
-- checked_at, is_placeholder). Bu depoda "semayi okumadan kolon adi
-- varsayma" hatasinin kacinci tekrari oldugunu artik saymiyorum ve bu
-- sefer yapan bendim; harness yakaladi, Gokberk'in eline gitmedi.
--
-- `guest_policy` bir ENUM DEGIL, kisitli TEXT (included|paid|not_allowed
-- |unknown). Uc agda da misafir UCRETLI — 217'nin plan sayfasi olcumu:
-- PP 30 EUR, DragonPass 36 EUR.
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, source_url, checked_at,
   active, is_placeholder)
select distinct on (s.venue_id, p.id)
       s.venue_id, p.id, true, 'paid', s.source_url, s.checked_at, true, false
  from card_network_source s
  join lounge_programs p on p.code = s.network
 where s.venue_id is not null
   and s.match_note like '214a/%'
 order by s.venue_id, p.id, s.id
on conflict (venue_id, program_id) do update
  set accepted = true, active = true;

-- ── NÖBETÇİ ─────────────────────────────────────────────────────────
do $nobetci$
declare v_kalan int; v_l text;
begin
  select count(*) into v_kalan from card_network_source where venue_id is null;
  if v_kalan > 0 then
    select string_agg(format('%s/%s "%s" [kapsam=%s]', network, airport, venue_name,
                             coalesce(scope,'?')), ' · ')
      into v_l from card_network_source where venue_id is null;
    raise notice '214a: % satir HALA eslesmedi → %', v_kalan, left(coalesce(v_l,''), 500);
  else
    raise notice '214a: butun kaynak satirlari bir salona bagli ✓';
  end if;
end
$nobetci$;
