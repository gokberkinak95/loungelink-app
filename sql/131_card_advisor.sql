-- ============================================================
-- LoungeLink · 131_card_advisor.sql
-- ESLESME YOKSA: "KENDI HAKKINI NASIL ALIRSIN?"
--
-- ⚠️ Uygulamayi ETKILER (yeni RPC).
--
-- ------------------------------------------------------------
-- URUN MANTIGI
-- ------------------------------------------------------------
-- Rakip, eslesme bulunamayinca "60 saniyelik testi coz, hangi kart
-- sana erisim verir ogren" diyor. Yani BASARISIZLIK anini bir
-- FAYDA anina ceviriyor. Bizim bos durumumuz dogru ama bombos:
-- "basvurabilecegin baska ilan yok."
--
-- Ve isin ilginci: bu soruyu ONLARDAN COK DAHA IYI cevaplayabiliriz.
-- Onlarda bir test var; bizde kart katalogu, kart kademesi matrisi,
-- misafir havuzu modelleri ve dogrulanmis banka verisi var.
--
-- 🔴 UC ILKE:
--   1. YALNIZ O SALONA yarayan karti oner. "Priority Pass al" demek
--      kolay ama o salon PP kabul etmiyorsa zarar verir.
--   2. DOGRULANMISI ONE AL, dogrulanmamisi "dogrulanmadi" diye ver.
--      Kart onerisi bir SATIS degil, bir BILGI; yanlis oneri
--      kullanicinin parasini yakar.
--   3. MISAFIR HAKKI OLANI ONCELIKLENDIR. Kullanici buraya misafir
--      olmak icin geldi; kendi girisini cozen ama misafir goturmeyen
--      bir kart onun sorununu yarim cozer.
-- ============================================================

create or replace function public.card_advice_for_lounge(p_lounge_id uuid)
returns table (
  issuer text, card text, program text, segment text,
  quota text, guest_note text, confidence text, source_url text, rank int
) language sql stable security definer set search_path = public as $$
  with venue as (
    select v.id from lounges l join lounge_venues v on v.id = l.venue_id
     where l.id = p_lounge_id
  ),
  -- Bu salonda GERCEKTEN kabul edilen programlar
  ok_programs as (
    select distinct a.program_id
      from lounge_venue_acceptance a, venue
     where a.venue_id = venue.id and a.active and a.accepted
  )
  select i.name, cp.name, p.name, cp.segment,
         case
           when cp.quota_total is null then 'Adet belirtilmemiş'
           else cp.quota_total::text || ' kullanım / ' ||
                case cp.quota_period when 'year' then 'yıl' when 'month' then 'ay'
                                     when 'visit' then 'ziyaret' else 'dönem' end
         end,
         case
           when cp.guest_consumes_quota
             then '⚠ Misafirin AYNI HAKTAN düşer — eşinle gidersen hakkın yarıya iner.'
           when cp.guest_quota_total is not null
             then cp.guest_quota_total::text || ' misafir hakkı (ayrı havuzdan)'
           else 'Misafir hakkı belirtilmemiş — bankandan teyit et.'
         end,
         coalesce(cp.confidence, 'unknown'),
         cp.source_url,
         -- 🔴 SIRALAMA BIR TAVSIYEDIR. Once DOGRULANMIS, sonra MISAFIR
         -- HAKKI OLAN, sonra kotasi buyuk olan. Kullanici ustteki
         -- secenegi "onerilen" sanir; en zayif veriyi basa koymak
         -- ona zarar verir.
         (case when cp.confidence = 'verified' and cp.checked_at is not null then 0 else 10 end
          + case when cp.guest_quota_total is not null and not cp.guest_consumes_quota then 0
                 when cp.guest_consumes_quota then 3 else 5 end
          + case when coalesce(cp.quota_total, 0) >= 10 then 0 else 1 end)::int
    from lounge_card_products cp
    join lounge_issuers i on i.id = cp.issuer_id and i.active
    join lounge_programs p on p.id = cp.program_id
    join ok_programs op on op.program_id = cp.program_id
   where cp.active
     and (cp.valid_to is null or cp.valid_to >= current_date)
   -- 🔴 `rank` bir SIRALAMA FONKSIYONU adi; PostgreSQL onu ORDER BY'da
   -- kolon takma adi olarak cozmez. Ifadeyi tekrar yaziyoruz.
   order by (case when cp.confidence = 'verified' and cp.checked_at is not null then 0 else 10 end
             + case when cp.guest_quota_total is not null and not cp.guest_consumes_quota then 0
                    when cp.guest_consumes_quota then 3 else 5 end
             + case when coalesce(cp.quota_total, 0) >= 10 then 0 else 1 end),
            i.name
   limit 6;
$$;
grant execute on function public.card_advice_for_lounge(uuid) to authenticated;

-- Havalimani genelinde: hic ilan yoksa hangi kart bu havalimaninda ise yarar
create or replace function public.card_advice_for_airport(p_airport text)
returns table (issuer text, card text, program text, lounges int,
               confidence text, source_url text)
language sql stable security definer set search_path = public as $$
  select i.name, cp.name, p.name,
         count(distinct a.venue_id)::int,
         coalesce(cp.confidence,'unknown'), cp.source_url
    from lounge_card_products cp
    join lounge_issuers i on i.id = cp.issuer_id and i.active
    join lounge_programs p on p.id = cp.program_id
    join lounge_venue_acceptance a on a.program_id = cp.program_id and a.active and a.accepted
    join lounge_venues v on v.id = a.venue_id and v.active
   where cp.active and v.airport_code = upper(p_airport)
   group by i.name, cp.name, p.name, cp.confidence, cp.source_url
   -- Kac SALONA girdigi belirleyici: bir kart o havalimaninda tek
   -- salona giriyorsa "burada ise yarar" demek yaniltici olur.
   order by count(distinct a.venue_id) desc,
            coalesce(cp.confidence = 'verified', false) desc, i.name
   limit 5;
$$;
grant execute on function public.card_advice_for_airport(text) to authenticated;

insert into beta_settings (key, value) values
 ('advice_intro', to_jsonb(
   'Bu havalimanında kendi hakkınla girmek istersen, aşağıdaki kartlar bu '
|| 'salonlarda geçerli. LoungeLink bu kartları satmaz ve komisyon almaz — '
|| 'yalnızca elimizdeki doğrulanmış veriyi gösteriyoruz. Koşullar değişebilir; '
|| 'başvurmadan önce bankandan teyit et.'::text))
on conflict (key) do update set value = excluded.value;

select '131 OK - kart danismani hazir' as sonuc;
