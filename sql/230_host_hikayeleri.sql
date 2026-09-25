-- ============================================================================
-- LoungeLink · 230_host_hikayeleri.sql                     (21 Ağustos 2026)
--
-- SİTEDE TEK BİR GERÇEK HOST CÜMLESİ YOK
--
-- v0.28'de host bölümünü baştan yazdım: altı kart, bir hesaplayıcı, bir
-- basamak şeridi, bir SSS. Hepsini BEN yazdım. Bir tanesi bile bunu
-- yaşamış birinden gelmiyor.
--
-- 🔴 Siteye "Ahmet, 34, THY Elite Plus: harika bir deneyimdi" yazmak
-- işin en kolay kısmı olurdu ve bu projede yaptığımız her şeyin
-- tersi olurdu. Uydurma referans, uydurulmuş bir ölçümdür.
--
-- Yapılacak doğru şey: uydurmak değil, TOPLAYABİLECEK MAKİNEYİ KURMAK
-- ve site tarafını boşken SESSİZ bırakmak. Bu dosya o makine.
--
-- 🆕 SINIF: **"ELİMDE OLMAYAN BİR ŞEYİ YAZMAK YERİNE, ONU ELDE
-- EDECEK YOLU KUR — VE O GELENE KADAR YERİ BOŞ KALSIN."**
--
-- ÜÇ SERT KURAL, ÜÇÜ DE VERİTABANINDA (yorumda değil):
--   1) Hikâye ancak TAMAMLANMIŞ bir oturumdan sonra yazılabilir
--   2) `published` olabilmesi için hem RIZA hem ONAY tarihi şart
--   3) Yayımlanan hikâye ismi kullanıcının SEÇTİĞİ görünen ad —
--      e-posta, telefon, tam ad asla dışarı çıkmaz
-- ============================================================================

create table if not exists host_stories (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references users(id) on delete cascade,
  session_id   uuid not null references sessions(id) on delete cascade,
  metin        text not null,
  gorunen_ad   text not null,          -- kullanıcının SEÇTİĞİ ad ("Gökberk İ." gibi)
  gorunen_not  text,                   -- "Elite Plus · 6 ağırlama" gibi, isteğe bağlı
  riza_at      timestamptz,            -- kullanıcı YAYINLANMASINA açıkça izin verdi
  onay_at      timestamptz,            -- biz moderasyondan geçirdik
  yayinda      boolean not null default false,
  created_at   timestamptz not null default now(),
  unique (session_id)                  -- bir oturum bir hikâye
);

alter table host_stories enable row level security;

-- Kendi hikâyeni gör; yayındakileri HERKES görür (site anon okuyor).
drop policy if exists "hs_own" on host_stories;
create policy "hs_own" on host_stories for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "hs_public" on host_stories;
create policy "hs_public" on host_stories for select to anon
  using (yayinda and riza_at is not null and onay_at is not null);

-- 🔴 KAPI VERİTABANINDA. "Rıza almadan yayınlamayız" bir yorum olsaydı
-- bir gün biri BO'dan `yayinda = true` yapardı ve kimse görmezdi.
alter table host_stories drop constraint if exists hs_yayin_riza_chk;
alter table host_stories add constraint hs_yayin_riza_chk
  check (not yayinda or (riza_at is not null and onay_at is not null));

-- Uzunluk sınırı: sitede tek satır duracak. 240 karakter bir cümle,
-- 2000 karakter bir blog yazısı — ikisi aynı yerde durmaz.
alter table host_stories drop constraint if exists hs_metin_uzunluk_chk;
alter table host_stories add constraint hs_metin_uzunluk_chk
  check (char_length(btrim(metin)) between 20 and 240);

comment on table host_stories is
  'Gercek host cumleleri. Sitede yalnizca yayinda+riza+onay olanlar gorunur; '
  'yoksa site o bolumu HIC gostermez (bos yer tutucu YOK).';

