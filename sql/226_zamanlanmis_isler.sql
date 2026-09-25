-- ============================================================================
-- LoungeLink · 226_zamanlanmis_isler.sql                  (19 Ağustos 2026)
--
-- ZAMANLANMIŞ İŞLER — "cron kur" demek yerine KURUYORUZ
--
-- Gökberk: "send_missed_value_digest() için cron ... nasıl yapacağım
-- anlamadım."
--
-- Haklı, çünkü bu bir talimat değil ödevdi. Teslim notlarında üç turdur
-- "cron kur" yazıyor ve kurulmadı — kurulmadığı için de
-- `send_missed_value_digest()` yazıldığı günden beri HİÇ ÇALIŞMADI.
-- Yani host'ları geri getirmesi beklenen tek mekanizma ölü duruyor.
--
-- 🔴 BU DOSYA ÇALIŞTIRILDIĞINDA CRON KENDİLİĞİNDEN KURULUR.
-- Supabase'de `pg_cron` uzantısı vardır (Dashboard → Database →
-- Extensions). Kuruluysa iş burada tanımlanır ve haftada bir çalışır.
-- Kurulu değilse dosya HATA VERMEZ ama ekrana tam olarak ne yapılacağını
-- yazar — sessizce atlamak, üç turdur yaşadığımız durumu tekrarlamak olur.
--
-- NEDEN PAZARTESİ 10:00 (TR):
--   · "Kaçırdığın değer" bildirimi bir HATIRLATMADIR, acil değil.
--   · Hafta başı, insanların uçuş planına baktığı gün.
--   · Sabah 10:00 — sessiz saat kuralına takılmaz (o kural zaten
--     `on_notification_created` içinde uygulanıyor).
--   · UTC 07:00 = TR 10:00. pg_cron UTC çalışır; saat dilimini burada
--     çeviriyoruz ki "neden 13:00'te geldi" sorusu doğmasın.
-- ============================================================================

do $cron$
declare
  v_var boolean;
  v_id  bigint;
