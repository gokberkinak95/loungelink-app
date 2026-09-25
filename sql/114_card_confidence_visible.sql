-- ============================================================
-- LoungeLink · 114_card_confidence_visible.sql
-- KART SECIMINDE GUVEN DERECESI GORUNMUYORDU
--
-- ⚠️ Uygulamayi ETKILER (kart listesi + karar metni).
--
-- ------------------------------------------------------------
-- 🔴 SORUN
-- ------------------------------------------------------------
-- Gokberk sordu: "kredi kartinda genel uyari gosteriyoruz, kacirdigim
-- bir sey mi var?" — Genel uyari yolu DOGRU calisiyor. Ama IKINCI bir
-- katman var ve orada sorun vardi:
--
--   Katman A (varsayilan): host "Kredi Karti Avantaji" secer
--     -> genel uyari cikar. Hicbir sey iddia etmeyiz. ✓ DOGRU
--
--   Katman B (istege bagli): host HANGI KART oldugunu da secebilir
--     -> o kartin kotasi, karekod sarti, misafir kurali uygulanir.
--
-- Katman B'nin verisi cogunlukla DOGRULANMAMIS (confidence='unknown'
-- ya da 'secondary'). Ama `card_product_options` bu bilgiyi HIC
-- DONDURMUYORDU: host listede "TEB Infinite" goruyor, seciyor, ve biz
-- misafire "ayda 4 misafir hakki var" gibi KESIN bir cumle kuruyoruz —
-- oysa o rakami hicbir zaman dogrulamadik.
--
-- Bu, genel uyaridan DAHA KOTU: genel uyari "bilmiyoruz" der ve
-- kullanici tedbirli olur. Dogrulanmamis bir rakam ise "biliyoruz"
-- der ve kullanici tedbiri BIRAKIR.
--
-- COZUM: guven derecesi listede de kararda da gorunsun.
-- ============================================================

drop function if exists public.card_product_options();

create or replace function public.card_product_options()
returns table (id uuid, issuer text, name text, label text,
               program_code text, confidence text, verified boolean,
               note text)
language sql stable security definer set search_path = public as $$
  select cp.id, i.name, cp.name,
         i.name || ' · ' || cp.name ||
           case when cp.segment is not null then ' (' || cp.segment || ')' else '' end,
         p.code,
         coalesce(cp.confidence, 'unknown'),
         (cp.confidence = 'verified' and cp.checked_at is not null),
         case
           when cp.confidence = 'verified' and cp.checked_at is not null
             then 'Koşulları resmî kaynaktan doğruladık (' || cp.checked_at::text || ').'
           when cp.confidence = 'secondary'
             then 'Koşulları ikincil kaynaktan aldık — banka kampanyaları değişebiliyor. '
               || 'Kendi kartının güncel hakkını bankandan teyit et.'
           else 'Bu kartın koşullarını doğrulayamadık. Seçebilirsin ama misafirine '
             || 'kesin bir söz vermeden önce bankandan teyit et.'
         end
    from lounge_card_products cp
    join lounge_issuers i on i.id = cp.issuer_id and i.active
    left join lounge_programs p on p.id = cp.program_id
   where cp.active
     and (cp.valid_from is null or cp.valid_from <= current_date)
     and (cp.valid_to   is null or cp.valid_to   >= current_date)
   -- 🔴 DOGRULANMISLAR USTTE. Liste sirasi bir tavsiyedir; kullanici
   -- ustteki secenegi "onerilen" sanir. Dogrulanmamislari basa koymak,
   -- en zayif veriyi one cikarmak olurdu.
   order by coalesce(cp.confidence = 'verified', false) desc, i.name, cp.name;
$$;
grant execute on function public.card_product_options() to authenticated;

-- Karar motoru: dogrulanmamis kart secildiyse KESIN konusma
create or replace function public.card_confidence_note(p_user_id uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when cp.id is null then null
    when cp.confidence = 'verified' and cp.checked_at is not null then null
    else 'Host''un kart bilgisi bizde DOĞRULANMAMIŞ olarak kayıtlı ('
      || coalesce(i.name,'') || ' ' || coalesce(cp.name,'') || '). Aşağıdaki '
      || 'misafir hakkı bilgisi kesin değildir; girişten önce host ile teyit edin.'
  end
  from host_entitlements he
  left join lounge_card_products cp on cp.id = he.card_product_id
  left join lounge_issuers i on i.id = cp.issuer_id
 where he.user_id = p_user_id
 order by he.self_reported_at desc nulls last
 limit 1;
$$;
grant execute on function public.card_confidence_note(uuid) to authenticated;

select confidence, count(*) from lounge_card_products group by 1 order by 2 desc;

select '114 OK - kart guven derecesi listede ve kararda gorunuyor' as sonuc;
