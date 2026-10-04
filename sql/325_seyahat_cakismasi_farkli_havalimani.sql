-- ============================================================================
-- 325 · SEYAHAT ÇAKIŞMASI: FARKLI HAVALİMANI + DÜZENLEME  (4 Ekim 2026)
--
-- BULGU (B15 · uçtan uca test, Gökberk onayı): aynı saatlerde FARKLI havalimanında
-- ikinci seyahat kabul ediliyordu (IST 10–12 varken SAW 11–13). Ne uygulama ne sunucu
-- denetliyordu. Ayrıca update_visit HİÇ çakışma denetlemiyordu — aynı havalimanında bile.
-- DÜZELTME: tek kapı `seyahat_cakisma_kapisi` — aynı havalimanı (eski kod
-- ayni_saatte_seyahatin_var) + farklı havalimanı mutlak saatle (yeni kod
-- baska_havalimaninda_seyahatin_var, i18n TR+EN app 6.3.4'te). seyahat_ekle ve
-- update_visit (kendisi hariç) ikisi de kullanır. Var olan çakışan kayıtlara dokunulmaz.
-- Gövdeler CANLI tanımın üstüne eklendi. Supabase SQL Editor: tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.seyahat_cakisma_kapisi(p_uid uuid, p_airport text, p_date date,
                                                          p_from time, p_to time, p_haric uuid)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_bas timestamptz; v_son timestamptz;
begin
  -- Aynı havalimanı · aynı gün · saat örtüşüyor (eski kural, aynı kod ve cümle)
  if exists (select 1 from visits v
              where v.user_id = p_uid and v.airport_code = upper(btrim(p_airport))::char(3)
                and v.visit_date = p_date and v.id is distinct from p_haric
                and v.time_from < p_to and p_from < v.time_to) then
    raise exception 'ayni_saatte_seyahatin_var';
  end if;
  -- 325 · FARKLI havalimanı: bir kişi aynı anda iki havalimanında olamaz. Saatler her
  -- havalimanının KENDİ yerel saati → mutlak zamana çevrilip kıyaslanır (IST 10:00 ≠ LHR 10:00).
  -- Aktarmalı aynı gün yolculuklar (IST 05–08, ESB 13–16) örtüşmediği için etkilenmez.
  v_bas := public.yerel_an(p_date, p_from, p_airport);
  v_son := public.yerel_an(p_date, p_to, p_airport);
  if exists (select 1 from visits v
              where v.user_id = p_uid and v.airport_code <> upper(btrim(p_airport))::char(3)
                and v.id is distinct from p_haric
                and v.visit_date between p_date - 1 and p_date + 1
                and public.yerel_an(v.visit_date, v.time_from, v.airport_code) < v_son
                and v_bas < public.yerel_an(v.visit_date, v.time_to, v.airport_code)) then
    raise exception 'baska_havalimaninda_seyahatin_var';
  end if;
end $function$;
revoke execute on function public.seyahat_cakisma_kapisi(uuid,text,date,time,time,uuid) from public, anon, authenticated;
grant execute on function public.seyahat_cakisma_kapisi(uuid,text,date,time,time,uuid) to service_role;

CREATE OR REPLACE FUNCTION public.seyahat_ekle(p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_destination text DEFAULT NULL::text, p_flight text DEFAULT NULL::text, p_purpose text DEFAULT NULL::text, p_carrier text DEFAULT NULL::text, p_kisi integer DEFAULT 1, p_cocuk_yas integer[] DEFAULT NULL::integer[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  perform public.motor_yazimi_ac();
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);   -- 282/B1
  if p_airport is null or btrim(p_airport) = '' then raise exception 'airport_required'; end if;
  if p_date is null then raise exception 'date_required'; end if;
  if p_date < current_date then raise exception 'date_in_past'; end if;
  if p_from is null or p_to is null or p_from >= p_to then raise exception 'invalid_time_range'; end if;
  if not exists (select 1 from airports where code = upper(btrim(p_airport))::char(3)) then
    raise exception 'unknown_airport';
  end if;
  if p_kisi is null or p_kisi < 1 or p_kisi > 6 then raise exception 'party_size_invalid'; end if;
  if p_cocuk_yas is not null and (array_length(p_cocuk_yas,1) >= p_kisi
     or exists (select 1 from unnest(p_cocuk_yas) x where x < 0 or x > 17)) then
    raise exception 'child_ages_invalid';
  end if;
  -- 325 · çakışma kuralı tek yerde (aynı havalimanı + FARKLI havalimanı, mutlak saatle)
  perform public.seyahat_cakisma_kapisi(v_uid, upper(btrim(p_airport)), p_date, p_from, p_to, null);

  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number,
                      party_size, child_ages)
  values (v_uid, upper(btrim(p_airport))::char(3),
          nullif(upper(btrim(coalesce(p_destination,''))),'')::char(3),
          p_date, p_from, p_to, nullif(btrim(coalesce(p_flight,'')),''),
          p_kisi, nullif(p_cocuk_yas::smallint[], '{}'::smallint[]))
  returning id into v_id;

  if p_purpose is not null then perform public.set_visit_purpose(v_id, p_purpose); end if;
  if p_carrier is not null then perform public.set_visit_carrier(v_id, p_carrier); end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end $function$;

CREATE OR REPLACE FUNCTION public.update_visit(p_id uuid, p_airport text DEFAULT NULL::text, p_destination text DEFAULT NULL::text, p_date date DEFAULT NULL::date, p_from time without time zone DEFAULT NULL::time without time zone, p_to time without time zone DEFAULT NULL::time without time zone, p_flight text DEFAULT NULL::text, p_carrier text DEFAULT NULL::text, p_purpose text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- 325 · DÜZENLEME çakışma denetlemiyordu (aynı havalimanında bile): bir seyahati
  -- diğerinin üstüne kaydırmak mümkündü. Kendisi hariç aynı kapı.
  perform public.seyahat_cakisma_kapisi(v_uid, v_ap, v_d, v_f, v_t, p_id);

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
end $function$;

select 'cakisma kapisi kullaniliyor' as kontrol,
       position('seyahat_cakisma_kapisi' in pg_get_functiondef('public.seyahat_ekle(text,date,time,time,text,text,text,text,integer,integer[])'::regprocedure)) > 0
   and position('seyahat_cakisma_kapisi' in pg_get_functiondef('public.update_visit(uuid,text,text,date,time,time,text,text,text)'::regprocedure)) > 0 as tamam;
-- Beklenen: tamam = true.
