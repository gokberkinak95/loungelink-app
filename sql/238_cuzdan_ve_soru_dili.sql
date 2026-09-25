-- ============================================================================
-- LoungeLink · 238_cuzdan_ve_soru_dili.sql                  (22 Ağustos 2026)
--
-- İKİ METİN, İKİSİ DE SUNUCUDAN GELİYOR — İKİSİ DE DÜZELİYOR
-- (Gökberk, madde 1 ve madde 6)
--
-- ════════════════════════════════════════════════════════════════════════
-- MADDE 1 · "YAKLAŞIK 144 EUR DEĞERİNDE"
-- ════════════════════════════════════════════════════════════════════════
-- Gökberk: "cüzdanında yılda X misafir hakkı duruyor ifadesi güzel ancak
-- 144 euro gibi bir değer belirtmek doğru gelmiyor bana."
--
-- Haklı, ve sebebi tek değil — üç tane:
--
--   (1) SAYI SAVUNULAMAZ. 12 × 12 EUR = 144. Ama o 12 EUR
--       `program_plans.guest_visit_fee`den geliyor ve KART SAHİBİNİN
--       ödeyeceği ücret değil, misafirin kapıda ödediği liste fiyatı.
--       Host o parayı hiçbir zaman kazanmayacak. "144 EUR değerinde"
--       demek, kazanmayacağı bir parayı ona vaat etmektir.
--   (2) YANLIŞ VAAT ÜRETİYOR. Rakam gören kişi "bunu nakde çevirebilir
--       miyim?" diye düşünür. Cevap hayır — ve bir sonraki cümle zaten
--       "bankaya yatmıyor" diyor. Yani kendi cümlemiz kendi rakamımızı
--       çürütüyor.
--   (3) ⚠️ VE PLATFORMUN HUKUKİ DURUŞUYLA ÇELİŞİYOR. Sitede ve SSS'de
--       "LoungeLink lounge erişimi satmaz, erişim hakkının devri
--       yasaktır" diyoruz. Hakka PARA DEĞERİ biçmek, tam olarak onu bir
--       satılabilir varlık gibi göstermektir.
--
-- 🆕 SINIF: **"BİR ŞEYE FİYAT YAZMAK, ONU SATILIK İLAN ETMEKTİR."**
--
-- YERİNE NE KOYUYORUM: parayı değil, KAYBI ve KARŞILIĞI anlatan cümle.
-- Kaybın birimi para değil, HAK. Ve karşılığı ürünün gerçekten verdiği
-- şey: 3 kredi (SQL 206:81) = hakkın olmayan salonda 3 misafirlik.
--
-- ════════════════════════════════════════════════════════════════════════
-- MADDE 6 · HOST'A GİDEN SORU MESAJI
-- ════════════════════════════════════════════════════════════════════════
-- Bugünkü metin (221:223):
--     "'Lounge Sds' ilanında misafir hakkı görünmüyor ama bunu
--      doğrulayamadık. Kartında misafir hakkın var mı?"
--
-- Üç kusuru var:
--   · Host'a NE YAPMASI gerektiğini söylemiyor (soruyu cevaplasa bile
--     ilan açılmaz — hakkını BEYAN etmesi gerekiyor)
--   · Karşı tarafın kim olduğunu ve neden yazdığını söylemiyor
--   · "doğrulayamadık" ifadesi host'a bizim eksiğimizi yükleyen bir
--     ton taşıyor
--
-- ⚠️ İKİ DİL SORUNU: bu metinler SQL'de Türkçe sabit. İngilizce
-- kullanıcı, İngilizce başlığın altında Türkçe gövde görüyor.
-- `beta_settings`e taşıyorum ki hem BO'dan düzenlenebilsin hem de
-- ileride dile göre seçilebilsin.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) CÜZDAN CÜMLESİ — para yok, hak ve karşılık var
-- ----------------------------------------------------------------------------
-- sqlcheck: allow-replace host_wallet  (returns jsonb — 206/208/232 ile AYNI)
--
-- 🔴 GÖVDEYİ YENİDEN YAZMIYORUM. 208'in dönem devri hesabı ve 232'nin
-- sahiplik kapısı olduğu gibi kalmalı. Yalnız `format(...)` cümlesini
-- değiştiriyorum — hedefli, ölçülebilir bir müdahale.
do $wt$
declare
  v_govde text;
  v_yeni  text;
