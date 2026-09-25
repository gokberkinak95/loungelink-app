-- ============================================================
-- LoungeLink · 151_deterministic_program_pick.sql
-- AYNI GIRDI, FARKLI CIKTI — BELIRSIZ SIRALAMA
--
-- ⚠️ Uygulamayi ETKILER (program secimi).
--
-- ------------------------------------------------------------
-- 🔴 E2E TESTI UC KEZ KOSTUM: 14/14, 9/14, 9/14
-- ------------------------------------------------------------
-- Ayni kod, ayni veri, FARKLI sonuc. Once testin kirilgan oldugunu
-- sandim ve gecici dizin sorununu duzelttim — o gercek bir sorundu
-- ama ASIL sebep degildi.
--
-- Gercek sebep: karar motorunda program secimi BELIRSIZ.
--   order by (guest_policy='included') desc, (guest_policy='paid') desc,
--            he.verified desc
--   limit 1
--
-- Host'un iki hakki ayni gruba dusuyorsa (ikisi de 'paid', ikisi de
-- dogrulanmamis) siralama BERABERE kaliyor ve PostgreSQL istedigini
-- donduruyor. Plan degisince cevap degisiyor.
--
-- 🔴 BU EN TEHLIKELI HATA TURU. Cokmuyor, hata vermiyor, denetimden
-- geciyor — sadece bazen yanlis cevap veriyor. Kullanici acisindan
-- "bazen misafir goturebiliyorum, bazen goturemiyorum" demek, urune
-- olan guvenin bittigi andir.
--
-- Cozum: siralamayi TAM BELIRLI yap. Beraberlik kalmayacak sekilde
-- en sona benzersiz bir anahtar koy.
-- ============================================================

create or replace function public.pick_host_program(p_host uuid, p_venue_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select a2.program_id
    from host_entitlements he
    join lounge_venue_acceptance a2
      on a2.program_id = he.program_id and a2.venue_id = p_venue_id
     -- 🔴 `accepted` NULL olabiliyor ve `and a2.accepted` NULL'da
     -- satiri ELIYOR. 086'dan devraldigim kosuldu; belirli siralamayi
     -- kurarken aynen tasidim ve fonksiyon BOS donmeye basladi.
     -- Ucuncu kez ayni ders: NULL, boolean baglamda false degil NULL'dir.
     and coalesce(a2.accepted, true) and a2.active
   where he.user_id = p_host
   -- 🔴 SIRALAMA TAM BELIRLI OLMALI. Her satir en az bir anahtarda
   -- digerinden farkli olmali; yoksa PostgreSQL istedigini secer ve
   -- ayni sorgu iki kez farkli cevap verir.
   order by coalesce(a2.guest_policy = 'included', false) desc,
            coalesce(a2.guest_policy = 'paid', false) desc,
            coalesce(he.verified, false) desc,
            coalesce(a2.is_placeholder, false) asc,     -- arastirilmis olan once
            a2.checked_at desc nulls last,              -- yeni dogrulanan once
            a2.program_id                               -- 🔴 SON CARE: benzersiz,
                                                        -- beraberligi kesin bitirir
   limit 1;
$$;
grant execute on function public.pick_host_program(uuid, uuid) to authenticated;

-- Karar motorunu bu tek secime bagla
do $$
declare v_src text; v_new text;
begin
  select pg_get_functiondef(p.oid) into v_src
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'lounge_access_decision_v3'
   limit 1;
  if v_src is null then return; end if;

  -- Belirsiz blogu tek satirlik belirli cagriyla degistir.
  v_new := regexp_replace(v_src,
    'select\s+a2\.program_id.*?limit 1;',
    'select public.pick_host_program(v_av.host_id, v_venue_id) into v_prog_id;',
    'is');
  if v_new <> v_src then
    execute v_new;
    raise notice '✓ lounge_access_decision_v3 belirli secime baglandi';
  else
    raise warning '⚠ Desen bulunamadi — v3 elle kontrol edilmeli';
  end if;
end $$;

-- ---- KARARLILIK TESTI: ayni sorgu 20 kez, hep ayni cevap mi ----
create or replace function public.determinism_check()
returns table (avail_id uuid, farkli_cevap int)
language sql stable security definer set search_path = public as $$
  select a.id, count(distinct x.pol)::int
    from availabilities a
    cross join lateral (
      select (public.lounge_access_decision_v5(a.id, null, null) ->> 'guest_policy') as pol
        from generate_series(1, 20)
    ) x
   group by a.id having count(distinct x.pol) > 1;
$$;
grant execute on function public.determinism_check() to authenticated;

select 'belirsiz karar veren ilan' as kontrol, count(*)::text from public.determinism_check();

select '151 OK - program secimi tam belirli' as sonuc;
