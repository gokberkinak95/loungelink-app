-- ============================================================
-- 215 · SAĞLAYICI VERİ YOLLARI — Ö7/Ö8/Ö9/Ö10'un ALTINDAKİ KOLONLARI
--        GERÇEKTEN DOLDURAN YAZMA YOLLARI
-- 17 Ağustos 2026
--
-- 213 altı sağlayıcı ekranını (Ö5–Ö10) açtı ve dördü "kısıtlı" ya da
-- "hesaplanamıyor" dedi. 213'ün teşhisi doğruydu ama TEDAVİ EDİLMEDİ:
-- rapor dürüsttü, VERİ YOKTU. Bu dosya raporu yumuşatmıyor — raporun
-- okuduğu kolonlara YAZAN YOLU açıyor.
--
-- ------------------------------------------------------------
-- ÖNCE ÖLÇTÜM (canlı şema, 234 dosya çalıştıktan sonra)
-- ------------------------------------------------------------
--   availabilities.program_id     0/25   (venue_id de 0/25)
--   visits.purpose                0/8
--   visits.flight_verified      false/8  (hiçbiri true)
--   visits.scheduled_departure    0/8
--   requests.visit_id             0/1
--   venue_prices                  5 satır, HEPSİ tek salon (Kepler Club SAW)
--   flight_cache                  0 satır
--   profiles.travel_style        11/29
--
-- ------------------------------------------------------------
-- HER BİRİNİN SEBEBİ — TAHMİN DEĞİL, GÖVDEDEN OKUNDU
-- ------------------------------------------------------------
-- (Ö7) `create_availability` gövdesindeki INSERT:
--        insert into availabilities (
--          host_id, lounge_id, airport_code, avail_date, time_from, time_to,
--          slots, filled, active, visibility, flight_number, min_trust, carrier)
--      `program_id` ve `venue_id` LİSTEDE YOK. Kolon 25 satır boyunca
--      boş kaldı çünkü hiç kimse yazmadı.
--      🔴 VE İKİNCİ BİR YAZICI DAHA VAR — bunu da ölçtüm:
--        select p.oid::regprocedure from pg_proc p
--         where pg_get_functiondef(p.oid) ilike '%into availabilities%';
--          → create_availability(...)   ve   publish_availability(...)
--      Yani YALNIZ sarmalayıcı yazmak, ikinci yazıcıyı kör bırakırdı.
--      Bu yüzden gerçek onarım BEFORE INSERT tetikleyicisi; sarmalayıcı
--      ayrıca var ama işi başka: host'a HANGİ programla kaydedildiğini
--      SÖYLEMEK.
--
-- (Ö8) `venue_prices` boş değil ama TEK salonun kataloğu. Karşılaştırma
--      kümesi (aynı havalimanı + aynı venue_kind) her yerde tek elemanlı
--      olduğu için `karsilastirilabilir=false` dönüyordu.
--
-- (Ö9) `visits.purpose`: uygulama iki ayrı yerden seyahat yazıyor ve
--      YALNIZ BİRİ amacı taşıyor —
--        src/screens.js:8362  AddVisit        → purpose YAZILIYOR
--        src/screens.js:151   Trips satır-içi → purpose YOK
--      Satır-içi form ölü değil: `setAdding(true)` boş-durum düğmesinden
--      (satır 236 ve 244) çağrılıyor. Yani İLK seyahatini boş ekrandan
--      ekleyen kullanıcının amacı hiç sorulmuyor.
--      `profiles.travel_style`: uygulama YAZIYOR (EditProfile, v2.66'da
--      düzeltilmiş) — 11/29 dolu. Burada yazma yolu KIRIK DEĞİL.
--      `quiet_zone`: katalog sözlüğünde hiç yoktu (213 bunu ölçmüştü).
--
-- (Ö10) `requests.visit_id`: `create_request_impl_preflag` gövdesi
--       eşleşen seyahati ZATEN BULUYOR ama yalnız VAR MI diye soruyor:
--         select exists (select 1 from visits v where ...) into v_has_trip;
--         if not v_has_trip then raise exception 'no_matching_trip'; end if;
--       Sonraki INSERT'te `visit_id` kolonu YOK. Yani istek, hangi
--       seyahate ait olduğunu BİLİYOR ve o bilgiyi çöpe atıyor.
--       `flight_verified` / `scheduled_departure`: zincir sağlam
--       (`trg_visit_flight_ins` → `sync_visit_flight` → `flight_cache`)
--       ama `flight_cache` 0 satır. Sebep aşağıda (bölüm 4c) ölçüldü.
-- ============================================================


-- ============================================================
-- 1) Ö7 · İLAN ARTIK KENDİ PROGRAMINI TAŞIYOR
-- ============================================================

-- ------------------------------------------------------------
-- 1a) TÜRETİM BİR ÇIKARIMDIR — KOLONA YAZARKEN BUNU KAYBETMEYİN
-- ------------------------------------------------------------
-- 🔴 BURADA NEREDEYSE BİR YALAN ÜRETİYORDUM.
-- 213'ün Ö7 gövdesi "doğrudan beyan" sayısını şöyle sayıyor:
--     count(*) filter (where a.program_id is not null)
-- Eğer `program_id`'yi `pick_host_program()` ile doldurup dursaydım,
-- ekran ertesi gün "%100 doğrudan beyan" derdi — oysa hiçbiri beyan
-- DEĞİL, hepsi çıkarım. Boş kolonu doldururken bilginin KAYNAĞINI
-- silmek, boş bırakmaktan daha zararlıdır: sözleşme masasına
-- "hostlarınızın hepsi Priority Pass beyan etti" diye oturursunuz.
--
-- Bu yüzden kolonla birlikte KAYNAĞI da yazıyoruz.
alter table availabilities
  add column if not exists program_source text;

do $blok$
begin
  if not exists (select 1 from pg_constraint where conname = 'av_program_source_chk') then
    alter table availabilities
      add constraint av_program_source_chk
      check (program_source is null or program_source in ('beyan', 'turetildi'));
  end if;
end $blok$;

comment on column availabilities.program_source is
  'program_id NEREDEN geldi: beyan = ilanı açan/yöneten açıkça verdi; turetildi = pick_host_program() ile host hak beyanından çıkarıldı. NULL = program çözülemedi.';


-- ------------------------------------------------------------
-- 1b) BEFORE INSERT TETİKLEYİCİSİ — "INSERT ANINDA" GERÇEKTEN
-- ------------------------------------------------------------
-- Neden sarmalayıcı değil de tetikleyici: yukarıda ölçtüm, ilan yazan
-- İKİ fonksiyon var (`create_availability`, `publish_availability`).
-- Sarmalayıcı birini kapatır, diğeri kolonu boş yazmaya devam ederdi ve
-- Ö7 "%30 bilinmeyen" gösterip sebebini kimseye söyleyemezdi. Tetikleyici
-- yazma yolunun TAMAMINI kapsar — ileride üçüncü bir yazıcı eklense bile.
--
-- 🔴 TETİKLEYİCİ İLANI DÜŞÜRMEZ. Program bilgisi bir RAPOR alanıdır;
-- ilanın kendisi ürünün canıdır. Katalogda bir tutarsızlık yüzünden
-- host ilan açamazsa, raporu düzeltirken ürünü kırmış oluruz (197'nin
-- uçuş tetikleyicisinde alınan aynı karar). AMA HATA GİZLENMİYOR:
-- `app_errors` tablosuna yazılıyor, böylece sessiz değil GÖRÜNÜR bir
-- başarısızlık oluyor.
create or replace function public.trg_avail_program_fill()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_ven uuid;
begin
  -- (1) venue: ilan salona bağlı, fiyat/kabul kataloğu ise venue'ya.
  --     Bu çeviri her okuma anında yeniden yapılıyordu; bir kez yazalım.
  if new.venue_id is null then
    select l.venue_id into v_ven from lounges l where l.id = new.lounge_id;
    new.venue_id := v_ven;
  else
    v_ven := new.venue_id;
  end if;

  -- (2) program
  if new.program_id is not null then
    -- Yazan taraf programı AÇIKÇA verdi → beyan.
    new.program_source := coalesce(new.program_source, 'beyan');
  elsif v_ven is not null and new.host_id is not null then
    begin
      new.program_id := public.pick_host_program(new.host_id, v_ven);
    exception when others then
      new.program_id := null;
      begin
        insert into app_errors (screen, code, message, context)
        values ('trg_avail_program_fill', sqlstate, sqlerrm,
                jsonb_build_object('host_id', new.host_id, 'venue_id', v_ven));
      exception when others then null;   -- günlük yazımı da ilanı düşüremez
      end;
    end;
    if new.program_id is not null then
      new.program_source := 'turetildi';
    end if;
  end if;

  return new;
end $fn$;

drop trigger if exists trg_avail_program_fill on availabilities;
create trigger trg_avail_program_fill
  before insert on availabilities
  for each row execute function public.trg_avail_program_fill();


-- ------------------------------------------------------------
-- 1c) GEÇMİŞ 25 SATIR — GERİYE DÖNÜK DOLDURMA
-- ------------------------------------------------------------
-- Tetikleyici yalnız BUNDAN SONRASINI kurtarır. Ö7 son 180 günü
-- okuduğu için var olan satırlar doldurulmazsa ekran altı ay daha
-- "bilinmeyen %100" derdi.
do $blok$
declare v_ven int; v_pg int;
begin
  update availabilities a
     set venue_id = l.venue_id
    from lounges l
   where l.id = a.lounge_id and a.venue_id is null and l.venue_id is not null;
  get diagnostics v_ven = row_count;

  update availabilities a
     set program_id = public.pick_host_program(a.host_id, a.venue_id),
         program_source = 'turetildi'
   where a.program_id is null
     and a.venue_id is not null
     and public.pick_host_program(a.host_id, a.venue_id) is not null;
  get diagnostics v_pg = row_count;

  raise notice '215: geriye donuk doldurma → venue_id % satir, program_id % satir', v_ven, v_pg;
end $blok$;


-- ------------------------------------------------------------
-- 1d) `create_availability` SARMALAYICISI — HOST NE KAYDEDİLDİĞİNİ GÖRSÜN
-- ------------------------------------------------------------
-- Tetikleyici kolonu zaten dolduruyor. Sarmalayıcının işi BAŞKA:
-- ilan açan kişiye "bu ilan hangi sözleşme altında sayılacak" bilgisini
-- DÖNMEK. Bugün host bunu hiçbir yerde göremiyor; sağlayıcıya giden
-- rapor onun hak beyanından türetiliyor ve kendisi haberdar değil.
--
-- 🔴 SONEK NEDEN `_base` — TAHMİN DEĞİL, ÜÇ NÖBETÇİDEN ÖLÇÜLDÜ.
-- İlk yazımda `create_availability_prepgm` dedim. Migration yeşil yandı
-- ama İKİ nöbetçi kırmızı yandı ve ikisi de HAKLIYDI:
--   flow_check  → "create_availability: eksik değişmez → ilan→role='host'
--                  promo + arz-talep eşleşme bildirimi"
--   drift_check → "raise not_authenticated / raise slots_exceed_capacity /
--                  update users — 158_device_findings.sql'de vardı"
-- Sebep: her ikisi de sarmalayıcı ZİNCİRİNİ sabit bir sonek listesinden
-- izliyor — `_impl`, `_base`, `_preflag`, `_prebfilter`, `_prerank`,
-- `_prek`. Uydurduğum `_prepgm` o listede yok, zincir kopuyor ve
-- denetimler mantığın SİLİNDİĞİNİ sanıyor.
-- Ders: bu depoda sarmalayıcı soneki bir SÖZLEŞMEdir, bir isimlendirme
-- zevki değil. Nöbetçilerin tanıdığı sonek kullanılır.
--
-- 🔴 GÖVDEYİ YENİDEN YAZMIYORUM. 140'ta `create_request`i sararken
-- gövdeyi grep sonucunun ORTASINDAN aldım ve dört şey birden bozuldu
-- (p_idem düştü, dönüş tipi kaydı, parametre sırası kaydı). Bu depoda
-- kural şu: özgün fonksiyon YENİDEN ADLANDIRILIR, üstüne aynı imzalı
-- ince bir sarmalayıcı konur. Gövde HİÇ KOPYALANMAZ.
--
-- İmza ve dönüş tipi TAHMİN EDİLMİYOR, KATALOGDAN OKUNUYOR:
--   pg_get_function_arguments(oid)              → argüman listesi
--   pg_catalog.format_type(prorettype, null)    → dönüş tipi
-- İkisinden biri beklenenden farklıysa dosya DURUR; sessizce yanlış
-- imzalı bir sarmalayıcı bırakmak, çağıranın 404/42883 almasıdır.
do $blok$
declare
  v_kimlik text;   -- ALTER FUNCTION icin (identity args)
  v_args   text;   -- kayit/karsilastirma icin (default'lar dahil)
  v_ret    text;
  v_beklenen constant text :=
    'p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, '
    'p_to time without time zone, p_slots integer, p_flight text DEFAULT NULL::text, '
    'p_visibility text DEFAULT ''all''::text, p_carrier text DEFAULT NULL::text';
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname = 'create_availability_base') then
    raise notice '215: create_availability_base zaten var — yeniden adlandirma ATLANDI (dosya tekrar calisiyor)';
    return;
  end if;

  select pg_get_function_identity_arguments(p.oid),
         pg_get_function_arguments(p.oid),
         pg_catalog.format_type(p.prorettype, null)
    into v_kimlik, v_args, v_ret
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_availability' and p.prokind = 'f'
   limit 1;

  if v_kimlik is null then
    raise exception '215: create_availability YOK — 071/158 calismamis olabilir';
  end if;
  if v_ret <> 'jsonb' then
    raise exception '215: create_availability donus tipi % — beklenen jsonb. Sarmalama YAPILMADI.', v_ret;
  end if;
  if v_args <> v_beklenen then
    raise exception E'215: create_availability argüman listesi beklenenden FARKLI.\n  canli   : %\n  beklenen: %\n  Sarmalayici bu haliyle yazilirsa cagiran taraf 42883 alir.',
      v_args, v_beklenen;
  end if;

  execute format('alter function public.create_availability(%s) rename to create_availability_base', v_kimlik);
  raise notice '215: create_availability → create_availability_base (imza korundu: %)', v_kimlik;
