-- ============================================================================
-- LoungeLink · 243_one_cikarma_gercekten_calissin.sql     (23 Ağustos 2026)
--
-- ÖNE ÇIKARMA İKİ YERDEN BİRDEN KIRIKTI — BİRİNİ BUGÜN BEN KIRDIM
--
-- ════════════════════════════════════════════════════════════════════════
-- GÖKBERK SORDU: "İlan öne çıkarma gerçekten çalışıyor mu?"
-- ════════════════════════════════════════════════════════════════════════
-- Ölçtüm. Cevap: HAYIR, iki ayrı sebeple.
--
-- ── KIRIK 1: YAZMA. 240'IN YAN ETKİSİ. BENİM HATAM. ──────────────────
-- 240'ta "kural motorunun çıktısı istemcinin girdisi değildir" diyerek
-- `featured_until`, `rule_*` ve `min_trust` kolonlarını tetikleyicide
-- SESSİZCE ESKİ DEĞERE geri alıyordum. Ama o tetikleyici HERKESE
-- çalışıyor — `set_featured()` gibi MEŞRU yazana da.
--
-- ÖLÇTÜM (host1, kendi ilanı):
--   set_featured(ilan) → {"ok": true, "kaynak": "plan", "plan_hakki_kalan": 1}
--   select featured_until ...  → NULL
--
-- Yani: kullanıcının plan hakkı (ya da 200 puanı) HARCANDI, uygulama
-- "oldu" dedi, ilan öne ÇIKMADI. Sessiz ve bedeli kullanıcıya ödetiyor —
-- bu projedeki en pahalı hata türü.
--
-- 🆕 SINIF: **"BİR KOLONU 'İSTEMCİ YAZAMAZ' DİYE KİLİTLERKEN, O KOLONU
-- MEŞRU OLARAK YAZAN FONKSİYONU DA KİLİTLEMİŞ OLABİLİRSİN."**
--
-- Neden nöbetçim yakalamadı: 240'ın nöbetçisi "istemci yazabiliyor mu?"
-- diye sordu, "meşru yazan hâlâ yazabiliyor mu?" diye SORMADI. Ters yön
-- ölçümünü uçuş numarası için yazmıştım, bu kolonlar için yazmamıştım.
--
-- ── KIRIK 2: SIRALAMA. BUGÜNDEN ÖNCE DE KIRIKTI. ─────────────────────
-- İki keşif fonksiyonu var:
--   discover_availabilities_base  → `order by b.featured desc, ...`  ✅
--   discover_availabilities       → `order by (match_score + host_rank_bonus) desc`
--                                                            ❌ featured YOK
-- App `discover_availabilities`i çağırıyor (screens.js:1335). Yani öne
-- çıkarma yazılsaydı bile SIRALAMAYI DEĞİŞTİRMEYECEKTİ. `_base`teki
-- doğru sıralama, üstüne binen sarmalayıcıda kayboluyor.
--
-- 🆕 SINIF: **"BİR SIRALAMA KURALI, ÜSTÜNE BAŞKA BİR SIRALAMA BİNDİĞİNDE
-- KURAL OLMAKTAN ÇIKAR."**
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) MEŞRU YAZAN İÇİN BİR KAPI — AMA İSTEMCİYE AÇILMAYAN BİR KAPI
-- ----------------------------------------------------------------------------
-- Tetikleyici, yazanın "motor" mu yoksa "istemci" mi olduğunu bilmeli.
--
-- ⚠️ `current_user` İŞE YARAMAZ: tetikleyicinin kendisi SECURITY DEFINER,
-- yani içeride current_user zaten sahip görünüyor — çağıran kim olursa
-- olsun. Ölçtüm, bu yolu bu yüzden bıraktım.
--
-- Çözüm: işlem-yerel bir bayrak. Yalnız güvenilen fonksiyonlar kaldırır.
-- İstemci bunu kaldıramaz çünkü `set_config` PostgREST yüzeyinde YOK
-- (pg_catalog'da; istemci yalnız public şemasındaki fonksiyonları
-- çağırabiliyor) ve aşağıdaki sarmalayıcının EXECUTE hakkı da alınıyor.
create or replace function public.motor_yazimi_ac()
returns void language plpgsql security definer set search_path = public as $f$
begin
  perform set_config('loungelink.motor', 'evet', true);   -- true = işlem sonunda düşer
