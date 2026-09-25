-- ============================================================================
-- LoungeLink · SEED5_BASVURU_AKISLARI.sql                   (22 Ağustos 2026)
--
-- "KABUL ET / REDDET AKIŞINI GÖREBİLEYİM" (Gökberk, madde 3)
--
-- Gökberk: "Yayın sayfasında başvuru kısmında bazı ilanlara birkaç tane
-- başvuru ekle ki kabul et reddet gibi butonları ve aksiyonları da
-- görebileyim. Birkaçında ilan dolu olmuş olsun ki kabul etsem bile ilan
-- dolduğu için kabul edemediğime hata mesajı alayım, birkaçında da ilan
-- boş olsun ki rahat rahat kabul ret yapabileyim."
--
-- ⚠️ Ekran görüntüsünde her ilanda TEK başvuru var ve o da zaten kabul
-- edilmiş. Yani host hiçbir zaman KARAR VERME ekranını görmüyor: kabul/
-- ret düğmeleri bir kez bile gösterilmiyor.
--
-- ── BU DOSYA ÜÇ DURUMU BİRDEN KURUYOR ───────────────────────────────
--   A) BOŞ İLAN + 3 BEKLEYEN BAŞVURU   → kabul/ret rahat denenir
--   B) DOLU İLAN + 2 BEKLEYEN BAŞVURU  → kabul denemesi HATA vermeli
--                                        ('availability_full')
--   C) KARIŞIK İLAN (1 kabul + 2 bekleyen, 1 slot kaldı)
--                                        → biri kabul edilir, sonraki
--                                          hata verir; sınır tam orada
--
-- 🔴 KENDİ BAŞVURUM SORUNU. Bir ilana başvurabilmek için misafirin
-- KREDİSİ ve ÖRTÜŞEN SEYAHATİ olmalı. Dört seed hesabı var; A/B/C için
-- 7 ayrı başvuru gerekiyor. Bu yüzden dosya dört EK misafir hesabı
-- açıyor (guest3..guest6) — hepsi giriş yapılabilir, şifre aynı.
--
-- ⚠️ RPC İLE DEĞİL, DOĞRUDAN YAZIYORUM ve sebebini söylüyorum:
-- `send_request` (033) `auth.uid()` okuyor; SQL Editor'de auth.uid() NULL
-- olduğu için RPC yolu burada çalışmaz. Doğrudan yazarken RPC'nin yaptığı
-- HER ŞEYİ elle yapıyorum: kredi tut, filled artır, bildirim yaz.
-- Atlarsam kabul akışı bu satırlarda patlar ve seed "test edilebilir"
-- olmaz.
--
-- ⚠️ İlk yazımda `request_type` diye bir kolon uydurdum; şema
-- (001:192) kolonu `type` diye adlandırıyor ve tipi `request_type`
-- ENUM'u ('standard' | 'direct_invite'). Harness yakaladı.
-- 🆕 SINIF: "TİPİN ADI, KOLONUN ADI DEĞİLDİR." 
-- ============================================================================

do $seed5$
declare
  v_host1 uuid; v_host2 uuid;
  v_gs    uuid[];
  v_g     uuid;
  v_i     int;
  v_av_bos    uuid; v_av_dolu uuid; v_av_karisik uuid;
  v_rid   uuid;
  v_bal   int;
  v_slots int;
  v_ap    text; v_d date; v_tf time; v_tt time;
  v_eposta text;
  v_ad    text;
  v_n     int := 0;
  v_sifre_sql text;
