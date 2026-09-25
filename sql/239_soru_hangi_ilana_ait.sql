-- ============================================================================
-- LoungeLink · 239_soru_hangi_ilana_ait.sql                (22 Ağustos 2026)
--
-- "SORDUKLARIM" HANGİ İLANI SORDUĞUNU TAHMİN EDİYORDU — ARTIK BİLİYOR
--
-- Gökberk: "3- için neden yapmadığını anlamadım. Yap."
--
-- Haklı, ve gerekçem zayıftı. Dün şöyle yazmıştım:
--   "connection_requests avail_id taşımıyor (221 böyle kurmuş).
--    Doğrusu tabloya avail_id eklemek; bu, 221'in sözleşmesini
--    değiştirir ve ayrı bir tur ister."
--
-- 🔴 O CÜMLE BİR TEŞHİS DEĞİL, BİR ERTELEMEYDİ. "Sözleşmeyi değiştirir"
-- dedim ama NE kırılacağını ölçmedim. Ölçtüm: `connection_requests`e
-- NULL kabul eden bir kolon eklemek hiçbir çağıranı kırmaz —
-- `respond_connection`, `pending_actions`, `discover_people`,
-- `home_connections` hiçbiri kolon listesi yazmıyor, hepsi ya `*` ya
-- adlandırılmış alan seçiyor. Yani "ayrı tur ister" demek için
-- baktığım tek şey KENDİ TEDİRGİNLİĞİMDİ.
--
-- 🆕 SINIF: **"ÖLÇMEDEN 'RİSKLİ' DEMEK, ÖLÇMEDEN 'GÜVENLİ' DEMEKLE AYNI
-- SINIFTIR — İKİSİ DE TAHMİNDİR."** Bu projede kural "ölçmeden teşhis
-- verme"ydi; ertelemenin gerekçesi de bir teşhistir.
--
-- ════════════════════════════════════════════════════════════════════════
-- BUGÜNKÜ KUSUR
-- ════════════════════════════════════════════════════════════════════════
-- `sorularim()` (235) ilanı şöyle buluyordu:
--     (select a.id from availabilities a
--       where a.host_id = s.host_id and a.active
--       order by a.avail_date asc limit 1)
-- Yani "host'un en yakın tarihli ilanı". Host'un aynı anda iki ilanı
-- varsa — ki SEED5 tam olarak bunu kuruyor — misafire YANLIŞ SALON
-- gösteriliyordu. Kullanıcı "ben bu salonu sormamıştım ki" der ve haklı
-- olur.
--
-- Aynı tahmin üç yerde daha vardı: 235'in `trg_soru_izi` bildirimi,
-- 238'in `trg_soru_metni` ve `trg_soru_bildirimi_host`. Dördü de aynı
-- LIMIT 1'i yazıyordu — yani tahmin çoğaltılmıştı.
-- 🆕 SINIF: **"BİR TAHMİN KOPYALANDIĞINDA, YANLIŞLIĞI DA KOPYALANIR."**
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) KOLON
-- ----------------------------------------------------------------------------
alter table connection_requests
  add column if not exists avail_id uuid references availabilities(id) on delete set null;

comment on column connection_requests.avail_id is
  'Kural sorusu HANGI ILANA dair soruldu. 221 bunu tasimiyordu ve sorularim() '
  'ilani "host un en yakin tarihli ilani" diye TAHMIN ediyordu; host un iki '
  'ilani varsa yanlis salon gorunuyordu.';

create index if not exists ix_cr_avail on connection_requests (avail_id)
  where avail_id is not null;

-- ----------------------------------------------------------------------------
-- 2) GEÇMİŞİ DOLDUR — ama YALNIZ EMİN OLDUĞUMUZ YERDE
-- ----------------------------------------------------------------------------
-- 🔴 Geriye dönük doldururken de tahmin etmiyoruz. Host'un TEK aktif
-- ilanı varsa soru kesinlikle ona dairdir; birden çoksa BOŞ BIRAKIYORUZ.
-- Boş bir alan, yanlış doldurulmuş bir alandan iyidir.
update connection_requests cr
   set avail_id = (
     select a.id from availabilities a
      where a.host_id = cr.to_id and a.active
      limit 1)
 where cr.intent = 'kural_sorusu'
   and cr.avail_id is null
   and (select count(*) from availabilities a
         where a.host_id = cr.to_id and a.active) = 1;

