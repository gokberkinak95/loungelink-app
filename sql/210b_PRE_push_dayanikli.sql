-- ============================================================================
-- LoungeLink · 210b_PRE_push_dayanikli.sql             (18 Ağustos 2026)
--
-- 🔴 GÖKBERK CANLIDA:
--     ERROR 3F000: schema "net" does not exist
--     QUERY: SELECT net.http_post(url := 'https://exp.host/...')
--     CONTEXT: notify_push() line 36 at PERFORM
--              insert into notifications ...
--              send_missed_value_digest(boolean) line 48
--
-- Zincir şu: 210 sonundaki blok `send_missed_value_digest()` çağırıyor →
-- o `notifications`a satır yazıyor → `on_notification_created` tetikleyicisi
-- `notify_push()` çalıştırıyor → `net.http_post` çağrılıyor → `pg_net`
-- uzantısı kurulu olmadığı için 3F000 → **bütün 210 geri alınıyor.**
--
-- ── ASIL KUSUR "pg_net yok" DEĞİL ───────────────────────────────────
-- Asıl kusur, dış dünyaya giden bir çağrının kullanıcının yazma işlemini
-- geri alabilmesi. Push best-effort bir şeydir: telefon titremezse
-- bildirim kaydı yine de durmalı. `notify_push` içinde bu ilke dokuz
-- satır yukarıda zaten yazılıydı —
--     "Token yoksa SESSIZCE geç ... burada hata fırlatmak bildirim
--      kaydını da engellerdi."
-- ama aynı akıl HTTP çağrısına uygulanmamıştı.
--
-- ── BENDE NEDEN ÇIKMADI ─────────────────────────────────────────────
-- Harness `pg_net`'i TAKLİT ediyor: sahte bir uzantı kurup `net` şeması
-- ve `net.http_post` fonksiyonu yaratıyor. Yani benim ortamımda çağrı
-- her zaman başarılı. Taklit, olmayan bir dünyayı test ediyordu.
-- (Taklidi kaldırmıyorum — o olmadan 013/014/111 hiç kurulamaz. Ama
--  kod artık taklide DE gerçeğe DE dayanıklı.)
--
-- ── DÜZELTME: İKİ KATMAN ────────────────────────────────────────────
--   1) `to_regnamespace('net') is null` → hiç denemeyiz, WARNING yazarız.
--   2) Denerken çıkan HER hata yutulur ama WARNING olarak loglanır.
-- Sessizce kaybolmaz; bildirim kaydı da asla geri alınmaz.
--
-- ── PUSH'U GERÇEKTEN ÇALIŞTIRMAK İSTERSEN ───────────────────────────
-- Supabase panelinde Database → Extensions → **pg_net** aç. Ya da:
--     create extension if not exists pg_net;
-- Bu dosya onu SENİN ADINA AÇMIYOR: uzantı kurmak proje düzeyinde bir
-- karar ve bir migration'ın sessizce alacağı bir karar değil.
--
-- KULLANIM: 210'dan ÖNCE çalıştır.
-- ============================================================================

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

-- Tetikleyici aynen kalsın (yeniden bağlamak zararsız, idempotent).
drop trigger if exists on_notification_created on notifications;
create trigger on_notification_created
  after insert on notifications
  for each row execute function public.notify_push();

-- ── NÖBETÇİ: pg_net YOKKEN de bildirim yazılabiliyor mu ─────────────
-- 🔴 "Çağır ve say" yetmez; kusuru ÜRETEN durumu kurup deniyoruz.
do $nobetci$
declare v_uid uuid; v_n bigint;
begin
  select id into v_uid from users limit 1;
  if v_uid is null then
    raise notice '210b: kullanici yok — nobetci calistirilamadi (KAPSAM YOK)';
    return;
  end if;
  insert into notifications (user_id, category, title, body)
  values (v_uid, 'system', '210b nobetci', 'push kapaliyken de yazilmali');
  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception '210b: bildirim YAZILAMADI — push hatasi hala yazmayi bozuyor';
  end if;
  -- Denemeyi geri al: nobetci veri birakmaz.
  delete from notifications
   where user_id = v_uid and title = '210b nobetci';
  raise notice '210b: push kapaliyken bile bildirim kaydi yaziliyor ✓';
end
$nobetci$;
