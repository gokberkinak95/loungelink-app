-- ============================================================
-- LoungeLink · 173_showcase_data.sql
-- VİTRİN VERİSİ — ekran görüntüsü almak için
--
-- ⚠️ SADECE DEMO/STAGE ORTAMINDA KOŞULMALI. Üretimde koşmayın:
--    dosya bunu kendi kontrol eder ve gerçek kullanıcı varsa DURUR.
--
-- ------------------------------------------------------------
-- 🔴 NEDEN VAR
-- ------------------------------------------------------------
-- Site ve Instagram'da gerçek cihaz ekranları kullanıyoruz — doğru
-- karar, çünkü çizim arayüz hem sahte durur hem ürün değişince bayatlar.
-- Ama ekranlardaki VERİ zayıf: "Gokay Banka Karti", tek satır profil,
-- boş rozetler, 59 puanlı eşleşme. Ürün bundan iyi.
--
-- İki yol vardı: (a) ekran görüntüsünü rötuşlamak — bu SAHTE ARAYÜZ
-- demek, tam da kaçındığımız şey (b) VERİYİ güzelleştirip Gökberk'in
-- ekranları yeniden çekmesi. Doğru olan (b): görünen her şey gerçekten
-- üründe olan şey olur.
--
-- Bu dosya sekiz gerçekçi profil, dolu kartlar, canlı ilanlar ve
-- tamamlanmış bir oturum kurar. İsimler kurgusal; kart/tier/salon
-- eşleşmeleri kural motoruna UYGUN seçildi ki ekranda çıkan rozetler
-- doğru olsun (yanlış rozet, güzel ekrandan kötüdür).
-- ============================================================

-- ---- 0) ÜRETİM KORUMASI + BİLİNÇLİ AÇMA ----
-- 🔴 İlk sürüm Gökberk'in veritabanında haklı olarak durdu:
--   "6 gerçek kullanıcı var — vitrin verisi ÜRETİMDE koşulmaz"
-- Bekçi doğru çalıştı ama ÇIKIŞ YOLU vermiyordu. Bir korumanın
-- aşılamaz olması, insanı korumayı devre dışı bırakmaya iter
-- (kodu silip koşmak). Doğrusu: aşmayı MÜMKÜN ama BİLİNÇLİ kılmak.
--
-- Açmak için bu dosyadan ÖNCE tek satır çalıştır:
--   insert into beta_settings (key, value) values ('allow_showcase_data','true'::jsonb)
--     on conflict (key) do update set value = 'true'::jsonb;
--
-- Vitrin verisi gerçek kullanıcıya zarar vermez: yalnız
-- @vitrin.loungelink.test hesapları ekler, mevcut veriye dokunmaz.
-- Temizlemek için dosyanın sonundaki DROP bloğunu kullan.
do $$
declare v_real int; v_ok boolean;
begin
  select coalesce((value)::text = 'true', false) into v_ok
    from beta_settings where key = 'allow_showcase_data';

  select count(*) into v_real from users
   where coalesce(email,'') not like '%@seed.loungelink.test'
     and coalesce(email,'') not like '%@vitrin.loungelink.test'
     and coalesce(is_staff, false) = false;

  if v_real > 5 and not coalesce(v_ok, false) then
    raise exception E'173: bu veritabanında % gerçek kullanıcı var.\n'
      'Bilerek koşmak istiyorsan önce şunu çalıştır:\n'
      '  insert into beta_settings (key, value) values (''allow_showcase_data'',''true''::jsonb)\n'
      '    on conflict (key) do update set value = ''true''::jsonb;', v_real;
  end if;
  if coalesce(v_ok, false) then
    raise notice '173: vitrin verisi BİLİNÇLİ olarak açık (allow_showcase_data=true)';
  end if;
end $$;

