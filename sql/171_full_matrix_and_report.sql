-- ============================================================
-- LoungeLink · 171_full_matrix_and_report.sql
-- SALON BAZLI MATRİS + ÇAPRAZ TAŞIYICI + TAM GÖRÜNÜRLÜK
--
-- ⚠️ Uygulamayı ETKİLEMEZ (test/rapor katmanı).
--
-- Gökberk üç şey söyledi ve üçü de doğru:
--
-- 1) "Satır sayısı azalmış, diğer kontroller nereye kayboldu?"
--    Kaybolmadı: rule_matrix_test(true) YALNIZ KIRMIZILARI döndürür,
--    düzelen vaka listeden çıkar. Ama bu, ekranda "az kontrol var"
--    izlenimi veriyor — bir denetimin GÖRÜNMEMESİ, güvenilmemesiyle
--    aynı şey. Artık rule_matrix_report() TAM tabloyu, program
--    program özetiyle birlikte veriyor.
--
-- 2) "Neden sadece M&S statüsü? PP, DragonPass, LoungeKey, Pegasus
--    da olmalı." Aslında 480 vakanın içinde hepsi VAR — ama hepsi
--    GEÇTİĞİ için kırmızı listede görünmüyorlardı. Görünürlük
--    sorunuydu; yine de kapsamı bu dosyada gerçekten genişletiyoruz.
--
-- 3) "Lounge lounge kurallara göre de denetlenmeli." EN DEĞERLİ
--    itiraz buydu. Şimdiye kadar matris KAPSAM düzeyindeydi
--    (domestic/international/abroad) — oysa aynı havalimanında iki
--    bölüm farklı davranır (IST dış hatta Business bölümünde kimseye
--    misafir yok, M&S bölümünde Elite'e var). Kapsam düzeyi bu farkı
--    ÖRTÜYORDU; kalan 15 kırmızının sebebi de buydu. Matris artık
--    SALON BAZINDA çalışıyor.
-- ============================================================

-- ---- 1) SALON BAZLI VAKA ÜRETİMİ ----
-- Her (aktif salon × onu kabul eden program × o programın kart tipi)
-- üçlüsü bir vakadır. Beklenti, o salonun kabul satırından ve kural
-- verisinden DEĞİL — motorun cevabını doğrulamak için bağımsız
-- kaynaktan gelir: kabul matrisi (lounge_venue_acceptance) ne
-- diyorsa çelişki aranır. Böylece test motoru değil, motorun İKİ
-- VERİ KAYNAĞI ARASINDAKİ TUTARLILIĞINI ölçer.
create table if not exists rule_venue_cases (
  id           bigserial primary key,
  venue_id     uuid not null,
  venue_adi    text not null,
  airport      text not null,
  scope        text,
  program_code text not null,
  card_tier    text,
  carrier_class text not null,
  beklenti     text not null,      -- 'kabul_ile_tutarli' | 'engel'
  created_at   timestamptz default now()
);
create unique index if not exists uq_rule_venue_case
  on rule_venue_cases (venue_id, program_code, coalesce(card_tier,'-'), carrier_class);

do $$
declare n int;
begin
  delete from rule_venue_cases;

  insert into rule_venue_cases
    (venue_id, venue_adi, airport, scope, program_code, card_tier, carrier_class, beklenti)
  select v.id, v.name, v.airport_code, v.scope, p.code, t.tier, c.cc,
         case when a.accepted then 'kabul_ile_tutarli' else 'engel' end
    from lounge_venues v
    join lounge_venue_acceptance a on a.venue_id = v.id and a.active
    join lounge_programs p on p.id = a.program_id and p.active
    cross join lateral (
      select distinct r.card_tier as tier from lounge_guest_rules r
       where r.program_id = p.id and r.card_tier is not null
      union all select null) t
    cross join (values ('TK'),('VF'),('SA'),('OTHER'),('UNKNOWN')) as c(cc)
   where v.active
  on conflict do nothing;

  get diagnostics n = row_count;
  raise notice '171: % salon-bazlı vaka üretildi (salon × program × tier × taşıyıcı)', n;
end $$;

-- ---- 2) SALON BAZLI KOŞUCU ----
-- Her vaka için motorun cevabını alır ve İKİ TUTARLILIK kuralını sınar:
--   · Kabul matrisi o salonda o programı KABUL ETMİYORSA motor da
--     misafir hakkı vermemeli (aksi hâlde kapıda ret)
--   · Motor bir kural bulamıyorsa (program varsayılanına düşüyorsa)
--     bu bir boşluktur — kullanıcıya tahmin sunmuş oluruz
drop function if exists public.rule_venue_test(boolean);
create or replace function public.rule_venue_test(p_only_fail boolean default true)
returns table (havalimani text, salon text, program text, tier text, tasiyici text,
               motor text, kabul text, sonuc text)