end $f$;
revoke execute on function public.motor_yazimi_ac() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2) TETİKLEYİCİ: KURAL AYNI, İSTİSNA DOĞRU YERDE
-- ----------------------------------------------------------------------------
create or replace function public.trg_ilan_kapatma_kapisi()
returns trigger language plpgsql security definer set search_path = public as $f$
declare
  v_kabul  int;
  v_admin  boolean;
  v_motor  boolean;
begin
  v_admin := auth.uid() is not null
             and exists (select 1 from admin_roles where user_id = auth.uid());
  -- 🔴 YENİ: motor yazımı. Sözleşme kilitleri (a,b,c) buna RAĞMEN geçerli —
  -- onlar yetki değil VERİ TUTARLILIĞI kuralı. Bayrak yalnızca (d)'yi,
  -- yani "motor çıktısını geri al" kısmını atlatır.
  v_motor := coalesce(current_setting('loungelink.motor', true), '') = 'evet';

  select count(*) into v_kabul
    from requests where avail_id = new.id and status = 'accepted';

  -- (a) kabul edilmiş misafir varken ilan kapatılamaz
  if coalesce(old.active,true) and not coalesce(new.active,true)
     and v_kabul > 0 and not v_admin then
    raise exception 'has_accepted_requests'
      using detail = format('%s kabul edilmis basvuru', v_kabul),
            hint   = 'Kabul ettigin misafir var. Ilani kaldirmadan once '
                  || 'sohbetten haber ver ve basvuruyu iptal et.';
  end if;

  -- (b) kabul edilmiş misafir varken tarih / saat / salon kilitli
  if v_kabul > 0 and not v_admin
     and (new.avail_date   is distinct from old.avail_date
       or new.time_from    is distinct from old.time_from
       or new.time_to      is distinct from old.time_to
       or new.lounge_id    is distinct from old.lounge_id
       or new.airport_code is distinct from old.airport_code) then
    raise exception 'kabul_edilmis_basvuru_var'
      using detail = format('%s kabul edilmis basvuru', v_kabul),
            hint   = 'Tarih, saat ve salon kilitli. Kontenjani artirabilir, '
                  || 'ucus numarasini duzeltebilirsin.';
  end if;

  -- (c) kontenjan, dolu koltuk sayısının altına inemez (aritmetik kural)
  if new.slots is distinct from old.slots and new.slots < coalesce(new.filled,0) then
    raise exception 'kontenjan_dolulugun_altinda'
      using detail = format('kontenjan %s, dolu %s', new.slots, coalesce(new.filled,0));
  end if;

  -- (d) motor çıktısı istemcinin girdisi değildir — AMA MOTORUN GİRDİSİDİR
  if not v_admin and not v_motor then
    new.rule_severity        := old.rule_severity;
    new.rule_headline        := old.rule_headline;
    new.rule_note            := old.rule_note;
    new.rule_entry_hours     := old.rule_entry_hours;
    new.rule_guest_policy    := old.rule_guest_policy;
    new.rule_flight_coupling := old.rule_flight_coupling;
    new.rule_checked_at      := old.rule_checked_at;
    new.min_trust            := old.min_trust;
    new.featured_until       := old.featured_until;
  end if;

  return new;
end $f$;

-- ----------------------------------------------------------------------------
-- 3) GÜVENİLEN YAZARLAR BAYRAĞI KALDIRSIN
-- ----------------------------------------------------------------------------
-- Kimlerin bu kolonları meşru olarak yazdığını ELLE saymıyorum; canlı
-- gövdelerden ÇIKARIYORUM. Elle liste tutmak bu projede defalarca eksik
-- kaldı ve yarın beşinci bir yazar eklenirse yine sessizce kırılırdı.
do $inject$
declare
  r        record;
  v_def    text;
  v_yeni   text;
  v_n      int := 0;
  v_atlan  text[] := '{}';
