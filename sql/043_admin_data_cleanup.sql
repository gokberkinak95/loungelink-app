-- ============================================================
-- 043 — BO'DAN VERİ TEMİZLİĞİ (prod beta için)
--
-- 042'den SONRA çalıştır.
--
-- GEREKÇE (Gokberk sordu):
-- "Sonuçta bu bir prod beta sürümü. Açacağım uçuş/ilan verilerini
--  BO'dan silebilmem lazım. BO'da bu özellik var mı?"
--
-- CEVAP: KISMEN — ve olan kısmı da vaadini tutmuyordu.
--
--   1) İLAN (availabilities): /content sayfasında "Kaldır" butonu VAR
--      ama yaptığı tek şey `active=false`. Satır durur, keşiften düşer.
--      Beta test verisi için bu yetersiz: 50 tane çöp ilan tabloda
--      birikir, sayımları (dashboard KPI) bozar.
--
--   2) 🔴 /content'in Info kutusu "Bekleyen istek varsa guest'in kredisi
--      iade edilir" DİYOR. actions.js bunu YAPMIYOR — sadece active=false.
--      Yani ilanı kaldırınca misafirin kredisi escrow'da ASILI KALIYOR.
--      Bu, sahte uçuş verisiyle aynı kategoride: tutulmayan vaat.
--
--   3) UÇUŞ/SEYAHAT (visits): BO'da HİÇ YOK. Ne listeleme, ne silme.
--      Beta'da en çok üreteceğin veri bu.
--
-- BU DOSYA NE YAPIYOR:
--   · admin_delete_availability(id, hard) — yumuşak (active=false +
--     GERÇEK iade) veya sert (satırı sil). Sert silme yalnız bekleyen
--     isteği olmayan ilanlarda.
--   · admin_delete_visit(id) — seyahat sil
--   · admin_purge_test_data(before, dry_run) — beta sonrası toplu temizlik.
--     dry_run=true varsayılan: NE SİLİNECEĞİNİ GÖSTERİR, silmez.
--   · admin_list_visits() — BO'nun listeleyeceği veri
--
-- TASARIM KARARI — neden sert silme var:
-- Normalde üretimde sert silme istemezsin (denetim izi kaybolur).
-- Ama bu bir BETA ve Gokberk kendi test verisini üretecek. Çöp veri
-- KPI'ları, eşleşme skorlarını ve partner talep grafiklerini kirletir;
-- yanlış kararlara yol açar. O yüzden sert silme VAR ama:
--   · yalnız bekleyen/kabul edilmiş isteği OLMAYAN kayıtlarda
--   · her zaman audit_log'a yazılır (ne silindiği before_data'da durur)
--   · tamamlanmış oturuma bağlı ilan ASLA silinemez (geçmiş korunur)
-- ============================================================


-- ============================================================
-- admin_delete_availability
--   p_hard=false -> active=false + bekleyen isteklere GERÇEK iade
--   p_hard=true  -> satırı sil (yalnız istek yoksa)
-- ============================================================
create or replace function public.admin_delete_availability(
  p_id uuid, p_hard boolean default false, p_reason text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_a availabilities%rowtype; v_r record; v_bal int; v_refunded int := 0; v_done int;
begin
  select * into v_a from availabilities where id = p_id;
  if not found then raise exception 'availability_not_found'; end if;

  -- Tamamlanmış oturumu olan ilan asla silinmez — geçmiş korunur
  select count(*) into v_done
    from requests r join sessions s on s.request_id = r.id
   where r.avail_id = p_id and s.status in ('active','completed');
  if v_done > 0 and p_hard then
    raise exception 'has_sessions_cannot_hard_delete';
  end if;
  if exists (select 1 from sessions s join requests r on r.id = s.request_id
             where r.avail_id = p_id and s.status = 'active') then
    raise exception 'session_active';
  end if;

  -- Bekleyen/kabul edilmiş isteklere GERÇEK iade
  -- (Info kutusu bunu vaat ediyordu, kod yapmıyordu — artık yapıyor.)
  for v_r in select * from requests where avail_id = p_id and status in ('pending','accepted') loop
    update requests set status = 'cancelled' where id = v_r.id;
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_r.guest_id, 1, 'request_cancel_refund', v_r.id, v_bal + 1);
    v_refunded := v_refunded + 1;
    begin
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      values (v_r.guest_id, 'requests', 'İlan kaldırıldı',
              coalesce(left(p_reason,80), 'Host''un ilanı kaldırıldı. Kredin iade edildi.'),
              'request', v_r.id);
    exception when others then null;
    end;
  end loop;

  if p_hard then
    delete from requests where avail_id = p_id;   -- iptal edilmişler
    delete from availabilities where id = p_id;
  else
    update availabilities set active = false, updated_at = now() where id = p_id;
  end if;

  return jsonb_build_object('ok', true, 'hard', p_hard, 'refunded', v_refunded);
end $$;


