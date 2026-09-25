-- ============================================================
-- LoungeLink · 063_error_logging.sql
--
-- SORUN: Şu an üretimde bir şey kırılırsa BUNU ANCAK BİR KULLANICI SÖYLERSE
-- öğreniyorsun. Bugün bulduğumuz iki hata (host kabul edemiyor, slot sayacı)
-- tam olarak böyleydi — aylarca sessizce kırıktı.
--
-- ÇÖZÜM: Uygulamadaki hatalar veritabanına yazılsın, backoffice'te görülsün.
-- Harici servis (Sentry vb.) gerekmiyor; mevcut altyapıya gömülü.
--
-- TASARIM NOTLARI:
--  • Kişisel veri yazılmaz: yalnız hata mesajı, ekran adı, sürüm, kullanıcı id.
--  • Kullanıcı SADECE INSERT edebilir (kendi hatasını bildirir), OKUYAMAZ.
--    Okuma yalnız backoffice'te (service_role RLS'i bypass eder).
--  • Kötüye kullanım/şişme koruması: kullanıcı başına 10 dakikada en fazla
--    20 kayıt. Aşarsa sessizce yok sayılır (uygulamayı asla bloklamaz).
--  • Fonksiyon ASLA hata fırlatmaz — log yazamamak yüzünden uygulama akışı
--    bozulmamalı.
-- ============================================================

create table if not exists app_errors (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references users(id) on delete set null,
  platform    text,                  -- 'android' | 'ios' | 'bo'
  app_version text,                  -- '1.48.0'
  screen      text,                  -- hatanın oluştuğu ekran/işlem
  code        text,                  -- kısa hata kodu (varsa)
  message     text not null,         -- hata mesajı (kırpılmış)
  context     jsonb,                 -- ek bağlam (PII YOK)
  created_at  timestamptz not null default now()
);

create index if not exists idx_app_errors_time   on app_errors(created_at desc);
create index if not exists idx_app_errors_screen on app_errors(screen, created_at desc);

alter table app_errors enable row level security;

-- Kullanıcı yalnızca KENDİ hatasını yazabilir; okuma yok.
drop policy if exists app_errors_insert_own on app_errors;
create policy app_errors_insert_own on app_errors
  for insert with check (user_id = auth.uid());


-- ============================================================
-- log_client_error — uygulamadan çağrılır, ASLA hata fırlatmaz
-- ============================================================
create or replace function public.log_client_error(
  p_screen   text,
  p_message  text,
  p_code     text  default null,
  p_version  text  default null,
  p_platform text  default null,
  p_context  jsonb default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_recent int;
begin
  if v_uid is null then return; end if;          -- anonim log tutmuyoruz

  -- Şişme koruması: 10 dakikada 20 kayıt üstü sessizce yok sayılır
  select count(*) into v_recent from app_errors
   where user_id = v_uid and created_at > now() - interval '10 minutes';
  if v_recent >= 20 then return; end if;

  insert into app_errors (user_id, platform, app_version, screen, code, message, context)
  values (v_uid,
          left(coalesce(p_platform,''), 20),
          left(coalesce(p_version,''), 20),
          left(coalesce(p_screen,'?'), 80),
          left(coalesce(p_code,''), 60),
          left(coalesce(p_message,'(bos)'), 500),
          p_context);
exception when others then
  -- Log yazamamak uygulamayı ASLA etkilememeli.
  return;
end $$;

grant execute on function public.log_client_error(text, text, text, text, text, jsonb) to authenticated;


-- ============================================================
-- bo_error_summary — backoffice özet görünümü
-- Aynı hatayı tekrar tekrar listelemek yerine gruplar.
-- ============================================================
create or replace function public.bo_error_summary(p_days int default 7)
returns table (
  screen text, code text, message text,
  adet bigint, etkilenen_kullanici bigint,
  ilk_gorulme timestamptz, son_gorulme timestamptz
)
language sql security definer set search_path = public as $$
  select e.screen, e.code, e.message,
         count(*)                         as adet,
         count(distinct e.user_id)        as etkilenen_kullanici,
         min(e.created_at)                as ilk_gorulme,
         max(e.created_at)                as son_gorulme
    from app_errors e
   where e.created_at > now() - make_interval(days => greatest(p_days,1))
   group by e.screen, e.code, e.message
   order by count(*) desc, max(e.created_at) desc
   limit 200;
$$;

revoke all on function public.bo_error_summary(int) from public, anon, authenticated;
grant execute on function public.bo_error_summary(int) to service_role;


select '063 OK — app_errors tablosu + log_client_error RPC + bo_error_summary hazir' as sonuc;
