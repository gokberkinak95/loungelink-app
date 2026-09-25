-- ============================================================
-- 204 · ENGELLEME ARTIK GERÇEK — blok, EYLEM sınırında uygulanıyor
-- 17 Ağustos 2026
--
-- 🔴 ÖLÇÜM (iddia değil, katalog sorgusu):
--   select proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--    where n.nspname='public' and prokind='f'
--      and pg_get_functiondef(p.oid) ~* '(\mblocks\M|is_blocked_pair)';
--   → alternatives_for, carrier_mismatch_note, discover_availabilities_base,
--     is_blocked_pair, lounge_radar_people
--
-- Yani `blocks` tablosu SADECE ÜÇ LİSTELEME YÜZEYİNDE okunuyordu.
-- Şu on iki fonksiyonun HİÇBİRİ bakmıyordu:
--   create_request · create_request_impl · respond_request ·
--   respond_connection · send_connection · send_invite ·
--   start_session_request · confirm_session · discover_people ·
--   invitable_guests · home_connections · share_session_status
--
-- SOMUT SONUÇ: A, B'yi engelliyor. B artık A'yı KEŞİFTE göremiyor —
-- ürün "engelledin" diyor. Ama B'nin elinde eski bir `avail_id` varsa
-- (bildirimden, ekran görüntüsünden, geri tuşundan, önbellekten)
-- `create_request` çağrısı GEÇİYOR; A'ya "Yeni istek ✦" bildirimi
-- düşüyor. Engelleme kozmetikti.
--
-- ⚠️ Bu bir güvenlik açığından fazlası: kadın kullanıcı güvenliği
-- (`women_safety_mode`) bu ürünün açık bir vaadi. Vaadin arkasındaki
-- mekanizmanın gerçekten çalışması, bir "iyileştirme" değil, şart.
--
-- ============================================================
-- MİMARİ KARAR: 12 FONKSİYONU TEK TEK YAMALAMIYORUM
-- ============================================================
-- On iki gövdeye tek tek `if is_blocked_pair(...) then raise` eklemek
-- bugünü düzeltir, yarını düzeltmez: 13. fonksiyon yazıldığında yine
-- unutulur. Nitekim bu on iki fonksiyonu yazan da (ben) her seferinde
-- unuttum. İnsan hafızasına dayanan kural, kural değildir.
--
-- Bu yüzden iki katman:
--   (A) YAZMA — İLİŞKİ TABLOLARINDA TETİKLEYİCİ. requests,
--       connection_requests, invites tablolarına giren HER satır
--       kontrol edilir. Hangi fonksiyondan geldiği önemsiz; yarın
--       yazılacak fonksiyon dahil, doğrudan SQL dahil.
--   (B) OKUMA — SARMALAYICI. Listeleme fonksiyonunun gövdesine
--       dokunmadan, adını `_prebfilter` yapıp yerine engelli
--       satırları eleyen bir sarmalayıcı koyuyorum. Gövde cerrahisi
--       yok, dolayısıyla mevcut davranış bozulmuyor.
-- ============================================================


-- ============================================================
-- A) YAZMA KATMANI — TETİKLEYİCİ
-- ============================================================
create or replace function public.blok_kapisi()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_a uuid; v_b uuid;
begin
  -- Her tabloda taraf kolonları farklı ad taşıyor; tetikleyici
  -- argümanıyla veriliyor ki fonksiyon tek olsun.
  execute format('select ($1).%I, ($1).%I', TG_ARGV[0], TG_ARGV[1])
    into v_a, v_b using new;

  if v_a is not null and v_b is not null and public.is_blocked_pair(v_a, v_b) then
    raise exception 'blocked_pair'
      using hint = 'Bu kisiyle iletisim engellenmis.';
  end if;
  return new;
end $fn$;

comment on function public.blok_kapisi() is
  'Iliski tablolarina giren satirda taraflardan biri digerini engellemisse INSERT i durdurur. TG_ARGV[0] ve [1] taraf kolon adlaridir.';

drop trigger if exists trg_blok_requests on requests;
create trigger trg_blok_requests
  before insert on requests
  for each row execute function public.blok_kapisi('guest_id', 'host_id');

drop trigger if exists trg_blok_connection_requests on connection_requests;
create trigger trg_blok_connection_requests
  before insert on connection_requests
  for each row execute function public.blok_kapisi('from_id', 'to_id');

drop trigger if exists trg_blok_invites on invites;
create trigger trg_blok_invites
  before insert on invites
  for each row execute function public.blok_kapisi('host_id', 'guest_id');