begin
  for r in
    select p.oid, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname <> 'trg_ilan_kapatma_kapisi'
       and p.prolang = (select oid from pg_language where lanname='plpgsql')
       and p.prosrc ~ '(featured_until|rule_severity|rule_headline|rule_note|rule_entry_hours|rule_guest_policy|rule_flight_coupling|rule_checked_at|min_trust)\s*='
  loop
    if r.proname = 'motor_yazimi_ac' then continue; end if;
    v_def := pg_get_functiondef(r.oid);
    if v_def ~ 'motor_yazimi_ac' then continue; end if;   -- zaten var (tekrar koşulabilir)

    -- İlk `begin`den hemen sonra. Gövde metnini EZBERDEN yazmıyorum;
    -- canlı tanımı okuyup düzenli ifadeyle işaretliyorum (238'in dersi).
    v_yeni := regexp_replace(v_def, '(\mbegin\M)',
                             E'begin\n  perform public.motor_yazimi_ac();', 1);
    if v_yeni = v_def then
      v_atlan := v_atlan || r.proname;
      continue;
    end if;
    execute v_yeni;
    v_n := v_n + 1;
  end loop;

  raise notice '243: % fonksiyona motor bayragi eklendi%', v_n,
    case when array_length(v_atlan,1) is null then ''
         else format(' · KALIP BULUNAMADI: %s', array_to_string(v_atlan, ', ')) end;
  if array_length(v_atlan,1) is not null then
    raise exception '243: su fonksiyonlara bayrak EKLENEMEDI: %. Bunlar meşru '
                    'yazar ama tetikleyici yazdiklarini geri alacak — sessiz '
                    'kirilma. Elle bakilmali.', array_to_string(v_atlan, ', ');
  end if;
end $inject$;

-- ----------------------------------------------------------------------------
-- 4) SIRALAMA: ÖNE ÇIKAN İLAN GERÇEKTEN ÖNE ÇIKSIN
-- ----------------------------------------------------------------------------
-- `_base` zaten doğru sıralıyordu ama sarmalayıcı üstüne kendi sıralamasını
-- koyuyordu. Öne çıkarma BİRİNCİ ölçüt olur; eşitlikte eski sıralama aynen
-- devam eder — yani öne çıkarma, eşleşme kalitesini YOK SAYMAZ, yalnız
-- 24 saatliğine öne alır.
-- 🔴 BU BÖLÜM İKİ KEZ PATLADI VE İKİSİNDE DE AYNI KÖKTEN:
--    GÖVDENİN NE OLDUĞUNU VARSAYDIM.
--
--    1. deneme: `order by`ı birebir metin arayıp değiştirdim →
--       "beklenen `order by` bulunamadi" (biçim farklıydı).
--    2. deneme: gövdeyi ince bir sarmalayıcı sanıp sıfırdan yazdım →
--       "govdesi bekledigim sarmalayici DEGIL" (güvenlik kapım durdurdu).
--
-- Gökberk'in veritabanındaki gerçek gövde ŞU:
--   declare v_uid uuid := auth.uid(); v_prof text;
--   begin ... return query with base as (
--     select d.* from public.discover_availabilities_base(...) d
--   ), enriched as ( ... lounge_access_decision ... )
--
-- Yani harness'teki üç satırlık SQL sarmalayıcı DEĞİL; kendi zenginleştirmesi
-- olan tam bir plpgsql fonksiyonu. İki farklı veritabanında iki farklı
-- gövde. Hangisinin doğru olduğu ayrı mesele — ama benim onarımım
-- İKİSİNDE DE çalışmak zorunda.
--
-- 🆕 SINIF: **"BİR GÖVDEYİ ONARMANIN EN SAĞLAM YOLU, GÖVDEYE HİÇ
-- DOKUNMAMAKTIR."**
--
-- Yeni yaklaşım gövdeyi OKUMUYOR bile:
--   1. Mevcut fonksiyon, gövdesi AYNEN korunarak
--      `discover_availabilities_ham` adıyla kopyalanır (yalnız BAŞLIK
--      satırındaki ad değişir, gövdenin tek karakterine dokunulmaz).
--   2. `discover_availabilities` ince bir sarmalayıcıya dönüşür:
--      ham fonksiyonu çağırır, satırların ORİJİNAL SIRASINI
--      `row_number() over ()` ile yakalar, sonra yalnızca öne çıkanları
--      en üste alır.
--
-- Böylece içerideki sıralama mantığı — eşleşme puanı, host rütbesi,
-- tarih, ne varsa — AYNEN korunur; tek değişen, öne çıkan ilanların
-- listenin başına alınması. Gövde yarın büsbütün değişse bile bu onarım
-- çalışmaya devam eder.
do $siralama$
declare v_def text; v_src text; v_arg text; v_ret text; v_ham text;
begin
  select pg_get_functiondef(p.oid), p.prosrc, pg_get_function_arguments(p.oid),
         pg_get_function_result(p.oid)
    into v_def, v_src, v_arg, v_ret
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='discover_availabilities' limit 1;

  if v_def is null then
    raise exception '243: discover_availabilities yok — once onu kuran dosyayi kostur.';
  end if;

  if v_src ilike '%discover_availabilities_ham%' then
    raise notice '243: siralama zaten sarmalanmis, dokunulmadi.';
    return;
  end if;

  -- Fonksiyon `is_featured` dondurmuyorsa one cikarma zaten gosterilemez.
  if v_ret not ilike '%is_featured%' then
    raise exception '243: discover_availabilities `is_featured` DONDURMUYOR. '
                    'One cikarma keste gosterilemez. Donen kolonlar: %', left(v_ret, 300);
  end if;

  -- Kendi kendini cagiran bir govdeyi yeniden adlandirmak sonsuz dongu
  -- yaratirdi. Olcuyorum, varsaymiyorum.
  if v_src ~ '\mdiscover_availabilities\s*\(' then
    raise exception '243: govde kendi adini cagiriyor — yeniden adlandirma guvenli degil. Elle bakilmali.';
  end if;

  -- (1) Gövdeyi AYNEN koru, yalnız başlıktaki adı değiştir.
  v_ham := regexp_replace(v_def,
    'FUNCTION\s+public\.discover_availabilities\s*\(',
    'FUNCTION public.discover_availabilities_ham(', 'i');
  if v_ham = v_def then
    raise exception '243: fonksiyon basligi beklenen bicimde degil, kopyalanamadi.';
  end if;
  execute v_ham;

  -- (2) Sarmalayıcı. `row_number() over ()` ham fonksiyonun KENDİ çıktı
  -- sırasını yakalar; ikinci sıralama ölçütü olarak kullanınca içerideki
  -- bütün mantık korunur.
  execute format(
    'create or replace function public.discover_availabilities(%s) returns %s '
    'language sql stable security definer set search_path = public as $b$ '
    '  select (t.r).* from ( '
    '    select h as r, row_number() over () as rn '
    '      from public.discover_availabilities_ham(p_airport, p_sector, p_flight, p_date) h '
    '  ) t '
    '  order by coalesce((t.r).is_featured, false) desc, t.rn $b$', v_arg, v_ret);

  raise notice '243: kesif sarmalandi — ic siralama AYNEN korundu, one cikanlar basa alindi.';
