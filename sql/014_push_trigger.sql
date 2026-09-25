-- ============================================================
-- LoungeLink · 014_push_trigger.sql
-- ÖNCE send-push Edge Function'ı deploy edilmeli. Sonra bu çalıştırılır.
-- notifications tablosuna INSERT olunca Edge Function'ı çağırır (pg_net).
-- ============================================================
create extension if not exists pg_net;

-- Proje URL'ini ve anon key'i buraya gömüyoruz (Edge Function public endpoint).
create or replace function public.notify_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://wgprynisnriyblccxuhq.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.anon_key', true)
    ),
    body := jsonb_build_object('record', to_jsonb(NEW))
  );
  return NEW;
end $$;

drop trigger if exists on_notification_created on notifications;
create trigger on_notification_created
  after insert on notifications
  for each row execute function public.notify_push();

select 'PUSH TRIGGER OK' as sonuc;
