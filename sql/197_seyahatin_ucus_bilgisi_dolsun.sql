-- ============================================================
-- 197 · SEYAHATİN UÇUŞ BİLGİSİ ARTIK GERÇEKTEN DOLUYOR
-- 17 Ağustos 2026
--
-- ------------------------------------------------------------
-- 🔴 ÖLÇÜM: ALTI KOLON, SIFIR YAZAN
-- ------------------------------------------------------------
-- 083_lounge_rules_and_flight_prep.sql `visits` tablosuna altı kolon
-- eklemişti:
--     flight_verified · scheduled_departure · scheduled_arrival
--     terminal · flight_source · flight_checked_at
--
-- Bugün bütün kod tabanını taradım: app, backoffice, site ve 218 SQL
-- dosyası. Bu altı kolona YAZAN TEK BİR SATIR YOK. Kolonlar on dört
-- dosya boyunca boş durdu.
--
-- Bu, bu projede DÖRDÜNCÜ kez tekrarlanan sınıf:
--   "KOLON EKLEMEK, O KOLONA YAZMA YOLUNU AÇMAK DEĞİLDİR."
-- (193'te `card_label` ile, 191'de `cabin_class` ile, 083'te burada.)
-- Şema hazır olduğu için iş bitmiş görünüyor; oysa veri hiç akmıyor.
--
-- ------------------------------------------------------------
-- NEDEN ÖNEMLİ — BOŞ KOLON SESSİZ BİR ÜRÜN KAYBI
-- ------------------------------------------------------------
-- Misafir "14:00–18:00 arası IST'teyim" yazıyor ve uçuşu 15:20'de
-- kalkıyor olabilir. Motor bunu bilmediği için:
--   · 16:00'daki bir ilanı ona ADAY GÖSTERİYOR (uçağı çoktan kalkmış)
--   · "aynı uçuştayız" rozetini yalnız ELLE yazılmış numaraya bakarak
--     veriyor; numara yanlış yazılmışsa rozet YANLIŞ çıkıyor
--   · terminal bilgisi elimizde olduğu hâlde eşleşmede kullanılmıyor
--
-- ------------------------------------------------------------
-- ÇÖZÜM: İKİ YÖNLÜ TETİKLEYİCİ
-- ------------------------------------------------------------
-- Tek yönlü olsaydı yarısı çalışırdı ve bu en yanıltıcı hâl olurdu:
--   A) Seyahat yazıldığında önbellekte veri VARSA → hemen damgala
--   B) Önbelleğe yeni uçuş düştüğünde → o uçuşu bekleyen seyahatleri
--      GERİYE DÖNÜK doldur
-- Kullanıcı uçuş numarasını önbellekte veri OLMADAN girer, veri
-- sonradan gelir. (B) olmasaydı o seyahat sonsuza kadar boş kalırdı.
--
-- 🔴 TETİKLEYİCİ ASLA THROW ETMEZ. Uçuş bilgisi bir SÜSTÜR; seyahat
-- kaydının kendisi kritiktir. Sağlayıcı verisi yüzünden kullanıcı
-- seyahatini kaydedemezse ürünü kırmış oluruz. (194'ün bekleme listesi
-- tetikleyicisi BİLEREK istisnaydı: o bir yazma kapısıydı, bu bir yan
-- etki.)
-- ============================================================

-- ---- 1) TEK BİR SEYAHATİ DAMGALA ----
create or replace function public.sync_visit_flight(p_visit_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare v visits%rowtype; c flight_cache%rowtype;
begin
  select * into v from visits where id = p_visit_id;
  if not found or coalesce(v.flight_number,'') = '' or v.visit_date is null then
    return false;
  end if;

  select * into c from flight_cache
   where upper(replace(flight_no,' ','')) = upper(replace(trim(v.flight_number),' ',''))
     and flight_date = v.visit_date;
  if not found then
    -- Önbellekte yok: DOKUNMA. Eski damgayı silmek, "bir zamanlar
    -- doğrulanmıştı" bilgisini kaybetmek olurdu.
    return false;
  end if;

  update visits set
    flight_verified     = true,
    scheduled_departure = c.scheduled_departure,
    scheduled_arrival   = c.scheduled_arrival,
    terminal            = coalesce(c.terminal, visits.terminal),
    -- 🔴 TAŞIYICI: kod paylaşımında İŞLETEN yazılır (195). Kural motoru
    -- salon hakkını uçuran havayoluna göre değerlendiriyor; seyahat
    -- kaydı da onunla tutarlı olmalı, yoksa iki yerde iki cevap olur.
    carrier_code        = coalesce(
                            nullif(public.flight_carrier_resolve(c.flight_no, c.flight_date) ->> 'carrier',''),
                            visits.carrier_code),
    flight_source       = coalesce(c.source, 'aviationstack'),
    flight_checked_at   = c.fetched_at
  where id = p_visit_id;
  return true;
end $$;
grant execute on function public.sync_visit_flight(uuid) to authenticated;


-- ---- 2) A YÖNÜ: seyahat yazıldı/güncellendi ----
create or replace function public.trg_visit_flight_sync()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    perform public.sync_visit_flight(new.id);
  exception when others then
    null;   -- 🔴 uçuş verisi seyahat kaydını ASLA düşürmez
  end;
  return null;   -- AFTER tetikleyici
