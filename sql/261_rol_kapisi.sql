-- ============================================================================
-- 261 - GUEST/HOST ROL KAPISI  (28 Agustos 2026)
--
-- 🔴 GOKBERK'IN MADDESI, KENDI SOZLERIYLE
-- "Guest ilan acma ve ilanlarim gibi ekranlari gorebiliyor ve ilan acabiliyor.
--  Bu guest'in temasina aykiri. Guest ilan acamamali, ilanlarim gibi bir ekran
--  gorememeli. Ya da host'a ozel yaptigimiz seyler guestte olmamali yani.
--  Bu madde cok kritik."
--
-- ARAYUZ SIZINTISI (app v3.3.3'te olculdu): Planim → Ilanlarim → HostDaveti
-- ekranindaki "+ Musaitlik Ekle" dugmesinde rol kontrolu YOKTU. Guest iki
-- dokunusla ilan formuna giriyordu. App v3.4'te uc kapiyla kapatildi.
--
-- AMA ASIL TEHLIKE ARAYUZDE DEGILDI. 055'ten beri ilan acan kisi SESSIZCE
-- host oluyordu (`update users set role='host'`). Bir misafir merakla formu
-- doldurdugunda rolu degisiyor, ana sayfasi baskalasiyor, bildirim akisi
-- degisiyordu — kimse sormadan.
--
-- 🆕 SINIF: "BIR YAN ETKI KULLANICININ ROLUNU DEGISTIRIYORSA O BIR YAN ETKI
-- DEGIL, SORULMAMIS BIR SORUDUR."
--
-- ============================================================================
-- ⚠️ BU DOSYANIN ILK SURUMU YANLISTI VE NOBETCI YAKALADI — YAZILI KALSIN
--
-- Ilk yazimda `create_availability`'nin govdesini `ETKIN_TANIMLAR.sql`den
-- alip kapiyi icine gomdum. `contract_check.py` kirmizi yandi:
--
--   ❌ rpc('create_availability') FAZLA parametre ['p_carrier'] —
--      fonksiyon (261_rol_kapisi.sql) bunlari tanimiyor
--
-- Sebep: SQL 215 bu fonksiyonu `create_availability_base` diye YENIDEN
-- ADLANDIRMIS ve uzerine 9 parametreli (p_carrier'li) INCE BIR SARMALAYICI
-- koymus. Benim aldigim govde ARTIK GIRIS NOKTASI DEGILDI. Yazdigim 8
-- parametreli fonksiyon canlida AYRI BIR ASIRI YUKLEME olarak durur, app
-- 9 parametreyle cagirdigi icin ESKI yola gider — ve kapi HIC CALISMAZDI.
--
-- Yani migration yesil yanar, nobetci yesil yanar, kapi kapali GORUNUR ve
-- guest ilan acmaya devam ederdi.
--
-- 🆕 SINIF: "BIR FONKSIYONU DEGISTIRMEDEN ONCE ONUN HALA GIRIS NOKTASI
-- OLDUGUNU DOGRULA — SARMALANMIS BIR GOVDEYI DUZELTMEK, KIMSENIN
-- CAGIRMADIGI BIR KODU DUZELTMEKTIR."
--
-- Ve bu deponun kendi kurali (215'in notu) zaten soyluyordu:
--   "Govde HIC KOPYALANMAZ. Ozgun fonksiyon yeniden adlandirilir, ustune
--    ayni imzali ince bir sarmalayici konur."
-- Ben o kurali okumus ama uygulamamistim.
--
-- DOGRU YAKLASIM (bu surum):
--   · Kapi SARMALAYICIYA konuyor — yani gercek giris noktasina.
--   · `_base`in govdesine HIC DOKUNULMUYOR.
--   · `_base` icindeki sessiz terfi (`update users set role='host'`) artik
--     ULASILAMAZ: sarmalayici zaten host olmayani iceri almiyor, dolayisiyla
--     o satirin calisabilecegi tek durum "zaten host" — yani no-op.
--     Terfiyi SILMEK yerine ETKISIZ KILMAK, govdeye dokunmama kuralini
--     bozmadan ayni sonucu veriyor.
--
-- ⚠️ GERIYE UYUMLULUK: bugune kadar ilan acmis herkes 055'in toplu
-- duzeltmesiyle ZATEN role='host'. On kontrol bunu SAYIYOR ve tutmuyorsa
-- migration DURUYOR.
--
-- ⚠️ HOST OLMANIN YOLU KAPANMIYOR, ACIKLASIYOR: `rolumu_sec('host')`
-- (uygulamadaki "Host ol") ya da onaylanmis `host_applications` kaydi.
-- ============================================================================

-- ── ON KONTROL 1: kapi mevcut hicbir host'u disarida birakiyor mu? ────────
do $on261a$
declare v_n int;
begin
  select count(distinct a.host_id) into v_n
    from availabilities a
    join users u on u.id = a.host_id
   where a.active
     and u.role <> 'host'
     and not exists (select 1 from host_applications ha
                      where ha.user_id = u.id and ha.status = 'approved');
  if v_n > 0 then
    -- ⚠️ BU MESAJIN İLK HÂLİ "Once 055 toplu duzeltmesini kosun" DİYORDU
    -- VE O TAVSİYE YANLIŞTI. 055 rol düzeltmesinin yanında
    -- `create_availability`yi 8 PARAMETRELİ olarak da geri kuruyor; oysa
    -- 215 onu `_base` yapıp üstüne 9 parametreli sarmalayıcı koydu.
    -- Yani 055'i bugün koşmak, bu dosyanın kendi başlığında uyardığı
    -- AŞIRI YÜKLEME tuzağını kurardı. Kendi uyarımı okuyup kendi hata
    -- mesajıma koymamışım.
    -- 🆕 SINIF: "BİR HATA MESAJINDAKİ TAVSİYE DE KODUN PARÇASIDIR VE
    -- ONUN GİBİ ESKİR — MESAJI YAZARKEN 'BU HÂLÂ DOĞRU MU' DİYE SOR."
    raise exception E'261 DURDU: aktif ilani olup host olmayan % hesap var.\n'
      '  → Once 261a_rol_uyumlama.sql dosyasini calistir.\n'
      '  ⚠️ 055 KOSMA: rol duzeltmesinin yaninda create_availability''yi'
      ' 8 parametreli olarak geri kurar ve 215''in sarmalayicisiyla'
      ' ikinci bir asiri yukleme yaratir.', v_n;
  end if;
  raise notice '261 on kontrol 1: kapi mevcut hicbir hostu disarida birakmiyor.';
end $on261a$;

-- ── ON KONTROL 2: SARMALAYICI GERCEKTEN ORADA MI ─────────────────────────
-- 🔴 ILK SURUMUMUN DUSTUGU YER TAM BURASIYDI. Artik VARSAYMIYORUM: giris
-- noktasinin 9 parametreli sarmalayici oldugunu ve altinda `_base`
-- bulundugunu DOGRULUYORUM. Tutmuyorsa dosya DURUYOR.
do $on261b$
declare
  v_args text;
  v_beklenen constant text :=
    'p_lounge_id uuid, p_airport text, p_date date, p_from time without time zone, '
    'p_to time without time zone, p_slots integer, p_flight text DEFAULT NULL::text, '
    'p_visibility text DEFAULT ''all''::text, p_carrier text DEFAULT NULL::text';
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                  where n.nspname='public' and p.proname='create_availability_base') then
    raise exception '261 DURDU: create_availability_base YOK — SQL 215 kosulmamis. '
                    'Kapiyi sarmalayiciya koyamam; once 215 kosulmali.';
  end if;

  select pg_get_function_arguments(p.oid) into v_args
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_availability' and p.prokind='f'
   limit 1;

  if v_args is null then
    raise exception '261 DURDU: create_availability sarmalayicisi YOK.';
  end if;
  if v_args <> v_beklenen then
    raise exception E'261 DURDU: sarmalayici imzasi beklenenden FARKLI.\n  canli   : %\n  beklenen: %\n  Kapiyi yanlis imzayla yazmak, app icin 42883 demektir.',
      v_args, v_beklenen;
  end if;
  raise notice '261 on kontrol 2: giris noktasi 9 parametreli sarmalayici, altinda _base var.';
end $on261b$;

-- ── SARMALAYICI YENIDEN YAZILIYOR: TEK DEGISIKLIK, EN USTTEKI KAPI ───────
-- 🔴 GOVDE KOPYALANMIYOR. Bu fonksiyon 215'te YAZILMIS ince bir
-- sarmalayici; icinde is mantigi yok, yalnizca `_base`i cagirip sonuca
-- program bilgisi ekliyor. Asagidaki metin 215'teki ile BIREBIR ayni —
-- tek fark en bastaki dort satirlik kapi.
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
returns jsonb language plpgsql security definer set search_path = public as $fn261$
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
end $fn261$;

revoke all on function public.create_availability(uuid, text, date, time, time, integer, text, text, text)
  from public, anon;
grant execute on function public.create_availability(uuid, text, date, time, time, integer, text, text, text)
  to authenticated;

-- ── HOST NIYETI SORGUSU ────────────────────────────────────────────────
-- Uygulama "bu kullanici ilan acabilir mi" sorusunu artik TAHMIN etmiyor,
-- SORUYOR. Arayuz kapisi ile sunucu kapisi boylece AYNI cevabi verir.
--
-- 🆕 SINIF: "AYNI KURALI HEM ISTEMCIDE HEM SUNUCUDA YAZARSAN IKI KURALIN
-- OLUR - SUNUCU KARAR VERSIN, ISTEMCI SORSUN."
create or replace function public.ilan_acabilir_miyim()
returns jsonb
language sql
stable
security definer
set search_path = public
as $iam261$
  select jsonb_build_object(
    'acabilir', exists (select 1 from users u where u.id = auth.uid() and u.role = 'host')
             or exists (select 1 from host_applications ha
                         where ha.user_id = auth.uid() and ha.status = 'approved'),
    'rol', (select u.role from users u where u.id = auth.uid())
  );
$iam261$;
revoke all on function public.ilan_acabilir_miyim() from public, anon;
grant execute on function public.ilan_acabilir_miyim() to authenticated;

-- ── NOBETCI ────────────────────────────────────────────────────────────
-- 🔴 "Kapiyi yazdim" ile "kapi kapaniyor" ayni sey degildir. Bu blok
-- veritabaninin SAKLADIGI tanimi okuyor — benim yazdigim metni degil.
--
-- 🆕 SINIF: "BIR KAPIYI YAZDIGIN METINDE DEGIL, VERITABANININ SAKLADIGI
-- TANIMDA DOGRULA - ARADAKI FARK TAM DA HATANIN SAKLANDIGI YERDIR."
do $nb261$
declare
  v_metin text;
  v_n int;
begin
  -- Kapi 9 PARAMETRELI olanda mi? (Ilk surumum 8 parametreliye yazmisti.)
  select pg_get_functiondef(p.oid) into v_metin
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_availability'
     and p.pronargs = 9
   limit 1;

  if v_metin is null then
    raise exception '261 NOBETCI: 9 parametreli create_availability YOK.';
  end if;
  if position('not_a_host' in v_metin) = 0 then
    raise exception '261 NOBETCI: rol kapisi GIRIS NOKTASINDA yok.';
  end if;
  if position('create_availability_base' in v_metin) = 0 then
    raise exception '261 NOBETCI: sarmalayici _base cagirmiyor — zincir kopmus.';
  end if;

  -- 🔴 ASIRI YUKLEME KALMASIN: 8 parametreli bir surum durursa PostgREST
  -- hangisini cagiracagini imza uyusmasina gore secer ve KAPISIZ olani
  -- secebilir. Ilk surumumun birakacagi tuzak tam olarak buydu.
  select count(*) into v_n from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_availability';
  if v_n <> 1 then
    raise exception '261 NOBETCI: create_availability icin % asiri yukleme var — kapisiz olan cagrilabilir.', v_n;
  end if;

  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                  where n.nspname='public' and p.proname='ilan_acabilir_miyim') then
    raise exception '261 NOBETCI: ilan_acabilir_miyim kurulmadi.';
  end if;

  raise notice '261 NOBETCI OK: kapi giris noktasinda, zincir saglam, asiri yukleme yok.';
end $nb261$;
