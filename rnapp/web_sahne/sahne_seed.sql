-- ⚠️ 12 Eylül — TOHUM SESSİZCE DÜŞÜYORDU. `do $$` bloğu hata verse
-- bile dosyanın SONUNDAKİ `select 'sahne seed OK'` yine çalışıyor ve
-- ekrana OK yazıyordu: yani kırık bir dünyayla sahne çekiyordum.
-- 🆕 SINIF: "BİR BETİĞİN SON SATIRI 'OK' YAZIYORSA, O SATIRIN HATADAN
-- SONRA DA ÇALIŞIP ÇALIŞMADIĞINI ÖLÇ."
\set ON_ERROR_STOP on
-- web_sahne/sahne_seed.sql — WEB SAHNESİNİN DÜNYASI (yalnız yerel `ll` için).
-- Tasarımdaki içerik (Gökberk · Deniz K. · Mert A. · Selin B. · Kaan T. · Ece Y.)
-- gerçek tablolara yazılır; ekranlar bu satırları GERÇEK RPC'lerle okur.
-- ⚠️ Canlı Supabase'e ASLA koşulmaz — "@sahne.loungelink.test" e-postaları
-- ve sabit UUID'ler yalnız burada anlamlı.
begin;

do $$
declare
  g  uuid := 'a1b2c3d4-0000-4000-8000-00000000000a';  -- Gökberk (misafir)
  hd uuid := 'a1b2c3d4-0000-4000-8000-00000000000d';  -- Deniz K. (host)
  hm uuid := 'a1b2c3d4-0000-4000-8000-00000000000e';  -- Mert A. (host)
  hs uuid := 'a1b2c3d4-0000-4000-8000-00000000000f';  -- Selin B. (host · ana_host sahnesi)
  kt uuid := 'a1b2c3d4-0000-4000-8000-000000000010';  -- Kaan T.
  ey uuid := 'a1b2c3d4-0000-4000-8000-000000000011';  -- Ece Y.
  ad uuid := 'a1b2c3d4-0000-4000-8000-000000000012';  -- Ayşegül D.
  bs uuid := 'a1b2c3d4-0000-4000-8000-000000000013';  -- Burak S. (05_tanis: aynı uçuş)
  ek uuid := 'a1b2c3d4-0000-4000-8000-000000000014';  -- Elif K.  (05_tanis: aynı rota)
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 12 EYLÜL · GECE — EKRANIN DEĞİL DURUMUNUN KAPSAMI.
  -- Keşfet kartının eylem alanının BEŞ hâli var; tohum dünyasında
  -- yalnız ikisi yaşanıyordu (uygun · engelli). Kalan üçü hiç
  -- ÇEKİLMEMİŞTİ, yani "doğru görünüyor mu" sorusu hiç sorulmamıştı.
  -- Bir durumu ölçmenin yolu onu YAŞAYAN bir kullanıcı eklemek:
  --   yn  telefonu doğrulanmamış → kartlarda "Telefonunu doğrula"
  --   hz  telefonu doğrulanmış ama seyahati yok → "Seyahat ekle"
  --   hs  (Selin) kendi ilanını görüyor → düğme yok
  -- Ayrıca `yn` boş dünyanın da temsilcisi: Planım, Bildirimler ve
  -- Tanış onda gerçekten BOŞ — boş durum ekranları ilk kez çekiliyor.
  -- 🆕 SINIF: "BİR EKRANI ÇEKMEK O EKRANI GÖRMEK DEĞİLDİR — EKRAN BİR
  -- DEĞİL, DURUMLARI KADAR ÇOKTUR."
  -- ══════════════════════════════════════════════════════════════════
  yn uuid := 'a1b2c3d4-0000-4000-8000-000000000015';  -- Yeni Üye (telefon doğrulanmamış, boş dünya)
  hz uuid := 'a1b2c3d4-0000-4000-8000-000000000016';  -- Hazır Üye (seyahati ilanla eşleşmiyor)
  bo uuid := 'a1b2c3d4-0000-4000-8000-000000000017';  -- Boş Üye (hiç seyahati yok → ilk gün formu)
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 13 EYLÜL · GÖKBERK NOT2 — "BOŞ GÖRÜNÜMDE SEKMELER YUKARI KAYMIŞ"
  -- Ölçmek için BOŞ BİR HOST gerekiyordu ve tohumda yoktu: üç boş
  -- kişinin (yn · hz · bo) ÜÇÜ DE misafir. Yani Planım'ın boş hâli
  -- host tarafında HİÇ çekilmemişti — çipler oradayken boşluk nasıl
  -- duruyor, kimse görmedi.
  -- 🆕 SINIF: "BİR DURUMU ÖLÇMEK İÇİN O DURUMU YAŞAYAN ROL GEREKİR —
  -- BOŞ EKRANI MİSAFİRDE ÖLÇÜP HOST'TA DA AYNI SANMAK ÖLÇÜM DEĞİL."
  bh uuid := 'a1b2c3d4-0000-4000-8000-000000000018';  -- Boş Host (ilanı ve seyahati yok)
  l_kapali uuid; v_kapali uuid;
  l_prime uuid; l_comfort uuid; p_tk uuid; p_pp uuid;
  av_d uuid; av_m uuid; av_s1 uuid; av_s2 uuid;
  rq uuid; ch uuid; ses uuid; rq2 uuid; ses2 uuid; cr uuid;
  r record;
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 12 EYLÜL · GECE — DÜNYA ARTIK "CANLI" BİR SAATE SAHİP.
  --
  -- Sohbetin üst şeridindeki sayaç `HH:MM:SS` kipine YALNIZ kalkışa
  -- 24 saatten az kaldığında geçiyor. Tohumda Deniz'in ilanı sabit
  -- "bugün 14:20"di; yani sahneyi 14:20'den ÖNCE çekersen şerit canlı,
  -- SONRA çekersen ölüydü. Aynı testin sabah ve akşam iki farklı şey
  -- ölçmesi, ölçüm değildir.
  --
  -- `kalkis` = şimdi + 2sa 41dk. Sayı keyfi değil: tasarım 06'daki
  -- şerit birebir "02:41:08 kalkışa" diyor. Artık sahne her koşuda
  -- tasarımın gösterdiği ANI gösteriyor.
  --
  -- ⚠️ MİSAFİRİN SEYAHATİ DE BİRLİKTE KAYIYOR. Yalnız ilanı kaydırsam
  -- "aynı uçuş / uygun saat" eşleşmesi kopardı — iki tarafı ayrı ayrı
  -- kaydırmak, ilişkiyi bozmanın en sessiz yoludur.
  -- ══════════════════════════════════════════════════════════════════
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 12 EYLÜL · 2. KEZ — KAYAN SAAT GECE YARISINI GEÇİYOR.
  -- v5.7.0'da pencerenin ÜST ucunu gün sonunda kestim; bu turda tohum
  -- 21:37'de koştu ve bu kez ALT uç patladı:
  --     time_from 23:48  ·  time_to 03:18  →  visits_check (from < to)
  -- Tek ucu düzeltmek, diğer ucun patlamasını ERTELEMEKTİ.
  -- Artık kalkış saatin KENDİSİ güvenli kuşağa (04:00–20:00) kilitli:
  -- o kuşaktaysa şimdi+2sa41dk, değilse bir sonraki 14:20. İki durumda
  -- da kalkışa 24 saatten az kalır (şerit `HH:MM:SS` kipinde) ve
  -- pencere gece yarısını hiç görmez.
  -- 🆕 SINIF: "ZAMANA BAĞLI BİR TEST VERİSİNDE TEK BİR UCU KESMEK
  -- ÇÖZÜM DEĞİL, ÖBÜR UCUN PATLAMASINI BEKLEMEKTİR."
  -- ══════════════════════════════════════════════════════════════════
  ham    timestamp := date_trunc('minute', now()) + interval '2 hours 41 minutes';
  kalkis timestamp := case
    when ham::time between time '04:00' and time '20:00' then ham
    when now()::time < time '14:20' then date_trunc('day', now())::timestamp + interval '14 hours 20 minutes'
    else date_trunc('day', now() + interval '1 day')::timestamp + interval '14 hours 20 minutes'
  end;
