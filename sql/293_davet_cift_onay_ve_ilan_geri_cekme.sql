-- ════════════════════════════════════════════════════════════════════════
-- 293 · DAVET YOLU ÇİFT ONAYA GİRİYOR + İLAN GERİ ÇEKME GERÇEKTEN ÇALIŞIYOR
--
-- 🔴 NEDEN VAR — NOT3 KANITINI YAZARKEN ÇIKTI (13 Eylül)
-- Gökberk Not3: "kabul reddet iptal hâlâ doğru çalışıyor mu, davetler ve
-- bağlantılar için de kontrol et." Kanıt dosyasını (`NOT3_AKSIYON_
-- KANITI.sql`) yazdım ve G bloğu `session_started` ile düştü. Kovaladım:
--
-- ÖLÇÜM 1 — `respond_invite` KABULDE OTURUMU ANINDA BAŞLATIYOR:
--     insert into sessions (request_id, status, started_at)
--     values (v_req, 'active', now())
--   İstek yolu (SQL 080 · v1.75) oturumu ÇİFT ONAYLA başlatıyor: satır
--   'pending' doğar, iki taraf da "Oturumu Başlat"a basınca 'active'
--   olur. Davet yolu bu kuralı TAMAMEN ATLIYORDU — buluşmadan günler
--   önce oturum "başlamış" oluyordu.
--   Bunun üç bedeli var:
--     a) Süre/iptal/no-show mantığı yanlış anda işlemeye başlıyor.
--     b) Host, daveti kabul edilmiş ilanı geri çekemiyor (aşağıda).
--     c) v5.9.0'da "Oturumu Başlat"ın önüne koyacağımız BİNİŞ KARTI
--        DOĞRULAMASI davet yolunda hiç çalışmayacaktı.
--
-- ÖLÇÜM 2 — 291'İN KAPISI ÇOK GENİŞ:
--     where q.avail_id = p_id and s.status in ('pending','active')
--   `pending` "başladı" demek değil. Ölçüm 1 ile birleşince sonuç şu:
--   daveti kabul edilmiş bir ilan ZORLA BİLE kaldırılamıyordu. Yani
--   13 Eylül madde 2'de istenen ("forced şekilde kaldırmalı") davranış,
--   tam da o maddeyi karşılamak için yazdığım 291 yüzünden çalışmıyordu.
--
-- 🆕 SINIF: "AYNI OLAYI İKİ AYRI YOLDAN ÜRETEN KOD, O OLAYIN KURALINI
-- DA İKİ KEZ TANIMLAR — VE BİRİ ER GEÇ ÖBÜRÜNDEN SAPAR."
--
-- 🆕 SINIF: "BİR KAPIYI 'BAŞLADI MI' DİYE KURARKEN DURUM ADINA DEĞİL
-- DURUMUN ANLAMINA BAK — SATIRIN VAR OLMASI, İŞİN BAŞLAMASI DEĞİLDİR."
--
-- NE DEĞİŞİYOR
--   1. `respond_invite`  → oturum 'pending' doğar (istek yoluyla AYNI)
--   2. `cancel_availability(p_id, p_force)` → yalnız GERÇEKTEN başlamış
--      buluşma geri çekmeyi engeller; başlamamış oturum satırları
--      ilanla birlikte 'cancelled' olur (yetim satır kalmaz)
--
-- ⚠️ 291 SİLİNMEDİ, ÜSTÜNE YAZILDI: 291 tarihte duruyor ve hâlâ sırayla
-- koşulabilir; 293 onun kapısını daraltıyor. İkisi de tekrar koşulabilir.
--
-- Gövdeler CANLI VERİTABANINDAN alındı (uretecler/davet_oturum_293.py —
-- değişiklik sayısı doğrulanır, tutmazsa dosya hiç üretilmez).
-- ════════════════════════════════════════════════════════════════════════

-- ── respond_invite ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.respond_invite(p_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_i invites%rowtype; v_req uuid; v_chan uuid;
  v_bal int; v_sess uuid; v_av availabilities%rowtype;
  v_mevcut requests%rowtype;
  v_yeni boolean := false;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);   -- 282/B1: yasaklı/silinmiş hesap yazamaz

  select * into v_i from invites where id = p_id for update;
  if not found then raise exception 'invite_not_found'; end if;
  if v_i.guest_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_i.status <> 'pending' then raise exception 'already_responded'; end if;

  update invites set status = (case when p_accept then 'accepted' else 'declined' end)::connection_status,
         responded_at = now()
   where id = p_id;

  if p_accept then
    -- ── 289: AYNI İLANA ZATEN AKTİF BİR İSTEK VAR MI? ─────────────────
    select * into v_mevcut from requests
     where guest_id = v_uid and avail_id = v_i.avail_id
       and status in ('pending','accepted')
     order by created_at desc limit 1
     for update;

    if found and v_mevcut.status = 'accepted' then
      -- Zaten kabul edilmiş: davet fazlalık. Yeni satır da yeni kredi de yok.
      v_req := v_mevcut.id;
    else
      -- Kapasite kontrolü her iki yolda da geçerli (030'dan beri).
      select * into v_av from availabilities where id = v_i.avail_id for update;
      if not found then raise exception 'availability_not_found'; end if;
      if coalesce(v_av.filled,0) >= v_av.slots then raise exception 'fully_booked'; end if;

      if v_mevcut.id is not null then
        -- PENDING istek var → davet onu kabule yükseltir. Kredi zaten emanette.
        update requests set status = 'accepted', responded_at = now(),
               type = 'direct_invite'
         where id = v_mevcut.id;
        v_req := v_mevcut.id;
      else
        -- Hiç istek yok → eskisi gibi: kredi al, satırı aç.
        select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
        if v_bal < 1 then raise exception 'insufficient_credits'; end if;

        insert into requests (guest_id, host_id, avail_id, status, type, intro_message, match_score)
        values (v_uid, v_i.host_id, v_i.avail_id, 'accepted', 'direct_invite', v_i.note, 60)
        returning id into v_req;
        v_yeni := true;

        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
        values (v_uid, -1, 'invite_hold', v_req, v_bal - 1);
      end if;
    end if;

    insert into chat_channels (request_id, kind) values (v_req, 'lounge')
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req;

    -- Davet notu ilk mesaj (gönderen: HOST — daveti o yazdı)
    if v_chan is not null and coalesce(nullif(trim(v_i.note),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_i.host_id, trim(v_i.note), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    -- Oturum: zaten varsa YENİSİ AÇILMAZ (davet iki kez oturum başlatamaz).
    select id into v_sess from sessions where request_id = v_req and status in ('pending','active') limit 1;
    if v_sess is null then
      -- 🔴 13 EYLÜL — BURASI 'active', now() YAZIYORDU.
      -- Yani davet kabul edilir edilmez oturum BAŞLAMIŞ sayılıyordu:
      -- buluşmadan günler önce, iki taraf da "Oturumu Başlat"a
      -- basmadan. İstek yolu (SQL 080 · v1.75) ÇİFT ONAY istiyor;
      -- davet yolu o kuralı tamamen atlıyordu. Aynı üründe aynı
      -- buluşmanın iki farklı başlama kuralı vardı.
      insert into sessions (request_id, status)
      values (v_req, 'pending') returning id into v_sess;
    end if;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin kabul edildi ✓', 'Sohbet açıldı, oturum başladı.', 'request', v_req);
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin yanıtlandı', 'Davet reddedildi.', 'invite', p_id);
  end if;

  return jsonb_build_object('ok', true, 'request_id', v_req, 'channel_id', v_chan,
                            'session_id', v_sess, 'yeni_istek', v_yeni);
end $function$;

-- ── cancel_availability(uuid, boolean) ───────────────────
CREATE OR REPLACE FUNCTION public.cancel_availability(p_id uuid, p_force boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_accepted int; v_pending int; v_iptal int := 0;
  r record;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  if not exists (select 1 from availabilities where id = p_id and host_id = v_uid) then
    raise exception 'not_your_availability';
  end if;

  -- Oturum başladıysa hiçbir yoldan geri çekilemez.
  -- 🔴 13 EYLÜL — BU KAPI ÇOK GENİŞTİ VE 291'İN KENDİ AMACINI
  -- ÇÜRÜTÜYORDU. `pending` bir oturum "başlamış" demek DEĞİL: SQL 080'de
  -- oturum satırı kabulde oluşur, gerçekten `active` olması için İKİ
  -- TARAFIN DA "Oturumu Başlat"a basması gerekir.
  -- ÖLÇÜM: `respond_invite` her kabulde bir oturum satırı yaratıyor
  -- (293 öncesi doğrudan 'active'). Sonuç: daveti kabul edilmiş bir
  -- ilanı host ZORLA BİLE geri çekemiyordu — yani Gökberk'in 13 Eylül
  -- madde 2'de istediği şeyin tam tersi oluyordu.
  -- Doğru kapı: buluşma GERÇEKTEN başlamışsa geri çekilemez.
  --   · status = 'active'                        → başladı
  --   · 'pending' ama bir taraf "geldim" dediyse  → biri kapıda bekliyor
  -- İkisi de yoksa zorlu kaldırma çalışır ve o boş oturum satırı da
  -- kapatılır (yetim satır bırakmak, temizlik değil sızıntıdır — 291'in
  -- kendi sınıfı).
  if exists (
    select 1 from sessions s join requests q on q.id = s.request_id
     where q.avail_id = p_id
       and (s.status = 'active'
            or (s.status = 'pending'
                and (s.host_started_at is not null or s.guest_started_at is not null)))
  ) then raise exception 'session_started'; end if;

  select count(*) filter (where status = 'accepted'),
         count(*) filter (where status = 'pending')
    into v_accepted, v_pending
    from requests where avail_id = p_id;

  if v_accepted > 0 and not p_force then
    raise exception 'has_accepted_requests';
  end if;

  if p_force then
    -- Açık her isteği REDDET: kredi iadesi + bildirim, `respond_request`
    -- ile AYNI yoldan (iade mantığı tek yerde kalsın).
    for r in select id, guest_id from requests
              where avail_id = p_id and status in ('pending','accepted')
              for update
    loop
      update requests set status = 'declined', responded_at = now() where id = r.id;
      perform public.istek_kredisi_iade(r.id, 'request_refund');
      insert into notifications (user_id, category, title, body, ref_id, ref_type)
      values (r.guest_id, 'requests', 'İlan geri çekildi',
              'Host bu ilanı kaldırdı. Kredin anında iade edildi; başka bir ilana başvurabilirsin.',
              r.id, 'request');
      v_iptal := v_iptal + 1;
    end loop;
  else
    -- Zorlamasız yolda BİLE bekleyen istekler serbest bırakılır:
    -- ilan kapanınca o istek zaten cevaplanamaz hâle geliyordu.
    for r in select id, guest_id from requests
              where avail_id = p_id and status = 'pending' for update
    loop
      update requests set status = 'declined', responded_at = now() where id = r.id;
      perform public.istek_kredisi_iade(r.id, 'request_refund');
      insert into notifications (user_id, category, title, body, ref_id, ref_type)
      values (r.guest_id, 'requests', 'İlan geri çekildi',
              'Host bu ilanı kaldırdı. Kredin anında iade edildi; başka bir ilana başvurabilirsin.',
              r.id, 'request');
      v_iptal := v_iptal + 1;
    end loop;
  end if;

  -- Bekleyen davetler de kapanır.
  -- 'cancelled' bu enum'da YOK (pending|accepted|declined|blocked) — davet geri
  -- çekilince 'declined' doğru karşılık: davet edilen kişi bir şey yapmadı.
  update invites set status = 'declined'::connection_status, responded_at = now()
   where avail_id = p_id and status = 'pending';

  -- Hiç başlamamış ('pending' ve iki taraf da basmamış) oturum satırları
  -- ilanla birlikte kapanır; yoksa `expire_stale_sessions` onları
  -- no-show sanıp kullanıcının güvenini düşürürdü.
  update sessions s set status = 'cancelled', completed_at = now(),
         cancel_reason = coalesce(s.cancel_reason, 'ilan_geri_cekildi')
    from requests q
   where q.id = s.request_id and q.avail_id = p_id
     and s.status = 'pending'
     and s.host_started_at is null and s.guest_started_at is null;

  -- Hiç başlamamış ('pending' ve iki taraf da basmamış) oturum satırları
  -- ilanla birlikte kapanır; yoksa `expire_stale_sessions` onları
  -- no-show sanıp kullanıcının güvenini düşürürdü.
  update sessions s set status = 'cancelled', completed_at = now(),
         cancel_reason = coalesce(s.cancel_reason, 'ilan_geri_cekildi')
    from requests q
   where q.id = s.request_id and q.avail_id = p_id
     and s.status = 'pending'
     and s.host_started_at is null and s.guest_started_at is null;

  update availabilities set active = false, updated_at = now() where id = p_id;
  return jsonb_build_object('ok', true, 'iptal_edilen', v_iptal,
                            'bekleyen', v_pending, 'kabul_edilen', v_accepted);
end $function$;

-- ── 3 · AŞIRI YÜKLEME BELİRSİZLİĞİ — 291'İN SESSİZ REGRESYONU ─────────
-- 🔴 ÖLÇÜM: 291, `cancel_availability(p_id uuid, p_force boolean default
-- false)` ekledi ama ESKİ `cancel_availability(p_id uuid)` yerinde kaldı.
-- İkisi bir arada, tek argümanlı her çağrıyı BELİRSİZ yapıyor:
--     ERROR: function public.cancel_availability(uuid) is not unique
-- Yani "geriye dönük uyumluluk için eskisini bıraktım" diye yazdığım
-- satır, tam da korumak istediğim eski çağrıyı KIRIYORDU. (Uygulama bu
-- turda `p_force: true` gönderdiği için fark edilmiyordu; NOT3 kanıtı
-- zorlamasız yolu sınayınca çıktı.)
--
-- 🆕 SINIF: "VARSAYILAN DEĞERLİ BİR AŞIRI YÜKLEME, ESKİ İMZAYI KORUMAZ —
-- ONU BELİRSİZ YAPAR. GERİYE DÖNÜK UYUM AŞIRI YÜKLEMEYLE DEĞİL
-- VARSAYILANLA SAĞLANIR."
--
-- Tek fonksiyon kalıyor: `(p_id uuid, p_force boolean default false)`.
-- `cancel_availability(p_id => ...)` ve `cancel_availability(av)` yine
-- çalışır, davranış eskisiyle aynıdır (zorlamasız).
drop function if exists public.cancel_availability(uuid);
grant execute on function public.cancel_availability(uuid, boolean) to authenticated;

-- ── KENDİ SINAMASI ─────────────────────────────────────────────────────
do $$
declare
  hd uuid; g uuid; lng uuid; av uuid; inv_id uuid; rq uuid;
  v_st text; sonuc jsonb; v_ses uuid; v_n int;
begin
  select id into hd from users where role = 'host' and deleted_at is null limit 1;
  select id into lng from lounges where airport_code = 'IST' limit 1;
  if hd is null or lng is null then raise notice '293 sinama: veri yok, atlandi'; return; end if;
  select id into g from users where id <> hd and deleted_at is null limit 1;
  if g is null then raise notice '293 sinama: misafir yok, atlandi'; return; end if;

  insert into availabilities (host_id, airport_code, lounge_id, avail_date, time_from, time_to, slots, active)
    values (hd, 'IST', lng, public.yerel_gun('IST') + 5, time '10:00', time '13:00', 2, true)
    returning id into av;
  insert into credit_ledger (user_id, delta, reason, balance_after)
    values (g, 3, 'sinama_293', coalesce((select sum(delta) from credit_ledger where user_id = g), 0) + 3);

  -- 1) Davet kabulü oturumu 'pending' doğurmalı, 'active' DEĞİL
  insert into invites (host_id, guest_id, avail_id, status, note)
    values (hd, g, av, 'pending', '293 sinama') returning id into inv_id;
  perform set_config('request.jwt.claims',
    json_build_object('sub', g::text, 'role', 'authenticated')::text, true);
  perform public.respond_invite(inv_id, true);
  select s.id, s.status::text into v_ses, v_st
    from sessions s join requests q on q.id = s.request_id
   where q.avail_id = av limit 1;
  if v_ses is null then raise exception '293: davet kabulunde oturum satiri olusmadi'; end if;
  if v_st <> 'pending' then
    raise exception '293: davet kabulu oturumu % yapti (pending bekleniyordu)', v_st;
  end if;
  raise notice '293 sinama 1 ✓ davet kabulu → oturum ''pending'' (cift onay korunuyor)';

  -- 2) Host, daveti kabul edilmiş ilanı ZORLA geri çekebilmeli
  perform set_config('request.jwt.claims',
    json_build_object('sub', hd::text, 'role', 'authenticated')::text, true);
  sonuc := public.cancel_availability(av, true);
  if (sonuc ->> 'ok') is distinct from 'true' then
    raise exception '293: zorlu kaldirma hala dusuyor';
  end if;
  if (select active from availabilities where id = av) then
    raise exception '293: ilan pasife dusmedi';
  end if;
  select status::text into v_st from sessions where id = v_ses;
  if v_st <> 'cancelled' then
    raise exception '293: baslamamis oturum satiri yetim kaldi (%)', v_st;
  end if;
  raise notice '293 sinama 2 ✓ davet kabul edilmis ilan ZORLA geri cekildi · oturum %', v_st;

  -- 3) GERÇEKTEN başlamış buluşma hâlâ korunmalı
  insert into availabilities (host_id, airport_code, lounge_id, avail_date, time_from, time_to, slots, active)
    values (hd, 'IST', lng, public.yerel_gun('IST') + 6, time '10:00', time '13:00', 2, true)
    returning id into av;
  insert into requests (guest_id, host_id, avail_id, status) values (g, hd, av, 'accepted') returning id into rq;
  insert into sessions (request_id, status, started_at) values (rq, 'active', now());
  begin
    perform public.cancel_availability(av, true);
    raise exception '293: BASLAMIS oturumda kaldirma engellenmedi';
  exception when others then
    if SQLERRM <> 'session_started' then raise; end if;
    raise notice '293 sinama 3 ✓ gercekten baslamis bulusma korunuyor (session_started)';
  end;

  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
    raise notice '293 sinama: tum veri geri alindi';
end $$;

select '293 kuruldu · davet yolu cift onaya girdi, ilan geri cekme calisiyor' as sonuc;