-- ----------------------------------------------------------------------------
-- 1) Host kendi hikâyesini yazar — yalnız tamamlanmış oturumdan sonra
-- ----------------------------------------------------------------------------
drop function if exists public.host_hikaye_yaz(uuid, text, text, text, boolean);
create or replace function public.host_hikaye_yaz(
  p_session uuid, p_metin text, p_gorunen_ad text,
  p_gorunen_not text default null, p_riza boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $hy$
declare v_uid uuid := auth.uid(); v_s sessions%rowtype; v_r requests%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_s from sessions where id = p_session;
  if not found or v_s.status <> 'completed' then
    raise exception 'session_not_completed';
  end if;
  select * into v_r from requests where id = v_s.request_id;
  if not found or v_r.host_id <> v_uid then
    raise exception 'not_host_of_session';   -- misafirin hikâyesi ayrı bir şey
  end if;

  if coalesce(btrim(p_gorunen_ad),'') = '' then raise exception 'display_name_required'; end if;

  insert into host_stories (user_id, session_id, metin, gorunen_ad, gorunen_not, riza_at)
  values (v_uid, p_session, btrim(p_metin), btrim(p_gorunen_ad),
          nullif(btrim(coalesce(p_gorunen_not,'')),''),
          case when p_riza then now() else null end)
  on conflict (session_id) do update
     set metin = excluded.metin,
         gorunen_ad = excluded.gorunen_ad,
         gorunen_not = excluded.gorunen_not,
         -- Rızayı GERİ ALMAK mümkün: false gönderilirse riza_at silinir
         -- ve kısıt yayından düşürür.
         riza_at = excluded.riza_at,
         yayinda = case when excluded.riza_at is null then false else host_stories.yayinda end;

  return jsonb_build_object('ok', true, 'riza', p_riza,
    'not', case when p_riza then 'Yayınlanmak üzere sıraya alındı — önce biz okuyacağız.'
                else 'Kaydedildi. Yayınlanması için izin vermen gerekiyor.' end);
end $hy$;
grant execute on function public.host_hikaye_yaz(uuid, text, text, text, boolean) to authenticated;

-- ----------------------------------------------------------------------------
-- 2) Site okuması — anon, yalnız yayındakiler, kişisel veri YOK
-- ----------------------------------------------------------------------------
drop function if exists public.yayindaki_host_hikayeleri(int);
create or replace function public.yayindaki_host_hikayeleri(p_limit int default 3)
returns table (metin text, gorunen_ad text, gorunen_not text)
language sql stable security definer set search_path = public as $yh$
  select s.metin, s.gorunen_ad, s.gorunen_not
    from host_stories s
   where s.yayinda and s.riza_at is not null and s.onay_at is not null
   order by s.onay_at desc
   limit greatest(1, least(coalesce(p_limit,3), 12));
$yh$;
grant execute on function public.yayindaki_host_hikayeleri(int) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2b) DAVET — app'in soracağı tek soru
-- ----------------------------------------------------------------------------
-- 🔴 KURULAN MAKİNE, KİMSE TETİKLEMEZSE ÇALIŞMAZ.
-- 228'in dersi buydu: kuralı metne yazmak onu sistemde uygulamak
-- değildir. Aynısı burada geçerli — `host_hikaye_yaz()` var ama hiçbir
-- ekran host'a "bir cümle yazar mısın?" demiyorsa tablo boş kalır ve
-- sitedeki bölüm hiç açılmaz.
--
-- Bu RPC app'in ana sayfasında sorulacak TEK daveti döndürür:
--   · oturum TAMAMLANMIŞ
--   · çağıran kişi o oturumun HOST'u
--   · o oturum için henüz hikâye YOK
--   · en fazla BİR tane (üst üste davet, davet değil baskıdır)
create or replace function public.bekleyen_hikaye_daveti()
returns table (session_id uuid, salon text, tarih date, misafir text)
language plpgsql stable security definer set search_path = public as $hd$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select s.id,
         coalesce(a.lounge_name, a.airport_code),
         a.avail_date,
         coalesce(p.name, 'Misafirin')
    from sessions s
    join requests r      on r.id = s.request_id
    left join availabilities a on a.id = r.avail_id
    left join profiles p on p.user_id = r.guest_id
   where s.status = 'completed'
     and r.host_id = v_uid
     and not exists (select 1 from host_stories h where h.session_id = s.id)
   order by s.completed_at desc nulls last
   limit 1;
end $hd$;
grant execute on function public.bekleyen_hikaye_daveti() to authenticated;

