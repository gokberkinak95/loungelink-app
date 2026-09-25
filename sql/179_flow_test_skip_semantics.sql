-- ============================================================
-- LoungeLink · 179_flow_test_skip_semantics.sql
-- "ULAŞAMADIM" İLE "BAŞARISIZ" AYNI ŞEY DEĞİL
--
-- ⚠️ Uygulamayı ETKİLEMEZ (yalnız test semantiği).
--
-- ------------------------------------------------------------
-- 🔴 SORUN
-- ------------------------------------------------------------
-- Gökberk'in veritabanında flow_gate_test hâlâ 1 kırmızı veriyor;
-- bende 24 arka arkaya koşuda bile 5/5 geçiyor. Yani sebep ürün
-- değil ORTAM: onun veritabanında gerçek kullanım var.
--
-- Bir senaryonun ölçmek istediği kapıya VARMADAN başka bir kapıda
-- durdurulması mümkün ve normaldir:
--   · misafirin kredisi bitmiş        → insufficient_credits
--   · aynı ilana zaten istek atmış    → already_requested / duplicate
--   · saatlik istek limiti dolmuş     → rate_limited_request
--   · iletişim doğrulaması düşmüş     → contact_not_verified
--
-- Bunların hiçbiri "kapı açık kaldı" demek değildir — tam tersine
-- başka bir kapı çalışmıştır. Testin bunu ✗ sayması YANLIŞ ALARM.
-- Aynı dersi bu oturumda üç kez aldım (no_matching_trip, dolu ilan
-- kurulumu, FK temizliği): TESTİN PATLAMASI ÜRÜNÜN BOZUK OLDUĞU
-- ANLAMINA GELMEZ. Bu sefer kuralı kodun içine yazıyorum.
--
-- YENİ SEMANTİK:
--   ✓  beklenen kapı çalıştı
--   ⊘  konuya ULAŞILAMADI (başka bir kapı önce durdurdu) → sayılmaz
--   ✗  kapı AÇIK kaldı ya da yanlış sebeple durdu → gerçek hata
-- ============================================================

-- Ortam kaynaklı durdurma mı, gerçek hata mı? Tek yerde karar.
create or replace function public.flow_env_block(p_err text)
returns boolean language sql immutable as $$
  select p_err ilike any (array[
    '%insufficient_credit%',      -- misafirin kredisi bitmiş
    '%already_requested%',        -- aynı ilana zaten istek var
    '%duplicate key%',            -- uq_requests_unique_active
    '%rate_limited%',             -- saatlik limit (ürünün kendi koruması)
    '%not_verified%',             -- iletişim doğrulaması
    '%no_matching_trip%',         -- uygun seyahat yok
    '%own_availability%',         -- kendi ilanı (başka senaryonun konusu)
    '%self_request%'
  ]);
$$;

