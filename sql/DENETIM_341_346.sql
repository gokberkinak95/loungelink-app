-- ============================================================================
-- DENETIM · 341–346 CANLIDA GERÇEKTEN UYGULANDI MI?   (8 Kasım 2026)
--
-- Supabase SQL Editor yalnız SON ifadenin sonucunu gösterir: bir dosyanın ortasındaki
-- adım düşse bile ekranda "Success" görülebilir. Bu sorgu 341–346'nın bütün doğrulama
-- satırlarını TEK tabloda verir. Hiçbir şey DEĞİŞTİRMEZ (yalnız okur).
-- Beklenen: her satırda tamam = true. false olan satırın dosyasını tekrar çalıştır.
-- ============================================================================
select * from (
  -- 341
  select '341' as dosya, 'plan maddelerinde "lounge girişi" kalmadı' as kontrol,
         not exists (select 1 from plan_catalog where perks::text like '%lounge giriş%') as tamam
  union all select '341', 'İngilizce maddelerde "lounge visit" kalmadı',
         not exists (select 1 from plan_catalog where perks_en::text like '%lounge visit%')
  union all select '341', 'Sık Uçan: her ay 3 ilan başvurusu',
         exists (select 1 from plan_catalog where plan = 'sik_ucan' and perks::text like '%Her ay 3 ilan başvurusu%')
  union all select '341', '1 kredi paketi açıklaması',
         not exists (select 1 from kredi_paketleri where aciklama like '%lounge isteği%')
  -- 342
  union all select '342', 'oturum başlatma kapısı (session_window_closed)',
         coalesce(position('session_window_closed' in pg_get_functiondef(to_regprocedure('public.start_session_request(uuid)'))) > 0, false)
  union all select '342', 'aktif oturum kapanışı havalimanı saatiyle',
         coalesce(position('yerel_an' in pg_get_functiondef(to_regprocedure('public.tek_tarafli_oturumlari_kapat()'))) > 0, false)
  -- 343 (346 sonrası)
  union all select '343', 'kaynakta olmayan salonlar görünmüyor',
         not exists (select 1 from lounges l join lounge_venues v on v.id = l.venue_id and v.active
                      where l.active and (l.airport_code, l.name) in
                        (('SAW','Aeroport Lounge'),('ESB','Anatolia Lounge'),('LHR','Turkish Airlines Lounge'),('DOH','Oryx Lounge')))
  union all select '343', 'eski adlı salon görünmüyor (ESB/AYT)',
         not exists (select 1 from lounges l join lounge_venues v on v.id = l.venue_id and v.active
                      where l.active and (l.airport_code, l.name) in
                        (('ESB','Primeclass CIP Lounge'),('AYT','Antalya Airport CIP Lounge')))
  union all select '343', 'SAW Marmara görünür',
         exists (select 1 from public.lounges_for_airport('SAW') s where s.name ilike '%Marmara%')
  -- 344
  union all select '344', 'uçuş önbelleğinde başka uçuşun / günün kaydı yok',
         not exists (select 1 from public.flight_cache
                      where source = 'aviationstack' and raw is not null
                        and (upper(coalesce(raw->'flight'->>'iata','')) <> upper(flight_no)
                             or coalesce(raw->>'flight_date','') <> flight_date::text))
  -- 345
  union all select '345', 'kimlik belgesi gönderimi kapalı',
         coalesce(position('kyc_kapali' in pg_get_functiondef(to_regprocedure('public.kimlik_belgesi_gonder(text,text)'))) > 0, false)
  union all select '345', 'kyc kovasına yazma kuralı yok',
         not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
                      and policyname in ('kyc_own_write', 'kyc_own_update'))
  union all select '345', 'tabloda belge yolu kalmadı',
         not exists (select 1 from public.verifications where id_doc_path is not null or id_selfie_path is not null)
  union all select '345', 'id_verified = doğrulanmış profil (herkes)',
         to_regprocedure('public.profil_dogrulandi_hesapla(uuid)') is not null
     and not exists (select 1 from public.verifications v
                      where v.id_verified is distinct from public.profil_dogrulandi_hesapla(v.user_id))
  union all select '345', 'güven puanında kimlik bileşeni kalmadı',
         not exists (select 1 from public.trust_scores where components ? 'id')
  union all select '345', 'pazarlama izni kolonu var',
         exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'users' and column_name = 'pazarlama_izni')
  union all select '345', 'kampanya pazarlama iznine bakıyor',
         coalesce(position('pazarlama_izni' in pg_get_functiondef(to_regprocedure('public.send_campaign(text,text,jsonb,uuid,uuid[])'))) > 0, false)
  union all select '345', 'kayıt onayı pazarlama iznini açıyor',
         coalesce(position('pazarlama_izni' in pg_get_functiondef(to_regprocedure('public.grant_consents(text[],text)'))) > 0, false)
  union all select '345', 'anonimleştirme cinsiyeti siliyor',
         coalesce(position('gender = null' in pg_get_functiondef(to_regprocedure('public.admin_anonymize_user(uuid,text,text)'))) > 0, false)
  union all select '345', 'saklama işi kurulu (her gece 04:10)',
         to_regprocedure('public.cron_isi_var(text)') is not null and public.cron_isi_var('ll-saklama-imha')
  -- 346
  union all select '346', 'ESB dış hat Primeclass tek, aktif ilan pasif salona bağlı değil',
         (select count(*) from lounges l join lounge_venues v on v.id = l.venue_id and v.active
           where l.active and l.airport_code = 'ESB' and l.name = 'Primeclass Lounge — Dış Hat') = 1
     and not exists (select 1 from availabilities a join lounges l on l.id = a.lounge_id
                      where a.active and not l.active and l.airport_code = 'ESB')
  -- Bilgi
  union all select 'bilgi', 'kyc kovasında kalan dosya sayısı = ' || (select count(*) from storage.objects where bucket_id = 'kyc')::text,
         (select count(*) from storage.objects where bucket_id = 'kyc') = 0
) t
order by dosya, kontrol;