end $$;

drop trigger if exists trg_visit_flight_ins on visits;
create trigger trg_visit_flight_ins after insert on visits
  for each row when (new.flight_number is not null)
  execute function public.trg_visit_flight_sync();

drop trigger if exists trg_visit_flight_upd on visits;
create trigger trg_visit_flight_upd after update of flight_number, visit_date on visits
  for each row when (new.flight_number is not null
                     and (new.flight_number is distinct from old.flight_number
                          or new.visit_date is distinct from old.visit_date))
  execute function public.trg_visit_flight_sync();


-- ---- 3) B YÖNÜ: önbelleğe yeni uçuş düştü → bekleyenleri doldur ----
-- 🔴 BU YÖN OLMADAN SİSTEM YARIM ÇALIŞIR ve yarım çalışan bir şey,
-- hiç çalışmayandan daha zor fark edilir: bazı seyahatler dolu, bazıları
-- boş görünür ve sebebi anlaşılmaz.
create or replace function public.trg_flight_cache_backfill()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record;
begin
  begin
    for r in select v.id from visits v
              where upper(replace(coalesce(v.flight_number,''),' ','')) =
                    upper(replace(new.flight_no,' ',''))
                and v.visit_date = new.flight_date
    loop
      perform public.sync_visit_flight(r.id);
    end loop;
  exception when others then
    null;   -- önbellek yazımı ASLA düşmez
  end;
  return null;
end $$;

drop trigger if exists trg_flight_cache_backfill on flight_cache;
create trigger trg_flight_cache_backfill after insert or update on flight_cache
  for each row execute function public.trg_flight_cache_backfill();


-- ---- 4) BO / rapor: kaç seyahat doğrulanmış ----
create or replace function public.visit_flight_coverage()
returns table (toplam int, ucus_yazan int, dogrulanan int, oran text)
language sql stable security definer set search_path = public as $$
  select count(*)::int,
         count(*) filter (where coalesce(flight_number,'') <> '')::int,
         count(*) filter (where flight_verified)::int,
         case when count(*) filter (where coalesce(flight_number,'') <> '') = 0
              then 'uçuş numarası yazan seyahat yok'
              else round(100.0 * count(*) filter (where flight_verified)
                         / count(*) filter (where coalesce(flight_number,'') <> ''), 1)::text || '%'
         end
    from visits
   where visit_date >= current_date - 30
$$;
grant execute on function public.visit_flight_coverage() to authenticated;


-- ============================================================
-- BEKÇİLER
-- ============================================================

-- 1) A YÖNÜ: önbellek ÖNCE, seyahat SONRA
do $$
declare v_uid uuid; v_vid uuid; v visits%rowtype;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then raise notice '197: seed kullanicisi yok — A yonu atlandi'; return; end if;

  insert into flight_cache (flight_no, flight_date, departure_iata, arrival_iata,
                            scheduled_departure, scheduled_arrival, terminal, status,
                            source, fetched_at, airline, airline_iata, operating_iata)
  values ('TK197A', current_date + 2, 'IST', 'LHR',
          (current_date + 2)::timestamptz + interval '9 hours',
          (current_date + 2)::timestamptz + interval '13 hours',
          '1', 'scheduled', 'bekci', now(), 'Turkish Airlines', 'TK', 'TK')
  on conflict (flight_no, flight_date) do nothing;

  insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
  values (v_uid, 'IST', current_date + 2, '08:00', '12:00', 'TK197A')
  returning id into v_vid;

  select * into v from visits where id = v_vid;
  if not coalesce(v.flight_verified, false) then
    delete from visits where id = v_vid;
    delete from flight_cache where source = 'bekci';
    raise exception '197: A yonu CALISMIYOR — seyahat yazildi ama damgalanmadi';
  end if;
  if v.scheduled_departure is null or v.terminal is null or v.flight_source is null then
    delete from visits where id = v_vid;
    delete from flight_cache where source = 'bekci';
    raise exception '197: A yonu EKSIK damgaladi (kalkis=% terminal=% kaynak=%)',
      v.scheduled_departure, v.terminal, v.flight_source;
  end if;
  delete from visits where id = v_vid;
  delete from flight_cache where source = 'bekci';
  raise notice '197: A yonu — seyahat yazilinca onbellekten damgalandi';
end $$;