begin
  select id into v_host1 from users where email = 'host1@seed.loungelink.test';
  select id into v_host2 from users where email = 'host2@seed.loungelink.test';
  if v_host1 is null then
    raise notice 'SEED5: host1 yok — once SEED3/SEED4 calistirilmali. HICBIR SEY YAPILMADI.';
    return;
  end if;

  -- ------------------------------------------------------------------
  -- 1) EK MİSAFİR HESAPLARI (guest3..guest6)
  -- ------------------------------------------------------------------
  -- Şifre kurgusu SEED1'den kopyalanıyor — ama 227'nin dersiyle:
  -- yalnız hash değil, GoTrue alanları ve auth.identities de kuruluyor.
  -- (227: "kopyalarken neyi kopyaladığını söylemek, kopyaladığını
  -- kanıtlamaz.")
  v_gs := '{}';
  for v_i in 3..6 loop
    v_eposta := 'guest' || v_i || '@seed.loungelink.test';
    v_ad     := 'guest' || v_i;

    select id into v_g from users where email = v_eposta;
    if v_g is null then
      v_g := gen_random_uuid();
      insert into users (id, email, role, password_hash)
      values (v_g, v_eposta, 'guest', 'seed');
      insert into profiles (user_id, name, profession, bio, guest_capacity)
      values (v_g, v_ad, 'Yolcu', 'SEED5 başvuru akışı hesabı', null)
      on conflict (user_id) do nothing;
      insert into verifications (user_id, email_verified, phone_verified)
      values (v_g, true, true)
      on conflict (user_id) do update set email_verified = true, phone_verified = true;
      v_n := v_n + 1;
    end if;

    -- auth tarafı — 🔴 SEED3'ün dersi: `crypt()` Supabase'de `extensions`
    -- şemasında olabilir ve arama yolunda olmayabilir. İlk yazımda
    -- doğrudan `crypt(...)` çağırdım ve harness "function gen_salt
    -- (unknown) does not exist" dedi. Çözümleme DİNAMİK olmalı.
    -- ⚠️ Şifre + GoTrue alanları + auth.identities: ÜÇÜ BİRDEN
    -- (227'nin sınıfı — hash tek başına giriş yaptırmaz).
    if to_regclass('auth.users') is not null then
      insert into auth.users (id, email, created_at, updated_at)
      values (v_g, v_eposta, now(), now())
      on conflict (id) do nothing;
      v_sifre_sql := case
        when exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where p.proname='crypt' and n.nspname='extensions')
          then 'update auth.users set encrypted_password = extensions.crypt($1, extensions.gen_salt(''bf'')), '
            || 'email_confirmed_at = now() where id = $2'
        when exists (select 1 from pg_proc where proname='crypt')
          then 'update auth.users set encrypted_password = crypt($1, gen_salt(''bf'')), '
            || 'email_confirmed_at = now() where id = $2'
        else null end;
      if v_sifre_sql is null then
        raise notice 'SEED5: pgcrypto YOK — % sifresi yazilamadi (giris yapilamaz).', v_eposta;
      else
        execute v_sifre_sql using 'Seed1234!', v_g;
      end if;
      if to_regclass('auth.identities') is not null then
        insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
        values (gen_random_uuid(), v_g,
                jsonb_build_object('sub', v_g::text, 'email', v_eposta),
                'email', v_g::text, now(), now(), now())
        on conflict do nothing;
      end if;
    end if;

    -- Kredi: 3'er (başvuru başına 1 harcanıyor)
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_g;
    if v_bal < 3 then
      insert into credit_ledger (user_id, delta, reason, balance_after)
      values (v_g, 3 - v_bal, 'seed5_grant', 3);
    end if;

    v_gs := v_gs || v_g;
  end loop;

  -- ------------------------------------------------------------------
  -- 2) ÜÇ İLAN SEÇ — A boş, B dolu, C karışık
  -- ------------------------------------------------------------------
  -- host1'in gelecek tarihli, aktif, başvurusu OLMAYAN ilanlarından
  -- üç tane. Yoksa yenisini açmıyorum: var olan vitrini bozmam.
  select id into v_av_bos from availabilities
   where host_id = v_host1 and active and avail_date >= current_date
     and not exists (select 1 from requests r where r.avail_id = availabilities.id)
   order by avail_date, time_from limit 1;

  select id into v_av_dolu from availabilities
   where host_id = v_host1 and active and avail_date >= current_date
     and id is distinct from v_av_bos
     and not exists (select 1 from requests r where r.avail_id = availabilities.id)
   order by avail_date, time_from offset 1 limit 1;

  select id into v_av_karisik from availabilities
   where host_id = coalesce(v_host2, v_host1) and active and avail_date >= current_date
     and id is distinct from v_av_bos and id is distinct from v_av_dolu
     and not exists (select 1 from requests r where r.avail_id = availabilities.id)
   order by avail_date, time_from limit 1;

  if v_av_bos is null then
    raise notice 'SEED5: basvurusuz aktif ilan bulunamadi — SEED4 calistirilmis mi?';
    return;
  end if;

  -- ------------------------------------------------------------------
  -- 3) YARDIMCI: bir misafire seyahat + başvuru kur
  -- ------------------------------------------------------------------
  -- (inline; PL/pgSQL'de iç fonksiyon yok, döngüyle yazıyorum)

  -- ---- A) BOŞ İLAN + 3 BEKLEYEN ----
  select airport_code, avail_date, time_from, time_to, slots
    into v_ap, v_d, v_tf, v_tt, v_slots
    from availabilities where id = v_av_bos;
  -- Kontenjanı 3'e çıkar ki üçü de kabul edilebilsin.
  update availabilities set slots = greatest(slots, 3), filled = 0 where id = v_av_bos;

  -- 🔴 23 AGUSTOS: SEED5 AYNI MISAFIRI BIRDEN COK ILANA BASVURTUYOR
  -- (senaryonun geregi: "bir ilanda 2+ bekleyen basvuru"). SQL 246 ile
  -- gelen "ayni anda kac acik istegin olabilir" tavani bunu engelledi.
  --
  -- Tavan dogru; SEED'in kendini o dunyaya gore KURMASI gerekiyor.
  -- Seed misafirlerini Kahya planina aliyorum (tavan 6) — gercek
  -- hayatta da bu senaryoyu yasayacak kisi ust plandaki kisidir.
  --
  -- 🆕 SINIF: "TEST VERISI, URUNUN KURALLARINI DELMEK ICIN DEGIL, O
  -- KURALLARIN ICINDE BIR DURUM KURMAK ICIN VARDIR."
  update users set plan = 'kahya' where id = any(v_gs);

  for v_i in 1..3 loop
    v_g := v_gs[v_i];
    insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
    values (v_g, v_ap, v_d, v_tf, v_tt, 'TK' || (900 + v_i))
    on conflict do nothing;

    insert into requests (guest_id, host_id, avail_id, status, type,
                          intro_message, match_score, idempotency_key)
    values (v_g, v_host1, v_av_bos, 'pending', 'standard',
            'Merhaba, aynı saatlerde aktarmadayım. Yanınızda bir kişilik yer var mı?',
            60 + v_i, 'seed5_bos_' || v_i)
    on conflict (idempotency_key) do nothing
    returning id into v_rid;

    if v_rid is not null then
      -- 007'nin yaptığı şey: 1 kredi emanete alınır ve filled ARTMAZ
      -- (filled kabul edilince artar — 009:117 kabul yolunda).
      select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_g;
      insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
      values (v_g, -1, 'request_hold', v_rid, v_bal - 1);
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      values (v_host1, 'requests', 'Yeni istek ✦',
              'Bir yolcu ilanına başvurdu.', 'request', v_rid);
    end if;
  end loop;

  -- ---- B) DOLU İLAN + 2 BEKLEYEN ----
  -- 🔴 Amaç: host "kabul et"e bassın ve GERÇEK hata mesajını görsün.
  -- İlanı DOLU yapmanın dürüst yolu kontenjanı 1'e indirip filled=1
  -- yazmak; yani bir kişi zaten kabul edilmiş olsun.
  if v_av_dolu is not null then
    select airport_code, avail_date, time_from, time_to
      into v_ap, v_d, v_tf, v_tt from availabilities where id = v_av_dolu;
    update availabilities set slots = 1, filled = 1 where id = v_av_dolu;

    -- Zaten kabul edilmiş olan: guest1
    select id into v_g from users where email = 'guest1@seed.loungelink.test';
    if v_g is not null then
      insert into visits (user_id, airport_code, visit_date, time_from, time_to)
      values (v_g, v_ap, v_d, v_tf, v_tt) on conflict do nothing;
      insert into requests (guest_id, host_id, avail_id, status, type,
                            intro_message, match_score, idempotency_key, responded_at)
      values (v_g, v_host1, v_av_dolu, 'accepted', 'standard',
              'Teşekkürler, görüşmek üzere!', 88, 'seed5_dolu_kabul', now())
      on conflict (idempotency_key) do nothing;
    end if;

    -- Ve iki kişi HÂLÂ bekliyor → host kabul etmeyi deneyince hata alır
    for v_i in 1..2 loop
      v_g := v_gs[v_i];
      insert into visits (user_id, airport_code, visit_date, time_from, time_to)
      values (v_g, v_ap, v_d, v_tf, v_tt) on conflict do nothing;
      insert into requests (guest_id, host_id, avail_id, status, type,
                            intro_message, match_score, idempotency_key)
      values (v_g, v_host1, v_av_dolu, 'pending', 'standard',
              'Yer kaldıysa çok sevinirim.', 55 + v_i, 'seed5_dolu_' || v_i)
      on conflict (idempotency_key) do nothing
      returning id into v_rid;
      if v_rid is not null then
        select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_g;
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
        values (v_g, -1, 'request_hold', v_rid, v_bal - 1);
      end if;
    end loop;
  end if;

  -- ---- C) KARIŞIK: 1 kabul + 2 bekleyen, 2 slot ----
  -- Sınır tam burada görünür: host birini daha kabul edebilir, ikincisinde
  -- ilan dolar ve üçüncü kabul HATA verir.
  if v_av_karisik is not null then
    select airport_code, avail_date, time_from, time_to
      into v_ap, v_d, v_tf, v_tt from availabilities where id = v_av_karisik;
    update availabilities set slots = 2, filled = 1 where id = v_av_karisik;

    select id into v_g from users where email = 'guest2@seed.loungelink.test';
    if v_g is not null then
      insert into visits (user_id, airport_code, visit_date, time_from, time_to)
      values (v_g, v_ap, v_d, v_tf, v_tt) on conflict do nothing;
      insert into requests (guest_id, host_id, avail_id, status, type,
                            intro_message, match_score, idempotency_key, responded_at)
      values (v_g, coalesce(v_host2, v_host1), v_av_karisik, 'accepted', 'standard',
              'Görüşmek üzere.', 74, 'seed5_karisik_kabul', now())
      on conflict (idempotency_key) do nothing;
    end if;

    for v_i in 3..4 loop
      v_g := v_gs[v_i];
      insert into visits (user_id, airport_code, visit_date, time_from, time_to)
      values (v_g, v_ap, v_d, v_tf, v_tt) on conflict do nothing;
      insert into requests (guest_id, host_id, avail_id, status, type,
                            intro_message, match_score, idempotency_key)
      values (v_g, coalesce(v_host2, v_host1), v_av_karisik, 'pending', 'standard',
              'Aynı uçuştayım, uygunsanız katılmak isterim.', 62 + v_i,
              'seed5_karisik_' || v_i)
      on conflict (idempotency_key) do nothing
      returning id into v_rid;
      if v_rid is not null then
        select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_g;
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
        values (v_g, -1, 'request_hold', v_rid, v_bal - 1);
      end if;
    end loop;
  end if;

  -- ------------------------------------------------------------------
  -- 4) GÜVEN PUANI — başvuru kartındaki sayı anlamlı olsun
  -- ------------------------------------------------------------------
  -- Ekran görüntüsünde "guest1 · 44" yazıyor ve 44'ün ne olduğu belli
  -- değil. App tarafında etiket ekleniyor; burada da SAYILARIN FARKLI
  -- olmasını sağlıyorum, yoksa etiket eklense bile hepsi aynı görünüp
  -- "acaba sabit mi?" sorusunu doğurur.
  for v_i in 1..4 loop
    insert into trust_scores (user_id, score, badge)
    values (v_gs[v_i], 40 + v_i * 9,
            case when 40 + v_i*9 >= 75 then 'Trusted Host'
                 when 40 + v_i*9 >= 60 then 'Verified Host'
                 else 'Basic Verified' end)
    on conflict (user_id) do update set score = excluded.score, badge = excluded.badge;
  end loop;

  raise notice 'SEED5: % yeni misafir hesabi · A(bos)=% · B(dolu)=% · C(karisik)=%',
    v_n, v_av_bos, coalesce(v_av_dolu::text,'YOK'), coalesce(v_av_karisik::text,'YOK');
