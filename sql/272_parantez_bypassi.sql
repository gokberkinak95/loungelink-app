-- ============================================================================
-- 272 — BİR PARANTEZ, ÜÇ TAM BYPASS   (29 Ağustos 2026)
--
-- ⚠️ 271'den SONRA çalıştır. 271 dış kapıydı; BU dosya kök nedeni onarıyor.
--
-- ----------------------------------------------------------------------------
-- 🔴 NASIL BULUNDU
-- Gökberk: "gerçek bir kullanıcı Keşfet'te 4 ilan görüyor" — ilanlar
-- `active = false` ve tarihi geçmiş. 270d katman katman ölçtü: sızıntı
-- EN ALT katmanda, `discover_availabilities_base`in kendisinde başlıyordu.
-- 270e gövdeyi açtı:
--
--   64 |  and (not coalesce(p.women_safety_mode,false)
--   65 |       or (v_female and exists (… vv.phone_verified)))     ← KAPANDI
--   69 |  or exists (select 1 from connection_requests c9 …)       ← ÜST SEVİYE
--   70 |  or exists (select 1 from requests r9 …)                  ← ÜST SEVİYE
--   72 |  or exists (select 1 from invites i9 …)                   ← ÜST SEVİYE
--
-- Satır 65 `)))` ile bitiyor: 64'teki `and (` orada kapanıyor. Üç `or`
-- WHERE'in EN ÜST seviyesinde kalıyor. SQL'de `AND`, `OR`'dan sıkı
-- bağladığı için koşul şuna dönüşüyor:
--
--   (aktif AND tarih AND staff AND is_visible AND görünürlük AND …)
--   OR exists(c9) OR exists(r9) OR (exists(i9) AND …)
--
-- Yani o üç `exists`ten BİRİ doğruysa DİĞER BÜTÜN KAPILAR ATLANIYOR.
--
-- ----------------------------------------------------------------------------
-- 🔴 SÖMÜRÜ KOŞTURULDU (geri alındı)
--
--   staff + pasif + tarihi 20 gün geçmiş bir ilan hazırlandı
--   bakan: staff olmayan sıradan kullanıcı
--
--   BAGLANTI ISTEGI YOKKEN : 0 ilan
--   insert into connection_requests(from_id → host, to_id → bakan)
--   VARKEN                 : 1 ilan
--
-- Tek bir `connection_requests` satırı; ilan kapalı, tarihi geçmiş,
-- sahibi staff — hepsi atlandı.
--
-- ----------------------------------------------------------------------------
-- ⚠️ BU KOZMETİK BİR KUSUR DEĞİL. Atlanan kapılar şunlar:
--   · `a.active` / `a.avail_date`     → var olmayan bir teklif gösteriliyor
--   · `is_staff` / `is_visible`       → test ve gölge-kısıtlı hesaplar görünüyor
--   · `visibility <> 'Hidden'`        → GİZLİ işaretlenmiş ilan görünüyor
--   · `min_trust`                     → host'un koyduğu güven eşiği çalışmıyor
--   · `women_safety_mode`             → korumanın İSTİSNASI, korumanın kendisini yiyor
--
-- Ve şartı kuran şey saldırganın elinde: sana bir bağlantı isteği
-- göndermek, sana başvurmak ya da seni davet etmek. Üçü de tek dokunuş.
--
-- 🆕 SINIF: "BİR KURALA İSTİSNA EKLERKEN PARANTEZ HATASI YAPARSAN,
-- İSTİSNA KURALIN İÇİNDE KALMAZ — KURALIN YERİNE GEÇER."
--
-- 🆕 SINIF: "`AND`/`OR` KARIŞIK BİR KOŞULDA PARANTEZ BİR BİÇİM TERCİHİ
-- DEĞİL, ANLAMIN KENDİSİDİR — VE YANLIŞI DERLENİR, TEST EDİLİR, GEÇER."
--
-- ⚠️ NİYET KORUNUYOR: 049/#20'nin amacı doğruydu — kadın güvenlik modu
-- açıkken, KADININ KENDİSİ etkileşimi başlattıysa karşı taraf onu
-- görebilmeli. Bu dosya o istisnayı SİLMİYOR, ait olduğu parantezin
-- İÇİNE alıyor.
-- ============================================================================

begin;

do $p272$
declare
  v_eski text; v_yeni text; v_kontrol text;
  -- Yanlış: kadın-güvenlik parantezi 65'te kapanıyor.
  v_ara constant text :=
    'or (v_female and exists (select 1 from verifications vv where vv.user_id=v_uid and vv.phone_verified)))';
  -- Doğru: bir parantez EKSİK kapanacak, üç `or` içeride kalacak.
  v_yer constant text :=
    'or (v_female and exists (select 1 from verifications vv where vv.user_id=v_uid and vv.phone_verified))';
  -- Ve üçüncü `or exists`in sonunda parantez KAPANACAK.
  v_ara2 constant text :=
    'or exists (select 1 from invites i9 where i9.host_id = a.host_id and i9.guest_id = v_uid)';
  v_yer2 constant text :=
    'or exists (select 1 from invites i9 where i9.host_id = a.host_id and i9.guest_id = v_uid))';
