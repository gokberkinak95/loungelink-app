-- ============================================================================
-- 350 · REHBER 187 YAMASI CANLIYA + İNCELEME VİTRİNİ TAZE   (9 Kasım 2026)
--
-- Ölçüm (canlı, 349 sonrası):
--   · DENETIM_TAM: guide_lounges canlı ≠ dosyalar. `187-oncelik:` canlıda YOK (false).
--     187 rehberi dinamik yamalıyor (salonun kabul satırı "misafir yok" diyorsa program
--     kuralı onu ezemez). Yama canlıda düşmüş: rehber "misafir götürebilirsin", karar
--     motoru "götüremezsin" diyebilir (187 §5, AJET_MS × ELITE_PLUS/ELITE/CLASSIC_PLUS).
--   · İnceleme hesabının göreceği bugün ve sonrası açık vitrin ilanı: 0. Fikstür ilanlarının
--     tarihi geçmiş; `test_verisi_tazele()` yalnız elle çağrılıyordu (270).
--
-- Yapılan:
--   1) 187 §5 yaması birebir yeniden uygulanır (zaten varsa dokunmaz).
--   2) Fikstür ilanları/seyahatleri ileri tarihe taşınır (test_verisi_tazele, 270).
--   3) Hâlâ açık vitrin ilanı yoksa @vitrin.loungelink.test ilanları yeniden açılır
--      (satır satır; iş kuralına takılan atlanır).
--   4) pg_cron `ll-vitrin-tazele` her gece 03:30: Apple incelemesi günler sürebilir,
--      vitrin incelemenin ortasında bayatlamasın.
-- Fikstür hesapları gerçek kullanıcıya GÖRÜNMEZ (270a: 0 satır); yalnız ekip ve
-- test_gorunurlugu'ndaki hesaplar (inceleme hesabı, 333) görür.
-- Tekrar koşulabilir. Doğrulama: 4 satır.
-- ============================================================================

-- 1 · 187 §5 (birebir)
do $s350a$
declare v_src text; v_new text; v_args text; v_res text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'guide_lounges' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  if v_oid is null then raise exception '350: guide_lounges yok'; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;

  if position('187-oncelik:' in v_src) > 0 then
    raise notice '350: rehber onceligi zaten guncel'; return;
  end if;

  v_new := replace(v_src,
'    if a.guest_policy = ''not_allowed'' and guest_count = 0 then',
'    -- 🔴 187-oncelik: 174 ile AYNI kural. Salonun kabul satiri
    -- "misafir yok" diyorsa, program duzeyi kural onu EZEMEZ.
    -- Yalniz SALONA OZEL kural (venue_scope dolu) ezebilir.
    if a.guest_policy = ''not_allowed''
       and (g ->> ''venue_scope'') is null then
      verdict := ''self_only'';
      headline := coalesce(nullif(g ->> ''headline'', ''''),
                           ''Bu salon yalniz kart sahibini aliyor'');
      guest_count := 0;
    elsif a.guest_policy = ''not_allowed'' and guest_count = 0 then');

  if v_new = v_src then
    raise notice '350: rehber kalibi bulunamadi - dogrulama false doner'; return;
  end if;

  v_args := pg_get_function_arguments(v_oid);
  v_res  := pg_get_function_result(v_oid);
  execute 'create or replace function public.guide_lounges(' || v_args
       || ') returns ' || v_res
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '350: rehber artik salon kisitina uyuyor';
end $s350a$;

-- 2 · fikstür tarihleri ileri
select public.test_verisi_tazele(2) as tazeleme;

-- 3 · hâlâ açık vitrin ilanı yoksa vitrin ilanlarını yeniden aç
do $s350b$
declare r record; v_acik int; v_n int := 0; v_atla int := 0;
begin
  select count(*) into v_acik
    from availabilities a join users u on u.id = a.host_id
   where a.active and a.avail_date >= current_date and u.deleted_at is null
     and (u.email like '%@vitrin.loungelink.test' or u.email like '%@seed.loungelink.test');
  if v_acik > 0 then
    raise notice '350: % acik vitrin ilani var, yeniden acma gerekmedi', v_acik; return;
  end if;
  for r in
    select a.id from availabilities a join users u on u.id = a.host_id
     where not a.active and u.deleted_at is null and u.email like '%@vitrin.loungelink.test'
  loop
    begin
      update availabilities
         set active = true,
             avail_date = greatest(avail_date, current_date + 2 + (abs(hashtext(r.id::text)) % 5))
       where id = r.id;
      v_n := v_n + 1;
    exception when others then
      v_atla := v_atla + 1;
    end;
  end loop;
  raise notice '350: % vitrin ilani yeniden acildi, % atlandi', v_n, v_atla;
end $s350b$;

-- 4 · her gece tazele
do $s350c$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'll-vitrin-tazele') then
      perform cron.unschedule('ll-vitrin-tazele');
    end if;
    perform cron.schedule('ll-vitrin-tazele', '30 3 * * *', 'select public.test_verisi_tazele(2)');
    raise notice '350: pg_cron isi kuruldu - ll-vitrin-tazele, her gece 03:30.';
  else
    raise notice '350: pg_cron yok - is kurulmadi.';
  end if;
end $s350c$;

-- DOĞRULAMA (4 satır)
select 'rehber 187 yamasi canlida' as kontrol,
       coalesce((select bool_and(position('187-oncelik:' in prosrc) > 0) from pg_proc
                  where proname = 'guide_lounges' and pronamespace = 'public'::regnamespace), false)::text as sonuc
union all
select 'fikstur hesabi (vitrin + seed)',
       (select count(*) from users where deleted_at is null
         and (email like '%@vitrin.loungelink.test' or email like '%@seed.loungelink.test'))::text
union all
select 'inceleme icin acik vitrin ilani (bugun ve sonrasi)',
       (select count(*) from availabilities a join users u on u.id = a.host_id
         where a.active and a.avail_date >= current_date and u.deleted_at is null
           and (u.email like '%@vitrin.loungelink.test' or u.email like '%@seed.loungelink.test'))::text
union all
select 'vitrin ilani olan havalimani',
       coalesce((select string_agg(distinct a.airport_code, ', ') from availabilities a join users u on u.id = a.host_id
         where a.active and a.avail_date >= current_date and u.deleted_at is null
           and (u.email like '%@vitrin.loungelink.test' or u.email like '%@seed.loungelink.test')), '-');