end $seed5$;

-- ----------------------------------------------------------------------------
-- NÖBETÇİ — üç durum GERÇEKTEN kuruldu mu?
-- ----------------------------------------------------------------------------
do $n5$
declare
  v_bekleyen int; v_dolu int; v_cok int;
begin
  select count(*) into v_bekleyen from requests where status = 'pending';
  select count(*) into v_dolu
    from availabilities a
   where a.active and a.filled >= a.slots
     and exists (select 1 from requests r where r.avail_id = a.id and r.status='pending');
  select count(*) into v_cok
    from (select avail_id from requests where status='pending'
           group by avail_id having count(*) >= 2) z;

  if v_bekleyen = 0 then
    raise exception 'SEED5 NOBETCI: hic BEKLEYEN basvuru yok — kabul/ret ekrani yine gorunmez.';
  end if;
  if v_dolu = 0 then
    raise notice 'SEED5 UYARI: dolu ilanda bekleyen basvuru YOK — "ilan doldu" hatasi denenemez. '
                 '(host1''in basvurusuz ikinci bir aktif ilani olmayabilir.)';
  end if;
  if v_cok = 0 then
    raise notice 'SEED5 UYARI: hicbir ilanda 2+ bekleyen basvuru yok.';
  end if;

  raise notice 'SEED5 OK · bekleyen basvuru: % · dolu+bekleyenli ilan: % · 2+ basvurulu ilan: %',
    v_bekleyen, v_dolu, v_cok;
  raise notice 'SEED5 OLCULMEDI: kabul akisinin GERCEK hata mesaji (availability_full) yalniz '
               'app''ten host1 ile denendiginde gorulur — auth.uid() burada NULL.';
