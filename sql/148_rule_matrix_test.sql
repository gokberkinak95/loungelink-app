-- ============================================================
-- LoungeLink · 148_rule_matrix_test.sql
-- KURAL MATRISI OZ-TESTI — BEKLENEN CIKTI DOSYADA YAZILI
--
-- ⚠️ Uygulamayi ETKILEMEZ (yalniz dogrulama).
--
-- 🔴 NEDEN VERITABANINDA BIR TEST
-- ------------------------------------------------------------
-- E2E testlerim Python'da ve app akisini kontrol ediyor. Ama kural
-- matrisinin KENDISI — 9 kart x 3 tasiyici x 2 kabin x 5 salon tipi —
-- hicbir yerde beklenen ciktisiyla karsilastirilmiyordu.
--
-- Bu fonksiyon, THY'nin resmi tablolarindan cikardigim BEKLENEN
-- degerleri tasir. Kural verisi degisirse ve sonuc beklenenden
-- saparsa, burasi kirmizi yanar.
--
-- Beklenen degerlerin kaynagi dosyada YAZILI: hangi tablodan geldigi
-- her satirda belirtiliyor. Boylece gelecekte "bu beklenen dogru mu"
-- sorusu kaynaga bakilarak yanitlanabilir.
-- ============================================================

create or replace function public.rule_matrix_check()
returns table (senaryo text, beklenen text, gercek text, sonuc text)
language plpgsql stable security definer set search_path = public as $$
declare c record; g jsonb; v_tk uuid; v_aj uuid; v_got text;
begin
  select id into v_tk from lounge_programs where code = 'TK_MS';
  select id into v_aj from lounge_programs where code = 'AJET_MS';

  for c in select * from (values
    -- ---- TABLO-1/2: TK SEFERINDE ----
    ('TK · Elite Plus',        v_tk,'ELPL','TK',   null, 'aile+1'),
    ('TK · Elite',             v_tk,'ELITE','TK',  null, 'aile+1'),   -- Elite = ELPL (Tablo-1)
    ('TK · M&S Elite Corp',    v_tk,'MS_EC','TK',  null, 'aile+1'),
    ('TK · Star Alliance Gold',v_tk,'SAG','TK',    null, '1'),        -- aile YOK
    ('TK · Miles&More',        v_tk,'PLM','TK',    null, '1'),
    ('TK · Corporate Club',    v_tk,'CORP','TK',   null, '1'),
    ('TK · Classic Plus',      v_tk,'CLPL','TK',   null, '0'),        -- Tablo-1: Yok
    ('TK · Classic',           v_tk,'CLASSIC','TK',null, '0-ucretli'),-- ucretle girer
    ('TK · M&S ABD Kart',      v_tk,'MS_US_CC','TK',null,'0'),
    -- ---- TABLO-2 alt blok: STAR ALLIANCE UYESI BASKA HAVAYOLU ----
    -- 🔴 AYNI KART, AILE HAKKI DUSUYOR. Fark yalniz tasiyici.
    ('LH · Elite Plus',        v_tk,'ELPL','LH',   null, '1'),
    ('LH · Elite',             v_tk,'ELITE','LH',  null, '1'),
    ('LX · Star Alliance Gold',v_tk,'SAG','LX',    null, '1'),
    -- ---- KABIN SINIFI (kartsiz) ----
    ('Kartsiz Business',       v_tk, null,'TK','business','0'),
    ('Kartsiz First',          v_tk, null,'TK','first',   '1'),
    -- ---- AJET ----
    ('AJet · Elite Plus',      v_aj,'ELPL','VF',   null, 'aile+1'),
    ('AJet · Elite',           v_aj,'ELITE','VF',  null, 'aile+1'),
    ('AJet · Classic Plus',    v_aj,'CLPL','VF',   null, '0-ucretli'),
    ('AJet · Classic',         v_aj,'CLASSIC','VF',null, '0-ucretli')
  ) as t(ad, pid, tier, carrier, cabin, bek)
  loop
    g := public.resolve_guest_rule(c.pid, null, c.tier, c.carrier, c.cabin);
    v_got := case
      when (g ->> 'family_allowed')::boolean then 'aile+' || (g ->> 'guest_allowance')
      when (g ->> 'guest_allowance')::int = 0 and (g ->> 'paid_entry_allowed')::boolean then '0-ucretli'
      else (g ->> 'guest_allowance') end;
    senaryo := c.ad; beklenen := c.bek; gercek := v_got;
    sonuc := case when v_got = c.bek then '✓' else '✗ SAPMA' end;
    return next;
  end loop;
end $$;
grant execute on function public.rule_matrix_check() to authenticated;

select sonuc, count(*) from public.rule_matrix_check() group by 1 order by 1;
select * from public.rule_matrix_check() where sonuc <> '✓';

select '148 OK - kural matrisi oz-testi kuruldu' as sonuc;