end $blok$;

create or replace function public.create_availability(
  p_lounge_id uuid,
  p_airport text,
  p_date date,
  p_from time without time zone,
  p_to time without time zone,
  p_slots integer,
  p_flight text default null::text,
  p_visibility text default 'all'::text,
  p_carrier text default null::text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v jsonb; v_id uuid;
  v_pg uuid; v_kaynak text; v_kod text; v_ad text;
begin
  -- Bütün kapılar, kotalar, bildirimler ve rol yükseltmesi _prepgm'de.
  -- Buraya tek bir iş kaldı: SONUCU ANLATMAK.
  v := public.create_availability_base(
         p_lounge_id, p_airport, p_date, p_from, p_to, p_slots,
         p_flight, p_visibility, p_carrier);

  v_id := nullif(v ->> 'id', '')::uuid;
  if v_id is null then
    return v;   -- _prepgm bir sey dondurmediyse uydurmuyoruz
  end if;

  select a.program_id, a.program_source, p.code, p.name
    into v_pg, v_kaynak, v_kod, v_ad
    from availabilities a
    left join lounge_programs p on p.id = a.program_id
   where a.id = v_id;

  return v || jsonb_build_object(
    'program_id',     v_pg,
    'program_kodu',   v_kod,
    'program_adi',    v_ad,
    'program_kaynagi', coalesce(v_kaynak, 'bilinmiyor'),
    -- Host'a gösterilecek cümle. "Türetildi" kelimesi bilinçli:
    -- kullanıcı düzeltebilmeli, ve düzeltebilmesi için önce
    -- ÇIKARIM OLDUĞUNU bilmeli.
    'program_notu', case
      when v_pg is null then
        'Bu ilan bir kart programına bağlanamadı: hak beyanınız bu salonun kabul listesiyle eşleşmiyor. İlan yayında; yalnız sağlayıcı raporunda "program bilinmeyen" sayılacak.'
      when coalesce(v_kaynak, '') = 'turetildi' then
        format('Bu ilan "%s" programı altında sayılacak. Bu bir ÇIKARIM: doğrulanmış hak beyanınızdan türetildi, sizin beyanınız değil.', coalesce(v_ad, v_kod))
      else
        format('Bu ilan "%s" programı altında sayılacak (beyan).', coalesce(v_ad, v_kod))
      end);
end $fn$;


-- ------------------------------------------------------------
-- 1e) Ö7 ARTIK TÜRETİMİ KOLONDAN OKUYOR
-- ------------------------------------------------------------
-- 213'ün gövdesi "program_id dolu = beyan" varsayıyordu; artık dolu
-- olanların büyük kısmı TÜRETİLMİŞ. Sözleşme yenileme toplantısında
-- bu ayrım her şeydir. İmza ve bütün JSON anahtarları aynen korunuyor;
-- değişen YALNIZ üç oranın nereden sayıldığı.
create or replace function public.venue_program_mix(
  p_lounge_id uuid, p_user uuid default null, p_from date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_k int := public.partner_k();
  v_from date;
  v_ven uuid;
  v_ilan int; v_host int; v_dogrudan int; v_turetilen int; v_bilinmeyen int;
  v_satir jsonb; v_gosterilen int;
  v_bilinmeyen_yuzde numeric;
begin
  if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then
    return jsonb_build_object('known', false, 'yetki', false, 'satirlar', '[]'::jsonb,
      'hesaplanabilir', false,
      'bilinmeyen_satiri', 'program bilinmeyen: ölçülemedi (yetki yok)',
      'neden', 'Bu salon için yetkiniz yok ya da partner_channel bayrağı kapalı.');
  end if;

  v_from := coalesce(p_from, current_date - 180);
  select l.venue_id into v_ven from lounges l where l.id = p_lounge_id;

  -- 🔴 ÜÇ SAYAÇ ARTIK `program_source` OKUYOR.
  -- Eski gövde `program_id is not null` görünce "beyan" diyordu; 215
  -- kolonu doldurduğu an bu cümle YALAN olurdu.
  select count(*)::int,
         count(distinct a.host_id)::int,
         count(*) filter (where a.program_id is not null
                            and coalesce(a.program_source, 'beyan') = 'beyan')::int,
         count(*) filter (where a.program_id is not null
                            and a.program_source = 'turetildi')::int,
         count(*) filter (where coalesce(a.program_id,
                                public.pick_host_program(a.host_id, coalesce(a.venue_id, v_ven))) is null)::int
    into v_ilan, v_host, v_dogrudan, v_turetilen, v_bilinmeyen
    from availabilities a
   where a.lounge_id = p_lounge_id
     and a.avail_date >= v_from;

  if coalesce(v_host, 0) < v_k then
    return jsonb_build_object(
      'known', true, 'yetki', true, 'satirlar', '[]'::jsonb,
      'baslangic', v_from, 'k_esigi', v_k,
      'toplam_host', coalesce(v_host, 0),
      'hesaplanabilir', false,
      'bilinmeyen_satiri', format('program bilinmeyen: ölçülemedi (salonda %s host var, eşik %s)',
                                  coalesce(v_host, 0), v_k),
      'neden', format('Bu salonda %s tarihinden bu yana %s farklı host ilan açmış; k-anonimite eşiği %s. Oran bile yayımlanmıyor.',
                      v_from, coalesce(v_host, 0), v_k),
      'not', 'Eşik `beta_settings.partner_k_threshold` ile yönetilir.');
  end if;

  v_bilinmeyen_yuzde := round(coalesce(v_bilinmeyen, 0)::numeric * 100 / nullif(v_ilan, 0), 1);

  select jsonb_agg(x order by (x ->> 'dolan_slot')::int desc,
                              (x ->> 'ilan')::int desc,
                              x ->> 'program'),
         coalesce(sum((x ->> 'ilan')::int), 0)::int
    into v_satir, v_gosterilen
  from (
    select jsonb_build_object(
             'program',      coalesce(p.name, 'Program bilinmiyor'),
             'program_kodu', coalesce(p.code, '—'),
             'bilinmiyor',   p.id is null,
             'host_sayisi',  count(distinct a.host_id)::int,
             'ilan',         count(*)::int,
             'toplam_slot',  coalesce(sum(a.slots), 0)::int,
             'dolan_slot',   coalesce(sum(a.filled), 0)::int,
             'ilan_payi_yuzde', round(count(*)::numeric * 100 / nullif(v_ilan, 0), 1),
             -- YENİ: satır düzeyinde de kaynak kırılımı. "Bu programın
             -- 7 ilanının 7'si çıkarım" cümlesi, tablodaki payı okuyan
             -- kişinin bilmesi gereken tek şeydir.
             'beyan_ilan',    count(*) filter (where coalesce(a.program_source, 'beyan') = 'beyan' and a.program_id is not null)::int,
             'turetilen_ilan', count(*) filter (where a.program_source = 'turetildi')::int
           ) as x
      from availabilities a
      left join lounge_programs p
             on p.id = coalesce(a.program_id,
                                public.pick_host_program(a.host_id, coalesce(a.venue_id, v_ven)))
     where a.lounge_id = p_lounge_id
       and a.avail_date >= v_from
     group by p.id, p.name, p.code
    having count(distinct a.host_id) >= v_k
  ) q;

  return jsonb_build_object(
    'known', true, 'yetki', true,
    'baslangic', v_from, 'k_esigi', v_k,
    'toplam_ilan', coalesce(v_ilan, 0),
    'toplam_host', coalesce(v_host, 0),
    'dogrudan_beyan', coalesce(v_dogrudan, 0),
    'turetilen', coalesce(v_turetilen, 0),
    'program_bilinmeyen', coalesce(v_bilinmeyen, 0),
    'dogrudan_beyan_yuzde', round(coalesce(v_dogrudan, 0)::numeric * 100 / nullif(v_ilan, 0), 1),
    'turetilen_yuzde',      round(coalesce(v_turetilen, 0)::numeric * 100 / nullif(v_ilan, 0), 1),
    'program_bilinmeyen_yuzde', v_bilinmeyen_yuzde,
    -- YENİ: kolonun kendi doluluk oranı. "Ekran neden böyle" sorusunun
    -- cevabı artık ekranın İÇİNDE.
    'kolon_dolulugu', jsonb_build_object(
      'program_id_dolu', coalesce(v_dogrudan, 0) + coalesce(v_turetilen, 0),
      'toplam', coalesce(v_ilan, 0)),
    'bilinmeyen_satiri', format('program bilinmeyen: %%%s', coalesce(v_bilinmeyen_yuzde, 0)),
    'satirlar', coalesce(v_satir, '[]'::jsonb),
    'gosterilen_ilan', coalesce(v_gosterilen, 0),
    'gizlenen_ilan', coalesce(v_ilan, 0) - coalesce(v_gosterilen, 0),
    'kapsam_yuzde', round(coalesce(v_gosterilen, 0)::numeric * 100 / nullif(v_ilan, 0), 1),
    'hesaplanabilir', v_satir is not null,
    'neden', case when v_satir is null
      then format('%s ilan var ama hiçbir program %s farklı host eşiğini geçmedi.', v_ilan, v_k) end,
    'not', format('İlanların %%%s''i programını host hak beyanından TÜRETİLMİŞ olarak taşıyor (215''ten beri kolonda `program_source` ile işaretli). Türetim bir çıkarımdır, beyan değildir.',
                  round(coalesce(v_turetilen, 0)::numeric * 100 / nullif(v_ilan, 0), 1)));
end $fn$;


-- ------------------------------------------------------------
-- 1f) NÖBETÇİ — GERÇEK RPC İLE YAZ, GERİ OKU, BOŞSA PATLA
-- ------------------------------------------------------------
-- 🔴 "Tetikleyiciyi yazdım" bir kanıt DEĞİLDİR. Kanıt: gerçek
-- `create_availability` çağrısıyla satır açmak ve `program_id`'yi geri
-- okumak. Yazmayan bir yazma yolu, olmayan yazma yolundan kötüdür —
-- çünkü yazıldığını sanırsınız.
--
-- 🔴 SAHNEYİ NÖBETÇİ KENDİ KURUYOR VE AYNEN GERİ BIRAKIYOR.
-- İlk yazımda var olan bir host'u seçtim ve nöbetçi `no_access_source`
-- ile düştü. Sonra eleme sayaçları koydum ve GERÇEK SEBEP çıktı:
--     Eleme: ilan=7 · venue'su olan=7 · profili olan=7 · kapasiteli=0
-- Yani 215 çalışırken sistemde YALNIZ 7 ilan var ve hiçbirinin host'u
-- erişim kaynağı beyan etmemiş. 25 ilanlı zengin sahne
-- `SEED_KURAL_SENARYOLARI.sql` ile geliyor — o dosya 215'ten SONRA
-- çalışıyor. "Veri var" varsayımı, o verinin NE ZAMAN geldiğini
-- bilmeden kurulmuş bir varsayımdı.
--
-- Çözüm 213'ün N1 nöbetçisiyle aynı: sahneyi kur, ölç, ESKİ HÂLİNE
-- DÖNDÜR. Kalıcı bir kapasite/doğrulama bırakmak, üründe olmayan bir
-- kullanıcı durumunu üretmek olurdu.
do $blok$
declare
  v_host uuid; v_lounge uuid; v_ven uuid; v_gun date;
  v jsonb; v_id uuid; v_pg uuid; v_src text;
  v_eski_kap int; v_dogrulama_vardi boolean; v_eski_email boolean; v_gecici_prog uuid;