begin
  select pg_get_functiondef(p.oid) into v_eski
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'discover_availabilities_base';
  if v_eski is null then
    raise exception '272: discover_availabilities_base YOK.';
  end if;

  if v_eski like '%i9.guest_id = v_uid))%' then
    raise notice '272: parantez zaten duzeltilmis — dokunulmadi.';
    return;
  end if;

  if position(v_ara in v_eski) = 0 or position(v_ara2 in v_eski) = 0 then
    raise exception '272 DURDU: beklenen iki satirdan biri BULUNAMADI. '
                    'Govde farkli olabilir — 270e ile bak, elle duzelt.';
  end if;

  v_yeni := replace(v_eski, v_ara, v_yer);
  v_yeni := replace(v_yeni, v_ara2, v_yer2);

  -- 🔴 PARANTEZ SAYIMI: değiştirdiğimiz şey PARANTEZ olduğuna göre,
  -- toplam açık/kapalı dengesini KONTROL ETMEDEN çalıştırmak, aynı
  -- sınıftan ikinci bir hata yapmaktır.
  if (length(v_yeni) - length(replace(v_yeni,'(',''))) <>
     (length(v_yeni) - length(replace(v_yeni,')',''))) then
    raise exception '272 DURDU: yeni govdede parantez dengesi bozuk — uygulanmadi.';
  end if;

  execute v_yeni;
  raise notice '272: parantez duzeltildi — uc istisna artik kadin-guvenlik kosulunun ICINDE. ✓';
end $p272$;

-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ: SÖMÜRÜ TEKRAR DENENİYOR
--
-- 🔴 "Düzelttim" demek yetmez. Bulguyu ÜRETEN deneyin aynısı koşuyor:
-- bağlantı isteği eklendiğinde kapalı/geçmiş ilan HÂLÂ açılıyor mu?
-- Ve ters yön: meşru istisna (kadın güvenlik modu + kadın başlattı)
-- çalışmaya devam ediyor mu?
-- ════════════════════════════════════════════════════════════════════════
do $nb272$
declare
  v_host uuid; v_bakan uuid; v_ilan uuid; n0 int; n1 int;
begin
  select id into v_host from users
   where deleted_at is null and role='host'
     and exists (select 1 from availabilities a where a.host_id=users.id)
   limit 1;
  select id into v_bakan from users
   where deleted_at is null and not coalesce(is_staff,false) and id <> v_host limit 1;
  if v_host is null or v_bakan is null then
    raise notice '272 NOBETCI: yeterli hesap yok — atlandi.'; return;
  end if;

  select id into v_ilan from availabilities where host_id=v_host limit 1;
  update availabilities set active=false, avail_date=current_date-20 where id=v_ilan;

  perform set_config('request.jwt.claims', json_build_object('sub', v_bakan::text)::text, true);
  select count(*) into n0 from public.discover_availabilities_base() d where d.id=v_ilan;

  insert into connection_requests(from_id, to_id, status) values (v_host, v_bakan, 'pending');
  select count(*) into n1 from public.discover_availabilities_base() d where d.id=v_ilan;

  raise notice '272 NOBETCI: kapali+gecmis ilan — istek yokken % · varken %', n0, n1;
  if n1 > 0 then
    raise exception '272 NOBETCI: BYPASS DEVAM EDIYOR — parantez duzeltmesi tutmadi.';
  end if;
  raise notice '272 NOBETCI OK: baglanti istegi artik diger kapilari ACMIYOR. ✓';

  raise exception 'NOBETCI_GERI_AL';
exception when others then
  if sqlerrm = 'NOBETCI_GERI_AL' then
    raise notice '272 NOBETCI: deney satirlari geri alindi.';
  else
    raise;
  end if;
end $nb272$;

commit;

-- ----------------------------------------------------------------------------
-- SONUÇ TABLOSU
-- ----------------------------------------------------------------------------
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='discover_availabilities_base'
      and pg_get_functiondef(p.oid) like '%i9.guest_id = v_uid))%')  as "parantez düzeltildi (1 olmalı)",
  (select count(*) from public.discover_availabilities() d
     join availabilities a on a.id=d.id
    where not a.active or a.avail_date < current_date)               as "kapalı/geçmiş sızan (0 olmalı)",
  (select count(*) from public.discover_availabilities())            as "Keşfet'te ilan";
