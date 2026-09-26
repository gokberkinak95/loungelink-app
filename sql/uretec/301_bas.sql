-- ============================================================================
-- LoungeLink · 301_guven_ve_akis_tamamlama.sql                (23 Eylül 2026)
--
-- UÇTAN UCA AKIŞ DENETİMİNİN İKİNCİ TURU — ÜÇ EKSİK AKIŞ, BİR SIZINTI
--
--   §1  ENGELLEME HİÇ YAPILAMIYORDU
--       Güvenlik ekranı "herhangi bir sohbetten Bildir düğmesiyle bir
--       kullanıcıyı engelleyebilirsin" diyordu. Ölçüm: uygulamada `blocks`
--       tablosuna yazan TEK SATIR YOK, veritabanında da onu yazan bir
--       fonksiyon YOK; `authenticated` rolünün tabloda yalnız SELECT hakkı
--       var. Keşif (112), istek (create_request) ve bağlantı kapıları
--       engeli okuyordu — ama kimse engel koyamıyordu. P2P yüz yüze
--       buluşma ürününde bu, var sanılan bir güvenlik özelliğidir.
--       🆕 SINIF: "OKUYANI OLUP YAZANI OLMAYAN BİR GÜVENLİK TABLOSU, BİR
--       ÖZELLİK DEĞİL, BİR VAATTİR."
--
--   §2  "GELMEDİ" İÇİN TEK YOL SÜPÜRGEYDİ
--       Tek taraf "Oturumu başlat"a basıp diğeri gelmezse, kapanış ancak
--       ilan saati + 2 saat sonra süpürgeyle oluyordu. Salonda bekleyen
--       kişinin yapabileceği hiçbir şey yoktu. `gelmedi_bildir` aynı
--       kuralı (süpürgenin (b)+(c) adımları: no_show işareti, istek kapanır,
--       misafire tutulan kredi iade, güven yeniden hesap) 15 dk bekledikten
--       sonra ANINDA uygular. İki politika yok: süpürge ile BİREBİR aynı.
--
--   §3  TEST HESAPLARI GERÇEK KULLANICILARA GÖRÜNÜYORDU
--       SEED hostları herkesin Keşfet'inde, Tanış'ında, Radar'ında ve
--       "65 host yayında" sayacındaydı. Artık yalnız test hesaplarına ve
--       ekibe görünüyor. Aç/kapa: BO → Feature Flags →
--       `test_hesaplarini_gizle` (varsayılan AÇIK).
--
--   §4  SALON REHBERİ KALDIRILMIŞ İLANLARI SAYIYORDU
--       `guide_hosts_today` `active` ve `visibility` bakmıyordu: iptal
--       edilmiş ve gizli ilanlar "bugün X host" sayısına giriyordu.
--
-- Gövdeler yine canlı tanımın üstüne yama (uretec/uret_301.py).
-- TEKRAR KOŞULABİLİR. §Z kendini ölçer.
-- ============================================================================

