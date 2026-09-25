-- ============================================================================
-- LoungeLink · 235_sordugunu_gorebilmeli.sql                (22 Ağustos 2026)
--
-- "HOST'A SOR" — SORAN KİŞİ SORDUĞUNU HİÇBİR YERDE GÖREMİYOR
-- (Gökberk, madde 5 ve 6)
--
-- Gökberk: "ben guest olarak bu aksiyonu yaptığımda ne ana sayfa ne de
-- başka bir yerde bu aksiyonuma dair bir şey göremiyorum."
--
-- Ölçtüm — haklı, ve sandığından daha kötü. Soru gönderildikten sonra:
--   · `pending_actions()` YALNIZ GELEN istekleri döndürüyor
--     (ETKIN_TANIMLAR:2202 → `where cr.to_id = v_uid`), soran `from_id`
--   · misafire HİÇ bildirim yazılmıyor (221/223 yalnız host'a yazıyor)
--   · sohbet kanalı ancak host KABUL ederse açılıyor (077:229) →
--     bekleyen soru hiçbir sohbet listesinde yok
--   · Tanış sekmesinde host KAYBOLUYOR: `discover_people` yönü olmayan
--     `rel='pending'` döndürüyor, ekran `rel==='none'||'incoming'`
--     filtresiyle onu eliyor (screens.js:4278) — yani soru sormak
--     host'u listeden SİLİYOR
--   · ekrandaki "Soru gönderildi" yazısı bileşen state'i; Keşfet
--     kapanınca yok oluyor
--
-- 🔴 VE ASIL KOPUKLUK: mutlu son da sessiz. Host hakkını beyan edince
-- `save_host_access` HİÇBİR bildirim yazmıyor ve hiçbir
-- `connection_requests` satırına dokunmuyor. Yani sistemin tasarlanan
-- akışı — "host güncellesin, ilan açılsın" — gerçekleştiğinde SORAN
-- KİŞİNİN HABERİ OLMUYOR. Soru sorması istenen kişi, cevabı
-- alamıyor.
--
-- 🆕 SINIF: **"BİR EYLEMİN İZİ YOKSA, KULLANICI ONU YAPMADIĞINI SANIR —
-- VE İKİNCİ KEZ YAPAR."**
--
-- ÜÇ PARÇA:
--   1) `sorularim()` — soran kişinin kendi soruları, durumuyla
--   2) soru gönderilince MİSAFİRE de bildirim (eylemin ilk izi)
--   3) host hakkını beyan edip ilan açılınca SORANA bildirim (kapanış)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) SORULARIM — takip yüzeyi
-- ----------------------------------------------------------------------------
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
  with sorular as (
    select cr.id, cr.to_id as host_id, cr.intro, cr.status::text as durum,
           cr.created_at, cr.responded_at
      from connection_requests cr
     where cr.from_id = v_uid
       and cr.intent = 'kural_sorusu'
  ),
  -- Soru bir İLANA dair sorulmuştu ama connection_requests avail_id
  -- taşımıyor (221 öyle kurmuş). Host'un o havalimanındaki AKTİF ilanı
  -- üzerinden bağlıyoruz — birden çoksa en yakın tarihli.
  eslesen as (
    select s.*,
           (select a.id from availabilities a
             where a.host_id = s.host_id and a.active
             order by a.avail_date asc limit 1) as av_id
      from sorular s
  )
  select e.id, e.host_id,
         coalesce(nullif(btrim(p.name),''), 'Host'),
         coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text),
         a.airport_code::text,
         e.av_id,
         e.durum,
         -- Kullanıcıya gösterilecek dil: ham enum değil.
         case
           when e.durum = 'accepted' then 'yanitlandi'
           when e.durum = 'declined' then 'reddedildi'
           when e.av_id is not null
                and coalesce(pr.guest_capacity,0) > 0 then 'hak_beyan_edildi'
           else 'bekliyor'
         end,
         e.created_at, e.responded_at,
         -- İlan gerçekten başvuruya açıldı mı? Tek kaynak: 221'in
         -- uygunluk fonksiyonu. "Artık uygun DEĞİL" = soru kapandı,
         -- yani ilan açıldı.
         case when e.av_id is null then false
              else not public.kural_sorusu_uygun_mu(e.av_id) end
    from eslesen e
    left join profiles p on p.user_id = e.host_id
    left join profiles pr on pr.user_id = e.host_id
    left join availabilities a on a.id = e.av_id
    left join lounges l on l.id = a.lounge_id
   order by e.created_at desc
   limit 30;
end $sr$;
grant execute on function public.sorularim() to authenticated;

comment on function public.sorularim() is
  'Soran kisinin KENDI kural sorulari. pending_actions() yalniz GELEN istekleri '
  'donduruyor (to_id); giden soru hicbir yuzeyde gorunmuyordu.';

-- ----------------------------------------------------------------------------
-- 2) SORU GÖNDERİLİNCE MİSAFİRE DE BİLDİRİM
-- ----------------------------------------------------------------------------
-- 🔴 `ilan_kurali_sor`ın GÖVDESİNİ YENİDEN YAZMIYORUM. 223 onu en son
-- takvim günü mantığıyla düzeltti; kopyalayıp değiştirsem 223'ün kararını
-- sessizce ezme riski var (158/183 dersi). Bunun yerine
-- `connection_requests` üzerine bir tetikleyici: intent='kural_sorusu'
-- eklendiğinde SORANA da bir satır yaz.
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
   where a.host_id = new.to_id and a.active
   order by a.avail_date asc limit 1;

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

