-- ============================================================================
-- 349 · 348'İN GERİLETTİĞİ create_availability VE YETKİLER GERİ ALINIR   (9 Kasım 2026)
--
-- SEBEP (ölçüldü): 348'in "olması gereken" kaynağı, yerel kurulumun İKİNCİ geçişinden
-- (tekrar kurulum stres testi) sonra alınmıştı; o geçiş bazı fonksiyonları eski hâline
-- yazıyordu. 348 bu yüzden canlıda:
--   · create_availability'yi 261/323 sarmalayıcısı yerine _base'in ESKİ gövdesine çevirdi →
--     onaysız misafir ilan açıp kendini host yapabiliyordu (328 delindi), 323'ün
--     "kendi ilanların çakışıyor" ve saat sırası kapıları düştü;
--   · 27 fonksiyonun yetkisini yanlış kaynağa göre değiştirdi.
-- Doğru hâl: ikinci geçiş OLMADAN 001-347 kurulmuş yerel veritabanı (pg_run LL_TEKRAR_ATLA=1).
-- create_availability'nin doğru gövdesi canlının 348 ÖNCESİ hâliyle birebir aynı (ed18e0e5).
-- Tetikleyici fonksiyonları (trg_*) 348'deki gibi KAPALI kalır: Postgres tetikleyici
-- yetkisini yalnız tetikleyici oluşturulurken denetler; kapatmak hiçbir şeyi bozmaz.
-- pg_run artık ikinci geçişte GÖVDE değişimini de "GERİLEME" sayıyor (bu sınıf bir daha kaçmaz).
-- Tekrar koşulabilir. Doğrulama: 3 satır, hepsi tamam = true. Sonra DENETIM_TAM.sql.
-- ============================================================================

-- ── 1 · create_availability doğru gövde ─────────────────────────────────────
-- create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text)  (348 sonrası 423b4191 → doğru ed18e0e5; 348 öncesi canlı ed18e0e5)
create or replace function public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text DEFAULT NULL::text, p_visibility text DEFAULT 'all'::text, p_carrier text DEFAULT NULL::text)
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

-- ── 2 · YETKİLER (dosyaların kurduğu hâl) ───────────────────────────────────
-- create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text)  (-u → -u)
revoke execute on function public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text) from public, anon, authenticated;
grant execute on function public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text) to service_role;
grant execute on function public.create_availability(p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, p_to time without time zone, p_slots integer, p_flight text, p_visibility text, p_carrier text) to authenticated;

-- istegin_acik_oturumu_var_mi(p_req uuid)  (-u → au)
revoke execute on function public.istegin_acik_oturumu_var_mi(p_req uuid) from public, anon, authenticated;
grant execute on function public.istegin_acik_oturumu_var_mi(p_req uuid) to service_role;
grant execute on function public.istegin_acik_oturumu_var_mi(p_req uuid) to anon;
grant execute on function public.istegin_acik_oturumu_var_mi(p_req uuid) to authenticated;

-- plan_kredisi_kalan(p_user uuid)  (-u → --)
revoke execute on function public.plan_kredisi_kalan(p_user uuid) from public, anon, authenticated;
grant execute on function public.plan_kredisi_kalan(p_user uuid) to service_role;

-- plan_ucretli(p_plan text)  (-u → --)
revoke execute on function public.plan_ucretli(p_plan text) from public, anon, authenticated;
grant execute on function public.plan_ucretli(p_plan text) to service_role;

-- profil_dogrulandi_hesapla(p_user uuid)  (-u → --)
revoke execute on function public.profil_dogrulandi_hesapla(p_user uuid) from public, anon, authenticated;
grant execute on function public.profil_dogrulandi_hesapla(p_user uuid) to service_role;

-- push_kanali(p_category notif_category)  (-u → au)
revoke execute on function public.push_kanali(p_category notif_category) from public, anon, authenticated;
grant execute on function public.push_kanali(p_category notif_category) to service_role;
grant execute on function public.push_kanali(p_category notif_category) to anon;
grant execute on function public.push_kanali(p_category notif_category) to authenticated;

-- push_kanali(p_category text)  (-u → au)
revoke execute on function public.push_kanali(p_category text) from public, anon, authenticated;
grant execute on function public.push_kanali(p_category text) to service_role;
grant execute on function public.push_kanali(p_category text) to anon;
grant execute on function public.push_kanali(p_category text) to authenticated;

-- seed_test_hesabi(p_email text)  (-u → --)
revoke execute on function public.seed_test_hesabi(p_email text) from public, anon, authenticated;
grant execute on function public.seed_test_hesabi(p_email text) to service_role;

