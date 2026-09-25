-- ============================================================
-- LoungeLink · 144_guide_fixes.sql
-- REHBERDE IKI HATA — IKISI DE URUNUN ANA VAADINI KIRIYORDU
--
-- ⚠️ Uygulamayi ETKILER (rehber sonuclari).
--
-- ------------------------------------------------------------
-- 🔴 HATA 1: KART TIPI, SALON OZGULLUGUNE YENILIYORDU
-- ------------------------------------------------------------
-- Rehberi test ettigimde Elite Plus'a "misafir goturemezsin" dedi.
-- Yanlis — Elite Plus'in 1 misafir hakki var ve bu, urunun EN COK
-- sorulan sorusunun cevabi.
--
-- Sebep siralamamdaydi: once `venue_id = r.id`, sonra `card_tier`.
-- Yani SALONA OZEL ama kart tipi bos bir kural, PROGRAM duzeyinde
-- ama Elite Plus'a ozel bir kurali yeniyordu.
--
-- Oysa THY'de en ayirt edici degisken KART TIPIDIR. Elite Plus ile
-- Classic Plus ayni salonda BAMBASKA sonuc verir; salon farki
-- ikincildir. Siralamayi tersine cevirdim: once TIP, sonra SALON.
--
-- ------------------------------------------------------------
-- 🔴 HATA 2: AYNI SALON HEM ANA KAYIT HEM BOLUM OLARAK GORUNUYOR
-- ------------------------------------------------------------
-- IST'te 10 satir cikti ama gercekte 6 salon var:
--   "TK Lounge — Dis Hat (Miles&Smiles)"  ← ana kayit (086 kalintisi)
--   "TK Lounge — Dis Hat (Miles&Smiles)"  ← bolum kaydi
-- Ayni ad, iki satir. Ustelik "TK Lounge — İç Hat" iki kez cikiyor
-- (business ve miles_smiles bolumleri) — farkli odalar ama AYNI AD,
-- yani kullanici hangisi oldugunu ayirt edemiyor.
--
-- Iki kural:
--   1. Bolumu olan bir salonun ANA kaydi listede gorunmez (bolumler
--      daha spesifik; ikisini birden gostermek tekrardir).
--   2. Bolum adi ADINDA gorunur: "— Business" / "— Miles&Smiles".
--      Ayirt edilemeyen iki secenek, secenek degildir.
-- ============================================================

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
    select v.*,
           -- Bolum adi ADA yedirilir; "İç Hat" iki kez gorunmesin.
           case when v.section = 'business' and v.name !~* 'business'
                  then v.name || ' — Business'
                when v.section = 'miles_smiles' and v.name !~* 'miles'
                  then v.name || ' — Miles&Smiles'
                else v.name end as disp_name
      from lounge_venues v
     where v.airport_code = upper(p_airport) and v.active and v.venue_kind = 'lounge'
       -- 🔴 Bolumu olan salonun ANA kaydini gizle: bolumler daha
       -- spesifik ve ikisini birden gostermek tekrardir.
       and not exists (select 1 from lounge_venues c
                        where c.section_of = v.id and c.active)
     order by (v.section is null) desc, v.name
  loop
    venue_id := r.id; lounge_name := r.disp_name;
    scope := coalesce(r.scope,''); terminal := coalesce(r.terminal,'');
    amenities := coalesce(r.amenities, '{}'::jsonb);

    select * into a from lounge_venue_acceptance x
     where x.venue_id = r.id and x.active
       and (v_pid is null or x.program_id = v_pid)
     order by coalesce(x.program_id = v_pid, false) desc, x.is_placeholder, x.checked_at desc nulls last
     limit 1;

    if v_pid is null then
      verdict := 'info'; headline := null;
      detail := (select string_agg(distinct p.name, ' · ')
                   from lounge_venue_acceptance x join lounge_programs p on p.id = x.program_id
                  where x.venue_id = r.id and x.active);
      guest_count := null; confidence := null; source_url := null;
      return next; continue;
    end if;

    if not found then
      verdict := 'no'; headline := 'Bu kartla girilmiyor';
      detail := 'Bu salon seçtiğin programı kabul etmiyor.';
      guest_count := 0; confidence := 'verified'; source_url := null;
      return next; continue;
    end if;

    -- 🔴 ONCE KART TIPI, SONRA SALON. THY'de en ayirt edici degisken
    -- kart tipidir; salon farki ikincildir.
    select * into g from lounge_guest_rules x
     where x.program_id = a.program_id
       and (x.venue_id = r.id or x.venue_id is null)
       and (p_tier is null or x.card_tier = p_tier or x.card_tier is null)
       and (x.effective_to is null or x.effective_to >= current_date)
     -- 🔴 NULL, DESC SIRALAMADA true'DAN ONCE GELIR — PostgreSQL'de
     -- varsayilan `NULLS FIRST`tir. `x.card_tier` NULL oldugunda
     -- `x.card_tier = p_tier` ifadesi false DEGIL **NULL** doner ve
     -- o satir en basa ciplar.
     --
     -- Sonuc: kart tipi belirtilmemis, misafir hakki 0 olan bir salon
     -- kurali, Elite Plus'a ozel 1 misafirlik kurali YENIYORDU. Yani
     -- urunun en cok sorulan sorusuna yanlis cevap veriyorduk.
     --
     -- coalesce ile ucuncu degeri kapatiyoruz: NULL artik false sayilir.
     order by coalesce(p_tier is not null and x.card_tier = p_tier, false) desc,
              coalesce(x.venue_id = r.id, false) desc,
              (x.card_tier is not null) desc
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
      verdict := 'paid'; headline := 'Misafir ücretli';
      detail := case a.fee_payer when 'member_card' then 'Ücret senin kartından çekilir.'
                                 else 'Misafir kapıda öder.' end;
    else
      verdict := 'yes';
      headline := guest_count::text || ' misafir götürebilirsin'
               || case when coalesce(g.family_allowed,false) then ' (veya ailen)' else '' end;
      detail := coalesce(g.notes, a.conditions, '');
    end if;
    detail := public.clip_text(detail, 130);
    return next;
  end loop;
end $$;
grant execute on function public.guide_lounges(text, text, text) to anon, authenticated;

select 'ELPL' as tip, lounge_name, verdict, headline
  from public.guide_lounges('IST','TK_MS','ELPL') where verdict <> 'no'
union all
select 'CLPL', lounge_name, verdict, headline
  from public.guide_lounges('IST','TK_MS','CLPL') where verdict <> 'no';

select '144 OK - kart tipi oncelikli, bolum tekrari giderildi' as sonuc;