begin
  select pg_get_functiondef(p.oid) into v_govde
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname in ('host_wallet','host_wallet_hesap') limit 1;

  if v_govde is null then
    raise notice '238: host_wallet yok — cuzdan cumlesi degistirilemedi.';
    return;
  end if;

  -- 232'nin kapısı gövdede DURMALI; yoksa yanlış sürümü düzenliyorum.
  if v_govde not like '%cuzdan_sahibi_degil%' then
    raise exception '238: host_wallet''ta 232 kapisi YOK — once 232 calistirilmali.';
  end if;

  -- 🔴 BİREBİR METİN EŞLEŞTİRMESİ DENEDİM, TUTMADI.
  -- İlk yazımda 208'in `format(...)` çağrısını harfi harfine yazıp
  -- `replace()` ettim. Nöbetçi "hala para degeri yaziyor" dedi: girinti
  -- benim yazdığımdan farklıydı (15 boşluk, ben 9 yazmıştım) ve
  -- `pg_get_functiondef` gövdeyi HARFİ HARFİNE üretiyor.
  -- 🆕 SINIF: **"KAYNAK METNİ EZBERDEN YAZMAK, OKUMAK DEĞİLDİR."**
  -- Artık DESENLE eşleştiriyorum; girinti/satır sonu fark etmiyor.
  if v_govde !~ 'Yaklaşık %s %s değerinde' then
    -- 🔴 248'DE DÜZELTİLDİ: burada `like '%3 kredi%'` yazıyordu, yani
    -- "yeni hâl" diye ORANIN KENDİSİNİ arıyordu. SQL 246 host kredisini
    -- 3 → 1 yaptı ve 248 cümleyi ona göre güncelledi; bu satır o günden
    -- sonra "cümle yok" demeye başladı ve TEKRAR KURULUMDA 238'i
    -- patlattı. Aranan şey bir ORAN değil, CÜMLENİN VARLIĞI olmalı.
    -- 🆕 SINIF: "BİR NÖBETÇİ DEĞİŞMESİ BEKLENEN BİR DEĞERİ SABİT OLARAK
    -- ARIYORSA, O DEĞERİ DEĞİŞTİREN HERKESİ SUÇLU İLAN EDER."
    if v_govde ~ 'Ağırladığın her kişi sana \d+ kredi bırakıyor' then
      raise notice '238: cuzdan cumlesi ZATEN yeni halinde — dokunulmadi.';
      return;
    end if;
    raise notice '238: beklenen cuzdan cumlesi bulunamadi — 208 degismis olabilir. DOKUNULMADI.';
    return;
  end if;

  -- Para birimi ve tutar CÜMLEDEN çıkıyor; `toplam_deger` alanı VERİDE
  -- kalıyor (BO ve iç raporlar okusun diye). Kullanıcıya gösterilmiyor.
  v_yeni := '''Bankaya yatmıyor, devretmiyor, gelecek yıla geçmiyor — kullanılmazsa siliniyor. '
         || 'Ağırladığın her kişi sana 3 kredi bırakıyor: hakkın olmayan bir salonda üç kez misafir olursun.''';

  -- (a) Ücretli dal: format(...) çağrısının TAMAMINI düz metinle değiştir.
  -- ⚠️ İKİNCİ DENEME. `[^)]*\)[^)]*\)` yazmıştım; ifade İÇ İÇE parantez
  -- taşıyor (`round(...)`, `coalesce(...)`) ve desen format'ın kendi
  -- kapanışını yiyemedi → "mismatched parentheses". Artık bitişi AÇIKÇA
  -- söylüyorum: `coalesce(v_para,'EUR'))`.
  v_govde := regexp_replace(
    v_govde,
    'format\(''Yaklaşık[\s\S]*?coalesce\(v_para,''EUR''\)\)',
    v_yeni, 'g');

  -- (b) Ücretsiz dal: aynı cümleyi orada da kur ki iki dal AYNI ŞEYİ desin
  v_govde := replace(
    v_govde,
    '''Bankaya yatmıyor, devretmiyor — kullanılmazsa siliniyor.''',
    v_yeni);

  execute v_govde;
  raise notice '238: cuzdan cumlesinden para degeri KALDIRILDI, karsilik cumlesi kondu';
end $wt$;

-- ----------------------------------------------------------------------------
-- 2) SORU MESAJI — BO'dan düzenlenebilir metinler
-- ----------------------------------------------------------------------------
insert into beta_settings (key, value) values
  ('soru_intro_tr', to_jsonb(
    'Merhaba! “{salon}” ilanına başvurmak istiyorum ama sistemde misafir hakkın '
    'görünmüyor. Kartında misafir hakkın varsa profilinden ekleyebilir misin? '
    'Eklediğin an ilanın başvuruya açılıyor.'::text)),
  ('soru_bildirim_baslik_tr', to_jsonb('Bir yolcu ilanını soruyor ✦'::text)),
  ('soru_bildirim_govde_tr', to_jsonb(
    'Bir yolcu “{salon}” ilanına başvurmak istiyor ama kartındaki misafir hakkını '
    'henüz bilmiyoruz — bu yüzden başvuru kapalı. Profil → Lounge hakkı kaynağı '
    'ekranından kartını eklersen ilan anında başvuruya açılır ve bu yolcu '
    'başvurabilir.'::text))
on conflict (key) do update set value = excluded.value;

-- 🔴 Metni okuyan yardımcı: `ilan_kurali_sor`ın gövdesine dokunmadan
-- (223'ün takvim günü kararı korunmalı) metni dışarıdan besliyorum.
-- Tetikleyici, INSERT edilen satırın intro'sunu ayardan gelen metinle
-- değiştiriyor.
create or replace function public.trg_soru_metni()
returns trigger language plpgsql security definer set search_path = public as $sm$
declare v_salon text; v_metin text;
begin
  if new.intent is distinct from 'kural_sorusu' then return new; end if;

  select coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text)
    into v_salon
    from availabilities a
    left join lounges l on l.id = a.lounge_id
   where a.host_id = new.to_id and a.active
   order by a.avail_date asc limit 1;

  select value #>> '{}' into v_metin from beta_settings where key = 'soru_intro_tr';
  if v_metin is null then return new; end if;

  new.intro := left(replace(v_metin, '{salon}', coalesce(v_salon, 'bu')), 400);
  return new;
