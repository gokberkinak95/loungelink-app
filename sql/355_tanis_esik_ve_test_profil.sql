-- ============================================================================
-- 355 · TANIŞ BOŞ GELİYORDU: "GÜVENİLİR ÜYE" EŞİĞİ 1 PUANLA KAÇIYORDU  (13 Kasım 2026)
--
-- BULGU (Gökberk, canlı 1.0.1, kurucu hesap): Tanış → Tümü boş; Keşfet'teki bir
-- hostun profili adsız açılıyor ("adlı kişiyle bağlantı kurunca…", puan 45 varsayılanı).
--
-- KÖK: profiles.profile_visibility varsayılanı 'Trusted+' (001). Trusted+ profili
-- görmek için bakanın güven puanı >= beta_settings.profil_trusted_esik olmalı.
--   · 335 eşiği 25 yaptı, gerekçesi: "e-posta görmez, e-posta + telefon (26) görür".
--   · 345 puanları değiştirdi: e-posta 10 + telefon 14 = 24. Eşik yeniden hesaplanmadı.
--   → e-posta + telefonu doğrulanmış (fotoğrafsız, mesleksiz) her kullanıcı 1 puanla
--     eşiğin altında: Tanış'ta Trusted+ (yani neredeyse herkes) görünmüyor, profiller
--     adsız açılıyor. Kurucu hesap dahil.
--
-- DÜZELTME:
--   §1 eşik 24 → 335'in niyeti geri gelir (e-posta 10 görmez, e-posta+telefon 24 görür).
--      Tanış (discover_people_prebfilter, 327) ve profil (profil_gorunur_mu) aynı ayarı okur.
--   §2 profil_gorunur_mu: test hesapları gerçek kullanıcıya profil olarak da kapalı
--      (Keşfet/Tanış/arama zaten gizliyordu; profil satırı kimliği bilen API çağrısına açıktı).
--   §3 vitrin hostlarının profili 'Everyone' (yalnız inceleme hesabı + istisnalar görür; §2).
--   §0/§4 ÖLÇÜM: her gerçek kullanıcının gözünden ÖNCE ve SONRA sayılır.
--
-- KOŞMA: SQL Editor → tamamı → Run. Tekrar koşulabilir. Son tablo sonuçtur.
-- ============================================================================

-- §0 · ölçüm tezgâhı
create schema if not exists tezgah;

create table if not exists tezgah.olcum_355 (
  asama text, tur text, user_id uuid, puan int,
  vitrin_kesfet int, vitrin_tanis int, vitrin_profil int, tanis_kisi int,
  olcum_at timestamptz default now()
);
-- 13 Kasım: TÜM test hesapları (yalnız vitrin değil) — Keşfet · Tanış · profil · Radar
alter table tezgah.olcum_355 add column if not exists test_kesfet int;
alter table tezgah.olcum_355 add column if not exists test_tanis int;
alter table tezgah.olcum_355 add column if not exists test_profil int;
alter table tezgah.olcum_355 add column if not exists test_radar int;
-- inceleme@loungelink.co test kalıbına uymuyor (gerçek e-posta) → ayrıca ölçülür
alter table tezgah.olcum_355 add column if not exists inceleme_goren int;

create or replace function tezgah.olc_355(p_asama text)
returns int language plpgsql set search_path = public as $o355$
declare
  r record; n int := 0;
  v_k int; v_t int; v_p int; v_n int; w_k int; w_t int; w_p int; w_r int;
  T uuid[] := array(select u.id from users u where public.seed_test_hesabi(u.email));
  v_inc uuid := (select u.id from users u where lower(u.email) = 'inceleme@loungelink.co');
  w_i int;
  V uuid[] := array['a354a354-0000-4000-8000-000000000001'::uuid, 'a354a354-0000-4000-8000-000000000002'::uuid];
begin
  delete from tezgah.olcum_355 where asama = p_asama;
  for r in
    select u.id, u.email,
           case when exists (select 1 from test_gorunurlugu g where g.user_id = u.id) then 'istisna' else 'gercek' end as tur,
           (select ts.score from trust_scores ts where ts.user_id = u.id) as puan
      from users u
     where not public.seed_test_hesabi(u.email)
       and not coalesce(u.is_staff, false)
       and u.deleted_at is null and u.banned_at is null
  loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', r.id::text, true);
    begin
      select count(*) filter (where d.host_id = any (V)), count(*) filter (where d.host_id = any (T))
        into v_k, w_k from public.discover_availabilities(null, null, null, null) d;
    exception when others then v_k := -1; w_k := -1; end;
    begin
      select count(*) filter (where p.user_id = any (V)), count(*) filter (where p.user_id = any (T)), count(*)
        into v_t, w_t, v_n from public.discover_people(null, null) p;
    exception when others then v_t := -1; w_t := -1; v_n := -1; end;
    begin
      select count(*) into w_r from public.lounge_radar_people() x where x.user_id = any (T);
    exception when others then w_r := -1; end;
    select count(*) into v_p from unnest(V) x where public.profil_gorunur_mu(x);
    select count(*) into w_p from unnest(T) x where public.profil_gorunur_mu(x);
    w_i := 0;
    if v_inc is not null and r.id <> v_inc then
      begin
        select (select count(*) from public.discover_people(null, null) p where p.user_id = v_inc)
             + (select count(*) from public.lounge_radar_people() x where x.user_id = v_inc)
             + (case when public.profil_gorunur_mu(v_inc) then 1 else 0 end)
          into w_i;
      exception when others then w_i := -1; end;
    end if;
    insert into tezgah.olcum_355 (asama, tur, user_id, puan, vitrin_kesfet, vitrin_tanis, vitrin_profil, tanis_kisi,
                                  test_kesfet, test_tanis, test_profil, test_radar, inceleme_goren)
    values (p_asama, r.tur, r.id, r.puan, v_k, v_t, v_p, v_n, w_k, w_t, w_p, w_r, w_i);
    n := n + 1;
  end loop;
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  return n;
end $o355$;

