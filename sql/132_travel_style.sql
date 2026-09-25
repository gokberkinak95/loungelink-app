-- ============================================================
-- LoungeLink · 132_travel_style.sql
-- SEYAHAT TARZI — "NASIL BIRI OLDUGUNU" SORUYORUZ
--
-- ⚠️ Uygulamayi ETKILER (yeni kolon + eslesme sinyali).
--
-- ------------------------------------------------------------
-- NEDEN GEREKLI — VE `purpose` ILE NEDEN AYNI SEY DEGIL
-- ------------------------------------------------------------
-- `purpose` zaten var: is / konferans / tatil / aktarma / etkinlik.
-- O NEDEN ucuyor sorusunu yanitliyor. Ama eslesmenin asil kirildigi
-- yer orasi degil: iki kisi de "is" icin uçuyor olabilir, biri sohbet
-- etmek ister, oteki dizustunu acip calismak.
--
-- Sessiz calismak isteyen birini konusmak isteyen biriyle eslestirmek,
-- ikisini de rahatsiz eder ve IKISI DE bir daha denemez. Bu, iki
-- tarafli bir pazarda en pahali hata turudur — tek bir kotu bulusma
-- iki kullanici birden kaybettirir.
--
-- 🔴 ZORUNLU DEGIL. Bos birakan kullanici cezalandirilmaz: eslesme
-- puani etkilenmez, yalniz uyum sinyali cikmaz. Kisilik testine
-- zorlamak, kaydolmayi zorlastirmaktan baska ise yaramaz.
-- ============================================================

alter table profiles add column if not exists travel_style text
  check (travel_style is null or travel_style in
         ('social','zen','foodie','explorer'));
comment on column profiles.travel_style is
  'Sosyal tarz — `purpose` (seyahat amaci) ile KARISTIRILMAMALI. '
  'social: sohbet · zen: sessiz eslik · foodie: ikram/bufe · explorer: havalimani kesfi. '
  'Bos birakilabilir; bos ise eslesme puani ETKILENMEZ.';

create or replace function public.travel_style_options()
returns table (code text, label text, sub text, sort_order int)
language sql stable as $$
  select * from (values
    ('social',   'Sohbete açığım',      'Bir şeyler içip muhabbet edelim', 1),
    ('zen',      'Sessiz eşlik',        'Yanımda biri olsun ama sessiz olsun', 2),
    ('foodie',   'İkramlar için buradayım', 'Büfeyi keşfetmeyi severim', 3),
    ('explorer', 'Havalimanı kaşifi',   'Her köşeyi bilirim, gezmeyi severim', 4)
  ) as t(code, label, sub, sort_order) order by sort_order;
$$;
grant execute on function public.travel_style_options() to authenticated;

-- ---- UYUM MATRISI ----
-- 🔴 "AYNI OLAN EN IYIDIR" DOGRU DEGIL.
-- İki "sohbetçi" harika eşleşir. İki "sessiz" de iyi eşleşir — ikisi
-- de sessizlikten rahatsız olmaz. Ama sohbetçi + sessiz KOTU: biri
-- konusur, oteki kacar.
-- Kaşif ile foodie iyi anlasir (ikisi de KESFETMEK ister).
-- Bu yuzden basit bir "esitse iyi" kurali degil, gercek bir matris.
create or replace function public.style_fit(p_a text, p_b text)
returns int language sql immutable as $$
  select case
    when p_a is null or p_b is null then 0        -- bilinmiyor: NOTR
    when p_a = p_b then 12
    when (p_a = 'social'  and p_b = 'zen')      or (p_a = 'zen'      and p_b = 'social')  then -10
    when (p_a = 'foodie'  and p_b = 'explorer') or (p_a = 'explorer' and p_b = 'foodie')  then 8
    when (p_a = 'social'  and p_b in ('foodie','explorer'))
      or (p_b = 'social'  and p_a in ('foodie','explorer')) then 6
    when (p_a = 'zen'     and p_b in ('foodie','explorer'))
      or (p_b = 'zen'     and p_a in ('foodie','explorer')) then 2
    else 0 end;
$$;
grant execute on function public.style_fit(text, text) to authenticated;

create or replace function public.style_note(p_a text, p_b text)
returns text language sql stable security definer set search_path = public as $$
  select case
    when p_a is null or p_b is null then null
    when p_a = p_b and p_a = 'social' then 'İkiniz de sohbete açıksınız.'
    when p_a = p_b and p_a = 'zen'    then 'İkiniz de sessiz eşlik tercih ediyorsunuz.'
    when p_a = p_b then 'Seyahat tarzınız aynı.'
    when public.style_fit(p_a, p_b) < 0
      then '⚠ Tarzlarınız farklı: biriniz sohbet, diğeriniz sessizlik istiyor. '
        || 'Buluşmadan önce beklentinizi konuşmanız iyi olur.'
    when public.style_fit(p_a, p_b) >= 6 then 'Seyahat tarzlarınız uyumlu.'
    else null end;
$$;
grant execute on function public.style_note(text, text) to authenticated;

select code, label from public.travel_style_options();
select 'social+zen' as cift, public.style_fit('social','zen') as puan
union all select 'social+social', public.style_fit('social','social')
union all select 'zen+zen', public.style_fit('zen','zen')
union all select 'foodie+explorer', public.style_fit('foodie','explorer')
union all select 'bilinmiyor', public.style_fit(null,'social');

select '132 OK - seyahat tarzi eklendi' as sonuc;
