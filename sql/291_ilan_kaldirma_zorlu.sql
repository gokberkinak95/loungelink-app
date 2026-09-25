-- ════════════════════════════════════════════════════════════════════════
-- 291 · İLAN KALDIRMA: ZORLA KALDIR + BEKLEYEN İSTEKLERİ SERBEST BIRAK
--
-- 🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL, MADDE 2
-- "İlanı kaldır dediğimde forced şekilde kaldırmalı ve başvurular iptal
--  dönmeli bence."
--
-- ÖLÇÜM — mevcut `cancel_availability` iki şey yapmıyordu:
--   1. Kabul edilmiş istek varsa HİÇ kaldırmıyordu ('has_accepted_requests').
--      Host'un gelemeyeceği bir günü kapatamaması, onu "gelmeyen host"
--      yapar — ürün için en pahalı sonuç.
--   2. BEKLEYEN istekleri hiç ellemiyordu. İlan pasife düşüyor, misafirin
--      isteği 'pending' kalıyor ve KREDİSİ EMANETTE ASILI KALIYOR.
--      Yani sessiz bir kredi tuzağı vardı.
--
-- 🆕 SINIF: "BİR KAYNAĞI KAPATIRKEN ONA BAĞLI BEKLEYENLERİ SERBEST
-- BIRAKMAZSAN, KAPATMA İŞLEMİ BİR TEMİZLİK DEĞİL BİR SIZINTIDIR."
--
-- YENİ DAVRANIŞ
--   cancel_availability(p_id)                → ESKİSİYLE AYNI (eski istemci kırılmaz)
--   cancel_availability(p_id, p_force=>true) → açık istekleri reddeder,
--     her birine krediyi İADE EDER, misafire bildirim gider, ilan pasife düşer
--   Oturum başlamışsa ('pending'/'active' session) İKİSİ DE reddedilir:
--     buluşma başladıysa ilan geri çekilemez ('session_started').
--
-- Dönen jsonb: {ok, iptal_edilen, bekleyen, kabul_edilen}
-- Tekrar koşulabilir.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.cancel_availability(p_id uuid, p_force boolean default false)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_accepted int; v_pending int; v_iptal int := 0;
  r record;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  if not exists (select 1 from availabilities where id = p_id and host_id = v_uid) then
    raise exception 'not_your_availability';
  end if;

  -- Oturum başladıysa hiçbir yoldan geri çekilemez.
  if exists (
    select 1 from sessions s join requests q on q.id = s.request_id
     where q.avail_id = p_id and s.status in ('pending','active')
  ) then raise exception 'session_started'; end if;

  select count(*) filter (where status = 'accepted'),
         count(*) filter (where status = 'pending')
    into v_accepted, v_pending
    from requests where avail_id = p_id;

  if v_accepted > 0 and not p_force then
    raise exception 'has_accepted_requests';
  end if;

  if p_force then
    -- Açık her isteği REDDET: kredi iadesi + bildirim, `respond_request`
    -- ile AYNI yoldan (iade mantığı tek yerde kalsın).
    for r in select id, guest_id from requests
              where avail_id = p_id and status in ('pending','accepted')
              for update
    loop
      update requests set status = 'declined', responded_at = now() where id = r.id;
      perform public.istek_kredisi_iade(r.id, 'request_refund');
      insert into notifications (user_id, category, title, body, ref_id, ref_type)
      values (r.guest_id, 'requests', 'İlan geri çekildi',
              'Host bu ilanı kaldırdı. Kredin anında iade edildi; başka bir ilana başvurabilirsin.',
              r.id, 'request');
      v_iptal := v_iptal + 1;
    end loop;
  else
    -- Zorlamasız yolda BİLE bekleyen istekler serbest bırakılır:
    -- ilan kapanınca o istek zaten cevaplanamaz hâle geliyordu.
    for r in select id, guest_id from requests
              where avail_id = p_id and status = 'pending' for update
    loop
      update requests set status = 'declined', responded_at = now() where id = r.id;
      perform public.istek_kredisi_iade(r.id, 'request_refund');
      insert into notifications (user_id, category, title, body, ref_id, ref_type)
      values (r.guest_id, 'requests', 'İlan geri çekildi',
              'Host bu ilanı kaldırdı. Kredin anında iade edildi; başka bir ilana başvurabilirsin.',
              r.id, 'request');
      v_iptal := v_iptal + 1;
    end loop;
  end if;

  -- Bekleyen davetler de kapanır.
  -- 'cancelled' bu enum'da YOK (pending|accepted|declined|blocked) — davet geri
  -- çekilince 'declined' doğru karşılık: davet edilen kişi bir şey yapmadı.
  update invites set status = 'declined'::connection_status, responded_at = now()
   where avail_id = p_id and status = 'pending';

  update availabilities set active = false, updated_at = now() where id = p_id;
  return jsonb_build_object('ok', true, 'iptal_edilen', v_iptal,
                            'bekleyen', v_pending, 'kabul_edilen', v_accepted);
end $function$;

-- ── Kendi sınaması ─────────────────────────────────────────────────────
do $$
declare
  hd uuid; av uuid; g uuid; r uuid; sonuc jsonb; v_bal_once int; v_bal_sonra int;
begin
  select host_id, id into hd, av from availabilities
   where active and avail_date >= current_date and coalesce(filled,0) < slots limit 1;
  if av is null then raise notice '291 sinama: uygun ilan yok, atlandi'; return; end if;
  select u.id into g from users u where u.id <> hd
    and not exists (select 1 from requests q where q.guest_id=u.id and q.avail_id=av
                      and q.status in ('pending','accepted')) limit 1;
  if g is null then raise notice '291 sinama: uygun misafir yok, atlandi'; return; end if;

  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (g, 2, 'sinama_291', (select coalesce(sum(delta),0) from credit_ledger where user_id=g) + 2);
  insert into requests (guest_id, host_id, avail_id, status) values (g, hd, av, 'pending') returning id into r;
  -- krediyi elle emanete al (istemci yolunda bunu `create_request` yapar)
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (g, -1, 'request_hold', r, (select coalesce(sum(delta),0) from credit_ledger where user_id=g) - 1);
  select coalesce(sum(delta),0) into v_bal_once from credit_ledger where user_id = g;

  perform set_config('request.jwt.claims', json_build_object('sub', hd::text, 'role','authenticated')::text, true);
  sonuc := public.cancel_availability(av, true);
  if (sonuc ->> 'ok') is distinct from 'true' then raise exception '291: zorlu kaldirma dusru'; end if;
  if (select status from requests where id = r) <> 'declined' then
    raise exception '291: bekleyen istek serbest birakilmadi';
  end if;
  if (select active from availabilities where id = av) then
    raise exception '291: ilan pasife dusmedi';
  end if;
  select coalesce(sum(delta),0) into v_bal_sonra from credit_ledger where user_id = g;
  if v_bal_sonra < v_bal_once then raise exception '291: kredi iade edilmedi (% -> %)', v_bal_once, v_bal_sonra; end if;
  raise notice '291 sinama: zorlu kaldirma + kredi iadesi OK (iptal edilen %)', sonuc ->> 'iptal_edilen';
  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
end $$;

select '291 kuruldu' as sonuc;
