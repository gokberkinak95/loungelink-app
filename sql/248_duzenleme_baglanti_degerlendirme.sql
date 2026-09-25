-- ============================================================================
-- 248 — DÜZENLEME · BAĞLANTI · DEĞERLENDİRME · KREDİ PAKETİ
--
-- Gokberk'in "LoungeLink sona dogru" listesindeki 16 maddenin SUNUCU yarisi.
-- Her bolum bir maddeye bagli ve her bolumun sonunda DAVRANIS olcen bir
-- nobetci var (kod metni degil — 243'te ogrendigim ders).
--
-- ============================================================================
-- 🔴 BU DOSYADA ÜÇ AYRI HATA SINIFI KAPANIYOR
--
-- (1) "BIR ALANI DEGISTIRMEDIGIN HALDE O ALANIN KURALINA TAKILIYORSAN,
--      KURAL DEGIL KAPI YANLIS YERDE."
--     Madde 14 — ilan duzenlemede "slot sayisi kapasiteni asiyor".
--     Olctum: `update_availability` kapasite kapisini KOSULSUZ calistiriyor.
--     Host yalnizca ucus numarasini duzeltse bile:
--         select guest_capacity into v_cap ...;
--         if v_cap is null then raise exception 'no_access_source';
--     Kapasite beyani olmayan (ya da sonradan dusen) her host, dokunmadigi
--     bir alanin kuraliyla TUM duzenlemeden men ediliyordu.
--     OLCUM (harness):  guest_capacity: <NULL> · SADECE UCUS: no_access_source
--
-- (2) "YENI BIR KURALI YALNIZCA YAZMA YOLUNA KOYMAK, O KURALDAN ONCE
--      YAZILMIS VERIYI DUZENLENEMEZ HALE GETIRIR."
--     Ayni fonksiyonda `kendi_ilanlarin_cakisiyor` var: host'un iki ilani
--     ayni saatte olamaz. Dogru bir kural. AMA bu kural once YOKTU ve
--     Gokberk'in ekraninda TAM OLARAK BU VAR:
--         IST · 10:00–16:00
--         IST · 10:00–16:00
--     Kural sonradan konuldugu icin bu iki ilanin ikisi de artik
--     DUZENLENEMEZ — saatine dokunmasan bile. Kapiyi "cakismayi
--     KOTULESTIRIYOR musun" sorusuna cevirdim: eskiden de cakisan bir
--     ciftte, cakismayi buyutmeyen duzenleme gecer.
--
-- (3) "BIR ALANI BASKA BIR ALANIN YAN ETKISI OLARAK SIFIRLAMAK, SESSIZ
--      VERI KAYBIDIR."
--     `min_trust = coalesce(v_min, min_trust)` ve v_min, gorunurluk
--     'all' secildiginde 0 oluyordu. Yani host guven esigini 60'a
--     ayarlayip sonra ilanini duzenlediginde ESIK SESSIZCE 0'A DUSUYORDU.
--     246'da acilan "yanimda kimi istiyorum" ayari, ilk duzenlemede
--     kayboluyordu. Kimse hata gormuyordu — en pahali hata turu.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — İLAN DÜZENLEME (madde 14)
--
-- Imza degisiyor: p_carrier / p_cabin / p_charter / p_min_trust eklendi.
-- `create or replace` YETMEZ — parametre eklemek yeni bir ASIRI YUKLEME
-- yaratir ve 9 argumanli cagri "function is not unique" ile patlar.
-- Once DROP.
-- ════════════════════════════════════════════════════════════════════════

drop function if exists public.update_availability(uuid, date, time, time, smallint, uuid, text, text, text);

create or replace function public.update_availability(
  p_id          uuid,
  p_date        date    default null,
  p_from        time    default null,
  p_to          time    default null,
  p_slots       smallint default null,
  p_lounge_id   uuid    default null,
  p_lounge_name text    default null,
  p_flight      text    default null,
  p_visibility  text    default null,
  -- ▼ 248: "müsaitlik ekle" ekraninda SORULAN ama duzenlemede SORULMAYAN
  --   alanlar. Madde 14'un asil talebi buydu: iki ekran birebir ayni olsun.
  p_carrier     text    default null,
  p_cabin       text    default null,
  p_charter     boolean default null,
  p_min_trust   int     default null
) returns jsonb
language plpgsql security definer set search_path = public as $f248$
declare
  v_uid    uuid := auth.uid();
  v_a      availabilities%rowtype;
  v_kabul  int;
  v_bekle  int;
  v_cap    int;
  v_yeni_d date; v_yeni_f time; v_yeni_t time; v_yeni_s smallint;
  v_yeni_l uuid;  v_yeni_ln text;
  v_kilit  boolean;
  v_degisen text[] := '{}';
  v_vis    availability_visibility;
  v_min    int;
  v_zaman_degisti boolean;
  v_cakisma_once  int;
  v_cakisma_sonra int;
  r        record;
begin
  perform public.motor_yazimi_ac();
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_a from availabilities where id = p_id for update;
  if not found then raise exception 'availability_not_found'; end if;
  if v_a.host_id <> v_uid then raise exception 'not_your_availability'; end if;
  if not coalesce(v_a.active, false) then raise exception 'availability_inactive'; end if;

  select count(*) filter (where status = 'accepted'),
         count(*) filter (where status = 'pending')
    into v_kabul, v_bekle
    from requests where avail_id = p_id;

  v_yeni_d  := coalesce(p_date, v_a.avail_date);
  v_yeni_f  := coalesce(p_from, v_a.time_from);
  v_yeni_t  := coalesce(p_to,   v_a.time_to);
  v_yeni_s  := coalesce(p_slots, v_a.slots);
  v_yeni_l  := coalesce(p_lounge_id, v_a.lounge_id);
  v_yeni_ln := coalesce(nullif(btrim(coalesce(p_lounge_name,'')),''), v_a.lounge_name);

  v_zaman_degisti := (v_yeni_d <> v_a.avail_date
                      or v_yeni_f <> v_a.time_from
                      or v_yeni_t <> v_a.time_to);

  -- ---- SÖZLEŞME KİLİDİ (degismedi) ----
  v_kilit := (v_kabul > 0);
  if v_kilit then
    if v_zaman_degisti or v_yeni_l is distinct from v_a.lounge_id then
      raise exception 'kabul_edilmis_basvuru_var'
        using detail = format('%s kabul edilmis basvuru var', v_kabul),
              hint   = 'Tarih, saat ve salon degistirilemez. Kontenjani artirabilir, '
                    || 'ucus numarasini duzeltebilirsin. Degistirmen sartsa once '
                    || 'misafirle sohbetten konus.';
    end if;
    if v_yeni_s < v_a.slots then
      raise exception 'kontenjan_azaltilamaz'
        using hint = 'Kabul edilmis misafir varken kontenjan dusurulemez.';
    end if;
  end if;

  -- ---- TEMEL GEÇERLİLİK ----
  -- 🔴 248: `v_yeni_d < current_date` KOSULSUZDU. Gecmis tarihli bir ilan
  -- (ornegin dun acilmis, hala active) artik hic duzenlenemiyordu — oysa
  -- host o ilanin ucus numarasini duzeltmek isteyebilir. Kural yalniz
  -- TARIHI DEGISTIRIYORSAN gecerli: gecmise TASIYAMAZSIN.
  if p_date is not null and v_yeni_d <> v_a.avail_date and v_yeni_d < current_date then
    raise exception 'date_in_past';
  end if;
  if v_yeni_f >= v_yeni_t then raise exception 'invalid_time_range'; end if;
  if v_yeni_s < 1 or v_yeni_s > 6 then raise exception 'invalid_slots'; end if;
  if v_yeni_s < coalesce(v_a.filled,0) then
    raise exception 'kontenjan_dolulugun_altinda'
      using detail = format('%s dolu', v_a.filled);
  end if;

  -- ---- KAPASİTE KAPISI — ARTIK KOŞULLU (madde 14'un kok nedeni) ----
  -- Kapasite beyani SLOT SAYISININ kuralidir. Slot sayisina dokunmayan
  -- bir duzenleme bu kapidan gecmez.
  if v_yeni_s > v_a.slots then
    select guest_capacity into v_cap from profiles where user_id = v_uid;
    if v_cap is null then
      raise exception 'no_access_source'
        using hint = 'Kontenjani artirmak icin once misafir hakki kaynagini '
                  || 'beyan etmen gerekiyor. Diger alanlari duzenlemek icin gerekmiyor.';
    end if;
    if v_yeni_s > v_cap then raise exception 'slots_exceed_capacity'; end if;
  end if;

  -- ---- HOST'UN KENDİ MİSAFİR İSTEĞİYLE ÇAKIŞMA ----
  -- Bu da yalniz ZAMAN DEGISTIYSE anlamli: degismeyen bir saat icin
  -- "cakisiyor" demek, var olan durumu duzenlenemez kilmaktir.
  if v_zaman_degisti and exists (
    select 1 from requests r2
      join availabilities a on a.id = r2.avail_id
     where r2.guest_id = v_uid and r2.status in ('pending','accepted')
       and a.avail_date = v_yeni_d
       and a.time_from < v_yeni_t and v_yeni_f < a.time_to
  ) then raise exception 'guest_same_slot'; end if;

  -- ---- HOST'UN KENDİ İKİ İLANI ÇAKIŞAMAZ — "KÖTÜLEŞTİRME" TESTİ ----
  -- 🔴 Eski hali: cakisma VARSA hata. Kural sonradan konuldugu icin
  -- kuraldan ONCE acilmis cakisan ilanlari da duzenlenemez yapiyordu.
  -- Yeni hali: cakisan ilan SAYISI artiyorsa hata. Var olan cakismayi
  -- buyutmeyen duzenleme (ucus, kontenjan, gorunurluk, hatta saati
  -- daraltmak) gecer.
  -- 🔴 İLK YAZIMIM SAYIYORDU — VE KENDİ NÖBETÇİM YAKALADI.
  -- `count(once) < count(sonra)` yazmistim. Nobetci sunu denedi: a1 zaten
  -- a2 ile cakisiyordu (once=1); a1'i BASKA bir gunde BASKA bir ilanla
  -- cakisan saate tasidim (sonra=1). 1 > 1 yanlis → duzenleme GECTI.
  -- Yani "eski cakismam vardi" kredisiyle YEPYENI bir cakisma acilabiliyordu.
  -- Dogru olcut sayi degil KUME: sonradan cakisanlar, oncekilerin ALT
  -- KUMESI olmali. Yeni bir ilan kumeye giriyorsa hata.
  -- 🆕 SINIF: "BIR DURUMUN KOTULESIP KOTULESMEDIGINI SAYIYLA OLCMEK,
  -- AYNI SAYIDA AMA BASKA BIR KOTULUGE KAPI ACAR."
  select count(*) into v_cakisma_sonra
    from availabilities a2
   where a2.host_id = v_uid and a2.id <> p_id and a2.active
     and a2.avail_date = v_yeni_d
     and a2.time_from < v_yeni_t and v_yeni_f < a2.time_to
     and not exists (
       select 1 from availabilities a3
        where a3.id = a2.id
          and a3.avail_date = v_a.avail_date
          and a3.time_from < v_a.time_to and v_a.time_from < a3.time_to);
  v_cakisma_once := 0;

  if v_cakisma_sonra > v_cakisma_once then
    raise exception 'kendi_ilanlarin_cakisiyor'
      using hint = 'Bu saatte baska bir ilanin var. Once onu kaldir ya da saatleri ayir.';
  end if;

  -- ---- DEĞİŞENLERİ TOPLA ----
  if v_yeni_d <> v_a.avail_date then v_degisen := v_degisen || 'tarih'::text; end if;
  if v_yeni_f <> v_a.time_from or v_yeni_t <> v_a.time_to then v_degisen := v_degisen || 'saat'::text; end if;
  if v_yeni_l is distinct from v_a.lounge_id
     or v_yeni_ln is distinct from v_a.lounge_name then v_degisen := v_degisen || 'salon'::text; end if;
  if v_yeni_s <> v_a.slots then v_degisen := v_degisen || 'kontenjan'::text; end if;
  if p_flight is not null and btrim(p_flight) is distinct from coalesce(v_a.flight_number,'')
    then v_degisen := v_degisen || 'uçuş'::text; end if;

  -- ---- GÖRÜNÜRLÜK ----
  -- 🔴 248: 'all' ARTIK min_trust'a DOKUNMUYOR. Eskiden v_min := 0 olup
  -- host'un guven esigini sessizce siliyordu (hata sinifi 3).
  if p_visibility is not null then
    case lower(p_visibility)
      when 'all'         then v_vis := 'Public';      v_min := null;
      when 'trusted'     then v_vis := 'Public';
                             v_min := coalesce(p_min_trust, 55);
      when 'hidden'      then v_vis := 'Hidden';      v_min := null;
      when 'connections' then v_vis := 'Connections'; v_min := null;
      else raise exception 'invalid_visibility';
    end case;
  end if;
  -- Acik istek her zaman gorunurluk esleminin onunde: host chip'e bastiysa
  -- dedigi olur.
  if p_min_trust is not null then
    if p_min_trust < 0 or p_min_trust > 100 then raise exception 'invalid_min_trust'; end if;
    v_min := p_min_trust;
  end if;

  -- ---- YAZ ----
  update availabilities set
    avail_date    = v_yeni_d,
    time_from     = v_yeni_f,
    time_to       = v_yeni_t,
    slots         = v_yeni_s,
    lounge_id     = v_yeni_l,
    lounge_name   = v_yeni_ln,
    flight_number = case when p_flight is null then flight_number
                         else nullif(btrim(p_flight),'') end,
    visibility    = coalesce(v_vis, visibility),
    min_trust     = coalesce(v_min, min_trust),
    rule_guest_policy    = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_guest_policy end,
    rule_flight_coupling = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_flight_coupling end,
    rule_severity        = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_severity end,
    rule_headline        = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_headline end,
    rule_note            = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_note end,
    rule_checked_at      = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_checked_at end,
    venue_id             = case when v_yeni_l is distinct from v_a.lounge_id
                                then (select l.venue_id from lounges l where l.id = v_yeni_l)
                                else venue_id end,
    updated_at    = now()
  where id = p_id;

  -- ---- TAŞIYICI / KABİN / CHARTER — KURALIN KENDİ KAPISINDAN ----
  -- 🔴 Bu uc alani BURADA `update availabilities set` ile yazmiyorum.
  -- Ucunun de kendi SECURITY DEFINER fonksiyonu var ve o fonksiyonlar
  -- kural motorunu yeniden tetikliyor (kabin notu, tasiyici eslesmesi).
  -- Kolonu dogrudan yazmak, kurali atlamak olurdu — 240'ta ogrendigim ders.
  if p_carrier is not null then
    perform public.set_availability_carrier(p_id, nullif(btrim(p_carrier),''));
    v_degisen := v_degisen || 'havayolu'::text;
  end if;
  if p_cabin is not null then
    perform public.set_availability_cabin(p_id, nullif(btrim(p_cabin),''));
    v_degisen := v_degisen || 'kabin'::text;
  end if;
  if p_charter is not null then
    perform public.set_availability_charter(p_id, p_charter);
  end if;

  -- ---- BEKLEYENLERE HABER VER ----
  if array_length(v_degisen,1) is not null and (v_bekle > 0 or v_kabul > 0) then
    for r in select distinct guest_id from requests
              where avail_id = p_id and status in ('pending','accepted')
    loop
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      values (r.guest_id, 'requests', 'Başvurduğun ilan güncellendi',
              format('Host %s bilgisini değiştirdi. Yeni hâli: %s · %s–%s%s. '
                  || 'Sana uymuyorsa başvurunu iptal edebilirsin — kredin iade edilir.',
                  array_to_string(v_degisen, ', '),
                  to_char(v_yeni_d,'DD.MM.YYYY'),
                  to_char(v_yeni_f,'HH24:MI'), to_char(v_yeni_t,'HH24:MI'),
                  coalesce(' · ' || v_yeni_ln, '')),
              'availability', p_id);
    end loop;
  end if;

  insert into audit_log (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_uid, 'availability.update', 'availabilities', p_id,
          jsonb_build_object('date', v_a.avail_date, 'from', v_a.time_from,
                             'to', v_a.time_to, 'slots', v_a.slots,
                             'lounge_id', v_a.lounge_id, 'min_trust', v_a.min_trust),
          jsonb_build_object('date', v_yeni_d, 'from', v_yeni_f,
                             'to', v_yeni_t, 'slots', v_yeni_s,
                             'lounge_id', v_yeni_l, 'degisen', v_degisen,
                             'min_trust', coalesce(v_min, v_a.min_trust)));

  return jsonb_build_object('ok', true, 'degisen', v_degisen,
                            'bildirilen', v_bekle + v_kabul,
                            'kural_sifirlandi', (v_yeni_l is distinct from v_a.lounge_id));
end $f248$;

grant execute on function public.update_availability(uuid, date, time, time, smallint, uuid, text, text, text, text, text, boolean, int) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — "SORDUKLARIM" ARTIK SOHBETE AÇILIYOR (madde 15)
--
-- Gokberk: "X yanitladiya tiklaninca chat acilmiyor, o kisinin profil
-- sayfasi aciliyor."
-- Olctum: `sorularim()` 11 kolon donduruyor ve HICBIRI kanal degil.
-- Ekran elindeki tek kimlikle (host_id) yapabilecegi tek seyi yapiyordu:
-- profili aciyordu. Ekranin sucu degil; veri yoktu.
--
-- `respond_connection` kabul edildiginde ZATEN bir 'companion' kanali
-- aciyor. Kanal VAR, sorularim onu OKUMUYORDU.
-- ════════════════════════════════════════════════════════════════════════

-- Donus tipi degisiyor (channel_id + 4 kolon) — `create or replace` bunu
-- yapamaz: "cannot change return type of existing function". Once DROP.
drop function if exists public.sorularim();

create or replace function public.sorularim()
returns table(
  id uuid, host_id uuid, host_name text, salon text, airport_code text,
  avail_id uuid, durum text, cevap_durumu text,
  soruldu_at timestamptz, yanit_at timestamptz, ilan_acildi boolean,
  channel_id uuid,          -- ▼ 248
  soru text,                -- ▼ 248: ne sordugunu hatirlatir
  avail_date date,          -- ▼ 248: "hicbir detay yok" (madde 15)
  time_from time, time_to time
)
language plpgsql stable security definer set search_path = public as $s248$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select cr.id, cr.to_id,
         coalesce(nullif(btrim(p.name),''), 'Host'),
         coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text),
         a.airport_code::text,
         cr.avail_id,
         cr.status::text,
         case
           when cr.status::text = 'accepted' then 'yanitlandi'
           when cr.status::text = 'declined' then 'reddedildi'
           when cr.avail_id is not null
                and not public.kural_sorusu_uygun_mu(cr.avail_id) then 'hak_beyan_edildi'
           else 'bekliyor'
         end,
         cr.created_at, cr.responded_at,
         case when cr.avail_id is null then false
              else not public.kural_sorusu_uygun_mu(cr.avail_id) end,
         ch.id,
         nullif(btrim(coalesce(cr.intro,'')),''),
         a.avail_date, a.time_from, a.time_to
    from connection_requests cr
    left join profiles p on p.user_id = cr.to_id
    left join availabilities a on a.id = cr.avail_id
    left join lounges l on l.id = a.lounge_id
    left join chat_channels ch on ch.connection_id = cr.id
   where cr.from_id = v_uid
     and cr.intent = 'kural_sorusu'
   order by cr.created_at desc
   limit 30;
end $s248$;

grant execute on function public.sorularim() to authenticated;

-- 🔴 KANAL YOKSA NE OLACAK?
-- `respond_connection` kanali kabul aninda aciyor ama ESKI kabullerde
-- (ya da kanal bir sekilde silinmisse) `channel_id` null gelir. Ekranin
-- "yanitlandi" deyip hicbir yere goturememesi, madde 15'in ta kendisidir.
-- Bu fonksiyon kanali GARANTI eder: varsa dondurur, yoksa acar.
create or replace function public.baglanti_sohbeti_ac(p_conn_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $b248$
declare v_uid uuid := auth.uid(); v_cr connection_requests%rowtype; v_ch uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_cr from connection_requests where id = p_conn_id;
  if not found then raise exception 'connection_not_found'; end if;
  if v_uid not in (v_cr.from_id, v_cr.to_id) then raise exception 'not_participant'; end if;
  if v_cr.status <> 'accepted' then
    raise exception 'baglanti_kabul_edilmedi'
      using hint = 'Sohbet, karsi taraf kabul edince acilir.';
  end if;
  -- Engellenmis ciftte sohbet acilmaz: kabul eski olabilir, engel yenidir.
  if public.is_blocked_pair(v_cr.from_id, v_cr.to_id) then
    raise exception 'blocked_pair';
  end if;
  select id into v_ch from chat_channels where connection_id = p_conn_id;
  if v_ch is null then
    insert into chat_channels (connection_id, kind, created_at)
    values (p_conn_id, 'companion', now())
    returning id into v_ch;
  end if;
  return jsonb_build_object('ok', true, 'channel_id', v_ch);
end $b248$;

grant execute on function public.baglanti_sohbeti_ac(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — BAĞLANTI İSTEKLERİ (madde 9)
--
-- Gokberk: "baglanti kur ile gonderilen baglanti istekleri ana sayfada
-- gozukmuyor. Tanis ekraninda Kesfet ve Baglantilar yaninda bir
-- 'Baglanti istekleri' tabi da olusturabiliriz."
--
-- Olctum, iki ayri boslugu var:
--  (a) GONDERDIGIN istegi gosteren HICBIR sorgu yok. Meet ekrani yalniz
--      `to_id = ben and status = pending` cekiyor. Gonderen taraf icin
--      istek gonderdikten sonra ORTADA HICBIR IZ KALMIYOR.
--  (b) Ana sayfada `home_connections` var ama o yalniz KABUL EDILMIS
--      baglantilarin sohbetlerini donduruyor. Bekleyen hicbir yerde yok.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.baglanti_istekleri()
returns table(
  id uuid, yon text, peer_id uuid, peer_name text, peer_photo text,
  peer_badge text, peer_score int, peer_profession text,
  intent text, intro text, durum text,
  gonderildi_at timestamptz, yanit_at timestamptz,
  channel_id uuid,
  -- Bir baglanti istegi bir ILANDAN dogmus olabilir (kural sorusu degil,
  -- duz baglanti da avail_id tasiyabiliyor). Baglami tasimak, karti
  -- "bir isim ve bir kelime" olmaktan cikarir.
  salon text, airport_code text, avail_date date
)
language plpgsql stable security definer set search_path = public as $c248$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select cr.id,
         case when cr.from_id = v_uid then 'giden' else 'gelen' end,
         case when cr.from_id = v_uid then cr.to_id else cr.from_id end,
         coalesce(nullif(btrim(p.name),''), 'Yolcu'),
         p.photo_url, ts.badge, ts.score, p.profession,
         coalesce(cr.intent,'connect'),
         nullif(btrim(coalesce(cr.intro,'')),''),
         cr.status::text,
         cr.created_at, cr.responded_at,
         ch.id,
         coalesce(nullif(btrim(a.lounge_name),''), l.name),
         a.airport_code::text, a.avail_date
    from connection_requests cr
    left join profiles p
      on p.user_id = case when cr.from_id = v_uid then cr.to_id else cr.from_id end
    left join trust_scores ts
      on ts.user_id = case when cr.from_id = v_uid then cr.to_id else cr.from_id end
    left join availabilities a on a.id = cr.avail_id
    left join lounges l on l.id = a.lounge_id
    left join chat_channels ch on ch.connection_id = cr.id
   where (cr.from_id = v_uid or cr.to_id = v_uid)
     -- Kural sorulari AYRI bir akis (sorularim) — burada tekrar etmiyoruz.
     and coalesce(cr.intent,'connect') <> 'kural_sorusu'
     -- Bekleyenler her zaman; yanitlanmislar 7 gun. Sonsuza kadar biriken
     -- liste, listenin kendisini oldurur.
     and (cr.status = 'pending'
          or coalesce(cr.responded_at, cr.created_at) > now() - interval '7 days')
     and not public.is_blocked_pair(v_uid,
           case when cr.from_id = v_uid then cr.to_id else cr.from_id end)
   -- 🔴 `(cr.status = 'pending') desc` YAZMIŞTIM; nöbetçi yakaladı.
   -- `status` kolonu NULL olabilir ve NULL = 'pending' ifadesi NULL döner;
   -- DESC sıralamada NULL EN BAŞA çıkar. Yani durumu bilinmeyen bir kayıt,
   -- bekleyen isteklerin de üstünde listenin tepesine otururdu.
   -- `coalesce` ile ifade artık her zaman boolean.
   order by (coalesce(cr.status::text,'') = 'pending') desc, cr.created_at desc
   limit 50;
end $c248$;

grant execute on function public.baglanti_istekleri() to authenticated;

-- ---- REDDEDİLDİKTEN SONRA TEKRAR GÖNDERME ----
-- 🔴 KENDİ BAŞIMA BULDUĞUM ARIZA (Gokberk'in listesinde YOK).
-- `connection_requests` tablosunda UNIQUE (from_id, to_id) var — DURUMDAN
-- BAGIMSIZ. `send_connection` ise yalniz 'pending'/'accepted' varsa
-- engelliyor. Yani REDDEDILMIS bir istek varsa:
--     fonksiyon "gonderebilirsin" diyor → insert 23505 ile patliyor
--     → kullaniciya ham Postgres metni dusuyor.
-- Ayrica bu, kural sorusu ile baglanti istegini birbirine KILITLIYOR:
-- bir host'a kural sorusu sorup reddedildiysen, o kisiyle bir daha ASLA
-- baglanti kuramiyorsun. Iki ayri urun akisi tek satiri paylasiyor.
--
-- Cozum: ayni yonde reddedilmis satir varsa YENIDEN ISLET (update), ama
-- 7 GUN SOGUMA SURESIYLE. Kilidi acarken tacizi acmiyoruz — mevcut
-- durumun tek erdemi kazara olan bu korumaydi, bilerek koruyoruz.
create or replace function public.send_connection(p_to uuid, p_intent text, p_intro text default null)
returns jsonb
language plpgsql security definer set search_path = public as $sc248$
declare v_uid uuid := auth.uid(); v_ok boolean; v_id uuid; v_eski connection_requests%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_to = v_uid then raise exception 'self_connect_blocked'; end if;

  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

  if public.is_blocked_pair(v_uid, p_to) then raise exception 'blocked_pair'; end if;

  if exists (select 1 from connection_requests
              where ((from_id=v_uid and to_id=p_to) or (from_id=p_to and to_id=v_uid))
                and status in ('pending','accepted')) then
    raise exception 'connection_exists';
  end if;

  select * into v_eski from connection_requests
   where from_id = v_uid and to_id = p_to;

  if found then
    -- Reddedilmis (ya da baska bir son durumda) eski satir. Tabloda
    -- UNIQUE(from_id,to_id) oldugu icin INSERT patlar; satiri yeniden
    -- isletiyoruz.
    if coalesce(v_eski.responded_at, v_eski.created_at) > now() - interval '7 days' then
      raise exception 'baglanti_soguma'
        using hint = 'Bu kisiye kisa sure once istek gonderdin ve yanit olumsuzdu. '
                  || 'Yeni istek icin 7 gun beklemen gerekiyor.';
    end if;
    update connection_requests
       set intent = coalesce(p_intent,'connect'),
           intro  = left(coalesce(p_intro,''),140),
           status = 'pending',
           created_at = now(),
           responded_at = null
     where id = v_eski.id
     returning id into v_id;
  else
    insert into connection_requests (from_id, to_id, intent, intro, status)
    values (v_uid, p_to, coalesce(p_intent,'connect'), left(coalesce(p_intro,''),140), 'pending')
    returning id into v_id;
  end if;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (p_to, 'connections', 'Yeni bağlantı isteği ◈',
          'Bir yolcu seninle bağlantı kurmak istiyor.', 'connection', v_id);

  return jsonb_build_object('ok', true, 'id', v_id);
end $sc248$;

grant execute on function public.send_connection(uuid, text, text) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — İLAN ÖZETİ (madde 8: "seyahat ekle" otomatik dolmuyor)
--
-- Gokberk: "baglantilar sayfasindan seyahat ekle dedigimde ilgili bilgiler
-- otomatik dolmuyor. Bunu kesfet ekranindaki seyahat ekle butonlari icin
-- yapmistik. Burada da uygulanmali."
--
-- Kok neden APP tarafinda (App.js `onAddTrip={() => setShowAddVisit(true)}`
-- — parametre HIC gecilmiyor) ama sunucu tarafinda da bir boslugu var:
-- `discover_people` ilanin ID'sini veriyor, TARIH ve SAATINI vermiyor.
-- AddVisit'in doldurmasi gereken alanlar tam olarak bunlar.
--
-- `discover_people`'in donus tipini degistirmek yerine (o fonksiyon 20
-- kolonlu ve dort ekran okuyor) tek amacli kucuk bir fonksiyon yaziyorum.
-- Bir sozlesmeyi genisletmek, tasimayan bir sozlesmeyi bozmaktan ucuzdur.
create or replace function public.ilan_ozeti(p_avail_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $i248$
declare v_uid uuid := auth.uid(); v_a availabilities%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_a from availabilities where id = p_avail_id and active;
  if not found then return jsonb_build_object('ok', false); end if;
  -- Gizli ilanin ozeti verilmez: keste gorunmeyen bir ilanin saatini
  -- sizdirmak, gorunurluk ayarini anlamsiz kilar.
  if v_a.visibility = 'Hidden' and v_a.host_id <> v_uid then
    return jsonb_build_object('ok', false);
  end if;
  return jsonb_build_object(
    'ok', true,
    'id', v_a.id,
    'airport_code', v_a.airport_code,
    'avail_date', v_a.avail_date,
    'time_from', v_a.time_from,
    'time_to', v_a.time_to,
    'lounge_name', v_a.lounge_name,
    'host_id', v_a.host_id);
end $i248$;

grant execute on function public.ilan_ozeti(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — DEĞERLENDİRMELER (madde 11)
--
-- Gokberk: "ana sayfadaki agirlaman nasil gecti alani daraltilip
-- genisletilemiyor... Simdi degile tiklaninca da bir daha bulunamiyor.
-- Profil tabinda Oturum gecmisi ile Bildirimler arasina Degerlendirmeler
-- diye bir alan olsun; bekleyen / tamamlanan iki sekme."
--
-- `pending_ratings()` BEKLEYENI veriyor; VERILMIS degerlendirmeyi
-- donduren hicbir fonksiyon yok. "Tamamlanan" sekmesi icin veri lazim.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.degerlendirmelerim()
returns table(
  durum text,                 -- 'bekleyen' | 'tamamlanan'
  session_id uuid, request_id uuid,
  other_id uuid, other_name text,
  salon text, airport_code text, avail_date date,
  time_from time, time_to time,
  completed_at timestamptz,
  i_am_host boolean,
  rating_id uuid, puan smallint, yorum text, verildi_at timestamptz
)
language plpgsql stable security definer set search_path = public as $d248$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select
    case when rt.id is null then 'bekleyen' else 'tamamlanan' end,
    s.id, r.id,
    case when r.host_id = v_uid then r.guest_id else r.host_id end,
    coalesce(nullif(btrim(p.name),''), 'Yolcu'),
    coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text),
    a.airport_code::text, a.avail_date, a.time_from, a.time_to,
    s.completed_at,
    (r.host_id = v_uid),
    rt.id, rt.score, nullif(btrim(coalesce(rt.comment,'')),''), rt.created_at
  from sessions s
  join requests r on r.id = s.request_id
  left join availabilities a on a.id = r.avail_id
  left join lounges l on l.id = a.lounge_id
  left join profiles p
    on p.user_id = case when r.host_id = v_uid then r.guest_id else r.host_id end
  left join ratings rt
    on rt.session_id = s.id and rt.rater_id = v_uid
 where s.status = 'completed'
   and (r.host_id = v_uid or r.guest_id = v_uid)
 order by (rt.id is null) desc, s.completed_at desc nulls last
 limit 60;
end $d248$;

grant execute on function public.degerlendirmelerim() to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §6 — KREDİ PAKETLERİ (madde 1)
--
-- Gokberk: "cuzdan sayfasinda kredi paketleri yer aliyor, DOLARLA
-- satiliyor ve 20000 kredi vs satiyoruz. Bunu dogru sekilde duzenle...
-- uyelik plani disinda ek bir satin alma gibi konumlandirilmali."
--
-- Haklı ve rakam saçmaydı: app'te PACKS sabiti "3000 / 8000 / 20000 kredi,
-- $4.99 / $11.99 / $24.99" diyordu. Oysa BU URUNDE:
--     1 istek = 1 kredi   (request_credit_cost)
--     Yolcu (ucretsiz) ayda 1 kredi · Sik Ucan 99₺/6 · Kahya 249₺/12
-- 20.000 kredi = 20.000 lounge istegi. Rakam bir oyun para birimi gibi
-- yazilmis; urunun kendi ekonomisiyle ILGISIZ.
--
-- FİYATLAMA KARARI VE GEREKÇESİ:
--   abonelikte kredi basina: 99/6 = 16,5₺ · 249/12 = 20,75₺
--   pakette kredi basina   : 39 · 33 · 29,8₺
-- Paket HER ZAMAN abonelikten pahali. Bu bilerek: paket bir ALTERNATIF
-- degil, TAKVIYE. Ucuz olsaydi abonelik anlamsizlasirdi ve tekrar eden
-- gelirimizi kendi elimizle bozardik.
--
-- Fiyatlar TABLODA, kodda degil: BO'dan degistirilebilir olmasi sart.
-- Uygulamaya gomulu fiyat, her degisiklikte yeni bir build demektir.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists kredi_paketleri (
  kod           text primary key,
  ad            text not null,
  kredi         int  not null check (kredi between 1 and 50),
  fiyat_try     int  not null check (fiyat_try > 0),
  sira          int  not null default 0,
  aktif         boolean not null default true,
  one_cikan     boolean not null default false,
  aciklama      text,
  guncellendi   timestamptz not null default now()
);

alter table kredi_paketleri enable row level security;
drop policy if exists kredi_paketleri_oku on kredi_paketleri;
create policy kredi_paketleri_oku on kredi_paketleri for select using (true);

insert into kredi_paketleri (kod, ad, kredi, fiyat_try, sira, one_cikan, aciklama) values
  ('tek',  'Tek hak',   1, 39,  1, false, 'Bu ay bir istek daha göndermek için.'),
  ('uclu', 'Üç hak',    3, 99,  2, true,  'Aynı anda birkaç ilana başvurmak için.'),
  ('altili','Altı hak', 6, 179, 3, false, 'Yoğun bir seyahat dönemi için.')
on conflict (kod) do update
  set ad = excluded.ad, kredi = excluded.kredi, fiyat_try = excluded.fiyat_try,
      sira = excluded.sira, one_cikan = excluded.one_cikan,
      aciklama = excluded.aciklama, guncellendi = now();

-- 🔴 NÖBETÇİ DEĞİL, KURAL: paket kredisi ABONELIK kredisinden UCUZ OLAMAZ.
-- Bu bir fiyat tercihi degil, is modelinin tasiyici kolonu. Tabloya
-- yazilabilir olmasi, yanlis yazilabilir olmasi demek — kapiyi koyuyorum.
create or replace function public.trg_kredi_paketi_kapisi() returns trigger
language plpgsql as $tkp$
declare v_en_ucuz_abonelik numeric;
begin
  select min(price_try::numeric / nullif(monthly_credits,0))
    into v_en_ucuz_abonelik
    from plan_catalog where aktif and price_try > 0 and monthly_credits > 0;
  if v_en_ucuz_abonelik is not null
     and (new.fiyat_try::numeric / new.kredi) <= v_en_ucuz_abonelik then
    raise exception 'paket_abonelikten_ucuz'
      using detail = format('paket %s₺/kredi · en ucuz abonelik %s₺/kredi',
                            round(new.fiyat_try::numeric / new.kredi, 2),
                            round(v_en_ucuz_abonelik, 2)),
            hint = 'Paket takviyedir, alternatif degil. Abonelikten ucuz bir paket '
                || 'tekrar eden geliri kendi elimizle bozar.';
  end if;
  return new;
end $tkp$;

drop trigger if exists trg_kredi_paketi_kapisi on kredi_paketleri;
create trigger trg_kredi_paketi_kapisi
  before insert or update on kredi_paketleri
  for each row execute function public.trg_kredi_paketi_kapisi();

create or replace function public.kredi_paketleri()
returns jsonb
language plpgsql stable security definer set search_path = public as $kp248$
declare v_uid uuid := auth.uid(); v_bal int; v_plan text; v_plan_kredi int; v_plan_fiyat int;
begin
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  select u.plan::text into v_plan from users u where u.id = v_uid;
  select pc.monthly_credits, pc.price_try into v_plan_kredi, v_plan_fiyat
    from plan_catalog pc where pc.plan::text = v_plan;

  return jsonb_build_object(
    'bakiye', v_bal,
    'plan', v_plan,
    'plan_aylik_kredi', v_plan_kredi,
    -- Cuzdan ekraninin en onemli cumlesi: "1 kredi = 1 lounge istegi".
    -- Rakamin BIRIMI yoksa rakam bilgi degildir.
    'kredi_bedeli', public.request_credit_cost(v_uid),
    'paketler', coalesce((
      select jsonb_agg(jsonb_build_object(
               'kod', k.kod, 'ad', k.ad, 'kredi', k.kredi,
               'fiyat_try', k.fiyat_try,
               'kredi_basina', round(k.fiyat_try::numeric / k.kredi, 1),
               'one_cikan', k.one_cikan, 'aciklama', k.aciklama)
             order by k.sira)
        from kredi_paketleri k where k.aktif), '[]'::jsonb),
    -- Abonelige yonlendirme, paketin yaninda ve DURUST: paket pahali
    -- oldugu icin pahali oldugunu biz soyluyoruz.
    'abonelik_ipucu', (
      select jsonb_build_object('plan', pc.ad, 'fiyat_try', pc.price_try,
                                'aylik_kredi', pc.monthly_credits,
                                'kredi_basina', round(pc.price_try::numeric / pc.monthly_credits, 1))
        from plan_catalog pc
       where pc.aktif and pc.price_try > 0 and pc.monthly_credits > 0
       order by pc.price_try::numeric / pc.monthly_credits asc limit 1)
  );
end $kp248$;

grant execute on function public.kredi_paketleri() to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §7 — YÜZEY KAYITLARI
-- 🔴 "Yazip cagirmamak, yazmamaktan kotudur" nobetcisi (v2.94) bu
-- kayitlardan besleniyor. Buraya yazilan her satir, app'te GERCEKTEN
-- cagrilmak zorunda; cagrilmazsa `npm run verify` kirmizi yanar.
-- ════════════════════════════════════════════════════════════════════════

insert into rpc_client_surface (fn_name, client, note) values
  ('baglanti_istekleri',  'app', 'Tanis > Istekler sekmesi + ana sayfa paneli (madde 9)'),
  ('baglanti_sohbeti_ac', 'app', 'Sorduklarim/Istekler karti > sohbeti ac (madde 15)'),
  ('ilan_ozeti',          'app', 'Seyahat ekle on doldurma (madde 8)'),
  ('degerlendirmelerim',  'app', 'Profil > Degerlendirmeler ekrani (madde 11)'),
  ('kredi_paketleri',     'app', 'Cuzdan > kredi paketleri, TRY (madde 1)')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

-- ════════════════════════════════════════════════════════════════════════
-- §8 — NÖBETÇİ
-- Kod METNI degil DAVRANIS olcuyor (243'te ogrendigim ders). Butun
-- yazmalar geri alinan bir alt islemin icinde — bir nobetci, nobet
-- tuttugu seye zarar veremez (240'ta ogrendigim ders).
-- ════════════════════════════════════════════════════════════════════════

do $n248$
declare
  v_h text[] := '{}';
  v_host uuid; v_guest uuid; v_ap text; v_lounge uuid;
  v_a1 uuid; v_a2 uuid; v_d date;
  v_r jsonb; v_cnt int; v_min int; v_cap int;
begin
  begin
    select code into v_ap from airports order by code limit 1;
    select l.id into v_lounge from lounges l
      where l.airport_code = v_ap::char(3) and l.active limit 1;

    -- ══════════════════════════════════════════════════════════════════
    -- 🔴 26 AĞUSTOS 2026 — BU NÖBETÇİ GÖKBERK'İN VERİTABANINDA ÇÖKTÜ,
    --    BENİMKİNDE GEÇMİŞTİ.
    --
    --    Hata:  update or delete on table "chat_channels" violates
    --           foreign key constraint "messages_channel_id_fkey"
    --
    --    Sebep zinciri ölçüldü:
    --      connection_requests  --ON DELETE CASCADE-->  chat_channels
    --      chat_channels        --CASCADE YOK       -->  messages
    --    Nöbetçi sahneyi temizlemek için `delete from connection_requests`
    --    diyordu. Onun kanallarında GERÇEK MESAJ vardı; benimkinde yoktu.
    --
    --    Ama asıl kusur o delete değil: NÖBETÇİNİN OYUNCULARI ÖDÜNÇ
    --    ALMASIYDI. `select id from users limit 1` demek, ölçümü
    --    veritabanındaki ilk satırın kim olduğuna bağlamaktır — o kişi
    --    admin olabilir, silinmiş olabilir, karşı tarafla geçmişi
    --    olabilir. (Bu projede aynı sınıfa iki kez düştüm: "kapıyı
    --    anahtarı olan biriyle denedim".)
    --
    --    Nöbetçi artık KENDİ OYUNCULARINI KURUYOR. Geçmişleri yok,
    --    dolayısıyla silinecek bir şey de yok: `delete` cümlesi tamamen
    --    kalktı. Her şey geri alınan alt işlemin içinde.
    --
    -- 🆕 SINIF: "OYUNCULARINI SAHNEDE BULDUĞU KİŞİLERDEN SEÇEN BİR ÖLÇÜM,
    --    O SAHNENİN GEÇMİŞİNİ DE ÖLÇER — VE EN DOLU VERİTABANINDA EN
    --    KÖTÜ SONUCU VERİR."
    -- ══════════════════════════════════════════════════════════════════
    insert into auth.users (id, email)
    values (gen_random_uuid(), 'n248-host-'  || gen_random_uuid() || '@nobetci.test')
    returning id into v_host;
    insert into auth.users (id, email)
    values (gen_random_uuid(), 'n248-guest-' || gen_random_uuid() || '@nobetci.test')
    returning id into v_guest;

    if v_host is null or v_guest is null then
      v_h := v_h || 'nobetci kendi oyuncularini kuramadi (auth.users yazilamiyor)'::text;
    end if;
    -- Köprü tetikleyicisi (004) profiles/verifications/trust satirlarini
    -- kurar; kurmadiysa ölçüm zaten anlamsiz — burada görelim.
    if not exists (select 1 from profiles where user_id = v_host) then
      v_h := v_h || 'auth kaydi acildi ama profiles satiri olusmadi (004 kopru tetikleyicisi)'::text;
    end if;

    update users set role = 'host' where id = v_host;
    v_d := current_date + 12;

    -- Kapasite beyanini BILEREK bosaltiyoruz: madde 14'un sahnesi bu.
    update profiles set guest_capacity = null where user_id = v_host;

    insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                time_from, time_to, slots, filled, active,
                                visibility, min_trust)
    values (v_host, v_lounge, v_ap::char(3), v_d, time '10:00', time '16:00',
            2, 0, true, 'Public', 60)
    returning id into v_a1;

    -- Gokberk'in ekranindaki durum: AYNI SAATTE ikinci bir ilan. Kural
    -- sonradan konuldu, veri once vardi.
    insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                time_from, time_to, slots, filled, active, visibility)
    values (v_host, v_lounge, v_ap::char(3), v_d, time '10:00', time '16:00',
            2, 0, true, 'Public')
    returning id into v_a2;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_host, 'role','authenticated')::text, true);

    -- (1) MADDE 14'ÜN TA KENDİSİ: yalniz ucus numarasi degisiyor.
    --     Kapasite NULL, ayni saatte ikinci ilan VAR. Eskiden iki ayri
    --     sebeple patliyordu.
    begin
      v_r := public.update_availability(p_id => v_a1, p_flight => 'TK1234');
      if coalesce(v_r ->> 'ok','') <> 'true' then
        v_h := v_h || 'sadece-ucus duzenlemesi ok donmedi'::text;
      end if;
    exception when others then
      v_h := v_h || ('sadece-ucus duzenlemesi HALA PATLIYOR: ' || sqlerrm)::text;
    end;

    -- (2) GÜVEN EŞİĞİ SESSİZCE SİLİNMİYOR (hata sinifi 3)
    begin
      perform public.update_availability(p_id => v_a1, p_visibility => 'all');
      select min_trust into v_min from availabilities where id = v_a1;
      if coalesce(v_min,0) <> 60 then
        v_h := v_h || format('gorunurluk degisince guven esigi %s oldu (60 olmaliydi)', v_min)::text;
      end if;
    exception when others then
      v_h := v_h || ('gorunurluk duzenlemesi patladi: ' || sqlerrm)::text;
    end;

    -- (3) TERS YÖN — kapasite kurali HALA CALISIYOR: slot ARTIRMAK,
    --     beyan yokken reddedilmeli. Kapiyi acmadigimizi kanitlar.
    begin
      perform public.update_availability(p_id => v_a1, p_slots => 3::smallint);
      v_h := v_h || 'kapasite beyani YOKKEN slot artirildi — kapi tamamen acilmis'::text;
    exception when others then
      if sqlerrm not like '%no_access_source%' then
        v_h := v_h || ('slot artirma beklenen hatayi vermedi: ' || sqlerrm)::text;
      end if;
    end;

    -- (4) TERS YÖN — cakismayi KOTULESTIREN duzenleme hala reddedilmeli.
    begin
      insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                  time_from, time_to, slots, filled, active, visibility)
      values (v_host, v_lounge, v_ap::char(3), v_d + 1, time '08:00', time '09:00',
              1, 0, true, 'Public');
      -- a1'i o saate tasimak, YENI bir cakisma yaratir.
      perform public.update_availability(p_id => v_a1, p_date => v_d + 1,
                                         p_from => time '08:00', p_to => time '09:00');
      v_h := v_h || 'YENI cakisma yaratan duzenleme gecti — kural tamamen kalkmis'::text;
    exception when others then
      if sqlerrm not like '%cakisiyor%' then
        v_h := v_h || ('cakisma testi beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;

    -- (5) MADDE 15 — sorularim SOHBET KANALINI donduruyor mu
    if not exists (
      select 1 from information_schema.columns
       where table_schema='public' and table_name='sorularim') then
      -- fonksiyon; kolon adlarini pg_proc'tan dogrula
      if position('channel_id' in pg_get_function_result(
           (select oid from pg_proc where proname='sorularim'
             and pronamespace='public'::regnamespace))) = 0 then
        v_h := v_h || 'sorularim() hala channel_id dondurmuyor (madde 15)'::text;
      end if;
    end if;

    -- (6) MADDE 9 — baglanti istekleri IKI YONU de goruyor mu
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_guest, 'role','authenticated')::text, true);
    -- (delete kalktı — oyuncular yeni, geçmişleri yok. Yukarıdaki
    --  26 Ağustos notuna bak.)
    update verifications set email_verified = true where user_id = v_guest;
    insert into verifications (user_id, email_verified) values (v_guest, true)
      on conflict (user_id) do update set email_verified = true;
    perform public.send_connection(v_host, 'coffee', 'Merhaba');
    select count(*) into v_cnt from public.baglanti_istekleri() where yon = 'giden';
    if v_cnt < 1 then
      v_h := v_h || 'GONDERDIGIM baglanti istegi hicbir yerde gorunmuyor (madde 9)'::text;
    end if;
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_host, 'role','authenticated')::text, true);
    select count(*) into v_cnt from public.baglanti_istekleri() where yon = 'gelen';
    if v_cnt < 1 then
      v_h := v_h || 'GELEN baglanti istegi baglanti_istekleri()nde yok'::text;
    end if;

    -- (7) REDDEDİLDİKTEN SONRA TEKRAR — soguma suresi calisiyor mu
    update connection_requests set status = 'declined', responded_at = now()
     where from_id = v_guest and to_id = v_host;
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_guest, 'role','authenticated')::text, true);
    begin
      perform public.send_connection(v_host, 'coffee', 'Tekrar');
      v_h := v_h || 'reddedilen istek ANINDA tekrar gonderilebildi — taciz kapisi'::text;
    exception when others then
      if sqlerrm not like '%soguma%' then
        v_h := v_h || ('soguma testi beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;
    -- soguma dolunca GECMELI (yoksa eski "asla" durumunu korumus oluruz)
    update connection_requests set responded_at = now() - interval '10 days'
     where from_id = v_guest and to_id = v_host;
    begin
      perform public.send_connection(v_host, 'coffee', 'Tekrar');
    exception when others then
      v_h := v_h || ('soguma dolduktan sonra da gonderilemedi: ' || sqlerrm)::text;
    end;

    -- (8) MADDE 1 — paket abonelikten ucuz olamaz
    begin
      insert into kredi_paketleri (kod, ad, kredi, fiyat_try)
      values ('bedava_gibi', 'Test', 10, 50);
      v_h := v_h || 'abonelikten UCUZ paket eklenebildi — is modeli kapisi yok'::text;
    exception when others then
      if sqlerrm not like '%paket_abonelikten_ucuz%' then
        v_h := v_h || ('paket kapisi beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;

    -- (9) MADDE 11 — degerlendirmelerim iki durumu da tanimliyor mu
    if position('tamamlanan' in coalesce(
         (select prosrc from pg_proc where proname='degerlendirmelerim'
           and pronamespace='public'::regnamespace), '')) = 0 then
      v_h := v_h || 'degerlendirmelerim() tamamlanan durumunu uretmiyor'::text;
    end if;

    raise exception 'GERI_AL_248';
  exception when others then
    if sqlerrm <> 'GERI_AL_248' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '248 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '248 OK · sadece-ucus duzenlemesi geciyor · guven esigi korunuyor · kapasite kapisi duruyor · baglanti istekleri iki yonlu · paket kapisi calisiyor';
end $n248$;

commit;

select '248 KURULDU' as sonuc,
       (select count(*) from kredi_paketleri where aktif) as kredi_paketi,
       (select count(*) from rpc_client_surface
         where fn_name in ('baglanti_istekleri','baglanti_sohbeti_ac','ilan_ozeti',
                           'degerlendirmelerim','kredi_paketleri')) as yeni_yuzey;

-- ════════════════════════════════════════════════════════════════════════
-- §9 — CÜZDAN TANITIM CÜMLESİ HÂLÂ "3 KREDİ" DİYORDU (madde 10)
--
-- Gokberk: "cuzdaninda X misafir hakki bulunuyor tanitim ekraninda hala
-- 1 agirlamaya 3 kredi kazanilacagi yaziyor."
--
-- Olctum, dogru. Cumle SQL 238'de `host_wallet` govdesine METIN olarak
-- gomulmus:
--     'Agirladigin her kisi sana 3 kredi birakiyor: hakkin olmayan bir
--      salonda uc kez misafir olursun.'
-- SQL 246 ekonomiyi degistirdi (host_credit_per_session 3 → 1) ama bu
-- cumleye dokunmadi. Yani sunucu 1 kredi yaziyor, urun 3 kredi vaat
-- ediyordu. Kullanicinin gorecegi ilk celiski bu olurdu ve gelen ilk
-- soru "hani 3 krediydi?" olacakti.
--
-- 🆕 SINIF: "BİR ORANI DEĞİŞTİRİRKEN O ORANI CÜMLEYLE ANLATAN METNİ
-- DEĞİŞTİRMEZSEN, ÜRÜN KENDİ KURALINI YALANLAR."
--
-- Cozum iki katmanli:
--  (1) Cumleyi AYARDAN uret — sabit yazma. Oran bir daha degisirse cumle
--      kendiliginden dogru kalir.
--  (2) Nobetci: `host_wallet` govdesindeki sayi ile beta_settings'teki
--      oran AYNI olmak zorunda. Ayrilirlarsa kurulum durur.
-- ════════════════════════════════════════════════════════════════════════

do $w248$
declare
  v_tanim text;
  v_oran  int;
  v_yeni  text;
  v_eski_sayi text;
begin
  select (value #>> '{}')::int into v_oran
    from beta_settings where key = 'host_credit_per_session';
  if v_oran is null then
    raise notice '248 §9: host_credit_per_session ayari yok — cumleye DOKUNULMADI.';
    return;
  end if;

  -- 🔴 İLK YAZIMIM `prosrc` OKUYUP BAŞLIĞI KENDİM YAZDI VE ORTALIĞI YAKTI.
  --     create or replace function public.host_wallet() returns jsonb ...
  -- Gerçek imza `host_wallet(p_user uuid default null)`. Yani gövdeyi
  -- doğru taşıdım ama İMZAYI EZBERDEN yazdım ve PostgreSQL bunu bir
  -- güncelleme değil YENİ BİR AŞIRI YÜKLEME olarak kaydetti. Sonuç:
  -- SQL 232'nin `host_wallet`e enjekte ettiği sahiplik kapısı (bir
  -- kullanıcının BAŞKASININ cüzdanını açmasını engelleyen kural)
  -- ikinci kurulumda kayboldu ve harness'in TEKRAR KURULUM turunda
  -- 232 ile 238 arka arkaya patladı.
  --
  -- 🆕 SINIF: "BİR FONKSİYONU GÖVDESİNDEN YENİDEN YAZARKEN İMZASINI
  -- EZBERDEN YAZMAK, ONU GÜNCELLEMEK DEĞİL YENİSİNİ YARATMAKTIR."
  --
  -- Doğrusu 232 ve 238'in yaptığı: `pg_get_functiondef` TAM TANIMI verir
  -- (imza + nitelikler + gövde). Değiştirip aynen çalıştırıyorum; imzaya
  -- hiç dokunmuyorum. Bir gövdeyi onarmanin en saglam yolu, imzaya hic
  -- dokunmamaktir.
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   -- 250 ayristirmasindan sonra cumle `host_wallet_hesap`ta.
   where n.nspname = 'public' and p.proname in ('host_wallet_hesap','host_wallet')
   order by coalesce(p.proname = 'host_wallet_hesap', false) desc
   limit 1;
  if v_tanim is null then
    raise notice '248 §9: host_wallet bulunamadi — DOKUNULMADI.'; return;
  end if;

  v_yeni := case when v_oran = 1
    then 'Ağırladığın her kişi sana 1 kredi bırakıyor: açtığın kapı, sana bir kapı açar.'
    else format('Ağırladığın her kişi sana %s kredi bırakıyor: hakkın olmayan bir salonda '
             || '%s kez misafir olursun.', v_oran, v_oran) end;

  if v_tanim !~ 'Ağırladığın her kişi sana \d+ kredi bırakıyor' then
    raise notice '248 §9: cuzdan cumlesi beklenen desende degil — DOKUNULMADI.';
    return;
  end if;

  select (regexp_match(v_tanim, 'Ağırladığın her kişi sana (\d+) kredi bırakıyor'))[1]
    into v_eski_sayi;
  if v_eski_sayi::int = v_oran then
    raise notice '248 §9: cumle zaten % kredi diyor — dokunulmadi.', v_oran;
    return;
  end if;

  v_tanim := regexp_replace(
    v_tanim,
    'Ağırladığın her kişi sana \d+ kredi bırakıyor:[^'']*',
    v_yeni, 'g');

  execute v_tanim;

  raise notice '248 §9: cuzdan cumlesi % kredi → % kredi olarak duzeltildi.',
    v_eski_sayi, v_oran;
end $w248$;

-- NÖBETÇİ: cümle ile ayar AYRILAMAZ.
do $w248n$
declare v_govde text; v_oran int; v_cumle_sayi text; v_imza int;
begin
  select (value #>> '{}')::int into v_oran from beta_settings where key='host_credit_per_session';
  select pg_get_functiondef(p.oid) into v_govde from pg_proc p
   where p.proname in ('host_wallet_hesap','host_wallet') and p.pronamespace='public'::regnamespace
   order by coalesce(p.proname='host_wallet_hesap', false) desc limit 1;
  if v_oran is null or v_govde is null then return; end if;

  -- 🔴 KENDİ HATAMIN NÖBETÇİSİ. İmzayı ezberden yazınca ikinci bir
  -- `host_wallet` doğmuştu. Aşırı yükleme sayısı 1'den fazlaysa bu
  -- dosya (ya da başka biri) imzaya dokunmuş demektir.
  select count(*) into v_imza from pg_proc
   where proname='host_wallet' and pronamespace='public'::regnamespace;
  -- 250 sonrasi kapi `host_wallet`te, cumle `_hesap`ta. Kapiyi ORADA ara.
  if v_imza <> 1 then
    raise exception '248 NOBETCI §9: host_wallet % adet imzaya sahip — biri govdeden yeniden yazarken imzayi ezberden yazmis', v_imza;
  end if;

  -- 232'nin sahiplik kapisi HALA yerinde mi? Bir metni degistirirken
  -- baska birinin kuralini ezmedigimi kanitlamak zorundayim.
  if not exists (select 1 from pg_proc p2
                  where p2.pronamespace='public'::regnamespace
                    and p2.proname in ('host_wallet','host_wallet_hesap')
                    and p2.prosrc like '%cuzdan_sahibi_degil%') then
    raise exception '248 NOBETCI §9: 232 sahiplik kapisi KAYBOLDU — cuzdan cumlesini degistirirken ezdim';
  end if;
  select (regexp_match(v_govde, 'Ağırladığın her kişi sana (\d+) kredi bırakıyor'))[1]
    into v_cumle_sayi;
  if v_cumle_sayi is null then
    raise exception '248 NOBETCI §9: cuzdan cumlesi kayboldu — kullanici hicbir oran gormeyecek';
  end if;
  if v_cumle_sayi::int <> v_oran then
    raise exception '248 NOBETCI §9: cuzdan cumlesi % kredi diyor ama ayar % — urun kendi kuralini yalanliyor',
      v_cumle_sayi, v_oran;
  end if;
  raise notice '248 §9 OK · cuzdan cumlesi ayarla ayni: % kredi', v_oran;
end $w248n$;

-- ════════════════════════════════════════════════════════════════════════
-- §10 — LİSTEMDE OLMAYAN BİR ARIZA: BO "PLAN HEDİYELERİ" EKRANI HİÇ
--       ÇALIŞMIYOR
--
-- Harness'in CANLI ÇAĞRI turu buldu:
--     bo_plan_hediyeleri  []  ERROR: column reference "user_id" is ambiguous
--
-- SEBEP (SQL 236:464): fonksiyon `returns table (... user_id uuid ...)`
-- ilan ediyor. plpgsql'de OUT parametreleri fonksiyon gövdesinde birer
-- DEĞİŞKEN gibi görünür. Gövdedeki yetki kapısı ise şunu diyor:
--
--     select 1 from admin_roles where user_id = auth.uid()
--
-- Buradaki `user_id` iki şeye birden işaret edebilir: `admin_roles.user_id`
-- kolonu ve fonksiyonun kendi OUT parametresi. PostgreSQL bunu çözemez ve
-- 42702 fırlatır — bu bir çalışma zamanı hatası değil, PLANLAMA hatası:
-- deyim her çalıştığında patlar.
--
-- Yani `auth.uid()` dolu olan HER ÇAĞRI (yani BO'daki her gerçek admin)
-- bu ekranı hiç açamıyordu. Ekran canlıda vardı, menüde duruyordu ve
-- HER ZAMAN hata veriyordu.
--
-- 🆕 SINIF: "returns table İLE İLAN EDİLEN HER KOLON ADI, GÖVDEDE BİR
-- DEĞİŞKEN ADIDIR — AYNI ADI TAŞIYAN BİR KOLONA NİTELİKSİZ REFERANS
-- VERMEK, KODU YAZARKEN DEĞİL ÇALIŞTIRIRKEN PATLAR."
--
-- Neden nöbetçiler görmedi: sözleşme denetimi imzayı, tip denetimi
-- kolon tiplerini, yüzey denetimi çağrılıp çağrılmadığını sorar.
-- Hiçbiri fonksiyonu ÇAĞIRMIYOR. Bu arızayı ancak canlı çağrı bulur —
-- ve tam da o buldu.
--
-- Düzeltme: kolonu nitelendiriyoruz (`ar.user_id`). Gövdenin geri kalanına
-- dokunmuyorum; 236'nın hesabı olduğu gibi kalıyor.
-- ════════════════════════════════════════════════════════════════════════

do $b10$
declare v_tanim text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'bo_plan_hediyeleri' limit 1;
  if v_tanim is null then
    raise notice '248 §10: bo_plan_hediyeleri yok — DOKUNULMADI.'; return;
  end if;
  if v_tanim !~ 'from admin_roles where user_id = auth\.uid\(\)' then
    raise notice '248 §10: kapi zaten nitelendirilmis ya da desen degismis — DOKUNULMADI.';
    return;
  end if;
  v_yeni := replace(v_tanim,
    'from admin_roles where user_id = auth.uid()',
    'from admin_roles ar where ar.user_id = auth.uid()');
  execute v_yeni;
  raise notice '248 §10: bo_plan_hediyeleri yetki kapisi nitelendirildi (42702 kapandi).';
end $b10$;

-- AYNI TUZAĞA DÜŞEN BAŞKA FONKSİYON VAR MI?
-- Bir arızayı düzeltip SINIFINI aramamak, aynı hatayı başka bir ekranda
-- bırakmaktır. `returns table` ile bir kolon adı ilan edip gövdede aynı
-- adı NİTELİKSİZ kullanan her fonksiyonu tarıyorum.
do $b10n$
declare r record; v_supheli text[] := '{}'; v_ad text;
begin
  for r in
    select p.proname,
           pg_get_function_result(p.oid) as sonuc,
           p.prosrc as govde
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and pg_get_function_result(p.oid) like 'TABLE%'
  loop
    foreach v_ad in array array['user_id','id','plan','status','name','email']
    loop
      -- kolon ADI donus tipinde ilan edilmis mi
      if r.sonuc ~ ('\m' || v_ad || '\M') then
        -- ve govdede NITELIKSIZ (nokta olmadan) bir esitlik kurulmus mu
        if r.govde ~ ('from [a-z_]+ where ' || v_ad || ' =')
           or r.govde ~ ('and ' || v_ad || ' = auth\.uid\(\)') then
          v_supheli := v_supheli || (r.proname || ' → ' || v_ad);
        end if;
      end if;
    end loop;
  end loop;

  if array_length(v_supheli,1) is not null then
    raise exception '248 NOBETCI §10: % fonksiyon returns-table kolon adiyla ayni adli bir kolona NITELIKSIZ referans veriyor (42702 riski): %',
      array_length(v_supheli,1), array_to_string(v_supheli, ' | ');
  end if;
  raise notice '248 §10 OK · returns-table kolon adiyla cakisan niteliksiz referans yok';
end $b10n$;