end $sm$;

drop trigger if exists trg_cr_soru_metni on connection_requests;
create trigger trg_cr_soru_metni before insert on connection_requests
  for each row execute function public.trg_soru_metni();

-- Host bildiriminin metni de ayardan gelsin. 235'in `trg_soru_izi`si
-- SORANA yazıyordu; bu HOST'a yazılanı düzeltiyor.
create or replace function public.trg_soru_bildirimi_host()
returns trigger language plpgsql security definer set search_path = public as $sbh$
declare v_salon text; v_b text; v_g text;
begin
  if new.intent is distinct from 'kural_sorusu' then return new; end if;

  select coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text)
    into v_salon
    from availabilities a
    left join lounges l on l.id = a.lounge_id
   where a.host_id = new.to_id and a.active
   order by a.avail_date asc limit 1;

  select value #>> '{}' into v_b from beta_settings where key='soru_bildirim_baslik_tr';
  select value #>> '{}' into v_g from beta_settings where key='soru_bildirim_govde_tr';
  if v_b is null or v_g is null then return new; end if;

  -- 221/223 zaten bir bildirim yazıyor; onun ÜSTÜNE yazmıyorum,
  -- ONU GÜNCELLİYORUM. İki bildirim, bir soru için gürültüdür.
  update notifications
     set title = v_b,
         body  = replace(v_g, '{salon}', coalesce(v_salon, 'bu'))
   where user_id = new.to_id and ref_type = 'connection' and ref_id = new.id;

  return new;
end $sbh$;

drop trigger if exists trg_cr_soru_bildirimi_host on connection_requests;
create trigger trg_cr_soru_bildirimi_host after insert on connection_requests
  for each row execute function public.trg_soru_bildirimi_host();

-- ----------------------------------------------------------------------------
-- 3) NÖBETÇİ
-- ----------------------------------------------------------------------------
do $n238$
declare
  v_para int;
  v_karsilik int;
  v_trg int;
begin
  -- (a) Cüzdan cümlesinde para değeri KALMAMALI
  select count(*) into v_para
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in ('host_wallet','host_wallet_hesap')
     and (p.prosrc like '%değerinde%' or p.prosrc like '%round(v_top_deger)%');
  if v_para <> 0 then
    raise exception '238 NOBETCI: host_wallet hala para degeri yaziyor.';
  end if;

  -- (b) Karşılık cümlesi VAR olmalı — kaldırıp yerine hiçbir şey
  --     koymamak, cümleyi zayıflatmak olurdu.
  select count(*) into v_karsilik
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in ('host_wallet','host_wallet_hesap')
     -- 248: oran ARTIK SABİT DEĞİL (bkz. yukarıdaki not). Nöbetçi
     -- cümlenin VARLIĞINI ölçüyor; oranın doğruluğunu 248 §9 ölçüyor.
     and p.prosrc ~ 'Ağırladığın her kişi sana \d+ kredi bırakıyor';
  if v_karsilik < 1 then
    raise exception '238 NOBETCI: karsilik cumlesi cuzdanda YOK.';
  end if;

  -- (c) 232'nin kapısı hâlâ yerinde mi? (Gövdeyi yeniden yazdım —
  --     yeniden yazan her müdahale bir öncekini ezebilir. 158'in dersi.)
  select count(*) into v_para
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in ('host_wallet','host_wallet_hesap')
     and p.prosrc like '%cuzdan_sahibi_degil%';
  if v_para < 1 then
    raise exception '238 NOBETCI: 232 kapisi KAYBOLDU — cuzdan cumlesini degistirirken ezdim.';
  end if;

  select count(*) into v_trg from pg_trigger
   where tgname in ('trg_cr_soru_metni','trg_cr_soru_bildirimi_host') and not tgisinternal;
  if v_trg <> 2 then
    raise exception '238 NOBETCI: soru metni tetikleyicileri bagli degil (%).', v_trg;
  end if;

  raise notice '238 OK · cuzdanda para yok · karsilik cumlesi var · 232 kapisi duruyor · metin tetikleyicileri bagli';
  raise notice '238 OLCULMEDI: metinler yalniz TURKCE. Ingilizce kullanici hala Ingilizce baslik '
               'altinda Turkce govde goruyor. Dogrusu i18n_strings uzerinden dile gore secmek; '
               'beta_settings anahtarlari `_tr` ekiyle acildi ki `_en` eklendiginde yer hazir olsun.';
end $n238$;

select '238 CUZDAN VE SORU DILI' as sonuc,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname in ('host_wallet','host_wallet_hesap')
           and p.prosrc ~ 'Ağırladığın her kişi sana \d+ kredi bırakıyor') as karsilik_cumlesi;
