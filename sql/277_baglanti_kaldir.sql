-- ============================================================
-- LoungeLink · sql/277_baglanti_kaldir.sql
-- 30 Ağustos 2026
--
-- BAĞLANTIYI KALDIRMA — ÜRÜNDE HİÇ YOKTU.
--
-- 🔴 Gökberk sordu: "kullanıcı bağlantı kurabiliyor ancak rahatsız
-- olduğu bir bağlantıyı kaldırabilmeli de."
--
-- Ölçtüm: `connection_requests` üstünde beş fonksiyon var
-- (send_connection · baglanti_istekleri · my_connections ·
-- home_connections · baglanti_sohbeti_ac) ve HİÇBİRİ geri almıyor.
-- Enum'da `blocked` duruyor ama onu yazan tek bir çağrı yolu yok.
--
-- Yani ürün bir ilişkiyi kurmayı biliyor, bitirmeyi bilmiyordu. Bu
-- bir eksik özellik değil, bir GÜVENLİK açığı: rahatsız olan kişinin
-- elindeki tek araç "rapor et"ti — yani başkasını suçlamadan geri
-- çekilmenin yolu yoktu.
--
-- 🆕 SINIF: "BİR İLİŞKİYİ KURAN HER ÜRÜN ONU BİTİRMEYİ DE SUNMAK
-- ZORUNDADIR — ÇIKIŞI OLMAYAN BİR BAĞ, BAĞ DEĞİL TUZAKTIR."
--
-- ── TASARIM KARARLARI ──────────────────────────────────────────
--
-- 1) SESSİZ. Karşı tarafa bildirim GİTMEZ. Sebep: "X seni bağlantıdan
--    çıkardı" bildirimi, kaldırma eylemini bir ÇATIŞMAYA çevirir ve
--    insanlar o yüzden kaldırmaz. Takipten çıkmak sessizdir; şikâyet
--    gürültülüdür. İkisi ayrı araç.
--
-- 2) SUÇLAMA YOK. `blocked` DEĞİL, yeni bir durum kullanılmıyor:
--    kayıt `declined`a çekiliyor. `blocked` engelleme/rapor yolunun
--    ileride kullanacağı durum olarak BOŞ bırakılıyor — iki farklı
--    niyeti aynı değere yazmak, ikisini de okunamaz yapar.
--
-- 3) AKTİF OTURUM VARSA REDDEDİLİR. İki kişi şu anda bir salonda
--    birlikteyse bağlantıyı koparmak sohbeti de kapatır ve
--    buluşmanın ortasında koordinasyonu keser. Önce oturum iptal
--    edilir; hata kodu bunu AÇIKÇA söyler.
--
-- 4) GERİ ALINABİLİR. Kaldırılan bağlantı yeniden istenebilir
--    (`send_connection` `declined` kaydın üstüne yazabiliyor).
--    Kalıcı ayrılık isteyen kişi engelleme/rapor yolunu kullanır.
-- ============================================================

-- ── ÖNCE KOLON ────────────────────────────────────────────────
-- 🔴 `chat_channels.active` diye bir kolon YOKTU. Fonksiyonu yazarken
-- varmış gibi davrandım; aşağıdaki nöbetçi bunu yakaladı ve migration
-- baştan patladı. PL/pgSQL bir kolonun yokluğunu ancak ÇALIŞMA ANINDA
-- görür — yani nöbetçi olmasaydı fonksiyon kurulur, ilk çağrıda
-- "column active does not exist" ile düşer ve kullanıcı "bağlantıyı
-- kaldıramıyorum" derdi.
--
-- 🆕 SINIF: "BİR NÖBETÇİYİ, DENETLEDİĞİ VARSAYIMI KENDİM YAPARKEN
-- YAZARSAM ONU İLK BEN ÇARPARIM — VE BU, NÖBETÇİNİN ÇALIŞTIĞININ
-- KANITIDIR."
alter table chat_channels
  add column if not exists active boolean not null default true;

comment on column chat_channels.active is
  'false ise kanal kapalı: bağlantı kaldırıldı ya da oturum bitti. '
  'Mesajlar SİLİNMEZ — şikâyet hâlinde delil olarak durur.';

create or replace function public.baglanti_kaldir(p_conn_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_conn   connection_requests%rowtype;
  v_other  uuid;
  v_aktif  int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_conn from connection_requests where id = p_conn_id;
  if not found then
    raise exception 'connection_not_found';
  end if;

  -- Yalnız tarafları kaldırabilir. `security definer` olduğu için bu
  -- kontrol ŞART: RLS burada devre dışı.
  if v_uid <> v_conn.from_id and v_uid <> v_conn.to_id then
    raise exception 'not_your_connection';
  end if;

  v_other := case when v_conn.from_id = v_uid then v_conn.to_id else v_conn.from_id end;

  -- Aktif oturum varsa DUR (karar 3).
  select count(*) into v_aktif
    from sessions s
    join requests r on r.id = s.request_id
   where s.status = 'active'
     and ((r.host_id = v_uid and r.guest_id = v_other)
       or (r.guest_id = v_uid and r.host_id = v_other));
  if v_aktif > 0 then
    raise exception 'active_session_exists';
  end if;

  update connection_requests
     set status = 'declined'
   where id = p_conn_id;

  -- Sohbet kanalı kapanır: bağlantı yoksa kanal da yoktur.
  -- ⚠️ MESAJLAR SİLİNMİYOR. Silmek, karşı tarafın bir şikâyette
  -- delil olarak gösterebileceği yazışmayı yok eder — ve kaldırma
  -- eylemi bir delil temizleme aracına dönüşür.
  update chat_channels
     set active = false
   where connection_id = p_conn_id;

  return jsonb_build_object('ok', true, 'other_id', v_other);
end $$;

comment on function public.baglanti_kaldir(uuid) is
  'Bağlantıyı sessizce kaldırır (durum declined, kanal pasif). '
  'Karşı tarafa bildirim GİTMEZ. Aktif oturum varsa reddeder.';

revoke all on function public.baglanti_kaldir(uuid) from public;
grant execute on function public.baglanti_kaldir(uuid) to authenticated;

-- ── NÖBETÇİ: kanal gerçekten kapanıyor mu ──────────────────────
-- `chat_channels.active` kolonu yoksa yukarıdaki `update` çalışmaz
-- ve fonksiyon SESSİZCE yarım iş yapar: bağlantı kalkar, sohbet
-- açık kalır. PL/pgSQL bunu ancak ÇALIŞMA ANINDA anlar.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema='public' and table_name='chat_channels'
       and column_name='active') then
    raise exception '277: chat_channels.active kolonu yok — '
      'baglanti_kaldir sohbeti kapatamaz, bagi koparip kanali acik birakir';
  end if;
  raise notice '277: kanal kapatma yolu dogrulandi';
end $$;

-- ── NÖBETÇİ: yetki sınırı ──────────────────────────────────────
do $$
declare v_acl text;
begin
  select array_to_string(proacl, ',') into v_acl
    from pg_proc where proname = 'baglanti_kaldir' limit 1;
  if v_acl is not null and v_acl like '%=X/%' and v_acl like '%PUBLIC%' then
    raise exception '277: baglanti_kaldir PUBLIC''e acik — herkes baskasinin bagini kaldirabilir';
  end if;
  raise notice '277: yetki siniri dogrulandi (yalniz authenticated)';
end $$;
