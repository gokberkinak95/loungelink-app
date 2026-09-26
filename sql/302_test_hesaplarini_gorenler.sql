-- ============================================================================
-- LoungeLink · 302_test_hesaplarini_gorenler.sql                (23 Eylül 2026)
--
-- 🔴 NEDEN VAR
-- 301, test hesaplarını (seed / sahne / vitrin / e2e) gerçek kullanıcılardan
-- gizledi. Gizleme doğru ama tek bir düğmeydi: ya herkes görür ya kimse.
-- Gökberk kendi gerçek hesabıyla test dünyasını görmek istiyor; bunun için
-- bayrağı kapatmak, beta kullanıcılarının da test ilanlarını görmesi demekti.
--
-- Artık KİŞİ BAZINDA: `test_gorunurlugu` tablosundaki hesaplar test
-- hesaplarını görür, geri kalan herkes görmez. Bayrak açık kalır.
--   · Gökberk'in hesabı (gokberkinak95@gmail.com) bu dosyayla eklenir.
--   · Başka biri: BO → Kullanıcılar → kişi → "Test hesaplarını görsün".
--
-- Tablo uygulamaya KAPALI (RLS açık, politika yok, anon/authenticated'a
-- yetki yok): kimse kendini listeye ekleyemez; yalnız BO (service role).
--
-- KULLANIM: Supabase → SQL Editor → tamamını yapıştır → Run.
-- ÖNKOŞUL: 301. TEKRAR KOŞULABİLİR. Satır başında geçici tablo YOK
-- (Editor her ifadeyi ayrı işlemde koşuyor — bkz. sql_editor_check.py).
-- ============================================================================

create table if not exists public.test_gorunurlugu (
  user_id    uuid primary key references public.users(id) on delete cascade,
  ekleyen    text,
  created_at timestamptz not null default now()
);
alter table public.test_gorunurlugu enable row level security;
revoke all on public.test_gorunurlugu from public, anon, authenticated;
grant all on public.test_gorunurlugu to service_role;

-- Gökberk'in gerçek hesabı (büyük/küçük harf duyarsız)
insert into public.test_gorunurlugu (user_id, ekleyen)
select u.id, '302 · kurucu'
  from public.users u
 where lower(u.email) = 'gokberkinak95@gmail.com'
on conflict (user_id) do nothing;

-- true = BU İZLEYİCİ için hedefi GİZLE
-- (301 ile birebir aynı; tek fark son satır: listedeki izleyici görür)
create or replace function public.test_hesabi_gizli_mi(p_hedef uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true)
     and exists (select 1 from users u where u.id = p_hedef and public.seed_test_hesabi(u.email))
     and not coalesce((select public.seed_test_hesabi(x.email) or coalesce(x.is_staff, false)
                         from users x where x.id = auth.uid()), false)
     and not exists (select 1 from test_gorunurlugu g where g.user_id = auth.uid());
$$;
revoke execute on function public.test_hesabi_gizli_mi(uuid) from public, anon;
grant execute on function public.test_hesabi_gizli_mi(uuid) to authenticated, service_role;

update public.feature_flags
   set description = 'Açıkken SEED/test hesapları (…@seed/sahne/vitrin.loungelink.test) gerçek kullanıcılara görünmez. '
                  || 'Test hesapları, ekip ve BO''da "Test hesaplarını görsün" işaretli kişiler her şeyi görür (302).'
 where key = 'test_hesaplarini_gizle';

-- ── §Z — kendini ölç ─────────────────────────────────────────────────────
do $z302$
begin
  if has_table_privilege('authenticated', 'public.test_gorunurlugu', 'insert')
     or has_table_privilege('authenticated', 'public.test_gorunurlugu', 'select')
     or has_table_privilege('anon', 'public.test_gorunurlugu', 'select') then
    raise exception '302 §Z: test_gorunurlugu uygulamaya açık';
  end if;
  if position('test_gorunurlugu' in (select prosrc from pg_proc where proname = 'test_hesabi_gizli_mi')) = 0 then
    raise exception '302 §Z: test_hesabi_gizli_mi yamasız';
  end if;
  if exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
              where p.proname = 'test_hesabi_gizli_mi' and a.grantee = 0 and a.privilege_type = 'EXECUTE') then
    raise exception '302 §Z: test_hesabi_gizli_mi PUBLIC''e açık';
  end if;
end $z302$;

-- SONUÇ: test hesaplarını kimler görüyor? Gökberk'in satırı YOKSA uygulamadaki
-- e-postan farklı demektir — BO → Kullanıcılar → hesabın → "Test hesaplarını görsün".
select '302 OK' as sonuc, u.email as test_hesaplarini_goren, g.ekleyen, g.created_at
  from public.test_gorunurlugu g join public.users u on u.id = g.user_id
union all
select '302 OK — ⚠ gokberkinak95@gmail.com hesabı bulunamadı, BO''dan ekle', null, null, null
 where not exists (select 1 from public.test_gorunurlugu g join public.users u on u.id = g.user_id
                    where lower(u.email) = 'gokberkinak95@gmail.com');
