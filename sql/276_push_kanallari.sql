-- ============================================================
-- LoungeLink · sql/276_push_kanallari.sql
-- 30 Ağustos 2026
--
-- BİLDİRİM KANALI ARTIK KATEGORİYE GÖRE SEÇİLİYOR.
--
-- 🔴 SORUN: `notify_push()` her bildirimi `'channelId','default'` ile
-- yolluyordu. Android'de kanal, kullanıcının SUSTURMA BİRİMİDİR — tek
-- kanalda kullanıcı "kampanya gelmesin, oturum bildirimi gelsin"
-- diyemez. Ya hepsini kapatır ya hepsini açar; ve insanlar o soruya
-- genellikle "hepsini kapat" der.
--
-- Uygulama tarafında (src/push.js) üç kanal kuruldu. AMA KANALI
-- SUNUCU SEÇER: app'te kanal açmak tek başına hiçbir şey değiştirmez,
-- payload hangi kanalı yazıyorsa bildirim oraya düşer.
--
-- 🆕 SINIF: "BİR AYRIMI YALNIZ İSTEMCİDE KURMAK, AYRIMI KURMAK
-- DEĞİLDİR — SEÇİMİ KİM YAPIYORSA DEĞİŞMESİ GEREKEN ORASIDIR."
--
-- EŞLEME (app'teki kanal kimlikleriyle BİREBİR):
--   safety, sessions            → 'guvenlik'  (yüksek önem)
--   requests, connections, invites → 'akis'   (yüksek önem)
--   diğer her şey               → 'diger'     (varsayılan önem)
--
-- ⚠️ 'default' kanalı app'te SİLİNMEDİ: eski sürümler hâlâ oraya
-- yolluyor ve Android'de bir kanalı silmek, kullanıcının o kanal için
-- verdiği ayarı da siler.
-- ============================================================

create or replace function push_kanali(p_category text)
returns text
language sql
immutable
as $$
  select case
    when p_category in ('safety', 'sessions')                  then 'guvenlik'
    when p_category in ('requests', 'connections', 'invites')  then 'akis'
    else 'diger'
  end
$$;

comment on function push_kanali(text) is
  'Bildirim kategorisini Android bildirim kanalına eşler. '
  'Kimlikler src/push.js içindeki KANALLAR listesiyle birebir aynı olmalı.';

-- ── notify_push içindeki sabit kanalı fonksiyona çevir ──────────
do $$
declare
  v_src text;
  v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_src
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where p.proname = 'notify_push' and n.nspname = 'public'
   limit 1;

  if v_src is null then
    raise notice '276: notify_push bulunamadi — atlandi';
    return;
  end if;

  if position($q$'channelId', 'default'$q$ in v_src) = 0 then
    raise notice '276: sabit kanal zaten yok — degisiklik gerekmedi';
    return;
  end if;

  v_yeni := replace(v_src,
              $q$'channelId', 'default'$q$,
              $q$'channelId', push_kanali(NEW.category)$q$);
  execute v_yeni;
  raise notice '276: notify_push kanal secimi kategoriye baglandi';
end $$;

-- ── NÖBETÇİ: app ile sunucu aynı kanal kimliklerini mi kullanıyor ──
-- Kimlikler iki yerde yazılı (JS ve SQL). Ayrışırlarsa bildirim
-- Android'in kendi varsayılanına düşer ve KİMSE FARK ETMEZ — ses,
-- öncelik ve kullanıcı ayarı sessizce değişir.
do $$
declare
  v_eksik text;
begin
  select string_agg(k, ', ') into v_eksik
    from (values ('guvenlik'), ('akis'), ('diger')) as x(k)
   where k not in (select push_kanali(c)
                     from (values ('safety'), ('sessions'), ('requests'),
                                  ('connections'), ('invites'), ('credits'),
                                  ('ratings'), ('system')) as y(c));
  if v_eksik is not null then
    raise exception '276: su kanallara hicbir kategori dusmuyor: %', v_eksik;
  end if;
  raise notice '276: uc kanalin ucu de kullaniliyor';
end $$;