begin
  -- Program çözülebilen ilk (host, salon) — kapasite/doğrulama ARANMIYOR,
  -- onları sahne olarak biz kuracağız.
  select a.host_id, a.lounge_id, l.venue_id
    into v_host, v_lounge, v_ven
    from availabilities a
    join lounges l on l.id = a.lounge_id
    join profiles pr on pr.user_id = a.host_id
   where l.venue_id is not null
     and public.pick_host_program(a.host_id, l.venue_id) is not null
   order by a.host_id, a.lounge_id
   limit 1;

  -- 🔴 SAHNEYİ TAM KURMAK — 214 SONRASI ÖĞRENİLDİ.
  -- Bu blok "programı çözülebilen bir ilan zaten VAR" varsayıyordu ve o
  -- varsayım 214 ile çöktü: 214, kaynaklarda listelenmeyen üç Primeclass
  -- kaydını pasife aldı ve Anatolia/Aeroport'un KAYNAKSIZ TK_MS kabul
  -- satırlarını geri çekti. 215 çalışırken elde kalan yedi ilanın
  -- hiçbirinin programı çözülmüyor — çünkü artık çözülmemesi DOĞRU.
  --
  -- Ders, 213'ün N1 nöbetçisinde yazılanın aynısı ve ikinci kez ısırdı:
  -- bir nöbetçi ÖLÇTÜĞÜ şeyi kendisi kurmalı. Var olan veriye yaslanan
  -- nöbetçi, veri değiştiği gün ürünü değil KENDİNİ kırar.
  -- Aşağısı eksik kalan yarısı: host'a, o salonun GERÇEKTEN kabul ettiği
  -- bir programdan geçici bir hak veriyoruz; blok sonunda geri alınıyor.
  if v_host is null then
    select a.host_id, a.lounge_id, l.venue_id
      into v_host, v_lounge, v_ven
      from availabilities a
      join lounges l  on l.id = a.lounge_id
      join lounge_venues v on v.id = l.venue_id and v.active
      join profiles pr on pr.user_id = a.host_id
     where exists (select 1 from lounge_venue_acceptance x
                    where x.venue_id = l.venue_id and x.accepted and x.active)
     order by a.host_id, a.lounge_id
     limit 1;
    if v_host is not null then
      select x.program_id into v_gecici_prog
        from lounge_venue_acceptance x
        join lounge_programs p on p.id = x.program_id
       where x.venue_id = v_ven and x.accepted and x.active
         and p.kind <> 'airline'          -- kart programı seç, havayolu statüsü değil
       order by p.code limit 1;
      if v_gecici_prog is null then
        select x.program_id into v_gecici_prog from lounge_venue_acceptance x
         where x.venue_id = v_ven and x.accepted and x.active limit 1;
      end if;
      insert into host_entitlements (user_id, program_id, verified, self_reported_at)
      values (v_host, v_gecici_prog, false, now())
      on conflict do nothing;
      raise notice '215: Ö7 sahnesi kuruldu — host''a gecici hak verildi (blok sonunda geri alinacak)';
    end if;
  end if;

  if v_host is null then
    raise exception '215: Ö7 nobetcisi CALISTIRILAMADI. Eleme: ilan=% · venue''su olan=% · profili olan=% · programi cozulen=%',
      (select count(*) from availabilities),
      (select count(*) from availabilities a join lounges l on l.id = a.lounge_id where l.venue_id is not null),
      (select count(*) from availabilities a join lounges l on l.id = a.lounge_id join profiles pr on pr.user_id = a.host_id where l.venue_id is not null),
      (select count(*) from availabilities a join lounges l on l.id = a.lounge_id join profiles pr on pr.user_id = a.host_id where l.venue_id is not null and public.pick_host_program(a.host_id, l.venue_id) is not null);
  end if;

  -- --- SAHNE KURULUYOR (eski hâl kaydediliyor) ---
  select guest_capacity into v_eski_kap from profiles where user_id = v_host;
  select true, email_verified into v_dogrulama_vardi, v_eski_email
    from verifications where user_id = v_host;

  if coalesce(v_eski_kap, 0) < 1 then
    update profiles set guest_capacity = 1 where user_id = v_host;
  end if;
  insert into verifications (user_id, email_verified, email_verified_at)
  values (v_host, true, now())
  on conflict (user_id) do update set email_verified = true, email_verified_at = now();

  -- Gelecekte, çakışmayan bir saat aralığı seç (create_availability
  -- geçmiş tarihi ve örtüşen slotu reddediyor — haklı olarak).
  v_gun := current_date + 300;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_host, 'role', 'authenticated')::text, true);

  v := public.create_availability(v_lounge, (select airport_code from lounges where id = v_lounge),
                                  v_gun, time '03:00', time '04:00', 1, null, 'hidden', null);
  perform set_config('request.jwt.claims', '', true);

  v_id := nullif(v ->> 'id', '')::uuid;
  if v_id is null then
    raise exception '215: Ö7 nobetcisi — create_availability id DONDURMEDI → %', v;
  end if;

  select program_id, program_source into v_pg, v_src from availabilities where id = v_id;

  if v_pg is null then
    raise exception '215: Ö7 KIRIK — gercek RPC ile acilan ilanin program_id degeri HALA NULL (ilan %). Tetikleyici yazmiyor.', v_id;
  end if;
  if v_src is distinct from 'turetildi' then
    raise exception '215: Ö7 KIRIK — program_source "turetildi" olmali, bulunan "%"; cikarim beyan gibi kaydediliyor.', v_src;
  end if;
  if (v ->> 'program_kaynagi') <> 'turetildi' then
    raise exception '215: Ö7 — RPC cevabi kaynagi SOYLEMIYOR → %', v;
  end if;

  raise notice '215: Ö7 KANIT — gercek create_availability cagrisi program_id=% (kaynak=%) yazdi', v_pg, v_src;

  -- --- SAHNE TOPLANIYOR — üründe hiçbir iz kalmıyor ---
  delete from availabilities where id = v_id;
  if v_gecici_prog is not null then
    delete from host_entitlements where user_id = v_host and program_id = v_gecici_prog;
  end if;
  update profiles set guest_capacity = v_eski_kap where user_id = v_host;
  if coalesce(v_dogrulama_vardi, false) then
    update verifications set email_verified = v_eski_email where user_id = v_host;
  else
    delete from verifications where user_id = v_host;
  end if;
end $blok$;


-- ============================================================
-- 2) Ö8 · FİYAT KATALOĞU — KAYNAKTAN, SATIR SATIR ALINTIYLA
-- ============================================================
-- 🔴 TEK KURAL: BU DOSYAYA UYDURULMUŞ TEK BİR FİYAT GİRMEZ.
-- Her satır /home/claude/kaynak/tur11/THY_AJET_PGS_KURAL.md içinde
-- BİREBİR YAZAN bir cümleden geliyor ve o cümle `note` kolonunda
-- tırnak içinde duruyor. Kaynağı olmayan salon LİSTEDE YOK — ve
-- raporun "bu salonun fiyat kaydı yok" demesi doğru davranıştır.
--
-- KAYNAKTA OLUP BURAYA GİRMEYENLER (ve sebebi — gizlemiyoruz):
--   · "Primeclass Lounge / Zürih Havalimanı : 40 CHF"  → ZRH'de
--     katalogda Primeclass YOK (yalnız "Aspire Lounge"). Salon eşleşmezse
--     fiyatı bir başkasına yazmak, fiyatı uydurmakla aynı şeydir.
--   · "Primeclass Lounge /Frankfurt Havalimanı : 36 EUR" → FRA'da
--     katalogda Primeclass YOK.
--   · "HelloSky Lounge / Milan Bergamo : 28 EUR", "… / Roma Fiumicino :
--     20 EUR" → katalogda HelloSky adlı salon YOK (FCO'da Plaza Premium var).
--   · AJet'in "Sabiha Gökçen Uluslararası Havalimanı*" satırı → fiyat
--     hücresi kaynakta "-" (salon geçici kapalı). Boş hücre fiyat değildir.
--
-- ⚠️ PARA BİRİMİ ÇEVRİLMİYOR. 27 EUR ile 2.800 TL aynı satırda
-- toplanmaz; `venue_price_position` zaten para birimine göre gruplar.
-- Kur uydurmak, fiyat uydurmaktır.

-- Kaynak eşlemesi salon ADI + HAVALİMANI ile yapılıyor, UUID ile değil:
-- `lounge_venues.id` her tam kurulumda yeniden üretiliyor (uuid_generate_v4),
-- sabit uuid yazmak dosyayı ikinci çalıştırmada sessizce boşa düşürürdü.
do $blok$
declare
  v_kayit int := 0;
  v_eslesmeyen text;
  v_pgs constant text := 'https://www.flypgs.com/seyahat-hizmetlerimiz/diger-seyahat-hizmetlerimiz/lounge';
  v_thy constant text := 'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/';
  v_tarih constant date := date '2026-08-17';
