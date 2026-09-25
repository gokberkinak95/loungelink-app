-- ============================================================
-- LoungeLink · 091_flight_quota.sql
-- UÇUŞ VERİSİNİ UYGULAMAYA AÇMAK — AMA KOTAYI YAKMADAN
--
-- ⚠️ UYGULAMAYI ETKİLER (v1.87 ile): yeni bir RPC + ayar. Eski imzalar aynı.
--
-- ------------------------------------------------------------
-- 🔴 ASIL KISIT DOMAIN DEĞİL, KOTA
-- ------------------------------------------------------------
-- Geçen tur "alan adı gerekli" demiştim; bu FAZLA GENİŞ bir ifadeydi.
-- Backoffice zaten Vercel'de bir *.vercel.app adresinde yayında ve API
-- rotaları oradan sorunsuz çalışır. Alan adı **e-posta bağlantıları** için
-- gerekli (Supabase Site URL), API çağrısı için değil. Düzeltiyorum.
--
-- Gerçek kısıt şu: AviationStack ücretsiz katman **ayda 100 istek**.
-- Uygulamadan serbestçe çağrılırsa:
--   20 host × 2 seyahat + misafirlerin görüntülemeleri = ilk hafta biter,
--   sonra herkes "uçuş bilgisi yok" görür ve özellik ölü görünür.
-- Üstelik /api/flight kimlik doğrulamasızsa, adresi bilen HERKES kotayı
-- yakabilir. Bu yüzden veriyi açmadan önce kapı gerekiyor.
--
-- ÜÇ KATMANLI KORUMA:
--   1. Önbellek önce — aynı uçuş/gün ikinci kez sağlayıcıya GİTMEZ (083)
--   2. Kimlik — rota Supabase JWT ister, anonim çağrı reddedilir
--   3. Kota — kullanıcı başına günlük + sistem geneli aylık tavan (BURASI)
--
-- Ayarların hepsi beta_settings'te: BO'dan kısıp açabilirsin, deploy yok.
-- `flight_autofetch=false` yaparsan uygulama SAĞLAYICIYA HİÇ GİTMEZ,
-- yalnız önbelleği okur (özellik yine çalışır, sadece veri seyrek olur).
-- ============================================================

create table if not exists flight_fetch_log (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid references users(id) on delete set null,
  flight_no  text,
  flight_day date,
  outcome    text not null default 'provider',
  created_at timestamptz default now()
);
create index if not exists idx_ffl_user_day on flight_fetch_log (user_id, created_at);
create index if not exists idx_ffl_created on flight_fetch_log (created_at);

alter table flight_fetch_log drop constraint if exists ffl_outcome_chk;
alter table flight_fetch_log add constraint ffl_outcome_chk
  check (outcome in ('provider','cache','denied_user_cap','denied_month_cap','denied_off'));

alter table flight_fetch_log enable row level security;
drop policy if exists ffl_own on flight_fetch_log;
create policy ffl_own on flight_fetch_log
  for select to authenticated using (user_id = auth.uid());

insert into beta_settings (key, value) values
  ('flight_autofetch',  to_jsonb(true)),
  ('flight_user_daily', to_jsonb(3)),     -- kullanıcı başına gün
  ('flight_month_cap',  to_jsonb(80))     -- 100'lük kotanın %80'i; kalan 20 BO testine
on conflict (key) do nothing;

