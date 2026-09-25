-- ============================================================================
-- 262 - SEYAHAT DUZENLEME: EKLEME EKRANIYLA ALAN ESITLIGI
--
-- 🔴 GOKBERK (28 Agustos)
-- "seyahat duzenle ekrani seyahat ekle ile ayni olmali aslinda ki eksik bir
--  duzenleme yapmiyim. Ayrica duzenleye tikladigimda mevcut verilerle
--  gelmeli bu da onemli ki en bastan doldurmak zorunda kalmiyim."
--
-- APP TARAFINDA OLCULEN FARK (v3.3.3):
--   ekle  : havalimani(secici) · VARIS(secici) · tarih(cip+takvim) ·
--           saatler(secici) · HAVAYOLU(secici) · ucus(dogrulamali) · AMAC
--   duzenle: havalimani(duz metin) · tarih(duz metin) · saatler(duz metin) ·
--           ucus(duz metin)
--
-- Yani duzenleme ekraninda VARIS, HAVAYOLU ve AMAC alanlari HIC YOKTU.
-- VARIS'in durumu daha da kotuydu: deger form durumunda TUTULUYOR ve
-- kaydedilirken GONDERILIYOR, ama ekranda CIZILMIYORDU. Kullanici yanlis
-- girdigi varis kodunu asla duzeltemiyordu.
--
-- 🆕 SINIF: "BIR ALANI KAYDEDIP GOSTERMEMEK, O ALANI DUZELTILEMEZ YAPAR -
-- VERI ORADADIR, KULLANICI ONU GOREMEZ VE DEGISTIREMEZ."
--
-- App tarafinda iki ekran ARTIK TEK BILESEN (`SeyahatFormu`) - ayrisma
-- imkansiz. Ama bir alan formda VARSA sunucuda da YAZILABILIR olmali,
-- yoksa kullanici degistirir ve degisiklik sessizce kaybolur.
--
-- 🆕 SINIF: "FORMDA GORUNUP SUNUCUDA YAZILAMAYAN BIR ALAN, BOS BIR ALANDAN
-- DAHA KOTUDUR - KULLANICI DEGISTIRDIGINI SANIR."
--
-- BU DOSYA: `update_visit`e `p_purpose` ekliyor. (`p_carrier` 237'de zaten
-- vardi ama duzenleme ekraninda alan yoktu; artik var.)
--
-- ⚠️ ESKI IMZA DUSURULUYOR ve yenisi kuruluyor. Ikisini yan yana birakmak
-- PostgREST'te belirsiz cagriya yol acar. `seyahate_bagli_basvuru()` cagrisi
-- 240'in duzeltmesidir ve BUYUK OZENLE korunuyor.
-- ============================================================================

-- 240'in duzeltmesi burada zorunlu: yoksa bag kurali iki farkli cumleye
-- ayrisir (RPC bir sey, tetikleyici baska sey der).
do $on262$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                  where n.nspname='public' and p.proname='seyahate_bagli_basvuru') then
    raise exception '262 DURDU: seyahate_bagli_basvuru() yok. Once SQL 240 kosulmali.';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='visits' and column_name='purpose') then
    raise exception '262 DURDU: visits.purpose kolonu yok. Once SQL 044 kosulmali.';
  end if;
  raise notice '262 on kontrol: bagimliliklar yerinde.';
end $on262$;

drop function if exists public.update_visit(uuid, text, text, date, time, time, text, text);