begin
  create temp table if not exists _fiyat_kaynak (
    ap text, salon text, kod text, ad text, tutar numeric, para text, kaynak text, aciklama text,
    venue_id uuid,         -- 18 Agu: cozumleme adimi eklendi, asagiya bak
    kademe text            -- hangi kademe cozdu (K4 ayrica kuyruga dusuyor)
  ) on commit drop;
  delete from _fiyat_kaynak;

  insert into _fiyat_kaynak (ap, salon, kod, ad, tutar, para, kaynak, aciklama) values
  -- ---------- PEGASUS · flypgs.com "Havaalanı Lounge" ----------
  ('SAW', 'Plaza Premium Lounge — İç Hat', 'ENTRY_DOM', 'İç hat salon girişi', 49, 'EUR', v_pgs,
   'Kaynak: "Plaza Premium Lounge / İç Hatlar        : 49 Euro" · "Fiyatlara KDV dahildir." · "Dış Hat ve İç Hat kullanım ücretleri 3 saat için geçerlidir." (Pegasus misafirlerine özel indirimli fiyat).'),
  -- Kaynak SAW dış hat için TEK fiyat basıyor; bizim katalogda o salon
  -- iki AYRI salon olarak duruyor (Bosphorus ve Marmara). İkisine de
  -- aynı satır yazılıyor ve bu ayrım burada AÇIKÇA söyleniyor.
  ('SAW', 'Plaza Premium Bosphorus Lounge — Dış Hat', 'ENTRY_INT', 'Dış hat salon girişi', 63, 'EUR', v_pgs,
   'Kaynak: "Plaza Premium Lounge / Dış Hatlar      : 63 Euro" · "Fiyatlara KDV dahildir." · 3 saat. ⚠️ Kaynak SAW dış hat için TEK fiyat basıyor; katalogda bu salon iki ayrı salon (Bosphorus / Marmara) olarak duruyor, ikisine de aynı fiyat yazıldı.'),
  ('SAW', 'Plaza Premium Lounge — Marmara — Dış Hat', 'ENTRY_INT', 'Dış hat salon girişi', 63, 'EUR', v_pgs,
   'Kaynak: "Plaza Premium Lounge / Dış Hatlar      : 63 Euro" · "Fiyatlara KDV dahildir." · 3 saat. ⚠️ Kaynak SAW dış hat için TEK fiyat basıyor; katalogda bu salon iki ayrı salon (Bosphorus / Marmara) olarak duruyor, ikisine de aynı fiyat yazıldı.'),

  ('ADB', 'Primeclass Lounge — İç Hat', 'ENTRY_DOM', 'İç hat salon girişi', 27, 'EUR', v_pgs,
   'Kaynak: "Primeclass Lounge / İzmir Adnan Menderes Havalimanı: 27 EUR + KDV" — ⚠️ KDV HARİÇ. "Lounge kullanım süresi 3 saat ile sınırlıdır." Kaynak iç/dış ayırmıyor; Lokasyon bölümü aynı salon için hem "İç Hatlar:" hem "Dış Hatlar:" satırı veriyor.'),
  ('ADB', 'Primeclass Lounge — Dış Hat', 'ENTRY_INT', 'Dış hat salon girişi', 27, 'EUR', v_pgs,
   'Kaynak: "Primeclass Lounge / İzmir Adnan Menderes Havalimanı: 27 EUR + KDV" — ⚠️ KDV HARİÇ. "Lounge kullanım süresi 3 saat ile sınırlıdır." Kaynak iç/dış ayırmıyor; Lokasyon bölümü aynı salon için hem "İç Hatlar:" hem "Dış Hatlar:" satırı veriyor.'),
  ('ESB', 'Primeclass Lounge — İç Hat', 'ENTRY_DOM', 'İç hat salon girişi', 27, 'EUR', v_pgs,
   'Kaynak: "Primeclass Lounge / Ankara Esenboğa Havalimanı: 27 EUR + KDV" — ⚠️ KDV HARİÇ. "Lounge kullanım süresi 3 saat ile sınırlıdır."'),
  ('ESB', 'Primeclass Lounge — Dış Hat', 'ENTRY_INT', 'Dış hat salon girişi', 27, 'EUR', v_pgs,
   'Kaynak: "Primeclass Lounge / Ankara Esenboğa Havalimanı: 27 EUR + KDV" — ⚠️ KDV HARİÇ. "Lounge kullanım süresi 3 saat ile sınırlıdır."'),
  ('BJV', 'Primeclass Lounge — İç Hat', 'ENTRY_DOM', 'İç hat salon girişi', 27, 'EUR', v_pgs,
   'Kaynak: "Primeclass Lounge / Milas-Bodrum Havalimanı: 27 EUR + KDV" — ⚠️ KDV HARİÇ. "Lounge kullanım süresi 3 saat ile sınırlıdır."'),
  ('BJV', 'Primeclass Lounge — Dış Hat', 'ENTRY_INT', 'Dış hat salon girişi', 27, 'EUR', v_pgs,
   'Kaynak: "Primeclass Lounge / Milas-Bodrum Havalimanı: 27 EUR + KDV" — ⚠️ KDV HARİÇ. "Lounge kullanım süresi 3 saat ile sınırlıdır."'),

  ('COV', 'Çelebi Platinum Lounge — İç Hat', 'ENTRY_DOM', 'İç hat salon girişi', 1260, 'TRY', v_pgs,
   'Kaynak: "İç Hat Çelebi Platinum Lounge = 1260 TL (KDV Dahil)" · "Yetişkin yanında gelen 6 yaşına kadar olan çocuklardan ücret alınmayacaktır." (Pegasus misafirlerine özel indirimli fiyat).'),
  ('COV', 'Çelebi Platinum Lounge — Dış Hat', 'ENTRY_INT', 'Dış hat salon girişi', 49.5, 'EUR', v_pgs,
   'Kaynak: "Dış Hat Çelebi Platinum Lounge = 49,5 EUR (KDV Dahil)" · "Yetişkin yanında gelen 6 yaşına kadar olan çocuklardan ücret alınmayacaktır."'),

  ('TBS', 'Primeclass', 'ENTRY_INT', 'Dış hat salon girişi', 44, 'EUR', v_pgs,
   'Kaynak: "Primeclass Lounge / Tiflis Havalimanı : 44 EUR (KDV Dahil)" · "Lounge kullanım süresi 3 saat ile sınırlıdır."'),
  ('SKP', 'TAV Primeclass Lounge', 'ENTRY_INT', 'Dış hat salon girişi', 32, 'EUR', v_pgs,
   'Kaynak: "Primeclass Lounge / Üsküp Havalimanı : 32 EUR (KDV Dahil)" · "Lounge kullanım süresi 3 saat ile sınırlıdır."'),
  ('MCT', 'Primeclass', 'ENTRY_INT', 'Dış hat salon girişi', 20, 'OMR', v_pgs,
   'Kaynak: "Primeclass Lounge / Maskat Havalimanı : 20 OMR (KDV Dahil)" · "Lounge kullanım süresi 3 saat ile sınırlıdır."'),

  -- ---------- THY · kendi salonlarının ÜCRETLİ KULLANIM tarifesi ----------
  -- ⚠️ Bu satırlar GENEL giriş ücreti DEĞİL: Miles&Smiles Classic kart
  -- sahibinin ödediği tarife. Ayrı bir item_code ile duruyorlar ki
  -- Pegasus'un walk-in fiyatıyla aynı satırda toplanmasınlar.
  ('IST', 'Turkish Airlines Lounge — İç Hat', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 3000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 3.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — İstanbul Havalimanı) · geçerlilik: "1 Haziran 2026 - 31 Aralık 2026 tarihleri arasında geçerli olmak üzere;" · aynı tabloda "Classic Plus Card Sahibi Yolcu | Ücretsiz".'),
  ('IST', 'Turkish Airlines Lounge — İç Hat (Business)', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 3000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 3.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — İstanbul Havalimanı). Aynı havalimanında iki bölüm var: "Bazı istasyonlarda iç hat özel yolcu salonları iki (2) farklı bölümden oluşmaktadır." Tarife bölüm ayırmıyor.'),

  ('AYT', 'Turkish Airlines Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2800, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.800 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Antalya, Adnan Menderes, Milas-Bodrum, Dalaman, Ankara Esenboğa) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('ADB', 'Turkish Airlines Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2800, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.800 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Antalya, Adnan Menderes, Milas-Bodrum, Dalaman, Ankara Esenboğa) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('ESB', 'Turkish Airlines Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2800, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.800 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Antalya, Adnan Menderes, Milas-Bodrum, Dalaman, Ankara Esenboğa) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('DLM', 'Turkish Airlines CIP Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2800, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.800 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Antalya, Adnan Menderes, Milas-Bodrum, Dalaman, Ankara Esenboğa) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('BJV', 'Milas-Bodrum Havalimanı iç hatlar özel yolcu salonu', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2800, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.800 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Antalya, Adnan Menderes, Milas-Bodrum, Dalaman, Ankara Esenboğa) · "1 Haziran 2026 - 31 Aralık 2026".'),

  ('COV', 'Turkish Airlines CIP Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Çukurova, Kayseri, Gaziantep, Hatay, Trabzon, Rize-Artvin, Diyarbakır) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('ASR', 'Turkish Airlines CIP Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Çukurova, Kayseri, Gaziantep, Hatay, Trabzon, Rize-Artvin, Diyarbakır) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('GZT', 'Turkish Airlines CIP Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Çukurova, Kayseri, Gaziantep, Hatay, Trabzon, Rize-Artvin, Diyarbakır) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('HTY', 'Turkish Airlines CIP Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Çukurova, Kayseri, Gaziantep, Hatay, Trabzon, Rize-Artvin, Diyarbakır) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('TZX', 'Turkish Airlines CIP Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Çukurova, Kayseri, Gaziantep, Hatay, Trabzon, Rize-Artvin, Diyarbakır) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('RZV', 'Turkish Airlines CIP Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Çukurova, Kayseri, Gaziantep, Hatay, Trabzon, Rize-Artvin, Diyarbakır) · "1 Haziran 2026 - 31 Aralık 2026".'),
  ('DIY', 'Turkish Airlines CIP Lounge', 'ENTRY_DOM_MS_CLASSIC', 'İç hat girişi — M&S Classic (ücretli)', 2000, 'TRY', v_thy,
   'Kaynak: "Classic Card Sahibi Yolcu | 2.000 TL" (İÇ HAT ÖZEL YOLCU SALONLARI — Çukurova, Kayseri, Gaziantep, Hatay, Trabzon, Rize-Artvin, Diyarbakır) · "1 Haziran 2026 - 31 Aralık 2026".'),

  ('VKO', 'Istanbul-Moscow', 'ENTRY_INT_MS_CLASSIC', 'Dış hat girişi — M&S Classic (ücretli)', 50, 'USD', v_thy,
   'Kaynak: "DIŞ HAT ÖZEL YOLCU SALONU — Vnukovo Uluslararası Havalimanı" sütununda "Classic Card Sahibi Yolcu | 50 USD" ve "Classic Plus Card Sahibi Yolcu | 50 USD". THY''nin BASILI fiyatı olan TEK dış hat salonu.');

  -- ── SALON ÇÖZÜMLEME ────────────────────────────────────────────
  -- 🔴 ESKİDEN BİREBİR AD EŞİTLİĞİYDİ (`v.name = k.salon`) VE KIRILGANDI.
  -- Gökberk'te şu çıktı:
  --     215: fiyat kaynagi ile katalog ESLESMEDI →
  --          ESB / Primeclass Lounge — Dış Hat | IST / Turkish Airlines Lounge — İç Hat
  -- Salon adları bu projede sürekli normalleşiyor (190 kanonik ada
  -- çeviriyor, 211 birleştirmeleri geri alıyor, 214a iç hat kayıtlarını
  -- tamamlıyor). Fiyat tablosunun bir metin sabitine bağlı kalması, her
  -- ad düzenlemesinde kurulumu durduran bir bağ demek.
  --
  -- Nöbetçiyi KALDIRMIYORUM — haklı, fiyat sessizce düşmemeli. Yaptığım
  -- şey eşleştirmeyi ada değil KİMLİĞE bağlamak:
  --   K1  birebir ad (eski davranış, hâlâ ilk sırada)
  --   K2  aynı havalimanı + aynı MARKA + fiyatın KENDİ KAPSAMI
  --
  -- Kapsam fiyat kodundan geliyor: `ENTRY_DOM*` → domestic,
  -- `ENTRY_INT*` → international. Yani iç hat fiyatı ASLA dış hat
  -- salonuna yazılamaz; gevşetme değil, doğru eksende sıkılaştırma.
  update _fiyat_kaynak k
     set venue_id = v.id, kademe = 'K1 birebir ad'
    from lounge_venues v
   where v.airport_code = k.ap and v.name = k.salon and coalesce(v.active, true);

  -- ⚠️ `update ... from lateral(...)` YAZMISTIM: UPDATE'in hedef tablosu
  -- FROM icindeki LATERAL'dan gorunmuyor → "invalid reference to
  -- FROM-clause entry for table k". Bagimli alt sorgu dogru bicim.
  update _fiyat_kaynak k
     set kademe = 'K2 marka+kapsam',
         venue_id = (
       select v.id
         from lounge_venues v
        where v.airport_code = k.ap
          and coalesce(v.active, true)
          and public.cns_brand(v.name) = public.cns_brand(k.salon)
          and coalesce(v.scope,'both') = case when k.kod like 'ENTRY_DOM%'
                                              then 'domestic' else 'international' end
        limit 1)
   where k.venue_id is null
     and 1 = (select count(*) from lounge_venues v2
               where v2.airport_code = k.ap
                 and coalesce(v2.active, true)
                 and public.cns_brand(v2.name) = public.cns_brand(k.salon)
                 and coalesce(v2.scope,'both') = case when k.kod like 'ENTRY_DOM%'
                                                      then 'domestic' else 'international' end);

  -- K3: BÖLÜM (section) AYRIMI — kaynağın kendi kodundan gelir.
  -- IST'te iki iç hat THY salonu var: {bolum=business} ve
  -- {bolum=miles_smiles}. Marka+kapsam ikisini de getiriyor, yani K2
  -- kararsız kalıyor. Ama fiyat kodu bunu ZATEN söylüyor:
  --     ENTRY_DOM_MS_CLASSIC  → "M&S Classic" → bolum=miles_smiles
  -- Yani ayrımı ben uydurmuyorum, kaynağın kod adından okuyorum.
  -- Kod bölüm belirtmiyorsa bölümsüz (genel) salon seçilir.
  update _fiyat_kaynak k
     set kademe = 'K3 marka+kapsam+bolum',
         venue_id = (
       select v.id
         from lounge_venues v
        where v.airport_code = k.ap
          and coalesce(v.active, true)
          and public.cns_brand(v.name) = public.cns_brand(k.salon)
          and coalesce(v.scope,'both') = case when k.kod like 'ENTRY_DOM%'
                                              then 'domestic' else 'international' end
          and coalesce(v.section,'') = case when k.kod like '%\_MS\_%' then 'miles_smiles'
                                            when k.kod like '%\_BUS%'  then 'business'
                                            else '' end
        limit 1)
   where k.venue_id is null
     and 1 = (select count(*) from lounge_venues v2
               where v2.airport_code = k.ap
                 and coalesce(v2.active, true)
                 and public.cns_brand(v2.name) = public.cns_brand(k.salon)
                 and coalesce(v2.scope,'both') = case when k.kod like 'ENTRY_DOM%'
                                                      then 'domestic' else 'international' end
                 and coalesce(v2.section,'') = case when k.kod like '%\_MS\_%' then 'miles_smiles'
                                                    when k.kod like '%\_BUS%'  then 'business'
                                                    else '' end);

  -- K4: BÖLÜNMEMİŞ KAYIT (`scope='both'`) — 18 Ağustos 2026.
  -- Gökberk'te K3'ten sonra ESB kaldı ve mesaj sebebini yazdı:
  --     ESB "Primeclass Lounge — Dış Hat" [kod=ENTRY_INT → kapsam=international]
  --       · adaylar: Primeclass CIP Lounge {kapsam=both} ,
  --                  Primeclass Lounge — İç Hat {kapsam=domestic}
  -- Yani onun katalogunda ESB Primeclass'ı İÇ/DIŞ diye BÖLÜNMEMİŞ; tek
  -- kayıt "both" kapsamıyla duruyor. Temiz kurulumda 099 onu ikiye
  -- ayırıyor, onda ayrılmamış.
  --
  -- Bu kaydı bölmüyorum. Sebebi: 211'in kart ağı eşleştiricisi ZATEN o
  -- "both" kaydına bağlanmış durumda (onun 214'ü geçti). Şimdi bölersem
  -- o bağları öksüz bırakırım — veriyi düzeltirken başka bir yeri bozmak.
  -- Fiyat da aynı kayda yazılıyor; kart ağı kabulüyle aynı salonu
  -- gösteriyor, yani ikisi tutarlı kalıyor.
  --
  -- Kapsam ∪ 'both' — kart ağı eşleştiricisinin K3'üyle AYNI kural.
  -- (Aynı mantığın iki dosyada iki kez yazılması hoşuma gitmiyor;
  --  kurulumdan sonra `cns_eslestir()` ile birlikte tek yere alınacak.)
  update _fiyat_kaynak k
     set kademe = 'K4 bolunmemis kayit',
         venue_id = (
       select v.id
         from lounge_venues v
        where v.airport_code = k.ap
          and coalesce(v.active, true)
          and public.cns_brand(v.name) = public.cns_brand(k.salon)
          and coalesce(v.scope,'both') = 'both'
        limit 1)
   where k.venue_id is null
     and 1 = (select count(*) from lounge_venues v2
               where v2.airport_code = k.ap
                 and coalesce(v2.active, true)
                 and public.cns_brand(v2.name) = public.cns_brand(k.salon)
                 and coalesce(v2.scope,'both') = 'both');

  -- Bölünmemiş kayda fiyat yazdıysak bunu KAYDA GEÇ: katalog olması
  -- gerekenden az hassas ve bu, host'a "hangi salon" derken belirsizlik
  -- üretebilir. Sessizce geçmek yerine BO kuyruğuna düşüyor.
  insert into venue_review_queue (venue_id, konu, gerekce)
  select distinct k.venue_id, 'bolunmemis-kayit',
         format('215: "%s" fiyati bu kayda yazildi ama kayit scope=both, yani ic/dis hat '
                'ayrimi yapilmamis. Kaynak ayri ayri ic hat ve dis hat salonu listeliyor; '
                'kayit ikiye ayrilirsa fiyat ve kabul satirlari da ayrilmali.', k.salon)
    from _fiyat_kaynak k
    join lounge_venues v on v.id = k.venue_id
   where k.venue_id is not null
     and k.kademe = 'K4 bolunmemis kayit'   -- 🔴 YALNIZ GERI CEKILDIGIMIZ satirlar.
     -- Ilk surumde "scope=both olan HER salon" diyordum ve bes kayit
     -- dustu; ucu adiyla birebir eslesen, zaten dogru salonlardi.
     -- Yanlis alarm ureten bir kuyruk, okunmayan bir kuyruk olur.
  on conflict (venue_id, konu) do nothing;

  -- 🔴 EŞLEŞMEYEN SATIR SESSİZCE DÜŞMEZ. Salon adı ileride değişirse
  -- fiyat kaydı yok olur ve Ö8 sebebini söyleyemeden küçülür. Bu yüzden
  -- eşleşmeyen varsa dosya DURUR — ama artık NE BULDUĞUNU da yazar
  -- (Supabase `raise notice` göstermiyor; bilgi hatanın içinde olmalı).
  select string_agg(
           format('%s "%s" [kod=%s → kapsam=%s] · katalogdaki adaylar: %s',
             k.ap, k.salon, k.kod,
             case when k.kod like 'ENTRY_DOM%' then 'domestic' else 'international' end,
             coalesce((select string_agg(v.name || ' {kapsam=' || coalesce(v.scope,'-')
                                         || ' bolum=' || coalesce(v.section,'-') || '}', ' , ')
                         from lounge_venues v
                        where v.airport_code = k.ap and coalesce(v.active,true)
                          and public.cns_brand(v.name) = public.cns_brand(k.salon)),
                      'ADAY YOK')), '  ||  ')
    into v_eslesmeyen
    from _fiyat_kaynak k
   where k.venue_id is null;
  if v_eslesmeyen is not null then
    -- ⚠️ `raise`'de bicim belirteci YALNIZ `%`. `%s` yazmistim ve mesaj
    -- ortadan kesildi; yani teshis tasimak icin yazdigim satir teshisi
    -- yutuyordu.
    raise exception '215: fiyat kaynagi ile katalog ESLESMEDI. Fiyat sessizce dusmesin diye duruyorum: %', v_eslesmeyen;
  end if;

  insert into venue_prices (venue_id, item_code, item_name, price, currency, unit, note, source_url, checked_at, active)
  select v.id, k.kod, k.ad, k.tutar, k.para, 'giris', k.aciklama, k.kaynak, v_tarih, true
    from _fiyat_kaynak k
    join lounge_venues v on v.id = k.venue_id
  on conflict (venue_id, item_code) do update
    set item_name = excluded.item_name,
        price      = excluded.price,
        currency   = excluded.currency,
        unit       = excluded.unit,
        note       = excluded.note,
        source_url = excluded.source_url,
        checked_at = excluded.checked_at,
        active     = true;
  get diagnostics v_kayit = row_count;

  raise notice '215: venue_prices — % satir kaynaktan yazildi', v_kayit;
end $blok$;


-- ------------------------------------------------------------
-- 2b) NÖBETÇİ — Ö8 GERÇEKTEN KARŞILAŞTIRABİLİYOR MU
-- ------------------------------------------------------------
-- Fiyat eklemek yetmez; ekranın "karşılaştırılabilir" demesi gerekiyor.
-- Karşılaştırma kümesi = aynı havalimanı + aynı venue_kind + BAŞKA salon.
do $blok$
declare v_n int; v_ap text; v_salon int;
begin
  select count(*) into v_n from venue_prices where active;
  if v_n < 20 then
    raise exception '215: Ö8 KIRIK — venue_prices yalniz % satir; katalog yazilmamis.', v_n;
  end if;

  -- En az bir havalimanında, aynı türde EN AZ İKİ salon fiyat taşımalı;
  -- yoksa "fiyat konumu" diye bir şey yok, yalnız kendi fiyatımız var.
  select v.airport_code, count(distinct vp.venue_id)
    into v_ap, v_salon
    from venue_prices vp join lounge_venues v on v.id = vp.venue_id
   where vp.active and coalesce(v.active, true)
   group by v.airport_code, v.venue_kind
   having count(distinct vp.venue_id) >= 2
   order by count(distinct vp.venue_id) desc, v.airport_code
   limit 1;

  if v_ap is null then
    raise exception '215: Ö8 KIRIK — hicbir havalimaninda ayni turde iki fiyatli salon yok; karsilastirma hala imkansiz.';
  end if;
  raise notice '215: Ö8 KANIT — % havalimaninda % salon fiyat tasiyor (toplam % satir)', v_ap, v_salon, v_n;
