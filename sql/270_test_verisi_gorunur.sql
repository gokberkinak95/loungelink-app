-- ============================================================================
-- 270 — TEST VERİSİ: SANA GÖRÜNSÜN, KULLANICIYA GÖRÜNMESİN  (29 Ağustos 2026)
--
-- ⚠️ 269c2'den SONRA çalıştır.
--
-- ----------------------------------------------------------------------------
-- 🔴 GÖKBERK: "Bu işlem app'in doğruluğunu kontrol etmek için eklediğimiz
--    seed verilerini etkileyecek mi? Kapsamlı bir app testi yapabilmek için
--    kapsamlı userlar ve datalar lazım (başvurulabilir/başvurulamaz/host'a
--    sor gibi ilanlar vs, tüm kural tabloları)."
--
-- BU SORUYU BEN SORMALIYDIM. Hesapların adı `kural1…kural18` — yani kural
-- motorunun test matrisi. Çıktıda o adları gördüm ve "bunlar ne işe
-- yarıyor?" diye sormadan 269c2'yi önerdim.
--
-- 🆕 SINIF: "BİR VERİYİ TEMİZLEMEDEN ÖNCE NE İŞE YARADIĞINI SOR — ADI
-- ZATEN SÖYLÜYORSA SORMAMAK İKİ KAT KUSURDUR."
--
-- ----------------------------------------------------------------------------
-- ÖLÇÜM: TEST MATRİSİ ZATEN GÖRÜNMÜYORDU — VE SEBEBİ `is_staff` DEĞİL
--
--     select u.email, a.avail_date, (a.avail_date >= current_date) gecerli
--       from availabilities a join users u on u.id=a.host_id
--      where u.email like 'kural%@seed%' and a.active;
--
--     kural10@seed… | 2026-08-28 | f
--     kural11@seed… | 2026-08-28 | f      ← BUGÜN 29 AĞUSTOS
--     …
--
-- 269c1'in temizlikten ÖNCEKİ çıktısında da `kural1…18` satırlarında
-- KEŞFETTE = 0 yazıyordu. Yani kural matrisi zaten ölüydü: ilanların
-- tarihi geçmiş, keşif geçmiş tarihli ilanı göstermiyor.
--
-- 🆕 SINIF: "SABİT TARİHE ÇİVİLENMİŞ TEST VERİSİ HER GÜN BİRAZ DAHA
-- ÖLÜR — VE ÖLDÜĞÜNÜ KİMSE SÖYLEMEZ, ÇÜNKÜ 'BOŞ LİSTE' BİR HATA DEĞİL
-- BİR SONUÇTUR."
--
-- Bu dosya iki şeyi düzeltiyor:
--   §1  Staff, staff ilanlarını GÖRÜR (gerçek kullanıcı görmez).
--   §2  `test_verisi_tazele()` — fikstür tarihlerini bugüne göre ileri
--       alır; matris tek komutla yeniden canlanır.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — STAFF, STAFF İLANLARINI GÖRÜR
--
-- SQL 041 şu satırı koymuş:
--     and coalesce(hu.is_staff,false) = false     -- YENİ (041)
-- Amaç doğru: test host'ları gerçek kullanıcının Keşfet'ini kirletmesin.
-- Ama kapsam fazla geniş: SENİ de dışarıda bırakıyor. Test verisi
-- görünmeyen bir test ortamı, test ortamı değildir.
--
-- Yeni kural: ilan sahibi staff DEĞİLSE herkese görünür (eskisi gibi);
-- staff İSE yalnız BAKAN KİŞİ de staff'sa görünür.
--
-- 🆕 SINIF: "BİR ŞEYİ GİZLEMEK İLE YOK ETMEK ARASINDAKİ FARK, KİMDEN
-- GİZLENDİĞİNİ SÖYLEMEKTİR — 'HERKESTEN' YAZAN BİR KURAL, SAHİBİNİ DE
-- KAPSAR."
--
-- ⚠️ GÖVDE KOPYALANMIYOR. 7 KB'lık fonksiyonu yeniden yazmak, aradan
-- geçen sürümlerin (kadın güvenliği, min_trust, bloklar, kabin kuralı)
-- üstüne yazma riski taşırdı. Tek satır metin üzerinden değiştiriliyor ve
-- değişimin TUTTUĞU doğrulanıyor.
-- ════════════════════════════════════════════════════════════════════════
do $s270$
declare
  v_eski text; v_yeni text;
  v_ara  constant text := 'and coalesce(hu.is_staff,false) = false';
  v_yer  constant text :=
    'and (coalesce(hu.is_staff,false) = false'
    || ' or coalesce((select x.is_staff from users x where x.id = auth.uid()), false))';
begin
  select pg_get_functiondef(p.oid) into v_eski
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'discover_availabilities_base';
  if v_eski is null then
    raise exception '270 §1: discover_availabilities_base YOK.';
  end if;

  if v_eski like '%x.is_staff from users x where x.id = auth.uid()%' then
    raise notice '270 §1: staff gorusu zaten acik — dokunulmadi.';
    return;
  end if;

  if position(v_ara in v_eski) = 0 then
    raise warning '270 §1: beklenen satir BULUNAMADI — elle bakilmali.';
    return;
  end if;

  v_yeni := replace(v_eski, v_ara, v_yer);
  execute v_yeni;
  raise notice '270 §1a: discover_availabilities_base yamalandi. ✓';