-- ============================================================
-- admin_delete_visit — seyahat/uçuş kaydı sil
-- visits başka hiçbir tabloya referans vermiyor (001 kontrol edildi:
-- yalnız users ve airports'a FK verir, kimse ona vermez), bu yüzden
-- doğrudan silmek güvenli.
-- ============================================================
create or replace function public.admin_delete_visit(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_v visits%rowtype;
begin
  select * into v_v from visits where id = p_id;
  if not found then raise exception 'visit_not_found'; end if;
  delete from visits where id = p_id;
  return jsonb_build_object('ok', true, 'user_id', v_v.user_id, 'airport', v_v.airport_code);
end $$;


-- ============================================================
-- admin_list_visits — BO'nun listeleyeceği veri
-- (BO service role ile tabloyu doğrudan da okuyabilir ama profil
--  join'i ve filtreleri tek yerde tutmak daha temiz)
-- ============================================================
create or replace function public.admin_list_visits(
  p_airport text default null, p_from date default null, p_limit int default 100
)
returns table (
  id uuid, user_id uuid, user_name text, user_email text,
  airport_code text, destination text, visit_date date,
  time_from time, time_to time, flight_number text, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select v.id, v.user_id, p.name, u.email,
         v.airport_code::text, v.destination::text, v.visit_date,
         v.time_from, v.time_to, v.flight_number, v.created_at
  from visits v
  join users u on u.id = v.user_id
  left join profiles p on p.user_id = v.user_id
  where (p_airport is null or v.airport_code = p_airport)
    and (p_from is null or v.visit_date >= p_from)
  order by v.created_at desc
  limit coalesce(p_limit, 100);
$$;


-- ============================================================
-- admin_purge_test_data — beta sonrası toplu temizlik
--
-- dry_run VARSAYILAN olarak true: önce NE SİLİNECEĞİNİ gösterir.
-- Silmek için açıkça p_dry_run => false demen gerekir.
-- Tamamlanmış oturuma bağlı hiçbir şeye dokunmaz.
-- ============================================================
create or replace function public.admin_purge_test_data(
  p_before date, p_dry_run boolean default true
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_avail int; v_visits int; v_reqs int;
begin
  if p_before is null then raise exception 'date_required'; end if;
  if p_before > current_date then raise exception 'date_in_future'; end if;

  -- Sayım: tamamlanmış/aktif oturumu OLMAYAN ilanlar
  select count(*) into v_avail from availabilities a
   where a.avail_date < p_before
     and not exists (select 1 from requests r join sessions s on s.request_id = r.id
                      where r.avail_id = a.id and s.status in ('active','completed'));
  select count(*) into v_visits from visits where visit_date < p_before;
  select count(*) into v_reqs from requests r
   where exists (select 1 from availabilities a where a.id = r.avail_id and a.avail_date < p_before)
     and not exists (select 1 from sessions s where s.request_id = r.id and s.status in ('active','completed'));

  if p_dry_run then
    return jsonb_build_object('dry_run', true, 'would_delete',
      jsonb_build_object('availabilities', v_avail, 'visits', v_visits, 'requests', v_reqs));
  end if;

  delete from requests r
   where exists (select 1 from availabilities a where a.id = r.avail_id and a.avail_date < p_before)
     and not exists (select 1 from sessions s where s.request_id = r.id and s.status in ('active','completed'));
  delete from availabilities a
   where a.avail_date < p_before
     and not exists (select 1 from requests r join sessions s on s.request_id = r.id
                      where r.avail_id = a.id and s.status in ('active','completed'));
  delete from visits where visit_date < p_before;

  return jsonb_build_object('dry_run', false, 'deleted',
    jsonb_build_object('availabilities', v_avail, 'visits', v_visits, 'requests', v_reqs));
end $$;


-- Bu fonksiyonlar YALNIZ service_role içindir (BO sbAdmin ile çağırır).
-- authenticated'a KESİNLİKLE grant verilmiyor — bir kullanıcı
-- başkasının ilanını silememeli.
revoke all on function public.admin_delete_availability(uuid, boolean, text) from public, authenticated;
revoke all on function public.admin_delete_visit(uuid) from public, authenticated;
revoke all on function public.admin_list_visits(text, date, int) from public, authenticated;
revoke all on function public.admin_purge_test_data(date, boolean) from public, authenticated;
grant execute on function public.admin_delete_availability(uuid, boolean, text) to service_role;
grant execute on function public.admin_delete_visit(uuid) to service_role;
grant execute on function public.admin_list_visits(text, date, int) to service_role;
grant execute on function public.admin_purge_test_data(date, boolean) to service_role;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
select 'admin_delete_availability' as fonksiyon,
  case when exists (select 1 from pg_proc where proname='admin_delete_availability') then '✓' else '🔴 YOK' end as durum
union all select 'admin_delete_visit',
  case when exists (select 1 from pg_proc where proname='admin_delete_visit') then '✓' else '🔴 YOK' end
union all select 'admin_list_visits',
  case when exists (select 1 from pg_proc where proname='admin_list_visits') then '✓' else '🔴 YOK' end
union all select 'admin_purge_test_data',
  case when exists (select 1 from pg_proc where proname='admin_purge_test_data') then '✓' else '🔴 YOK' end
union all select 'mevcut ilan sayisi', count(*)::text from availabilities
union all select 'mevcut seyahat sayisi', count(*)::text from visits;
