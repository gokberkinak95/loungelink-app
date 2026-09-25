-- ════════════════════════════════════════════════════════════════════════
-- 289 · DAVET KABULÜ, AYNI İLANA ZATEN İSTEK GÖNDERMİŞ MİSAFİRDE PATLIYOR
--
-- 🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL, MADDE 16 (kritik)
-- "Lounge isteğini kabul ettiğimde bir şeyler ters gitti hatası alıyorum."
--
-- ÖLÇÜM (yerel, gerçek veriyle, senaryo birebir kuruldu):
--     respond_invite(<davet>, true)
--     → 23505 / duplicate key value violates unique constraint
--       "idx_requests_unique_active"
--
-- Yani hata bizim kodlarımızdan biri DEĞİL, ham bir Postgres kısıt
-- ihlali. `mapErr` onu çeviremediği için ekranda "Bir şeyler ters gitti"
-- yazıyordu — kullanıcı için bu "uygulama bozuk" demek.
--
-- KÖK NEDEN: `respond_invite` kabul edince KOŞULSUZ yeni bir `requests`
-- satırı açıyordu. Oysa `idx_requests_unique_active` aynı (misafir, ilan)
-- çifti için aktif TEK satıra izin veriyor. Misafir o ilana zaten istek
-- göndermişse (ki davet edilen kişi çoğu zaman göndermiştir — host onu
-- listede görüp davet ediyor) kabul HER ZAMAN düşüyordu.
--
-- 🆕 SINIF: "BİR KISIT, ONU BİLMEYEN BİR YAZMA YOLUNUN VARLIĞINI
-- ENGELLEMEZ — YALNIZ O YOLU KULLANAN KULLANICIYI CEZALANDIRIR."
--
-- DÜZELTME — üç hâl, üçü de veri kaybetmeden:
--   · zaten ACCEPTED bir istek var  → yeni satır AÇILMAZ, mevcut oturum
--     ve kanal döndürülür, İKİNCİ KREDİ ALINMAZ (davet zaten gerçekleşmiş)
--   · PENDING bir istek var         → o istek 'accepted'e YÜKSELTİLİR
--     (host zaten davet ederek kabul etmiş sayılır), kredi yeniden
--     alınmaz — bekleyen istek krediyi zaten emanette tutuyor
--   · hiç aktif istek yok           → eskisi gibi yeni satır + kredi
--
-- Tekrar koşulabilir.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.respond_invite(p_id uuid, p_accept boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid(); v_i invites%rowtype; v_req uuid; v_chan uuid;
  v_bal int; v_sess uuid; v_av availabilities%rowtype;
  v_mevcut requests%rowtype;
  v_yeni boolean := false;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);   -- 282/B1: yasaklı/silinmiş hesap yazamaz

  select * into v_i from invites where id = p_id for update;
  if not found then raise exception 'invite_not_found'; end if;
  if v_i.guest_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_i.status <> 'pending' then raise exception 'already_responded'; end if;

  update invites set status = (case when p_accept then 'accepted' else 'declined' end)::connection_status,
         responded_at = now()
   where id = p_id;

  if p_accept then
    -- ── 289: AYNI İLANA ZATEN AKTİF BİR İSTEK VAR MI? ─────────────────
    select * into v_mevcut from requests
     where guest_id = v_uid and avail_id = v_i.avail_id
       and status in ('pending','accepted')
     order by created_at desc limit 1
     for update;

    if found and v_mevcut.status = 'accepted' then
      -- Zaten kabul edilmiş: davet fazlalık. Yeni satır da yeni kredi de yok.
      v_req := v_mevcut.id;
    else
      -- Kapasite kontrolü her iki yolda da geçerli (030'dan beri).
      select * into v_av from availabilities where id = v_i.avail_id for update;
      if not found then raise exception 'availability_not_found'; end if;
      if coalesce(v_av.filled,0) >= v_av.slots then raise exception 'fully_booked'; end if;

      if v_mevcut.id is not null then
        -- PENDING istek var → davet onu kabule yükseltir. Kredi zaten emanette.
        update requests set status = 'accepted', responded_at = now(),
               type = 'direct_invite'
         where id = v_mevcut.id;
        v_req := v_mevcut.id;
      else
        -- Hiç istek yok → eskisi gibi: kredi al, satırı aç.
        select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
        if v_bal < 1 then raise exception 'insufficient_credits'; end if;

        insert into requests (guest_id, host_id, avail_id, status, type, intro_message, match_score)
        values (v_uid, v_i.host_id, v_i.avail_id, 'accepted', 'direct_invite', v_i.note, 60)
        returning id into v_req;
        v_yeni := true;

        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
        values (v_uid, -1, 'invite_hold', v_req, v_bal - 1);
      end if;
    end if;

    insert into chat_channels (request_id, kind) values (v_req, 'lounge')
      on conflict (request_id) do nothing;
    select id into v_chan from chat_channels where request_id = v_req;

    -- Davet notu ilk mesaj (gönderen: HOST — daveti o yazdı)
    if v_chan is not null and coalesce(nullif(trim(v_i.note),''),'') <> '' then
      insert into messages (channel_id, from_id, body, created_at)
      select v_chan, v_i.host_id, trim(v_i.note), now()
       where not exists (select 1 from messages m where m.channel_id = v_chan);
    end if;

    -- Oturum: zaten varsa YENİSİ AÇILMAZ (davet iki kez oturum başlatamaz).
    select id into v_sess from sessions where request_id = v_req and status in ('pending','active') limit 1;
    if v_sess is null then
      insert into sessions (request_id, status, started_at)
      values (v_req, 'active', now()) returning id into v_sess;
    end if;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin kabul edildi ✓', 'Sohbet açıldı, oturum başladı.', 'request', v_req);
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_i.host_id, 'requests', 'Davetin yanıtlandı', 'Davet reddedildi.', 'invite', p_id);
  end if;

  return jsonb_build_object('ok', true, 'request_id', v_req, 'channel_id', v_chan,
                            'session_id', v_sess, 'yeni_istek', v_yeni);