end $siralama$;

grant execute on function public.discover_availabilities(text, text, text, date) to authenticated;

-- ----------------------------------------------------------------------------
-- 4b) ÖNE ÇIKARMAYI ONARINCA YENİ BİR RİSK AÇTIM — ONU DA KAPATIYORUM
-- ----------------------------------------------------------------------------
-- 🔴 Öne çıkarmayı sıralamanın BİRİNCİ ölçütü yaptım. Aynı anda Kâhya
-- planında `one_cikarma_ayda = 99` var — yani pratikte sınırsız, günde
-- ~3 öne çıkarma. Üç ilanı olan tek bir Kâhya kullanıcısı, keşfin en
-- üstünü SÜREKLİ işgal edebilir.
--
-- Yani bir kırığı onarırken bir kaldıraç yarattım: para ödeyen tek
-- kullanıcı, eşleşme kalitesini kalıcı olarak ezebilir. Öne çıkarma
-- "24 saatliğine görünürlük" demek olmalı, "keşfi satın almak" değil.
--
-- 🆕 SINIF: **"BİR SIRALAMA KALDIRACINI ONARIRKEN, O KALDIRACIN TAVANINI
-- DA KOYMAZSAN ONARDIĞIN ŞEY İSTİSMAR YOLU OLUR."**
--
-- Tavan: bir host'un aynı anda EN FAZLA 1 ilanı öne çıkabilir. Plan
-- hakkı ayda kaç kez öne çıkarabileceğini belirler; bu kural aynı anda
-- kaç tanesinin üstte durabileceğini. İkisi farklı sorulardır.
insert into beta_settings (key, value) values ('one_cikan_esz_tavan_host', to_jsonb(1))
on conflict (key) do nothing;