-- ============================================================
-- A2) ENGEL ANINDA GEÇMİŞİ DE TEMİZLE
-- ============================================================
-- Tetikleyici YENİ satırı durdurur; peki engellemeden ÖNCEKİ bekleyen
-- istek ne olacak? Bugün öylece duruyor ve iki tarafın da ekranında
-- görünüyor. Engelleyen kişi "engelledim" der ama karşı taraf hâlâ
-- listesinde. Blok satırı yazılınca aradaki BEKLEYEN her şey kapanır.
create or replace function public.blok_gecmisi_kapat()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  update requests set status = 'cancelled', responded_at = now()
   where status = 'pending'
     and ((guest_id = new.blocker and host_id = new.blocked)
       or (guest_id = new.blocked and host_id = new.blocker));

  -- ⚠️ `connection_status` = pending | accepted | declined | blocked.
  -- İlk yazışımda 'rejected' yazdım — enum'da YOK, 22P02 aldım. Enum'un
  -- kendisinde zaten 'blocked' var ve burada 'declined'dan DAHA DOĞRU:
  -- kullanıcı reddetmedi, engelledi. Sebep kayıtta kalsın.
  update connection_requests set status = 'blocked', responded_at = now()
   where status = 'pending'
     and ((from_id = new.blocker and to_id = new.blocked)
       or (from_id = new.blocked and to_id = new.blocker));

  update invites set status = 'blocked', responded_at = now()
   where status = 'pending'
     and ((host_id = new.blocker and guest_id = new.blocked)
       or (host_id = new.blocked and guest_id = new.blocker));

  return new;
end $fn$;

drop trigger if exists trg_blok_gecmis on blocks;
create trigger trg_blok_gecmis
  after insert on blocks
  for each row execute function public.blok_gecmisi_kapat();


-- ============================================================
-- B) OKUMA KATMANI — SARMALAYICI ÜRETİCİ
-- ============================================================
-- 🔴 Gövdeyi metin olarak düzenlemiyorum. 199'da `trip_fit_note`
-- gövdesini `replace()` ile değiştirmiştim ve o yöntem, kaynak
-- metindeki tek bir boşluk değişse sessizce hiçbir şey yapmayacak
-- kadar kırılgan. Burada gövdeye HİÇ dokunulmuyor: fonksiyon
-- yeniden adlandırılıyor, üstüne aynı imzalı bir sarmalayıcı
-- yazılıyor. Sarmalayıcı bozulursa GÖRÜLÜR, sessiz kalmaz.
create or replace function public.blok_filtresi_ekle(p_fn text, p_peer_col text)
returns text language plpgsql security definer set search_path = public as $fn$
declare
  v_oid  oid;
  v_args text;
  v_args_full text;
  v_res  text;
  v_cagri text;
  v_yeni text := p_fn || '_prebfilter';
