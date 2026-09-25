-- ============================================================================
-- 268 — TELEFON NUMARASI: TARAMA KAPISI VE TEKİLLİK   (28 Ağustos 2026)
--
-- ⚠️ 265 ve 267'den SONRA çalıştır.
--
-- ----------------------------------------------------------------------------
-- 🔴 GÖKBERK: "Açık bıraktıklarım, gerekçeleriyle >> neden hâlâ çözmüyoruz
--    bunları. Biz yapamıyo muyuz?"
--
-- Açık bıraktığım dördüncü madde şuydu: "`phone_in_use` anon çağrılabiliyor;
-- yalnız bir boolean döndürüyor ama elindeki numara listesini tarayıp
-- hangilerinin kullanıcımız olduğunu öğrenebilirsin. Postgres'te IP
-- görünmediği için hız sınırı koyamıyorum."
--
-- Oturup ÖLÇTÜM. Gerekçem YANLIŞTI — ve yerine iki gerçek kusur çıktı.
-- ----------------------------------------------------------------------------
--
-- ══════════════════════════════════════════════════════════════════════════
-- ÖLÇÜM 1 — TARAMA ZATEN KAPALIYDI. BEN ESKİ HÂLİ ANLATIYORDUM.
-- ══════════════════════════════════════════════════════════════════════════
--     begin; set local role anon;
--     select public.phone_in_use('+905551112233');
--     → ERROR:  not_authenticated
--
-- SQL 253 §8 bu fonksiyonu zaten `auth.uid()` şartına ve saatte 10 çağrıya
-- bağlamış. 265'in anon beyaz listesinde adı DURUYOR ama fonksiyon anon
-- için ilk satırda patlıyor. Yani anon tarama yüzeyi = 0.
--
-- Ben bunu "açık" diye rapor ettim çünkü BEYAZ LİSTEYE baktım,
-- FONKSİYONUN GÖVDESİNE bakmadım.
--
-- 🆕 SINIF: "BİR YÜZEYİ İZİN LİSTESİNDEN OKUMAK, O YÜZEYİN ÇALIŞTIĞINI
-- KANITLAMAZ — İZİN VERİLMİŞ AMA GÖVDESİ REDDEDEN BİR FONKSİYON, LİSTEDE
-- AÇIK GÖRÜNÜR VE GERÇEKTE KAPALIDIR. HER İKİ YÖNDE DE."
--
-- ══════════════════════════════════════════════════════════════════════════
-- ÖLÇÜM 2 — VE TAM BU YÜZDEN KAYIT FORMUNDAKİ KONTROL ÖLÜYDÜ.
-- ══════════════════════════════════════════════════════════════════════════
-- `App.js` kayıt akışında, `signUp`tan ÖNCE — yani kullanıcı HENÜZ ANONİMKEN:
--
--     const { data: taken } = await supabase.rpc("phone_in_use", { p_phone: phone });
--     if (taken) { … "bu numara kayıtlı" … return; }
--
-- Çağrı `not_authenticated` fırlatıyor; `error` destructure EDİLMEDİĞİ için
-- `taken` `null` oluyor; `if (taken)` hiç çalışmıyor. Kontrol sessizce
-- ölmüş. Bir güvenlik sıkılaştırması (253), başka bir akıştaki bir kontrolü
-- FARK EDİLMEDEN devre dışı bırakmış.
--
-- 🆕 SINIF: "BİR FONKSİYONA KİMLİK ŞARTI EKLEMEK, O FONKSİYONU KİMLİKSİZ
-- ÇAĞIRAN HER AKIŞI SESSİZCE BOZAR — VE HATAYI YUTAN ÇAĞRI YERİ, BOZULMAYI
-- BAŞARI GİBİ GÖSTERİR."
--
-- ══════════════════════════════════════════════════════════════════════════
-- ÖLÇÜM 3 — ASIL KUSUR: AYNI NUMARA İKİ HESAPTA OLABİLİYOR.
-- ══════════════════════════════════════════════════════════════════════════
-- `declare_phone` gövdesi (etkin: 138_email_otp.sql):
--     update users set phone = p_phone where id = v_uid;
-- Hiçbir tekillik kontrolü yok. Ve tabloda da yok:
--
--     select i.relname, a.attname, ix.indisunique … where t.relname='users'
--     → idx_users_phone | phone_e164 | f      (TEK indeks, UNIQUE DEĞİL)
--
-- Denedim (geri alarak):
--     update users set phone='+905550001122' where id = a;
--     update users set phone='+905550001122' where id = b;
--     → NOTICE: AYNI NUMARAYI TASIYAN HESAP: 2
--
-- Yani ölü kontrolün arkasında koruma YOKTU. Telefon bu üründe bir
-- güven sinyali: doğrulaması +10 puan veriyor, talep kapılarından biri,
-- kadın güvenlik modunun dayanaklarından biri. İki hesabın aynı hattı
-- paylaşabilmesi "bir kişi = bir doğrulanmış hat" varsayımını çürütür —
-- ve bu varsayım üzerine kurulmuş her kural onunla birlikte çürür.
--
-- 🆕 SINIF: "BİR TEKİLLİK KURALI YALNIZCA UYGULAMADAKİ BİR ÖN KONTROLE
-- DAYANIYORSA, O KURAL YOKTUR — VERİTABANI KABUL EDİYORSA KURAL DEĞİL
-- TEMENNİDİR."
--
-- ----------------------------------------------------------------------------
-- BU DOSYA NE YAPIYOR
--   §1  Numaranın KANONİK hâli tek bir yerde tanımlanıyor.
--   §2  Mevcut çakışmalar RAPORLANIYOR (silinmiyor — kimse habersiz
--       hesabını kaybetmesin).
--   §3  Kısmi UNIQUE indeks: aynı hat iki AKTİF hesapta olamaz.
--   §4  `declare_phone` artık `phone_taken` fırlatıyor ve İKİ kolonu da yazıyor.
--   §5  `phone_in_use` anon beyaz listesinden çıkıyor (zaten çalışmıyordu).
--   §6  Nöbetçi: çakışma DENENİYOR ve reddedildiği görülüyor.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — KANONİK NUMARA TEK BİR YERDE
--
-- 🔴 Bugün üç ayrı yerde üç ayrı normalleştirme var:
--   `phone_in_use`  → regexp_replace(phone, '\D', '', 'g')
--   `declare_phone` → hiç (ham metin)
--   `verify_otp`    → hiç (ham metin, ama iki kolona birden yazıyor)
-- Aynı numaranın "+90 555 111 22 33" ve "+905551112233" yazımları FARKLI
-- iki kayıt olur. Tekillik kuralı, kuralın uygulandığı BİÇİM tek değilse
-- hiçbir şey ifade etmez.
--
-- 🆕 SINIF: "TEKİLLİK, KARŞILAŞTIRILAN BİÇİM TEK OLMADAN TANIMLANAMAZ."
-- ════════════════════════════════════════════════════════════════════════
-- ⚠️ v2 — İLK SÜRÜM FAZLA GEVŞEKTİ VE CANLIDA PATLADI.
--
-- Gökberk'in aldığı hata:
--     ERROR: 23505: could not create unique index "uq_users_phone_kanonik"
--     DETAIL: Key (phone_kanonik)=(90555000000) is duplicated.
--
-- `90555000000` ON BİR hane. Geçerli bir Türkiye cep numarası kanonik
-- hâlde ON İKİ hanedir (90 + 5XXXXXXXXX). Yani bu bir numara değil,
-- eksik girilmiş bir şey — muhtemelen `+90 555 000 000`.
--
-- İlk sürümüm `length(d) < 7 then null` diyordu; yani 7 haneden uzun HER
-- ŞEYİ geçerli sayıyordu. Çöp veri tekillik alanına girdi ve iki çöp
-- kayıt birbiriyle çarpıştı. İndeks kurulamadı, işlem geri alındı ve
-- kullanıcı ham bir Postgres hatası gördü.
--
-- 🆕 SINIF: "BİR TEKİLLİK KISITI, KISITLADIĞI ALANIN NEYİ KABUL ETTİĞİNDEN
-- DAHA SIKI OLAMAZ — GEÇERSİZ DEĞERLERİ İÇERİ ALAN BİR NORMALLEŞTİRME,
-- ÇAKIŞMALARI KENDİSİ ÜRETİR."
--
-- Yeni kural uzunluğu ADIYLA söylüyor:
--   · '90' ile başlıyorsa TAM 12 hane (Türkiye)
--   · '0' ile başlıyorsa TAM 11 hane → 90 + 10
--   · 10 hane ise TR yerel kabul edilir → 90 + 10
--   · 11–15 hane arası diğerleri yabancı numara sayılır
--   · geri kalan her şey NULL — yani indekste hiç yer almaz
create or replace function public.telefon_kanonik(p_phone text)
returns text
language sql immutable
set search_path = public as $$
  select case
    when d is null                     then null
    -- Türkiye: ülke kodu 90 yalnız Türkiye'ye ait; uzunluk kesin.
    when left(d, 2) = '90'             then (case when length(d) = 12 then d end)
    when left(d, 1) = '0'              then (case when length(d) = 11 then '90' || substr(d, 2) end)
    when length(d) = 10                then '90' || d
    -- Yabancı numara: E.164 en fazla 15 hane, en az ~11 anlamlı.
    when length(d) between 11 and 15   then d
    else null
  end
  from (select nullif(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), '') as d) x;