-- sogu_baslangic_ozeti(p_airport text)  (-u → au)
revoke execute on function public.sogu_baslangic_ozeti(p_airport text) from public, anon, authenticated;
grant execute on function public.sogu_baslangic_ozeti(p_airport text) to service_role;
grant execute on function public.sogu_baslangic_ozeti(p_airport text) to anon;
grant execute on function public.sogu_baslangic_ozeti(p_airport text) to authenticated;

-- telefon_kanonik(p_phone text)  (-u → au)
revoke execute on function public.telefon_kanonik(p_phone text) from public, anon, authenticated;
grant execute on function public.telefon_kanonik(p_phone text) to service_role;
grant execute on function public.telefon_kanonik(p_phone text) to anon;
grant execute on function public.telefon_kanonik(p_phone text) to authenticated;

-- tutma_sebepleri()  (-u → au)
revoke execute on function public.tutma_sebepleri() from public, anon, authenticated;
grant execute on function public.tutma_sebepleri() to service_role;
grant execute on function public.tutma_sebepleri() to anon;
grant execute on function public.tutma_sebepleri() to authenticated;

-- tutma_varsayim_esigi()  (-u → au)
revoke execute on function public.tutma_varsayim_esigi() from public, anon, authenticated;
grant execute on function public.tutma_varsayim_esigi() to service_role;
grant execute on function public.tutma_varsayim_esigi() to anon;
grant execute on function public.tutma_varsayim_esigi() to authenticated;

-- tutulan_kredi(p_req uuid)  (-u → au)
revoke execute on function public.tutulan_kredi(p_req uuid) from public, anon, authenticated;
grant execute on function public.tutulan_kredi(p_req uuid) to service_role;
grant execute on function public.tutulan_kredi(p_req uuid) to anon;
grant execute on function public.tutulan_kredi(p_req uuid) to authenticated;

-- ucus_hatti(p_origin text, p_dest text)  (-u → au)
revoke execute on function public.ucus_hatti(p_origin text, p_dest text) from public, anon, authenticated;
grant execute on function public.ucus_hatti(p_origin text, p_dest text) to service_role;
grant execute on function public.ucus_hatti(p_origin text, p_dest text) to anon;
grant execute on function public.ucus_hatti(p_origin text, p_dest text) to authenticated;

-- yerel_an(p_date date, p_time time without time zone, p_airport text)  (au → -u)
revoke execute on function public.yerel_an(p_date date, p_time time without time zone, p_airport text) from public, anon, authenticated;
grant execute on function public.yerel_an(p_date date, p_time time without time zone, p_airport text) to service_role;
grant execute on function public.yerel_an(p_date date, p_time time without time zone, p_airport text) to authenticated;

-- yerel_gun(p_airport text)  (au → -u)
revoke execute on function public.yerel_gun(p_airport text) from public, anon, authenticated;
grant execute on function public.yerel_gun(p_airport text) to service_role;
grant execute on function public.yerel_gun(p_airport text) to authenticated;

-- yerel_saat(p_airport text)  (au → -u)
revoke execute on function public.yerel_saat(p_airport text) from public, anon, authenticated;
grant execute on function public.yerel_saat(p_airport text) to service_role;
grant execute on function public.yerel_saat(p_airport text) to authenticated;

-- yonetici_kapisi()  (-- → -u)
revoke execute on function public.yonetici_kapisi() from public, anon, authenticated;
grant execute on function public.yonetici_kapisi() to service_role;
grant execute on function public.yonetici_kapisi() to authenticated;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'create_availability: host kapisi ve 323 sarmalayicisi geri geldi' as kontrol,
       position('not_a_host' in pg_get_functiondef('public.create_availability(uuid,text,date,time,time,integer,text,text,text)'::regprocedure)) > 0
   and position('create_availability_base' in pg_get_functiondef('public.create_availability(uuid,text,date,time,time,integer,text,text,text)'::regprocedure)) > 0 as tamam
union all select 'create_availability govdesi 348 oncesi canliyla ayni',
       md5(regexp_replace(pg_get_functiondef('public.create_availability(uuid,text,date,time,time,integer,text,text,text)'::regprocedure), '\s+', '', 'g')) = 'ed18e0e5cc9021d34e441b4432b18bb0'
union all select 'tetikleyici fonksiyonlari istemciye kapali kaldi',
       not has_function_privilege('anon', 'public.trg_bakiye_negatife_dusemez()', 'execute')
   and not has_function_privilege('authenticated', 'public.trg_mesaj_bildirimi()', 'execute');
-- Beklenen: 3 satır, hepsi tamam = true.