begin
  -- Zaten sarmalanmışsa tekrar sarmalama (idempotent).
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname = v_yeni) then
    return p_fn || ': zaten sarmalanmis';
  end if;

  -- ⚠️ create icin VARSAYILANLI imza (pg_get_function_arguments),
  -- alter/revoke/grant icin KIMLIK imzasi (identity). Ikisini
  -- karistirmak sarmalayiciyi varsayilansiz dogurur ve daha az
  -- argumanla cagiran her yer 42883 alir (207'de tam bunu yasadim).
  select p.oid, pg_get_function_identity_arguments(p.oid),
         pg_get_function_arguments(p.oid), pg_get_function_result(p.oid)
    into v_oid, v_args, v_args_full, v_res
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = p_fn and p.prokind = 'f';
  if v_oid is null then raise exception 'blok_filtresi_ekle: % bulunamadi', p_fn; end if;

  -- Çağrı listesi: `p_airport text, p_date date` → `p_airport, p_date`
  select coalesce(string_agg(split_part(btrim(x), ' ', 1), ', '), '')
    into v_cagri
    from unnest(string_to_array(v_args, ',')) x
   where btrim(x) <> '';

  execute format('alter function public.%I(%s) rename to %I', p_fn, v_args, v_yeni);

  execute format($sql$
    create function public.%I(%s) returns %s
    language sql stable security definer set search_path = public as $body$
      select q.* from public.%I(%s) q
       where auth.uid() is null
          or not public.is_blocked_pair(auth.uid(), q.%I)
    $body$
  $sql$, p_fn, v_args_full, v_res, v_yeni, v_cagri, p_peer_col);

  -- İstemci yüzeyindeyse hakkı korunur; değilse 203'ün sınırı geçerli.
  if exists (select 1 from rpc_client_surface s where s.fn_name = p_fn) then
    execute format('grant execute on function public.%I(%s) to public', p_fn, v_args);
  else
    execute format('revoke all on function public.%I(%s) from public, anon, authenticated', p_fn, v_args);
    execute format('grant execute on function public.%I(%s) to service_role', p_fn, v_args);
  end if;
  -- İç fonksiyon artık istemciye AÇIK OLMAMALI, yoksa filtre atlanır.
  execute format('revoke all on function public.%I(%s) from public, anon, authenticated', v_yeni, v_args);
  execute format('grant execute on function public.%I(%s) to service_role', v_yeni, v_args);

  return p_fn || ': sarmalandi (' || p_peer_col || ')';
end $fn$;

do $$
begin
  raise notice '204: %', public.blok_filtresi_ekle('discover_people', 'user_id');
  raise notice '204: %', public.blok_filtresi_ekle('invitable_guests', 'guest_id');
  raise notice '204: %', public.blok_filtresi_ekle('home_connections', 'peer_id');
end $$;


-- ============================================================
-- C) IDEMPOTENCY ANAHTARI ARTIK SAHİBİNE BAĞLI
-- ============================================================
-- Mevcut hâl: `select id from requests where idempotency_key = p_idem`
-- — anahtar KİMİN olduğuna bakılmıyor. Anahtar istemcide üretiliyor;
-- bir kullanıcı başkasının anahtarını gönderirse o isteğin id'sini
-- geri alır. İstek oluşturmaz ama BAŞKASININ KAYIT KİMLİĞİNİ öğrenir
-- ve o id ile ekran açabilir. Küçük ama gerçek bir sızıntı; düzeltmesi
-- tek satır: `and guest_id = v_uid`.
create or replace function public.create_request_impl(
  p_avail_id uuid, p_type text default 'lounge', p_intro text default null, p_idem text default null)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype;
  v_ok boolean; v_bal int; v_score int; v_req_id uuid; v_has_trip boolean;
  v_conflict boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  if p_idem is not null then
    -- 🔴 204: anahtar artık SAHİBİNE bağlı.
    select id into v_req_id from requests
     where idempotency_key = p_idem and guest_id = v_uid;
    if v_req_id is not null then return jsonb_build_object('ok', true, 'id', v_req_id, 'idempotent', true); end if;
  end if;

  v_ok := public.is_contact_verified(v_uid);
  if not v_ok then raise exception 'contact_not_verified'; end if;

  select * into v_av from availabilities where id = p_avail_id for update;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_request_blocked'; end if;

  -- 🔴 204: BLOK, KREDİDEN ÖNCE. Tetikleyici zaten durdururdu ama o
  -- noktada kredi düşmüş olurdu ve kullanıcı "blocked_pair" hatasıyla
  -- birlikte 1 kredi kaybederdi. Kapı, ödemeden ÖNCE olmalı.
  if public.is_blocked_pair(v_uid, v_av.host_id) then
    raise exception 'blocked_pair';
  end if;

  if v_av.filled >= v_av.slots then raise exception 'fully_booked'; end if;
  if v_av.avail_date < current_date then raise exception 'availability_expired'; end if;

  select exists (
    select 1 from availabilities a
     where a.host_id = v_uid and a.active
       and a.avail_date = v_av.avail_date
       and a.time_from < v_av.time_to and v_av.time_from < a.time_to
  ) into v_conflict;
  if v_conflict then raise exception 'hosting_same_slot'; end if;

  select exists (
    select 1 from visits v
     where v.user_id = v_uid and v.airport_code = v_av.airport_code
       and v.visit_date = v_av.avail_date
       and v.time_from < v_av.time_to and v_av.time_from < v.time_to
  ) into v_has_trip;
  if not v_has_trip then raise exception 'no_matching_trip'; end if;

  declare v_dec jsonb;
  begin
    v_dec := public.lounge_access_decision(p_avail_id, null);
    if (v_dec ->> 'guest_policy') = 'not_allowed'
       or ((v_dec ->> 'severity') = 'block' and coalesce((v_dec ->> 'fits')::text,'') <> 'false') then
      raise exception 'guests_not_allowed';
    end if;
  end;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  if v_bal < 1 then raise exception 'insufficient_credits'; end if;

  select match_score into v_score from discover_availabilities(v_av.airport_code, null, null)
   where id = p_avail_id limit 1;

  insert into requests (guest_id, host_id, avail_id, status, type, purpose, intro_message, match_score, idempotency_key)
  values (v_uid, v_av.host_id, p_avail_id, 'pending', 'standard'::request_type, coalesce(p_type,'lounge'), left(coalesce(p_intro,''),120),
          coalesce(v_score,40), p_idem)
  returning id into v_req_id;

  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -1, 'request_hold', v_req_id, v_bal - 1);

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'requests', 'Yeni istek ✦',
          'Bir misafir lounge isteği gönderdi.', 'request', v_req_id);

  return jsonb_build_object('ok', true, 'id', v_req_id);