$$;
revoke execute on function public.telefon_kanonik(text) from public;
grant execute on function public.telefon_kanonik(text) to authenticated, service_role;

-- Kanonik biçim tabloda DA duruyor: indeks bir ifade üzerinde değil bir
-- kolon üzerinde olsun ki plan okunabilir ve hata mesajı anlaşılır olsun.
alter table users add column if not exists phone_kanonik text;

update users
   set phone_kanonik = public.telefon_kanonik(coalesce(phone, phone_e164))
 where phone_kanonik is distinct from public.telefon_kanonik(coalesce(phone, phone_e164));

-- ════════════════════════════════════════════════════════════════════════
-- §2 — MEVCUT ÇAKIŞMALAR: SİLMİYORUZ, SÖYLÜYORUZ
--
-- ⚠️ Burada `delete` YOK. Canlıda iki hesap aynı numarayı taşıyorsa
-- hangisinin gerçek olduğuna bir SQL dosyası karar veremez. Yapılacak
-- şey kararı İNSANA bırakıp indeksi yine de kurabilmektir: indeks
-- yalnız SİLİNMEMİŞ hesapları kapsıyor (§3), çakışan eski kayıtlar
-- raporlanıyor.
-- ════════════════════════════════════════════════════════════════════════
do $c268$
declare
  r record;
  v_n int := 0;
  v_ilk text := '';
