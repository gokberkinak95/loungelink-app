-- ============================================================================
-- 311 · KEŞFET ÖZETİ — ANA SAYFA SAYILARI KEŞFET'İN KENDİ LİSTESİNDEN (tek kaynak)
--
-- Gökberk (1 Ekim): "ana sayfada IST 11 · ESB 5 · SAW 4 host yazıyor, Salon ara'ya basınca
-- Keşfet'te 3 ilan var." ÖLÇÜLDÜ: sakin gün kartı `havalimani_nabzi`nı okuyordu; o fonksiyon
-- bir arz/talep PANOSU (BO ve raporlar için) ve bir ilanı Keşfet'te görünür kılan kuralların
-- HİÇBİRİNİ uygulamıyor: host rolü, personel hesabı, "Keşfet'te görün" ayarı, görünürlük
-- (bağlantılar / güvenilir), güven eşiği, kadın güvenliği modu, engel, yasak/silinmiş hesap,
-- sona ermiş ilan, dolu ilan, kendi ilanın. Yani kullanıcıya "gidebileceğin host" diye
-- gidemeyeceği hostları sayıyordu.
--
-- `kesfet_ozeti()` sayıyı Keşfet'in KENDİ sorgusundan (discover_availabilities, çağıranın
-- gözüyle) üretir: yalnız SAATİ GEÇMEMİŞ, BOŞ YERİ OLAN ve BAŞKASININ ilanları. Keşfet
-- başlığı da aynı tanımı kullanır (app 6.2.6) → iki sayı artık aynı yerden gelir.
-- `havalimani_nabzi` BO/rapor panosu olarak DEĞİŞMEDEN kalır.
-- ============================================================================

create or replace function public.kesfet_ozeti(p_gun integer default 14)
returns table (airport_code text, canli_ilan integer, host_sayisi integer, acik_slot integer, durum text)
language plpgsql stable security definer set search_path = public as $fn$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  with d as (
    select k.id, k.host_id, k.airport_code::text as ap, k.slots, k.filled, k.fully_booked
      from public.discover_availabilities(null, null, null, null) k
  ), canli as (
    select d.*
      from d
      join availabilities a on a.id = d.id
      left join airports ap on ap.code = a.airport_code
     where d.host_id <> v_uid
       and not coalesce(d.fully_booked, false)
       and greatest(0, coalesce(d.slots,0) - coalesce(d.filled,0)) > 0
       and a.avail_date <= current_date + greatest(1, coalesce(p_gun, 14))
       and (a.avail_date + a.time_to) > (now() at time zone coalesce(ap.timezone, 'Europe/Istanbul'))
  )
  select c.ap,
         count(*)::int,
         count(distinct c.host_id)::int,
         coalesce(sum(greatest(0, coalesce(c.slots,0) - coalesce(c.filled,0))), 0)::int,
         case when count(distinct c.host_id) >= 3 then 'canli'
              when count(distinct c.host_id) >= 1 then 'isiniyor' else 'soguk' end
    from canli c
   group by c.ap
   order by count(distinct c.host_id) desc, c.ap;
end $fn$;

revoke all on function public.kesfet_ozeti(integer) from public, anon;
grant execute on function public.kesfet_ozeti(integer) to authenticated, service_role;

insert into rpc_client_surface (fn_name, client, note)
values ('kesfet_ozeti', 'app', 'Ana sayfa havalimanı çipleri: Keşfet''in kendi listesinden sayılır (311).')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

do $$
begin
  if not exists (select 1 from pg_proc where proname = 'kesfet_ozeti') then
    raise exception '311: kesfet_ozeti kurulmadı';
  end if;
  raise notice '311: kesfet_ozeti hazır (ana sayfa sayıları = Keşfet listesi)';
end $$;

-- ── ana_sayfa_akisi: SOHBET kutusu = bağlantılar + kabul edilmiş buluşmalar ──
CREATE OR REPLACE FUNCTION public.ana_sayfa_akisi()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_sohbet int := 0;
  v_istek  int := 0;
  v_davet  int := 0;
  v_soru   int := 0;
  v_baglanti int := 0;
  v_ilan   int := 0;
begin
  if v_uid is null then
    return jsonb_build_object('sohbet',0,'istek',0,'davet',0,'soru',0,'baglanti',0,'ilan',0);
  end if;

  -- SOHBETLER: kabul edilmis TUM baglantilarim (engellenenler haric).
  select count(*)::int into v_sohbet
    from connection_requests cr
   where cr.status = 'accepted'
     and (cr.from_id = v_uid or cr.to_id = v_uid)
     and not public.is_blocked_pair(v_uid,
           case when cr.from_id = v_uid then cr.to_id else cr.from_id end);

  -- ISTEKLER: bekleyen misafir istekleri — hem bana gelen hem gonderdigim.
  -- 311 (1 Ekim): SOHBET kutusu = "Oturumlar ve sohbetler" ekranı → bağlantı sohbetleri +
  -- kabul edilmiş lounge buluşmaları (OTURUMLAR sekmesiyle birebir aynı küme).
  v_sohbet := coalesce(v_sohbet, 0) + (select count(*)::int from requests r
                where r.status = 'accepted' and (r.host_id = v_uid or r.guest_id = v_uid));

  select count(*)::int into v_istek
    from requests r
   where r.status = 'pending'
     and (r.host_id = v_uid or r.guest_id = v_uid);

  select count(*) filter (where pa.kind = 'invite')::int
    into v_davet
    from public.pending_actions() pa;

  select count(*)::int into v_soru
    from public.sorularim() s
   where coalesce(s.cevap_durumu, '') not in ('yanitlandi', 'acildi');

  select count(*)::int into v_ilan
    from availabilities a
   where a.host_id = v_uid and a.active and a.avail_date >= current_date;

  -- BAGLANTI: bana gelen bekleyen baglanti istekleri.
  select count(*)::int into v_baglanti
    from connection_requests cr
   where cr.to_id = v_uid and cr.status = 'pending';

  return jsonb_build_object(
    'sohbet', coalesce(v_sohbet, 0),
    'istek',  coalesce(v_istek, 0),
    'davet',  coalesce(v_davet, 0),
    'soru',   coalesce(v_soru, 0),
    'baglanti', coalesce(v_baglanti, 0),
    'ilan', coalesce(v_ilan, 0)
  );
end $function$;