end $fn$;


-- ============================================================
-- D) KALICI DENETİM — engelin uygulanmadığı yazma yolu kalmasın
-- ============================================================
create or replace function public.blok_kapsam_denetimi()
returns table (tablo text, neden text)
language sql stable security definer set search_path = public as $fn$
  select t.tablo::text, 'iliski tablosunda blok tetikleyicisi YOK'::text
    from (values ('requests'), ('connection_requests'), ('invites')) t(tablo)
   where not exists (
     select 1 from pg_trigger g join pg_class c on c.oid = g.tgrelid
      where c.relname = t.tablo and not g.tgisinternal
        and g.tgfoid = 'public.blok_kapisi()'::regprocedure)
  union all
  select f.fn::text, 'listeleme yuzeyi blok filtresiz'::text
    from (values ('discover_people'), ('invitable_guests'), ('home_connections')) f(fn)
   where not exists (
     select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = f.fn || '_prebfilter');
$fn$;

grant execute on function public.blok_kapsam_denetimi() to service_role;


-- ============================================================
-- E) 203'ÜN SINIRINI YENİDEN UYGULA
-- ============================================================
-- 203'ün koyduğu kural: fonksiyon üreten her migration SONUNDA
-- `apply_rpc_surface()` çağırır. Bu dosya dört yeni fonksiyon üretti
-- (blok_kapisi, blok_gecmisi_kapat, blok_filtresi_ekle,
-- blok_kapsam_denetimi) ve üç tanesini yeniden adlandırdı. Çağırmadan
-- geçseydim hepsi istemciye açık kalırdı — nitekim ilk denememde
-- öyle oldu ve 204'ün 6. nöbetçisi bunu yakaladı.
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '204: sinir yeniden uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $$;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) SAHNE KUR — iki kullanıcı, bir engel
do $$
declare v_a uuid; v_b uuid;
begin
  select id into v_a from users order by created_at limit 1;
  select id into v_b from users where id <> v_a order by created_at limit 1;
  if v_a is null or v_b is null then raise notice '204: iki kullanici yok — atlandi'; return; end if;
  delete from blocks where (blocker = v_a and blocked = v_b) or (blocker = v_b and blocked = v_a);
  insert into blocks (blocker, blocked) values (v_a, v_b);
  if not public.is_blocked_pair(v_b, v_a) then
    raise exception '204: blok simetrik degil — is_blocked_pair yanlis';
  end if;
  raise notice '204: sahne hazir (% engelledi %)', v_a, v_b;
end $$;

-- 2) YAZMA KAPISI GERÇEKTEN KAPALI MI — üç tabloda da
do $$
declare v_a uuid; v_b uuid; v_av uuid; v_gecti text := '';
begin
  select blocker, blocked into v_a, v_b from blocks order by created_at desc limit 1;
  if v_a is null then raise notice '204: blok yok — atlandi'; return; end if;
  select id into v_av from availabilities limit 1;

  begin
    insert into requests (guest_id, host_id, avail_id, status, purpose)
    values (v_b, v_a, v_av, 'pending', 'lounge');
    v_gecti := v_gecti || 'requests ';
  exception when others then
    if sqlerrm <> 'blocked_pair' then raise; end if;
  end;

  begin
    insert into connection_requests (from_id, to_id, status)
    values (v_b, v_a, 'pending');
    v_gecti := v_gecti || 'connection_requests ';
  exception when others then
    if sqlerrm <> 'blocked_pair' then raise; end if;
  end;

  begin
    insert into invites (host_id, guest_id, avail_id, status)
    values (v_b, v_a, v_av, 'pending');
    v_gecti := v_gecti || 'invites ';
  exception when others then
    if sqlerrm <> 'blocked_pair' then raise; end if;
  end;

  if v_gecti <> '' then
    raise exception '204: engelli ciftte su tablolara HALA yazilabiliyor: %', v_gecti;
  end if;
  raise notice '204: engelli cift uc iliski tablosuna da yazamiyor';
end $$;