end $function$;

-- ── Kendi sınaması: üç hâl de düşmeden geçmeli ──────────────────────────
do $$
declare
  hd uuid; g uuid; av uuid; inv uuid; r uuid; sonuc jsonb;
begin
  select host_id, id into hd, av from availabilities
   where active and avail_date >= current_date and coalesce(filled,0) < slots limit 1;
  if av is null then raise notice '289 sinama: uygun ilan yok, atlandi'; return; end if;
  select u.id into g from users u
   where u.id <> hd
     and not exists (select 1 from requests q where q.guest_id = u.id and q.avail_id = av
                       and q.status in ('pending','accepted'))
   limit 1;
  if g is null then raise notice '289 sinama: uygun misafir yok, atlandi'; return; end if;

  -- misafirin kredisi olsun
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (g, 3, 'sinama_289', (select coalesce(sum(delta),0) from credit_ledger where user_id = g) + 3);

  -- HÂL 2: once PENDING istek, sonra davet kabulu
  insert into requests (guest_id, host_id, avail_id, status) values (g, hd, av, 'pending') returning id into r;
  insert into invites (avail_id, host_id, guest_id, status, note)
    values (av, hd, g, 'pending', '289 sinama') returning id into inv;
  perform set_config('request.jwt.claims', json_build_object('sub', g::text, 'role','authenticated')::text, true);
  sonuc := public.respond_invite(inv, true);
  if (sonuc ->> 'ok') is distinct from 'true' then
    raise exception '289: bekleyen istek varken davet kabulu dusrdu';
  end if;
  if (select status from requests where id = r) <> 'accepted' then
    raise exception '289: bekleyen istek accepted''e yukseltilmedi';
  end if;
  if (sonuc ->> 'yeni_istek') <> 'false' then
    raise exception '289: bekleyen istek varken YENI satir acilmis (mukerrer kredi)';
  end if;
  raise notice '289 sinama: bekleyen istek + davet kabulu = OK (istek %)', r;
  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
end $$;

select '289 kuruldu' as sonuc;