-- ── §3a · test hesabı tanımı (SEED7/8 ile birebir; migration'a alındı ki
--         bu dosya SEED'siz bir veritabanında da çalışsın) ──────────────────
create or replace function public.seed_test_hesabi(p_email text)
returns boolean language sql immutable as $$
  select coalesce(p_email, '') like '%@seed.loungelink.test'
      or coalesce(p_email, '') like '%@sahne.loungelink.test'
      or coalesce(p_email, '') like '%@vitrin.loungelink.test'
      or coalesce(p_email, '') like '%@e2e.test';
$$;

insert into feature_flags (key, enabled, rollout_pct, description, surface, is_kill_switch)
values ('test_hesaplarini_gizle', true, 100,
        'Açıkken SEED/test hesapları (…@seed/sahne/vitrin.loungelink.test) gerçek kullanıcılara görünmez. Test hesapları ve ekip her şeyi görür.',
        'is_visible (Keşfet · Tanış · Radar) · guide_hosts_today · havalimani_nabzi', false)
on conflict (key) do update set surface = excluded.surface, description = excluded.description;

-- true = BU İZLEYİCİ için hedefi GİZLE
create or replace function public.test_hesabi_gizli_mi(p_hedef uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true)
     and exists (select 1 from users u where u.id = p_hedef and public.seed_test_hesabi(u.email))
     and not coalesce((select public.seed_test_hesabi(x.email) or coalesce(x.is_staff, false)
                         from users x where x.id = auth.uid()), false);
$$;
revoke execute on function public.test_hesabi_gizli_mi(uuid) from public, anon;
grant execute on function public.test_hesabi_gizli_mi(uuid) to authenticated, service_role;

-- ── §1a · engel kaydının sebebi (BO'da görünür) ────────────────────────
alter table public.blocks add column if not exists sebep text;

-- ── §1b · engelle / engeli kaldır / engellediklerim ───────────────────
create or replace function public.engelle(p_user uuid, p_sebep text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  r record;
  v_istek int := 0; v_davet int := 0; v_bag int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  if p_user is null or p_user = v_uid then raise exception 'cannot_block_self'; end if;
  if not exists (select 1 from users where id = p_user) then raise exception 'target_not_found'; end if;

  insert into blocks (blocker, blocked, created_at, sebep)
  values (v_uid, p_user, now(), left(nullif(btrim(coalesce(p_sebep,'')),''), 200))
  on conflict (blocker, blocked) do update set sebep = coalesce(excluded.sebep, blocks.sebep);

  -- İki kişi arasındaki AÇIK buluşmalar kapanır. Başlamış (aktif) oturuma
  -- dokunulmaz: o an salondalar — orada doğru yol Bildir/SOS.
  for r in
    select q.id, q.status, q.guest_id
      from requests q
     where ((q.guest_id = v_uid and q.host_id = p_user) or (q.guest_id = p_user and q.host_id = v_uid))
       and q.status in ('pending', 'accepted')
       and not exists (select 1 from sessions s where s.request_id = q.id
                         and (s.status = 'active'
                              or (s.status = 'pending' and (s.host_started_at is not null
                                                            or s.guest_started_at is not null))))
     for update of q
  loop
    update requests set status = 'cancelled', responded_at = coalesce(responded_at, now()),
           decision_note = coalesce(decision_note, 'Engelleme nedeniyle kapandı (301).')
     where id = r.id;
    update sessions set status = 'cancelled', completed_at = now(), cancelled_by = v_uid,
           cancel_reason = 'engellendi'
     where request_id = r.id and status = 'pending';
    perform public.istek_kredisi_iade(r.id, 'request_refund');
    v_istek := v_istek + 1;
  end loop;

  update invites set status = 'declined', responded_at = now()
   where status = 'pending'
     and ((host_id = v_uid and guest_id = p_user) or (host_id = p_user and guest_id = v_uid));
  get diagnostics v_davet = row_count;

  update connection_requests set status = 'blocked', responded_at = now()
   where status in ('pending', 'accepted')
     and ((from_id = v_uid and to_id = p_user) or (from_id = p_user and to_id = v_uid));
  get diagnostics v_bag = row_count;
  update chat_channels c set active = false
   where c.connection_id in (select id from connection_requests
                              where (from_id = v_uid and to_id = p_user) or (from_id = p_user and to_id = v_uid));

  -- Engellenen kişiye BİLDİRİM GİTMEZ (bilerek: engel sessizdir).
  return jsonb_build_object('ok', true, 'kapanan_istek', v_istek,
                            'reddedilen_davet', v_davet, 'kapanan_baglanti', v_bag);
end $$;

create or replace function public.engeli_kaldir(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_n int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  delete from blocks where blocker = v_uid and blocked = p_user;
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', true, 'kaldirildi', v_n > 0);
end $$;

create or replace function public.engellediklerim()
returns table (user_id uuid, name text, photo_url text, created_at timestamptz, sebep text)
language sql stable security definer set search_path = public as $$
  select b.blocked, coalesce(p.name, '—'), p.photo_url, b.created_at, b.sebep
    from blocks b left join profiles p on p.user_id = b.blocked
   where b.blocker = auth.uid()
   order by b.created_at desc;
$$;

revoke execute on function public.engelle(uuid, text) from public, anon;
revoke execute on function public.engeli_kaldir(uuid) from public, anon;
revoke execute on function public.engellediklerim() from public, anon;
grant execute on function public.engelle(uuid, text) to authenticated, service_role;
grant execute on function public.engeli_kaldir(uuid) to authenticated, service_role;
grant execute on function public.engellediklerim() to authenticated, service_role;
insert into rpc_client_surface (fn_name, client, note)
select x, 'app', '301 §1 — engelleme'
  from unnest(array['engelle','engeli_kaldir','engellediklerim','gelmedi_bildir']) x
 where not exists (select 1 from rpc_client_surface s where s.fn_name = x);

-- ── §1c · engellenmiş çifte mesaj yazılamaz ───────────────────────────
-- Engel, sohbeti de kapatmalı: yoksa engellenen kişi açık kalan istek
-- sohbetinden yazmaya devam eder.
create or replace function public.trg_mesaj_engel()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_diger uuid;
begin
  select case when q.guest_id = new.from_id then q.host_id else q.guest_id end into v_diger
    from chat_channels c join requests q on q.id = c.request_id
   where c.id = new.channel_id;
  if v_diger is null then
    select case when k.from_id = new.from_id then k.to_id else k.from_id end into v_diger
      from chat_channels c join connection_requests k on k.id = c.connection_id
     where c.id = new.channel_id;
  end if;
  if v_diger is not null and public.is_blocked_pair(new.from_id, v_diger) then
    raise exception 'blocked_pair';
  end if;
  return new;
end $$;
revoke execute on function public.trg_mesaj_engel() from public, anon, authenticated;
drop trigger if exists trg_mesaj_engel on public.messages;
create trigger trg_mesaj_engel before insert on public.messages
  for each row execute function public.trg_mesaj_engel();

-- ── §2 · gelmedi_bildir ───────────────────────────────────────────────
insert into beta_settings (key, value)
select 'gelmedi_bekleme_dk', '15'::jsonb
 where not exists (select 1 from beta_settings where key = 'gelmedi_bekleme_dk');

create or replace function public.gelmedi_bildir(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_req requests%rowtype;
  v_s sessions%rowtype;
  v_ben_host boolean; v_bas timestamptz; v_diger uuid;
  v_dk int := coalesce((select (value #>> '{}')::int from beta_settings where key = 'gelmedi_bekleme_dk'), 15);
  v_iade int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  select * into v_req from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;
  if v_uid not in (v_req.host_id, v_req.guest_id) then raise exception 'not_party'; end if;
  if v_req.status <> 'accepted' then raise exception 'not_open'; end if;

  select * into v_s from sessions where request_id = p_request_id for update;
  if not found or v_s.status <> 'pending' then raise exception 'gelmedi_once_baslat'; end if;
  v_ben_host := (v_uid = v_req.host_id);
  v_bas := case when v_ben_host then v_s.host_started_at else v_s.guest_started_at end;
  if v_bas is null then raise exception 'gelmedi_once_baslat'; end if;
  if (case when v_ben_host then v_s.guest_started_at else v_s.host_started_at end) is not null then
    raise exception 'karsi_taraf_geldi';
  end if;
  if now() < v_bas + make_interval(mins => v_dk) then
    raise exception 'gelmedi_erken'
      using hint = format('%s dakika dolmadı', v_dk);
  end if;
  v_diger := case when v_ben_host then v_req.guest_id else v_req.host_id end;

  -- Süpürgenin (b) adımı — birebir
  update sessions set status = 'expired', completed_at = now(), cancel_reason = 'no_show',
         no_show_user_id = v_diger, cancelled_by = v_uid, cancel_note = 'gelmedi_bildirildi'
   where id = v_s.id;
  -- Süpürgenin (c) adımı — birebir: istek kapanır, misafire tutulan kredi döner
  update requests set status = 'cancelled' where id = v_req.id;
  if not exists (select 1 from credit_ledger c where c.ref_id = v_req.id and c.reason = 'no_show_refund') then
    v_iade := coalesce(public.tutulan_kredi(v_req.id), 0);
    if v_iade > 0 then
      insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
      select v_req.guest_id, v_iade, 'no_show_refund', v_req.id,
             coalesce((select sum(delta) from credit_ledger where user_id = v_req.guest_id), 0) + v_iade;
    end if;
  end if;
  perform public.recompute_trust(v_diger);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_diger, 'sessions', 'Buluşma kapandı',
          'Seni bekleyen taraf gelmediğini bildirdi. Bir yanlışlık varsa bu buluşmanın sohbetindeki "Bu buluşmayla ilgili sorun bildir" ile itiraz edebilirsin.',
          'request', v_req.id),
         (v_uid, 'sessions', 'Bildirimin alındı',
          case when v_ben_host then 'Buluşma kapandı. Misafirin gelmediği kaydedildi.'
               when v_iade > 0 then 'Buluşma kapandı ve tutulan kredin iade edildi.'
               else 'Buluşma kapandı. Host''un gelmediği kaydedildi.' end,
          'request', v_req.id);

  return jsonb_build_object('ok', true, 'iade', v_iade, 'gelmeyen', v_diger);
end $$;
revoke execute on function public.gelmedi_bildir(uuid) from public, anon;
grant execute on function public.gelmedi_bildir(uuid) to authenticated, service_role;

-- Eşik TEK YERDEN: uygulama "Gelmedi mi?" düğmesini sunucunun kullandığı
-- AYNI sayıyla açar. BO /manage/engine-settings'ten 20 yapılırsa düğme de
-- 20'de açılır — "düğme göründü, basınca 'erken' dedi" çelişkisi olmaz.
create or replace function public.gelmedi_esigi()
returns int language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::int from beta_settings where key = 'gelmedi_bekleme_dk'), 15)
$$;
revoke execute on function public.gelmedi_esigi() from public, anon;
grant execute on function public.gelmedi_esigi() to authenticated, service_role;
insert into rpc_client_surface (fn_name, client, note)
select 'gelmedi_esigi', 'app', '301 §2 — gelmedi eşiği (sunucuyla aynı sayı)'
 where not exists (select 1 from rpc_client_surface s where s.fn_name = 'gelmedi_esigi');

-- ── §4 · salon rehberi sayacı ─────────────────────────────────────────
create or replace function public.guide_hosts_today(p_airport text, p_date date default null)
returns jsonb language sql stable security definer set search_path = public as $$
  -- 🔴 301/§4: `active` ve `visibility` yoktu — kaldırılmış ve gizli ilanlar
  -- "bugün X host" sayısına giriyordu. Test hesapları da (§3) düşüyor.
  select jsonb_build_object(
    'airport', upper(p_airport),
    'date', coalesce(p_date, current_date),
    'count', (select count(*) from availabilities a
               where a.airport_code = upper(p_airport)
                 and a.active and coalesce(a.visibility::text, 'Public') <> 'Hidden'
                 and a.avail_date >= coalesce(p_date, current_date)
                 and a.avail_date <= coalesce(p_date, current_date) + 2
                 and coalesce(a.filled,0) < coalesce(a.slots,1)
                 and not public.test_hesabi_gizli_mi(a.host_id)),
    'next_date', (select min(a.avail_date) from availabilities a
                   where a.airport_code = upper(p_airport)
                     and a.active and coalesce(a.visibility::text, 'Public') <> 'Hidden'
                     and a.avail_date >= current_date
                     and coalesce(a.filled,0) < coalesce(a.slots,1)
                     and not public.test_hesabi_gizli_mi(a.host_id)));
$$;

-- ── §6 · ÖN KONTROL = SUNUCU (istek sayfası yalan söylemesin) ─────────
-- Tam akış testi 134 ilan×misafir çiftinde ölçtü: `request_precheck`
-- "başvurabilirsin" deyip `create_request`in REDDETTİĞİ çiftler vardı:
--   · guest_carrier_mismatch (misafirin havayolu salonun istediği değil)
--   · hosting_same_slot      (misafirin kendi ilanı aynı saatte)
-- Sebep: ön kontrol misafire ÖZEL kuralları (kişi sayısı, çocuk, havayolu,
-- kabin, kota, kendi ilanı, kredi, açık istek tavanı) hiç sormuyordu;
-- kullanıcı "İstek gönder"e basıyor ve ANCAK O ZAMAN reddi görüyordu.
-- Artık ön kontrol, sunucunun kendi yolunu KURU koşuyor: `create_request`
-- bir kayıt noktası içinde çağrılır, sonuç ölçülür, her şey geri alınır.
-- İki ayrı kural listesi tutmak yerine TEK kaynak: uyuşmazlık imkânsız.
-- 🆕 SINIF: "BİR KARARIN ÖN İZLEMESİ, KARARIN KENDİSİNİ KOŞMUYORSA
-- ÖN İZLEME DEĞİL TAHMİNDİR — VE TAHMİN, KURAL SAYISI ARTTIKÇA ŞAŞAR."
create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare j jsonb; d jsonb; v_kod text;
begin
  j := public.request_precheck_pregate(p_avail_id);
  if coalesce((j ->> 'can_request')::boolean, false) is not true then
    return j;
  end if;
  d := public.lounge_access_decision(p_avail_id, null);
  if (d ->> 'guest_policy') = 'not_allowed'
     or ((d ->> 'severity') = 'block' and coalesce(d ->> 'fits','') <> 'false') then
    return j || jsonb_build_object(
      'can_request', false, 'needs_ack', false, 'severity', 'block', 'gate', 'server',
      'headline', coalesce(nullif(d ->> 'headline',''), 'Bu ilana misafir alınamıyor'),
      'detail', coalesce(nullif(j ->> 'detail',''), d ->> 'detail'));
  end if;
  -- 301/§6: kuru koşu
  begin
    perform public.create_request(p_avail_id, 'lounge', null, null);
    raise exception 'GERI_AL_ONKONTROL_GECER';
  exception when others then
    v_kod := sqlerrm;
  end;
  if v_kod is distinct from 'GERI_AL_ONKONTROL_GECER' then
    return j || jsonb_build_object(
      'can_request', false, 'needs_ack', false, 'severity', 'block',
      'gate', v_kod, 'headline', null);   -- metni uygulama `e_<kod>` ile çevirir (TR/EN)
  end if;
  return j;
end $$;

-- ── §7 · SEYAHAT SİLİNEMİYORDU (ham yabancı anahtar hatası) ──────────
-- Tam akış testi: iptal edilmiş (KAPALI) bir istek seyahate bağlı
-- kaldığında `seyahat_sil` şunu döndürüyordu:
--   update or delete on table "visits" violates foreign key constraint
--   "requests_visit_id_fkey"
-- Yani bir kez başvurup iptal eden kullanıcı o seyahati BİR DAHA
-- silemiyordu. AÇIK başvuru varsa silme zaten `seyahat_silinemez_
-- basvuru_var` ile duruyor (doğru); kapalı istekler için bağ kopar,
-- geçmiş kaydı kalır.
alter table public.requests drop constraint if exists requests_visit_id_fkey;
alter table public.requests add constraint requests_visit_id_fkey
  foreign key (visit_id) references public.visits(id) on delete set null;

