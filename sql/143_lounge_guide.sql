-- ============================================================
-- LoungeLink · 143_lounge_guide.sql
-- SALON REHBERI — TEK KULLANICIYLA DEGERLI OLAN URUN
--
-- ⚠️ Uygulamayi ETKILER (yeni giris noktasi).
--
-- ------------------------------------------------------------
-- 🔴 URUNUN EN BUYUK YAPISAL SORUNU
-- ------------------------------------------------------------
-- Olctugumde su cikti: `card_advice_for_lounge` app'te 1 kez,
-- `venue_amenities` 0 kez, `card_advice_for_airport` 0 kez cagriliyor.
--
-- Yani BASKA KULLANICI GEREKTIRMEYEN her sey, BASKA KULLANICI
-- GEREKTIREN akislarin arkasinda kilitli. Uygulamayi ilk acan kisi
-- bos bir kesif listesi goruyor ve gidiyor.
--
-- Bu, iki tarafli pazarin klasik olumu. Cozumu de klasik: TEK TARAFLI
-- BIR ARACLA BASLA. Elimizde Turkiye'de kimsenin veremedigi bir cevap
-- var: "Elite Plus kartimla IST dis hatta misafir goturebilir miyim?"
--
-- Bu fonksiyon o cevabi HIC ILAN OLMADAN veriyor. Kullanici degerini
-- ilk 30 saniyede goruyor; eslesme SONRA geliyor.
-- ============================================================

create or replace function public.guide_airports()
returns table (code text, city text, name text, lounges int, has_rules boolean)
language sql stable security definer set search_path = public as $$
  select a.code::text, a.city, a.name,
         count(distinct v.id)::int,
         -- 🔴 "Kural var mi" ayri bir soru: salon listelemek kolay,
         -- kuralini bilmek zor. Kullaniciya hangi havalimaninda GERCEK
         -- cevap verebildigimizi durustce gosteriyoruz.
         bool_or(exists (select 1 from lounge_venue_acceptance x
                          where x.venue_id = v.id and x.active and not x.is_placeholder))
    from airports a
    left join lounge_venues v on v.airport_code = a.code and v.active and v.venue_kind = 'lounge'
   group by a.code, a.city, a.name
  having count(distinct v.id) > 0
   order by count(distinct v.id) desc, a.code;
$$;
grant execute on function public.guide_airports() to anon, authenticated;

-- ---- HAVALIMANINDAKI SALONLAR + O KART ICIN CEVAP ----
-- 🔴 GIRIS GEREKTIRMIYOR (anon). Degeri gormeden kaydolmayi istemek,
-- kullanicidan once guven istemektir. Once ise yara, sonra sor.
create or replace function public.guide_lounges(
  p_airport text, p_program_code text default null, p_tier text default null
) returns table (
  venue_id uuid, lounge_name text, scope text, terminal text,
  amenities jsonb, verdict text, headline text, detail text,
  guest_count int, confidence text, source_url text
) language plpgsql stable security definer set search_path = public as $$
declare r record; a lounge_venue_acceptance%rowtype; g lounge_guest_rules%rowtype; v_pid uuid;
begin
  v_pid := case when p_program_code is null then null
                else (select id from lounge_programs where code = p_program_code) end;

  for r in
    select v.* from lounge_venues v
     where v.airport_code = upper(p_airport) and v.active and v.venue_kind = 'lounge'
     order by (v.section is null) desc, v.name
  loop
    venue_id := r.id; lounge_name := r.name;
    scope := coalesce(r.scope,''); terminal := coalesce(r.terminal,'');
    amenities := coalesce(r.amenities, '{}'::jsonb);

    select * into a from lounge_venue_acceptance x
     where x.venue_id = r.id and x.active
       and (v_pid is null or x.program_id = v_pid)
     order by coalesce(x.program_id = v_pid, false) desc, x.is_placeholder, x.checked_at desc nulls last
     limit 1;

    if v_pid is null then
      -- Kart secilmemis: yalniz "buraya kimlerle girilir" bilgisi
      verdict := 'info';
      headline := null;
      detail := (select string_agg(distinct p.name, ' · ')
                   from lounge_venue_acceptance x join lounge_programs p on p.id = x.program_id
                  where x.venue_id = r.id and x.active);
      guest_count := null; confidence := null; source_url := null;
      return next; continue;
    end if;

    if not found then
      verdict := 'no';
      headline := 'Bu kartla girilmiyor';
      detail := 'Bu salon seçtiğin programı kabul etmiyor.';
      guest_count := 0; confidence := 'verified'; source_url := null;
      return next; continue;
    end if;

    -- Kart tipi kurali varsa ONU kullan: "Elite Plus" ile "Classic Plus"
    -- ayni programda BAMBASKA sonuc verir ve fark tam da burada.
    select * into g from lounge_guest_rules x
     where x.program_id = a.program_id
       and (x.venue_id = r.id or x.venue_id is null)
       and (p_tier is null or x.card_tier = p_tier or x.card_tier is null)
       and (x.effective_to is null or x.effective_to >= current_date)
     order by coalesce(x.venue_id = r.id, false) desc, coalesce(x.card_tier = p_tier, false) desc nulls last
     limit 1;

    guest_count := coalesce(g.guest_allowance, a.guest_included_count, 0);
    confidence := case when a.is_placeholder then 'unknown'
                       when a.checked_at is not null then 'verified' else 'assumed' end;
    source_url := a.source_url;

    if a.guest_policy = 'not_allowed' or guest_count = 0 then
      verdict := 'self_only';
      headline := 'Girebilirsin, misafir götüremezsin';
      detail := coalesce(g.notes, a.conditions, 'Bu hakla yalnız kendin girebilirsin.');
    elsif a.guest_policy = 'paid' then
      verdict := 'paid';
      headline := 'Misafir ücretli';
      detail := case a.fee_payer when 'member_card' then 'Ücret senin kartından çekilir.'
                                 else 'Misafir kapıda öder.' end;
    else
      verdict := 'yes';
      headline := guest_count::text || ' misafir götürebilirsin';
      detail := coalesce(g.notes, a.conditions, '');
    end if;
    detail := public.clip_text(detail, 130);
    return next;
  end loop;
