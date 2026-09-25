-- ============================================================
-- LoungeLink · 061_fix_respond_request_and_slots.sql
--
-- 🔴🔴 EN KRİTİK DÜZELTME — çekirdek döngü şu an KIRIK.
--
-- BULGU 1 (akış kırıcı): respond_request geçersiz enum değeri yazıyor.
--   notifications.category bir `notif_category` enum'u ve geçerli değerler
--   ÇOĞUL: requests|sessions|invites|connections|system|safety|credits|ratings
--   Ama respond_request TEKİL 'request' yazıyor →
--     ERROR: invalid input value for enum notif_category: "request"
--   Sonuç: HOST BİR İSTEĞİ KABUL EDEMİYOR. Reddedemiyor da.
--   Yani ilan→başvuru→KABUL→sohbet→oturum zinciri 3. adımda duruyor.
--   Neden fark edilmedi: 026/027 aynı hatayı start_session/send_connection/
--   respond_connection'da düzeltmiş, ama respond_request 007'den beri hiç
--   yeniden tanımlanmamış. Ve iki-hesap canlı testi henüz yapılmadı.
--
-- BULGU 2 (sessiz veri hatası): slot muhasebesi hiç çalışmıyor.
--   availabilities.filled 007/009'da artırılıyordu; 026'da fonksiyon yeniden
--   yazılırken ARTIŞ DÜŞTÜ, 033 de onu devraldı. Yani `filled` hep 0 kalıyor:
--     • "fully_booked" kontrolü hiç tetiklenmiyor → 1 slotluk ilana sınırsız
--       kabul yapılabilir (host lounge'a 5 kişi almış olabilir)
--     • Uygulamadaki "● N açık" göstergesi HER ZAMAN yanlış (hep tam kapasite)
--   Ayrıca iki farklı muhasebe modeli çakışıyordu: 007 "istekte tut / redde
--   iade", 032 ise "kabulde doldur" varsayıyor (yalnız accepted ise düşürüyor).
--
-- SEÇİLEN MODEL — "KABULDE DOLDUR" (ürün olarak doğrusu):
--   Bekleyen istek slotu BLOKLAMAZ. 1 slota 5 kişi başvurabilir, host
--   aralarından seçer. Slot ancak KABUL edilince dolar. Böylece bekleyen tek
--   bir başvuru diğerlerini engellemez ve host seçme hakkını korur.
--   (Alternatif "istekte tut" modeli ilk başvuranı ayrıcalıklı kılardı.)
--   Kredi escrow'u aynen kalıyor: istekte tutulur, red/iptalde iade edilir.
-- ============================================================


-- ============================================================
-- 1) respond_request — enum düzeltmesi + doğru slot muhasebesi
--    (007'deki gövde birebir korundu; yalnız kategori ve slot kısmı değişti)
-- ============================================================
create or replace function public.respond_request(
  p_request_id uuid,
  p_action     text  -- 'accept' | 'decline' | 'cancel'
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_req  requests%rowtype;
  v_av   availabilities%rowtype;
  v_bal  integer;
  v_chan uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_req from requests where id = p_request_id for update;
  if not found then raise exception 'request_not_found'; end if;

  if p_action = 'accept' then
    if v_req.host_id <> v_uid then raise exception 'not_host'; end if;
    if v_req.status <> 'pending' then raise exception 'not_pending'; end if;

    -- Slot kapasitesi: ilan satırını KİLİTLE, sonra kontrol et.
    -- (for update olmadan iki eşzamanlı kabul son slotu birlikte geçebilirdi.)
    select * into v_av from availabilities where id = v_req.avail_id for update;
    if not found then raise exception 'availability_not_found'; end if;
    if coalesce(v_av.filled,0) >= v_av.slots then raise exception 'fully_booked'; end if;

    update requests set status='accepted', responded_at=now() where id = v_req.id;

    -- SLOT DOLDUR (026'da düşen adım geri geldi)
    update availabilities set filled = coalesce(filled,0) + 1, updated_at = now()
     where id = v_req.avail_id;

    insert into chat_channels (request_id) values (v_req.id)
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req.id;

    -- 🔴 'request' → 'requests' (geçerli enum değeri)
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (v_req.guest_id, 'requests', 'İstek kabul edildi! 🎉', 'Sohbet açıldı.', v_req.id, 'request');

    return jsonb_build_object('ok', true, 'channel_id', v_chan);

  elsif p_action in ('decline','cancel') then
    if p_action = 'decline' and v_req.host_id  <> v_uid then raise exception 'not_host'; end if;
    if p_action = 'cancel'  and v_req.guest_id <> v_uid then raise exception 'not_guest'; end if;
    if v_req.status not in ('pending','accepted') then raise exception 'not_open'; end if;

    update requests set status = case when p_action='decline' then 'declined' else 'cancelled' end::request_status,
           responded_at = now()
     where id = v_req.id;

    -- Kredi iadesi (escrow çözülür) — her iki durumda da
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_req.guest_id, 1, 'request_refund', v_req.id, v_bal + 1);

    -- SLOT İADESİ yalnızca istek DAHA ÖNCE KABUL EDİLMİŞSE.
    -- Bekleyen bir istek slotu hiç doldurmamıştı; onu düşürmek sayacı bozardı.
    if v_req.status = 'accepted' then
      update availabilities set filled = greatest(coalesce(filled,0) - 1, 0), updated_at = now()
       where id = v_req.avail_id;
    end if;

    -- 🔴 'request' → 'requests'
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (case when p_action='decline' then v_req.guest_id else v_req.host_id end,
            'requests',
            case when p_action='decline' then 'İstek reddedildi' else 'İstek iptal edildi' end,
            'Kredi anında iade edildi.', v_req.id, 'request');
    return jsonb_build_object('ok', true);
  end if;

  raise exception 'unknown_action';
end $$;

grant execute on function public.respond_request(uuid, text) to authenticated;


-- ============================================================
-- 2) MEVCUT VERİYİ ONAR — filled sayacını gerçek kabullerden yeniden hesapla
--    (026'dan beri yanlış olduğu için birikmiş sapma olabilir)
-- ============================================================
update availabilities a
   set filled = coalesce(x.n, 0)
  from (
    select av.id,
           count(r.id) filter (
             where r.status = 'accepted'
           ) as n
      from availabilities av
      left join requests r on r.avail_id = av.id
     group by av.id
  ) x
 where x.id = a.id
   and coalesce(a.filled,0) <> coalesce(x.n,0);


-- ============================================================
-- 3) EKSİK İNDEKSLER — ölçek büyüyünce yavaşlayacak sıcak yollar
--    connection_requests: discover_people HER Tanış açılışında from_id/to_id
--    üzerinden sorguluyordu ve tabloda HİÇ indeks yoktu (tam tablo taraması).
-- ============================================================
create index if not exists idx_conn_from    on connection_requests(from_id, status);
create index if not exists idx_conn_to      on connection_requests(to_id, status);
create index if not exists idx_ratings_rated on ratings(rated_id);
create index if not exists idx_ratings_sess  on ratings(session_id, rater_id);
create index if not exists idx_invites_host  on invites(host_id, status);
create index if not exists idx_invites_guest on invites(guest_id, status);


-- ============================================================
-- 4) DOĞRULAMA
-- ============================================================

-- 4.1 respond_request artık doğru (çoğul) kategoriyi mi yazıyor?
--     "gecerli" iki satır da true dönmeli.
select
  (prosrc ilike '%''requests''%')                        as "cogul_dogru_kullanilmis",
  (prosrc not ilike '%category, title%''request'',%')    as "tekil_kalmadi"
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.proname='respond_request';

-- 4.2 filled sayacı gerçek kabullerle tutarlı mı? (boş dönmeli)
select av.id, av.filled as "kayitli", count(r.id) filter (where r.status='accepted') as "gercek"
from availabilities av
left join requests r on r.avail_id = av.id
group by av.id, av.filled
having av.filled <> count(r.id) filter (where r.status='accepted');

select '061 OK — respond_request enum duzeltildi (KABUL ARTIK CALISIYOR), slot muhasebesi onarildi, indeksler eklendi' as sonuc;