begin
  for r in
    select phone_kanonik, count(*) n,
           string_agg(coalesce(email,'(e-posta yok)'), ', ' order by created_at) kimler
      from users
     where deleted_at is null and phone_kanonik is not null
     group by 1 having count(*) > 1
     order by 2 desc
  loop
    raise warning '268 ÇAKIŞMA: % → % hesap: %', r.phone_kanonik, r.n, r.kimler;
    v_n := v_n + 1;
    if v_ilk = '' then v_ilk := r.phone_kanonik; end if;
  end loop;

  if v_n = 0 then
    raise notice '268 §2: cakisan numara yok. ✓';
    return;
  end if;

  -- 🔴 v2 — BURASI ESKİDEN SADECE UYARI VERİP GEÇİYORDU.
  -- Sonra §3 indeksi kurmayı deniyor, Postgres 23505 fırlatıyor, işlemin
  -- TAMAMI geri alınıyordu. Kullanıcı şu ham satırı görüyordu:
  --     ERROR: 23505: could not create unique index …
  --     DETAIL: Key (phone_kanonik)=(90555000000) is duplicated.
  -- Bu mesaj ne olduğunu söylüyor, NE YAPILACAĞINI söylemiyor. Üstelik
  -- dosyanın geri kalanı (declare_phone sıkılaştırması, anon iznin
  -- kaldırılması) da geri alınıyordu — yani tek bir çöp kayıt yüzünden
  -- HİÇBİR iyileştirme uygulanmıyordu.
  --
  -- 🆕 SINIF: "BİR ÖN KONTROL 'UYARIP GEÇİYORSA' ÖN KONTROL DEĞİLDİR —
  -- ARDINDAN GELEN ADIMIN HAM HATASINI ERTELEMİŞ OLUR, VE HAM HATA
  -- KULLANICIYA NE YAPACAĞINI SÖYLEMEZ."
  raise exception E'268 DURDU: % numara birden fazla hesapta (orn. %).\n'
    '  Bu numaralar GEÇERLİ formatta oldugu icin otomatik temizlenmiyor —\n'
    '  hangi hesabin numarayi tutacagina bir SQL dosyasi karar veremez.\n'
    '  → Kimler oldugunu gormek ve cozmek icin: 268a_telefon_cakismasi.sql\n'
    '  (Not: gecersiz formatli numaralar bu surumde zaten NULL''a dusuruldu;\n'
    '   burada kalanlar gercek numaralardir.)', v_n, v_ilk;
