-- ============================================================================
-- LoungeLink · 234_aktif_oturum_kendini_anlatsin.sql        (22 Ağustos 2026)
--
-- "OTURUM DEVAM EDİYOR" EKRANI KİMİNLE, NEREDE OLDUĞUNU BİLMİYOR
-- (Gökberk, madde 2)
--
-- Ekranda:
--     Birlikte: Guest          ← karşı tarafın adı yerine ham veri
--     LOUNGE   Lounge oturumu  ← salon adı yerine yer tutucu metin
--
-- ════════════════════════════════════════════════════════════════════════
-- KÖK SEBEP — EKRAN VERİYİ HİÇ İSTEMİYOR
-- ════════════════════════════════════════════════════════════════════════
-- `Chat` bileşeni (screens.js:2769) karşı tarafın adını AÇANIN verdiği
-- string'den alıyor (`otherName` prop). Açanlardan biri `null` geçiyor
-- (App.js:720 — LiveStatus), biri seed hesabının ham adını geçiyor.
-- Bileşen `otherId`'yi hiçbir yerde profile çözmüyor.
--
-- Salon adı ise `request.availabilities`'ten okunuyor (screens.js:2990)
-- ama eksik `request` nesnesini onaran sorgu availabilities'i JOIN
-- ETMİYOR (screens.js:2807):
--     .select("id, host_id, guest_id, avail_id, status, intro_message, type, purpose")
-- `avail_id` geliyor, `lounge_name` hiç gelmiyor → `t.loungeSession`
-- yani "Lounge oturumu" yer tutucusu ekrana düşüyor.
--
-- 🔴 VE SUNUCUDA BU VERİ İÇİN HİÇBİR ŞEY YOK: aktif oturumu anlatan bir
-- RPC yok. `sessions` tablosu doğrudan okunuyor (screens.js:2836) ve o
-- tabloda ne salon adı ne katılımcı adı var. Tamamlanmış oturumun
-- karşılığı VAR (`pending_ratings`, 187:50 — other_name, lounge, uçuş,
-- saat hepsi orada) ama AKTİF oturumun yok.
--
-- 🆕 SINIF: **"BİR EKRANIN YANLIŞ BİLGİ GÖSTERMESİ, ÇOĞU ZAMAN O BİLGİYİ
-- HİÇ İSTEMEMESİNDENDİR."** Yer tutucu bir tasarım tercihi gibi görünür;
-- aslında sorulmamış bir sorunun cevabıdır.
--
-- ⚠️ NEDEN `Chat`'İN İÇİNDEN SORGU YAZMIYORUM: aynı ekran altı ayrı
-- yerden açılıyor ve her açan farklı bir `request` şekli geçiriyor.
-- Onarımı istemciye bırakırsam altı yerde altı kez onarmam gerekir —
-- bu dosyanın varlık sebebi tam da o: TEK KAYNAK.
-- ============================================================================

drop function if exists public.aktif_oturum_detay(uuid);
create or replace function public.aktif_oturum_detay(p_request_id uuid)
returns table (
  session_id uuid, request_id uuid, durum text,
  other_id uuid, other_name text, i_am_host boolean,
  lounge text, airport_code text, avail_date date,
  time_from time, time_to time, flight_number text, carrier text,
  started_at timestamptz, completed_at timestamptz,
  host_confirmed boolean, guest_confirmed boolean,
  cancel_grace_until timestamptz
)
language plpgsql stable security definer set search_path = public as $ao$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select s.id, r.id, s.status::text,
         case when r.host_id = v_uid then r.guest_id else r.host_id end,
         -- 🔴 `coalesce(p.name, 'Yolcu')` — 187'nin kalıbı. Ham uuid ya da
         -- boş string ekrana DÜŞMEZ; düşerse kullanıcı "Guest" görür ve
         -- bu ekranın tamamı güvenilmez olur.
         coalesce(nullif(btrim(p.name), ''), 'Yolcu'),
         (r.host_id = v_uid),
         -- Salon adı: serbest metin → katalog adı → havalimanı kodu.
         -- Üçü de yoksa NULL döner ve istemci kendi yer tutucusunu koyar;
         -- burada uydurma bir ad ÜRETMİYORUZ.
         coalesce(nullif(btrim(a.lounge_name), ''), l.name, a.airport_code::text),
         a.airport_code::text,
         a.avail_date, a.time_from, a.time_to,
         a.flight_number, a.carrier,
         s.started_at, s.completed_at,
         s.host_confirmed, s.guest_confirmed,
         s.cancel_grace_until
    from sessions s
    join requests r on r.id = s.request_id
    left join availabilities a on a.id = r.avail_id
    left join lounges l on l.id = a.lounge_id
    left join profiles p
      on p.user_id = case when r.host_id = v_uid then r.guest_id else r.host_id end
   where r.id = p_request_id
     and (r.host_id = v_uid or r.guest_id = v_uid)   -- taraf değilsen 0 satır
   limit 1;
end $ao$;
grant execute on function public.aktif_oturum_detay(uuid) to authenticated;

comment on function public.aktif_oturum_detay(uuid) is
  'Aktif/bekleyen oturum ekraninin TEK veri kaynagi. pending_ratings(187) ne '
  'yapiyorsa aktif oturum icin ayni sey. Taraf olmayan 0 satir alir.';

-- ----------------------------------------------------------------------------
-- NÖBETÇİ
-- ----------------------------------------------------------------------------
do $n234$
declare
  v_kolon int;
  v_yer   int;
begin
  select coalesce(array_length(p.proallargtypes,1),0) into v_kolon
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='aktif_oturum_detay' limit 1;
  if coalesce(v_kolon,0) < 18 then
    raise exception '234 NOBETCI: aktif_oturum_detay % argumanla kuruldu, >=18 bekleniyordu.', v_kolon;
  end if;

  -- 🔴 ASIL SINAMA: gerçekten aktif bir oturum varsa, adı ve salonu
  -- YER TUTUCU OLMAYAN bir değerle dönüyor mu? Veri yoksa sustuğumu
  -- söylüyorum — sessizce geçmiyorum.
  if not exists (select 1 from sessions) then
    raise notice '234 OLCULMEDI: veritabaninda hic oturum yok — cikti icerigi sinanmadi. '
                 'SEED sonrasi tekrar bakilmali.';
  else
    select count(*) into v_yer
      from sessions s
      join requests r on r.id = s.request_id
      left join availabilities a on a.id = r.avail_id
      left join lounges l on l.id = a.lounge_id
     where coalesce(nullif(btrim(a.lounge_name),''), l.name, a.airport_code::text) is null;
    if v_yer > 0 then
      raise notice '234 UYARI: % oturumun salon adi UCU DE bos (lounge_name, katalog, havalimani). '
                   'Bu bir VERI eksigi; RPC uydurma ad uretmiyor.', v_yer;
    else
      raise notice '234 OK · her oturum bir salon adi uretebiliyor';
    end if;
  end if;
end $n234$;

-- ----------------------------------------------------------------------------
-- RPC YÜZEYİ
-- ----------------------------------------------------------------------------
insert into rpc_client_surface (fn_name, client, note) values
  ('aktif_oturum_detay','app','Aktif oturum ekrani: karsi tarafin adi + salon + ucus (234)')
on conflict (fn_name) do update set note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '234: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '234 AKTIF OTURUM DETAYI KURULDU' as sonuc,
       (select count(*) from sessions where status = 'active') as aktif_oturum;