end $blok$;


-- ============================================================
-- 3) Ö9 · AMAÇ, SEYAHAT TARZI VE `quiet_zone`
-- ============================================================

-- ------------------------------------------------------------
-- 3a) OLANAK SÖZLÜĞÜ ARTIK BİR TABLO — VE `quiet_zone` İÇİNDE
-- ------------------------------------------------------------
-- 🔴 ÖLÇTÜM: olanak anahtarları HİÇBİR YERDE TANIMLI DEĞİLDİ.
-- `lounge_venues.amenities` serbest bir jsonb; anahtar listesi iki
-- ayrı kaynak dosyada ELLE tekrarlanıyor (app AMENITY_ICONS, BO
-- AMENITY_KEYS). Şemada sayım:
--   food 78 · wifi 78 · extra 23 · work 23 · bar 23 · kids 21 ·
--   buffet 19 · games 17 · shower 13 · prayer 13 · cinema 11 ·
--   sleep 11 · tv 8 · terrace 6 · nursery 2 · luggage 2
-- `quiet_zone` YOK — 213 bunu doğru tespit etmiş ve 'zen' talebini
-- ölçülemez bırakmıştı.
--
-- Sözlük artık tek yerde. Böylece "bu anahtar var mı" sorusu, iki
-- JS dosyasının hafızasına değil, veriye sorulur.
create table if not exists amenity_keys (
  key        text primary key,
  label_tr   text not null,
  sira       int  not null default 100,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

insert into amenity_keys (key, label_tr, sira) values
  ('wifi', 'Wi-Fi', 10), ('food', 'Yiyecek', 20), ('buffet', 'Açık büfe', 30),
  ('bar', 'Bar', 40), ('shower', 'Duş', 50), ('sleep', 'Dinlenme', 60),
  ('kids', 'Çocuk alanı', 70), ('prayer', 'Mescit', 80), ('work', 'Çalışma', 90),
  ('tv', 'TV', 100), ('terrace', 'Teras', 110), ('cinema', 'Sinema', 120),
  ('games', 'Oyun', 130), ('luggage', 'Emanet', 140), ('nursery', 'Bebek bakım', 150),
  ('extra', 'Diğer (serbest liste)', 900),
  -- 🔴 YENİ VE BİLEREK BOŞ: sözlükte var, hiçbir salonda BEYAN EDİLMEMİŞ.
  -- Uydurup "şu salonda sessiz alan var" demek, bu dosyanın var oluş
  -- sebebine aykırı olurdu. Anahtarın varlığı boşluğun ÖLÇÜLEBİLİR
  -- olmasını sağlar; doluluğu ise sahadan gelecek.
  ('quiet_zone', 'Sessiz alan', 160)
on conflict (key) do update set label_tr = excluded.label_tr, sira = excluded.sira, active = true;

alter table amenity_keys enable row level security;
drop policy if exists ak_read on amenity_keys;
create policy ak_read on amenity_keys for select to anon, authenticated using (active);

create or replace function public.amenity_key_options()
returns table (key text, label_tr text, sira int, salon_sayisi int)
language sql stable security definer set search_path = public as $fn$
  select k.key, k.label_tr, k.sira,
         (select count(*)::int from lounge_venues v
           where coalesce(v.active, true)
             and (v.amenities -> k.key)::text = 'true') as salon_sayisi
    from amenity_keys k
   where k.active
   order by k.sira, k.key;
$fn$;

-- ------------------------------------------------------------
-- 3b) `set_visit_purpose` — VAR OLAN SEYAHATE AMAÇ YAZMA YOLU
-- ------------------------------------------------------------
-- ÖLÇÜM: uygulamada seyahat iki yerden yazılıyor ve amaç yalnız birinde
-- var. Ayrıca kaydedilmiş bir seyahatin amacını SONRADAN yazmanın hiç
-- yolu yoktu. `set_visit_carrier` / `set_visit_charter` ile birebir
-- aynı kalıp — sahibi kontrol edilir, başkasının seyahatine yazılamaz.
--
-- ⚠️ AMAÇ ZORUNLU DEĞİL (132'nin kararı: boş bırakan cezalandırılmaz).
-- Bu yüzden NULL geçerli bir değer: kullanıcı beyanını GERİ ALABİLİR.
create or replace function public.set_visit_purpose(p_visit_id uuid, p_purpose text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_sahip uuid; v_deger text;
begin
  select user_id into v_sahip from visits where id = p_visit_id;
  if v_sahip is null then raise exception 'visit_not_found'; end if;
  if v_sahip <> auth.uid() then raise exception 'not_owner'; end if;

  v_deger := nullif(trim(coalesce(p_purpose, '')), '');
  -- Kontrol burada da yapılıyor: tablo kısıtı zaten var ama kullanıcıya
  -- 23514 yerine anlaşılır bir hata dönmek istiyoruz.
  if v_deger is not null
     and v_deger not in ('business', 'conference', 'leisure', 'connecting', 'event') then
    raise exception 'bad_purpose';
  end if;

  update visits set purpose = v_deger where id = p_visit_id;
  return jsonb_build_object('ok', true, 'purpose', v_deger);
end $fn$;


-- ------------------------------------------------------------
-- 3c) Ö9 · 'zen' ARTIK ÖLÇÜLEBİLİR — VE ÜÇ DURUMLU
-- ------------------------------------------------------------
-- 🔴 BURADA İKİNCİ BİR YALAN TUZAĞI VARDI.
-- Sadece haritayı 'zen' → 'quiet_zone' yapsaydım, gövde şunu diyor:
--     coalesce((v_ola -> anahtar)::text = 'true', false)
-- Yani anahtar jsonb'de HİÇ YOKSA da `false` döner ve ekran
-- "sessiz alan YOK" der. Oysa doğru cümle "BEYAN EDİLMEMİŞ".
-- Bilinmeyeni yokluk gibi göstermek, sağlayıcıya olmayan bir eksiği
-- kapattırmaktır. Bu yüzden üç durum ayrıldı:
--     var_mi = true   → salon "var" demiş
--     var_mi = false  → salon açıkça "yok" demiş
--     var_mi = null   → salon HİÇ BEYAN ETMEMİŞ (beyan_edildi=false)
--
-- İmza ve var olan bütün JSON anahtarları korunuyor.
create or replace function public.venue_guest_profile(
  p_lounge_id uuid, p_user uuid default null, p_gun int default 180)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_k int := public.partner_k();
  v_ap text; v_ola jsonb;
  v_misafir int; v_amac_beyan int; v_tarz_beyan int;
  v_beyan jsonb;
  v_amac jsonb; v_tarz jsonb; v_bosluk jsonb;
  v_sozluk_var boolean;
  -- Talep → katalog olanak anahtarı. 215'ten beri 'zen' KARŞILIĞI VAR:
  -- `quiet_zone` sözlüğe (amenity_keys) eklendi.
  -- 'explorer' hâlâ NULL: "havalimanı kaşifi" bir salon olanağı değil,
  -- bir davranış. Ona karşılık bir anahtar UYDURMUYORUZ.
  v_harita constant jsonb := jsonb_build_object(
    'business',  'work',
    'conference','work',
    'leisure',   'food',
    'connecting','shower',
    'event',     'bar',
    'social',    'bar',
    'foodie',    'buffet',
    'zen',       'quiet_zone',
    'explorer',  null::text
  );
begin
  if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then
    return jsonb_build_object('known', false, 'yetki', false,
      'amac_satirlari', '[]'::jsonb, 'tarz_satirlari', '[]'::jsonb, 'olanak_bosluklari', '[]'::jsonb,
      'hesaplanabilir', false,
      'neden', 'Bu salon için yetkiniz yok ya da partner_channel bayrağı kapalı.');
  end if;

  select l.airport_code into v_ap from lounges l where l.id = p_lounge_id;
  v_ola := public.venue_amenities(p_lounge_id);

  select jsonb_agg(jsonb_build_object('amac', z.amac, 'tarz', z.tarz))
    into v_beyan
  from (
    select m.uid,
           -- 215: `requests.visit_id` artık DOLU (tetikleyici + geriye
           -- dönük doldurma). Önce DOĞRUDAN bağ denenir; yoksa eski
           -- yedek eşleme (kişinin bu havalimanındaki en yakın beyanı)
           -- devrede kalır ve cevabın notunda hangisinin kullanıldığı yazar.
           coalesce(
             (select v.purpose from visits v
               where v.id = m.visit_id and v.purpose is not null),
             (select v.purpose from visits v
               where v.user_id = m.uid
                 and v.airport_code = v_ap
                 and v.visit_date >= current_date - p_gun
                 and v.purpose is not null
               order by v.visit_date desc, v.id
               limit 1)) as amac,
           (select pr.travel_style from profiles pr
             where pr.user_id = m.uid and pr.travel_style is not null) as tarz
      from (
        select r.guest_id as uid, max(r.visit_id::text)::uuid as visit_id
          from sessions s
          join requests r on r.id = s.request_id
          join availabilities a on a.id = r.avail_id
          join users u on u.id = r.guest_id
         where a.lounge_id = p_lounge_id
           and s.started_at >= now() - make_interval(days => p_gun)
           and s.status = 'completed'
           and coalesce(u.is_staff, false) = false
           and u.deleted_at is null
         group by r.guest_id
      ) m
  ) z;

  v_misafir := coalesce(jsonb_array_length(v_beyan), 0);

  if coalesce(v_misafir, 0) < v_k then
    return jsonb_build_object(
      'known', true, 'yetki', true, 'gun', p_gun, 'k_esigi', v_k,
      'misafir_sayisi', coalesce(v_misafir, 0),
      'amac_satirlari', '[]'::jsonb, 'tarz_satirlari', '[]'::jsonb,
      'olanak_bosluklari', '[]'::jsonb, 'olanaklar', coalesce(v_ola, '{}'::jsonb),
      'amac_beyan_orani_yuzde', null, 'tarz_beyan_orani_yuzde', null,
      -- 🔴 SÖZLÜK DURUMU BU DALDA DA VERİLİYOR. İlk yazımda yalnız tam
      -- cevapta vardı ve ekran k eşiğinin altındayken "quiet_zone" kutusu
      -- hiç görünmüyordu — oysa sözlük KATALOG verisidir, kimseyi ifşa
      -- etmez. k eşiği kişileri korur, katalogu değil.
      'sozluk', jsonb_build_object(
        'quiet_zone_var', exists (select 1 from amenity_keys where key = 'quiet_zone' and active),
        'quiet_zone_beyan_eden_salon',
          (select count(*)::int from lounge_venues lv
            where coalesce(lv.active, true) and lv.amenities ? 'quiet_zone'),
        'not', 'quiet_zone anahtarı 215''te olanak sözlüğüne (amenity_keys) eklendi. Hiçbir salon henüz beyan etmedi; boşluk "yok" değil "bilinmiyor" olarak raporlanıyor.'),
      'hesaplanabilir', false,
      'neden', format('Son %s günde bu salonda tamamlanmış oturumu olan %s misafir var; k-anonimite eşiği %s. Hiçbir kırılım yayımlanmıyor. (Bu bir yazma yolu eksiği DEĞİL: amaç ve seyahat tarzı kolonlarına uygulamadan yazılabiliyor; eksik olan tamamlanmış oturum sayısı.)',
                      p_gun, coalesce(v_misafir, 0), v_k),
      'not', 'Beyan oranı da gizlendi: küçük kümede "kaç kişi beyan etti" sayısı da kişiyi işaret eder.');
  end if;

  select count(*) filter (where e ->> 'amac' is not null)::int,
         count(*) filter (where e ->> 'tarz' is not null)::int
    into v_amac_beyan, v_tarz_beyan
    from jsonb_array_elements(coalesce(v_beyan, '[]'::jsonb)) e;

  select jsonb_agg(x order by (x ->> 'kisi')::int desc, x ->> 'deger') into v_amac
    from (select jsonb_build_object('deger', e ->> 'amac', 'kisi', count(*)::int,
                 'beyan_edenin_yuzdesi', round(count(*)::numeric * 100 / nullif(v_amac_beyan, 0), 1)) as x
            from jsonb_array_elements(coalesce(v_beyan, '[]'::jsonb)) e
           where e ->> 'amac' is not null
           group by e ->> 'amac' having count(*) >= v_k) q;

  select jsonb_agg(x order by (x ->> 'kisi')::int desc, x ->> 'deger') into v_tarz
    from (select jsonb_build_object('deger', e ->> 'tarz', 'kisi', count(*)::int,
                 'beyan_edenin_yuzdesi', round(count(*)::numeric * 100 / nullif(v_tarz_beyan, 0), 1)) as x
            from jsonb_array_elements(coalesce(v_beyan, '[]'::jsonb)) e
           where e ->> 'tarz' is not null
           group by e ->> 'tarz' having count(*) >= v_k) q;

  select jsonb_agg(x order by (x ->> 'kisi')::int desc, x ->> 'talep') into v_bosluk
    from (
      select jsonb_build_object(
               'talep', t.deger,
               'kaynak', t.kaynak,
               'kisi', t.kisi,
               'olanak_anahtari', v_harita ->> t.deger,
               'olculebilir', (v_harita ->> t.deger) is not null,
               -- ÜÇ DURUM: beyan edilmiş mi, edildiyse ne demiş.
               'beyan_edildi', case when (v_harita ->> t.deger) is not null
                                    then coalesce(v_ola, '{}'::jsonb) ? (v_harita ->> t.deger) end,
               'var_mi', case
                 when (v_harita ->> t.deger) is null then null
                 when not (coalesce(v_ola, '{}'::jsonb) ? (v_harita ->> t.deger)) then null
                 else ((v_ola -> (v_harita ->> t.deger))::text = 'true') end,
               'neden', case
                 when (v_harita ->> t.deger) is null
                   then 'Bu talep bir salon olanağı değil, bir davranış; sözlükte karşılığı YOK ve uydurulmadı. Boşluk ÖLÇÜLEMİYOR.'
                 when not (coalesce(v_ola, '{}'::jsonb) ? (v_harita ->> t.deger))
                   then format('Sözlükte "%s" anahtarı VAR ama bu salon onu hiç BEYAN ETMEMİŞ. "Yok" demiyoruz — bilinmiyor.',
                               v_harita ->> t.deger)
                 end
             ) as x
        from (
          select (e ->> 'deger') as deger, (e ->> 'kisi')::int as kisi, 'amaç'::text as kaynak
            from jsonb_array_elements(coalesce(v_amac, '[]'::jsonb)) e
          union all
          select (e ->> 'deger'), (e ->> 'kisi')::int, 'tarz'
            from jsonb_array_elements(coalesce(v_tarz, '[]'::jsonb)) e
        ) t
    ) q;

  select exists (select 1 from amenity_keys where key = 'quiet_zone' and active) into v_sozluk_var;

  return jsonb_build_object(
    'known', true, 'yetki', true, 'gun', p_gun, 'k_esigi', v_k,
    'misafir_sayisi', v_misafir,
    'amac_beyan_eden', coalesce(v_amac_beyan, 0),
    'tarz_beyan_eden', coalesce(v_tarz_beyan, 0),
    'amac_beyan_orani_yuzde', round(coalesce(v_amac_beyan, 0)::numeric * 100 / nullif(v_misafir, 0), 1),
    'tarz_beyan_orani_yuzde', round(coalesce(v_tarz_beyan, 0)::numeric * 100 / nullif(v_misafir, 0), 1),
    'beyan_satiri', format('beyan eden: amaç %%%s · tarz %%%s',
        round(coalesce(v_amac_beyan, 0)::numeric * 100 / nullif(v_misafir, 0), 1),
        round(coalesce(v_tarz_beyan, 0)::numeric * 100 / nullif(v_misafir, 0), 1)),
    'amac_satirlari', coalesce(v_amac, '[]'::jsonb),
    'tarz_satirlari', coalesce(v_tarz, '[]'::jsonb),
    'olanaklar', coalesce(v_ola, '{}'::jsonb),
    'olanak_bosluklari', coalesce(v_bosluk, '[]'::jsonb),
    -- Sözlüğün kendi durumu ekranın içinde: "sessiz alan" satırı
    -- boşsa sebebi sözlük mü, beyan mı?
    'sozluk', jsonb_build_object(
      'quiet_zone_var', coalesce(v_sozluk_var, false),
      'quiet_zone_beyan_eden_salon',
        (select count(*)::int from lounge_venues lv
          where coalesce(lv.active, true) and lv.amenities ? 'quiet_zone'),
      'not', 'quiet_zone anahtarı 215''te olanak sözlüğüne (amenity_keys) eklendi. Hiçbir salon henüz beyan etmedi; boşluk "yok" değil "bilinmiyor" olarak raporlanıyor.'),
    'hesaplanabilir', (v_amac is not null or v_tarz is not null),
    'neden', case
      when coalesce(v_amac_beyan, 0) = 0 and coalesce(v_tarz_beyan, 0) = 0
        then format('%s misafirin hiçbiri amaç ya da seyahat tarzı beyan etmemiş; iki kolon da isteğe bağlı (visits.purpose ve profiles.travel_style). Kırılım üretilemez.', v_misafir)
      when v_amac is null and v_tarz is null
        then format('Beyan var ama hiçbir değer %s kişilik eşiği geçmedi.', v_k)
      end,
    'not', 'Seyahat amacı önce requests.visit_id ile DOĞRUDAN bağlanır (215); bağ yoksa kişinin bu havalimanındaki en yakın tarihli beyanına düşülür.');
end $fn$;


-- ------------------------------------------------------------
-- 3d) NÖBETÇİ — AMAÇ GERÇEKTEN YAZILIYOR MU
-- ------------------------------------------------------------
do $blok$
declare v_u uuid; v_ap text; v_id uuid; v jsonb; v_geri text; v_key_var boolean;
begin
  select user_id, airport_code into v_u, v_ap from visits order by visit_date, id limit 1;
  if v_u is null then
    raise exception '215: Ö9 nobetcisi CALISTIRILAMADI — hic seyahat yok.';
  end if;

  insert into visits (user_id, airport_code, visit_date, time_from, time_to)
  values (v_u, v_ap, current_date + 320, time '09:00', time '11:00')
  returning id into v_id;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_u, 'role', 'authenticated')::text, true);
  v := public.set_visit_purpose(v_id, 'business');
  perform set_config('request.jwt.claims', '', true);

  select purpose into v_geri from visits where id = v_id;
  if v_geri is null then
    raise exception '215: Ö9 KIRIK — set_visit_purpose calisti ama visits.purpose HALA NULL (seyahat %)', v_id;
  end if;
  if v_geri <> 'business' then
    raise exception '215: Ö9 KIRIK — yazilan "business", geri okunan "%"', v_geri;
  end if;

  -- Geri alma da çalışmalı: beyan isteğe bağlıysa geri çekilebilmeli.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_u, 'role', 'authenticated')::text, true);
  perform public.set_visit_purpose(v_id, null);
  perform set_config('request.jwt.claims', '', true);
  select purpose into v_geri from visits where id = v_id;
  if v_geri is not null then
    raise exception '215: Ö9 KIRIK — amac geri alinamadi, hala "%"', v_geri;
  end if;

  delete from visits where id = v_id;

  select exists (select 1 from amenity_keys where key = 'quiet_zone' and active) into v_key_var;
  if not v_key_var then
    raise exception '215: Ö9 KIRIK — quiet_zone olanak sozlugune eklenmemis.';
  end if;

  raise notice '215: Ö9 KANIT — set_visit_purpose yazip geri okudu, geri alma da calisti; quiet_zone sozlukte (beyan eden salon: %)',
    (select count(*) from lounge_venues where coalesce(active, true) and amenities ? 'quiet_zone');
