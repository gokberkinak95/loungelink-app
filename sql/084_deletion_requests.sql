-- ============================================================
-- LoungeLink · 084_deletion_requests.sql
--
-- Google Play, uygulama içi silmenin YANINDA web üzerinden erişilebilen bir
-- hesap silme yolu istiyor (mağaza listesindeki "Account deletion URL").
-- BO'daki /hesap-sil sayfası talebi buraya yazar; silme OTOMATİK DEĞİLDİR —
-- e-postasını bilen herkesin başkasının hesabını silebilmesi demek olurdu.
-- Talep BO'da işlenir, kullanıcıya e-posta ile doğrulanır.
-- ============================================================

create table if not exists deletion_requests (
  id          uuid primary key default uuid_generate_v4(),
  email       text not null,
  note        text,
  source      text default 'web',            -- web | app | support
  status      text not null default 'pending' check (status in ('pending','verified','done','rejected')),
  matched_user_id uuid references users(id),
  handled_by  uuid references users(id),
  handled_at  timestamptz,
  resolution  text,
  created_at  timestamptz default now()
);
create index if not exists idx_delreq_status on deletion_requests(status, created_at desc);

-- Yalnız servis rolü okur/yazar: talep listesi kişisel veri içerir, hiçbir
-- normal kullanıcı görmemeli.
alter table deletion_requests enable row level security;
revoke all on deletion_requests from anon, authenticated;
grant all on deletion_requests to service_role;

-- Gelen talebi mevcut kullanıcıyla eşleştir (BO listesinde kolaylık)
create or replace function public.match_deletion_requests()
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update deletion_requests d
     set matched_user_id = u.id
    from users u
   where lower(u.email) = lower(d.email)
     and d.matched_user_id is null;
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.match_deletion_requests() from anon, authenticated;
grant execute on function public.match_deletion_requests() to service_role;

-- DOĞRULAMA
select exists (select 1 from information_schema.tables
                where table_name='deletion_requests') as "talep_tablosu_var";
select '084 OK - hesap silme talepleri tablosu hazir (Play sarti)' as sonuc;
