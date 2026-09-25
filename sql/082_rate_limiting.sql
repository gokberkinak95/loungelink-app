-- ============================================================
-- LoungeLink · 082_rate_limiting.sql
--
-- 🔴 BUGÜNE KADAR HİÇ RATE LIMIT YOKTU. Bir kişi saniyede yüzlerce istek
-- gönderip: (a) diğer kullanıcıları spam'leyebilir, (b) Supabase ücretsiz
-- katman kotasını yakabilir, (c) bildirim/e-posta gönderimini tüketebilirdi.
--
-- TASARIM KARARI — neden TRIGGER, neden fonksiyon içi değil:
-- Sınırı RPC fonksiyonlarının içine koymak, o fonksiyonların HEPSİNİ yeniden
-- tanımlamayı gerektirirdi (10+ fonksiyon, her biri regresyon riski).
-- Trigger, YAZMA YOLUNU kapatır: RPC'den de gelse, doğrudan tablo
-- insert'inden de gelse, gelecekte yazacağımız yeni bir fonksiyondan da
-- gelse aynı sınır uygulanır. Kapsam bakımından daha güvenli.
--
-- SAYAÇ: kayan pencere (son N dakikadaki kendi satırlarını sayar). Ayrı bir
-- sayaç tablosu tutmuyoruz — veri zaten tabloda; böylece sayaç ile gerçek
-- asla ayrışamaz (078'de öğrendiğimiz "tek doğruluk kaynağı" dersi).
--
-- LİMİTLER beta_settings'ten okunur → sunucuyu yeniden yüklemeden BO'dan
-- değiştirilebilir. Değer yoksa güvenli varsayılan kullanılır.
-- ============================================================

insert into beta_settings (key, value) values
  ('rate_limits', jsonb_build_object(
     'messages_per_min',        20,   -- sohbet: normal yazışma ~5-10/dk
     'requests_per_hour',        10,  -- istek gönderme (kredi zaten sınırlı ama spam olur)
     'connections_per_hour',     15,  -- bağlantı isteği
     'invites_per_hour',         20,  -- davet
     'availabilities_per_day',   10,  -- ilan açma
     'visits_per_day',           15,  -- seyahat ekleme
     'reports_per_day',          10   -- şikayet (kötüye kullanım aracı olabiliyor)
  ))
on conflict (key) do nothing;


create or replace function public.rl_limit(p_key text, p_default int)
returns int language sql stable security definer set search_path = public as $$
  select coalesce((select (value ->> p_key)::int from beta_settings where key = 'rate_limits'), p_default)
$$;


-- Ortak kontrol: belirli bir tabloda, belirli bir kullanıcı kolonunda,
-- son X dakikada Y satırdan fazlası varsa hata.
create or replace function public.rl_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid; v_limit int; v_window interval; v_count int;
  v_key text := TG_ARGV[0];      -- beta_settings anahtarı
  v_default int := TG_ARGV[1]::int;
  v_minutes int := TG_ARGV[2]::int;
  v_col text := TG_ARGV[3];      -- kullanıcı kolonu adı
begin
  v_uid := auth.uid();
  if v_uid is null then return new; end if;   -- sunucu tarafı işler (service_role) sınırsız

  v_limit := public.rl_limit(v_key, v_default);
  v_window := make_interval(mins => v_minutes);

  execute format(
    'select count(*) from %I where %I = $1 and created_at > now() - $2',
    TG_TABLE_NAME, v_col
  ) into v_count using v_uid, v_window;

  if v_count >= v_limit then
    raise exception 'rate_limited'
      using hint = format('%s: %s/%s dk', v_key, v_limit, v_minutes);
  end if;
  return new;
end $$;


-- ---------- Tetikleyiciler ----------
drop trigger if exists trg_rl_messages on messages;
create trigger trg_rl_messages before insert on messages
for each row execute function public.rl_guard('messages_per_min', '20', '1', 'from_id');

drop trigger if exists trg_rl_requests on requests;
create trigger trg_rl_requests before insert on requests
for each row execute function public.rl_guard('requests_per_hour', '10', '60', 'guest_id');

drop trigger if exists trg_rl_connections on connection_requests;
create trigger trg_rl_connections before insert on connection_requests
for each row execute function public.rl_guard('connections_per_hour', '15', '60', 'from_id');

drop trigger if exists trg_rl_invites on invites;
create trigger trg_rl_invites before insert on invites
for each row execute function public.rl_guard('invites_per_hour', '20', '60', 'host_id');

drop trigger if exists trg_rl_availabilities on availabilities;
create trigger trg_rl_availabilities before insert on availabilities
for each row execute function public.rl_guard('availabilities_per_day', '10', '1440', 'host_id');

drop trigger if exists trg_rl_visits on visits;
create trigger trg_rl_visits before insert on visits
for each row execute function public.rl_guard('visits_per_day', '15', '1440', 'user_id');

drop trigger if exists trg_rl_reports on reports;
create trigger trg_rl_reports before insert on reports
for each row execute function public.rl_guard('reports_per_day', '10', '1440', 'reporter_id');


-- ---------- DOĞRULAMA ----------
-- 7 tetikleyici de kurulmuş olmalı
select count(*) as "rate_limit_tetikleyici_sayisi"
  from pg_trigger where tgname like 'trg_rl_%' and not tgisinternal;

-- Limitler BO'dan değiştirilebilir olmalı
select value as "gecerli_limitler" from beta_settings where key = 'rate_limits';

select '082 OK - rate limiting 7 yazma yolunda aktif, limitler beta_settings.rate_limits ile ayarlanir' as sonuc;