language plpgsql stable security definer set search_path = public as $$
declare r record; v_pid uuid; v_carr text; j jsonb; v_g int; v_found boolean; v_pol text;
begin
  for r in select * from rule_venue_cases order by airport, venue_adi, program_code, card_tier nulls first, carrier_class loop
    select id into v_pid from lounge_programs where code = r.program_code;
    v_carr := case r.carrier_class
                when 'TK' then 'TK' when 'VF' then 'VF'
                when 'SA' then (select code from carriers where alliance='star_alliance' and code<>'TK' limit 1)
                when 'OTHER' then (select code from carriers where coalesce(alliance,'')<>'star_alliance' and code not in ('TK','VF') limit 1)
                else null end;

    j := public.resolve_guest_rule(v_pid, r.venue_id, r.card_tier, v_carr, null);
    v_found := coalesce((j ->> 'found')::boolean, false);
    v_g := coalesce((j ->> 'guest_allowance')::int, 0);
    select a.guest_policy into v_pol from lounge_venue_acceptance a
     where a.venue_id = r.venue_id and a.program_id = v_pid and a.active limit 1;

    havalimani := r.airport; salon := r.venue_adi; program := r.program_code;
    tier := coalesce(r.card_tier,'—'); tasiyici := r.carrier_class;
    motor := case when v_found then 'kural: ' else 'VARSAYILAN: ' end || v_g || ' misafir';
    kabul := coalesce(v_pol,'—');

    sonuc := case
      when not v_found then '✗ KURAL YOK (tahmin sunuluyor)'
      when r.beklenti = 'engel' and v_g > 0 then '✗ KABUL YOK AMA MİSAFİR VAR'
      when v_pol = 'not_allowed' and v_g > 0 then '✗ POLİTİKA ÇELİŞKİSİ'
      else '✓' end;

    if (not p_only_fail) or sonuc not like '✓%' then return next; end if;
  end loop;
end $$;
grant execute on function public.rule_venue_test(boolean) to authenticated;

-- ---- 3) TAM RAPOR: her şey tek ekranda ----
-- "3-5 satırlık veriye bakınca konu kaçmış gibi görünüyor" — haklı.
-- Bu fonksiyon HER kontrolü, geçenler dahil, program program özetler.
drop function if exists public.rule_full_report();
create or replace function public.rule_full_report()
returns table (bolum text, kalem text, toplam int, gecen int, kalan int, durum text)
language plpgsql stable security definer set search_path = public as $$
declare r record;
begin
  -- A) Program bazlı beklenti matrisi (167/168/170)
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

  -- B) Salon bazlı tutarlılık (171)
  bolum := 'B · Salon bazlı tutarlılık (salon × program × tier × taşıyıcı)';
  kalem := 'tüm aktif salonlar';
  toplam := (select count(*)::int from rule_venue_cases);
  kalan := (select count(*)::int from public.rule_venue_test(true));
  gecen := toplam - kalan;
  durum := case when kalan = 0 then '✓' else '✗ ' || kalan || ' tutarsızlık' end;
  return next;

  -- C) Kapsam denetimi (163/164/166)
  for r in select kontrol, sinif, deger, esik, sonuc from public.rule_coverage_audit() loop
    bolum := 'C · Kapsam denetimi'; kalem := r.kontrol || ' [' || r.sinif || ']';
    toplam := r.deger; gecen := r.esik; kalan := greatest(0, r.deger - r.esik);
    durum := r.sonuc;
    return next;
  end loop;

  -- D) Senaryo testleri (156/157)
  bolum := 'D · Karar zinciri senaryoları'; kalem := 'decision_chain_check';
  toplam := (select count(*)::int from public.decision_chain_check());
  kalan := (select count(*)::int from public.decision_chain_check() where sonuc not like '✓%');
  gecen := toplam - kalan;
  durum := case when kalan = 0 then '✓' else '✗' end; return next;

  bolum := 'D · Karışık senaryolar'; kalem := 'mixed_case_check';
  toplam := (select count(*)::int from public.mixed_case_check());
  kalan := (select count(*)::int from public.mixed_case_check() where sonuc like '✗%');
  gecen := toplam - kalan;
  durum := case when kalan = 0 then '✓' else '✗' end; return next;

  -- E) Akış kapıları (166)
  bolum := 'E · Akış kapıları'; kalem := 'flow_gate_test';
  toplam := (select count(*)::int from public.flow_gate_test());
  kalan := (select count(*)::int from public.flow_gate_test() where sonuc like '✗%');
  gecen := toplam - kalan;
  durum := case when kalan = 0 then '✓' else '✗' end; return next;
end $$;
grant execute on function public.rule_full_report() to authenticated;

-- ---- 4) ÇELİŞKİ LİSTESİ: kaynaktan doğrulanması gerekenler ----
-- Kalan aile-hakkı uyuşmazlıklarında motor bir şey, benim beklentim
-- başka bir şey diyor ve HANGİSİNİN DOĞRU OLDUĞUNU RESMÎ TABLOYA
-- BAKMADAN BİLEMEM. Sessizce beklentiyi motora uydurmak testi
-- anlamsızlaştırır (motor ne derse doğru sayılır); motoru beklentiye
-- uydurmak da veriyi bozabilir. Doğrusu: bunları AÇIKÇA "insan
-- doğrulaması bekliyor" diye işaretlemek.
alter table rule_test_cases add column if not exists needs_review boolean default false;

update rule_test_cases c
   set needs_review = true,
       kaynak = coalesce(kaynak,'') || ' · 171: motor ile beklenti çelişiyor, resmî tablodan teyit gerek'
 where c.level = 'exact'
   and exists (
     select 1 from public.rule_matrix_test(true) m
      where m.vaka = c.program_code || ' · ' || coalesce(c.card_tier,'(tier yok)')
                     || ' · ' || c.venue_scope || ' · ' || c.carrier_class
        and m.sonuc like '%AİLE%');

do $$
declare n int;
begin
  select count(*) into n from rule_test_cases where needs_review;
  if n > 0 then
    raise notice '171: % vaka İNSAN DOĞRULAMASI bekliyor (aile hakkı çelişkisi) — '
                 'select * from rule_test_cases where needs_review;', n;
  end if;
end $$;

select '171 OK - salon bazli matris + tam rapor' as sonuc;