-- 2) B YÖNÜ: seyahat ÖNCE, önbellek SONRA (geriye dönük doldurma)
do $$
declare v_uid uuid; v_vid uuid; v visits%rowtype;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then raise notice '197: seed kullanicisi yok — B yonu atlandi'; return; end if;

  insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
  values (v_uid, 'IST', current_date + 3, '08:00', '12:00', 'TK197B')
  returning id into v_vid;

  select * into v from visits where id = v_vid;
  if coalesce(v.flight_verified, false) then
    delete from visits where id = v_vid;
    raise exception '197: onbellekte YOKKEN dogrulanmis gorundu — uydurma damga';
  end if;

  insert into flight_cache (flight_no, flight_date, departure_iata, arrival_iata,
                            scheduled_departure, scheduled_arrival, terminal, status,
                            source, fetched_at, airline, airline_iata, operating_iata)
  values ('TK197B', current_date + 3, 'IST', 'CDG',
          (current_date + 3)::timestamptz + interval '10 hours',
          (current_date + 3)::timestamptz + interval '13 hours',
          '2', 'scheduled', 'bekci', now(), 'Turkish Airlines', 'TK', 'AF')
  on conflict (flight_no, flight_date) do nothing;

  select * into v from visits where id = v_vid;
  if not coalesce(v.flight_verified, false) then
    delete from visits where id = v_vid;
    delete from flight_cache where source = 'bekci';
    raise exception '197: B yonu CALISMIYOR — onbellek geldi ama seyahat GERIYE DONUK dolmadi';
  end if;
  -- Kod paylaşımı: işleten AF, seyahatin taşıyıcısı da AF olmalı
  if coalesce(v.carrier_code,'') <> 'AF' then
    delete from visits where id = v_vid;
    delete from flight_cache where source = 'bekci';
    raise exception '197: kod paylasiminda ISLETEN tasiyici seyahate yazilmadi (gelen %)', v.carrier_code;
  end if;
  delete from visits where id = v_vid;
  delete from flight_cache where source = 'bekci';
  raise notice '197: B yonu — onbellek gelince seyahat geriye donuk doldu, isleten tasiyici yazildi';
end $$;

-- 3) VERİ YOKSA UYDURMA YOK
do $$
declare v_uid uuid; v_vid uuid; v visits%rowtype;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then raise notice '197: seed yok — atlandi'; return; end if;
  insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
  values (v_uid, 'IST', current_date + 4, '08:00', '12:00', 'ZZ9999')
  returning id into v_vid;
  select * into v from visits where id = v_vid;
  if coalesce(v.flight_verified, false) or v.scheduled_departure is not null then
    delete from visits where id = v_vid;
    raise exception '197: olmayan ucus icin veri UYDURULDU';
  end if;
  delete from visits where id = v_vid;
  raise notice '197: onbellekte olmayan ucus icin hicbir sey uydurulmuyor';
end $$;

-- 4) TETİKLEYİCİ SEYAHAT KAYDINI DÜŞÜREMEZ
-- 🔴 Bu bekçi bir GÜVENLİK bekçisi: sync fonksiyonunu bilerek bozup
-- seyahatin YİNE DE yazılabildiğini kanıtlıyor. Tetikleyicinin
-- "throw etmiyor" olduğunu iddia etmek yetmez; ölçmek gerekir.
do $$
declare v_uid uuid; v_vid uuid; v_src text;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  if v_uid is null then raise notice '197: seed yok — atlandi'; return; end if;

  select prosrc into v_src from pg_proc
   where proname = 'sync_visit_flight' and pronamespace = 'public'::regnamespace;

  execute 'create or replace function public.sync_visit_flight(p_visit_id uuid) '
       || 'returns boolean language plpgsql as $B$ begin '
       || 'raise exception ''197 bilerek bozuldu''; end $B$';

  insert into visits (user_id, airport_code, visit_date, time_from, time_to, flight_number)
  values (v_uid, 'IST', current_date + 5, '08:00', '12:00', 'TK197C')
  returning id into v_vid;

  execute 'create or replace function public.sync_visit_flight(p_visit_id uuid) '
       || 'returns boolean language plpgsql security definer set search_path = public as $B$'
       || v_src || '$B$';

  if v_vid is null then
    raise exception '197: sync bozukken seyahat YAZILAMADI — tetikleyici urunu kiriyor';
  end if;
  delete from visits where id = v_vid;
  raise notice '197: sync bozukken bile seyahat yazildi (tetikleyici yan etki, kapi degil)';
end $$;

-- 5) KAPSAMA RAPORU ÇAĞRILABİLİYOR
do $$
declare r record;
begin
  select * into r from public.visit_flight_coverage();
  raise notice '197: son 30 gun — % seyahat, %si ucus numarali, %si dogrulanmis (%)',
    r.toplam, r.ucus_yazan, r.dogrulanan, r.oran;
end $$;

select '197 OK - visits ucus kolonlari artik iki yonlu doluyor' as sonuc;
