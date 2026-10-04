-- ============================================================================
-- 323 · İLAN AÇ: TERS SAAT / 0 KİŞİ TÜRKÇE SEBEPLE REDDEDİLİR  (4 Ekim 2026)
--
-- BULGU (uçtan uca test · iş kuralları): create_availability bitiş ≤ başlangıç
-- ve kontenjan < 1 durumlarını yalnız tablo kısıtına bırakıyordu → istemciye
-- `new row for relation "availabilities" violates check constraint` düşüyor,
-- kullanıcı "Bir şeyler ters gitti" görüyordu. seyahat_ekle bunu zaten
-- 'invalid_time_range' ile reddediyor; ilan da aynı dili konuşur.
-- Gövde CANLI tanımın üstüne eklendi. Supabase SQL Editor: tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text DEFAULT NULL::text, p_visibility text DEFAULT 'all'::text, p_carrier text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v jsonb; v_id uuid;
  v_pg uuid; v_kaynak text; v_kod text; v_ad text;
begin
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 261 — ROL KAPISI. ILAN ACMAK ARTIK KIMSEYI SESSIZCE HOST YAPMAZ.
  --
  -- Kapi EN USTTE: `_base` cagrilmadan once. Boylece `_base` icindeki
  -- 055 terfisi (`update users set role='host'`) ULASILAMAZ hale
  -- geliyor — buraya gelen zaten host.
  --
  -- Host olmanin TEK yolu artik acik niyet: `rolumu_sec('host')`
  -- (uygulamadaki "Host ol" dugmesi) ya da onaylanmis host basvurusu.
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from users u where u.id = auth.uid() and u.role = 'host')
     and not exists (select 1 from host_applications ha
                      where ha.user_id = auth.uid() and ha.status = 'approved')
  then
    raise exception 'not_a_host';
  end if;
  -- 323 · Saat sırası ve kontenjan alt sınırı yalnız tablo KISITINDAYDI: ters saatte
  -- kullanıcı ham "violates check constraint" (→ "Bir şeyler ters gitti") görüyordu.
  -- Kodlar i18n'de zaten var (invalid_time_range · invalid_slots).
  if p_from is null or p_to is null or p_from >= p_to then raise exception 'invalid_time_range'; end if;
  if p_slots is null or p_slots < 1 then raise exception 'invalid_slots'; end if;
  -- 🔴 301/§5: KENDİ İLANIYLA ÇAKIŞAN İLAN açılabiliyordu (tam akış testi,
  -- 10–13 varken 12–15 GEÇTİ). `update_availability` bunu 'kendi_ilanlarin_
  -- cakisiyor' ile zaten reddediyordu — açma yolu reddetmiyordu. Aynı kişi
  -- aynı saatte iki salonda olamaz; ikinci ilana kabul edilen misafir kapıda kalır.
  if exists (select 1 from availabilities a
              where a.host_id = auth.uid() and a.active
                and a.avail_date = p_date
                and a.time_from < p_to and p_from < a.time_to) then
    raise exception 'kendi_ilanlarin_cakisiyor'
      using hint = 'Bu saatte başka bir ilanın var. Önce onu kaldır ya da saatleri ayır.';
  end if;
  -- ══════════════════════════════════════════════════════════════════

  -- Butun kapilar, kotalar, bildirimler _base zincirinde.
  -- Buraya tek bir is kaldi: SONUCU ANLATMAK.
  v := public.create_availability_base(
         p_lounge_id, p_airport, p_date, p_from, p_to, p_slots,
         p_flight, p_visibility, p_carrier);

  v_id := nullif(v ->> 'id', '')::uuid;
  if v_id is null then
    return v;   -- _base bir sey dondurmediyse uydurmuyoruz
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
    'program_notu', case
      when v_pg is null then
        'Bu ilan bir kart programına bağlanamadı: hak beyanınız bu salonun kabul listesiyle eşleşmiyor. İlan yayında; yalnız sağlayıcı raporunda "program bilinmeyen" sayılacak.'
      when coalesce(v_kaynak, '') = 'turetildi' then
        format('Bu ilan "%s" programı altında sayılacak. Bu bir ÇIKARIM: doğrulanmış hak beyanınızdan türetildi, sizin beyanınız değil.', coalesce(v_ad, v_kod))
      else
        format('Bu ilan "%s" programı altında sayılacak (beyan).', coalesce(v_ad, v_kod))
      end);
end $function$;

select 'ilan saat sirasi kapisi' as kontrol,
       position('323 · Saat sırası' in pg_get_functiondef(p.oid)) > 0 as tamam
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'create_availability';
-- Beklenen: tamam = true.