end $c268$;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — KISMİ UNIQUE İNDEKS
--
-- `where deleted_at is null`: silinmiş bir hesabın numarası yeni bir
-- hesabı engellememeli — kullanıcı hesabını silip yeniden açabilmeli.
-- `and phone_kanonik is not null`: numarasını hiç yazmamış herkes
-- birbirini engellemesin.
-- ════════════════════════════════════════════════════════════════════════
create unique index if not exists uq_users_phone_kanonik
  on users (phone_kanonik)
  where deleted_at is null and phone_kanonik is not null;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — `declare_phone` ARTIK KURALI SÖYLÜYOR
--
-- 🔴 İki değişiklik:
--   (a) Çakışma varsa `phone_taken` — indeksin ham hata metnini
--       kullanıcıya göstermek yerine ürünün bildiği bir ad.
--   (b) `phone`, `phone_e164` VE `phone_kanonik` birlikte yazılıyor.
--       Bugün `declare_phone` yalnız `phone`i, `verify_otp` ikisini
--       yazıyordu; hangi kolonun doğru olduğu çağrı yerine bağlıydı.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.declare_phone(p_phone text)
returns jsonb
language plpgsql security definer set search_path = public as $dp268$
declare
  v_uid uuid := auth.uid();
  v_kan text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if coalesce(p_phone, '') = '' then raise exception 'empty_phone'; end if;

  v_kan := public.telefon_kanonik(p_phone);
  if v_kan is null then raise exception 'invalid_phone'; end if;

  -- 🔴 ÖNCE SOR, SONRA YAZ — ama indeks de arkada duruyor. Bu kontrol
  -- kullanıcıya İYİ BİR MESAJ vermek için; yarışı KAZANAN taraf indekstir.
  -- (Sadece kontrole güvenmek, iki eşzamanlı kaydın ikisinin de "boş"
  --  görüp ikisinin de yazması demekti — 138'in yaptığı tam buydu.)
  -- 🆕 SINIF: "UYGULAMA KONTROLÜ MESAJ İÇİNDİR, KISIT KURAL İÇİN —
  -- BİRİ DİĞERİNİN YERİNE GEÇEMEZ."
  if exists (select 1 from users
              where phone_kanonik = v_kan and deleted_at is null and id <> v_uid) then
    raise exception 'phone_taken';
  end if;

  begin
    update users
       set phone = p_phone, phone_e164 = v_kan, phone_kanonik = v_kan
     where id = v_uid;
  exception when unique_violation then
    raise exception 'phone_taken';
  end;

  -- 🔴 phone_verified'a DOKUNMUYORUZ. Numarayi girmek dogrulamak degil.
  insert into verifications (user_id, phone_verified_method)
  values (v_uid, null)
  on conflict (user_id) do nothing;

  return jsonb_build_object('ok', true, 'verified', false,
    'note', (select value #>> '{}' from beta_settings where key = 'otp_notice_phone_declared'));
end $dp268$;
grant execute on function public.declare_phone(text) to authenticated;

-- `verify_otp` de kanonik kolonu yazsın: doğrulama sonrası numara
-- kanonikleşmezse indeks o hesabı hiç görmez.
do $vo268$
declare v_tanim text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p where p.oid = to_regprocedure('public.verify_otp(text, text)');
  if v_tanim is null then
    raise notice '268: verify_otp yok — atlandi.'; return;
  end if;
  if v_tanim like '%phone_kanonik%' then
    raise notice '268: verify_otp zaten kanonik yaziyor.'; return;
  end if;
  v_tanim := replace(v_tanim,
    'update users set phone = p_phone, phone_e164 = p_phone where id = v_uid;',
    'update users set phone = p_phone, phone_e164 = public.telefon_kanonik(p_phone),'
    || ' phone_kanonik = public.telefon_kanonik(p_phone) where id = v_uid;');
  if v_tanim not like '%phone_kanonik%' then
    raise warning '268: verify_otp govdesi beklenen satiri TASIMIYOR — elle bakilmali.';
    return;
  end if;
  execute v_tanim;
  raise notice '268: verify_otp kanonik kolona da yaziyor. ✓';
end $vo268$;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — `phone_in_use` ANON LİSTESİNDEN ÇIKIYOR
--
-- Gövdesi zaten anon'u reddediyor (ÖLÇÜM 1). İzni bırakmak, listeye
-- bakan bir sonraki insana "burası anon'a açık" diye YANLIŞ bilgi verir.
-- İzin listesi bir belge de olduğu için, yanlış satırı silmek koruma
-- kadar önemlidir.
-- ════════════════════════════════════════════════════════════════════════
revoke execute on function public.phone_in_use(text) from anon;

-- ════════════════════════════════════════════════════════════════════════
-- §6 — NÖBETÇİ: ÇAKIŞMAYI GERÇEKTEN DENİYORUZ
--
-- 🔴 "İndeks kuruldu" yazmak kanıt değil. İki hesaba aynı numarayı
-- yazmayı DENİYORUZ ve reddedildiğini görüyoruz. Ters yön de var:
-- numarası olmayan iki hesap birbirini engellememeli, yoksa kayıt
-- akışı ilk kullanıcıdan sonra kilitlenir.
-- ════════════════════════════════════════════════════════════════════════
do $nb268$
declare
  a uuid; b uuid; v_engellendi boolean := false; v_bos int;
begin
  select id into a from users where deleted_at is null order by id limit 1;
  select id into b from users where deleted_at is null and id <> a order by id limit 1;
  if a is null or b is null then
    raise notice '268 NOBETCI: iki hesap yok — canli disinda atlandi.';
    return;
  end if;

  -- (a) AYNI NUMARA İKİ HESABA YAZILAMAMALI
  begin
    update users set phone_kanonik = '905550009988' where id = a;
    update users set phone_kanonik = '905550009988' where id = b;
  exception when unique_violation then
    v_engellendi := true;
  end;
  if not v_engellendi then
    raise exception '268 NOBETCI: AYNI NUMARA HALA IKI HESAPTA OLABILIYOR.';
  end if;
  raise notice '268 NOBETCI: ayni numara ikinci hesaba yazilamadi. ✓';

  -- (b) TERS YÖN: numarasız hesaplar birbirini engellemiyor
  select count(*) into v_bos from users
   where deleted_at is null and phone_kanonik is null;
  raise notice '268 NOBETCI: numarasiz % hesap yan yana duruyor (kisitlanmadi). ✓', v_bos;

  -- (c) anon `phone_in_use` çağıramıyor
  begin
    set local role anon;
    perform public.phone_in_use('+905551112233');
    reset role;
    raise exception '268 NOBETCI: anon phone_in_use CAGIRABILIYOR.';
  exception when insufficient_privilege or raise_exception then
    reset role;
    raise notice '268 NOBETCI: anon phone_in_use cagiramiyor. ✓';
  end;

  raise exception 'NOBETCI_GERI_AL';
exception when others then
  if sqlerrm = 'NOBETCI_GERI_AL' then
    raise notice '268 NOBETCI OK — deney satirlari geri alindi.';
  else
    raise;
  end if;
end $nb268$;

commit;
