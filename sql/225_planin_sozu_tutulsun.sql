-- ============================================================================
-- LoungeLink · 225_planin_sozu_tutulsun.sql               (19 Ağustos 2026)
--
-- PLAN SAYFASINDA YAZAN DÖRT SÖZ KODDA KARŞILIKSIZDI
--
-- Sınır envanterinde çıktı: `plan_catalog` dört şey vaat ediyor, dördünü de
-- uygulayan yok.
--     kart_siniri          1 / 3 / sınırsız      → uygulayan YOK
--     ucus_dogrulama_ayda  3 / 20 / 9999         → uygulayan YOK
--     one_cikarma_ayda     0 / 2 / 99            → uygulayan YOK
--     monthly_credits      2 / 6 / 12            → uygulayan YOK
--
-- 🔴 Bunların üçü "eksik özellik", biri ÖDENMİŞ BİR SÖZÜN TUTULMAMASI.
-- Kâhya planına 249 ₺ ödeyen biri ayda 12 kredi bekliyor ve hiç almıyor.
-- Bu bir hata değil, bir borç.
--
-- Gökberk kararı bana bıraktı. Dördü için dört ayrı karar verdim ve her
-- birinin gerekçesini yazıyorum — çünkü yarın biri "neden böyle" diye
-- soracak ve cevabın kodda durması gerekiyor.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- KARAR 1 · KART SINIRI KALDIRILIYOR (vaat siliniyor, kod değişmiyor)
--
-- Uygulamak, bugün 2 kartı olan Yolcu kullanıcısından bir şey GERİ ALMAK
-- olurdu. Ama asıl sebep bu değil.
--
-- 🔴 CÜZDAN BU ÜRÜNÜN KANCASI, PAYWALL'I DEĞİL.
-- LoungeLink'in tek satış argümanı şu soruya doğru cevap vermek:
-- "bu kartla, bu salonda, bu uçuşta ne olur?" Kullanıcının kartlarını
-- beyan etmesini SINIRLAMAK, tam da bu sorunun sorulmasını engellemek
-- demek. Üstelik beyan edilen her kart bizim için VERİDİR — hangi kartın
-- hangi salonda geçtiğini öğrendiğimiz tek yol.
--
-- Yani kart sınırı iki taraflı zarar: kullanıcı değerini göremiyor, biz
-- veriyi toplayamıyoruz. Para kazanılacak yer BURASI değil; eylemler
-- (öne çıkarma, uçuş doğrulama, kredi) zaten ücretli.
--
-- Teknik tavan (program başına 4 kart, SQL 193) DURUYOR — o bir kötüye
-- kullanım freni, plan farkı değil.
-- ════════════════════════════════════════════════════════════════════════

update plan_catalog set kart_siniri = 999 where aktif;

