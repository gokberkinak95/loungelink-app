-- ============================================================
-- LoungeLink · 111_push_direct_expo.sql
-- TELEFONA BILDIRIM: ZINCIRIN UC HALKASI DA KOPUKTU
--
-- ⚠️ Uygulamayi ETKILER. Tetikleyici degisiyor.
--
-- ------------------------------------------------------------
-- 🔴 NEDEN HIC BILDIRIM DUSMUYORDU
-- ------------------------------------------------------------
-- Gokberk sordu: "app icinde bildirim var ama telefona hic dusmuyor."
-- Zinciri bastan sona takip ettim; UC AYRI yerde kopuk:
--
--   1. TOKEN HIC KAYDEDILMIYOR.
--      src/push.js yazilmis, izin istiyor, Expo token aliyor,
--      save_push_token'i cagiriyor... ama BU DOSYA HICBIR YERDEN
--      CAGRILMIYOR. push_tokens tablosu bos. Alici yok.
--
--   2. TETIKLEYICI OLMAYAN BIR ADRESE GIDIYOR.
--      014, her bildirimde bir Supabase EDGE FUNCTION'a POST atiyor:
--        /functions/v1/send-push
--      O fonksiyon HIC YAZILMADI ve deploy edilmedi. Yani istek
--      404'e gidiyor, sessizce kayboluyor.
--
--   3. YETKI BASLIGI BOS.
--      'Bearer ' || current_setting('app.anon_key', true)
--      Bu ayar hicbir yerde tanimli degil; deger NULL, baslik 'Bearer '.
--
-- ------------------------------------------------------------
-- COZUM: ARADAKI KATMANI TAMAMEN KALDIR
-- ------------------------------------------------------------
-- Edge Function yazmak yerine DOGRUDAN Expo'nun push servisine
-- gidiyoruz. Expo'nun /--/api/v2/push/send ucu kimlik dogrulamasi
-- ISTEMEZ (gelismis guvenlik acilmadikca) ve tek istekte 100 mesaj
-- kabul eder.
--
-- Neden bu daha iyi: Edge Function AYRI bir deploy adimi, AYRI bir
-- log yeri ve AYRI bir bozulma noktasi demek. Bir halkayi silmek,
-- o halkanin bir gun kopmasini da siler.
-- ============================================================

create or replace function public.notify_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_body jsonb; v_quiet boolean := false;
begin
  -- Sessiz saat / kanal tercihi. Kullanicinin kapattigi bir kategori
  -- icin telefonunu titretmek, bildirimi kapatmasina yol acar.
  begin
    select coalesce(
             (n.prefs -> NEW.category::text ->> 'push')::boolean = false, false)
      into v_quiet
      from notification_prefs n where n.user_id = NEW.user_id;
  exception when undefined_table or undefined_column then
    v_quiet := false;
  end;
  if v_quiet then return NEW; end if;

  select jsonb_agg(jsonb_build_object(
           'to', t.token,
           'title', coalesce(NEW.title, 'LoungeLink'),
           'body', coalesce(NEW.body, ''),
           'sound', 'default',
           'channelId', 'default',
           'priority', 'high',
           'data', jsonb_build_object(
                     'category', NEW.category,
                     'notification_id', NEW.id)))
    into v_body
    from push_tokens t
   where t.user_id = NEW.user_id
     and coalesce(t.active, true)
     and coalesce(t.token,'') like 'ExponentPushToken%';

  -- Token yoksa SESSIZCE gec. Kullanici henuz izin vermemis olabilir;
  -- burada hata firlatmak bildirim kaydini da engellerdi.
  if v_body is null then return NEW; end if;

  -- 🔴 PUSH BEST-EFFORT'TUR — 18 Agustos 2026, Gokberk canlida:
  --     ERROR 3F000: schema "net" does not exist
  --     CONTEXT: notify_push() line 36 at PERFORM
  --       ... insert into notifications ...
  --       ... send_missed_value_digest(boolean) ...
  -- Yani `pg_net` uzantisi kurulu olmadigi icin BILDIRIM KAYDI bile
  -- yazilamadi ve 210 komple dustu.
  --
  -- Bu satirlarin dokuz satir yukarisinda dogru ilke ZATEN yaziliydi:
  --   "Token yoksa SESSIZCE gec ... burada hata firlatmak bildirim
  --    kaydini da engellerdi."
  -- Ayni akil HTTP cagrisina uygulanmamisti. Dis dunyaya giden bir
  -- cagri, kullanicinin yazma islemini ASLA geri almamali.
  --
  -- Iki katman: (1) sema yoksa hic denemeyiz, (2) denerken cikan HER
  -- hata yutulur ama WARNING olarak loglanir — sessizce kaybolmaz.
  if to_regnamespace('net') is null then
    raise warning 'notify_push: pg_net kurulu degil, push atlandi (bildirim kaydi DURUYOR)';
    return NEW;
  end if;

  begin
    perform net.http_post(
      url     := 'https://exp.host/--/api/v2/push/send',
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Accept', 'application/json'),
      body    := v_body);
  exception when others then
    raise warning 'notify_push: push gonderilemedi (% / %) — bildirim kaydi DURUYOR',
      sqlstate, sqlerrm;
  end;
  return NEW;
end $$;

drop trigger if exists on_notification_created on notifications;
create trigger on_notification_created
  after insert on notifications
  for each row execute function public.notify_push();

-- ---- Token kaydi: ayni cihaz iki kez yazilmasin ----
alter table push_tokens add column if not exists active boolean not null default true;
alter table push_tokens add column if not exists updated_at timestamptz default now();
create unique index if not exists uq_push_token on push_tokens (token);

create or replace function public.save_push_token(p_token text, p_platform text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if coalesce(p_token,'') not like 'ExponentPushToken%' then
    -- 🔴 Bicimi dogrula. Gecersiz token Expo tarafinda "DeviceNotRegistered"
    -- uretir ve tum toplu gonderiyi bozabilir.
    return jsonb_build_object('ok', false, 'reason', 'invalid_token_format');
  end if;

  insert into push_tokens (user_id, token, platform, active, updated_at)
  values (v_uid, p_token, p_platform, true, now())
  on conflict (token) do update
    set user_id = excluded.user_id,      -- cihaz el degistirmis olabilir
        platform = excluded.platform,
        active = true, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.save_push_token(text, text) to authenticated;

-- Cikis yapinca token pasife alinsin: baskasinin telefonuna bildirim gitmesin
create or replace function public.disable_push_token(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update push_tokens set active = false, updated_at = now()
   where token = p_token and user_id = auth.uid();
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.disable_push_token(text) to authenticated;

select count(*) as kayitli_token,
       count(*) filter (where active) as aktif
  from push_tokens;

select '111 OK - bildirimler DOGRUDAN Expo''ya gidiyor, ara katman kalkti' as sonuc;
