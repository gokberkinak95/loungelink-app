-- ============================================================
-- LoungeLink · 013_push_tokens.sql — Push token saklama + tetikleyici
-- ============================================================

-- 1) Cihaz push token'ları
create table if not exists push_tokens (
  user_id    uuid not null references users(id) on delete cascade,
  token      text not null,
  platform   text default 'android',
  updated_at timestamptz default now(),
  primary key (user_id, token)
);
alter table push_tokens enable row level security;
drop policy if exists "push_own" on push_tokens;
create policy "push_own" on push_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 2) Token kaydet (upsert)
create or replace function public.save_push_token(p_token text, p_platform text default 'android')
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  insert into push_tokens (user_id, token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, now())
  on conflict (user_id, token) do update set updated_at = now();
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.save_push_token(text, text) to authenticated;

-- 3) Yeni bildirim eklendiğinde Edge Function'ı çağıran trigger.
--    NOT: net.http_post için pg_net eklentisi + ayarlar gerekir. Edge Function
--    deploy edilene kadar bu trigger'ı KURMUYORUZ; fonksiyon hazır olunca
--    aşağıdaki bloğu ayrı çalıştıracağız (014 olarak).

select 'PUSH TOKENS OK' as sonuc;