end $blok$;


-- ============================================================
-- 4) Ö10 · İSTEK HANGİ SEYAHATE AİT — VE UÇUŞ ZİNCİRİ
-- ============================================================

-- ------------------------------------------------------------
-- 4a) `requests.visit_id` — BİLİNEN BİR ŞEYİ ÇÖPE ATMAYI BIRAKIYORUZ
-- ------------------------------------------------------------
-- `create_request_impl_preflag` eşleşen seyahati zaten buluyor
-- (`v_has_trip` için) ve sonra unutuyor. Ayrıca istek yazan İKİNCİ bir
-- fonksiyon daha var — ölçtüm:
--     create_request_impl_preflag(...)  ve  respond_invite(uuid,boolean)
-- Bu yüzden onarım yine tetikleyici: iki yolu da kapsar ve INSERT
-- ANINDA yazar.
--
-- EŞLEŞME KURALI (isteğin kendi kapısıyla AYNI olmalı, yoksa iki yerde
-- iki cevap olur): aynı misafir + aynı havalimanı + aynı gün + saat
-- aralıkları örtüşüyor. Birden çok aday varsa sıralama TAM BELİRLİ:
-- uçuş numarası olan önce (doğrulanabilir olan yeğlenir), sonra en
-- erken başlayan, sonra id — beraberliği kesin bitirsin diye.
create or replace function public.trg_request_visit_link()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_av availabilities%rowtype;
begin
  if new.visit_id is not null then
    return new;
  end if;

  select * into v_av from availabilities where id = new.avail_id;
  if not found then
    return new;   -- ilan yoksa bag kurulamaz; asil hata baska yerde patlar
  end if;

  select v.id into new.visit_id
    from visits v
   where v.user_id = new.guest_id
     and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
     and v.time_from < v_av.time_to
     and v_av.time_from < v.time_to
   order by (coalesce(v.flight_number, '') <> '') desc, v.time_from, v.id
   limit 1;

  return new;
