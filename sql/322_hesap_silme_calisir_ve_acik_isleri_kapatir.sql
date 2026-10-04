-- ============================================================================
-- 322 · "HESABIMI SİL" ÇALIŞIR · SİLİNEN / YASAKLANAN HESABIN AÇIK İŞLERİ KAPANIR
--       (4 Ekim 2026)
--
-- 🔴 KRİTİK BULGU (uçtan uca test · Profil › Hesabı sil):
-- delete_my_account() 282'den beri deletion_requests'e status = 'open' yazıyordu;
-- tablonun kısıtı yalnız ('pending','verified','done','rejected') kabul ediyor
-- (084 · BO'nun eylemi ve listesi de bu dört değeri kullanıyor). Sonuç: insert
-- check_violation ile düşüyor, BÜTÜN İŞLEM GERİ ALINIYOR — kullanıcı "Hesabımı sil"e
-- basıyor, "Bir şeyler ters gitti" görüyor, hesabı SİLİNMİYOR ve BO'ya talep de
-- düşmüyor. (Uygulama mağazası kuralı + KVKK: hesap silme çalışmak zorunda.)
-- Ölçüldü: new row for relation "deletion_requests" violates check constraint.
--
-- 🔴 AYNI ZİNCİR · SİLİNEN ya da BO'DA YASAKLANAN kullanıcının açık işleri açık
-- kalıyordu (ölçüldü):
--   · misafir olarak bekleyen/kabul edilmiş istekleri → host'un gelen kutusunda
--     artık var olmayan birinin isteği, kabul edilmişse dolu slot;
--   · host olarak ilanlarına gelen istekler → misafirin kredisi tutulu, KABUL
--     EDİLMİŞ buluşma takvimde duruyor (yasaklanan biriyle buluşma!), kimse haber almıyor;
--   · bağlantıları → karşı tarafın "Bağlantılarım"ında ve ana sayfa şeridinde kalıyor.
-- DÜZELTME: tek yardımcı `hesap_acik_islerini_kapat` — istekler kapanır, karşı tarafa
-- kredi iadesi (istek_kredisi_iade, idempotent) + iki dilde TARAFSIZ bildirim
-- (yasak sebebi açıklanmaz), açık oturumlar iptal, bağlantılar ve kanallar kapanır
-- (mesajlar SİLİNMEZ — şikâyet delili), ilanlar kapanır, profil keşiften çekilir.
-- Kullananlar: delete_my_account ve users.banned_at null → dolu tetikleyicisi.
--
-- Supabase SQL Editor: her ifade ayrı işlemde koşabilir; dosya tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.hesap_acik_islerini_kapat(p_uid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ad text := public.kisa_ad(p_uid);
  r record; v_misafir int := 0; v_host int := 0;
begin
  if p_uid is null then return jsonb_build_object('ok', false); end if;

  -- Misafir tarafı: açık isteklerim kapanır; kabul edilmişse host'a haber.
  for r in
    select q.id, q.host_id, q.status from requests q
     where q.guest_id = p_uid and q.status in ('pending', 'accepted')
  loop
    update requests set status = 'cancelled', responded_at = coalesce(responded_at, now())
     where id = r.id and status in ('pending', 'accepted');
    perform public.istek_kredisi_iade(r.id, 'request_cancel_refund');
    if r.status = 'accepted' then
      perform public.bildir(r.host_id, 'requests',
        'Buluşma iptal oldu',
        coalesce(v_ad, 'Misafir') || ' artık LoungeLink''te değil; kabul ettiğin buluşma gerçekleşmeyecek. Yerin yeniden açıldı.',
        'Meetup cancelled',
        coalesce(v_ad, 'The guest') || ' is no longer on LoungeLink; the meetup you accepted won''t happen. Your spot is open again.',
        'request', r.id);
    end if;
    v_misafir := v_misafir + 1;
  end loop;

  -- Host tarafı: ilanlarıma gelen açık istekler kapanır; misafire iade + haber.
  for r in
    select q.id, q.guest_id from requests q
      join availabilities a on a.id = q.avail_id
     where a.host_id = p_uid and q.status in ('pending', 'accepted')
  loop
    update requests set status = 'cancelled', responded_at = coalesce(responded_at, now())
     where id = r.id and status in ('pending', 'accepted');
    perform public.istek_kredisi_iade(r.id, 'request_refund');
    perform public.bildir(r.guest_id, 'requests',
      'Buluşma iptal oldu',
      coalesce(v_ad, 'Host') || ' artık LoungeLink''te değil; bu buluşma gerçekleşmeyecek. Kredin iade edildi — Keşfet''te başka ilanlar var.',
      'Meetup cancelled',
      coalesce(v_ad, 'The host') || ' is no longer on LoungeLink; this meetup won''t happen. Your credit was refunded — there are other listings in Discover.',
      'request', r.id);
    v_host := v_host + 1;
  end loop;

  update sessions s set status = 'cancelled', completed_at = now(), cancel_reason = 'account_closed'
    from requests q
   where q.id = s.request_id and (q.guest_id = p_uid or q.host_id = p_uid)
     and s.status in ('pending', 'active');

  update connection_requests set status = 'declined', responded_at = coalesce(responded_at, now())
   where (from_id = p_uid or to_id = p_uid) and status in ('pending', 'accepted');
  update chat_channels c set active = false
   where c.connection_id in (select id from connection_requests where from_id = p_uid or to_id = p_uid);

  update availabilities set active = false where host_id = p_uid and active;
  update profiles set show_on_discovery = false where user_id = p_uid;

  return jsonb_build_object('ok', true, 'kapanan_istek_misafir', v_misafir, 'kapanan_istek_host', v_host);
end $function$;

-- Yalnız sunucu içi (delete_my_account ve tetikleyici); kullanıcı doğrudan çağıramaz.
revoke execute on function public.hesap_acik_islerini_kapat(uuid) from public, anon, authenticated;
grant execute on function public.hesap_acik_islerini_kapat(uuid) to service_role;

CREATE OR REPLACE FUNCTION public.delete_my_account()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_email text; v_kapanan jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select email into v_email from users where id = v_uid;

  -- 322 · açık işler (istekler · oturumlar · bağlantılar · ilanlar · keşif görünürlüğü)
  v_kapanan := public.hesap_acik_islerini_kapat(v_uid);

  update users set deleted_at = now() where id = v_uid and deleted_at is null;

  -- 282/B2: SLA kuyruğuna DÜŞ (bo_silme_talepleri yalnız bu tabloyu okur).
  -- 322: durum sözlüğü tablonun ve BO'nun sözlüğü — 'pending' (eskiden 'open' → kısıt hatası).
  insert into deletion_requests (email, note, source, status, matched_user_id)
  select coalesce(v_email, v_uid::text), 'uygulama içi "Hesabı sil"', 'app', 'pending', v_uid
   where not exists (select 1 from deletion_requests
                      where matched_user_id = v_uid and status in ('pending', 'verified'));
  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('app.account_delete', 'users', v_uid, jsonb_build_object('requested_by', 'user') || coalesce(v_kapanan, '{}'::jsonb));
  return jsonb_build_object('ok', true, 'sla_days', 30);
end $function$;

-- ── BO yasağı: banned_at null → dolu olduğunda aynı kapanış ─────────────────
CREATE OR REPLACE FUNCTION public.trg_users_yasak_acik_isleri_kapat()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if old.banned_at is null and new.banned_at is not null then
    perform public.hesap_acik_islerini_kapat(new.id);
  end if;
  return new;
end $function$;

drop trigger if exists users_yasak_acik_isleri_kapat on public.users;
create trigger users_yasak_acik_isleri_kapat
  after update of banned_at on public.users
  for each row execute function public.trg_users_yasak_acik_isleri_kapat();

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'silme talebi durumu pending' as kontrol,
       position('''app'', ''pending''' in pg_get_functiondef('public.delete_my_account()'::regprocedure)) > 0 as tamam
union all
select 'acik isler yardimcisi kullaniliyor',
       position('hesap_acik_islerini_kapat' in pg_get_functiondef('public.delete_my_account()'::regprocedure)) > 0
union all
select 'yasak tetikleyicisi kurulu',
       exists (select 1 from pg_trigger where tgname = 'users_yasak_acik_isleri_kapat' and not tgisinternal)
union all
select 'yardimci kullaniciya kapali',
       not has_function_privilege('authenticated', 'public.hesap_acik_islerini_kapat(uuid)', 'execute');
-- Beklenen: dört satır da tamam = true.