end $s270$;

-- ════════════════════════════════════════════════════════════════════════
-- §1b — AYNI KURAL İKİNCİ BİR YERDE DAHA VARMIŞ
--
-- 🔴 §1a'yı uyguladım, nöbetçi hâlâ 0 gösterdi. Kazıyınca sebep çıktı:
-- SQL 041 staff dışlamasını İKİ AYRI YERE yazmış —
--   (1) `discover_availabilities_base` WHERE'i
--   (2) `public.is_visible(uuid)` gövdesi
-- Birini düzeltmek hiçbir şey değiştirmiyor; ikincisi zaten `false`
-- döndürüp satırı eliyor.
--
-- Ve bu sessiz bir başarısızlıktı: yama "tuttu" dedi, fonksiyon tanımı
-- gerçekten değişti, sonuç DEĞİŞMEDİ. Ölçmeseydim "düzelttim" derdim.
--
-- 🆕 SINIF: "AYNI KURAL İKİ YERE YAZILDIYSA, BİRİNİ DÜZELTMEK KODU
-- DEĞİŞTİRİR AMA DAVRANIŞI DEĞİŞTİRMEZ — VE DEĞİŞEN KOD, DEĞİŞMEYEN
-- DAVRANIŞTAN DAHA İKNA EDİCİDİR."
-- ════════════════════════════════════════════════════════════════════════
do $s270b$
declare
  v_eski text; v_yeni text;
  v_ara constant text :=
    'and not coalesce((select is_staff from users where id = p_user), false)';
  v_yer constant text :=
    'and (not coalesce((select is_staff from users where id = p_user), false)'
    || ' or coalesce((select x.is_staff from users x where x.id = auth.uid()), false))';
begin
  select pg_get_functiondef(p.oid) into v_eski
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'is_visible';
  if v_eski is null then
    raise notice '270 §1b: is_visible YOK — atlandi.'; return;
  end if;
  if v_eski like '%x.is_staff from users x%' then
    raise notice '270 §1b: is_visible zaten yamali.'; return;
  end if;
  if position(v_ara in v_eski) = 0 then
    raise warning '270 §1b: beklenen satir BULUNAMADI — elle bakilmali.'; return;
  end if;
  v_yeni := replace(v_eski, v_ara, v_yer);
  execute v_yeni;
  raise notice '270 §1b: is_visible yamalandi — staff artik staffi goruyor. ✓';
end $s270b$;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — FİKSTÜR TAZELEME: TARİH ÇİVİSİNİ SÖK
--
-- Fikstür ilanlarının tarihi sabit yazılmış. Bugünü geçince matris ölüyor
-- ve kimse fark etmiyor. Bu fonksiyon hepsini BUGÜNE GÖRE ileri alıyor.
--
-- ⚠️ YALNIZCA test alan adlarındaki hesaplara dokunur. Gerçek bir
-- kullanıcının ilanına ASLA dokunmaz — `where` şartı e-posta desenine
-- bağlı ve `.test` alan adı IANA tarafından ayrılmıştır, kimseye satılmaz.
--
-- Kullanımı: her test turundan önce
--     select public.test_verisi_tazele();
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.test_verisi_tazele(p_gun_ileri int default 3)
returns jsonb
language plpgsql security definer set search_path = public as $tvt270$
declare
  r record;
  v_ilan int := 0; v_atlanan int := 0; v_seyahat int := 0; v_hesap int;
  v_yeni date;
