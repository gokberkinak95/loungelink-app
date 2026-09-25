-- ============================================================
-- LoungeLink · 126_partners_visible.sql
-- ANLASMALI KURUMLAR EKRANA CIKIYOR
--
-- ⚠️ Uygulamayi ETKILER (yeni RPC).
--
-- 125 veriyi girdi. Ama GORUNMEYEN VERI, OLMAYAN VERIDIR — bu hatayi
-- bu projede iki kez yaptim (promo_redemptions tablosu vardi ekrani
-- yoktu; flight.js yazilmisti cagrilmiyordu). Bu sefer ayni turda
-- bagliyorum.
--
-- IKI KULLANIM:
--   · Host "hangi kartla girerim" diye bakarken salonun kabul ettigi
--     kurumlari gorsun.
--   · Misafir bir ilana bakarken "benim kartim da gecer mi" diye
--     kontrol edebilsin.
-- ============================================================

create or replace function public.venue_partners(p_lounge_id uuid)
returns table (scope text, partner_kind text, partner_name text,
               program_code text, terms_known boolean)
language sql stable security definer set search_path = public as $$
  select vp.scope, vp.partner_kind, vp.partner_name, pr.code, vp.terms_known
    from lounges l
    join lounge_venues v on v.id = l.venue_id
    join lounge_venue_partners vp on vp.venue_id = v.id and vp.active
    left join lounge_programs pr on pr.id = vp.program_id
   where l.id = p_lounge_id
   -- 🔴 SIRA ANLAM TASIR: once BANKALAR (kullanicilarin cogunda banka
   -- karti var), sonra kart aglari, sonra havayolu, en sonda kurumsal.
   -- Alfabetik siralama en olasi secenegi listenin ortasina gomerdi.
   order by case vp.partner_kind when 'bank' then 1 when 'global' then 2
                                 when 'airline' then 3 else 4 end,
            vp.partner_name;
$$;
grant execute on function public.venue_partners(uuid) to authenticated;

-- Salonun kac anlasmasi var — kesif kartinda kisa ozet
create or replace function public.venue_partner_count(p_lounge_id uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(distinct vp.partner_name)::int
    from lounges l
    join lounge_venues v on v.id = l.venue_id
    join lounge_venue_partners vp on vp.venue_id = v.id and vp.active
   where l.id = p_lounge_id;
$$;
grant execute on function public.venue_partner_count(uuid) to authenticated;

select '126 OK - anlasmali kurumlar app''e acildi' as sonuc;

-- ============================================================
-- 🔴 DEGISMEZ DENETIMI YAKALADI: yeni programlarin KABUL SATIRI yok
-- ------------------------------------------------------------
-- 125'te DreamFolks, OnPass, Everylounge ve ST Pass'i tanittim ama
-- hicbir salona baglamadim. Sonuc: host "DreamFolks" yazinca program
-- ESLESIYOR ama hicbir salonda kabul satiri olmadigi icin karar motoru
-- bos donuyor ve genel uyariya dusuyor.
--
-- Oysa NEREDE gecerli olduklarini BILIYORUZ: havalimaninin kendi
-- sayfasi SAW Plaza Premium icin listelemis. Bildigimiz bir seyi
-- baglamamak, 107'deki "sessiz atlama" hatasinin aynisi.
--
-- Kosullari bilmiyoruz -> guest_policy 'unknown', enforcement 'warn'.
-- Yani: "bu salona bu programla girilebiliyor, ama misafir kurali
-- dogrulanmadi" diyoruz. Bildigimizi soyleyip bilmedigimizi saklamiyoruz.
-- ============================================================
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, enforcement, conditions, source_url, checked_at)
select distinct vp.venue_id, p.id, true, 'unknown', 0, 'any', 'warn',
       'Havalimanının kendi sayfası bu salonu ' || p.name || ' anlaşma listesinde '
       || 'gösteriyor. Girişin mümkün olduğunu biliyoruz; MİSAFİR koşullarını '
       || '(hak sayısı, ücret) doğrulayamadık — girişten önce teyit edin.',
       'https://www.sabihagokcen.aero/', current_date
  from lounge_venue_partners vp
  join lounge_programs p
    on lower(p.name) = lower(vp.partner_name)
   and p.code in ('DREAMFOLKS','ONPASS','EVERYLOUNGE','ST_PASS','AMEX_GLOBAL')
 where vp.active
on conflict (venue_id, program_id) do nothing;

select p.code, count(*) as kabul_satiri
  from lounge_programs p
  left join lounge_venue_acceptance a on a.program_id = p.id and a.active
 where p.code in ('DREAMFOLKS','ONPASS','EVERYLOUNGE','ST_PASS','AMEX_GLOBAL')
 group by p.code order by 1;