select tezgah.olc_355('1_once') as olculen_kullanici;

-- §1 · eşik: e-posta + telefon (10 + 14 = 24) güvenilir üyedir
insert into beta_settings (key, value) values ('profil_trusted_esik', to_jsonb(24))
  on conflict (key) do update set value = to_jsonb(24);

-- §2 · profil: test hesabı gerçek kullanıcıya kapalı
create or replace function public.profil_gorunur_mu(p_target uuid)
returns boolean
language plpgsql stable security definer set search_path = public as $pg355$
declare v_ben uuid := auth.uid(); v_gor text; v_esik int; v_puan int;
begin
  if v_ben is null then return false; end if;
  if p_target = v_ben then return true; end if;

  -- 355 · test hesapları (vitrin dahil) gerçek kullanıcıya profil olarak da kapalı.
  -- Keşfet/Tanış/arama zaten gizliyordu; profil satırı kimliği bilen API çağrısına açıktı.
  if public.test_hesabi_gizli_mi(p_target) then return false; end if;

  -- Aramızda gerçek bir ilişki varsa görünürlük tercihi devreye girmez:
  -- bir isteği kabul etmiş ya da göndermiş kişi zaten karşılaşmıştır.
  if exists (select 1 from connection_requests c
              where ((c.from_id = v_ben and c.to_id = p_target)
                  or (c.to_id = v_ben and c.from_id = p_target))
                and c.status in ('pending','accepted'))
     or exists (select 1 from requests r
                 where (r.guest_id = v_ben and r.host_id = p_target)
                    or (r.host_id = v_ben and r.guest_id = p_target))
  then
    return true;
  end if;

  select coalesce(profile_visibility::text, 'Everyone') into v_gor
    from profiles where user_id = p_target;
  if v_gor is null then return false; end if;
  if v_gor = 'Everyone' then return true; end if;
  if v_gor = 'Connections' then return false; end if;

  -- 'Trusted+' → bakanın güven puanı eşiği geçmeli.
  v_esik := coalesce((select (value #>> '{}')::int from beta_settings
                       where key = 'profil_trusted_esik'), 40);
  select score into v_puan from trust_scores where user_id = v_ben;
  return coalesce(v_puan, 0) >= v_esik;
end $pg355$;

grant execute on function public.profil_gorunur_mu(uuid) to authenticated;
grant execute on function public.profil_gorunur_mu(uuid) to service_role;


-- §3 · vitrin hostlarının profili açık (yalnız inceleme hesabı ve istisnalar görebilir — §2)
update profiles set profile_visibility = 'Everyone'
 where user_id in ('a354a354-0000-4000-8000-000000000001', 'a354a354-0000-4000-8000-000000000002');

-- §3b · mağaza inceleme hesabı gerçek kullanıcının hiçbir listesinde görünmesin.
--   Tanış/arama show_on_discovery'ye, Radar location_sharing'e, profil 'Connections'a uyar.
--   İnceleme hesabının kendi akışı (Keşfet, vitrin ilanına istek) etkilenmez; isteği alan
--   vitrin host aradaki istek sayesinde profili görür (profil_gorunur_mu ilişki dalı).
update profiles
   set show_on_discovery = false, location_sharing = false, profile_visibility = 'Connections'
 where user_id in (select u.id from users u where lower(u.email) = 'inceleme@loungelink.co');

-- §4 · sonra
select tezgah.olc_355('2_sonra') as olculen_kullanici;

-- §5 · SONUÇ (beklenen: 'gercek' satırlarında vitrin_* ve herhangi_test_hesabi_goren = 0 ·
--      'sonra' satırında inceleme_hesabini_goren = 0 · tanis_bos_kullanici 'sonra'da düşer · olcum_hatasi 0. 'istisna' = test_gorunurlugu listesi, görmesi normal)
select asama, tur,
       count(*)                                         as kullanici,
       sum(greatest(vitrin_kesfet, 0))                  as vitrin_kesfet_goren,
       sum(greatest(vitrin_tanis, 0))                   as vitrin_tanis_goren,
       sum(vitrin_profil)                               as vitrin_profil_goren,
       sum(greatest(test_kesfet, 0) + greatest(test_tanis, 0) + test_profil + greatest(test_radar, 0)) as herhangi_test_hesabi_goren,
       count(*) filter (where tanis_kisi = 0)           as tanis_bos_kullanici,
       round(avg(nullif(tanis_kisi, -1)), 1)            as tanis_ort_kisi,
       sum(greatest(inceleme_goren, 0))                 as inceleme_hesabini_goren,
       count(*) filter (where vitrin_kesfet = -1 or tanis_kisi = -1 or test_radar = -1 or inceleme_goren = -1) as olcum_hatasi,
       count(*) filter (where coalesce(puan, 0) < 24)   as puan_24_alti,
       count(*) filter (where puan = 24)                as puan_tam_24
  from tezgah.olcum_355
 group by asama, tur
 order by tur, asama;

-- GERİ ALMA (gerekirse): eşik 25
--   update beta_settings set value = to_jsonb(25) where key = 'profil_trusted_esik';
