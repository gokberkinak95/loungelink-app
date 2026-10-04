-- ============================================================================
-- 326 · KİŞİ ARAMA: ADAY SINIRI  (4 Ekim 2026)
--
-- ÖLÇÜM (ll_yuk · 50 bin üye): geniş eşleşen aramada kisi_ara 3,2 sn (319 sonrası);
-- süre, ismi eşleşen HER profil için koşan profil_gorunur_mu'daydı.
-- DÜZELTME: ucuz süzgeçlerden geçen ilk 200 aday (aynı sıralama) → pahalı karar
-- yalnız onlarda. ÖNKOŞUL: 319 + 324. Gövde CANLI tanımın üstüne. Tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.kisi_ara(p_q text)
 RETURNS TABLE(user_id uuid, ad text, meslek text, foto text, iliski text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v319_staff boolean; v319_test_gorur boolean;
  v_uid uuid := auth.uid(); v_q text; v_female boolean; v_safe boolean; v_phone_ok boolean;
begin
  -- 319 · is_visible() İLE EŞ — izleyici tarafı BİR KEZ (bkz. 317 · discover_availabilities_base).
  -- Satır başına is_visible → test_hesabi_gizli_mi çağrısı (SECURITY DEFINER + SET, satır içine
  -- alınamaz) ölçek dünyasında discover_people'ı 15,5 sn'ye çıkarıyordu. is_visible DEĞİŞİRSE BURASI DA.
  select coalesce(x.is_staff, false), public.seed_test_hesabi(x.email)
    into v319_staff, v319_test_gorur from users x where x.id = auth.uid();
  v319_staff := coalesce(v319_staff, false);
  v319_test_gorur := coalesce(v319_test_gorur, false) or v319_staff
    or not coalesce((select f.enabled from feature_flags f where f.key = 'test_hesaplarini_gizle'), true)
    or exists (select 1 from test_gorunurlugu g where g.user_id = auth.uid());
  if v_uid is null then raise exception 'not_authenticated'; end if;
  v_q := btrim(coalesce(p_q, ''));
  if char_length(v_q) < 2 then return; end if;
  v_q := replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_');

  select (u.gender = 'female'), coalesce(pr.women_safety_mode, false)
    into v_female, v_safe
    from users u left join profiles pr on pr.user_id = u.id where u.id = v_uid;
  select coalesce(phone_verified, false) into v_phone_ok from verifications where verifications.user_id = v_uid;

  return query
  -- 326 · ADAY SINIRI. Eskiden profil_gorunur_mu (her biri 3-4 sorgu) ismi eşleşen HER
  -- profil için koşuyordu: geniş aramada (ölçek: 50 bin eşleşme) 19 sn → 3,2 sn. Ucuz
  -- süzgeçlerden geçen ilk 200 aday (AYNI sıralama) alınır, pahalı karar yalnız onlarda.
  -- Sonuç eskisiyle aynıdır; yalnız ilk 200 adayın 180'inden fazlası gizliyse daha az
  -- sonuç döner (kullanıcı aramasını daraltır).
  with aday as (
    select p.user_id, p.name, p.profession, p.photo_url, p.photo_connections_only,
           (p.name ilike v_q || '%') as bas
      from profiles p
      join users hu on hu.id = p.user_id
     where p.user_id <> v_uid
       and hu.deleted_at is null and hu.banned_at is null
       and (p.name ilike v_q || '%' or p.name ilike '% ' || v_q || '%')   -- kelime başı
       and coalesce(p.show_on_discovery, true)
       and (/* 319 · is_visible ile eş */ (v319_test_gorur or not public.seed_test_hesabi(hu.email))
           and not coalesce(hu.shadow_limited and (hu.restricted_until is null or hu.restricted_until > now()), false)
           and (not coalesce(hu.is_staff, false) or v319_staff))
       and (not (coalesce(v_female, false) and coalesce(v_safe, false)) or hu.gender = 'female')
       and (not coalesce(p.women_safety_mode, false)
            or (coalesce(v_female, false) and coalesce(v_phone_ok, false))
            or exists (select 1 from connection_requests c9 where c9.from_id = p.user_id and c9.to_id = v_uid))
     order by (p.name ilike v_q || '%') desc, p.name
     limit 200
  )
  select a.user_id, public.kisa_ad(a.user_id),
         nullif(btrim(coalesce(a.profession, '')), ''),
         case when a.photo_url is not null and not coalesce(a.photo_connections_only, false) then a.photo_url end,
         coalesce((select c.status::text from connection_requests c
                    where ((c.from_id = v_uid and c.to_id = a.user_id) or (c.from_id = a.user_id and c.to_id = v_uid))
                      and coalesce(c.intent, '') <> 'kural_sorusu'
                    order by (c.status::text = 'accepted') desc, c.created_at desc limit 1), 'none')
    from aday a
   where public.profil_gorunur_mu(a.user_id)
     and not public.is_blocked_pair(v_uid, a.user_id)
   order by a.bas desc, a.name
   limit 20;
end $function$;

select 'kisi_ara aday siniri' as kontrol,
       position('326 · ADAY SINIRI' in pg_get_functiondef('public.kisi_ara(text)'::regprocedure)) > 0 as tamam;
-- Beklenen: tamam = true.