-- Kapı. Rota bunu ÇAĞIRIR, sonucuna göre sağlayıcıya gider ya da gitmez.
-- Kararı ve gerekçesini kaydeder ki kotanın nereye gittiği görünsün.
create or replace function public.flight_fetch_allow(p_user_id uuid, p_flight text, p_day date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_on    boolean := coalesce((select (value #>> '{}')::boolean from beta_settings where key='flight_autofetch'), true);
  v_ud    int     := coalesce((select (value #>> '{}')::int from beta_settings where key='flight_user_daily'), 3);
  v_mc    int     := coalesce((select (value #>> '{}')::int from beta_settings where key='flight_month_cap'), 80);
  v_user  int;
  v_month int;
  v_out   text;
begin
  -- Önbellekte varsa kapı hiç işlemez; rota zaten oraya bakıyor.
  if not v_on then v_out := 'denied_off';
  else
    select count(*) into v_user from flight_fetch_log
     where user_id = p_user_id and outcome = 'provider'
       and created_at >= date_trunc('day', now());
    select count(*) into v_month from flight_fetch_log
     where outcome = 'provider' and created_at >= date_trunc('month', now());
    if v_user >= v_ud then v_out := 'denied_user_cap';
    elsif v_month >= v_mc then v_out := 'denied_month_cap';
    else v_out := 'provider';
    end if;
  end if;

  insert into flight_fetch_log (user_id, flight_no, flight_day, outcome)
  values (p_user_id, upper(trim(coalesce(p_flight,''))), p_day, v_out);

  return jsonb_build_object(
    'allow', v_out = 'provider',
    'reason', v_out,
    'user_today', coalesce(v_user,0), 'user_cap', v_ud,
    'month_used', coalesce(v_month,0), 'month_cap', v_mc);
end $$;
revoke all on function public.flight_fetch_allow(uuid, text, date) from public, authenticated;
-- 🔴 Yalnız SUNUCU (service_role) çağırabilir. İstemciye açık olsaydı
-- kullanıcı kendi kotasını sahte çağrılarla tüketip/atlatabilirdi.

-- Uygulamanın çağıracağı TEK fonksiyon: önbelleği okur, yoksa "yok" der.
-- Sağlayıcıya gitme kararı SUNUCUDA (BO rotası) verilir.
create or replace function public.flight_info(p_flight_no text, p_date date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v flight_cache%rowtype;
begin
  if coalesce(p_flight_no,'') = '' or p_date is null then
    return jsonb_build_object('hit', false, 'reason', 'eksik_parametre');
  end if;
  select * into v from flight_cache
   where upper(replace(flight_no,' ','')) = upper(replace(trim(p_flight_no),' ',''))
     and flight_date = p_date;
  if not found then
    return jsonb_build_object('hit', false,
      'autofetch', coalesce((select (value #>> '{}')::boolean from beta_settings where key='flight_autofetch'), true));
  end if;
  -- 🔴 KAYNAK VE ZAMAN HER ZAMAN DÖNER. v1.81'de uydurma "Zamanında"
  -- yazdığımız için Canlı Durum bloğu tamamen kaldırılmıştı; uçuş verisi
  -- kaynağı ve tazeliği gösterilmeden EKRANA KONMAZ.
  return jsonb_build_object('hit', true,
    'scheduled_departure', v.scheduled_departure,
    'terminal', v.terminal, 'gate', null,
    'status', v.status, 'source', v.source, 'fetched_at', v.fetched_at,
    'stale', v.fetched_at < now() - interval '12 hours');
end $$;
grant execute on function public.flight_info(text, date) to authenticated;

-- Kota nereye gitti? BO raporu.
create or replace function public.flight_quota_report()
returns table (gun date, saglayici int, onbellek int, reddedilen int)
language sql stable security definer set search_path = public as $$
  select created_at::date,
         count(*) filter (where outcome = 'provider')::int,
         count(*) filter (where outcome = 'cache')::int,
         count(*) filter (where outcome like 'denied%')::int
    from flight_fetch_log
   where created_at >= now() - interval '45 days'
   group by 1 order by 1 desc;
$$;
grant execute on function public.flight_quota_report() to authenticated;

select (select value #>> '{}' from beta_settings where key='flight_autofetch') as otomatik_cekim,
       (select value #>> '{}' from beta_settings where key='flight_user_daily') as kullanici_gunluk,
       (select value #>> '{}' from beta_settings where key='flight_month_cap')  as aylik_tavan;

select '091 OK - ucus verisi kotali kapiyla acildi' as sonuc;