end $fn$;

drop trigger if exists trg_request_visit_link on requests;
create trigger trg_request_visit_link
  before insert on requests
  for each row execute function public.trg_request_visit_link();


-- 4b) GEÇMİŞ İSTEKLER — GERİYE DÖNÜK BAĞLAMA
do $blok$
declare v_n int;
begin
  update requests r
     set visit_id = k.vid
    from (
      select r2.id as rid,
             (select v.id from visits v
               join availabilities a on a.id = r2.avail_id
              where v.user_id = r2.guest_id
                and v.airport_code = a.airport_code
                and v.visit_date = a.avail_date
                and v.time_from < a.time_to
                and a.time_from < v.time_to
              order by (coalesce(v.flight_number, '') <> '') desc, v.time_from, v.id
              limit 1) as vid
        from requests r2
       where r2.visit_id is null
    ) k
   where r.id = k.rid and k.vid is not null;
  get diagnostics v_n = row_count;
  raise notice '215: requests.visit_id geriye donuk baglandi → % satir', v_n;
end $blok$;


-- ------------------------------------------------------------
-- 4c) UÇUŞ ZİNCİRİ — ÖLÇÜM VE SINIRIN ADI
-- ------------------------------------------------------------
-- 🔴 BURADA HİÇBİR ŞEY UYDURMUYORUM VE SEBEBİNİ ÖLÇTÜM.
-- Zincir SAĞLAM ve kod düzeyinde eksiksiz:
--     visits INSERT (flight_number dolu)
--       → trg_visit_flight_ins → sync_visit_flight(id)
--       → flight_cache'te (flight_no, flight_date) ARANIR
--       → bulunursa flight_verified=true + scheduled_departure yazılır
--     flight_cache INSERT/UPDATE
--       → trg_flight_cache_backfill → bekleyen seyahatler GERİYE dolar
--
-- KIRIK OLAN ZİNCİR DEĞİL, KAYNAK:
--     select count(*) from flight_cache;            → 0
--     select * from service_endpoints();
--       → {"backoffice_url": "", "flight_lookup_ready": false}
-- `flight_cache`e yazan TEK yol backoffice'in `/api/flight` rotası
-- (AviationStack). Backoffice adresi Supabase'e hiç yazılmamış
-- (SQL 205'in `service_endpoints` kaydı boş), yani uygulama
-- `flight.js` içinden çekim yapamıyor: `if (!base) return { hit:false }`.
-- Ayrıca sağlayıcı anahtarı (AVIATIONSTACK_KEY) bu ortamda yok.
--
-- YANİ EKSİK OLAN VERİ ŞUDUR: gerçek uçuş tarifesi (kalkış saati).
-- ONU ÜRETECEK ŞEY: backoffice'in dağıtılması (adresini kendisi yazar)
-- + AVIATIONSTACK_KEY tanımlanması. Kod tarafında yapılacak iş YOK —
-- ve bunu kanıtlamak için zinciri aşağıda GERÇEKTEN çalıştırıyorum.
--
-- Sahte bir `flight_cache` satırı ÜRÜNDE BIRAKILMIYOR: nöbetçi kendi
-- satırını açar, zinciri doğrular, sonra hem satırı hem damgayı siler.
do $blok$
declare
  v_u uuid; v_ap text; v_vid uuid;
  -- 🔴 UÇUŞ NUMARASI 'ZZ9999' İDİ VE NÖBETÇİ DÜŞTÜ. Sebep ölçüldü:
  -- `sync_visit_flight` taşıyıcıyı `flight_carrier_resolve` ile çözüp
  -- `visits.carrier_code`e yazıyor ve o kolonun `carriers(code)`a FK'si
  -- var. Var olmayan "ZZ" taşıyıcısı 23503 veriyor, `trg_flight_cache_backfill`
  -- ise hatayı YUTUYOR (`exception when others then null`). Yani zincir
  -- sessizce kopuyordu ve hiçbir yerde iz yoktu.
  -- Gerçek bir taşıyıcı ön eki kullanılıyor; ayrıca aşağıda hata
  -- yutulursa ORTAYA ÇIKARAN ikinci bir çağrı var.
  v_no constant text := 'TK9911';
  v_gun date;
  v_dogrulandi boolean; v_kalkis timestamptz; v_kaynak text;
begin
  select user_id, airport_code into v_u, v_ap from visits order by visit_date, id limit 1;
  if v_u is null then
    raise exception '215: Ö10 ucus nobetcisi CALISTIRILAMADI — hic seyahat yok.';
  end if;
  v_gun := current_date + 340;

  insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
  values (v_u, v_ap, v_gun, time '06:00', time '10:00', v_no)
  returning id into v_vid;

  -- Adım 1: önbellek BOŞken damga OLUŞMAMALI (yoksa zincir değil, varsayım olurdu)
  select flight_verified into v_dogrulandi from visits where id = v_vid;
  if coalesce(v_dogrulandi, false) then
    raise exception '215: Ö10 — onbellek bosken ucus DOGRULANMIS gorunuyor; damga veriden gelmiyor.';
  end if;

  -- Adım 2: önbelleğe satır düşünce GERİYE DÖNÜK dolmalı
  insert into flight_cache (flight_no, flight_date, departure_iata, scheduled_departure,
                            scheduled_arrival, terminal, status, source)
  values (v_no, v_gun, v_ap, (v_gun + time '09:20') at time zone 'Europe/Istanbul',
          (v_gun + time '11:05') at time zone 'Europe/Istanbul', 'T1', 'scheduled', '215_nobetci');

  select flight_verified, scheduled_departure, flight_source
    into v_dogrulandi, v_kalkis, v_kaynak
    from visits where id = v_vid;

  if not coalesce(v_dogrulandi, false) then
    -- 🔴 TETİKLEYİCİ HATAYI YUTUYOR (bilerek: uçuş verisi seyahat kaydını
    -- düşürmemeli). Ama nöbetçi yutulmuş hatayı GÖRMEK zorunda, yoksa
    -- "çalışmıyor" der ve sebebini söyleyemez. Aynı işi doğrudan çağırıp
    -- hatayı yukarı bırakıyoruz.
    perform public.sync_visit_flight(v_vid);
    select flight_verified into v_dogrulandi from visits where id = v_vid;
    if not coalesce(v_dogrulandi, false) then
      raise exception '215: Ö10 KIRIK — onbellege satir dustu, sync_visit_flight dogrudan da cagrildi ama visits.flight_verified HALA false.';
    end if;
    raise notice '215: ⚠ trg_flight_cache_backfill damgayi vurmadi, dogrudan cagri vurdu — tetikleyici bir hatayi yutmus olabilir.';
  end if;
  if v_kalkis is null then
    raise exception '215: Ö10 KIRIK — flight_verified true ama scheduled_departure NULL.';
  end if;

  raise notice '215: Ö10 KANIT — ucus zinciri UCTAN UCA calisiyor (kalkis=%, kaynak=%). Eksik olan tek sey GERCEK tarife verisi.',
    v_kalkis, v_kaynak;

  -- Sahne toplanıyor — test verisi üründe kalmaz.
  delete from visits where id = v_vid;
  delete from flight_cache where flight_no = v_no and flight_date = v_gun;
end $blok$;


-- ------------------------------------------------------------
-- 4d) NÖBETÇİ — GERÇEK `create_request` İLE visit_id DOLUYOR MU
-- ------------------------------------------------------------
-- 🔴 Tetikleyiciyi tek başına test etmek yetmez: asıl soru, ÜRÜNÜN
-- kullandığı yoldan (create_request → create_request_impl →
-- create_request_impl_preflag) geçildiğinde bağın kurulup kurulmadığı.
--
-- `create_request` YEDİ kapıdan geçiyor: iletişim doğrulaması, kredi,
-- engel çifti, kural motorunun `guest_policy`si, slot, tarih, çakışma.
-- Tek bir aday seçip "olur herhalde" demek, nöbetçinin ürünü değil
-- ŞANSI ölçmesi olurdu. Bu yüzden ADAY DÖNGÜSÜ var: bir aday kural
-- motoruna takılırsa sahne toplanır ve SIRADAKİ denenir; hiçbiri
-- geçmezse SON HATA aynen yukarı verilir — yutulmaz.
do $blok$
declare
  r record;
  v_guest uuid; v_gun date;
  v_av uuid; v_vis uuid; v_req uuid; v jsonb; v_bag uuid;
  v_bakiye int; v_maliyet int;
  v_eski_kap int; v_dogr_vardi boolean; v_eski_mail boolean;
  v_g_dogr_vardi boolean; v_g_eski_mail boolean;
  v_son_hata text := 'aday hic denenmedi';
  v_tamam boolean := false;
  v_deneme int := 0;