begin
  select exists (select 1 from pg_extension where extname = 'pg_cron') into v_var;

  if not v_var then
    raise notice '';
    raise notice '════════════════════════════════════════════════════════════';
    raise notice '226: pg_cron KURULU DEGIL — zamanlanmis is kurulamadi.';
    raise notice '';
    raise notice 'YAPILACAK (bir kez, ~30 saniye):';
    raise notice '  1) Supabase Dashboard -> Database -> Extensions';
    raise notice '  2) Arama kutusuna: pg_cron';
    raise notice '  3) Yanindaki anahtari AC (Enable)';
    raise notice '  4) Bu dosyayi (226) TEKRAR calistir';
    raise notice '';
    raise notice 'KURMAZSAN NE OLUR: haftalik "kacirdigin deger" bildirimi';
    raise notice 'hic gitmez. Fonksiyon calisir ama kimse cagirmaz —';
    raise notice 'bugune kadar oldugu gibi.';
    raise notice '';
    raise notice 'ALTERNATIF: Supabase Dashboard -> Edge Functions -> Cron,';
    raise notice 'ya da disaridan bir zamanlayici su cagriyi haftada bir yapar:';
    raise notice '  select public.send_missed_value_digest();';
    raise notice '════════════════════════════════════════════════════════════';
    raise notice '';
    return;
  end if;

  -- Aynı isimde iş varsa önce kaldır (dosya iki kez çalışabilmeli).
  begin
    perform cron.unschedule('loungelink_kacirilan_deger');
  exception when others then null;
  end;

  -- Pazartesi 07:00 UTC = 10:00 Türkiye
  select cron.schedule(
           'loungelink_kacirilan_deger',
           '0 7 * * 1',
           $$select public.send_missed_value_digest();$$)
    into v_id;

  raise notice '226: haftalik "kacirdigin deger" isi kuruldu (job #%, Pazartesi TR 10:00)', v_id;

  -- 🔴 İKİNCİ İŞ: oran sınırı tablosunun temizliği.
  -- `prune_rate_limits()` (140:91) 2 günden eski satırları siliyor ama
  -- HİÇBİR ZAMANLAYICI çağırmıyordu — tablo sonsuza kadar büyüyordu.
  -- Bunu kimse fark etmez çünkü yavaşlama aylar içinde birikir.
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='prune_rate_limits') then
    begin
      perform cron.unschedule('loungelink_oran_temizligi');
    exception when others then null;
    end;
    select cron.schedule(
             'loungelink_oran_temizligi',
             '30 3 * * *',                      -- her gece 03:30 UTC
             $$select public.prune_rate_limits();$$)
      into v_id;
    raise notice '226: gunluk oran-sinir temizligi kuruldu (job #%)', v_id;
  end if;

  -- 🔴 ÜÇÜNCÜ İŞ: aylık plan kredisi.
  -- 225 krediyi app açılışına bağladı (cron'suz da çalışsın diye) ama
  -- uygulamayı ay içinde hiç açmayan ödeyen kullanıcı kredisini geç
  -- alıyordu. Cron varsa ayın 1'inde herkese yazılır.
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='plan_kredisi_yerlestir') then
    begin
      perform cron.unschedule('loungelink_aylik_kredi');
    exception when others then null;
    end;
    select cron.schedule(
             'loungelink_aylik_kredi',
             '0 6 1 * *',                       -- ayın 1'i, 06:00 UTC (TR 09:00)
             $$do $inner$
               declare r record;
               begin
                 for r in select id from users where deleted_at is null loop
                   perform public.plan_kredisi_yerlestir(r.id);
                 end loop;
               end
             $inner$;$$)
      into v_id;
    raise notice '226: aylik plan kredisi isi kuruldu (job #%, ayin 1i TR 09:00)', v_id;
  end if;
end
$cron$;


-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ · YAZILMIŞ AMA KİMSENİN ÇAĞIRMADIĞI İŞ VAR MI
--
-- 🔴 BU DENETİMİN VARLIK SEBEBİ: `send_missed_value_digest()` üç sürüm
-- boyunca yazılı durdu ve hiç çalışmadı, çünkü "çağıran var mı" diye
-- soran bir şey yoktu. Bir fonksiyonun var olması, çalıştığı anlamına
-- gelmez.
--
-- Aşağıdaki liste "zamanlayıcı ister" diye işaretlenmiş fonksiyonları
-- tutuyor. pg_cron kuruluysa hepsinin bir işi olmalı; kurulu değilse
-- durum EKRANDA yazılır — sessiz kalmaz.
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cron boolean;
  v_eksik text := '';
  f text;
begin
  select exists (select 1 from pg_extension where extname = 'pg_cron') into v_cron;

  foreach f in array array['send_missed_value_digest','prune_rate_limits','plan_kredisi_yerlestir']
  loop
    -- Fonksiyon yoksa bu dosyanın işi değil.
    if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                    where n.nspname='public' and p.proname = f) then
      continue;
    end if;
    if not v_cron then
      v_eksik := v_eksik || f || ' ';
    elsif not exists (select 1 from cron.job where command like '%' || f || '%') then
      v_eksik := v_eksik || f || ' ';
    end if;
  end loop;

  if v_eksik <> '' then
    if v_cron then
      raise exception '226: su fonksiyonlarin zamanlanmis isi YOK → %', v_eksik;
    else
      raise warning '226: pg_cron kurulu degil — su isler CALISMIYOR: % '
                    '(yukaridaki adimlari uygula, sonra 226''yi tekrar calistir)', v_eksik;
    end if;
  else
    raise notice '226: zamanlayici isteyen her fonksiyonun bir isi var';
  end if;
end $$;

select '226 OK — zamanlanmis isler tanimlandi' as sonuc;
