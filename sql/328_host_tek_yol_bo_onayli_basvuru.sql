-- ============================================================================
-- 328 · HOST OLMANIN TEK YOLU: BO ONAYLI BAŞVURU  (4 Ekim 2026 · Gökberk kararı)
--
-- ÖLÇÜM (uçtan uca test · rol ayrımı): misafirin host olmasının DÖRT yolu vardı:
--   1) kayıtta "host" seçmek → handle_new_user rolü doğrudan host yazıyordu
--   2) sosyal giriş tamamlama ekranı → rolumu_sec('host')
--   3) "Host olsam ne kazanırım?" → "Kartındaki yeri değerlendir" → rolumu_sec('host')
--      ANINDA host (kart beyanından bile önce; ölçüldü: rol=host, başvuru yok)
--   4) Profil → "Kartımda bir kişilik yer var" → apply_for_host → BO onayı
--   + ARKA KAPI: create_availability_base kullanıcıya doğrudan açıktı; kart beyan etmiş
--     bir misafir onunla ilan açıp 055 terfisiyle host olabilirdi (261 kapısı yalnız
--     sarmalayıcıdaydı).
-- KARAR: tek yol 4. Bu dosya:
--   · rolumu_sec('host') onaylı başvuru yoksa 'host_basvurusu_gerekli' (TR+EN app 6.3.4)
--   · handle_new_user: kayıtta host seçen MİSAFİR açılır (niyet meta veride kalır)
--   · create_availability_base: kullanıcıya kapalı (yalnız create_availability çağırır)
-- Var olan host'lara dokunulmaz. Gövdeler CANLI tanımın üstüne. Tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g user_gender; n text; r user_role; v_staff boolean;
begin
  begin g := (new.raw_user_meta_data->>'gender')::user_gender; exception when others then g := null; end;
  begin r := coalesce((new.raw_user_meta_data->>'role')::user_role, 'guest'); exception when others then r := 'guest'; end;
  -- 328 · TEK YOL: host rolü YALNIZ BO onaylı başvuruyla. Kayıtta "host" seçen hesap misafir
  -- açılır; niyet raw_user_meta_data.role'de kalır ve uygulama onu başvuru formuna götürür.
  if r = 'host' then r := 'guest'; end if;
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1));

  -- YENİ (041): BO daveti bu bayrakları zaten gönderiyor
  begin
    v_staff := coalesce((new.raw_user_meta_data->>'is_staff')::boolean, false)
            or coalesce((new.raw_user_meta_data->>'is_partner')::boolean, false);
  exception when others then v_staff := false;
  end;

  insert into public.users (id, email, role, gender, password_hash, is_staff)
  values (new.id, new.email, r, g, 'supabase-auth', v_staff) on conflict (id) do nothing;

  -- staff ise keşifte görünme
  insert into public.profiles (user_id, name, show_on_discovery)
  values (new.id, n, not v_staff) on conflict (user_id) do nothing;

  insert into public.verifications (user_id, email_verified, email_verified_at)
  values (new.id, true, now()) on conflict (user_id) do nothing;
  insert into public.trust_scores (user_id, score, components, badge)
  values (new.id, 10, '{"email":10}'::jsonb, 'New') on conflict (user_id) do nothing;

  -- BETA (033): açılış kredisi — ama ekip hesabına DEĞİL.
  -- Kendi hatasını yutar: kredi verilemezse KAYIT YİNE DE TAMAMLANIR.
  if not v_staff then
    begin
      perform grant_signup_credits(new.id);
    exception when others then
      null;
    end;
  end if;

  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.rolumu_sec(p_role text, p_gender text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid   uuid := auth.uid();
  v_eski  user_role;
  v_yeni  user_role;
  v_kay   text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_role is null or p_role not in ('guest','host') then
    raise exception 'gecersiz_rol';
  end if;

  select role into v_eski from users where id = v_uid;
  v_yeni := p_role::user_role;

  if v_eski = v_yeni then
    -- Cinsiyet beyanı gelmişse yine de yaz; boşa dönüş verme.
    if p_gender is not null then
      update users set gender = p_gender::user_gender where id = v_uid;
    end if;
    return jsonb_build_object('ok', true, 'rol', v_yeni::text, 'degisti', false);
  end if;

  -- 328 · TEK YOL (Gökberk, 4 Ekim): misafir kendini host YAPAMAZ; host rolü BO'nun onayladığı
  -- başvuruyla gelir (review_host_application). Onaylı başvurusu olan biri (ör. geri dönüp
  -- yeniden host olmak isteyen) geçebilir. Host → misafir geçişi serbest.
  if v_yeni = 'host' and not exists (select 1 from host_applications ha
                                      where ha.user_id = v_uid and ha.status = 'approved') then
    raise exception 'host_basvurusu_gerekli';
  end if;

  v_kay := case when v_yeni = 'host' then 'beyan' else 'geri' end;

  update users
     set role = v_yeni,
         role_source = v_kay,
         role_changed_at = now(),
         gender = coalesce(p_gender::user_gender, gender)
   where id = v_uid;

  insert into audit_log (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_uid, 'user.role_change', 'users', v_uid,
          jsonb_build_object('role', v_eski::text),
          jsonb_build_object('role', v_yeni::text, 'source', v_kay));

  return jsonb_build_object('ok', true, 'rol', v_yeni::text, 'degisti', true);
end $function$;

revoke execute on function public.create_availability_base(uuid,text,date,time,time,integer,text,text,text) from public, anon, authenticated;
grant execute on function public.create_availability_base(uuid,text,date,time,time,integer,text,text,text) to service_role;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'rolumu_sec onayli basvuru ister' as kontrol,
       position('host_basvurusu_gerekli' in pg_get_functiondef('public.rolumu_sec(text,text)'::regprocedure)) > 0 as tamam
union all
select 'kayitta host secen misafir acilir',
       position('328 · TEK YOL' in pg_get_functiondef('public.handle_new_user()'::regprocedure)) > 0
union all
select 'create_availability_base kullaniciya kapali',
       not has_function_privilege('authenticated', 'public.create_availability_base(uuid,text,date,time,time,integer,text,text,text)', 'execute');
-- Beklenen: üç satır da tamam = true.
-- Bilgi (yalnız okur): BO onayı OLMADAN host olmuş mevcut hesaplar —
--   select u.email, u.role_source, u.role_changed_at from users u
--    where u.role = 'host' and not exists (select 1 from host_applications h where h.user_id = u.id and h.status = 'approved')
--    order by u.role_changed_at desc nulls last;
