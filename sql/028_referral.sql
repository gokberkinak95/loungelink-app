-- ============================================================
-- LoungeLink · 028_referral.sql — Arkadaş daveti (§19: +500 puan)
-- invites tablosu şemada vardı, kullanılmıyordu. Kod bazlı referans.
-- ============================================================

alter table profiles add column if not exists referral_code text;
alter table profiles add column if not exists referred_by uuid references users(id);
create unique index if not exists profiles_refcode_uniq on profiles (referral_code) where referral_code is not null;

-- Kod üret (LL + 6 karakter)
create or replace function public.my_referral()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_code text; v_invited jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select referral_code into v_code from profiles where user_id = v_uid;
  if v_code is null then
    loop
      v_code := 'LL' || upper(substr(md5(random()::text), 1, 6));
      begin
        update profiles set referral_code = v_code where user_id = v_uid;
        exit;
      exception when unique_violation then null;
      end;
    end loop;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('name', p.name)), '[]'::jsonb)
    into v_invited from profiles p where p.referred_by = v_uid;

  return jsonb_build_object('code', v_code, 'invited', v_invited);
end $$;
grant execute on function public.my_referral() to authenticated;

-- Kod uygula (kayıt sonrası): davet edene +500, edilene +500
create or replace function public.apply_referral(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_ref uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if exists (select 1 from profiles where user_id = v_uid and referred_by is not null) then
    raise exception 'referral_already_used';
  end if;
  select user_id into v_ref from profiles where upper(referral_code) = upper(p_code);
  if v_ref is null then raise exception 'invalid_referral_code'; end if;
  if v_ref = v_uid then raise exception 'self_referral_blocked'; end if;

  update profiles set referred_by = v_ref where user_id = v_uid;
  insert into invites (host_id, guest_id, status, created_at)
  values (v_ref, v_uid, 'accepted', now()) on conflict do nothing;

  insert into points_ledger (user_id, delta, reason) values (v_ref, 500, 'referral_invite');
  insert into points_ledger (user_id, delta, reason) values (v_uid, 500, 'referral_joined');

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_ref, 'system', 'Davetin kabul edildi 🎉', 'Arkadaşın katıldı · +500 puan', 'referral');

  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.apply_referral(text) to authenticated;

select 'REFERRAL OK' as sonuc;