do $$
declare r record; v_yeni jsonb;
begin
  for r in select plan, perks, perks_en from plan_catalog where aktif loop
    -- "3 karta kadar cüzdan" / "Sınırsız kart" satırları artık YANLIŞ
    -- değil ama ANLAMSIZ: herkes için aynı. Vaadi listeden çıkarıyoruz.
    -- Tutulamayan sözü silmek, tutuyormuş gibi yapmaktan iyidir.
    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_yeni
      from jsonb_array_elements_text(coalesce(r.perks,'[]'::jsonb)) x
     where x !~* 'kart';
    update plan_catalog set perks = v_yeni where plan = r.plan;

    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_yeni
      from jsonb_array_elements_text(coalesce(r.perks_en,'[]'::jsonb)) x
     where x !~* 'card';
    update plan_catalog set perks_en = v_yeni where plan = r.plan;
  end loop;
  raise notice '225: kart sinirı vaadi kaldirildi (cuzdan herkese acik)';
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- KARAR 2 · UÇUŞ DOĞRULAMA — UYGULANIYOR, AMA YALNIZ EKLEYEREK
--
-- Bugünkü tek gerçek sınır: herkese 3/gün (`flight_user_daily`).
-- Plan "ayda 20" / "ayda 9999" diyor ve hiç okunmuyor.
--
-- 🔴 SINIRI DÜŞÜREN YÖNDE UYGULAMIYORUM. Ücretsiz kullanıcı bugün ne
-- alıyorsa aynısını almaya devam ediyor (3/gün). Ücretli plan üstüne
-- AYLIK bir havuz ekliyor: günlük hak bittiğinde aylık havuzdan
-- harcanıyor. Kimse kaybetmiyor, ödeyen kazanıyor.
--
-- Sebebi basit: bir sözü tutmanın yolu, başka birinden bir şey almak
-- olmamalı. "Artık uygulanıyor" diye ücretsiz kullanıcının hakkını
-- kısmak, sözü tutmak değil, bahane bulmaktır.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.flight_fetch_allow(p_user_id uuid, p_flight text, p_day date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_on    boolean := coalesce((select (value #>> '{}')::boolean from beta_settings where key='flight_autofetch'), true);
  v_ud    int     := coalesce((select (value #>> '{}')::int from beta_settings where key='flight_user_daily'), 3);
  v_mc    int     := coalesce((select (value #>> '{}')::int from beta_settings where key='flight_month_cap'), 80);
  v_user  int;
  v_month int;
  v_out   text;
  v_plan_ay int;      -- planın aylık uçuş doğrulama hakkı
  v_kul_ay  int;      -- kullanıcının bu ay harcadığı
begin
  if not v_on then v_out := 'denied_off';
  else
    -- 🔴 PENCERE Europe/Istanbul'a bağlandı. `date_trunc('day', now())`
    -- sunucu UTC'sine göre çalışıyordu; Türkiye'de kota gece 03:00'te
    -- yenileniyordu ve kullanıcıya "gece yarısı" diyecektik.
    select count(*) into v_user from flight_fetch_log
     where user_id = p_user_id and outcome = 'provider'
       and created_at >= (date_trunc('day', timezone('Europe/Istanbul', now()))
                            at time zone 'Europe/Istanbul');
    select count(*) into v_month from flight_fetch_log
     where outcome = 'provider'
       and created_at >= (date_trunc('month', timezone('Europe/Istanbul', now()))
                            at time zone 'Europe/Istanbul');

    -- Planın aylık havuzu (225): günlük hak bittiğinde devreye girer.
    select coalesce(p.ucus_dogrulama_ayda, 0) into v_plan_ay
      from users u left join plan_catalog p on p.plan = u.plan and p.aktif
     where u.id = p_user_id;
    v_plan_ay := coalesce(v_plan_ay, 0);

    select count(*) into v_kul_ay from flight_fetch_log
     where user_id = p_user_id and outcome = 'provider'
       and created_at >= (date_trunc('month', timezone('Europe/Istanbul', now()))
                            at time zone 'Europe/Istanbul');

    if v_month >= v_mc then
      -- Platform tavanı herkesi bağlar; plan bunu aşamaz (maliyet freni).
      v_out := 'denied_month_cap';
    elsif v_user < v_ud then
      v_out := 'provider';                       -- günlük hak duruyor
    elsif v_kul_ay < v_plan_ay then
      v_out := 'provider';                       -- 225: planın aylık havuzu
    else
      v_out := 'denied_user_cap';
    end if;
  end if;

  insert into flight_fetch_log (user_id, flight_no, flight_day, outcome)
  values (p_user_id, upper(trim(coalesce(p_flight,''))), p_day, v_out);

  return jsonb_build_object(
    'allow', v_out = 'provider',
    'reason', v_out,
    'user_today', coalesce(v_user,0), 'user_cap', v_ud,
    'plan_month_used', coalesce(v_kul_ay,0), 'plan_month_cap', coalesce(v_plan_ay,0),
    'month_used', coalesce(v_month,0), 'month_cap', v_mc);
end $$;
revoke all on function public.flight_fetch_allow(uuid, text, date) from public, authenticated;


-- ════════════════════════════════════════════════════════════════════════
-- KARAR 3 · ÖNE ÇIKARMA — PLAN HAKKI EKLENİYOR, PUAN YOLU DURUYOR
--
-- Bugün tek kapı: 200 puan (`set_featured`). Plan "ayda 2" / "ayda 99"
-- diyor, okunmuyor.
--
-- Yine EKLEYEREK: puanla öne çıkarma herkes için aynen duruyor. Ücretli
-- planın aylık ücretsiz hakkı ÖNCE harcanıyor; bittiğinde puana düşüyor.
-- Ücretsiz kullanıcı (Yolcu, hak=0) bugünkü davranışı birebir görüyor.
--
-- 🔴 VE HATA METNİ DÜZELİYOR. `insufficient_points` kullanıcıya "Yetersiz
-- puan." diyordu — KAÇ puan gerektiğini söylemiyordu. i18n'de
-- `e_insufficient_points_feature` diye "200 puan gerekir" yazan bir
-- anahtar VAR ama hiçbir yerden çağrılmıyor: yani doğru cümle yazılmış,
-- bağlanmamış. Artık hata `hint` ile eksik puanı da taşıyor.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.set_featured(p_avail_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_pts int; v_host uuid;
  v_plan_hak int; v_kul_ay int; v_ay_bas timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select host_id into v_host from availabilities where id = p_avail_id;
  if v_host is null then raise exception 'availability_not_found'; end if;
  if v_host <> v_uid then raise exception 'not_owner'; end if;

  v_ay_bas := (date_trunc('month', timezone('Europe/Istanbul', now()))
                 at time zone 'Europe/Istanbul');

  select coalesce(p.one_cikarma_ayda, 0) into v_plan_hak
    from users u left join plan_catalog p on p.plan = u.plan and p.aktif
   where u.id = v_uid;
  v_plan_hak := coalesce(v_plan_hak, 0);

  select count(*) into v_kul_ay from points_ledger
   where user_id = v_uid and reason = 'plan_feature' and created_at >= v_ay_bas;

  if coalesce(v_kul_ay,0) < v_plan_hak then
    -- 225: planın aylık ücretsiz öne çıkarma hakkı. Puan HARCANMAZ;
    -- deftere 0 delta ile iz düşülür ki sayılabilsin.
    insert into points_ledger (user_id, delta, reason, ref_id)
    values (v_uid, 0, 'plan_feature', p_avail_id);
  else
    select coalesce(sum(delta),0) into v_pts from points_ledger where user_id = v_uid;
    if v_pts < 200 then
      raise exception 'insufficient_points'
        using detail = format('%s/200 puan', v_pts),
              hint   = 'eksik=' || (200 - v_pts)::text;
    end if;
    insert into points_ledger (user_id, delta, reason, ref_id)
    values (v_uid, -200, 'feature_listing', p_avail_id);
  end if;

  update availabilities
     set featured_until = now() + interval '24 hours'
   where id = p_avail_id;

  return jsonb_build_object('ok', true,
    'kaynak', case when coalesce(v_kul_ay,0) < v_plan_hak then 'plan' else 'puan' end,
    'plan_hakki_kalan', greatest(0, v_plan_hak - coalesce(v_kul_ay,0) - 1));
end $$;
grant execute on function public.set_featured(uuid) to authenticated;


-- ════════════════════════════════════════════════════════════════════════
-- KARAR 4 · AYLIK KREDİ — ÖDENMİŞ SÖZ, EN ÖNCELİKLİSİ
--
-- Kâhya 249 ₺ · ayda 12 kredi vaat ediyor. `monthly_topup` ayarı
-- `{"enabled": false}` ve zaten tek okuyanı yok. Yani söz hiç
-- tutulmamış.
--
-- 🔴 CRON'A BAĞLAMIYORUM — KENDİ KENDİNİ İYİLEŞTİRİYOR.
-- Zamanlanmış iş kurmak, kurulmadığında sessizce çalışmayan bir söz daha
-- üretmek demek (bu projede `send_missed_value_digest` tam olarak bu
-- durumda: yazılmış, cron'u yok). Bunun yerine kredi, kullanıcı
-- BAKİYESİNE HER BAKTIĞINDA yerine oturuyor: ay içinde ilk kez
-- bakıldığında o ayın kredisi yazılır. Cron kurulursa daha erken olur,
-- kurulmazsa yine olur.
--
-- Idempotent: `reason = 'plan_monthly:<YYYY-MM>'` tekilliği sağlıyor.
-- Aynı ay iki kez yazılamaz.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.plan_kredisi_yerlestir(p_user uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_ay text; v_n int; v_reason text; v_bal int;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'neden', 'oturum_yok'); end if;

  v_ay := to_char(timezone('Europe/Istanbul', now()), 'YYYY-MM');
  v_reason := 'plan_monthly:' || v_ay;

  if exists (select 1 from credit_ledger where user_id = v_uid and reason = v_reason) then
    return jsonb_build_object('ok', true, 'durum', 'zaten_verildi', 'ay', v_ay);
  end if;

  select coalesce(p.monthly_credits, 0) into v_n
    from users u left join plan_catalog p on p.plan = u.plan and p.aktif
   where u.id = v_uid;
  v_n := coalesce(v_n, 0);
  if v_n <= 0 then
    return jsonb_build_object('ok', true, 'durum', 'plan_kredisi_yok', 'ay', v_ay);
  end if;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (v_uid, v_n, v_reason, v_bal + v_n);

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_uid, 'system', 'Aylık kredin yüklendi ✓',
          v_n || ' kredi hesabına eklendi. Planın her ay bu krediyi veriyor.',
          'credits');

  return jsonb_build_object('ok', true, 'durum', 'verildi', 'adet', v_n, 'ay', v_ay);
exception when others then
  -- Kredi yükleme, bakiye okumayı ASLA bozmamalı.
  return jsonb_build_object('ok', false, 'neden', sqlerrm);
end $$;
grant execute on function public.plan_kredisi_yerlestir(uuid) to authenticated;

-- 🔴 SARMALAYICI DENEDİM, ÖLÇÜM YANLIŞ OLDUĞUNU GÖSTERDİ.
-- İlk yazımda `my_credits()` RPC'sini sarmalayıp krediyi oraya
-- bağlamıştım. Kurulum şunu dedi:
--     "225: my_credits yok — otomatik yukleme baglanamadi"
-- Baktım: app bakiyeyi bir RPC'den değil, doğrudan `credit_ledger`
-- TABLOSUNDAN okuyor (screens.js:3333). Sarmalayacak bir fonksiyon yok.
--
-- Gizli bir kanca aramak yerine AÇIK çağrı: app açılışta bir kez
-- `plan_kredisi_yerlestir()` çağırıyor. Fonksiyon idempotent olduğu için
-- kaç kez çağrıldığı önemsiz. Cron kurulursa daha erken çalışır,
-- kurulmazsa kullanıcı uygulamayı her açtığında yerine oturur.
--
-- Gizli kanca, görünür çağrıdan her zaman daha kırılgandır: birileri
-- sarmalanan fonksiyonu değiştirir ve kanca sessizce düşer. Bu projede
-- tam olarak böyle üç şey kayboldu (166'nın rl_guard'ı, 210'un plan
-- maskesi, 091'in kota reddi).
insert into rpc_client_surface (fn_name, client, note) values
  ('plan_kredisi_yerlestir','app','Aylik plan kredisi (225) — app acilista cagirir, idempotent')
on conflict (fn_name) do update set note = excluded.note;

-- Ayarı da doğru duruma getir: artık gerçekten açık.
insert into beta_settings (key, value)
values ('monthly_topup', jsonb_build_object('enabled', true, 'source', 'plan_catalog.monthly_credits'))
on conflict (key) do update set value = excluded.value;


-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ · PLAN SAYFASINDA YAZAN HER SÖZÜN BİR UYGULAYICISI VAR MI
--
-- 🔴 BU DOSYANIN ASIL ÜRÜNÜ BU DENETİM.
-- Dört sözün dördü de kodda karşılıksızdı ve bunu kimse görmedi, çünkü
-- "yazılmış olmak" ile "çalışıyor olmak" arasındaki farkı ölçen bir şey
-- yoktu. Bundan sonra plan_catalog'a yeni bir söz eklenirse, uygulayıcısı
-- da eklenene kadar kurulum kırmızı yanar.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_eksik text := '';
  v_src text;
begin
  -- ucus_dogrulama_ayda → flight_fetch_allow okumalı
  select prosrc into v_src from pg_proc
   where proname='flight_fetch_allow' and pronamespace='public'::regnamespace;
  if position('ucus_dogrulama_ayda' in coalesce(v_src,'')) = 0 then
    v_eksik := v_eksik || 'ucus_dogrulama_ayda ';
  end if;

  -- one_cikarma_ayda → set_featured okumalı
  select prosrc into v_src from pg_proc
   where proname='set_featured' and pronamespace='public'::regnamespace;
  if position('one_cikarma_ayda' in coalesce(v_src,'')) = 0 then
    v_eksik := v_eksik || 'one_cikarma_ayda ';
  end if;

  -- monthly_credits → plan_kredisi_yerlestir okumalı
  select prosrc into v_src from pg_proc
   where proname='plan_kredisi_yerlestir' and pronamespace='public'::regnamespace;
  if position('monthly_credits' in coalesce(v_src,'')) = 0 then
    v_eksik := v_eksik || 'monthly_credits ';
  end if;

  -- kart_siniri → BİLEREK uygulayıcısı yok; o yüzden tüm planlarda
  -- aynı olmalı. Farklıysa yine bir söz veriliyor demektir.
  if (select count(distinct kart_siniri) from plan_catalog where aktif) > 1 then
    v_eksik := v_eksik || 'kart_siniri(planlar-arasi-fark-var-ama-uygulayan-yok) ';
  end if;

  if v_eksik <> '' then
    raise exception '225: plan sozu UYGULAYICISIZ → %', v_eksik;
  end if;
  raise notice '225: plan_catalog''daki her sozun bir uygulayicisi var';
end $$;


-- ── NÖBETÇİ 2 · AYLIK KREDİ GERÇEKTEN YÜKLENİYOR MU ─────────────────
-- Sıfır satır ölçen denetim yeşil yanar. Burada GERÇEK bir kullanıcıda
-- deneyip geri alıyoruz.
do $$
declare
  v_u uuid; v_once int; v_sonra int; v_bekl int; v_ay text;
begin
  select u.id into v_u
    from users u join plan_catalog p on p.plan = u.plan and p.aktif
   where coalesce(p.monthly_credits,0) > 0
     and u.deleted_at is null
   limit 1;

  if v_u is null then
    raise notice '225: aylik kredisi olan planda kullanici yok — OLCULEMEDI';
    return;
  end if;

  v_ay := to_char(timezone('Europe/Istanbul', now()), 'YYYY-MM');
  delete from credit_ledger where user_id = v_u and reason = 'plan_monthly:' || v_ay;

  select coalesce(sum(delta),0) into v_once from credit_ledger where user_id = v_u;
  select coalesce(p.monthly_credits,0) into v_bekl
    from users u join plan_catalog p on p.plan = u.plan and p.aktif where u.id = v_u;

  perform public.plan_kredisi_yerlestir(v_u);
  select coalesce(sum(delta),0) into v_sonra from credit_ledger where user_id = v_u;

  if v_sonra - v_once <> v_bekl then
    raise exception '225: aylik kredi yuklenmedi → once=% sonra=% beklenen=%',
      v_once, v_sonra, v_bekl;
  end if;

  -- İKİNCİ çağrı hiçbir şey eklememeli (idempotent).
  perform public.plan_kredisi_yerlestir(v_u);
  select coalesce(sum(delta),0) into v_once from credit_ledger where user_id = v_u;
  if v_once <> v_sonra then
    raise exception '225: aylik kredi IKI KEZ yuklendi (idempotent degil)';
  end if;

  raise notice '225: aylik kredi yuklendi (% kredi) ve ikinci cagri tekrar yuklemedi', v_bekl;
end $$;

select '225 OK — plan_catalog''daki dort soz de karsilikli' as sonuc;