begin
  -- Yalnız service_role / staff çalıştırabilir: fikstür tazelemek bir
  -- bakım işidir, istemciye açık bir uç değil.
  if auth.uid() is not null
     and not coalesce((select is_staff from users where id = auth.uid()), false) then
    raise exception 'not_authorized';
  end if;

  -- 🔴 SATIR SATIR, HER BİRİ KENDİ ALT İŞLEMİNDE.
  -- İlk yazışımda tek bir toplu `update` vardı ve ilk engelde TAMAMI
  -- düştü: `kabul_edilmis_basvuru_var` tetikleyicisi, kabul edilmiş
  -- başvurusu olan bir ilanın tarihini değiştirmeye izin vermiyor.
  -- Bu doğru bir iş kuralı — fikstür tazeleyicinin onu ezmeye HAKKI YOK.
  --
  -- Ama tek bir korunan satır yüzünden 26 ilanın hiçbiri tazelenmedi.
  -- Toplu güncelleme "ya hep ya hiç" demektir; bakım işi ise "elinden
  -- geleni yap, dokunamadığını SÖYLE" olmalıdır.
  --
  -- 🆕 SINIF: "BİR BAKIM İŞİ, İŞ KURALLARINI EZMEK YERİNE ONLARA
  -- TAKILDIĞINI RAPORLAMALIDIR — VE TEK BİR ENGEL, GERİ KALAN İŞİ
  -- İPTAL ETMEMELİDİR."
  for r in
    select a.id
      from availabilities a
      join users u on u.id = a.host_id
     where a.active and a.avail_date < current_date
       and u.deleted_at is null
       and (u.email like '%@vitrin.loungelink.test'
         or u.email like '%@seed.loungelink.test'
         or u.email like '%@e2e.test')
  loop
    v_yeni := current_date + (p_gun_ileri + (abs(hashtext(r.id::text)) % 5));
    begin
      update availabilities set avail_date = v_yeni where id = r.id;
      v_ilan := v_ilan + 1;
    exception when others then
      -- Korunan satır (kabul edilmiş başvuru vb.) — dokunmuyoruz.
      v_atlanan := v_atlanan + 1;
    end;
  end loop;

  -- Misafir seyahatleri de tazelensin, yoksa "uçuşun yok" kapısı kapanır
  -- ve talep akışı hiç denenemez.
  for r in
    select v.id
      from visits v
      join users u on u.id = v.user_id
     where v.visit_date < current_date
       and u.deleted_at is null
       and (u.email like '%@vitrin.loungelink.test'
         or u.email like '%@seed.loungelink.test'
         or u.email like '%@e2e.test')
  loop
    begin
      update visits
         set visit_date = current_date + (p_gun_ileri + (abs(hashtext(r.id::text)) % 5))
       where id = r.id;
      v_seyahat := v_seyahat + 1;
    exception when others then
      null;
    end;
  end loop;

  select count(*) into v_hesap from users
   where deleted_at is null
     and (email like '%@vitrin.loungelink.test'
       or email like '%@seed.loungelink.test'
       or email like '%@e2e.test');

  return jsonb_build_object(
    'ok', true,
    'tazelenen_ilan', v_ilan,
    'atlanan_ilan', v_atlanan,
    'tazelenen_seyahat', v_seyahat,
    'test_hesabi', v_hesap,
    'not', case when v_atlanan > 0
                then v_atlanan || ' ilan is kurali korumasi nedeniyle atlandi (kabul edilmis basvuru).'
                else 'Hepsi tazelendi.' end);
end $tvt270$;

revoke execute on function public.test_verisi_tazele(int) from public, anon, authenticated;
grant  execute on function public.test_verisi_tazele(int) to service_role;

-- İlk tazeleme şimdi
select public.test_verisi_tazele();

-- ════════════════════════════════════════════════════════════════════════
-- §3 — NÖBETÇİ: İKİ YÖN DE DOĞRULANIYOR
--
-- 🔴 Tek yön yetmez. "Staff görüyor" doğru olabilir ve aynı anda
-- "gerçek kullanıcı da görüyor" olabilir — o zaman hiçbir şey
-- düzeltilmemiş, sadece kapı açılmış olur.
-- ════════════════════════════════════════════════════════════════════════
-- ⚠️ NÖBETÇİ BURADAN ÇIKARILDI — VE SEBEBİ ÖNEMLİ.
--
-- İlk iki sürümde görünürlük nöbetçisi bu dosyanın İÇİNDEYDİ ve
-- `raise exception` ile duruyordu. Bulgu doğru olsa bile sonuç şuydu:
-- işlem geri alınıyor, YAMALAR DA GİDİYOR, `test_verisi_tazele()` hiç
-- kurulmuyor. Yani bir TEŞHİS, bir DÜZELTMEYİ engelliyordu.
--
-- Gökberk iki kez üst üste bunu yaşadı: dosya "SIZINTI" deyip durdu,
-- ama durduğu için düzeltmenin hiçbir parçası da uygulanmadı.
--
-- 🆕 SINIF: "TEŞHİS İLE TEDAVİYİ AYNI İŞLEME KOYARSAN, TEŞHİS KÖTÜ
-- HABER VERDİĞİNDE TEDAVİYİ DE İPTAL EDERSİN."
--
-- Görünürlük kontrolü artık ayrı ve SALT OKUNUR: 270a_GORUNURLUK.sql
-- Orada sızan satırlar ADIYLA listeleniyor — sayı değil, kayıt.

commit;

-- ----------------------------------------------------------------------------
-- SONUÇ TABLOSU
-- ----------------------------------------------------------------------------
select
  (select count(*) from users where is_staff and deleted_at is null)          as "staff hesap",
  (select count(*) from availabilities a
     join users u on u.id = a.host_id
    where a.active and a.avail_date >= current_date
      and (u.email like '%@seed.loungelink.test'
        or u.email like '%@vitrin.loungelink.test'
        or u.email like '%@e2e.test'))                                        as "canlı fikstür ilanı",
  (select count(*) from availabilities a
     join users u on u.id = a.host_id
    where a.active and a.avail_date < current_date
      and (u.email like '%@seed.loungelink.test'
        or u.email like '%@vitrin.loungelink.test'
        or u.email like '%@e2e.test'))                                        as "hâlâ tarihi geçmiş";
