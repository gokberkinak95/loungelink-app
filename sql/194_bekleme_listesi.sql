-- ============================================================
-- 194 · BEKLEME LİSTESİ — mailto'nun yerine ölçülebilir liste
-- 17 Ağustos 2026
--
-- 🔴 NEDEN: site v0.18'e kadar beta çağrısı `mailto:` idi ve bu ÜÇ
-- ŞEYİ BİRDEN öldürüyordu:
--   1. Mobilde posta uygulaması yapılandırılmamış kullanıcılarda
--      tıklama boşa gider → dönüşüm SESSİZCE sıfırlanır
--   2. Hangi kanaldan (IG postu, arama, LinkedIn) geldiği ÖLÇÜLEMEZ
--   3. Sonradan e-posta gönderilecek liste BİRİKMEZ
--
-- Sitedeki gerekçe ("beta'da 100 kişi için mailto yeterli") beta
-- ÖNCESİNDE doğruydu; lansmanda yanlış. Ölçmediğin kanalı optimize
-- edemezsin.
--
-- 🔴 GÜVENLİK TASARIMI — anon YAZAR, OKUYAMAZ:
-- Liste e-posta adresi taşıyor; `anon` rolüne select vermek onu tek
-- `curl` ile dışarı verirdi. 187'de Priority Pass kural tablosunda
-- aynı kararı vermiştik: anon yalnız KATALOĞU görür, değerli veriyi
-- görmez. Burada anon yalnız INSERT eder.
-- ============================================================

create table if not exists waitlist (
  id         uuid primary key default uuid_generate_v4(),
  email      text not null,
  role       text not null,          -- 'host' | 'misafir'
  source     text default 'site',    -- hangi kanal: site | ig | linkedin | ...
  consent    boolean not null default false,
  note       text,
  invited_at timestamptz,            -- davet gönderildiğinde dolar
  created_at timestamptz not null default now()
);

alter table waitlist drop constraint if exists wl_email_chk;
alter table waitlist add constraint wl_email_chk
  check (position('@' in email) > 1 and length(email) between 5 and 254);

alter table waitlist drop constraint if exists wl_role_chk;
alter table waitlist add constraint wl_role_chk
  check (role in ('host', 'misafir'));