do $tavan$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='set_featured' limit 1;
  if v_def is null then raise exception '243: set_featured yok.'; end if;
  if v_def ~ 'one_cikan_esz_tavan_host' then
    raise notice '243: es zamanli one cikarma tavani zaten kurulu.';
    return;
  end if;

  -- Sahiplik kontrolünden HEMEN SONRA araya giriyorum. Metni birebir
  -- aramıyorum: `not_owner` satırı kısa ve kararlı bir çapa.
  v_yeni := regexp_replace(v_def,
    '(raise exception ''not_owner'';\s*end if;)',
    E'\\1\n'
    '   if (select count(*) from availabilities a\n'
    '        where a.host_id = v_uid and a.featured_until > now()\n'
    '          and a.id <> p_avail_id)\n'
    '      >= coalesce((select (value #>> ''{}'')::int from beta_settings\n'
    '                    where key = ''one_cikan_esz_tavan_host''), 1) then\n'
    '     raise exception ''zaten_one_cikan_ilanin_var''\n'
    '       using hint = ''Ayni anda tek ilanin one cikabilir. Digerinin 24 saati dolunca tekrar dene.'';\n'
    '   end if;');

  if v_yeni = v_def then
    raise exception '243: set_featured govdesinde `not_owner` capasi bulunamadi — '
                    'es zamanli tavan EKLENEMEDI. Govde: %', left(v_def, 300);
  end if;
  execute v_yeni;
  raise notice '243: es zamanli one cikarma tavani kuruldu (host basina 1).';
end $tavan$;

-- ----------------------------------------------------------------------------
-- 5) NÖBETÇİ — HER İKİ KIRIĞI DA, HER İKİ YÖNDE
-- ----------------------------------------------------------------------------
do $n243$
declare
  v_av      uuid;
  v_host    uuid;
  v_son     timestamptz;
  v_hatalar text[] := '{}';
  v_notlar  text[] := '{}';
  v_r       jsonb;
  v_ilk     uuid;