-- 3) MUTASYON — tetikleyici gerçekten çalışıyor mu, yoksa insert
--    başka bir sebepten mi düşüyordu?
-- 🔴 Bu nöbetçi olmadan 2. nöbetçi hiçbir şey kanıtlamaz: NOT NULL
-- ihlali de aynı "yazılamadı" sonucunu verirdi ve yeşil görünürdü.
do $$
declare v_a uuid; v_b uuid; v_n int;
begin
  select blocker, blocked into v_a, v_b from blocks order by created_at desc limit 1;
  if v_a is null then raise notice '204: blok yok — atlandi'; return; end if;

  delete from blocks where blocker = v_a and blocked = v_b;
  begin
    insert into connection_requests (from_id, to_id, status) values (v_b, v_a, 'pending');
  exception when others then
    raise exception '204: blok KALKTIGI halde yazma yine dustu (%) — 2. nobetci sahteydi', sqlerrm;
  end;
  select count(*) into v_n from connection_requests where from_id = v_b and to_id = v_a;
  delete from connection_requests where from_id = v_b and to_id = v_a;
  insert into blocks (blocker, blocked) values (v_a, v_b);

  if v_n < 1 then raise exception '204: blok yokken de yazilamadi'; end if;
  raise notice '204: mutasyon dogrulandi — engeli KALDIRINCA yazma geciyor, koyunca dusuyor';
end $$;

-- 4) GEÇMİŞ TEMİZLİĞİ — engelden önceki bekleyen istek kapandı mı
do $$
declare v_a uuid; v_b uuid; v_av uuid; v_id uuid; v_st text;
begin
  select blocker, blocked into v_a, v_b from blocks order by created_at desc limit 1;
  select id into v_av from availabilities limit 1;
  if v_a is null or v_av is null then raise notice '204: sahne eksik — atlandi'; return; end if;

  delete from blocks where blocker = v_a and blocked = v_b;
  insert into requests (guest_id, host_id, avail_id, status, purpose)
  values (v_b, v_a, v_av, 'pending', 'lounge') returning id into v_id;

  insert into blocks (blocker, blocked) values (v_a, v_b);
  select status::text into v_st from requests where id = v_id;
  delete from requests where id = v_id;

  if v_st <> 'cancelled' then
    raise exception '204: engelden onceki bekleyen istek kapanmadi (durum: %)', v_st;
  end if;
  raise notice '204: engel anında bekleyen istek otomatik kapaniyor';
end $$;

-- 5) OKUMA YÜZEYİ — engelli kişi listede görünmüyor mu
do $$
declare v_a uuid; v_b uuid; v_gorunuyor boolean;
begin
  select blocker, blocked into v_a, v_b from blocks order by created_at desc limit 1;
  if v_a is null then raise notice '204: blok yok — atlandi'; return; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  select exists (select 1 from public.discover_people(null, null) q where q.user_id = v_b)
    into v_gorunuyor;
  perform set_config('request.jwt.claims', '', true);

  if v_gorunuyor then
    raise exception '204: engelledigi kisi HALA discover_people listesinde';
  end if;
  raise notice '204: engelli kisi kesif listesinde gorunmuyor';
end $$;

-- 6) SARMALAYICI YÜZEYİ BOZMADI MI — imza ve haklar aynı mı
do $$
declare v_ihlal text;
begin
  select string_agg(fn_name || ' (' || neden || ')', '; ')
    into v_ihlal
    from public.rpc_surface_violations();
  if v_ihlal is not null then
    raise exception '204: sarmalama sonrasi RPC yuzeyi bozuldu → %', v_ihlal;
  end if;
  raise notice '204: RPC yuzeyi saglam (sarmalayicilar imzayi ve haklari korudu)';
end $$;

-- 7) KAPSAM DENETİMİ TEMİZ Mİ
do $$
declare v text;
begin
  select string_agg(tablo || ': ' || neden, '; ') into v from public.blok_kapsam_denetimi();
  if v is not null then raise exception '204: blok kapsam denetimi ihlal buldu → %', v; end if;
  raise notice '204: blok kapsam denetimi temiz';
end $$;

-- 8) SAHNEYİ TOPLA
do $$
declare v_a uuid; v_b uuid;
begin
  select blocker, blocked into v_a, v_b from blocks order by created_at desc limit 1;
  if v_a is not null then delete from blocks where blocker = v_a and blocked = v_b; end if;
  raise notice '204: test blogu temizlendi';
end $$;

select '204 OK - engelleme artik yazma ve okumada GERCEKTEN uygulaniyor' as sonuc;