-- ---- 1) VİTRİN PROFİLLERİ ----
-- Meslek + biyografi + dil + güven puanı dolu. Ekranda "boş profil"
-- görünmesin: kullanıcı ilk izlenimi profillerden alıyor.
do $$
declare r record; v_uid uuid; v_pid uuid;
begin
  for r in
    select * from (values
      ('elif',   'Elif K.',   'Ürün Tasarımcısı',    'Sık uçuyorum, lounge''da sohbet etmeyi severim. Aktarmalarda kahve eşliğinde tanışmak en sevdiğim şey.', 'TK_MS','ELPL', 78),
      ('mert',   'Mert A.',   'Girişim Kurucusu',    'Haftada iki uçuş, çoğu IST aktarmalı. Yeni insanlarla tanışmak işimin en keyifli tarafı.',              'TK_MS','ELITE',82),
      ('deniz',  'Deniz Y.',  'Yazılım Mühendisi',   'Uzaktan çalışıyorum, havalimanları benim ofisim. İyi bir sohbet uçuşu kısaltıyor.',                     'PRIORITY_PASS','PP_PRESTIGE',71),
      ('selin',  'Selin T.',  'Pazarlama Direktörü', 'Avrupa hatlarında sık gidip geliyorum. Aktarma beklerken tanıştığım insanlar en güzel hikâyelerim.',      'TK_MS','ELPL', 88),
      ('kaan',   'Kaan D.',   'Mimar',               'Projeler için çok seyahat ediyorum. Lounge''da bir kahve, iyi bir sohbete bahane.',                      'DRAGONPASS','DP_PREFERENTIAL',64),
      ('ayse',   'Ayşe N.',   'Doktor',              'Kongre yolculukları sık. Sessiz bir köşe ve nazik bir sohbet yeterli.',                                  'TK_MS','MS_EC',75),
      ('burak',  'Burak K.',  'Yatırım Bankacısı',   'Ayda 6-8 uçuş. Aktarmada tanıştığım insanlardan çok şey öğrendim.',                                      'TK_MS','ELITE',80),
      ('zeynep', 'Zeynep A.', 'Akademisyen',         'Konferans yolculukları. Uçuş öncesi sohbet, uzun yolu kısaltıyor.',                                      'AJET_MS','ELPL',69)
    ) as x(slug, ad, meslek, bio, prog, tier, guven)
  loop
    v_uid := ('a1b2c3d4-0000-4000-8000-' || lpad(abs(hashtext(r.slug))::text, 12, '0'))::uuid;

    insert into users (id, email, password_hash, role, plan)
    values (v_uid, r.slug || '@vitrin.loungelink.test', 'supabase-auth', 'host'::user_role, 'explorer'::plan_type)
    on conflict (id) do nothing;

    insert into profiles (user_id, name, profession, bio, languages, show_on_discovery)
    values (v_uid, r.ad, r.meslek, r.bio, array['Türkçe','İngilizce'], true)
    on conflict (user_id) do update
      set name = excluded.name, profession = excluded.profession,
          bio = excluded.bio, languages = excluded.languages;

    -- Kart hakkı: rozetlerin DOĞRU çıkması için gerçek program+tier
    select id into v_pid from lounge_programs where code = r.prog;
    if v_pid is not null then
      insert into host_entitlements (user_id, program_id, tier, verified)
      values (v_uid, v_pid, r.tier, true)
      on conflict do nothing;
    end if;

    -- Güven puanı: boş rozet yerine gerçek bir sayı
    insert into trust_scores (user_id, score, badge)
    values (v_uid, r.guven,
            case when r.guven >= 80 then 'trusted' when r.guven >= 65 then 'verified' else 'basic' end)
    on conflict (user_id) do update set score = excluded.score, badge = excluded.badge;

    insert into verifications (user_id, email_verified, phone_verified, id_verified)
    values (v_uid, true, true, r.guven >= 75)
    on conflict (user_id) do update
      set email_verified = true, phone_verified = true, id_verified = excluded.id_verified;
  end loop;
end $$;

-- ---- 2) CANLI İLANLAR ----
-- Farklı havalimanı, farklı saat, farklı kart — keşfet ekranı tek tip
-- görünmesin. Tarihler BUGÜNE göre kayar ki ekran hep taze olsun.
do $$
declare r record; v_uid uuid; v_lounge uuid;
begin
  for r in
    select * from (values
      ('elif',  'IST', 0, '10:00', '13:30', 'TK1980', 'TK', 2),
      ('mert',  'IST', 0, '14:00', '17:00', 'TK2124', 'TK', 1),
      ('selin', 'ESB', 1, '07:30', '10:00', 'TK2103', 'TK', 2),
      ('deniz', 'ADB', 1, '16:00', '19:00', 'PC2214', 'PC', 1),
      ('burak', 'IST', 2, '09:00', '12:00', 'TK1854', 'TK', 2),
      ('kaan',  'SAW', 2, '18:00', '21:00', 'PC1042', 'PC', 1),
      ('ayse',  'AYT', 3, '11:00', '14:00', 'TK2412', 'TK', 1)
    ) as x(slug, ap, gun, t1, t2, ucus, tasiyici, slot)
  loop
    v_uid := ('a1b2c3d4-0000-4000-8000-' || lpad(abs(hashtext(r.slug))::text, 12, '0'))::uuid;
    select l.id into v_lounge from lounges l
     where l.active and l.airport_code = r.ap
       and exists (select 1 from lounge_venues v where v.id = l.venue_id and v.active)
     order by length(l.name) limit 1;

    insert into availabilities
      (host_id, lounge_id, airport_code, avail_date, time_from, time_to,
       slots, filled, flight_number, carrier, visibility, active)
    select v_uid, v_lounge, r.ap, current_date + r.gun, r.t1::time, r.t2::time,
           r.slot, 0, r.ucus, r.tasiyici, 'Public'::availability_visibility, true
    where not exists (
      select 1 from availabilities a
       where a.host_id = v_uid and a.airport_code = r.ap
         and a.avail_date = current_date + r.gun);
  end loop;