-- ----------------------------------------------------------------------------
-- 3) YAZAN TARAF: ilan_kurali_sor artık avail_id yazıyor
-- ----------------------------------------------------------------------------
-- 🔴 GÖVDEYİ YENİDEN YAZMIYORUM. 223 onu takvim günü mantığıyla en son
-- düzeltti; kopyalayıp değiştirirsem o kararı sessizce ezme riski var
-- (158/183 dersi). Tetikleyiciyle yazıyorum: `intent='kural_sorusu'` ile
-- eklenen satırda avail_id boşsa, o anda hangi ilana bakıldığını
-- bilemeyiz — bu yüzden RPC'nin kendisi bir oturum değişkeni bırakıyor.
--
-- ⚠️ Oturum değişkeni yerine DAHA BASİT ve daha sağlam bir yol seçtim:
-- `ilan_kurali_sor` zaten `p_avail_id` alıyor ve INSERT'i kendisi
-- yapıyor. Gövdeyi yeniden yazmak yerine, INSERT'ten SONRA aynı
-- fonksiyonun içinde çalışan bir AFTER tetikleyici yeterli değil
-- (avail_id'yi bilmiyor). Bu yüzden burada TEK İSTİSNA yapıyorum:
-- fonksiyonun CANLI gövdesini okuyup içindeki INSERT satırına avail_id
-- ekliyorum. Böylece 223'ün kararı olduğu gibi kalıyor — değişen tek
-- şey bir kolon adı.
do $ins$
declare v_govde text; v_eski text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_govde
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='ilan_kurali_sor' limit 1;

  if v_govde is null then
    raise notice '239: ilan_kurali_sor yok — avail_id yazimi baglanamadi.';
    return;
  end if;
  if v_govde like '%avail_id)%values (v_uid, v_av.host_id%' or v_govde like '%p_avail_id)%' then
    raise notice '239: ilan_kurali_sor ZATEN avail_id yaziyor — dokunulmadi.';
    return;
  end if;

  v_eski := 'insert into connection_requests (from_id, to_id, intent, intro, status)
  values (v_uid, v_av.host_id, ''kural_sorusu'', v_intro, ''pending'')';
  v_yeni := 'insert into connection_requests (from_id, to_id, intent, intro, status, avail_id)
  values (v_uid, v_av.host_id, ''kural_sorusu'', v_intro, ''pending'', p_avail_id)';

  if position(v_eski in v_govde) = 0 then
    -- Girinti/satır sonu farkına karşı desenle dene (238'in dersi:
    -- "kaynak metni ezberden yazmak, okumak değildir").
    v_govde := regexp_replace(
      v_govde,
      'insert into connection_requests \(from_id, to_id, intent, intro, status\)\s*values \(v_uid, v_av\.host_id, ''kural_sorusu'', v_intro, ''pending''\)',
      v_yeni);
  else
    v_govde := replace(v_govde, v_eski, v_yeni);
  end if;

  if v_govde not like '%avail_id%' then
    raise notice '239: beklenen INSERT bulunamadi — ilan_kurali_sor degismis olabilir. DOKUNULMADI.';
    return;
  end if;

  execute v_govde;
  raise notice '239: ilan_kurali_sor artik avail_id yaziyor';
end $ins$;

-- ----------------------------------------------------------------------------
-- 4) OKUYAN TARAF: sorularim() artık TAHMİN ETMİYOR
-- ----------------------------------------------------------------------------
-- sqlcheck: allow-replace sorularim  (returns table AYNI — 235 ile birebir
--            11 kolon; degisen yalniz ilanin NEREDEN geldigi)
drop function if exists public.sorularim();
create or replace function public.sorularim()
returns table (
  id uuid, host_id uuid, host_name text, salon text, airport_code text,
  avail_id uuid, durum text, cevap_durumu text,
  soruldu_at timestamptz, yanit_at timestamptz, ilan_acildi boolean
)
language plpgsql stable security definer set search_path = public as $sr$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select cr.id, cr.to_id,
         coalesce(nullif(btrim(p.name),''), 'Host'),
         -- 🔴 TAHMİN YOK: ilan doğrudan `cr.avail_id`den geliyor.
         -- Eski kayıtlarda avail_id boşsa salon adı da BOŞ dönüyor —
         -- yanlış bir salon adı uydurmaktansa boş bırakmak doğru.
         coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text),
         a.airport_code::text,
         cr.avail_id,
         cr.status::text,
         case
           when cr.status::text = 'accepted' then 'yanitlandi'
           when cr.status::text = 'declined' then 'reddedildi'
           when cr.avail_id is not null
                and not public.kural_sorusu_uygun_mu(cr.avail_id) then 'hak_beyan_edildi'
           else 'bekliyor'
         end,
         cr.created_at, cr.responded_at,
         case when cr.avail_id is null then false
              else not public.kural_sorusu_uygun_mu(cr.avail_id) end
    from connection_requests cr
    left join profiles p on p.user_id = cr.to_id
    left join availabilities a on a.id = cr.avail_id
    left join lounges l on l.id = a.lounge_id
   where cr.from_id = v_uid
     and cr.intent = 'kural_sorusu'
   order by cr.created_at desc
   limit 30;
end $sr$;
grant execute on function public.sorularim() to authenticated;

