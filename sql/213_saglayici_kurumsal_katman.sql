-- ============================================================
-- 213 · SAĞLAYICI KURUMSAL KATMAN — Ö5…Ö10
-- 17 Ağustos 2026
--
-- 209 sağlayıcı panelini AÇTI (Ö1–Ö4). Bu dosya, SAGLAYICI_MODULU.md
-- Ö5–Ö10'daki altı ekranın verisini üretir:
--
--   Ö5  venue_airport_share   · havalimanı içi pay (rakip ADI YOK)
--   Ö6  venue_no_show         · haftalık no-show / iptal / kalış
--   Ö7  venue_program_mix     · hangi kart programı arz getiriyor
--   Ö8  venue_price_position  · fiyat konumu (katalog, sıfır kişisel veri)
--   Ö9  venue_guest_profile   · amaç × tarz × olanak boşluğu
--   Ö10 venue_stay_pressure   · erken giriş / aşırı kalış baskısı
--
-- ⚠️ TASLAK SQL DOĞRULANMADAN KULLANILMADI. Ö5–Ö10'un belgedeki
-- sorguları BAŞLANGIÇ NOKTASIydı; her kolonu canlı şemada ölçtüm ve
-- üçü taslakta yazdığı gibi ÇALIŞMIYORDU:
--   · Ö7 `join lounge_programs p on p.id = a.program_id` — INNER join.
--     Ölçüm: `availabilities.program_id` 25/25 satırda NULL. Taslak
--     sorgu bu şemada HER ZAMAN boş döner. Çözüm: left join +
--     `pick_host_program()` ile türetme + türetmenin oranını RAPORLA.
--   · Ö8 `venue_prices` `venue_id` ile anahtarlı ama fonksiyonun
--     parametresi `lounge_id`. `lounges.venue_id` üzerinden çeviri şart.
--   · Ö10 `requests.visit_id` 1/1 satırda NULL — seyahat bağı doğrudan
--     kurulamıyor; (misafir, havalimanı, tarih) ile yedek eşleme var
--     ve bu YÖNTEM FARKI cevabın içinde söyleniyor.
--
-- BU DOSYANIN KURALI: bilmediğimizi saklamıyoruz. Altı fonksiyonun
-- HEPSİ kendi kapsamını (`kapsam_yuzde`, `beyan_orani_yuzde`,
-- `program_bilinmeyen_yuzde`) cevabın içinde döndürür ve
-- hesaplanamayan bir metrik `hesaplanabilir=false` + `neden` ile
-- açıkça reddedilir. Sıfırı sessizce göstermek, veri yokluğunu
-- başarısızlık gibi sunmaktır.
-- ============================================================


-- ============================================================
-- 0) ÖNCE ÖLÇTÜM: 212 SAĞLAYICI KAPISINI KIRMIŞ
-- ============================================================
-- 🔴 YENİ EKRAN YAZMADAN ÖNCE VAR OLANI ÇALIŞTIRDIM VE ŞUNU BULDUM:
-- sağlayıcı panelinin BEŞ fonksiyonu da bugün hata fırlatıyor.
--
-- ÖLÇÜM (canlı şema, bayrak KAPALI hâli):
--   venue_gate_report(...)  → 22P02 invalid input syntax for type uuid: "f"
--   partner_payout(...)     → 22P02 invalid input syntax for type uuid: "f"
--   (venue_lost_demand · venue_inbound_wave · venue_rule_compliance aynı)
--
-- SEBEP ZİNCİRİ:
--   209: `partner_gate(uuid,uuid) returns UUID` — yetkili kullanıcının
--        kimliğini döndürür, yetkisizde `raise 'not_partner'`.
--   212: kapıyı bayrağa bağlarken sarmalayıcıyı `returns BOOLEAN`
--        yazdı. 209'un beş fonksiyonu ise hâlâ
--        `v_uid := public.partner_gate(...)` diyor ve `v_uid` UUID.
--        boolean `false` → uuid çevrimi 22P02 verir.
--
-- İKİNCİ ÖLÇÜM — BAYRAĞI AÇINCA DA ÇALIŞMIYOR:
--   partner_gate(...) → 22P02 invalid input syntax for type boolean:
--                       "11110001-0000-4000-8000-000000000001"
--   çünkü sarmalayıcı `return public.partner_gate_preflag(...)` diyor
--   ve preflag UUID döndürüyor; boolean'a çevrilemiyor.
--
-- YANİ KAPI HER İKİ BAYRAK DURUMUNDA DA KIRIK. Kill switch'in "aç"
-- konumu hiç denenmemiş — bayrak tek yönlü bir tuzak olmuş.
--
-- NÖBETÇİLER NEDEN YAKALAMADI: 209'un nöbetçileri 209 çalışırken
-- geçti — 212 HENÜZ ÇALIŞMAMIŞTI. Bir dosyanın nöbetçisi yalnız o
-- ana kadarki dünyayı kanıtlar; SONRAKİ dosya onu bozarsa kimse
-- bakmaz. Bu, "yeşil migration ≠ çalışan ürün" sınıfının ta kendisi.
--
-- Bu dosya yeni ekran eklemeden ÖNCE kapıyı onarıyor. Onarmadan
-- eklemek, kırık bir temele altı kat çıkmak olurdu.
-- ============================================================