begin
  begin  -- ölçüm alt işlemi, sonunda geri alınır
    select a.id, a.host_id into v_av, v_host
      from availabilities a
     where a.active and a.avail_date >= current_date
       and not exists (select 1 from requests r where r.avail_id=a.id and r.status='accepted')
     order by a.id limit 1;

    if v_av is null then
      raise notice '243 OLCULMEDI: uygun ilan yok (SEED kosulmamis olabilir).';
    else
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_host, 'role', 'authenticated')::text, true);

      -- Ölçüm için puan yatırıyorum. Alt işlem geri alınacağı için
      -- veriye dokunmuyor; amaç `set_featured`in PUAN yolunu da
      -- sınayabilmek (host'un plan hakkı olmayabilir).
      insert into points_ledger (user_id, delta, reason)
      values (v_host, 1000, 'nobetci_243_olcum');

      -- (1) 🔴 ASIL KIRIK: set_featured GERÇEKTEN yazıyor mu
      begin
        v_r := public.set_featured(v_av);
      exception when others then
        v_hatalar := v_hatalar || ('set_featured patladi: ' || sqlerrm);
      end;
      select featured_until into v_son from availabilities where id = v_av;
      if v_son is null or v_son <= now() then
        v_hatalar := v_hatalar ||
          format('set_featured "%s" dedi ama featured_until YAZILMADI (%s) — hak harcandi, ilan one cikmadi',
                 coalesce(v_r::text,'(hata)'), coalesce(v_son::text,'NULL'));
      end if;

      -- (2) TERS YÖN: istemci yolundan motor çıktısı HÂLÂ yazılamamalı.
      -- Bayrak işlem-yerel; ayrı bir alt işlemde sıfırlanmadığı için
      -- burada elle kapatıyorum — yoksa (1) yüzünden açık kalır ve bu
      -- ölçüm yalancı yeşil verir.
      perform set_config('loungelink.motor', '', true);
      update availabilities set rule_headline = 'Kesinlikle girersin' where id = v_av;
      if exists (select 1 from availabilities where id=v_av and rule_headline='Kesinlikle girersin') then
        v_hatalar := v_hatalar || 'motor cikitisi istemci yolundan YAZILABILDI — 240 in korumasi gitti'::text;
      end if;
    end if;

    raise exception 'GERI_AL_243';
  exception when others then
    if sqlerrm <> 'GERI_AL_243' then
      v_hatalar := v_hatalar || ('olcum alt islemi coktu: ' || sqlerrm);
    end if;
  end;

  -- 🔴 (3) VE (4) ÖNCE METNE BAKIYORDU: "gövdede `is_featured` geçiyor
  -- mu", "`match_score` geçiyor mu". Sarmalayıcı yaklaşımına geçince
  -- ikisi de gövdeden çıktı (artık `_ham`ın içindeler) ve nöbetçi
  -- ÇALIŞAN bir düzeltmeyi hata saydı.
  --
  -- 🆕 SINIF: **"BİR DAVRANIŞI KOD METNİNDEN DOĞRULAMAK, DAVRANIŞI DEĞİL
  -- YAZIM BİÇİMİNİ DOĞRULAMAKTIR."**
  --
  -- Artık ikisi de DAVRANIŞ ölçüyor: gerçekten öne çıkarıp listeye
  -- bakıyorum, ve iç sıralamanın bozulmadığını satır satır karşılaştırıyorum.
  begin
    declare
      v_dusuk uuid; v_ilk uuid; v_ham uuid[]; v_yeni uuid[];
    begin
      -- Ham sıra (öne çıkarmadan önce)
      select array_agg(id order by sira) into v_ham from (
        select id, row_number() over () as sira
          from public.discover_availabilities(null,null,null,null)) z;

      select id into v_dusuk from public.discover_availabilities(null,null,null,null)
       order by match_score asc limit 1;

      if v_dusuk is null then
        v_notlar := v_notlar || 'siralama OLCULMEDI (kesifte ilan yok)'::text;
      else
        perform public.motor_yazimi_ac();
        update availabilities set featured_until = now() + interval '24 hours' where id = v_dusuk;

        select id into v_ilk from public.discover_availabilities(null,null,null,null) limit 1;
        if v_ilk is distinct from v_dusuk then
          v_hatalar := v_hatalar ||
            'one cikarilan ilan listenin BASINA GELMEDI — siralama onarimi calismiyor'::text;
        end if;

        -- TERS YÖN: öne çıkarma listeden satır DÜŞÜRMEMELİ, EKLEMEMELİ.
        --
        -- 🔴 İLK YAZDIĞIMDA "kalanların sırası birebir aynı kalmalı"
        -- diyordum ve nöbetçi kırmızı yandı. Sebebini ölçtüm: iç
        -- sıralamada BERABERLİK BOZUCU YOK (48 ilanın match_score'u aynı:
        -- 54). Eşit puanlı satırların sırası her çağrıda değişebiliyor —
        -- yani onarımım değil, ALTTAKİ SIRALAMA kararsız.
        --
        -- Nöbetçiyi gevşetiyorum ama kusuru SUSTURMUYORUM: aşağıda
        -- ayrıca ölçülüp NOT olarak raporlanıyor.
        select array_agg(id order by sira) into v_yeni from (
          select id, row_number() over () as sira
            from public.discover_availabilities(null,null,null,null)
           where id <> v_dusuk) z;
        if (select count(*) from unnest(array_remove(v_ham, v_dusuk)) x
             where x <> all (coalesce(v_yeni, '{}'))) > 0
           or coalesce(array_length(v_yeni,1),0) <> coalesce(array_length(v_ham,1),1) - 1 then
          v_hatalar := v_hatalar ||
            'one cikarma listeden satir DUSURDU ya da EKLEDI — sarmalayici veri kaybettiriyor'::text;
        end if;
        v_notlar := v_notlar || 'siralama davranisla olculdu'::text;

        -- 🔴 AYRI BULGU: keşif sıralaması KARARSIZ mı? Aynı sorguyu iki
        -- kez çağırıp karşılaştırıyorum. Kararsızsa sayfalama bozulur:
        -- kullanıcı 2. sayfaya geçince 1. sayfadaki ilanı tekrar görür ya
        -- da hiç görmez. Bunu bu turda DÜZELTMİYORUM (iç gövde ayrı bir
        -- sözleşme) ama sessizce de geçmiyorum.
        declare v_a uuid[]; v_b uuid[];
        begin
          select array_agg(id order by sira) into v_a from (
            select id, row_number() over () as sira
              from public.discover_availabilities(null,null,null,null)) z;
          select array_agg(id order by sira) into v_b from (
            select id, row_number() over () as sira
              from public.discover_availabilities(null,null,null,null)) z;
          if v_a is distinct from v_b then
            -- 🔴 Once iki bitisik literal yazmistim; `sql_lint` hakli olarak
            -- yakaladi. Bitisik literal SQL'de tek dizeye birlesir ama
            -- cast'in nereye bagli oldugu okuyana belirsiz kalir.
            v_notlar := v_notlar || ('UYARI: kesif siralamasi KARARSIZ (ayni sorgu iki '
                     || 'farkli sira dondurdu). Beraberlik bozucu yok; sayfalama '
                     || 'guvenilmez. Ayri bir turda ele alinmali.')::text;
          end if;
        end;
      end if;
    end;
    raise exception 'GERI_AL_243_SIRA';
  exception when others then
    if sqlerrm <> 'GERI_AL_243_SIRA' then
      v_hatalar := v_hatalar || ('siralama olcumu coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_hatalar,1) is not null then
    raise exception '243 NOBETCI: %', array_to_string(v_hatalar, ' | ');
  end if;
  raise notice '243 OK · one cikarma yaziliyor · motor cikitisi hala korumali · siralama featured i okuyor';
  -- Notlar HATA degil ama SESSIZ de kalmamali: olculemeyen ve
  -- olculup kusur bulunan seyler burada gorunur.
  if array_length(v_notlar,1) is not null then
    raise notice '243 NOTLAR · %', array_to_string(v_notlar, ' | ');
  end if;
end $n243$;

select '243 ONE CIKARMA CALISIYOR' as sonuc,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.prosrc ilike '%motor_yazimi_ac%'
           and p.proname <> 'motor_yazimi_ac')                                as bayrakli_fonksiyon,
       (select (prosrc ilike '%is_featured%')::int from pg_proc p
          join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='discover_availabilities' limit 1) as siralama_duzeldi;