begin
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 18 EYLÜL — "BAŞVURU KAPALI" SALONU ARTIK SABİT UUID DEĞİL.
  -- Eski hâl `'cc865fe6-…'::uuid` ve `'01daa983-…'::uuid` yazıyordu.
  -- `lounges.id` her kurulumda `gen_random_uuid()` ile ÜRETİLİYOR; yani
  -- o iki sabit yalnız o günkü veritabanında vardı. Sıfırdan kurulan bir
  -- replikada tohum `availabilities_lounge_id_fkey` ile düşüyor — ve
  -- düştüğü için sahnelerin YARISI oturum açılmamış ana sayfada kalıyor,
  -- kapılar da "ekranda yok" diye kırmızı yanıyordu. Kapı haklıydı, veri
  -- yoktu; ama sebep koddaki bir hata değil TOHUMDAKİ BİR SABİTTİ.
  -- 🆕 SINIF: "ÜRETİLEN BİR KİMLİĞİ TOHUMA SABİT YAZARSAN, TOHUM YALNIZ
  -- O GÜNKÜ VERİTABANINDA ÇALIŞIR — KİMLİĞİ DEĞİL KURALI ARA."
  -- Aranan şey zaten kuralın kendisi: misafir kabul ETMEYEN bir IST salonu.
  select l.id, lv.id into l_kapali, v_kapali
    from lounge_venue_acceptance a2
    join lounge_venues lv on lv.id = a2.venue_id
    join lounges l on l.venue_id = lv.id
   where a2.guest_policy = 'not_allowed' and l.airport_code = 'IST'
   limit 1;
  if l_kapali is null then
    raise exception 'sahne_seed: misafir kabul etmeyen IST salonu bulunamadi (kural verisi eksik)';
  end if;
  select id into l_prime   from lounges where airport_code='IST' and name ilike 'Primeclass%' limit 1;
  select id into l_comfort from lounges where airport_code='SAW' and name ilike 'Plaza Premium Lounge%' limit 1;
  select id into p_tk from lounge_programs where code='TK_MS';
  select id into p_pp from lounge_programs where code='PRIORITY_PASS';

  -- ── kişiler ─────────────────────────────────────────────────────
  for r in select * from (values
      (g,  'gokberk@sahne.loungelink.test', 'guest', 'Gökberk İnak', 'Ürün Yönetimi', 44, 'basic'),
      (hd, 'deniz@sahne.loungelink.test',   'host',  'Deniz K.',     'Yazılım Mühendisi', 84, 'trusted'),
      (hm, 'mert@sahne.loungelink.test',    'host',  'Mert A.',      'Girişim Kurucusu', 71, 'verified'),
      (hs, 'selin@sahne.loungelink.test',   'host',  'Selin B.',     'Ürün Yönetimi', 88, 'trusted'),
      (kt, 'kaan@sahne.loungelink.test',    'guest', 'Kaan T.',      'Mimar', 64, 'basic'),
      (ey, 'ece@sahne.loungelink.test',     'guest', 'Ece Y.',       'Akademisyen', 69, 'verified'),
      (ad, 'aysegul@sahne.loungelink.test', 'guest', 'Ayşegül D.',   'Doktor', 75, 'verified'),
      (bs, 'burak@sahne.loungelink.test',   'guest', 'Burak S.',     'Pilot', 61, 'basic'),
      (ek, 'elif@sahne.loungelink.test',    'guest', 'Elif K.',      'Avukat', 72, 'verified'),
      (yn, 'yeni@sahne.loungelink.test',    'guest', 'Yeni Üye',     'Mühendis', 0, 'basic'),
      (hz, 'hazir@sahne.loungelink.test',   'guest', 'Hazır Üye',    'Tasarımcı', 38, 'basic'),
      (bo, 'bos@sahne.loungelink.test',     'guest', 'Boş Üye',      'Öğretmen', 10, 'basic'),
      (bh, 'boshost@sahne.loungelink.test', 'host',  'Boş Host',     'Kaptan Pilot', 55, 'basic')
    ) as x(uid, email, rol, ad, meslek, guven, rozet)
  loop
    insert into auth.users (id, email, role, aud) values (r.uid, r.email, 'authenticated', 'authenticated')
      on conflict (id) do nothing;
    insert into users (id, email, password_hash, role, plan)
      values (r.uid, r.email, 'supabase-auth', r.rol::user_role, 'explorer'::plan_type)
      on conflict (id) do update set role = excluded.role;
    insert into profiles (user_id, name, profession, bio, languages, show_on_discovery)
      values (r.uid, r.ad, r.meslek, 'Aktarmalarda iyi bir sohbet uçuşu kısaltır.', array['Türkçe','İngilizce'], true)
      on conflict (user_id) do update set name = excluded.name, profession = excluded.profession, show_on_discovery = true;
    insert into trust_scores (user_id, score, badge) values (r.uid, r.guven, r.rozet)
      on conflict (user_id) do update set score = excluded.score, badge = excluded.badge;
    insert into verifications (user_id, email_verified, phone_verified, id_verified)
      values (r.uid, true, true, r.guven >= 70)
      on conflict (user_id) do update set email_verified = true, phone_verified = true, id_verified = excluded.id_verified;
  end loop;

  -- onaylar (18 yaş + sözleşmeler) ve host erişim kaynağı: tasarım sahnesinde
  -- ilk-açılış kapıları (yaş kartı, "Lounge Erişim Kurulumu") görünmez
  insert into consents (user_id, type, version)
    select u, ty, '1' from unnest(array[g, hd, hm, hs, kt, ey, ad, bs, ek, yn, hz, bo, bh]) u,
           unnest(array['age_18','terms','privacy','community','no_resale','rules']) ty
    on conflict do nothing;
  -- `bh` de burada: `access_source` boş kalsa App.js ilk açılışta "Lounge
  -- Erişim Kurulumu" katmanını açar ve BOŞ PLANIM'ı hiç göremezdik.
  update profiles set access_source = 'Priority Pass', guest_capacity = 2 where user_id in (hd, hm, hs, bh);
  -- Yeni Üye: hiçbir doğrulaması yok → Keşfet'te "Telefonunu doğrula" kapısı
  update verifications set phone_verified = false, id_verified = false, email_verified = true
    where user_id = yn;
  -- Hazır Üye: telefon doğrulanmış, seyahati yok → "Seyahat ekle" kapısı
  update verifications set phone_verified = true, id_verified = false where user_id = hz;
  delete from visits where user_id in (yn, hz, bo, bh);
  delete from notifications where user_id in (yn, hz, bo, bh);
  -- Boş Host gerçekten boş: ilanı da olmayacak (tohum ona hiç ilan
  -- açmıyor; yine de tekrar koşulduğunda birikmesin diye siliyorum).
  delete from availabilities where host_id = bh;
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 ÜRÜN, SEYAHATİ OLMAYANI FORMA ZORLUYOR — VE BU DOĞRU DAVRANIŞ.
  -- `App.js:835`: seyahati yoksa açılışta `AddVisit` açılıyor. İlk
  -- denememde `yn` ve `hz`ye hiç seyahat vermemiştim; ikisi de sekme
  -- çubuğuna hiç ulaşamadı, çünkü form ekranı kaplıyordu.
  -- Yani "Keşfet'te seyahat kapısı" durumu seyahatSİZ bir kullanıcıyla
  -- ÇEKİLEMEZ; o kapı, seyahati OLAN ama İLANLA EŞLEŞMEYEN kullanıcıya
  -- görünür (`has_trip` satır bazında hesaplanıyor).
  --   yn → IST, bugün        → ilanla eşleşiyor, engel yalnız telefon
  --   hz → IST, +5 gün       → ilan var ama eşleşme yok → "Seyahat ekle"
  -- 🆕 SINIF: "BİR DURUMU ÜRETMEK İÇİN VERİYİ BOŞALTMAK YETMEZ —
  -- ÜRÜNÜN O BOŞLUĞA VERDİĞİ TEPKİYİ DE HESABA KAT."
  -- ══════════════════════════════════════════════════════════════════
  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number, carrier_code)
    values (yn, 'IST', 'LHR', kalkis::date, (kalkis - interval '30 minutes')::time,
            least(kalkis + interval '3 hours', date_trunc('day', kalkis) + interval '23 hours 59 minutes')::time,
            'TK1979', 'TK'),
           (hz, 'IST', 'CDG', (kalkis + interval '5 days')::date, '10:00', '14:00', 'TK1823', 'TK');

  -- kartlar
  -- Selin iki hak taşır: TK Elite Plus (IST Primeclass → misafir ücretsiz)
  -- ve Priority Pass (SAW → misafir ücretle girer) — tasarım 12'deki iki çip.
  delete from host_entitlements where user_id in (hd, hm, hs);
  insert into host_entitlements (user_id, program_id, tier, verified) values
    (hd, p_tk, 'ELPL', true), (hm, p_pp, 'PP_STANDARD', true), (hs, p_pp, 'PP_PRESTIGE', true), (hs, p_tk, 'ELPL', true)
    on conflict do nothing;

  -- cüzdan: Gökberk 14 kredi · 200 puan ; Selin bu ay +360 puan
  delete from credit_ledger where user_id in (g, hs);
  delete from points_ledger where user_id in (g, hs);
  insert into credit_ledger (user_id, delta, reason, balance_after) values (g, 14, 'seed', 14), (hs, 6, 'seed', 6);
  insert into points_ledger (user_id, delta, reason, balance_after) values (g, 200, 'seed', 200);
  insert into points_ledger (user_id, delta, reason, balance_after, created_at)
    values (hs, 120, 'session', 120, now() - interval '6 hours'),
           (hs, 120, 'session', 240, now() - interval '3 hours'),
           (hs, 120, 'session', 360, now() - interval '1 hour');

  -- ── ilanlar (tasarım: Deniz · TAV Primeclass IST 14:20–16:40 TK1979 · Mert · Comfort SAW 09:00–11:30)
  -- (yeniden koşulabilir: önce bağımlı satırlar temizlenir)
  -- (SEED6 aynı kurgu kişileri host1'e de başvurtur → misafir kümesi geniş)
  delete from ratings where session_id in (select id from sessions where request_id in (select id from requests where guest_id in (g, kt, ey, ad, bs, ek) or host_id in (hd, hm, hs)));
  delete from messages where channel_id in (select id from chat_channels where request_id in (select id from requests where guest_id in (g, kt, ey, ad, bs, ek) or host_id in (hd, hm, hs)));
  delete from chat_channels where request_id in (select id from requests where guest_id in (g, kt, ey, ad, bs, ek) or host_id in (hd, hm, hs));
  delete from sessions where request_id in (select id from requests where guest_id in (g, kt, ey, ad, bs, ek) or host_id in (hd, hm, hs));
  delete from requests where guest_id in (g, kt, ey, ad, bs, ek) or host_id in (hd, hm, hs);
  delete from invites where avail_id in (select id from availabilities where host_id in (hd, hm, hs));  -- SEED6 aynı UUID'leri kullanır
  delete from availabilities where host_id in (hd, hm, hs);
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active)
    values (hd, l_prime, 'IST', 'TAV Primeclass', kalkis::date, kalkis::time,
            -- 🔴 GECE YARISINI GEÇEN PENCERE: ilan saati artık kayan bir
            -- değer ve 21:40'tan sonra `+2sa20dk` ertesi güne taşıyor;
            -- `time_to > time_from` kısıtı haklı olarak reddediyor.
            -- Kalkış saatini korumak için pencereyi gün sonunda kesiyoruz.
            least(kalkis + interval '2 hours 20 minutes',
                  date_trunc('day', kalkis) + interval '23 hours 59 minutes')::time, 2, 0, 'TK1979', 'TK', 'Public', true) returning id into av_d;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active)
    values (hm, l_comfort, 'SAW', 'Comfort Lounge', current_date + 1, '09:00', '11:30', 1, 0, 'PC2210', 'PC', 'Public', true) returning id into av_m;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active)
    values (hs, l_prime, 'IST', 'TAV Primeclass', current_date, '14:20', '16:40', 2, 1, 'TK1979', 'TK', 'Public', true) returning id into av_s1;
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to, slots, filled, flight_number, carrier, visibility, active)
    values (hs, l_comfort, 'SAW', 'Comfort Lounge', current_date + 1, '09:00', '11:30', 1, 0, 'PC2210', 'PC', 'Public', true) returning id into av_s2;

  update availabilities set program_id = p_tk where id in (av_d, av_s1);

  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 18 EYLÜL (Gökberk md.10 · md.11) — PASİF İLAN SAHNEYE GİRDİ.
  -- Bugüne kadar sahne dünyasında yalnız CANLI ilan vardı; yani
  -- "kaldırılmış ilan nasıl görünüyor" hâli hiçbir ekran görüntüsünde
  -- yoktu. Gökberk'in iki maddesi tam olarak o hâlle ilgiliydi:
  -- "kaldır" bastıktan sonra satırın listede kalması ve "düzenle"nin
  -- sunucudan reddedilmesi. Ölçülmeyen bir hâl, bildirilene kadar
  -- yoktur.
  -- 🆕 SINIF: "BİR DURUMU SAHNEYE KOYMADIYSAN, O DURUMU ÖLÇMÜYORSUN —
  -- VE ÖLÇÜLMEYEN HÂL, KULLANICININ İLK GÖRDÜĞÜ HÂLDİR."
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date,
                              time_from, time_to, slots, filled, flight_number, carrier,
                              visibility, active)
    values (hs, l_prime, 'IST', 'TAV Primeclass', current_date + 4, '10:00', '12:30',
            2, 0, 'TK1980', 'TK', 'Public', false);
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 "BAŞVURU KAPALI" DURUMU — UYDURMA DEĞİL, KAYNAĞIN KENDİ HÜKMÜ.
  --
  -- Bir tur önce bu ilanı açmayı denedim ve `availabilities` üzerindeki
  -- tetikleyici patladı; orada gerçek bir hata çıktı (sql/288:
  -- `profiles.trust_score` diye bir kolon yok). Tetikleyici düzeldi,
  -- yol açıldı.
  --
  -- Engel gerçek veriden: THY'nin kendi Dış Hat Business salonu,
  -- Miles&Smiles statüsüyle gelen MİSAFİRİ kabul etmiyor
  -- (`lounge_venue_acceptance.guest_policy = 'not_allowed'`).
  -- Mert'e o salonda bir ilan açıyoruz; kural motoru "misafir kabul
  -- edilmiyor" diyor ve kart engelli hâline geçiyor.
  -- `kural_uyum_check.py` zaten vitrindeki her iddiayı motorun
  -- tablosuyla karşılaştırıyor — yani bu kurgu değil, kaynak.
  -- ══════════════════════════════════════════════════════════════════
  insert into availabilities (host_id, lounge_id, airport_code, lounge_name, avail_date, time_from, time_to,
                              slots, filled, flight_number, carrier, visibility, active, program_id, venue_id)
    values (hm, l_kapali, 'IST', 'THY Dış Hat Business',
            kalkis::date, kalkis::time,
            least(kalkis + interval '2 hours', date_trunc('day', kalkis) + interval '23 hours 59 minutes')::time,
            2, 0, 'TK1979', 'TK', 'Public', true, p_tk, v_kapali);


  -- ── seyahatler
  delete from visits where user_id in (g, kt, ey, ad, hs, bs, ek);
  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number, carrier_code)
    values (g, 'IST', 'LHR', kalkis::date, (kalkis - interval '20 minutes')::time,
                             least(kalkis + interval '3 hours 40 minutes',
                                   date_trunc('day', kalkis) + interval '23 hours 59 minutes')::time, 'TK1979', 'TK'),
           (g, 'SAW', null,  current_date + 8, '09:00', '11:00', 'PC2210', 'PC'),
           (kt, 'IST', 'AMS', current_date, '13:00', '17:00', 'TK1979', 'TK'),
           (kt, 'SAW', null,  current_date + 1, '08:30', '11:00', 'PC2210', 'PC'),   -- 02_kesfet sahnesi Kaan'la: iki karta da "İstek gönder"
           (ey, 'IST', 'LHR', current_date, '15:00', '18:05', 'TK1979', 'TK'),
           (ad, 'IST', 'FRA', current_date, '12:00', '16:00', 'TK1590', 'TK'),
           (bs, 'IST', 'AMS', current_date, '13:30', '17:30', 'TK1979', 'TK'),
           (ek, 'IST', 'LHR', current_date, '14:30', '18:00', 'TK1983', 'TK');
  update visits set purpose = 'connecting' where user_id = ek;
  -- tasarım 14: "IST · Aktarma [2 kişi · 4 yaş]" · "SAW · Varış"
  update visits set purpose = 'connecting', party_size = 2, child_ages = array[4]
    where user_id = g and airport_code = 'IST';
  update visits set purpose = 'leisure' where user_id = g and airport_code = 'SAW';

  -- ── istekler: Gökberk → Deniz KABUL (sohbet + canlı oturum), Gökberk ↔ Selin tamamlandı (puanla)
  insert into requests (guest_id, host_id, avail_id, status, intro_message, responded_at, created_at)
    values (g, hd, av_d, 'accepted', 'Aynı uçuştayız, kahve içelim mi?', now() - interval '20 minutes', now() - interval '40 minutes')
    returning id into rq;
  insert into chat_channels (request_id, kind, active) values (rq, 'request', true) returning id into ch;
  insert into messages (channel_id, from_id, body, created_at) values
    (ch, hd, 'Merhaba! Primeclass girişinde buluşalım mı?', now() - interval '18 minutes'),
    (ch, g,  'Olur, güvenlikten yeni geçtim — 5 dakikaya oradayım.', now() - interval '16 minutes'),
    (ch, g,  'Lounge girişindeyim', now() - interval '11 minutes');
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 12 EYLÜL · GECE — UZUN İÇERİK. ÜRÜNÜ KISA İÇERİKLE ÖLÇÜYORDUK.
  -- Sohbet sahnesi üç mesajla çekiliyordu; 20 mesajlık bir sohbette
  -- kaydırma, balon yoğunluğu ve şampanya yüzey oranı hiç görülmedi.
  -- Uzun bir mesaj da ekliyorum: tek satırlık balonlarla sarma
  -- davranışı ölçülemez.
  -- 🆕 SINIF: "KISA İÇERİKLE ÖLÇÜLEN BİR ARAYÜZ, YALNIZ KISA İÇERİKTE
  -- ÇALIŞTIĞI BİLİNEN BİR ARAYÜZDÜR."
  -- ══════════════════════════════════════════════════════════════════
  for r in select * from (values
      (1,  hd, 'Ben de yeni geçtim, kapıdayım.'),
      (2,  g,  'Süper. Kaç numaralı kapıdasın?'),
      (3,  hd, 'A12. Primeclass girişi tam karşısı.'),
      (4,  g,  'Anladım, yürüyen merdivenden çıkıyorum.'),
      (5,  hd, 'Acele etme, uçuşa daha var.'),
      (6,  g,  'Kahve ısmarlayayım mı? Burada sıra yok gibi.'),
      (7,  hd, 'Olur, ben sade içiyorum.'),
      (8,  g,  'Not aldım.'),
      (9,  hd, 'Bu arada salonda çalışma alanı da var, prizli masalar arka tarafta. Uçuşa kadar iş çıkarmak istersen orası daha sessiz oluyor genelde.'),
      (10, g,  'Harika, sunum bitirmem gereken bir iş vardı zaten.'),
      (11, hd, 'O zaman arka tarafa geçelim.'),
      (12, g,  'Tamam, geldim sayılır.'),
      (13, hd, 'Turnikede kartı ben okutacağım, sen arkamdan gel.'),
      (14, g,  'Anladım, teşekkürler.'),
      (15, hd, 'Rica ederim, daha önce de misafir aldım; sorun çıkmıyor.'),
      (16, g,  'İlk seferim, o yüzden soruyorum.'),
      (17, hd, 'Gayet normal. Kapıda seni sorarlarsa misafirim dersin, yeter.'),
      (18, g,  'Tamamdır, görüşmek üzere.')
    ) as x(sira, kimden, govde)
  loop
    insert into messages (channel_id, from_id, body, created_at)
      values (ch, r.kimden, r.govde, now() - interval '11 minutes' + (r.sira || ' seconds')::interval * 20);
  end loop;
  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 12 EYLÜL · GECE — BU OTURUM ARTIK BAŞLAMIŞ.
  --
  -- `ekran_kapsam_check.py`de gerekçeli tek boşluk `LiveStatus`tı:
  -- "yalnız BAŞLAMIŞ bir oturumun sohbetinden açılıyor; tohum
  -- dünyasında aktif oturum yok." Gerekçe doğruydu ama bir gerekçe
  -- kalıcı olursa mazerete döner. Boşluğu kapatmanın yolu ekranı
  -- sahte veriyle çekmek değil, DÜNYAYA o durumu eklemekti.
  --
  -- Tohumun kendi hikâyesi zaten bunu söylüyordu: mesajlar "Lounge
  -- girişindeyim" (-11 dk) ve host durumu "Kapı A12 önü" (-12 dk).
  -- Yani iki kişi buluşmuş; oturumun `pending` kalması verinin
  -- hikâyeyle çelişmesiydi.
  -- ══════════════════════════════════════════════════════════════════
  insert into sessions (request_id, status, started_at, host_confirmed, guest_confirmed,
                        host_status, host_status_ts, guest_status, guest_status_ts)
    values (rq, 'active', now() - interval '9 minutes', true, true,
            'Kapı A12 önü', now() - interval '12 minutes',
            'Salondayım, pencere tarafı', now() - interval '6 minutes') returning id into ses;

  insert into requests (guest_id, host_id, avail_id, status, intro_message, responded_at, created_at)
    values (kt, hs, av_s1, 'completed', 'Aynı uçuştayız.', now() - interval '3 hours', now() - interval '4 hours')
    returning id into rq2;
  insert into sessions (request_id, status, started_at, completed_at, host_confirmed, guest_confirmed)
    values (rq2, 'completed', now() - interval '2 hours', now() - interval '1 hour', true, true) returning id into ses2;
  insert into requests (guest_id, host_id, avail_id, status, intro_message, created_at)
    values (ey, hs, av_s1, 'pending', 'Uçuştan önce kahve?', now() - interval '25 minutes');
  -- tasarım 12: "3 misafir ağırladın" — bu ay iki tamamlanmış oturum daha
  -- (saat cinsinden geriye: ay başı ne zaman olursa olsun "bu ay" sayılsın)
  for r in select * from (values (ey, av_s2, 6), (ad, av_s2, 3)) as x(gid, aid, saat) loop
    insert into requests (guest_id, host_id, avail_id, status, intro_message, responded_at, created_at)
      values (r.gid, hs, r.aid, 'completed', 'Aktarmada kahve.', now() - (r.saat || ' hours')::interval - interval '1 hour', now() - (r.saat || ' hours')::interval - interval '2 hours')
      returning id into rq2;
    insert into sessions (request_id, status, started_at, completed_at, host_confirmed, guest_confirmed)
      values (rq2, 'completed', now() - (r.saat || ' hours')::interval - interval '1 hour', now() - (r.saat || ' hours')::interval, true, true);
  end loop;

  -- ── bağlantılar (13_baglantilar: gelen Deniz K. · giden Kaan T. (bekliyor), Ece Y. (bağlısınız))
  delete from messages where channel_id in (select id from chat_channels where connection_id in
    (select id from connection_requests where from_id in (g, hd, kt, ey, ad, bs, ek) or to_id in (g, hd, kt, ey, ad, bs, ek)));
  delete from chat_channels where connection_id in
    (select id from connection_requests where from_id in (g, hd, kt, ey, ad, bs, ek) or to_id in (g, hd, kt, ey, ad, bs, ek));
  delete from connection_requests where from_id in (g, hd, kt, ey, ad, bs, ek) or to_id in (g, hd, kt, ey, ad, bs, ek);
  insert into connection_requests (from_id, to_id, status, intro) values
    (hd, g, 'pending',  'Uçuşun aynı, güzel.'),
    (g, kt, 'pending',  'Aynı uçuştayız.'),
    (g, ey, 'accepted', 'Aynı rota.'),
    (ad, g, 'pending',  'Seninle tanışmak istiyor.');

  -- 🔴 12 EYLÜL (Gökberk md.5) — "bağlantılarım boş gelmiş tasarımda".
  -- 06b_sohbet_tanis TANIŞMA SOHBETİ ekranı ama tohumda hiç tanışma
  -- mesajı yoktu: ekran boş çıkıyor, kontakt levhasında "bu ekran ne
  -- yapıyor?" sorusu cevapsız kalıyordu. Kabul edilmiş bağlantıya
  -- (Gökberk ↔ Ece Y.) gerçek bir kanal ve dört mesaj.
  select id into cr from connection_requests where from_id = g and to_id = ey;
  insert into chat_channels (connection_id, kind, active) values (cr, 'connection', true) returning id into ch;
  insert into messages (channel_id, from_id, body, created_at) values
    (ch, g,  'Merhaba Ece, aynı rotadayız — IST''te kahve içelim mi?', now() - interval '26 minutes'),
    (ch, ey, 'Olur! Ben 14:40''ta iniyorum, aktarmam uzun.',           now() - interval '24 minutes'),
    (ch, g,  'A7 kapısındayım, lacivert ceket.',                       now() - interval '21 minutes'),
    (ch, ey, 'Gördüm, geliyorum.',                                     now() - interval '19 minutes');

  -- ── bildirimler (10_bildirim)
  delete from notifications where user_id = g;
  insert into notifications (user_id, category, title, body, read, created_at) values
    (g, 'requests',    'İstek kabul edildi',    'Deniz K. seni Primeclass''a alıyor.',          false, now() - interval '2 minutes'),
    (g, 'connections', 'Yeni bağlantı isteği',  'Ayşegül D. seninle tanışmak istiyor.',         false, now() - interval '18 minutes'),
    (g, 'sessions',    'Oturum Devam Ediyor',   'TAV Primeclass · Kapı A12 önü.',               true,  now() - interval '1 hour'),
    (g, 'ratings',     'Oturumu değerlendir',   'Deniz K. ile geçen oturum tamamlandı.',        true,  now() - interval '3 hours'),
    (g, 'credits',     'Kredin yenilendi',      'Bu ay 2 kredi eklendi.',                        true,  now() - interval '1 day');
  -- UZUN LİSTE: 24 satırlık bildirim akışı (kaydırma ve ritim ölçümü)
  for r in select generate_series(1, 24) as i loop
    insert into notifications (user_id, category, title, body, read, created_at)
      values (g, 'system', 'Havalimanı güncellemesi #' || r.i,
              'IST Dış Hatlar terminalinde salon kapasitesi güncellendi. Kart kurallarını yeniden kontrol ettik.',
              r.i % 3 = 0, now() - (r.i || ' hours')::interval);
  end loop;

  -- güven puanı/rozet: oturum tetikleyicileri yeniden hesaplıyor; tasarımın
  -- değerleri EN SONDA yazılır ("SELİN B. · GÜVENİLİR HOST")
  update trust_scores set score = 88, badge = 'trusted' where user_id = hs;
  update trust_scores set score = 84, badge = 'trusted' where user_id = hd;
  update trust_scores set score = 44, badge = 'basic'   where user_id = g;
end $$;

commit;
select 'sahne seed OK' as sonuc;