end $$;
grant execute on function public.guide_lounges(text, text, text) to anon, authenticated;

-- ---- KART/PROGRAM SECIM LISTESI ----
create or replace function public.guide_programs()
returns table (code text, name text, tiers jsonb, popular boolean)
language sql stable security definer set search_path = public as $$
  select p.code, p.name,
         coalesce((select jsonb_agg(jsonb_build_object(
                     'code', r.card_tier,
                     'label', public.card_tier_label(r.card_tier)) order by r.card_tier)
                     from (select distinct card_tier from lounge_guest_rules
                            where program_id = p.id and card_tier is not null) r), '[]'::jsonb),
         -- Turkiye'de en cok kullanilanlar once: liste sirasinin kendisi
         -- bir tavsiyedir, alfabetik siralama en olasi secenegi gomer.
         p.code in ('TK_MS','AJET_MS','PGS_PAID','PRIORITY_PASS','LOUNGEKEY','DRAGONPASS','STAR_GOLD')
    from lounge_programs p
   where p.active and p.code <> 'BANK_CARD'
   order by (p.code in ('TK_MS','AJET_MS','PGS_PAID','PRIORITY_PASS','LOUNGEKEY','DRAGONPASS','STAR_GOLD')) desc,
            p.name;
$$;
grant execute on function public.guide_programs() to anon, authenticated;

-- ---- REHBERDEN ESLESMEYE KOPRU ----
-- 🔴 Rehber tek basina degerli ama URUN degil; urun eslesme.
-- Kullanici "misafir goturemezsin" cevabini aldigi ANDA ona cikis
-- yolunu gostermeliyiz: "ama bugun seni iceri alabilecek N kisi var".
-- Bu cumle, rehberi bir SONUC olmaktan cikarip bir BASLANGIC yapar.
create or replace function public.guide_hosts_today(p_airport text, p_date date default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'airport', upper(p_airport),
    'date', coalesce(p_date, current_date),
    'count', (select count(*) from availabilities a
               where a.airport_code = upper(p_airport)
                 and a.avail_date >= coalesce(p_date, current_date)
                 and a.avail_date <= coalesce(p_date, current_date) + 2
                 and coalesce(a.filled,0) < coalesce(a.slots,1)),
    'next_date', (select min(a.avail_date) from availabilities a
                   where a.airport_code = upper(p_airport)
                     and a.avail_date >= current_date
                     and coalesce(a.filled,0) < coalesce(a.slots,1)));
$$;
grant execute on function public.guide_hosts_today(text, date) to anon, authenticated;

select count(*) as havalimani from public.guide_airports();
select '143 OK - salon rehberi hazir (giris gerektirmez)' as sonuc;