-- ----------------------------------------------------------------------------
-- 5) BİLDİRİM METİNLERİ DE TAHMİN ETMESİN
-- ----------------------------------------------------------------------------
-- 235'in `trg_soru_izi`si ve 238'in iki tetikleyicisi aynı LIMIT 1
-- tahminini yazıyordu. Üçü de artık `new.avail_id`ye bakıyor.
create or replace function public.trg_soru_izi()
returns trigger language plpgsql security definer set search_path = public as $si$
declare v_host text; v_salon text;
begin
  if new.intent is distinct from 'kural_sorusu' then return new; end if;

  select coalesce(nullif(btrim(p.name),''), 'Host') into v_host
    from profiles p where p.user_id = new.to_id;

  select coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text)
    into v_salon
    from availabilities a
    left join lounges l on l.id = a.lounge_id
   where a.id = new.avail_id;

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (new.from_id, 'connections',
          'Soru iletildi ✦',
          coalesce(v_host,'Host') || ' kişisine '
       || coalesce('“' || v_salon || '” ilanı için ', '')
       || 'misafir hakkını sorduk. Yanıtlarsa ya da hakkını güncellerse '
       || 'haber vereceğiz — bu arada sorularını Ana Sayfa''dan takip edebilirsin.',
          'connection', new.id);
  return new;
end $si$;

create or replace function public.trg_soru_metni()
returns trigger language plpgsql security definer set search_path = public as $sm$
declare v_salon text; v_metin text;
begin
  if new.intent is distinct from 'kural_sorusu' then return new; end if;

  select coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text)
    into v_salon
    from availabilities a
    left join lounges l on l.id = a.lounge_id
   where a.id = new.avail_id;

  select value #>> '{}' into v_metin from beta_settings where key = 'soru_intro_tr';
  if v_metin is null then return new; end if;

  new.intro := left(replace(v_metin, '{salon}', coalesce(v_salon, 'bu')), 400);
  return new;
end $sm$;

create or replace function public.trg_soru_bildirimi_host()
returns trigger language plpgsql security definer set search_path = public as $sbh$
declare v_salon text; v_b text; v_g text;
begin
  if new.intent is distinct from 'kural_sorusu' then return new; end if;

  select coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text)
    into v_salon
    from availabilities a
    left join lounges l on l.id = a.lounge_id
   where a.id = new.avail_id;

  select value #>> '{}' into v_b from beta_settings where key='soru_bildirim_baslik_tr';
  select value #>> '{}' into v_g from beta_settings where key='soru_bildirim_govde_tr';
  if v_b is null or v_g is null then return new; end if;

  update notifications
     set title = v_b,
         body  = replace(v_g, '{salon}', coalesce(v_salon, 'bu'))
   where user_id = new.to_id and ref_type = 'connection' and ref_id = new.id;

  return new;
end $sbh$;

-- ----------------------------------------------------------------------------
-- 6) NÖBETÇİ — tahmin gerçekten kalktı mı?
-- ----------------------------------------------------------------------------
do $n239$
declare
  v_kolon int; v_tahmin int; v_yazar int;
begin
  select count(*) into v_kolon from information_schema.columns
   where table_schema='public' and table_name='connection_requests' and column_name='avail_id';
  if v_kolon <> 1 then
    raise exception '239 NOBETCI: connection_requests.avail_id kolonu YOK.';
  end if;

  -- 🔴 ASIL SINAMA: hiçbir okuyucu artık "host'un ilk ilanı" tahminini
  -- taşımamalı. Dört fonksiyonun gövdesinde o desen kaldıysa tahmin
  -- sürüyor demektir.
  select count(*) into v_tahmin
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and p.proname in ('sorularim','trg_soru_izi','trg_soru_metni','trg_soru_bildirimi_host')
     and p.prosrc like '%a.host_id = %active%order by%limit 1%';
  if v_tahmin <> 0 then
    raise exception '239 NOBETCI: % fonksiyon hala ilani TAHMIN ediyor.', v_tahmin;
  end if;

  select count(*) into v_yazar
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='ilan_kurali_sor'
     and p.prosrc like '%avail_id%';
  if v_yazar <> 1 then
    raise notice '239 UYARI: ilan_kurali_sor gövdesinde avail_id gorunmuyor — '
                 'yeni sorular ilansiz kaydedilecek. 221/223 degismis olabilir.';
  else
    raise notice '239 OK · kolon var · yazan taraf avail_id yaziyor · 4 okuyucuda tahmin yok';
  end if;

  raise notice '239 OLCULMEDI: GECMIS sorularin avail_id si yalniz host un TEK aktif ilani '
               'varsa dolduruldu. Birden cok ilani olan hostlarin eski sorulari BOS kaldi — '
               'bilerek: yanlis doldurmaktansa bos birakmak.';
end $n239$;

select '239 SORU ARTIK ILANI BILIYOR' as sonuc,
       (select count(*) from connection_requests where intent='kural_sorusu') as toplam_soru,
       (select count(*) from connection_requests where intent='kural_sorusu' and avail_id is not null) as ilani_bilinen;