-- ------------------------------------------------------------
-- 0a) KAPININ KENDİSİ — 212'nin imzası korunuyor, gövdesi düzeliyor
-- ------------------------------------------------------------
-- 212'nin SÖZLEŞMESİ doğru: kapı bir BOOLEAN döndürmeli, çünkü
-- "bayrak kapalı" bir yetki hatası DEĞİL, bir ürün kararıdır ve
-- exception ile anlatılmamalı. Yanlış olan uygulamaydı.
--
-- İmza (partner_gate(uuid,uuid) → boolean) AYNEN korunuyor; yalnız
-- gövde `create or replace` ile düzeltiliyor. Hiçbir şey düşürülmüyor.
--
-- `not_partner` yakalanıp `false`'a çevriliyor — çağıran fonksiyonlar
-- "veri döndürme" kararını exception yerine bayrakla verebilsin diye.
-- ⚠️ AMA YALNIZ O: başka her hata olduğu gibi yukarı fırlar. Her
-- hatayı `false`'a çevirmek, kapıyı kapatırken hatayı da gizlemek olurdu.
-- 🔴 DÜZ `create or replace` YAZMADIM VE SEBEBİ ÖLÇÜLDÜ:
-- 209 dosyası `partner_gate`i UUID döner olarak tanımlıyor; 212 onu
-- ÇALIŞMA ZAMANINDA `partner_gate_preflag` diye yeniden adlandırıp
-- yerine BOOLEAN dönen bir sarmalayıcı koyuyor. Yani dosyaları statik
-- okuyan biri (bizim `returns_check.py` nöbetçimiz dâhil) "bu 42P13
-- verecek" der; veritabanının gerçeği ise farklıdır.
--
-- İki tarafı da doğru yapmanın yolu tahmin etmek değil, SORMAK:
-- aşağıdaki blok mevcut dönüş tipini `pg_proc`tan okur ve yalnız
-- BOOLEAN ise değiştirir. UUID görürse (yani 212 çalışmamışsa)
-- sessizce yanlış şey yapmak yerine AÇIK bir hata verir.
do $blok$
declare v_ret text;
begin
  select pg_get_function_result(p.oid) into v_ret
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'partner_gate'
   limit 1;

  if v_ret is null then
    raise exception '213: partner_gate YOK — 209 calismamis olabilir';
  end if;

  -- 🔴 BEKLENEN TİP `uuid` (209'un özgün sözleşmesi) ya da `boolean`
  -- (bu blok daha önce çalışmışsa). Başka bir şeyse durur.
  -- İlk yazımda burada `boolean` bekliyordum çünkü 212 gate'i
  -- sarmalıyordu; 212 o sarmalamayı KALDIRDI (çağırıcıları aynı dosyada
  -- düzeltmediği için hatalıydı) ve bu nöbetçi kırmızı yandı. Doğrusu:
  -- sözleşme değişimi ve çağırıcı onarımı AYNI dosyada, yani burada.
  if v_ret not in ('uuid', 'boolean') then
    raise exception '213: partner_gate donus tipi % — beklenmeyen; kapi onarimi bu hâlde YAPILAMAZ.', v_ret;
  end if;

  -- 209'un özgün hâli sarmalanmamışsa önce ADINI DEĞİŞTİR, sonra
  -- boolean sarmalayıcıyı üstüne koy. (212'nin yapmadığı ikinci yarı:
  -- çağırıcılar hemen aşağıdaki 0b bloğunda düzeltiliyor.)
  if v_ret = 'uuid' and not exists (select 1 from pg_proc where proname = 'partner_gate_preflag') then
    execute 'alter function public.partner_gate(uuid, uuid) rename to partner_gate_preflag';
    raise notice '213: 209 partner_gate → partner_gate_preflag (uuid sozlesmesi korundu)';
  end if;

  execute $ddl$
    create or replace function public.partner_gate(p_user uuid, p_lounge uuid)
    returns boolean language plpgsql stable security definer set search_path = public as $fn$
    declare v_acik boolean; v_uid uuid;
    begin
      select f.enabled into v_acik from feature_flags f where f.key = 'partner_channel';
      if not coalesce(v_acik, true) then
        return false;                       -- kill switch: kanal kapalı
      end if;
      begin
        v_uid := public.partner_gate_preflag(p_user, p_lounge);
      exception when others then
        if sqlerrm = 'not_partner' then
          return false;                     -- yetkisiz: veri yok, hata da yok
        end if;
        raise;                              -- başka her hata GÖRÜNÜR kalır
      end;
      return v_uid is not null;
    end $fn$;
  $ddl$;
  raise notice '213: partner_gate govdesi onarildi (bayrak ACIK iken de calisiyor)';
end $blok$;


-- ------------------------------------------------------------
-- 0b) 209'UN BEŞ ÇAĞIRICISI — kaynak üzerinden ONARIM
-- ------------------------------------------------------------
-- 🔴 NEDEN GÖVDELERİ BU DOSYAYA KOPYALAMIYORUM: beş fonksiyonun
-- toplam ~220 satırlık iş mantığını 213'e kopyalasaydım, 209 ile 213
-- iki ayrı gerçek taşımaya başlardı ve bir sonraki düzeltme birinde
-- yapılıp diğerinde unutulurdu. Aynı veriyi iki dosyanın iki farklı
-- yolla taşıması, er ya da geç ikisinin ayrışması demektir (bu dersi
-- `app/partner/actions.js` zaten yazmış).
--
-- Bunun yerine tek satırlık çağrı kalıbı, `pg_get_functiondef` ile
-- okunan GERÇEK gövde üzerinde değiştiriliyor. Yama körlemesine
-- değil: kalıp bulunamazsa DO bloğu EXCEPTION fırlatır. Sessizce
-- hiçbir şey yapmayan bir onarım, onarım değildir — yeşil yanan bir
-- yalandır.
do $$
declare
  v_hedef text[] := array['partner_payout','venue_gate_report','venue_lost_demand',
                          'venue_inbound_wave','venue_rule_compliance'];
  v_ad    text;
  v_def   text;
  v_yeni  text;
  v_ret   text;
  v_eski  constant text := 'v_uid := public.partner_gate(p_user, p_lounge_id);';
  v_yama  constant text :=
    'if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then '
 || 'return jsonb_build_object(''known'', false, ''yetki'', false, ''satirlar'', ''[]''::jsonb, '
 || '''not'', ''Bu salon icin yetkiniz yok ya da partner_channel bayragi kapali.''); end if; '
 || 'v_uid := coalesce(p_user, auth.uid());';
  v_sayac int := 0;
begin
  foreach v_ad in array v_hedef loop
    select pg_get_functiondef(p.oid), pg_get_function_result(p.oid)
      into v_def, v_ret
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = v_ad
     limit 1;

    if v_def is null then
      raise exception '213: onarilacak fonksiyon YOK → %', v_ad;
    end if;

    -- Yama yalnız jsonb dönen fonksiyonlara uygulanabilir; başka bir
    -- dönüş tipi varsa `return jsonb_build_object(...)` derlenmez.
    if v_ret <> 'jsonb' then
      raise exception '213: % jsonb DEGIL (%) — yama gecersiz', v_ad, v_ret;
    end if;

    if position(v_yama in v_def) > 0 then
      raise notice '213: % zaten onarilmis — atlandi', v_ad;
      continue;
    end if;

    if position(v_eski in v_def) = 0 then
      raise exception '213: % icinde beklenen kapi cagrisi BULUNAMADI — kalip degismis olabilir; yama korlemesine uygulanmayacak.', v_ad;
    end if;

    v_yeni := replace(v_def, v_eski, v_yama);
    execute v_yeni;
    v_sayac := v_sayac + 1;
  end loop;
  raise notice '213: 209 kapi cagrisi % fonksiyonda onarildi', v_sayac;
end $$;


-- ------------------------------------------------------------
-- 0c) BAYRAK — 212'nin BEYAN ETTİĞİ değere getiriliyor
-- ------------------------------------------------------------
-- 🔴 ÜÇÜNCÜ ÖLÇÜM: `feature_flags.partner_channel.enabled = false`.
-- Oysa 212 satır 48 açıkça `('partner_channel', true, 100, ...)` yazıyor.
-- Değer uygulanmadı çünkü aynı ifadenin `on conflict do update set`
-- listesi yalnız `description, surface, is_kill_switch` güncelliyor —
-- `enabled` YOK. Bayrağı 029 satır 108'de yazılan `false` değeri
-- kazandı ve 212 "açtım" sanıp geçti.
--
-- YENİ HATA SINIFI: `on conflict do update` KOLON LİSTESİ, INSERT'in
-- değer listesinden EKSİK olduğunda, dosya niyetini beyan eder ama
-- uygulamaz. Beyan ile durum sessizce ayrışır.
--
-- Burada YENİ bir ürün kararı vermiyorum; 212'nin yazılı kararını
-- uyguluyorum. Geri almak tek satır:
--   update feature_flags set enabled = false where key = 'partner_channel';
update feature_flags set enabled = true, updated_at = now()
 where key = 'partner_channel' and enabled is distinct from true;


-- ============================================================
-- Ö5 · HAVALİMANI İÇİ PAY — "talebin yüzde kaçı bana geldi?"
-- ============================================================
-- Mutlak sayı ("42 talep") bağlamsızdır; PAY rekabetçi bir sayıdır.
-- Rakip salonların ADI VERİLMEZ — ne hukuken ne ticari olarak doğru.
--
-- ⚠️ İKİ AYRI EŞİK VAR VE İKİSİ DE GEREKLİ:
--   1) k-anonimite (`partner_k()`): karşılaştırma kümesine giren HER
--      salon en az k FARKLI misafir taşımalı. Kendi salonum da dâhil —
--      k, benim misafirlerimi de korur.
--   2) rakip gizliliği (v_rakip_esigi = 3): kümede yalnız 2 salon
--      varsa "en yüksek pay" doğrudan TEK bir rakibin sayısıdır. Adı
--      vermemek yetmez; sayıyı tekilleştirmemek de gerekir. 3'ün
--      altında medyan/maksimum YAYIMLANMAZ.
create or replace function public.venue_airport_share(
  p_lounge_id uuid, p_user uuid default null, p_gun int default 90)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_k int := public.partner_k();
  v_rakip_esigi constant int := 3;
  v_ap text;
  v_salon int; v_toplam numeric;
  v_benim_talep numeric; v_benim_pay numeric; v_benim_kabul_pay numeric;
  v_medyan numeric; v_max numeric;
  v_ham_salon int; v_ham_talep bigint;
begin
  -- KAPI: yetki yoksa VERİ DEĞİL, boş cevap.
  if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then
    return jsonb_build_object('known', false, 'yetki', false, 'hesaplanabilir', false,
      'neden', 'Bu salon için yetkiniz yok ya da partner_channel bayrağı kapalı.');
  end if;

  select l.airport_code into v_ap from lounges l where l.id = p_lounge_id;
  if v_ap is null then
    return jsonb_build_object('known', false, 'yetki', true, 'hesaplanabilir', false,
      'neden', 'Salonun havalimanı kodu yok.');
  end if;

  -- HAM sayılar: eşik ÖNCESİ. Kapsamı söyleyebilmek için gerekli —
  -- "3 salondan 0'ı eşiği geçti" ile "hiç veri yok" aynı şey değil.
  select count(distinct a.lounge_id), count(*)
    into v_ham_salon, v_ham_talep
    from requests r
    join availabilities a on a.id = r.avail_id
    join users u on u.id = r.guest_id
   where a.airport_code = v_ap
     and r.created_at >= now() - make_interval(days => p_gun)
     and coalesce(u.is_staff, false) = false
     and u.deleted_at is null;

  with t as (
    select a.lounge_id,
           count(*)::numeric as talep,
           count(*) filter (where r.status in ('accepted','completed'))::numeric as kabul
      from requests r
      join availabilities a on a.id = r.avail_id
      join users u on u.id = r.guest_id
     where a.airport_code = v_ap
       and r.created_at >= now() - make_interval(days => p_gun)
       and coalesce(u.is_staff, false) = false
       and u.deleted_at is null
     group by a.lounge_id
    having count(distinct r.guest_id) >= v_k     -- k-anonimite, SALON düzeyinde
  ), pay as (
    select lounge_id, talep, kabul,
           talep * 100 / nullif(sum(talep) over (), 0) as pay,
           kabul * 100 / nullif(sum(kabul) over (), 0) as kabul_pay
      from t
  )
  select (select count(*)::int from pay),
         (select sum(talep) from pay),
         (select talep from pay where lounge_id = p_lounge_id),
         (select round(pay, 1) from pay where lounge_id = p_lounge_id),
         (select round(kabul_pay, 1) from pay where lounge_id = p_lounge_id),
         (select round((percentile_cont(0.5) within group (order by pay::float8))::numeric, 1) from pay),
         (select round(max(pay), 1) from pay)
    into v_salon, v_toplam, v_benim_talep, v_benim_pay, v_benim_kabul_pay, v_medyan, v_max;

  return jsonb_build_object(
    'known', true, 'yetki', true,
    'havalimani', v_ap, 'gun', p_gun,
    'k_esigi', v_k, 'rakip_esigi', v_rakip_esigi,
    'ham_salon', coalesce(v_ham_salon, 0),
    'ham_talep', coalesce(v_ham_talep, 0),
    'karsilastirilan_salon', coalesce(v_salon, 0),
    'esik_ustu_talep', coalesce(v_toplam, 0),
    'benim_talebim', v_benim_talep,
    'benim_payim_yuzde', v_benim_pay,
    'benim_kabul_payim_yuzde', v_benim_kabul_pay,
    'benim_esik_altinda', v_benim_pay is null,
    -- Rakip eşiği altında medyan/maksimum GİZLENİR.
    'havalimani_medyan_pay_yuzde', case when coalesce(v_salon,0) >= v_rakip_esigi then v_medyan end,
    'en_yuksek_pay_yuzde',         case when coalesce(v_salon,0) >= v_rakip_esigi then v_max end,
    'hesaplanabilir', v_benim_pay is not null,
    'neden', case
      when coalesce(v_ham_talep,0) = 0
        then format('Son %s günde %s havalimanında hiç talep kaydı yok.', p_gun, v_ap)
      when v_benim_pay is null
        then format('Bu salon son %s günde %s farklı misafir eşiğini geçemedi; kendi payınız da gizlendi (k=%s). Havalimanında eşik öncesi %s talep, %s salon var.',
                    p_gun, v_k, v_k, v_ham_talep, v_ham_salon)
      when coalesce(v_salon,0) < v_rakip_esigi
        then format('Payınız hesaplandı ama karşılaştırma kümesinde yalnız %s salon var; medyan/en yüksek gizlendi (tek rakibin sayısını ifşa ederdi, eşik %s).',
                    v_salon, v_rakip_esigi)
      end,
    'not', 'Rakip salonların adı hiçbir koşulda paylaşılmaz; yalnız pay dağılımı verilir.');
end $fn$;


-- ============================================================
-- Ö6 · NO-SHOW, İPTAL VE BOŞA GİDEN SLOT
-- ============================================================
-- Salon için boşa giden slot kaybedilen kapasitedir. `cancel_reason`
-- ve `no_show_user_id` (080) zaten yazılıyor; yeni veri gerekmiyor.
--
-- ⚠️ İKİ NO-SHOW SİNYALİ VAR ve ikisi de sayılıyor: `cancel_reason`
-- serbest metin bir kolon, `no_show_user_id` yapısal. Yalnız birine
-- bakmak, diğer yoldan yazılan kayıtları sessizce düşürürdü.
create or replace function public.venue_no_show(
  p_lounge_id uuid, p_user uuid default null, p_from date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_k int := public.partner_k();
  v_from date;
  v_satir jsonb;
  v_ham int; v_gosterilen int;
begin
  if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then
    return jsonb_build_object('known', false, 'yetki', false, 'haftalar', '[]'::jsonb,
      'hesaplanabilir', false,
      'neden', 'Bu salon için yetkiniz yok ya da partner_channel bayrağı kapalı.');
  end if;

  v_from := coalesce(p_from, current_date - 90);

  select count(*) into v_ham
    from sessions s
    join requests r on r.id = s.request_id
    join availabilities a on a.id = r.avail_id
    join users u on u.id = r.guest_id
   where a.lounge_id = p_lounge_id
     and s.started_at >= v_from
     and coalesce(u.is_staff, false) = false
     and u.deleted_at is null;

  select jsonb_agg(x order by x ->> 'hafta'), coalesce(sum((x ->> 'oturum')::int), 0)::int
    into v_satir, v_gosterilen
  from (
    select jsonb_build_object(
             'hafta',       date_trunc('week', s.started_at)::date,
             'oturum',      count(*)::int,
             'kisi',        count(distinct r.guest_id)::int,
             'tamamlanan',  count(*) filter (where s.status = 'completed')::int,
             'no_show',     count(*) filter (where s.cancel_reason = 'no_show'
                                                or s.no_show_user_id is not null)::int,
             'iptal',       count(*) filter (where s.status = 'cancelled'
                                               and coalesce(s.cancel_reason, '') <> 'no_show'
                                               and s.no_show_user_id is null)::int,
             -- 🔴 `avg(...) filter (...)::numeric` YAZMADIM: FILTER'dan
             -- sonra gelen cast sözdizimi tartışmalı ve okuyanı yanıltır.
             -- Süzmeyi CASE ile ifade etmek hem çalışır hem açıktır.
             'ort_kalis_saat', round(avg(case when s.completed_at is not null
                                    then extract(epoch from (s.completed_at - s.started_at)) / 3600.0
                                  end)::numeric, 1)
           ) as x
      from sessions s
      join requests r on r.id = s.request_id
      join availabilities a on a.id = r.avail_id
      join users u on u.id = r.guest_id
     where a.lounge_id = p_lounge_id
       and s.started_at >= v_from
       and coalesce(u.is_staff, false) = false
       and u.deleted_at is null
     group by date_trunc('week', s.started_at)
    having count(distinct r.guest_id) >= v_k      -- k-anonimite, HAFTA düzeyinde
  ) q;

  return jsonb_build_object(
    'known', true, 'yetki', true,
    'baslangic', v_from, 'k_esigi', v_k,
    'haftalar', coalesce(v_satir, '[]'::jsonb),
    'ham_oturum', coalesce(v_ham, 0),
    'gosterilen_oturum', coalesce(v_gosterilen, 0),
    'gizlenen_oturum', coalesce(v_ham, 0) - coalesce(v_gosterilen, 0),
    -- KAPSAM: eşikten geçen oturum / toplam oturum. Bu sayı olmadan
    -- tablo "salonun tamamı" sanılır.
    'kapsam_yuzde', case when coalesce(v_ham, 0) = 0 then null
                    else round(coalesce(v_gosterilen, 0)::numeric * 100 / v_ham, 1) end,
    'hesaplanabilir', v_satir is not null,
    'neden', case
      when coalesce(v_ham, 0) = 0
        then format('%s tarihinden bu yana bu salonda hiç oturum kaydı yok.', v_from)
      when v_satir is null
        then format('%s oturum var ama hiçbir hafta %s farklı misafir eşiğini geçmedi; tamamı gizlendi.', v_ham, v_k)
      end,
    'not', 'Ortalama kalış = completed_at − started_at. Yalnız tamamlanan oturumlarda hesaplanır; iptal ve no-show ortalamaya girmez.');
end $fn$;


-- ============================================================
-- Ö7 · KART PROGRAMI KARMASI — hangi sözleşme trafik getiriyor?
-- ============================================================
-- 🔴 TASLAK SORGU BU ŞEMADA ÇALIŞMAZDI VE ÖLÇTÜM:
--     select count(*) from availabilities where program_id is null → 25/25
-- Yani `join lounge_programs p on p.id = a.program_id` (inner join)
-- HER ZAMAN sıfır satır döndürürdü. Ekran boş görünür, kimse sebebini
-- bilmezdi — en pahalı hata sınıfı: inandırıcı yanlış cevap.
--
-- ÇÖZÜM VE BEDELİ: program `pick_host_program(host, venue)` ile
-- host'un hak beyanından TÜRETİLİYOR (151'in belirli seçicisi).
-- Türetme bir tahmindir; bu yüzden cevap üç oranı BİRDEN taşır:
--   dogrudan_beyan_yuzde  — ilanın kendi `program_id`'si (ölçüm: %0)
--   turetilen_yuzde       — host hakkından türetildi
--   program_bilinmeyen_yuzde — hiçbiri; "program bilinmeyen: %N" satırı
-- Sözleşme yenileme toplantısına giren kişi, sayının ne kadarının
-- beyan ne kadarının çıkarım olduğunu BİLMEK zorundadır.
create or replace function public.venue_program_mix(
  p_lounge_id uuid, p_user uuid default null, p_from date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_k int := public.partner_k();
  v_from date;
  v_ven uuid;
  v_ilan int; v_host int; v_dogrudan int; v_turetilen int; v_bilinmeyen int;
  v_satir jsonb; v_gosterilen int;
  v_bilinmeyen_yuzde numeric;
begin
  if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then
    return jsonb_build_object('known', false, 'yetki', false, 'satirlar', '[]'::jsonb,
      'hesaplanabilir', false,
      'bilinmeyen_satiri', 'program bilinmeyen: ölçülemedi (yetki yok)',
      'neden', 'Bu salon için yetkiniz yok ya da partner_channel bayrağı kapalı.');
  end if;

  v_from := coalesce(p_from, current_date - 180);
  select l.venue_id into v_ven from lounges l where l.id = p_lounge_id;

  select count(*)::int,
         count(distinct a.host_id)::int,
         count(*) filter (where a.program_id is not null)::int,
         count(*) filter (where a.program_id is null
                            and public.pick_host_program(a.host_id, v_ven) is not null)::int,
         count(*) filter (where coalesce(a.program_id,
                                public.pick_host_program(a.host_id, v_ven)) is null)::int
    into v_ilan, v_host, v_dogrudan, v_turetilen, v_bilinmeyen
    from availabilities a
   where a.lounge_id = p_lounge_id
     and a.avail_date >= v_from;

  -- 🔴 BÜTÜN RAPOR k EŞİĞİNE TABİ. Salonun tamamı k'dan az host
  -- taşıyorsa "program bilinmeyen: %100" bile tek bir kişinin hak
  -- beyanını ifşa eder. Bilmediğimizi söylemek, birini ifşa etme
  -- pahasına yapılmaz — o zaman ÖLÇEMEDİĞİMİZİ söyleriz.
  if coalesce(v_host, 0) < v_k then
    return jsonb_build_object(
      'known', true, 'yetki', true, 'satirlar', '[]'::jsonb,
      'baslangic', v_from, 'k_esigi', v_k,
      'toplam_host', coalesce(v_host, 0),
      'hesaplanabilir', false,
      'bilinmeyen_satiri', format('program bilinmeyen: ölçülemedi (salonda %s host var, eşik %s)',
                                  coalesce(v_host, 0), v_k),
      'neden', format('Bu salonda %s tarihinden bu yana %s farklı host ilan açmış; k-anonimite eşiği %s. Oran bile yayımlanmıyor.',
                      v_from, coalesce(v_host, 0), v_k),
      'not', 'Eşik `beta_settings.partner_k_threshold` ile yönetilir.');
  end if;

  v_bilinmeyen_yuzde := round(coalesce(v_bilinmeyen, 0)::numeric * 100 / nullif(v_ilan, 0), 1);

  select jsonb_agg(x order by (x ->> 'dolan_slot')::int desc,
                              (x ->> 'ilan')::int desc,
                              x ->> 'program'),
         coalesce(sum((x ->> 'ilan')::int), 0)::int
    into v_satir, v_gosterilen
  from (
    select jsonb_build_object(
             'program',      coalesce(p.name, 'Program bilinmiyor'),
             'program_kodu', coalesce(p.code, '—'),
             'bilinmiyor',   p.id is null,
             'host_sayisi',  count(distinct a.host_id)::int,
             'ilan',         count(*)::int,
             'toplam_slot',  coalesce(sum(a.slots), 0)::int,
             'dolan_slot',   coalesce(sum(a.filled), 0)::int,
             'ilan_payi_yuzde', round(count(*)::numeric * 100 / nullif(v_ilan, 0), 1)
           ) as x
      from availabilities a
      left join lounge_programs p
             on p.id = coalesce(a.program_id, public.pick_host_program(a.host_id, v_ven))
     where a.lounge_id = p_lounge_id
       and a.avail_date >= v_from
     group by p.id, p.name, p.code
    having count(distinct a.host_id) >= v_k     -- k-anonimite, PROGRAM düzeyinde
  ) q;

  return jsonb_build_object(
    'known', true, 'yetki', true,
    'baslangic', v_from, 'k_esigi', v_k,
    'toplam_ilan', coalesce(v_ilan, 0),
    'toplam_host', coalesce(v_host, 0),
    'dogrudan_beyan', coalesce(v_dogrudan, 0),
    'turetilen', coalesce(v_turetilen, 0),
    'program_bilinmeyen', coalesce(v_bilinmeyen, 0),
    'dogrudan_beyan_yuzde', round(coalesce(v_dogrudan, 0)::numeric * 100 / nullif(v_ilan, 0), 1),
    'turetilen_yuzde',      round(coalesce(v_turetilen, 0)::numeric * 100 / nullif(v_ilan, 0), 1),
    'program_bilinmeyen_yuzde', v_bilinmeyen_yuzde,
    -- Şartname gereği HER ZAMAN görünen satır: ekran bu metni olduğu
    -- gibi basar, yorumlamaz.
    'bilinmeyen_satiri', format('program bilinmeyen: %%%s', coalesce(v_bilinmeyen_yuzde, 0)),
    'satirlar', coalesce(v_satir, '[]'::jsonb),
    'gosterilen_ilan', coalesce(v_gosterilen, 0),
    'gizlenen_ilan', coalesce(v_ilan, 0) - coalesce(v_gosterilen, 0),
    'kapsam_yuzde', round(coalesce(v_gosterilen, 0)::numeric * 100 / nullif(v_ilan, 0), 1),
    'hesaplanabilir', v_satir is not null,
    'neden', case when v_satir is null
      then format('%s ilan var ama hiçbir program %s farklı host eşiğini geçmedi.', v_ilan, v_k) end,
    'not', format('İlanların %%%s''i kendi program kaydını taşımıyor; program host hak beyanından türetildi. Türetim bir çıkarımdır, beyan değildir.',
                  round(coalesce(v_turetilen, 0)::numeric * 100 / nullif(v_ilan, 0), 1)));
end $fn$;


-- ============================================================
-- Ö8 · FİYAT KONUMLANDIRMA — sıfır kişisel veri, sıfır KVKK riski
-- ============================================================
-- ⚠️ k-ANONİMİTE MUAFİYETİ VE GEREKÇESİ: bu fonksiyonun okuduğu
-- `venue_prices` tamamen KATALOG verisidir — satırları salonlar
-- üretir, kullanıcılar değil. Ortada korunacak bir kişi yoktur, bu
-- yüzden `partner_k()` UYGULANMAZ. Muafiyet kapsam dışı bir istisna
-- değil, verinin türünden gelen bir sonuçtur; başka hiçbir sağlayıcı
-- fonksiyonuna genişletilemez.
--
-- Buna karşılık katalog verisinin KENDİ belirsizliği var ve o
-- söyleniyor: her satır `kaynak_url` + `kontrol_tarihi` taşır. Kaynağı
-- ve tarihi olmayan bir fiyat karşılaştırması, fiyat kararı için
-- kullanılamaz.
create or replace function public.venue_price_position(
  p_lounge_id uuid, p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ven uuid; v_ap text; v_kind text;
  v_satir jsonb; v_rakip int; v_benim int;
begin
  if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then
    return jsonb_build_object('known', false, 'yetki', false, 'satirlar', '[]'::jsonb,
      'hesaplanabilir', false,
      'neden', 'Bu salon için yetkiniz yok ya da partner_channel bayrağı kapalı.');
  end if;

  select l.venue_id into v_ven from lounges l where l.id = p_lounge_id;
  if v_ven is null then
    return jsonb_build_object('known', false, 'yetki', true, 'satirlar', '[]'::jsonb,
      'hesaplanabilir', false,
      'neden', 'Salon bir venue kaydına bağlı değil; fiyat kataloğu venue üzerinden tutuluyor.');
  end if;
  select v.airport_code, v.venue_kind into v_ap, v_kind from lounge_venues v where v.id = v_ven;

  -- Karşılaştırma kümesi: AYNI havalimanı + AYNI venue_kind.
  -- Bir "sleep" odasıyla bir "lounge" girişini karşılaştırmak sayı
  -- üretir ama anlam üretmez.
  select jsonb_agg(to_jsonb(w) order by w.kalem),
         count(*) filter (where w.benim_fiyatim is not null)::int
    into v_satir, v_benim
  from (
    select z.*,
           round((z.benim_fiyatim - z.medyan) * 100 / nullif(z.medyan, 0), 1) as fark_yuzde
      from (
        select vp.item_name                      as kalem,
               vp.item_code                      as kalem_kodu,
               coalesce(vp.unit, '—')            as birim,
               vp.currency                       as para,
               count(distinct vp.venue_id)::int  as salon_sayisi,
               round((percentile_cont(0.5) within group (order by vp.price::float8))::numeric, 2) as medyan,
               min(vp.price)                     as en_dusuk,
               max(vp.price)                     as en_yuksek,
               max(vp.price)      filter (where vp.venue_id = v_ven) as benim_fiyatim,
               max(vp.source_url) filter (where vp.venue_id = v_ven) as kaynak_url,
               max(vp.checked_at) filter (where vp.venue_id = v_ven) as kontrol_tarihi,
               min(vp.checked_at)                as kume_en_eski_kontrol,
               max(vp.checked_at)                as kume_en_yeni_kontrol
          from venue_prices vp
          join lounge_venues v on v.id = vp.venue_id
         where vp.active
           and coalesce(v.active, true)
           and v.airport_code = v_ap
           and coalesce(v.venue_kind, '') = coalesce(v_kind, '')
         group by vp.item_code, vp.item_name, vp.unit, vp.currency
      ) z
  ) w;

  select count(distinct vp.venue_id)::int into v_rakip
    from venue_prices vp
    join lounge_venues v on v.id = vp.venue_id
   where vp.active and coalesce(v.active, true)
     and v.airport_code = v_ap
     and coalesce(v.venue_kind, '') = coalesce(v_kind, '')
     and vp.venue_id <> v_ven;

  return jsonb_build_object(
    'known', true, 'yetki', true,
    'havalimani', v_ap, 'venue_kind', coalesce(v_kind, '—'),
    'k_muaf', true,
    'k_muaf_neden', 'Bu ekran yalnız katalog verisi okur (venue_prices). Hiçbir kullanıcı kaydına dokunmaz, bu yüzden k-anonimite eşiği uygulanmaz.',
    'satirlar', coalesce(v_satir, '[]'::jsonb),
    'kendi_fiyati_olan_kalem', coalesce(v_benim, 0),
    'karsilastirilabilir_salon', coalesce(v_rakip, 0),
    'karsilastirilabilir', coalesce(v_rakip, 0) > 0,
    'hesaplanabilir', v_satir is not null,
    'neden', case
      when v_satir is null
        then format('%s havalimanında "%s" türünde hiç fiyat kaydı yok; venue_prices bu salon çevresinde boş.',
                    v_ap, coalesce(v_kind, '—'))
      when coalesce(v_rakip, 0) = 0
        then format('%s havalimanında "%s" türünde fiyat kaydı olan başka salon yok; medyan/en düşük/en yüksek yalnız KENDİ fiyatınızdan geliyor, karşılaştırma değildir.',
                    v_ap, coalesce(v_kind, '—'))
      when coalesce(v_benim, 0) = 0
        then 'Karşılaştırma kümesi var ama bu salonun kendi fiyat kaydı yok; "benim fiyatım" sütunu boş.'
      end,
    'not', 'Her satır kaynak bağlantısı ve kontrol tarihi taşır. Kontrol tarihi eskiyse sayı değil, tarih konuşur.');
end $fn$;


-- ============================================================
-- Ö9 · MİSAFİR PROFİLİ — amaç × tarz × olanak boşluğu
-- ============================================================
-- 🔴 İKİ KOLON DA İSTEĞE BAĞLI (132: "ZORUNLU DEGIL. Bos birakan
-- kullanici cezalandirilmaz"). Bu yüzden rapor BEYAN ORANI olmadan
-- yayımlanmaz: %8'i beyan etmiş bir kümede "%46 iş amaçlı" cümlesi
-- doğru görünen ama yanlış bir cümledir.
--
-- ⚠️ OLANAK EŞLEŞTİRMESİ UYDURULMADI. `lounge_venues.amenities`
-- anahtarlarını şemadan saydım: food, wifi, extra, work, bar, kids,
-- buffet, games, shower, prayer, sleep, cinema, tv, terrace, nursery,
-- luggage. Belgedeki `quiet_zone` KATALOGDA YOK. Bu yüzden 'zen' ve
-- 'explorer' talepleri için karşılık NULL bırakıldı ve ekrana
-- "ölçülemiyor + sebep" olarak çıkıyor. Var olmayan bir anahtara
-- eşleştirip "boşluk var" demek, uydurmanın en sinsi hâliydi.
create or replace function public.venue_guest_profile(
  p_lounge_id uuid, p_user uuid default null, p_gun int default 180)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_k int := public.partner_k();
  v_ap text; v_ola jsonb;
  v_misafir int; v_amac_beyan int; v_tarz_beyan int;
  v_beyan jsonb;
  v_amac jsonb; v_tarz jsonb; v_bosluk jsonb;
  -- Talep → katalog olanak anahtarı. NULL = katalogda karşılığı YOK.
  -- ⚠️ `null::text` yazmak zorunlu: `jsonb_build_object` variadic "any"
  -- alır ve çıplak NULL'da tipi çözemeyip 42P18 verir.
  v_harita constant jsonb := jsonb_build_object(
    'business',  'work',
    'conference','work',
    'leisure',   'food',
    'connecting','shower',
    'event',     'bar',
    'social',    'bar',
    'foodie',    'buffet',
    'zen',       null::text,      -- 'quiet_zone' katalogda yok
    'explorer',  null::text       -- karşılığı olan anahtar yok
  );
begin
  if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then
    return jsonb_build_object('known', false, 'yetki', false,
      'amac_satirlari', '[]'::jsonb, 'tarz_satirlari', '[]'::jsonb, 'olanak_bosluklari', '[]'::jsonb,
      'hesaplanabilir', false,
      'neden', 'Bu salon için yetkiniz yok ya da partner_channel bayrağı kapalı.');
  end if;

  select l.airport_code into v_ap from lounges l where l.id = p_lounge_id;
  v_ola := public.venue_amenities(p_lounge_id);

  -- Misafir kümesi: BU salonda tamamlanmış oturumu olan kişiler.
  -- Havalimanı geneli değil — "salonuna gelen misafir" sorusu bu.
  --
  -- 🔴 GEÇİCİ TABLO KULLANILAMAZ VE SEBEBİ ÖNEMLİ: bu fonksiyon
  -- `stable`. PostgreSQL, volatile olmayan bir fonksiyon içinde yazma
  -- işlemine izin vermez (`INSERT is not allowed in a non-volatile
  -- function`). Fonksiyonu `volatile` yapmak derdi çözerdi ama YANLIŞ
  -- çözüm olurdu: bu bir RAPOR, veri yazmıyor ve planlayıcıya öyle
  -- söylenmeli. Doğru çözüm ara sonucu jsonb'de taşımak.
  --
  -- Ayrıca 209'un öğrettiği "42P01 temp table" sınıfı da böylece hiç
  -- doğmuyor: olmayan tablo bozulamaz.
  select jsonb_agg(jsonb_build_object('amac', z.amac, 'tarz', z.tarz))
    into v_beyan
  from (
    select m.uid,
           -- Amaç: seyahatin `purpose` alanı. Oturuma bağlı seyahat
           -- kaydı yoksa (ölçüm: requests.visit_id 1/1 NULL) kişinin bu
           -- havalimanındaki en yakın tarihli beyanı alınır. Bu bir
           -- YEDEK eşlemedir ve cevabın notunda söylenir.
           (select v.purpose from visits v
             where v.user_id = m.uid
               and v.airport_code = v_ap
               and v.visit_date >= current_date - p_gun
               and v.purpose is not null
             order by v.visit_date desc, v.id
             limit 1) as amac,
           (select pr.travel_style from profiles pr
             where pr.user_id = m.uid and pr.travel_style is not null) as tarz
      from (
        select distinct r.guest_id as uid
          from sessions s
          join requests r on r.id = s.request_id
          join availabilities a on a.id = r.avail_id
          join users u on u.id = r.guest_id
         where a.lounge_id = p_lounge_id
           and s.started_at >= now() - make_interval(days => p_gun)
           and s.status = 'completed'
           and coalesce(u.is_staff, false) = false
           and u.deleted_at is null
      ) m
  ) z;

  v_misafir := coalesce(jsonb_array_length(v_beyan), 0);

  if coalesce(v_misafir, 0) < v_k then
    return jsonb_build_object(
      'known', true, 'yetki', true, 'gun', p_gun, 'k_esigi', v_k,
      'misafir_sayisi', coalesce(v_misafir, 0),
      'amac_satirlari', '[]'::jsonb, 'tarz_satirlari', '[]'::jsonb,
      'olanak_bosluklari', '[]'::jsonb, 'olanaklar', coalesce(v_ola, '{}'::jsonb),
      'amac_beyan_orani_yuzde', null, 'tarz_beyan_orani_yuzde', null,
      'hesaplanabilir', false,
      'neden', format('Son %s günde bu salonda tamamlanmış oturumu olan %s misafir var; k-anonimite eşiği %s. Hiçbir kırılım yayımlanmıyor.',
                      p_gun, coalesce(v_misafir, 0), v_k),
      'not', 'Beyan oranı da gizlendi: küçük kümede "kaç kişi beyan etti" sayısı da kişiyi işaret eder.');
  end if;

  select count(*) filter (where e ->> 'amac' is not null)::int,
         count(*) filter (where e ->> 'tarz' is not null)::int
    into v_amac_beyan, v_tarz_beyan
    from jsonb_array_elements(coalesce(v_beyan, '[]'::jsonb)) e;

  select jsonb_agg(x order by (x ->> 'kisi')::int desc, x ->> 'deger') into v_amac
    from (select jsonb_build_object('deger', e ->> 'amac', 'kisi', count(*)::int,
                 'beyan_edenin_yuzdesi', round(count(*)::numeric * 100 / nullif(v_amac_beyan, 0), 1)) as x
            from jsonb_array_elements(coalesce(v_beyan, '[]'::jsonb)) e
           where e ->> 'amac' is not null
           group by e ->> 'amac' having count(*) >= v_k) q;   -- k-anonimite, SATIR düzeyinde

  select jsonb_agg(x order by (x ->> 'kisi')::int desc, x ->> 'deger') into v_tarz
    from (select jsonb_build_object('deger', e ->> 'tarz', 'kisi', count(*)::int,
                 'beyan_edenin_yuzdesi', round(count(*)::numeric * 100 / nullif(v_tarz_beyan, 0), 1)) as x
            from jsonb_array_elements(coalesce(v_beyan, '[]'::jsonb)) e
           where e ->> 'tarz' is not null
           group by e ->> 'tarz' having count(*) >= v_k) q;

  -- OLANAK BOŞLUĞU: yalnız eşiği geçen taleplerde ve yalnız katalogda
  -- karşılığı OLAN anahtarlarda ölçülür.
  select jsonb_agg(x order by (x ->> 'kisi')::int desc, x ->> 'talep') into v_bosluk
    from (
      select jsonb_build_object(
               'talep', t.deger,
               'kaynak', t.kaynak,
               'kisi', t.kisi,
               'olanak_anahtari', v_harita ->> t.deger,
               'olculebilir', (v_harita ->> t.deger) is not null,
               'var_mi', case when (v_harita ->> t.deger) is not null
                              then coalesce((v_ola -> (v_harita ->> t.deger))::text = 'true', false) end,
               'neden', case when (v_harita ->> t.deger) is null
                             then 'Katalogda bu talebe karşılık gelen olanak anahtarı yok; boşluk ÖLÇÜLEMİYOR.' end
             ) as x
        from (
          select (e ->> 'deger') as deger, (e ->> 'kisi')::int as kisi, 'amaç'::text as kaynak
            from jsonb_array_elements(coalesce(v_amac, '[]'::jsonb)) e
          union all
          select (e ->> 'deger'), (e ->> 'kisi')::int, 'tarz'
            from jsonb_array_elements(coalesce(v_tarz, '[]'::jsonb)) e
        ) t
    ) q;

  return jsonb_build_object(
    'known', true, 'yetki', true, 'gun', p_gun, 'k_esigi', v_k,
    'misafir_sayisi', v_misafir,
    'amac_beyan_eden', coalesce(v_amac_beyan, 0),
    'tarz_beyan_eden', coalesce(v_tarz_beyan, 0),
    -- ŞARTNAME: "beyan eden: %N" olmadan bu ekran yayımlanmaz.
    'amac_beyan_orani_yuzde', round(coalesce(v_amac_beyan, 0)::numeric * 100 / nullif(v_misafir, 0), 1),
    'tarz_beyan_orani_yuzde', round(coalesce(v_tarz_beyan, 0)::numeric * 100 / nullif(v_misafir, 0), 1),
    'beyan_satiri', format('beyan eden: amaç %%%s · tarz %%%s',
        round(coalesce(v_amac_beyan, 0)::numeric * 100 / nullif(v_misafir, 0), 1),
        round(coalesce(v_tarz_beyan, 0)::numeric * 100 / nullif(v_misafir, 0), 1)),
    'amac_satirlari', coalesce(v_amac, '[]'::jsonb),
    'tarz_satirlari', coalesce(v_tarz, '[]'::jsonb),
    'olanaklar', coalesce(v_ola, '{}'::jsonb),
    'olanak_bosluklari', coalesce(v_bosluk, '[]'::jsonb),
    'hesaplanabilir', (v_amac is not null or v_tarz is not null),
    'neden', case
      when coalesce(v_amac_beyan, 0) = 0 and coalesce(v_tarz_beyan, 0) = 0
        then format('%s misafirin hiçbiri amaç ya da seyahat tarzı beyan etmemiş; iki kolon da isteğe bağlı. Kırılım üretilemez.', v_misafir)
      when v_amac is null and v_tarz is null
        then format('Beyan var ama hiçbir değer %s kişilik eşiği geçmedi.', v_k)
      end,
    'not', 'Seyahat amacı oturuma doğrudan bağlanamadığı için kişinin bu havalimanındaki en yakın tarihli beyanı kullanıldı; bu bir yedek eşlemedir.');
end $fn$;


-- ============================================================
-- Ö10 · ERKEN GİRİŞ / AŞIRI KALIŞ BASKISI
-- ============================================================
-- "Girişlerin %18'i uçuştan 5+ saat önce; kuralın 3 saat" — kapıda
-- çatışma üreten yapısal sorunun ölçüsü.
--
-- 🔴 YALNIZ `flight_verified = true` SEYAHATLER. Doğrulanmamış uçuş
-- saatiyle "erken geldi" demek, kullanıcının elle yazdığı saate dayanıp
-- işletmeciye kural değiştirtmektir. Bu yüzden KAPSAM da yayımlanıyor
-- ve kapsam eşiğin altındaysa sayı HİÇ verilmiyor — düşük kapsamlı bir
-- yüzde, yüksek kapsamlı bir yüzdeyle aynı görünür ama aynı şey değildir.
create or replace function public.venue_stay_pressure(
  p_lounge_id uuid, p_user uuid default null, p_gun int default 180)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_k int := public.partner_k();
  v_kapsam_esigi constant numeric := 50;   -- % — altındaysa yayımlanmaz
  v_ap text;
  v_prog text; v_erken_o numeric; v_erken_a numeric; v_azami numeric;
  v_url text; v_tarih date; v_kural_ap text;
  v_oturum int; v_dogrulanmis int; v_saatli int; v_kisi int;
  v_erken int; v_asiri int; v_kapsam numeric;
begin
  if not coalesce(public.partner_gate(p_user, p_lounge_id), false) then
    return jsonb_build_object('known', false, 'yetki', false, 'hesaplanabilir', false,
      'neden', 'Bu salon için yetkiniz yok ya da partner_channel bayrağı kapalı.');
  end if;

  select l.airport_code into v_ap from lounges l where l.id = p_lounge_id;

  -- KURAL SEÇİMİ BELİRLİ OLMALI: havalimanına özel satır genel satırı
  -- yener; `max_stay_hours` dolu olan boş olanı yener; sonra en yeni
  -- kontrol; en son `id` — beraberliği kesin bitirsin diye. Aksi hâlde
  -- aynı sorgu iki kez farklı kural seçer ve rapor "bazen" değişir.
  select w.program_code, w.airport_code, w.earliest_hours_origin, w.earliest_hours_connecting,
         w.max_stay_hours, w.source_url, w.checked_at
    into v_prog, v_kural_ap, v_erken_o, v_erken_a, v_azami, v_url, v_tarih
    from lounge_entry_windows w
   where coalesce(w.active, true)
     and (w.airport_code = v_ap or w.airport_code is null)
   order by (w.airport_code is not null) desc,
            (w.max_stay_hours is not null) desc,
            w.checked_at desc nulls last,
            w.id
   limit 1;

  -- Oturum → seyahat bağı. `requests.visit_id` ölçümde 1/1 NULL olduğu
  -- için yedek eşleme var: aynı misafir + aynı havalimanı + aynı gün.
  --
  -- 🔴 GEÇİCİ TABLO YOK: fonksiyon `stable`, yazma yapamaz (bkz. Ö9).
  -- Bütün sayımlar TEK geçişte, tek CTE üzerinden alınıyor — erken
  -- giriş ve aşırı kalış dâhil. İkinci bir geçiş, iki geçişin farklı
  -- `now()` görme riskini de doğururdu.
  with k as (
    select r.guest_id,
           coalesce(v.flight_verified, false) as dogrulandi,
           v.scheduled_departure              as kalkis,
           s.started_at                       as bas,
           s.completed_at                     as bit
      from sessions s
      join requests r on r.id = s.request_id
      join availabilities a on a.id = r.avail_id
      join users u on u.id = r.guest_id
      left join lateral (
        select vv.flight_verified, vv.scheduled_departure
          from visits vv
         where vv.id = r.visit_id
            or (r.visit_id is null
                and vv.user_id = r.guest_id
                and vv.airport_code = v_ap
                and vv.visit_date = s.started_at::date)
         -- 🔴 `coalesce(..., false)` ŞART: `r.visit_id` NULL iken
         -- `vv.id = r.visit_id` false DEĞİL **NULL** döner ve
         -- PostgreSQL'in varsayılan NULLS FIRST kuralı onu en başa
         -- taşır — yani yedek eşleşme, doğrudan eşleşmeyi yenerdi.
         -- 144'te bu tuzak ürünün en çok sorulan sorusuna yanlış cevap
         -- verdirdi; nöbetçim (sql_lint nullsort) beni burada da yakaladı.
         order by coalesce(vv.id = r.visit_id, false) desc, vv.visit_date desc, vv.id
         limit 1) v on true
     where a.lounge_id = p_lounge_id
       and s.started_at >= now() - make_interval(days => p_gun)
       and coalesce(u.is_staff, false) = false
       and u.deleted_at is null
  )
  select count(*)::int,
         count(*) filter (where dogrulandi)::int,
         count(*) filter (where dogrulandi and kalkis is not null)::int,
         count(distinct guest_id) filter (where dogrulandi and kalkis is not null)::int,
         count(*) filter (where dogrulandi and kalkis is not null
                            and v_erken_o is not null
                            and extract(epoch from (kalkis - bas)) / 3600.0 > v_erken_o)::int,
         count(*) filter (where dogrulandi and kalkis is not null
                            and v_azami is not null and bit is not null
                            and extract(epoch from (bit - bas)) / 3600.0 > v_azami)::int
    into v_oturum, v_dogrulanmis, v_saatli, v_kisi, v_erken, v_asiri
    from k;

  v_kapsam := round(coalesce(v_saatli, 0)::numeric * 100 / nullif(v_oturum, 0), 1);

  -- ÜÇ AYRI RET SEBEBİ, ÜÇÜ DE AYRI SÖYLENİYOR.
  if coalesce(v_oturum, 0) = 0 then
    return jsonb_build_object('known', true, 'yetki', true, 'gun', p_gun, 'k_esigi', v_k,
      'havalimani', v_ap, 'oturum_toplam', 0, 'ucus_dogrulanmis', 0, 'kapsam_yuzde', null,
      'kapsam_esigi_yuzde', v_kapsam_esigi, 'hesaplanabilir', false,
      'neden', format('Son %s günde bu salonda hiç oturum yok.', p_gun));
  end if;

  if coalesce(v_kapsam, 0) < v_kapsam_esigi then
    return jsonb_build_object('known', true, 'yetki', true, 'gun', p_gun, 'k_esigi', v_k,
      'havalimani', v_ap,
      'oturum_toplam', v_oturum, 'ucus_dogrulanmis', v_dogrulanmis,
      'kalkis_saati_olan', v_saatli, 'kapsam_yuzde', coalesce(v_kapsam, 0),
      'kapsam_esigi_yuzde', v_kapsam_esigi, 'hesaplanabilir', false,
      'neden', format('%s oturumun yalnız %s''inde doğrulanmış uçuş ve kalkış saati var (kapsam %%%s, eşik %%%s). Bu kapsamla yayımlanan bir yüzde işletmeciyi yanıltır.',
                      v_oturum, coalesce(v_saatli, 0), coalesce(v_kapsam, 0), v_kapsam_esigi),
      'not', 'Uçuş doğrulaması arttıkça bu ekran kendiliğinden açılır; ayrı bir veri toplama gerekmiyor.');
  end if;

  if coalesce(v_kisi, 0) < v_k then
    return jsonb_build_object('known', true, 'yetki', true, 'gun', p_gun, 'k_esigi', v_k,
      'havalimani', v_ap,
      'oturum_toplam', v_oturum, 'ucus_dogrulanmis', v_dogrulanmis,
      'kalkis_saati_olan', v_saatli, 'kapsam_yuzde', v_kapsam,
      'kapsam_esigi_yuzde', v_kapsam_esigi, 'kisi', v_kisi, 'hesaplanabilir', false,
      'neden', format('Kapsam yeterli (%%%s) ama ölçüm yalnız %s farklı kişiye dayanıyor; k-anonimite eşiği %s.',
                      v_kapsam, coalesce(v_kisi, 0), v_k));
  end if;

  -- v_erken / v_asiri yukarıdaki TEK geçişte zaten hesaplandı.

  return jsonb_build_object(
    'known', true, 'yetki', true, 'gun', p_gun, 'k_esigi', v_k, 'havalimani', v_ap,
    'oturum_toplam', v_oturum, 'ucus_dogrulanmis', v_dogrulanmis,
    'kalkis_saati_olan', v_saatli, 'kisi', v_kisi,
    'kapsam_yuzde', v_kapsam, 'kapsam_esigi_yuzde', v_kapsam_esigi,
    'kural', case when v_prog is null then null else jsonb_build_object(
       'program_kodu', v_prog,
       'kural_havalimani', coalesce(v_kural_ap, 'genel'),
       'en_erken_saat_dogrudan', v_erken_o,
       'en_erken_saat_aktarma', v_erken_a,
       'azami_kalis_saat', v_azami,
       'kaynak_url', v_url,
       'kontrol_tarihi', v_tarih) end,
    'erken_giris', coalesce(v_erken, 0),
    'erken_giris_yuzde', round(coalesce(v_erken, 0)::numeric * 100 / nullif(v_saatli, 0), 1),
    'asiri_kalis', coalesce(v_asiri, 0),
    'asiri_kalis_yuzde', case when v_azami is null then null
      else round(coalesce(v_asiri, 0)::numeric * 100 / nullif(v_saatli, 0), 1) end,
    'hesaplanabilir', true,
    'neden', case when v_azami is null
      then 'Erken giriş ölçüldü; aşırı kalış ÖLÇÜLEMEDİ çünkü uygulanan kuralda azami kalış saati tanımlı değil.' end,
    'not', format('Yalnız flight_verified seyahatler sayıldı; kapsam %%%s.', v_kapsam));
end $fn$;


-- ============================================================
-- NÖBETÇİLER — her fonksiyonun ÇALIŞTIĞINI kanıtla
-- ============================================================
-- 🔴 Bir nöbetçi ATLADIĞINI söylemezse, atlayan nöbetçi olmayan
-- nöbetçidir (209'un dersi). Aşağıdaki bloklar sahneyi KENDİ kurar:
-- veri olan bir salona partner bağlar, ölçer, sonra toplar.

-- (N1) KAPI GERÇEKTEN KAPALI MI — bayrak KAPALI iken hiçbiri veri vermemeli
do $$
declare
  v_u uuid; v_l uuid; v jsonb; v_ad text;
  v_eski boolean;
begin
  select id into v_l from lounges where id in (select lounge_id from availabilities) limit 1;
  select id into v_u from auth.users limit 1;
  if v_l is null or v_u is null then raise notice '213: ⚠ sahne yok — N1 ATLANDI'; return; end if;

  select enabled into v_eski from feature_flags where key = 'partner_channel';
  delete from lounge_partners where user_id = v_u and lounge_id = v_l;
  insert into lounge_partners (user_id, lounge_id, role) values (v_u, v_l, 'manager');

  update feature_flags set enabled = false where key = 'partner_channel';

  foreach v_ad in array array['venue_airport_share','venue_no_show','venue_program_mix',
                              'venue_price_position','venue_guest_profile','venue_stay_pressure'] loop
    execute format('select public.%I($1, $2)', v_ad) into v using v_l, v_u;
    if v is null then
      update feature_flags set enabled = coalesce(v_eski, true) where key='partner_channel';
      delete from lounge_partners where user_id = v_u and lounge_id = v_l;
      raise exception '213: % bayrak kapaliyken NULL dondu — sekil bozuk', v_ad;
    end if;
    if (v ->> 'yetki') <> 'false' then
      update feature_flags set enabled = coalesce(v_eski, true) where key='partner_channel';
      delete from lounge_partners where user_id = v_u and lounge_id = v_l;
      raise exception '213: partner_channel KAPALI iken % veri dondurdu (yetki=%)', v_ad, (v ->> 'yetki');
    end if;
  end loop;

  update feature_flags set enabled = coalesce(v_eski, true) where key = 'partner_channel';
  delete from lounge_partners where user_id = v_u and lounge_id = v_l;
  raise notice '213: kill switch gercek — bayrak kapaliyken alti fonksiyon da veri VERMIYOR';
end $$;

-- (N2) ALTI FONKSİYON DA ÇAĞRILABİLİYOR VE ŞEKLİ DOĞRU MU
do $$
declare
  v_u uuid; v_l uuid; v jsonb;
begin
  -- Veri OLAN salonu seç: nöbetçi boş sahnede hiçbir şey kanıtlamaz.
  select a.lounge_id into v_l
    from availabilities a group by a.lounge_id
   order by count(distinct a.host_id) desc, a.lounge_id limit 1;
  select id into v_u from auth.users limit 1;
  if v_l is null or v_u is null then raise notice '213: ⚠ sahne yok — N2 ATLANDI'; return; end if;

  delete from lounge_partners where user_id = v_u and lounge_id = v_l;
  insert into lounge_partners (user_id, lounge_id, role) values (v_u, v_l, 'manager');

  v := public.venue_airport_share(v_l, v_u);
  if v is null or (v ->> 'yetki') <> 'true' or not (v ? 'karsilastirilan_salon') then
    raise exception '213: venue_airport_share sekli bozuk → %', v; end if;

  v := public.venue_no_show(v_l, v_u);
  if v is null or not (v ? 'haftalar') or not (v ? 'kapsam_yuzde') then
    raise exception '213: venue_no_show sekli bozuk → %', v; end if;

  v := public.venue_program_mix(v_l, v_u);
  -- ŞARTNAME: "program bilinmeyen: %N" satırı HER ZAMAN olmalı.
  if v is null or (v ->> 'bilinmeyen_satiri') is null then
    raise exception '213: venue_program_mix "program bilinmeyen" satirini VERMIYOR → %', v; end if;

  v := public.venue_price_position(v_l, v_u);
  if v is null or (v ->> 'k_muaf') <> 'true' then
    raise exception '213: venue_price_position k muafiyetini BEYAN ETMIYOR → %', v; end if;

  v := public.venue_guest_profile(v_l, v_u);
  -- ŞARTNAME: beyan oranı olmadan bu ekran yayımlanamaz.
  if v is null or not (v ? 'amac_beyan_orani_yuzde') or (v ->> 'neden') is null and (v ->> 'hesaplanabilir') = 'false' then
    raise exception '213: venue_guest_profile beyan oranini/sebebini VERMIYOR → %', v; end if;

  v := public.venue_stay_pressure(v_l, v_u);
  if v is null or not (v ? 'kapsam_yuzde') then
    raise exception '213: venue_stay_pressure kapsam yuzdesini VERMIYOR → %', v; end if;

  delete from lounge_partners where user_id = v_u and lounge_id = v_l;
  raise notice '213: alti kurumsal fonksiyonun sekli de dogrulandi';
end $$;

-- (N3) MUTASYON KANITI — k eşiği GERÇEKTEN satır gizliyor mu
-- 🔴 Eşiği ayara taşımanın tek anlamı DEĞİŞTİRİLEBİLİR olmasıdır.
-- Değiştirip sonucun değiştiğini kanıtlamazsam ayar sahtedir.
do $$
declare
  v_u uuid; v_l uuid; v jsonb; v_eski int;
  v_host int; v_az int; v_cok int;
begin
  select a.lounge_id, count(distinct a.host_id)::int into v_l, v_host
    from availabilities a group by a.lounge_id
   order by count(distinct a.host_id) desc, a.lounge_id limit 1;
  select id into v_u from auth.users limit 1;
  if v_l is null or v_u is null or coalesce(v_host,0) < 2 then
    raise notice '213: ⚠ k-esigi MUTASYON KANITI ATLANDI — tek host tasiyan sahnede kanit uretilemez';
    return;
  end if;

  delete from lounge_partners where user_id = v_u and lounge_id = v_l;
  insert into lounge_partners (user_id, lounge_id, role) values (v_u, v_l, 'manager');
  select (value #>> '{}')::int into v_eski from beta_settings where key = 'partner_k_threshold';

  -- Eşik 1: her satır görünmeli
  update beta_settings set value = to_jsonb(1) where key = 'partner_k_threshold';
  v := public.venue_program_mix(v_l, v_u);
  v_az := jsonb_array_length(coalesce(v -> 'satirlar', '[]'::jsonb));

  -- Eşik host sayısından BÜYÜK: hiçbir satır kalmamalı
  update beta_settings set value = to_jsonb(v_host + 1) where key = 'partner_k_threshold';
  v := public.venue_program_mix(v_l, v_u);
  v_cok := jsonb_array_length(coalesce(v -> 'satirlar', '[]'::jsonb));

  update beta_settings set value = to_jsonb(coalesce(v_eski, 5)) where key = 'partner_k_threshold';
  delete from lounge_partners where user_id = v_u and lounge_id = v_l;

  if v_az = 0 then
    raise exception '213: k=1 iken bile satir yok — mutasyon kaniti veri uretemedi (host=%)', v_host;
  end if;
  if v_cok <> 0 then
    raise exception '213: k=% iken hala % satir dondu — esik UYGULANMIYOR', v_host + 1, v_cok;
  end if;
  raise notice '213: k-esigi mutasyon kaniti — k=1 iken % satir, k=% iken 0 satir (salonda % host)',
    v_az, v_host + 1, v_host;
end $$;

-- (N4) YABANCI BİRİ VERİ ALABİLİYOR MU (kapı mutasyonu)
do $$
declare v_l uuid; v_y uuid; v jsonb; v_ad text;
begin
  select id into v_l from lounges where id in (select lounge_id from availabilities) limit 1;
  select u.id into v_y from auth.users u
   where not exists (select 1 from lounge_partners lp where lp.user_id = u.id)
     and not exists (select 1 from admin_roles a where a.user_id = u.id)
   limit 1;
  if v_l is null or v_y is null then raise notice '213: ⚠ yabanci kullanici yok — N4 ATLANDI'; return; end if;

  foreach v_ad in array array['venue_airport_share','venue_no_show','venue_program_mix',
                              'venue_price_position','venue_guest_profile','venue_stay_pressure'] loop
    execute format('select public.%I($1, $2)', v_ad) into v using v_l, v_y;
    if (v ->> 'yetki') <> 'false' then
      raise exception '213: YABANCI biri % cagirdi ve yetki=% dondu', v_ad, (v ->> 'yetki');
    end if;
    if coalesce(jsonb_array_length(coalesce(v -> 'satirlar', '[]'::jsonb)), 0) > 0 then
      raise exception '213: YABANCI biri % icinden SATIR aldi', v_ad;
    end if;
  end loop;
  raise notice '213: alti fonksiyon da yabanciya kapali (satir da vermiyor)';
end $$;

-- (N5) 209'UN BEŞ FONKSİYONU ONARILDI MI — 22P02 geri geldi mi
do $$
declare v_u uuid; v_l uuid; v jsonb; v_ad text;
begin
  select id into v_l from lounges where id in (select lounge_id from availabilities) limit 1;
  select id into v_u from auth.users limit 1;
  if v_l is null or v_u is null then raise notice '213: ⚠ sahne yok — N5 ATLANDI'; return; end if;

  delete from lounge_partners where user_id = v_u and lounge_id = v_l;
  insert into lounge_partners (user_id, lounge_id, role) values (v_u, v_l, 'manager');

  begin
    v := public.venue_gate_report(v_l, 90, v_u);
    if v is null then raise exception 'NULL dondu'; end if;
    v := public.venue_lost_demand(v_l, 30, v_u);
    if v is null then raise exception 'NULL dondu'; end if;
    v := public.venue_inbound_wave(v_l, 72, v_u);
    if v is null then raise exception 'NULL dondu'; end if;
    v := public.venue_rule_compliance(v_l, 180, v_u);
    if v is null then raise exception 'NULL dondu'; end if;
    v := public.partner_payout(v_l, current_date - 30, current_date, v_u);
    if v is null then raise exception 'NULL dondu'; end if;
  exception when others then
    delete from lounge_partners where user_id = v_u and lounge_id = v_l;
    raise exception '213: 209 fonksiyonlari HALA KIRIK → % / %', sqlstate, sqlerrm;
  end;

  delete from lounge_partners where user_id = v_u and lounge_id = v_l;
  raise notice '213: 209''un bes fonksiyonu da onarildi — 22P02 gitti';
end $$;

-- (N6) SAHNEYİ TOPLA — test partner kaydı kalmasın
do $$
declare v_n int;
begin
  delete from lounge_partners
   where role = 'manager'
     and created_at > now() - interval '10 minutes'
     and user_id in (select id from auth.users);
  get diagnostics v_n = row_count;
  raise notice '213: sahne toplandi — % test partner kaydi silindi', v_n;
end $$;


-- ============================================================
-- YÜZEY — EN SONDA, HER FONKSİYON YARATILDIKTAN SONRA
-- ============================================================
-- 🔴 BU ÜÇ KEZ ISIRDI: `apply_rpc_surface()` dosyanın ORTASINDA
-- çağrıldığında, ondan SONRA yaratılan fonksiyonlar istemciye açık
-- kalıyor ve "RPC yuzeyi ihlali" değişmezi kırmızı yanıyor. Çağrı
-- bilinçli olarak dosyanın EN SONUNDA.
--
-- Sıra da bilinçli: önce kayıt (rpc_client_surface), sonra kilitleme
-- (apply), sonra izin (grant). `rpc_surface_violations()` üçüncü
-- kuralı ile "yüzeyde yazılı ama istemci ÇAĞIRAMIYOR" durumunu da
-- denetliyor — grant, apply'dan SONRA gelmezse apply onu geri alır.
insert into rpc_client_surface (fn_name, client, note) values
  ('venue_airport_share', 'backoffice_session','O5 · havalimani ici pay (rakip adi yok)'),
  ('venue_no_show',       'backoffice_session','O6 · no-show / iptal / ortalama kalis'),
  ('venue_program_mix',   'backoffice_session','O7 · kart programi karmasi + bilinmeyen orani'),
  ('venue_price_position','backoffice_session','O8 · fiyat konumu (katalog, k muaf)'),
  ('venue_guest_profile', 'backoffice_session','O9 · amac x tarz x olanak boslugu'),
  ('venue_stay_pressure', 'backoffice_session','O10 · erken giris / asiri kalis')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '213: sinir uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $$;

do $$
declare r record;
begin
  for r in
    select p.proname, pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      join rpc_client_surface s on s.fn_name = p.proname
     where n.nspname = 'public' and p.prokind = 'f' and s.client = 'backoffice_session'
  loop
    execute format('grant execute on function public.%I(%s) to authenticated, anon', r.proname, r.args);
  end loop;
end $$;

select '213 OK - saglayici kapisi onarildi, alti kurumsal ekranin verisi acildi' as sonuc;
