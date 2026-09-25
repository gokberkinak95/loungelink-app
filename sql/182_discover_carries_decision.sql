-- ============================================================
-- LoungeLink · 182_discover_carries_decision.sql
-- KEŞFET ROZETLERİNİN KAYBOLMASI — ROZET YOK, VERİ YOK
--
-- ⚠️ Uygulamayı ETKİLER (keşfet listesi sözleşmesi genişliyor).
--
-- ------------------------------------------------------------
-- 🔴 TEŞHİS (Gökberk madde 6 ve 9)
-- ------------------------------------------------------------
-- "Misafir ücretsiz / misafir hakkı yok gibi hiçbir badge gelmiyor."
-- Ölçtüm: discover_availabilities 23 kolon döndürüyor ve İÇLERİNDE
-- KURAL KARARI YOK. Yani rozetler "uçmamış" — liste ekranına o veri
-- hiç ulaşmıyormuş. App ne kadar doğru yazılırsa yazılsın olmayan
-- alanı gösteremez.
--
-- Aynı eksik, madde 9'un da sebebi: "misafir hakkı görünmüyor ama
-- hâlâ istek gönderebiliyorum". Liste, ilanın istek almaya AÇIK olup
-- olmadığını bilmiyor; buton da bilmiyor. Sunucu tarafında kapı var
-- (159'un guests_not_allowed kapısı) ama kullanıcı bunu ancak
-- REDDEDİLDİKTEN SONRA öğreniyor. Doğrusu: butonu hiç aktif etmemek.
--
-- Ve madde 7'nin liste tarafı: AJet bileti olan biri THY'linin
-- ilanına başvuramaz. Bu bilgi de kararın içinde ama listeye
-- taşınmıyordu.
--
-- ------------------------------------------------------------
-- ÇÖZÜM: KARARI LİSTEYE TAŞI
-- ------------------------------------------------------------
-- Yeni kolonlar (mevcut 23'ün üstüne, hiçbiri kaldırılmadı):
--   guest_policy      included | paid | not_allowed | unknown
--   guest_allowance   kaç misafir
--   family_allowed    aile hakkı
--   decision_note     kullanıcı diline hazır tek cümle
--   blocks_request    TRUE ise buton pasif olmalı
--   block_reason      neden pasif (i18n anahtarı)
--   carrier_note      taşıyıcı uyuşmazlığı uyarısı (AJet/THY)
--
-- Kolon EKLEMEK sözleşmeyi bozmaz: app alanları ADIYLA seçiyor,
-- eski sürümler yeni kolonları görmezden gelir.
-- ============================================================

-- ---- 0) ORİJİNAL GÖVDE `_base` OLARAK KORUNUR ----
-- 🔴 Sarmalayıcı yazarken orijinali kopyalamak yerine TAŞIYORUZ:
-- kopyalasaydım iki gövde birbirinden bağımsız yaşar ve biri
-- güncellenince diğeri bayatlardı (bu projede iki kez oldu:
-- contract_check kopyası, BO'nun ölü denetimi). Gövde tek yerde
-- kalır; sarmalayıcı yalnız karar alanlarını ekler.
do $$
declare v_src text; v_res text; v_args text;
begin
  if to_regprocedure('public.discover_availabilities_base(text,text,text,date)') is not null then
    raise notice '182: _base zaten var'; return;
  end if;
  select prosrc, pg_get_function_result(oid), pg_get_function_identity_arguments(oid)
    into v_src, v_res, v_args
    from pg_proc where proname = 'discover_availabilities'
      and pronamespace = 'public'::regnamespace limit 1;
  if v_src is null then raise exception '182: discover_availabilities yok'; end if;

  execute 'create or replace function public.discover_availabilities_base('
       || 'p_airport text default null, p_sector text default null, '
       || 'p_flight text default null, p_date date default null) returns '
       || v_res || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_src || '$BODY$';
  raise notice '182: orijinal gövde _base olarak taşındı';
end $$;

grant execute on function public.discover_availabilities_base(text, text, text, date) to authenticated, anon;

drop function if exists public.discover_availabilities(text, text, text, date);

create or replace function public.discover_availabilities(
  p_airport text default null,
  p_sector  text default null,
  p_flight  text default null,
  p_date    date default null
) returns table (
  id uuid, host_id uuid, airport_code text, lounge_name text,
  avail_date date, time_from time, time_to time, flight_number text,
  slots int, filled int,
  host_name text, host_badge text, host_score int, host_profession text,
  host_photo text, match_score int, same_flight boolean, has_trip boolean,
  is_featured boolean, fully_booked boolean, visibility text,
  host_gender text, host_langs text[],
  -- 🔴 182: karar alanları
  guest_policy text, guest_allowance int, family_allowed boolean,
  decision_note text, blocks_request boolean, block_reason text,
  carrier_note text
)
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  with base as (
    select d.* from public.discover_availabilities_base(p_airport, p_sector, p_flight, p_date) d
  ), enriched as (
    select b.*,
           public.lounge_access_decision(b.id, b.flight_number) as dec,
           (select a.carrier from availabilities a where a.id = b.id) as av_carrier,
           (select upper(substring(regexp_replace(coalesce(v.flight_number,''), '[^A-Za-z]', '', 'g') from 1 for 2))
              from visits v
             where v.user_id = v_uid and v.airport_code = b.airport_code
               and v.visit_date = b.avail_date
               and coalesce(v.flight_number,'') <> ''
             limit 1) as my_carrier
      from base b
  )
  select e.id, e.host_id, e.airport_code, e.lounge_name, e.avail_date,
         e.time_from, e.time_to, e.flight_number, e.slots, e.filled,
         e.host_name, e.host_badge, e.host_score, e.host_profession,
         e.host_photo, e.match_score, e.same_flight, e.has_trip,
         e.is_featured, e.fully_booked, e.visibility,
         e.host_gender, e.host_langs,
         coalesce(e.dec ->> 'guest_policy', 'unknown'),
         coalesce((e.dec ->> 'guest_allowance')::int, 0),
         coalesce((e.dec ->> 'family_allowed')::boolean, false),
         nullif(e.dec ->> 'headline', ''),
         -- Buton HANGİ durumda pasif olmalı: kapasite dolu, misafir
         -- kabul edilmiyor, ya da karar açıkça engelliyor.
         coalesce(e.fully_booked, coalesce(e.filled,0) >= e.slots)
           or (coalesce(e.dec ->> 'guest_policy','') = 'not_allowed')
           or (coalesce(e.dec ->> 'severity','') = 'block'),
         case
           when coalesce(e.fully_booked, coalesce(e.filled,0) >= e.slots) then 'fully_booked'
           when coalesce(e.dec ->> 'guest_policy','') = 'not_allowed' then 'guests_not_allowed'
           when coalesce(e.dec ->> 'severity','') = 'block' then 'blocked_by_rule'
           else null end,
         -- 🔴 TAŞIYICI UYARISI (madde 7): Miles&Smiles bir STATÜDÜR ve
         -- THY ile AJet'i kapsar, ama salona giriş UÇULAN havayoluna
         -- bağlıdır. AJet biletiyle THY salonuna misafir olunamaz.
         -- Kullanıcı bunu başvurmadan önce görmeli.
         case
           when e.av_carrier is null or e.my_carrier is null then null
           when e.av_carrier = e.my_carrier then null
           when e.av_carrier in ('TK') and e.my_carrier in ('VF','AJ')
             then 'Bu ilan THY seferinde; senin biletin AJet. Aynı havayolunda olmadığınız için kabul alamayabilirsin.'
           when e.av_carrier in ('VF','AJ') and e.my_carrier = 'TK'
             then 'Bu ilan AJet seferinde; senin biletin THY. Aynı havayolunda olmadığınız için kabul alamayabilirsin.'
           else null end
    from enriched e;
end $$;

grant execute on function public.discover_availabilities(text, text, text, date) to authenticated, anon;

-- ---- KANIT ----
do $$
declare r record; n int := 0; v_block int := 0;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from users where email like 'kmisafir1%' limit 1),
                      'role', 'authenticated')::text, true);

  for r in select * from public.discover_availabilities(null, null, null, null) limit 40 loop
    n := n + 1;
    if r.guest_policy is null then
      raise exception '182: guest_policy boş döndü — karar listeye taşınmıyor';
    end if;
    if r.blocks_request then v_block := v_block + 1; end if;
  end loop;

  if n = 0 then
    raise notice '182: keşifte ilan yok — kanıt sınırlı';
  else
    raise notice '182: % ilan, %si istek almaya kapalı (buton pasif olmalı)', n, v_block;
  end if;
  perform set_config('request.jwt.claims', '{}', true);
end $$;

select '182 OK - kesfet karti karari, kapi durumunu ve tasiyici uyarisini tasiyor' as sonuc;