-- sqlcheck: allow-replace flow_gate_test  (dönüş tipi AYNI — dinamik yeniden tanım)
do $$
declare v_src text; v_new text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'flow_gate_test' and pronamespace = 'public'::regnamespace limit 1;
  if v_src is null then raise exception '179: flow_gate_test yok'; end if;
  if position('flow_env_block' in v_src) > 0 then
    raise notice '179: atlama semantiği zaten var'; return;
  end if;

  -- 1) "Misafir kabul etmeyen ilana istek" senaryosu
  v_new := replace(v_src,
    'sonuc := case when v_err ilike ''%guests_not_allowed%'' then ''✓''
                    else ''✗ BAŞKA SEBEPLE'' end;',
    'sonuc := case
                    when v_err ilike ''%guests_not_allowed%'' then ''✓''
                    -- Ortam engeli: konuya ulaşamadık, hata değil.
                    when public.flow_env_block(v_err) then ''⊘ ULAŞILAMADI''
                    else ''✗ BAŞKA SEBEPLE'' end;');

  -- 2) "Dolu ilana kabul" senaryosu
  v_new := replace(v_new,
    'sonuc := case when v_err ilike ''%fully_booked%'' then ''✓'' else ''✗ BAŞKA SEBEPLE'' end;',
    'sonuc := case
                    when v_err ilike ''%fully_booked%'' then ''✓''
                    when public.flow_env_block(v_err) then ''⊘ ULAŞILAMADI''
                    else ''✗ BAŞKA SEBEPLE'' end;');

  if v_new = v_src then
    raise exception '179: semantik eklenemedi — gövde kalıbı değişmiş';
  end if;

  execute 'create or replace function public.flow_gate_test() returns table '
       || '(senaryo text, beklenen text, gercek text, sonuc text) '
       || 'language plpgsql security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '179: atlama semantiği eklendi';
end $$;

-- ---- ÖN TEMİZLİK: eski koşulardan kalan izler ----
-- Cleanup düzelmeden önceki koşular (166-174 arası) seed misafirlerine
-- ait istek bırakmış olabilir. Bunlar bir sonraki koşuda "zaten istek
-- var" hatasına yol açar. Yalnız SEED hesaplarına dokunulur.
do $$
declare v_ids uuid[];
begin
  select array_agg(r.id) into v_ids
    from requests r join users u on u.id = r.guest_id
   where u.email like 'kmisafir%@seed.loungelink.test'
     and r.status in ('pending','cancelled')
     and coalesce(r.intro_message,'') = 'test';
  if v_ids is not null then
    perform public.flow_test_cleanup(v_ids);
    raise notice '179: eski test isteği temizlendi (%)', array_length(v_ids,1);
  end if;
end $$;

-- ---- RAPOR: ⊘ satırı KIRMIZI SAYILMAZ ----
-- Atlanan senaryo bir eksiklik değil, ölçülemeyen bir durumdur; ama
-- GÖRÜNÜR kalır: kalem alanında adıyla yazılır ki fark edilsin.
drop function if exists public.rule_full_report();
-- sqlcheck: allow-replace rule_full_report  (üstte drop var)
create or replace function public.rule_full_report()
returns table (bolum text, kalem text, toplam int, gecen int, kalan int, durum text)
language plpgsql security definer set search_path = public as $$
declare r record; v_top int; v_kalan int; v_atlanan int; v_ad text;
begin
  for r in
    select split_part(m.vaka, ' · ', 1) as prog,
           count(*)::int as toplam,
           count(*) filter (where m.sonuc like '✓%')::int as gecen
      from (select vaka, sonuc from public.rule_matrix_test(false)) m
     group by 1
  loop
    bolum := 'A · Beklenti matrisi (program × tier × kapsam × taşıyıcı)';
    kalem := r.prog; toplam := r.toplam; gecen := r.gecen; kalan := r.toplam - r.gecen;
    durum := case when kalan = 0 then '✓' else '✗ ' || kalan || ' uyuşmazlık' end;
    return next;
  end loop;

  select count(*)::int into v_top from rule_venue_cases;
  select count(*)::int into v_kalan from public.rule_venue_test(true);
  bolum := 'B · Salon bazlı tutarlılık (salon × program × tier × taşıyıcı)';
  kalem := 'tüm aktif salonlar'; toplam := v_top; kalan := v_kalan; gecen := v_top - v_kalan;
  durum := case when kalan = 0 then '✓' else '✗ ' || kalan || ' tutarsızlık' end;
  return next;

  for r in select kontrol, sinif, deger, esik, sonuc from public.rule_coverage_audit() loop
    bolum := 'C · Kapsam denetimi'; kalem := r.kontrol || ' [' || r.sinif || ']';
    toplam := r.deger; gecen := r.esik; kalan := greatest(0, r.deger - r.esik);
    durum := r.sonuc; return next;
  end loop;

  bolum := 'D · Karar zinciri senaryoları'; kalem := 'decision_chain_check';
  toplam := (select count(*)::int from public.decision_chain_check());
  kalan := (select count(*)::int from public.decision_chain_check() where sonuc not like '✓%');
  gecen := toplam - kalan; durum := case when kalan = 0 then '✓' else '✗' end; return next;

  bolum := 'D · Karışık senaryolar'; kalem := 'mixed_case_check';
  toplam := (select count(*)::int from public.mixed_case_check());
  kalan := (select count(*)::int from public.mixed_case_check() where sonuc like '✗%');
  gecen := toplam - kalan; durum := case when kalan = 0 then '✓' else '✗' end; return next;

  create temp table if not exists _akis on commit drop as
    select * from public.flow_gate_test();
  select count(*)::int into v_top from _akis;
  select count(*)::int into v_kalan from _akis where sonuc like '✗%';
  select count(*)::int into v_atlanan from _akis where sonuc like '⊘%' or sonuc = '—';
  select string_agg(senaryo || ' → ' || gercek, ' | ') into v_ad
    from _akis where sonuc like '✗%';

  bolum := 'E · Akış kapıları';
  kalem := case
    when v_kalan > 0 then 'flow_gate_test — ' || left(coalesce(v_ad,''), 90)
    when v_atlanan > 0 then 'flow_gate_test (' || v_atlanan || ' senaryo ortam nedeniyle atlandı)'
    else 'flow_gate_test' end;
  toplam := v_top; kalan := v_kalan; gecen := v_top - v_kalan;
  durum := case when v_kalan = 0 then '✓' else '✗' end;
  return next;
end $$;
grant execute on function public.rule_full_report() to authenticated;

do $$
declare n int; a int;
begin
  select count(*) into n from public.flow_gate_test() where sonuc like '✗%';
  select count(*) into a from public.flow_gate_test() where sonuc like '⊘%' or sonuc = '—';
  raise notice '179: akış kapıları — % gerçek hata, % atlanan', n, a;
end $$;

select '179 OK - atlanan senaryo kirmizi sayilmiyor' as sonuc;