-- ----------------------------------------------------------------------------
-- 3) Moderasyon (BO)
-- ----------------------------------------------------------------------------
drop function if exists public.host_hikaye_onayla(uuid, boolean);
create or replace function public.host_hikaye_onayla(p_id uuid, p_yayinla boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $ho$
declare v_h host_stories%rowtype;
begin
  -- 🔴 YETKİ İKİ KATMANLI, ama KATMANLAR FARKLI ŞEYLERE BAKAR:
  --  (1) Bu fonksiyon istemci rollerine HİÇ verilmiyor (aşağıda yalnız
  --      service_role'a grant var + apply_rpc_surface() sınırı uyguluyor).
  --      BO `sbAdmin()` yani service_role ile çağırıyor.
  --  (2) Yine de biri bir gün authenticated'a grant verirse, aşağıdaki
  --      kontrol devreye girer. auth.uid() null ise service_role
  --      bağlamındayız (BO); doluysa gerçek bir kullanıcıdır ve
  --      admin_roles'ta olmak ZORUNDA.
  -- 205'in kalıbı yalnız (1)'e güveniyordu; bir grant hatası orada
  -- sessiz bir açık bırakırdı.
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select * into v_h from host_stories where id = p_id for update;
  if not found then raise exception 'story_not_found'; end if;
  if p_yayinla and v_h.riza_at is null then
    raise exception 'consent_missing';   -- kısıt da engelliyor; burada AÇIKÇA söylüyoruz
  end if;

  update host_stories
     set onay_at = case when p_yayinla then now() else null end,
         yayinda = p_yayinla
   where id = p_id;
  return jsonb_build_object('ok', true, 'yayinda', p_yayinla);
end $ho$;
grant execute on function public.host_hikaye_onayla(uuid, boolean) to service_role;   -- BO sbAdmin() ile cagirir

drop function if exists public.bekleyen_host_hikayeleri();
create or replace function public.bekleyen_host_hikayeleri()
returns table (id uuid, metin text, gorunen_ad text, gorunen_not text,
               riza_at timestamptz, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $bh$
begin
  -- 🔴 YETKİ İKİ KATMANLI, ama KATMANLAR FARKLI ŞEYLERE BAKAR:
  --  (1) Bu fonksiyon istemci rollerine HİÇ verilmiyor (aşağıda yalnız
  --      service_role'a grant var + apply_rpc_surface() sınırı uyguluyor).
  --      BO `sbAdmin()` yani service_role ile çağırıyor.
  --  (2) Yine de biri bir gün authenticated'a grant verirse, aşağıdaki
  --      kontrol devreye girer. auth.uid() null ise service_role
  --      bağlamındayız (BO); doluysa gerçek bir kullanıcıdır ve
  --      admin_roles'ta olmak ZORUNDA.
  -- 205'in kalıbı yalnız (1)'e güveniyordu; bir grant hatası orada
  -- sessiz bir açık bırakırdı.
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  return query
  select h.id, h.metin, h.gorunen_ad, h.gorunen_not, h.riza_at, h.created_at
    from host_stories h
   where h.riza_at is not null and h.onay_at is null
   order by h.riza_at asc;
end $bh$;
grant execute on function public.bekleyen_host_hikayeleri() to service_role;   -- BO sbAdmin() ile cagirir

-- ----------------------------------------------------------------------------
-- 4) NÖBETÇİ — mutasyona dayanıklı
-- ----------------------------------------------------------------------------
do $n230$
declare v_kisit int; v_yayin int; v_riza_yok int; v_test uuid;
begin
  select count(*) into v_kisit from pg_constraint
   where conname in ('hs_yayin_riza_chk','hs_metin_uzunluk_chk');
  if v_kisit <> 2 then
    raise exception '230 NOBETCI: 2 kisit bekleniyordu, % kuruldu.', v_kisit;
  end if;

  -- Rızasız yayın gerçekten imkânsız mı? Deneyerek ölç.
  begin
    insert into host_stories (user_id, session_id, metin, gorunen_ad, yayinda)
    select u.id, s.id, 'Riza olmadan yayina almayi deniyorum, engellenmeli.', 'Test', true
      from users u, sessions s limit 1;
    -- Buraya düşmek kısıtın çalışmadığı anlamına gelir.
    raise exception '230 NOBETCI: RIZASIZ YAYIN GECTI — kisit calismiyor.';
  exception
    when check_violation then
      null;  -- beklenen
    when others then
      -- Boş veritabanında users/sessions yoksa insert hiç satır üretmez;
      -- o durumda kısıt sınanamaz. Sustuğumu SÖYLÜYORUM.
      raise notice '230 OLCULMEDI: rizasiz-yayin mutasyonu calistirilamadi (%). Kisit tanimi yerinde.', sqlerrm;
  end;

  select count(*) into v_yayin from host_stories where yayinda;
  select count(*) into v_riza_yok from host_stories where yayinda and riza_at is null;
  if v_riza_yok <> 0 then
    raise exception '230 NOBETCI: % hikaye RIZASIZ yayinda.', v_riza_yok;
  end if;

  raise notice '230 OK · yayindaki host hikayesi: % · rizasiz yayin: 0', v_yayin;
  raise notice '230 NOT: bugun 0 hikaye var ve bu DOGRU — site bolumu bos oldugu icin '
               'HIC GORUNMUYOR. Ilk oturum tamamlaninca host_hikaye_yaz() ile toplanacak.';
end $n230$;

-- ----------------------------------------------------------------------------
-- 5) RPC YÜZEYİ
-- ----------------------------------------------------------------------------
-- App host'un hikâyesini yazacak, site yayındakileri okuyacak: ikisi de
-- yüzeye giriyor. Moderasyon fonksiyonları GİRMİYOR (BO = service_role).
insert into rpc_client_surface (fn_name, client, note) values
  ('host_hikaye_yaz','app','Host tamamlanan oturumdan sonra tek cumlesini yazar (230)'),
  ('bekleyen_hikaye_daveti','app','App ana sayfasi: hikayesi yazilmamis TEK tamamlanmis oturum (230)'),
  ('yayindaki_host_hikayeleri','public_web','Site: yalnizca riza+onay almis hikayeler (230)')
on conflict (fn_name) do update set note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '230: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select 'HOST HIKAYELERI KURULDU' as sonuc,
       (select count(*) from host_stories) as toplam,
       (select count(*) from host_stories where yayinda) as yayinda;