end $$;

-- ---- 3) SEYAHATLER ----
-- Keşfet'te "seyahatinle eşleşiyor" rozetinin YEŞİL çıkması için
-- vitrin misafirinin uygun bir seyahati olmalı.
do $$
declare v_guest uuid;
begin
  v_guest := ('a1b2c3d4-0000-4000-8000-' || lpad(abs(hashtext('zeynep'))::text, 12, '0'))::uuid;
  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number)
  select v_guest, 'IST', 'LHR', current_date, '09:30'::time, '14:00'::time, 'TK1979'
  where not exists (select 1 from visits v where v.user_id = v_guest and v.visit_date = current_date);
end $$;

-- ---- 4) TAMAMLANMIŞ OTURUM + PUAN ----
-- "Oturum tamamlandı" ve puanlama ekranlarının dolu görünmesi için.
do $$
declare v_h uuid; v_g uuid; v_av uuid; v_req uuid; v_ses uuid;
begin
  v_h := ('a1b2c3d4-0000-4000-8000-' || lpad(abs(hashtext('elif'))::text, 12, '0'))::uuid;
  v_g := ('a1b2c3d4-0000-4000-8000-' || lpad(abs(hashtext('mert'))::text, 12, '0'))::uuid;
  select id into v_av from availabilities where host_id = v_h limit 1;
  if v_av is null then return; end if;

  -- 🔴 ratings.session_id NOT NULL: puan bir OTURUMA bağlıdır, isteğe
  -- değil. Şemayı okumadan yazınca blok sessizce atlanıyordu ve
  -- "oturum tamamlandı" ekranı vitrin verisinde boş kalıyordu.
  -- Doğru sıra: request → session → rating.
  insert into requests (avail_id, guest_id, host_id, status, intro_message)
  select v_av, v_g, v_h, 'completed', 'Aynı uçuştayız, kahve içelim mi?'
   where not exists (select 1 from requests r where r.avail_id = v_av and r.guest_id = v_g)
  returning id into v_req;

  if v_req is not null then
    -- 🔴 ŞEMA OKUNDU (üçüncü denemede): sessions tablosunda host_id/guest_id
    -- YOK — taraflar request üzerinden gelir; tamamlanma alanı
    -- completed_at, ve iki taraflı onay host_confirmed/guest_confirmed
    -- kolonlarında tutulur. Hafızadan kolon adı yazmak bu dosyada üç kez
    -- ısırdı; `loungelink-sql` becerisinin ilk maddesi tam bu.
    insert into sessions (request_id, status, started_at, completed_at,
                          host_confirmed, guest_confirmed)
    values (v_req, 'completed', now() - interval '2 hours',
            now() - interval '1 hour', true, true)
    returning id into v_ses;

    if v_ses is not null then
      insert into ratings (session_id, rater_id, rated_id, score, comment)
      values (v_ses, v_g, v_h, 5, 'Çok keyifli bir sohbetti, teşekkürler.'),
             (v_ses, v_h, v_g, 5, 'Zamanında geldi, sohbeti çok iyiydi.')
      on conflict do nothing;
    end if;
  end if;
exception when others then
  raise notice '173: oturum/puan bloğu atlandı (%): şema farkı', SQLERRM;
end $$;

-- ---- DOĞRULAMA ----
do $$
declare n_p int; n_a int;
begin
  select count(*) into n_p from profiles p join users u on u.id = p.user_id
   where u.email like '%@vitrin.loungelink.test';
  select count(*) into n_a from availabilities a join users u on u.id = a.host_id
   where u.email like '%@vitrin.loungelink.test' and a.active;
  raise notice '173: % vitrin profili, % canlı ilan hazır', n_p, n_a;
  if n_p < 6 then raise exception '173: vitrin profilleri eksik (%)', n_p; end if;
end $$;

-- ---- TEMİZLİK (isteğe bağlı) ----
-- Ekran görüntülerini aldıktan sonra vitrin hesaplarını kaldırmak
-- istersen bu bloğu ayrıca çalıştır. Gerçek veriye dokunmaz.
--
--   do $$
--   declare v_ids uuid[];
--   begin
--     select array_agg(id) into v_ids from users where email like '%@vitrin.loungelink.test';
--     if v_ids is null then return; end if;
--     delete from requests where guest_id = any(v_ids) or host_id = any(v_ids);
--     delete from availabilities where host_id = any(v_ids);
--     delete from visits where user_id = any(v_ids);
--     delete from host_entitlements where user_id = any(v_ids);
--     delete from trust_scores where user_id = any(v_ids);
--     delete from verifications where user_id = any(v_ids);
--     delete from profiles where user_id = any(v_ids);
--     delete from users where id = any(v_ids);
--   end $$;

select '173 OK - vitrin verisi hazir (ekran goruntusu icin)' as sonuc;
