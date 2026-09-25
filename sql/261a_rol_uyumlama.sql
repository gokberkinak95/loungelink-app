-- ============================================================================
-- 261a — İLANI OLUP HOST OLMAYAN HESAPLARI UYUMLA   (29 Ağustos 2026)
--
-- ⚠️ 261'DEN ÖNCE ÇALIŞTIR. 261 bunlar durdukça başlamaz.
--
-- ----------------------------------------------------------------------------
-- 🔴 GÖKBERK'E: 261'İN SANA VERDİĞİ TAVSİYE YANLIŞTI. BENİM HATAM.
--
--     ERROR: 261 DURDU: aktif ilani olup host olmayan 6 hesap var.
--            Once 055 toplu duzeltmesini kosun.
--
-- Kapının DURMASI doğru. Ama "055'i koş" tavsiyesini ben yazdım ve o
-- tavsiye BUGÜN TEHLİKELİ:
--
-- 055 iki şey yapıyor. (2) toplu rol düzeltmesi — istediğimiz bu.
-- Ama (1) `create_availability`yi 8 PARAMETRELİ olarak yeniden kuruyor.
-- Oysa SQL 215 o fonksiyonu `create_availability_base` diye yeniden
-- adlandırıp üstüne 9 parametreli (p_carrier'lı) bir sarmalayıcı koydu.
--
-- Yani 055'i bugün çalıştırmak, canlıya İKİNCİ BİR AŞIRI YÜKLEME ekler:
--     create_availability(8 parametre)   ← 055'in geri getirdiği
--     create_availability(9 parametre)   ← 215'in sarmalayıcısı
-- App 9 parametreyle çağırır, sarmalayıcıya gider, kapı çalışır gibi
-- görünür — ama ortada kimsenin denetlemediği ikinci bir giriş yolu durur.
-- Bu, 261'in kendi başlığında "ilk sürümüm yanlıştı" diye yazdığım
-- tuzağın TA KENDİSİ. Kendi uyarımı okuyup kendi hata mesajıma
-- koymamışım.
--
-- 🆕 SINIF: "ESKİ BİR GÖÇ DOSYASINI 'İÇİNDEKİ BİR PARÇA İŞE YARIYOR' DİYE
-- YENİDEN ÇALIŞTIRMAK, O DOSYANIN GERİ KALANINI DA GERİ GETİRMEKTİR —
-- GÖÇLER GERİ SARILMAZ, İLERİ YAZILIR."
--
-- Bu dosya 055'in YALNIZCA (2). maddesini yapar. Hiçbir fonksiyona
-- dokunmaz.
--
-- ----------------------------------------------------------------------------
-- 🔴 O 6 HESAP NE DURUMDA — ÖLÇÜLDÜ
--
--     with hedef as (ilanı olup host olmayanlar)
--     select (select count(*) from hedef)                        → 6
--            (select count(*) from discover_availabilities() d
--               join hedef h on h.host_id = d.host_id)           → 0
--
-- Yani bu 6 kişinin ilanı AÇIK, AKTİF ve KİMSE GÖREMİYOR. Keşif kapısı
-- (`discover_availabilities`) zaten `role='host'` istiyor. İlanı açtılar,
-- ürün "tamam" dedi, ilan hiçbir yerde listelenmedi ve kimse onlara
-- bunu söylemedi.
--
-- 🆕 SINIF: "BİR KAYIT OLUŞTURULUP HİÇBİR OKUMA YOLUNDA GÖRÜNMÜYORSA, O
-- BİR VERİ DEĞİL BİR SESSİZ BAŞARISIZLIKTIR."
--
-- Yani bu uyumlama bir 'temizlik' değil: 6 kişinin görünmeyen ilanını
-- GÖRÜNÜR yapıyor. Rolü değiştirmek onların niyetini geri vermek oluyor —
-- ilanı zaten onlar açtı.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — ÖNCE KİMLER OLDUĞUNU YAZ (kalıcı kayıt)
--
-- 🔴 Rol değiştiren bir işlem, KİMİN rolünü değiştirdiğini bırakmadan
-- çalışmamalı. Yarın "benim rolüm neden host?" diye soran biri olursa
-- cevabı burada durur.
-- ════════════════════════════════════════════════════════════════════════
create table if not exists rol_uyumlama_kaydi (
  user_id     uuid primary key,
  eski_rol    text not null,
  yeni_rol    text not null,
  aktif_ilan  int  not null,
  sebep       text not null,
  yapildi_at  timestamptz not null default now()
);

insert into rol_uyumlama_kaydi (user_id, eski_rol, yeni_rol, aktif_ilan, sebep)
select u.id, u.role, 'host',
       (select count(*) from availabilities a2 where a2.host_id = u.id and a2.active),
       '261a: aktif ilani var, kesif kapisi role=host istiyordu, ilani gorunmuyordu'
  from users u
 where u.role = 'guest'
   and exists (select 1 from availabilities a where a.host_id = u.id and a.active)
   and not exists (select 1 from host_applications ha
                    where ha.user_id = u.id and ha.status = 'approved')
on conflict (user_id) do nothing;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — YALNIZ `guest` TERFİ EDER
--
-- ⚠️ 055'in toplu düzeltmesi `where role <> 'host'` diyordu — yani
-- `admin` ve `staff` hesapları da host'a çeviriyordu. 055'in kendi notu
-- bunu itiraf ediyor: "BO v1.20 staff hesabının rolünü 'admin' yaptı".
-- Aynı `<>` ifadesini bugün çalıştırmak bir yöneticiyi sessizce
-- rolünden edebilir.
--
-- 🆕 SINIF: "BİR TOPLU GÜNCELLEMEDE 'ŞUNA EŞİT DEĞİLSE' YAZMAK, HENÜZ
-- VAR OLMAYAN ROLLERİ DE KAPSAMINA ALIR — DEĞİŞTİRECEĞİN ŞEYİ ADIYLA
-- SÖYLE."
--
-- Bu yüzden burada `= 'guest'` var. Başka bir rolde takılan varsa §4
-- onu RAPORLAR ve dosyayı durdurur; kararı insan verir.
-- ════════════════════════════════════════════════════════════════════════
update users u
   set role = 'host'
 where u.role = 'guest'
   and exists (select 1 from availabilities a where a.host_id = u.id and a.active)
   and not exists (select 1 from host_applications ha
                    where ha.user_id = u.id and ha.status = 'approved');

-- ════════════════════════════════════════════════════════════════════════
-- §3 — GÜVEN PUANI TAZELE
--
-- Rol değişti; `recompute_trust` rolü okuyan bileşenler taşıyor. Puanı
-- yeniden hesaplamazsak BO ve app farklı şey gösterir.
-- ════════════════════════════════════════════════════════════════════════
select public.recompute_trust(user_id) from rol_uyumlama_kaydi;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — NÖBETÇİ: 261'İN KAPISI ARTIK AÇILIYOR MU
--
-- 🔴 261'in ÖN KONTROL 1'inin AYNI sorgusu. Aynısı olmalı: farklı bir
-- sorguyla "düzeldi" demek, 261'i yine durduran bir düzeltme yapmaktır.
-- ════════════════════════════════════════════════════════════════════════
do $nb261a$
declare
  v_kalan int;
  v_guest int;
  r record;
begin
  select count(distinct a.host_id) into v_kalan
    from availabilities a
    join users u on u.id = a.host_id
   where a.active
     and u.role <> 'host'
     and not exists (select 1 from host_applications ha
                      where ha.user_id = u.id and ha.status = 'approved');

  if v_kalan = 0 then
    raise notice '261a NOBETCI OK: 261 artik calisabilir (kalan 0).';
    raise notice '261a: % hesap host yapildi (kayit: rol_uyumlama_kaydi).',
      (select count(*) from rol_uyumlama_kaydi);
    return;
  end if;

  -- Kalan varsa: `guest` OLMAYAN roller. Bunları otomatik değiştirmiyorum.
  raise warning '261a: % hesap HALA kapinin disinda ve hicbiri guest degil:', v_kalan;
  for r in
    select u.id, u.role, u.email,
           (select count(*) from availabilities a2 where a2.host_id=u.id and a2.active) n
      from users u
     where u.role <> 'host' and u.role <> 'guest'
       and exists (select 1 from availabilities a where a.host_id=u.id and a.active)
       and not exists (select 1 from host_applications ha
                        where ha.user_id=u.id and ha.status='approved')
  loop
    raise warning '   % · rol=% · % aktif ilan · %', r.id, r.role, r.n, r.email;
  end loop;
  raise exception '261a DURDU: yukaridaki hesaplarin rolu ELLE karara baglanmali. '
                  'Secenekler: (a) rolumu_sec(''host'') ile host yap, '
                  '(b) ilanlarini pasife al, (c) onayli host_applications kaydi ac.';
end $nb261a$;

commit;

-- ----------------------------------------------------------------------------
-- ÇIKTI: kimin rolü değişti (Supabase sonuç sekmesinde tablo olarak görünür)
-- ----------------------------------------------------------------------------
select k.user_id      as "hesap",
       u.email        as "e-posta",
       k.eski_rol     as "eski rol",
       k.yeni_rol     as "yeni rol",
       k.aktif_ilan   as "aktif ilan",
       k.yapildi_at   as "ne zaman"
  from rol_uyumlama_kaydi k
  join users u on u.id = k.user_id
 order by k.yapildi_at desc, u.email;