drop trigger if exists trg_cr_soru_izi on connection_requests;
create trigger trg_cr_soru_izi after insert on connection_requests
  for each row execute function public.trg_soru_izi();

-- ----------------------------------------------------------------------------
-- 3) HOST HAKKINI BEYAN EDİNCE SORANLARA HABER VER
-- ----------------------------------------------------------------------------
-- Akışın kapanışı buydu ve hiç yazılmamıştı. `host_entitlements`
-- değiştiğinde (yeni kart, kapasite artışı) o host'a kural sorusu sormuş
-- ve hâlâ bekleyen herkese bildirim gider.
create or replace function public.trg_hak_beyani_soranlara()
returns trigger language plpgsql security definer set search_path = public as $hb$
declare r record; v_n int := 0;
begin
  -- Yalnız misafir hakkı ANLAMLI hâle geldiyse haber ver; her küçük
  -- güncellemede bildirim yağdırmak, bildirimi değersizleştirir.
  if coalesce(new.guest_capacity,0) <= 0 then return new; end if;
  if tg_op = 'UPDATE' and coalesce(old.guest_capacity,0) > 0 then return new; end if;

  for r in
    select cr.id, cr.from_id
      from connection_requests cr
     where cr.to_id = new.user_id
       and cr.intent = 'kural_sorusu'
       and cr.status = 'pending'
  loop
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (r.from_id, 'connections',
            'Sorduğun host hakkını güncelledi ✦',
            'Sorduğun ilanın host''u kart hakkını beyan etti. Keşfet''te o ilana '
         || 'yeniden bak — başvuruya açılmış olabilir.',
            'connection', r.id);
    v_n := v_n + 1;
  end loop;
  return new;
end $hb$;

drop trigger if exists trg_he_hak_beyani on host_entitlements;
create trigger trg_he_hak_beyani after insert or update of guest_capacity
  on host_entitlements
  for each row execute function public.trg_hak_beyani_soranlara();

-- ----------------------------------------------------------------------------
-- 4) NÖBETÇİ — tetikleyiciler BAĞLI mı, gerçekten yazıyor mu?
-- ----------------------------------------------------------------------------
do $n235$
declare
  v_trg int;
  v_uid uuid;
  v_host uuid;
  v_cr uuid;
  v_bildirim int;
begin
  select count(*) into v_trg from pg_trigger
   where tgname in ('trg_cr_soru_izi','trg_he_hak_beyani') and not tgisinternal;
  if v_trg <> 2 then
    raise exception '235 NOBETCI: 2 tetikleyici bekleniyordu, % bagli.', v_trg;
  end if;

  -- MUTASYONLA DEĞİL, GERÇEK YAZIMLA ölç: iki kullanıcı varsa bir soru
  -- satırı ekle ve sorana bildirim düştü mü bak, sonra geri al.
  select id into v_uid from users order by created_at limit 1;
  select id into v_host from users where id <> v_uid order by created_at limit 1;
  if v_uid is null or v_host is null then
    raise notice '235 OLCULMEDI: iki kullanici yok — tetikleyici davranisi sinanmadi.';
  else
    insert into connection_requests (from_id, to_id, intent, intro, status)
    values (v_uid, v_host, 'kural_sorusu', '235 nobetci sinamasi', 'pending')
    returning id into v_cr;

    select count(*) into v_bildirim from notifications
     where user_id = v_uid and ref_type = 'connection' and ref_id = v_cr;

    -- İzleri temizle: nöbetçi veri BIRAKMAZ.
    delete from notifications where ref_type='connection' and ref_id = v_cr;
    delete from connection_requests where id = v_cr;

    if v_bildirim <> 1 then
      raise exception '235 NOBETCI: soru gonderildi ama SORANA bildirim yazilmadi (% satir).', v_bildirim;
    end if;
    raise notice '235 OK · soru izi tetikleyicisi gercekten yaziyor (1 bildirim)';
  end if;

  raise notice '235 OLCULMEDI: `sorularim()` ilani host''un EN YAKIN TARIHLI aktif ilanindan '
               'tahmin ediyor — connection_requests avail_id tasimiyor (221 boyle kurmus). '
               'Host''un ayni anda iki ilani varsa yanlis salonu gosterebilir. '
               'Dogrusu connection_requests''e avail_id eklemek; bu, 221''in sozlesmesini '
               'degistirir ve ayri bir tur ister.';
end $n235$;

-- ----------------------------------------------------------------------------
-- 5) RPC YÜZEYİ
-- ----------------------------------------------------------------------------
insert into rpc_client_surface (fn_name, client, note) values
  ('sorularim','app','Soran kisinin kendi kural sorulari — takip yuzeyi (235)')
on conflict (fn_name) do update set note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '235: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '235 SORDUGUNU GOREBILIYOR' as sonuc,
       (select count(*) from connection_requests where intent='kural_sorusu') as toplam_soru;