begin
  v_gun := current_date + 310;

  for r in
    select distinct a.host_id, a.lounge_id, l.airport_code
      from availabilities a
      join lounges l on l.id = a.lounge_id
      join profiles pr on pr.user_id = a.host_id
     where l.venue_id is not null
     order by a.host_id, a.lounge_id
     limit 8
  loop
    exit when v_tamam;
    v_deneme := v_deneme + 1;
    v_av := null; v_vis := null; v_req := null; v_guest := null;

    -- Misafir: host DEĞİL, personel değil, silinmemiş, profili olan.
    select u.id into v_guest
      from users u
      join profiles p on p.user_id = u.id
     where u.id <> r.host_id
       and coalesce(u.is_staff, false) = false
       and u.deleted_at is null
       and not public.is_blocked_pair(u.id, r.host_id)
     order by u.id limit 1;
    continue when v_guest is null;

    -- --- SAHNE (iki tarafın da eski hâli kaydediliyor) ---
    select guest_capacity into v_eski_kap from profiles where user_id = r.host_id;
    select true, email_verified into v_dogr_vardi, v_eski_mail from verifications where user_id = r.host_id;
    select true, email_verified into v_g_dogr_vardi, v_g_eski_mail from verifications where user_id = v_guest;

    if coalesce(v_eski_kap, 0) < 1 then
      update profiles set guest_capacity = 1 where user_id = r.host_id;
    end if;
    insert into verifications (user_id, email_verified, email_verified_at)
    values (r.host_id, true, now())
    on conflict (user_id) do update set email_verified = true, email_verified_at = now();
    insert into verifications (user_id, email_verified, email_verified_at)
    values (v_guest, true, now())
    on conflict (user_id) do update set email_verified = true, email_verified_at = now();

    begin
      -- Host ilanı — GERÇEK RPC (böylece Ö7 yolu ikinci kez de geçiliyor)
      perform set_config('request.jwt.claims',
        json_build_object('sub', r.host_id, 'role', 'authenticated')::text, true);
      v := public.create_availability(r.lounge_id, r.airport_code, v_gun,
                                      time '13:00', time '17:00', 1, null, 'hidden', null);
      perform set_config('request.jwt.claims', '', true);
      v_av := nullif(v ->> 'id', '')::uuid;
      if v_av is null then raise exception 'ilan acilamadi: %', v; end if;

      -- Misafirin seyahati — uygulamanın yazdığı gibi DOĞRUDAN tablo yazımı
      insert into visits (user_id, airport_code, visit_date, time_from, time_to, purpose)
      values (v_guest, r.airport_code, v_gun, time '12:00', time '18:00', 'business')
      returning id into v_vis;

      -- Kredi: istek bedeli mertebeye bağlı (207); bakiye yetmiyorsa yüklenir
      v_maliyet := public.request_credit_cost(v_guest);
      select coalesce(sum(delta), 0) into v_bakiye from credit_ledger where user_id = v_guest;
      if v_bakiye < v_maliyet then
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
        values (v_guest, v_maliyet - v_bakiye + 1, 'admin_grant', v_vis,
                v_maliyet + 1, '215 nobetcisi — istek yolu kaniti');
      end if;

      perform set_config('request.jwt.claims',
        json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);
      v := public.create_request(v_av, 'lounge', null, '215-nobetci-' || v_av::text);
      perform set_config('request.jwt.claims', '', true);

      v_req := nullif(v ->> 'id', '')::uuid;
      if v_req is null then raise exception 'istek olusmadi: %', v; end if;

      -- ★ ASIL ÖLÇÜM
      select visit_id into v_bag from requests where id = v_req;
      if v_bag is null then
        raise exception '215: Ö10 KIRIK — gercek create_request cagrisindan sonra requests.visit_id HALA NULL (istek %).', v_req;
      end if;
      if v_bag <> v_vis then
        raise exception '215: Ö10 KIRIK — istek YANLIS seyahate baglandi (beklenen %, bulunan %).', v_vis, v_bag;
      end if;

      raise notice '215: Ö10 KANIT — gercek create_request cagrisi requests.visit_id=% yazdi (aday %)', v_bag, v_deneme;
      v_tamam := true;

    exception
      -- 🔴 YALNIZ KAPI REDLERİNİ YUTUYORUZ. `215: Ö10 KIRIK` ile başlayan
      -- hata BİZİM ölçümümüzdür ve asla yutulmaz — yoksa nöbetçi kendi
      -- bulgusunu susturur.
      when others then
        perform set_config('request.jwt.claims', '', true);
        if sqlerrm like '215: Ö10 KIRIK%' then
          raise;
        end if;
        v_son_hata := sqlerrm;
    end;

    -- --- SAHNE TOPLANIYOR (başarılı da olsa, başarısız da) ---
    if v_req is not null then
      delete from credit_ledger where ref_id = v_req;
      delete from notifications where ref_id = v_req;
      delete from requests where id = v_req;
    end if;
    if v_vis is not null then
      delete from credit_ledger where ref_id = v_vis;
      delete from visits where id = v_vis;
    end if;
    if v_av is not null then
      delete from notifications where ref_id = v_av;
      delete from availabilities where id = v_av;
    end if;
    update profiles set guest_capacity = v_eski_kap where user_id = r.host_id;
    if coalesce(v_dogr_vardi, false) then
      update verifications set email_verified = v_eski_mail where user_id = r.host_id;
    else
      delete from verifications where user_id = r.host_id;
    end if;
    if coalesce(v_g_dogr_vardi, false) then
      update verifications set email_verified = v_g_eski_mail where user_id = v_guest;
    else
      delete from verifications where user_id = v_guest;
    end if;
  end loop;

  if not v_tamam then
    raise exception '215: Ö10 istek nobetcisi HICBIR adayla calisamadi (% aday denendi). Son kapi reddi: %. Bag KANITLANMADI.',
      v_deneme, v_son_hata;
  end if;
end $blok$;


-- ============================================================
-- 5) SONRA ÖLÇTÜM — DOSYA KENDİ SONUCUNU RAPORLUYOR
-- ============================================================
-- 🔴 "Düzelttim" bir cümledir; oran bir kanıttır. Bu blok dosyanın
-- kendi iddiasını sayıya çeviriyor. Kolonu doldurmayan bir düzeltme
-- burada görünür olur.
do $blok$
declare
  v_a_top int; v_a_pg int; v_a_ven int;
  v_v_top int; v_v_pur int; v_v_dog int; v_v_kalkis int;
  v_r_top int; v_r_vis int; v_r_bagsiz int;
  v_fiyat int; v_fiyat_salon int; v_fc int;
  v_p_top int; v_p_tarz int;
begin
  select count(*), count(program_id), count(venue_id) into v_a_top, v_a_pg, v_a_ven from availabilities;
  select count(*), count(purpose), count(*) filter (where flight_verified), count(scheduled_departure)
    into v_v_top, v_v_pur, v_v_dog, v_v_kalkis from visits;
  select count(*), count(visit_id) into v_r_top, v_r_vis from requests;
  select count(*), count(distinct venue_id) into v_fiyat, v_fiyat_salon from venue_prices where active;
  select count(*) into v_fc from flight_cache;
  select count(*), count(travel_style) into v_p_top, v_p_tarz from profiles;

  raise notice '215 ═══ SONRA ÖLÇÜM ═══';
  raise notice '215   availabilities.program_id  : %/%   (venue_id %/%)', v_a_pg, v_a_top, v_a_ven, v_a_top;
  raise notice '215   requests.visit_id          : %/%', v_r_vis, v_r_top;
  raise notice '215   venue_prices               : % satir / % salon', v_fiyat, v_fiyat_salon;
  raise notice '215   visits.purpose             : %/%', v_v_pur, v_v_top;
  raise notice '215   profiles.travel_style      : %/%', v_p_tarz, v_p_top;
  raise notice '215   visits.flight_verified     : %/%   (flight_cache % satir)', v_v_dog, v_v_top, v_fc;
  raise notice '215   visits.scheduled_departure : %/%', v_v_kalkis, v_v_top;

  -- İDDİA EDİLEN DÜZELTMELERİN SAYISAL KAPISI. Bu eşiklerin altına
  -- düşersek dosya YEŞİL YANMAMALI: "düzelttim" diyen bir migration'ın
  -- kendi iddiasını doğrulaması gerekir.
  if v_a_pg = 0 then
    -- 🔴 EŞİK, ÇÖZÜLEBİLİR İLAN SAYISINA BAĞLI OLMALI — 214 ÖĞRETTİ.
    -- Bu satır "en az 1 ilanın programı yazılmış olmalı" diyordu ve 214
    -- sonrası kırmızı yandı. Sebep bir gerileme DEĞİLDİ: 214, kaynakta
    -- listelenmeyen salonları pasife aldı ve kaynaksız kabul satırlarını
    -- geri çekti; 215 çalışırken elde kalan yedi ilanın hiçbirinin
    -- programı ARTIK ÇÖZÜLEMİYOR — ve çözülmemesi DOĞRU.
    --
    -- Yani eşik yanlış şeyi ölçüyordu: "kaç ilan yazıldı" değil,
    -- "YAZILABİLECEK ilanların hepsi yazıldı mı". Doğrusu bu. Sıfır
    -- çözülebilir ilan varsa iddia da sıfırdır — ama tetikleyicinin
    -- gerçekten yazdığı, 4a'daki gerçek RPC turuyla ayrıca kanıtlı.
    declare v_cozulebilir int;
    begin
      select count(*) into v_cozulebilir
        from availabilities a
        join lounges l on l.id = a.lounge_id
       where l.venue_id is not null
         and public.pick_host_program(a.host_id, l.venue_id) is not null;
      if v_cozulebilir > 0 then
        raise exception '215: programi COZULEBILEN % ilan var ama program_id yazili olan 0 — tetikleyici calismiyor.', v_cozulebilir;
      end if;
      raise notice '215   ⚠ program_id 0/% — bu anda programi cozulebilen ilan YOK (214 kaynaksiz salonlari pasife aldi). Tetikleyici 4a''da gercek RPC ile KANITLANDI.', v_a_top;
    end;
  end if;
  -- 🔴 İLK YAZIMDA BURADA "visit_id 0 ise patla" yazıyordum ve nöbetçi
  -- düştü. Ölçüm: 215 çalışırken sistemdeki istek(ler)in eşleşen bir
  -- seyahati YOK (zengin sahne SEED ile 215'ten SONRA geliyor).
  -- "Sıfır bağ" bir hata DEĞİL; hata olan şey "bağlanabilecekken
  -- bağlanmamış" olmasıdır. Doğru değişmez bu:
  select count(*) into v_r_bagsiz
    from requests r
    join availabilities a on a.id = r.avail_id
   where r.visit_id is null
     and exists (select 1 from visits v
                  where v.user_id = r.guest_id
                    and v.airport_code = a.airport_code
                    and v.visit_date = a.avail_date
                    and v.time_from < a.time_to
                    and a.time_from < v.time_to);
  if v_r_bagsiz > 0 then
    raise exception '215: % istek eslesen seyahati OLDUGU HALDE baglanmamis — Ö10 bagi kurulmadi.', v_r_bagsiz;
  end if;
  if v_r_top > 0 and v_r_vis = 0 then
    raise notice '215   ⚠ requests.visit_id 0/% — mevcut isteklerin HICBIRININ ortusen seyahati yok (SEED sahnesi 215''ten sonra geliyor). Tetikleyici 4d''de gercek RPC ile KANITLANDI.', v_r_top;
  end if;
  if v_fiyat_salon < 5 then
    raise exception '215: venue_prices hala % salonda — fiyat katalogu yazilmadi.', v_fiyat_salon;
  end if;

  -- ⚠️ UÇUŞ İÇİN EŞİK YOK VE BU BİLİNÇLİ: `flight_cache` bu ortamda
  -- boş olmak ZORUNDA (dış sağlayıcı yok). Buraya eşik koymak, dosyayı
  -- sahte veri üretmeye zorlamak olurdu.
  if v_fc = 0 then
    raise notice '215   ⚠ flight_cache BOS — Ö10 kapsami 0%% kalir. Eksik olan: gercek ucus tarifesi. Uretecek olan: backoffice dagitimi (service_endpoints adresi yazar) + AVIATIONSTACK_KEY. Zincirin kendisi 4c''de UCTAN UCA kanitlandi.';
  end if;
end $blok$;


-- ============================================================
-- 6) YÜZEY — EN SONDA (213'ün öğrettiği sıra)
-- ============================================================
-- Önce kayıt, sonra kilitleme, sonra izin. `apply_rpc_surface()` bu
-- dosyada yaratılan yeni fonksiyonları da görmeli; ortada çağrılırsa
-- sonrakiler istemciye AÇIK kalır ve "RPC yuzeyi ihlali" degismezi
-- kirmizi yanar.
--
-- `create_availability_base` BİLEREK yüzeyde YOK: istemci onu
-- çağırmamalı, sarmalayıcı `security definer` olduğu için zaten
-- çalıştırabiliyor.
insert into rpc_client_surface (fn_name, client, note) values
  ('set_visit_purpose',   'app',               'Seyahat amaci — var olan seyahate sonradan yazma/geri alma (O9)'),
  ('amenity_key_options', 'app',               'Olanak sozlugu (quiet_zone dahil) + salon sayilari (O9)')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

do $blok$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '215: sinir uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $blok$;

do $blok$
declare r record;
begin
  for r in
    select p.proname, pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      join rpc_client_surface s on s.fn_name = p.proname
     where n.nspname = 'public' and p.prokind = 'f'
       and s.fn_name in ('set_visit_purpose', 'amenity_key_options')
  loop
    execute format('grant execute on function public.%I(%s) to authenticated', r.proname, r.args);
  end loop;
end $blok$;

grant select on amenity_keys to anon, authenticated;

-- ------------------------------------------------------------
-- YOL ÜSTÜNDE BULUNAN İKİNCİ SESSİZ KAPI — `redemptions`
-- ------------------------------------------------------------
-- Bu dosyanın konusu değil ama tam olarak AYNI SINIF, ve pg_run'ın
-- yeni "app tablo sorgusu / GRANT" değişmezi onu bu turda gösterdi:
--     redemptions SELECT — authenticated icin GRANT yok
--     (screens.js dogrudan sorguluyor, canlida 42501)
-- Ölçüm: `redemptions` üzerinde RLS AÇIK ve satır politikası VAR
--   POLICY redemptions_own FOR SELECT TO authenticated USING (user_id = auth.uid())
-- ama tabloya GRANT hiç verilmemiş. 159 bu sınıfı ("politika var, GRANT
-- yok") 24 tablo için elle kapatmıştı; bu tablo listede yoktu.
-- Sonuç: `screens.js:4001` — `.from("redemptions").select(...)` —
-- canlıda 42501 alıyor, supabase-js `data:null` veriyor, ekran
-- "hiç ödül kullanmadın" diyor. Kullanıcı hatayı hiç görmüyor.
--
-- Tek satırlık onarım ve GÜVENLİ: satır filtresini politika yapıyor,
-- GRANT yalnız kapıyı açıyor.
grant select on redemptions to authenticated;

-- 🔴 SON KONTROL: yüzey ihlali kalmadı mı? 213 bunu dosya sonunda
-- yapmıyordu ve 215 yeni fonksiyon eklediği için burada şart.
do $blok$
declare v_n int; v_ilk text;
begin
  select count(*), min(fn_name || ' (' || neden || ')') into v_n, v_ilk
    from public.rpc_surface_violations();
  if v_n > 0 then
    raise exception '215: RPC yuzey ihlali % adet — ornek: %', v_n, v_ilk;
  end if;
  raise notice '215: RPC yuzeyi temiz';
end $blok$;

select '215 OK - program_id / visit_id / fiyat katalogu / amac yazma yolu acildi; ucus zinciri uctan uca kanitlandi' as sonuc;