end $n5$;

-- ----------------------------------------------------------------------------
-- SON ADIM · SEED'LER ARASI ÇAKIŞMA ONARIMI
-- ----------------------------------------------------------------------------
-- 🔴 GÖKBERK SORDU: "1'den 5'e çalıştıracağım ama çakışma ve bu sebeple
-- hatalı bir görünüm oluşmaz di mi?" — Varsaymadım, ÖLÇTÜM. Beşini de
-- kurup baktım:
--
--   aynı host+tarih+salon mükerrer ilan  : 0
--   filled > slots (tutarsız)            : 0
--   mükerrer e-posta                     : 0
--   aynı host, aynı saatte İKİ HAVALİMANI: 2   ← ÇAKIŞMA VAR
--
-- Bulunan tek çakışma: host1, 2026-08-25'te hem ESB 09:00–12:00 hem
-- IST 10:00–14:00. Bir insan aynı saatte iki havalimanında olamaz.
-- Sebep: host1'in ilanları İKİ AYRI SEED'den geliyor (SEED3 temel,
-- SEED4 vitrin) ve ikisi birbirinin saatini bilmiyor.
--
-- Uygulama ÇÖKMÜYOR; her ekran tek başına doğru görünüyor. Ama host1'in
-- profiline bakan biri imkânsız bir tablo görür. Test verisinin işi
-- gerçeği taklit etmek; taklit edemediği yerde onu düzeltmek gerekir.
--
-- 🆕 SINIF: **"AYRI AYRI DOĞRU İKİ VERİ KÜMESİ, BİRLEŞTİĞİNDE İMKÂNSIZ
-- BİR DÜNYA ÜRETEBİLİR."**
--
-- Onarım BELİRLENİMCİ: çakışan çiftin GEÇ oluşturulanı bir gün ileri
-- kaydırılır (kural senaryosu tarihe bağlı değil, korunur). Ne
-- taşındığı tek tek yazılır — sessiz düzeltme yok.
do $cakisma$
declare r record; v_n int := 0; v_tur int := 0;
begin
  loop
    v_tur := v_tur + 1;
    exit when v_tur > 10;

    select a.id, a.avail_date, a.airport_code, u.email, b.airport_code as oteki
      into r
      from availabilities a
      join users u on u.id = a.host_id
      join availabilities b
        on b.host_id = a.host_id and b.id <> a.id
       and b.avail_date = a.avail_date
       and b.time_from < a.time_to and a.time_from < b.time_to
       and b.airport_code <> a.airport_code
     where a.created_at >= b.created_at
       and not exists (select 1 from requests q
                        where q.avail_id = a.id and q.status in ('pending','accepted'))
     order by a.created_at desc, a.id
     limit 1;

    exit when not found;

    update availabilities set avail_date = avail_date + 1 where id = r.id;
    v_n := v_n + 1;
    raise notice 'SEED5 CAKISMA ONARIMI · % · % (%) → % gunu bir gun ileri alindi (ayni gun % ilani da vardi)',
      r.email, r.airport_code, r.avail_date, r.avail_date + 1, r.oteki;
  end loop;

  if v_n = 0 then
    raise notice 'SEED5 · seedler arasi cakisma yok (ayni host, ayni saat, iki havalimani: 0)';
  else
    raise notice 'SEED5 · % cakisan ilan bir gun ileri alindi', v_n;
  end if;

  -- NÖBETÇİ: onarımdan sonra çakışma KALMAMALI
  if exists (select 1 from availabilities a join availabilities b
              on b.host_id=a.host_id and b.id<>a.id and b.avail_date=a.avail_date
             and b.time_from < a.time_to and a.time_from < b.time_to
             and b.airport_code <> a.airport_code) then
    raise notice 'SEED5 UYARI: cakisma SURUYOR — kalan cift kabul/bekleyen basvurulu oldugu icin '
                 'dokunulmadi. Basvuruyu iptal edip SEED5 i tekrar kosarsan duzelir.';
  end if;
end $cakisma$;

select 'SEED5 BASVURU AKISLARI' as sonuc,
       (select count(*) from requests where status='pending') as bekleyen_basvuru,
       (select count(*) from users where email like 'guest%@seed.loungelink.test') as misafir_hesabi;
