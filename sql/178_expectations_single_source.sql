-- ============================================================
-- LoungeLink · 178_expectations_single_source.sql
-- KALICI ÇÖZÜM: BEKLENTİLER ÜRETECİN İÇİNDE
--
-- ⚠️ Uygulamayı ETKİLEMEZ (test/rapor katmanı).
--
-- ------------------------------------------------------------
-- 🔴 NEDEN HÂLÂ KIRMIZI GÖRÜNÜYOR
-- ------------------------------------------------------------
-- 167 vaka tablosunu ÜRETİYOR (`delete from rule_test_cases` +
-- yeniden doldur). 177 ise o tabloyu resmî tabloya göre DÜZELTİYOR.
-- İkisi ayrı dosyada olduğu için sıra kritik: 177'den sonra 167
-- tekrar koşarsa (ya da dosyalar farklı sırada çalışırsa) bütün
-- düzeltmeler silinir ve matris yine kırmızı yanar.
--
-- Bu kırılganlığı ben yarattım: düzeltmeyi üretecin İÇİNE değil
-- SONRASINA yazdım. Kalıcı çözüm tek kaynak: üreteç zaten DOĞRU
-- beklentiyi üretsin. Artık `rebuild_rule_test_cases()` tek
-- fonksiyon; hangi sırayla kaç kez koşarsa koşsun sonuç aynı.
--
-- Ayrıca rapor artık akış testinde HANGİ senaryonun düştüğünü
-- yazıyor. "1 başarısız" demek teşhis değildir; hangi kapı olduğu
-- yazmazsa her seferinde ayrı sorgu gerekir.
-- ============================================================

create or replace function public.rebuild_rule_test_cases()
returns int language plpgsql security definer set search_path = public as $$
declare
  v_scopes text[] := array['domestic','international','abroad'];
  v_carr   text[] := array['TK','VF','SA','OTHER','UNKNOWN'];
  s text; c text; t text; n int := 0;
  v_lvl text; v_g int; v_f boolean; v_p boolean; v_src text;