-- 🔴 KVKK: onay olmadan kayıt YAZILAMAZ. Kısıtı politikaya bırakmıyoruz;
-- tablo düzeyinde de zorunlu — politika bir gün gevşetilirse veri
-- yine korunur. İki katman (159'un dersi: RLS ve GRANT ayrı şeyler).
alter table waitlist drop constraint if exists wl_consent_chk;
alter table waitlist add constraint wl_consent_chk check (consent = true);

-- Aynı e-posta iki kez yazılmasın; büyük/küçük harf fark etmez
create unique index if not exists uq_waitlist_email on waitlist (lower(btrim(email)));
create index if not exists idx_waitlist_created on waitlist (created_at desc);

alter table waitlist enable row level security;

-- anon: YALNIZ insert, yalnız onaylıysa
revoke all on waitlist from anon;
grant insert on waitlist to anon;
drop policy if exists wl_anon_insert on waitlist;
create policy wl_anon_insert on waitlist
  for insert to anon with check (consent = true);

-- authenticated de yazabilsin (app içinden davet), okuyamasın
grant insert on waitlist to authenticated;
drop policy if exists wl_auth_insert on waitlist;
create policy wl_auth_insert on waitlist
  for insert to authenticated with check (consent = true);

-- 🔴 OKUMA YOK. BO servis anahtarıyla okur (RLS'i atlar); uygulama
-- rollerinden hiçbiri listeyi göremez.

comment on table waitlist is
  '194: beta bekleme listesi. anon YAZAR, OKUYAMAZ — e-posta listesi '
  'tek curl ile dışarı verilmemeli. BO servis anahtarıyla okur.';


-- ---- Hız sınırı: tek bir betik listeyi şişirmesin ----
-- 🔴 TETİKLEYİCİ ASLA THROW ETMEMELİ kuralının İSTİSNASI burada
-- bilinçli: bu bir YAZMA KAPISI, bir yan etki değil. Kayıt düşerse
-- kullanıcı "biraz sonra tekrar dene" görür; kayıt yazılırsa liste
-- çöple dolar. 033'ün kredi tetikleyicisi yan etkiydi ve yutuluyordu;
-- bu değil.
create or replace function public.trg_waitlist_rate()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_n int;
begin
  select count(*) into v_n from waitlist
   where created_at > now() - interval '1 minute';
  if v_n > 20 then
    raise exception 'rate_limited_waitlist'
      using hint = 'Dakikada 20 kayıt sınırı aşıldı, biraz sonra tekrar dene.';
  end if;
  return new;
end $$;

drop trigger if exists trg_waitlist_rate on waitlist;
create trigger trg_waitlist_rate before insert on waitlist
  for each row execute function public.trg_waitlist_rate();


-- ---- BO için özet ----
create or replace function public.waitlist_summary()
returns table (toplam int, host int, misafir int, bugun int, davet_bekleyen int)
language sql stable security definer set search_path = public as $$
  select count(*)::int,
         count(*) filter (where role = 'host')::int,
         count(*) filter (where role = 'misafir')::int,
         count(*) filter (where created_at::date = current_date)::int,
         count(*) filter (where invited_at is null)::int
    from waitlist
$$;
grant execute on function public.waitlist_summary() to authenticated;


-- ============================================================
-- BEKÇİLER
-- ============================================================

-- 1) anon GERÇEKTEN yazabiliyor mu (grant + politika birlikte)
do $$
declare v_ok boolean := false;
begin
  set local role anon;
  begin
    insert into waitlist (email, role, consent, source)
    values ('194-bekci@test.local', 'host', true, 'bekci');
    v_ok := true;
  exception when others then
    v_ok := false;
  end;
  reset role;
  delete from waitlist where source = 'bekci';
  if not v_ok then
    raise exception '194: anon bekleme listesine YAZAMIYOR — form calismaz';
  end if;
  raise notice '194: anon yazabiliyor';
exception when insufficient_privilege then
  reset role;
  raise notice '194: anon rolu bu ortamda yok (yerel harness) — atlandi';
end $$;

-- 2) anon OKUYAMAMALI — e-posta listesi sizmamali
do $$
declare v_n int; v_leak boolean := false;
begin
  insert into waitlist (email, role, consent, source)
  values ('194-sizinti@test.local', 'misafir', true, 'bekci')
  on conflict do nothing;

  set local role anon;
  begin
    select count(*) into v_n from waitlist;
    v_leak := (v_n > 0);
  exception when others then
    v_leak := false;      -- okuyamadi: DOGRU davranis
  end;
  reset role;
  delete from waitlist where source = 'bekci';

  if v_leak then
    raise exception '194: anon bekleme listesini OKUYABILIYOR — e-posta sizintisi';
  end if;
  raise notice '194: anon listeyi okuyamiyor';
exception when insufficient_privilege then
  reset role;
  delete from waitlist where source = 'bekci';
  raise notice '194: anon rolu yok — sizinti bekcisi atlandi';
end $$;

-- 3) Onaysız kayıt yazılamamalı (KVKK)
do $$
declare v_bloklandi boolean := false;
begin
  begin
    insert into waitlist (email, role, consent, source)
    values ('194-onaysiz@test.local', 'host', false, 'bekci');
  exception when others then v_bloklandi := true;
  end;
  delete from waitlist where source = 'bekci';
  if not v_bloklandi then
    raise exception '194: ONAYSIZ kayit yazilabiliyor — KVKK kapisi yok';
  end if;
  raise notice '194: onaysiz kayit engelleniyor';
end $$;

-- 4) Aynı e-posta iki kez yazılamamalı
do $$
declare v_bloklandi boolean := false;
begin
  insert into waitlist (email, role, consent, source)
  values ('194-tek@test.local', 'host', true, 'bekci');
  begin
    insert into waitlist (email, role, consent, source)
    values ('194-TEK@test.local', 'misafir', true, 'bekci');   -- buyuk harf
  exception when unique_violation then v_bloklandi := true;
  end;
  delete from waitlist where source = 'bekci';
  if not v_bloklandi then
    raise exception '194: ayni e-posta iki kez yazilabiliyor';
  end if;
  raise notice '194: mukerrer e-posta engelleniyor (buyuk/kucuk harf dahil)';
end $$;

select '194 OK - bekleme listesi acildi (anon yazar, okuyamaz)' as sonuc;
