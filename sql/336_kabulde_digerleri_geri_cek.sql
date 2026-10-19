-- ============================================================================
-- 336 · KABUL GELİNCE AYNI UÇUŞTAKİ DİĞER İSTEKLER GERİ ÇEKİLİR  (19 Ekim 2026)
--
-- Gökberk onayı: ücretli planlarda misafir aynı anda 3 / 6 host'a başvurabiliyor. Biri kabul
-- edince diğerleri bekliyordu: misafir iki kabul alıp iki kredi harcayabiliyor, öbür host'lar da
-- boşuna yer tutuyordu. Artık bir istek KABUL edilince aynı misafirin AYNI HAVALİMANI + AYNI GÜN
-- için bekleyen diğer istekleri kendiliğinden geri çekilir ve kredileri iade edilir.
--
-- İADE TEK YOLDAN: `istek_kredisi_iade` (idempotent — bir isteğe ikinci iade yazılmaz; ne
-- tutulduysa o iade edilir). Önceki iptal hatalarının sınıfı (çift iade / eksik iade) bu yüzden
-- burada tekrar etmez. Bekleyen oturum satırı da kapanır (respond_request 'cancel' ile aynı).
-- Diğer gün/havalimanı istekleri DOKUNULMAZ (gidiş-dönüş).
-- Supabase SQL Editor: tek dosya, tekrar koşulabilir.
-- ============================================================================

create or replace function public.kabulde_digerlerini_geri_cek(p_kabul uuid)
returns int
language plpgsql security definer set search_path = public as $kd336$
declare
  v_k requests%rowtype; v_av availabilities%rowtype; r record; v_n int := 0; v_salon text;
begin
  select * into v_k from requests where id = p_kabul;
  if not found or v_k.status <> 'accepted' then return 0; end if;
  select * into v_av from availabilities where id = v_k.avail_id;
  if not found then return 0; end if;

  for r in
    select q.id, q.host_id, q.avail_id from requests q join availabilities a on a.id = q.avail_id
     where q.guest_id = v_k.guest_id and q.id <> v_k.id and q.status = 'pending'
       and a.airport_code = v_av.airport_code and a.avail_date = v_av.avail_date
     for update of q
  loop
    update requests set status = 'cancelled'::request_status, responded_at = now() where id = r.id;
    update sessions set status = 'cancelled', completed_at = now(), cancelled_by = v_k.guest_id,
           cancel_reason = 'not_started'
     where request_id = r.id and status = 'pending';
    perform public.istek_kredisi_iade(r.id, 'request_cancel_refund');
    v_salon := public.salon_etiketi(r.avail_id);
    perform public.bildir(r.host_id, 'requests',
      public.kisa_ad(v_k.guest_id) || ' başka bir ilanla eşleşti',
      v_salon || ' — isteği kendiliğinden geri çekildi, yerin açık.',
      public.kisa_ad(v_k.guest_id) || ' matched with another listing',
      v_salon || ' — the request was withdrawn automatically; your spot is open.',
      'request', r.id);
    v_n := v_n + 1;
  end loop;

  if v_n > 0 then
    perform public.bildir(v_k.guest_id, 'requests',
      'Diğer ' || v_n || ' isteğin geri çekildi',
      'Aynı uçuş için bir host seni kabul etti. Diğer isteklerin geri çekildi ve kredilerin iade edildi.',
      v_n || ' other request' || case when v_n > 1 then 's' else '' end || ' withdrawn',
      'A host accepted you for this flight. Your other requests were withdrawn and the credits refunded.',
      'request', v_k.id);
  end if;
  return v_n;
end $kd336$;
revoke all on function public.kabulde_digerlerini_geri_cek(uuid) from public, anon, authenticated;
grant execute on function public.kabulde_digerlerini_geri_cek(uuid) to service_role;

-- respond_request: kabul satırından hemen sonra çağır
do $rr336$
declare v_tanim text;
  v_eski text := 'update requests set status=''accepted'', responded_at=now() where id = v_req.id;';
begin
  select pg_get_functiondef('public.respond_request(uuid, text)'::regprocedure) into v_tanim;
  if v_tanim like '%kabulde_digerlerini_geri_cek%' then raise notice '336: respond_request zaten guncel.'; return; end if;
  if position(v_eski in v_tanim) = 0 then raise exception '336: respond_request govdesi beklenenden farkli — elle bak.'; end if;
  v_tanim := replace(v_tanim, v_eski, v_eski || E'\n    perform public.kabulde_digerlerini_geri_cek(v_req.id);');
  execute v_tanim;
end $rr336$;

-- doğrulama
select 'geri cekme fonksiyonu' as kontrol, to_regprocedure('public.kabulde_digerlerini_geri_cek(uuid)') is not null as tamam
union all
select 'respond_request cagiriyor', pg_get_functiondef('public.respond_request(uuid, text)'::regprocedure) like '%kabulde_digerlerini_geri_cek%'
union all
select 'yalniz service_role', not has_function_privilege('authenticated', 'public.kabulde_digerlerini_geri_cek(uuid)', 'execute');
-- Beklenen: üç satır tamam = true.
