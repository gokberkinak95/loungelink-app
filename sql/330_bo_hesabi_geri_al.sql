-- ============================================================================
-- 330 · BO "HESABI GERİ AL" — silme talebinin 14 günü içinde  (4 Ekim 2026)
--
-- Gökberk: "14 gün içinde geri alma BO'da elle" → düğme olsun.
-- 329 ile: "Hesabımı sil" → users.deleted_at + auth giriş kilidi (banned_until +15 gün);
-- 14. gün gece otomatik anonimleştirme. Bu fonksiyon o aralıkta hesabı GERİ AÇAR:
--   · users.deleted_at temizlenir · auth giriş kilidi kalkar (deleted_at varsa o da)
--   · profil keşfe döner (personel değilse) · BO silme talebi 'rejected' + not
-- AÇILMAYANLAR (bilerek): silme anında kapanan istekler/buluşmalar/bağlantılar ve
-- kapatılan ilanlar geri gelmez — karşı tarafa iade ve bildirim çoktan yapıldı;
-- geri açmak onları habersiz yeniden bağlamak olur. Kullanıcı yeniden başlatır.
-- KAPILAR: anonimleştirilmiş hesap geri alınamaz (veri yok) · YASAKLI hesap bu
-- yoldan açılmaz (önce yasak BO'dan kaldırılır).
-- Yalnız service_role (BO sbAdmin). Tekrar koşulabilir.
-- ============================================================================

create or replace function public.admin_hesabi_geri_al(p_user_id uuid, p_admin text, p_reason text default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare v_u users%rowtype;
begin
  select * into v_u from users where id = p_user_id;
  if not found then raise exception 'user_not_found'; end if;
  if v_u.anonymized_at is not null then raise exception 'zaten_anonimlestirildi'; end if;
  if v_u.deleted_at is null then raise exception 'hesap_silinmemis'; end if;
  if v_u.banned_at is not null then raise exception 'yasakli_hesap_once_yasagi_kaldir'; end if;

  update users set deleted_at = null where id = p_user_id;
  update profiles set show_on_discovery = true
   where user_id = p_user_id and not coalesce(v_u.is_staff, false);

  update auth.users set banned_until = null where id = p_user_id;
  if exists (select 1 from information_schema.columns
              where table_schema = 'auth' and table_name = 'users' and column_name = 'deleted_at') then
    execute 'update auth.users set deleted_at = null where id = $1' using p_user_id;
  end if;

  update deletion_requests
     set status = 'rejected', handled_at = now(),
         resolution = left('Kullanıcı talebiyle geri alındı (' || coalesce(p_admin, 'BO') || ')'
                           || coalesce(' · ' || nullif(btrim(p_reason), ''), ''), 500)
   where matched_user_id = p_user_id and status in ('pending', 'verified');

  return jsonb_build_object('ok', true,
    'not', 'Silme anında kapanan istekler, buluşmalar, bağlantılar ve ilanlar geri açılmadı.');
end $function$;

revoke execute on function public.admin_hesabi_geri_al(uuid, text, text) from public, anon, authenticated;
grant execute on function public.admin_hesabi_geri_al(uuid, text, text) to service_role;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'geri al fonksiyonu yalniz BO' as kontrol,
       has_function_privilege('service_role', 'public.admin_hesabi_geri_al(uuid,text,text)', 'execute')
   and not has_function_privilege('authenticated', 'public.admin_hesabi_geri_al(uuid,text,text)', 'execute') as tamam;
-- Beklenen: tamam = true.