begin
  delete from rule_test_cases;

  -- ============ TK MILES&SMILES ============
  -- Kaynak: THY Tablo-1 (iç hat), Tablo-2 (dış hat), Tablo-5 (yurt dışı).
  --   TK taşıyıcı → ELPL/Elite/M&S EC: "Aile veya bir misafir"
  --                 SAG/PLM/CORP     : "Bir misafir"
  --                 CLPL / M&S U.S. Kredi Kartı : "Yok"
  --   Star Alliance taşıyıcı → hepsi "Bir misafir" (aile YOK)
  --   Yurt dışı anlaşmalı (Tablo-5) → aile YOK, tek misafir
  --   AJet uçuşu (VF) → hak AJET_MS tablosundan gelir, burada iddia yok
  foreach s in array v_scopes loop
  foreach c in array v_carr loop
    foreach t in array array['ELPL','ELITE','CLPL','CLASSIC','CORP','MS_EC','SAG','PLM','MS_US_CC'] loop
      v_lvl := 'defined'; v_g := null; v_f := null; v_p := null;
      v_src := 'THY Tablo-1/2/5';

      if t in ('CLPL','CLASSIC') then
        v_lvl := 'exact'; v_g := 0; v_f := false;
        v_src := 'Tablo-1/2: "Yok" — hiçbir kapsamda misafir hakkı yok';

      elsif t = 'MS_US_CC' then
        v_lvl := 'exact'; v_g := 0; v_f := false;
        v_src := 'Tablo-1/2: M&S U.S. Kredi Kartı → "Yok"';

      elsif c = 'VF' then
        v_lvl := 'defined';
        v_src := 'AJet seferinde hak AJET_MS tablosundan gelir';

      elsif c = 'UNKNOWN' then
        v_lvl := 'defined';
        v_src := '163 ilkesi: taşıyıcı bilinmiyorsa en kısıtlayıcı kural';

      elsif t in ('ELPL','ELITE','MS_EC') then
        if s = 'abroad' then
          v_lvl := 'exact'; v_g := 1; v_f := false;
          v_src := 'Tablo-5: yurt dışı anlaşmalı salonda aile hakkı yok';
        elsif s = 'international' and c in ('SA','OTHER') and t = 'MS_EC' then
          -- Tablo-2 "aile yok" der; Tablo-4 IST M&S bölümü için istisna
          -- tanır. İkisi çelişmez, biri diğerinin istisnasıdır — kesin
          -- cevap SALON düzeyinde verilir (B testi).
          v_lvl := 'defined';
          v_src := 'Tablo-2 kapsam kuralı + Tablo-4 M&S bölümü istisnası';
        elsif c = 'TK' then
          v_lvl := 'exact'; v_g := 1; v_f := true;
          v_src := 'Tablo-1/2 (TK): "Aile veya bir misafir"';
        else
          v_lvl := 'exact'; v_g := 1; v_f := false;
          v_src := 'Tablo-2 (Star Alliance): "Bir misafir"';
        end if;

      elsif t in ('SAG','PLM','CORP') then
        if s = 'abroad' then v_lvl := 'defined';
        else
          v_lvl := 'exact'; v_g := 1; v_f := false;
          v_src := 'Tablo-1/2: "Bir misafir"';
        end if;
      end if;

      insert into rule_test_cases
        (program_code, card_tier, venue_scope, carrier_class, level,
         exp_guests, exp_family, kaynak, needs_review)
      values ('TK_MS', t, s, c, v_lvl, v_g, v_f, v_src, false)
      on conflict do nothing;
      n := n + 1;
    end loop;
  end loop;
  end loop;

  -- ============ AJET MILES&SMILES ============
  foreach s in array v_scopes loop
  foreach c in array v_carr loop
    foreach t in array array['ELPL','ELITE','CLPL','CLASSIC','MS_EC'] loop
      if t in ('CLPL','CLASSIC') then
        insert into rule_test_cases
          (program_code, card_tier, venue_scope, carrier_class, level,
           exp_guests, exp_family, kaynak, needs_review)
        values ('AJET_MS', t, s, c, 'exact', 0, false, 'AJet kart matrisi', false)
        on conflict do nothing;
      else
        insert into rule_test_cases
          (program_code, card_tier, venue_scope, carrier_class, level, kaynak, needs_review)
        values ('AJET_MS', t, s, c, 'defined', 'AJet kart matrisi', false)
        on conflict do nothing;
      end if;
      n := n + 1;
    end loop;
  end loop;
  end loop;

  -- ============ PRIORITY PASS · DRAGONPASS ============
  -- Hiçbir planda misafir ücretsiz dahil değil; kapıda ücretli girer.
  foreach s in array v_scopes loop
  foreach c in array v_carr loop
    foreach t in array array['PP_STANDARD','PP_STANDARD_PLUS','PP_PRESTIGE'] loop
      insert into rule_test_cases
        (program_code, card_tier, venue_scope, carrier_class, level,
         exp_guests, exp_family, exp_paid, kaynak, needs_review)
      values ('PRIORITY_PASS', t, s, c, 'exact', 0, false, true,
              'PP plan sayfası 2026: misafir ücretli', false)
      on conflict do nothing;
      n := n + 1;
    end loop;
    foreach t in array array['DP_CLASSIC','DP_PREFERENTIAL'] loop
      insert into rule_test_cases
        (program_code, card_tier, venue_scope, carrier_class, level,
         exp_guests, exp_family, exp_paid, kaynak, needs_review)
      values ('DRAGONPASS', t, s, c, 'exact', 0, false, true,
              'DP şartları: ek üye veya misafir ücretli, aynı uçuş şartı', false)
      on conflict do nothing;
      n := n + 1;
    end loop;
  end loop;
  end loop;

  -- ============ BUSINESS BİLETİ ============
  foreach s in array v_scopes loop
  foreach c in array v_carr loop
    insert into rule_test_cases
      (program_code, card_tier, venue_scope, carrier_class, level,
       exp_guests, exp_family, kaynak, needs_review)
    values ('BUSINESS_TICKET', null, s, c, 'exact', 0, false,
            'Tablo-4: Business bölümünde misafir/aile hakkı yok', false)
    on conflict do nothing;
    n := n + 1;
  end loop;
  end loop;

  -- ============ OPERATÖR SALONLARI ============
  foreach s in array v_scopes loop
  foreach c in array v_carr loop
    foreach t in array array['PRIMECLASS','IGA_LOUNGE','PLAZA_PREMIUM','PGS_PAID'] loop
      insert into rule_test_cases
        (program_code, card_tier, venue_scope, carrier_class, level,
         exp_guests, exp_family, exp_paid, kaynak, needs_review)
      values (t, null, s, c, 'exact', 0, false, true,
              'Operatör kapı tarifesi: misafir de aynı tarifeden girer', false)
      on conflict do nothing;
      n := n + 1;
    end loop;
  end loop;
  end loop;

  -- ============ BANKA / KART AĞLARI ============
  foreach s in array v_scopes loop
  foreach c in array v_carr loop
    foreach t in array array['AMEX_GLOBAL','BANK_CARD','LOUNGEKEY','DREAMFOLKS','EVERYLOUNGE','ONPASS','ST_PASS','STAR_GOLD'] loop
      insert into rule_test_cases
        (program_code, card_tier, venue_scope, carrier_class, level, kaynak, needs_review)
      values (t, null, s, c, 'defined',
              'Koşullar kartı verene göre değişir; yalnız kural çözülmeli', false)
      on conflict do nothing;
      n := n + 1;
    end loop;
  end loop;
  end loop;

  return (select count(*)::int from rule_test_cases);
end $$;
grant execute on function public.rebuild_rule_test_cases() to authenticated;

select public.rebuild_rule_test_cases() as uretilen_vaka;

-- ============================================================
-- RAPOR: AKIŞ TESTİNDE HANGİ SENARYO DÜŞTÜ, ADIYLA YAZILIR
-- "1 başarısız" teşhis değildir.
-- ============================================================
-- sqlcheck: allow-replace rule_full_report  (üstte drop var)
drop function if exists public.rule_full_report();
create or replace function public.rule_full_report()
returns table (bolum text, kalem text, toplam int, gecen int, kalan int, durum text)
language plpgsql security definer set search_path = public as $$
declare r record; v_top int; v_kalan int; v_ad text;
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
  select string_agg(senaryo || ' → ' || gercek, ' | ') into v_ad
    from _akis where sonuc like '✗%';
  bolum := 'E · Akış kapıları';
  kalem := case when v_kalan = 0 then 'flow_gate_test'
                else 'flow_gate_test — ' || left(coalesce(v_ad,''), 90) end;
  toplam := v_top; kalan := v_kalan; gecen := v_top - v_kalan;
  durum := case when kalan = 0 then '✓' else '✗' end; return next;
end $$;
grant execute on function public.rule_full_report() to authenticated;

do $$
declare n int;
begin
  select count(*) into n from public.rule_full_report() where durum not like '✓%';
  raise notice '178: raporda % kırmızı', n;
end $$;

select '178 OK - beklentiler tek kaynakta, rapor teshis veriyor' as sonuc;