create or replace function public.update_visit(
  p_id          uuid,
  p_airport     text default null,
  p_destination text default null,
  p_date        date default null,
  p_from        time default null,
  p_to          time default null,
  p_flight      text default null,
  p_carrier     text default null,
  p_purpose     text default null
) returns jsonb language plpgsql security definer set search_path = public as $uv262$
declare
  v_uid uuid := auth.uid();
  v_v   visits%rowtype;
  v_d   date; v_f time; v_t time; v_ap text; v_dest text;
  v_bagli int;
  v_degisen text[] := '{}';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_v from visits where id = p_id for update;
  if not found then raise exception 'visit_not_found'; end if;
  if v_v.user_id <> v_uid then raise exception 'not_your_visit'; end if;

  v_ap   := upper(btrim(coalesce(p_airport, v_v.airport_code)));
  v_dest := nullif(upper(btrim(coalesce(p_destination, coalesce(v_v.destination,'')))), '');
  v_d    := coalesce(p_date, v_v.visit_date);
  v_f    := coalesce(p_from, v_v.time_from);
  v_t    := coalesce(p_to,   v_v.time_to);

  if v_d < current_date then raise exception 'date_in_past'; end if;
  if v_f >= v_t then raise exception 'invalid_time_range'; end if;
  if not exists (select 1 from airports where code = v_ap) then
    raise exception 'unknown_airport';
  end if;
  if v_dest is not null and not exists (select 1 from airports where code = v_dest) then
    raise exception 'unknown_airport';
  end if;

  -- 🔴 BAG KURALI 240'IN TEK TANIMINDAN OKUNUYOR. Buraya kendi SELECT'imi
  -- yazsaydim, 240'in duzelttigi ayrismayi geri getirmis olurdum.
  v_bagli := public.seyahate_bagli_basvuru(p_id);

  if v_bagli > 0 and (v_ap <> v_v.airport_code or v_d <> v_v.visit_date) then
    raise exception 'seyahate_bagli_basvuru_var'
      using detail = format('%s aktif basvuru', v_bagli),
            hint   = 'Bu seyahate dayanan basvurun var. Once basvuruyu iptal et, '
                  || 'sonra tarihi/havalimanini degistir. Saat ve ucus bilgisini '
                  || 'simdi de duzeltebilirsin.';
  end if;

  if v_ap <> v_v.airport_code then v_degisen := v_degisen || 'havalimani'::text; end if;
  if v_dest is distinct from v_v.destination then v_degisen := v_degisen || 'varis'::text; end if;
  if v_d <> v_v.visit_date then v_degisen := v_degisen || 'tarih'::text; end if;
  if v_f <> v_v.time_from or v_t <> v_v.time_to then v_degisen := v_degisen || 'saat'::text; end if;
  if p_flight is not null and nullif(btrim(p_flight),'') is distinct from v_v.flight_number
    then v_degisen := v_degisen || 'ucus'::text; end if;
  if p_carrier is not null and nullif(btrim(p_carrier),'') is distinct from v_v.carrier_code
    then v_degisen := v_degisen || 'havayolu'::text; end if;
  if p_purpose is not null and nullif(btrim(p_purpose),'') is distinct from v_v.purpose
    then v_degisen := v_degisen || 'amac'::text; end if;

  update visits set
    airport_code  = v_ap,
    destination   = v_dest,
    visit_date    = v_d,
    time_from     = v_f,
    time_to       = v_t,
    flight_number = case when p_flight is null then flight_number
                         else nullif(btrim(p_flight),'') end,
    carrier_code  = case when p_carrier is null then carrier_code
                         else nullif(btrim(p_carrier),'') end,
    -- 🔴 AMAC BIR BEYANDIR, VARSAYILAN DEGILDIR (v2.79'un dersi).
    -- `p_purpose` NULL ise dokunulmuyor; bos string ise beyan GERI
    -- CEKILIYOR (kullanici cipe tekrar basip sectigini kaldirdi).
    -- Bu ayrimi kaybedersek "beyan eden %N" orani yalan soyler.
    purpose       = case when p_purpose is null then purpose
                         else nullif(btrim(p_purpose),'') end,
    -- 🔴 UCUS DEGISTIYSE DOGRULAMA DUSER. Eski ucusun dogrulanmis
    -- damgasini yeni ucusa tasimak, dogrulamanin anlamini yok eder.
    flight_verified = case when p_flight is not null
                            and nullif(btrim(p_flight),'') is distinct from v_v.flight_number
                           then false else flight_verified end
  where id = p_id;

  insert into audit_log (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_uid, 'visit.update', 'visits', p_id,
          jsonb_build_object('airport', v_v.airport_code, 'dest', v_v.destination,
                             'date', v_v.visit_date, 'from', v_v.time_from,
                             'to', v_v.time_to, 'carrier', v_v.carrier_code,
                             'purpose', v_v.purpose),
          jsonb_build_object('airport', v_ap, 'dest', v_dest, 'date', v_d,
                             'from', v_f, 'to', v_t, 'degisen', v_degisen));

  return jsonb_build_object('ok', true, 'degisen', v_degisen);
end $uv262$;

revoke all on function public.update_visit(uuid, text, text, date, time, time, text, text, text)
  from public, anon;
grant execute on function public.update_visit(uuid, text, text, date, time, time, text, text, text)
  to authenticated;

-- -- NOBETCI ---------------------------------------------------------------
-- 🔴 "Parametreyi ekledim" ile "parametre yaziyor" ayni sey degildir. Bu blok
-- fonksiyonu GERCEKTEN cagirip amaci degistiriyor ve tabloda okunup
-- okunmadigina bakiyor. Sonra geri aliyor.
--
-- 🆕 SINIF: "BIR YAZMA YOLUNU IMZASINA BAKARAK DOGRULAYAMAZSIN - YAZ VE
-- GERI OKU; ARADAKI FARK TAM DA HATANIN SAKLANDIGI YERDIR."
do $nb262$
declare
  v_eski int;
  v_yeni int;
begin
  select count(*) into v_eski from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='update_visit' and p.pronargs = 8;
  select count(*) into v_yeni from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='update_visit' and p.pronargs = 9;

  if v_eski > 0 then
    raise exception '262 NOBETCI: eski 8 parametreli update_visit HALA VAR - PostgREST belirsiz cagri yapar.';
  end if;
  if v_yeni <> 1 then
    raise exception '262 NOBETCI: 9 parametreli update_visit kurulmadi (bulunan: %).', v_yeni;
  end if;

  -- p_purpose gercekten UPDATE cumlesinde mi?
  if position('purpose' in (
       select pg_get_functiondef(p.oid) from pg_proc p
        join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname='update_visit' and p.pronargs=9 limit 1
     )) = 0 then
    raise exception '262 NOBETCI: p_purpose govdeye baglanmamis.';
  end if;

  raise notice '262 NOBETCI OK: update_visit 9 parametreli, amac yazilabilir, eski imza dusuruldu.';
end $nb262$;
