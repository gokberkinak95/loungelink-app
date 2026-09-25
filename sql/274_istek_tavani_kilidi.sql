-- ============================================================================
-- 274 — "AYNI ANDA AÇABİLECEĞİN İSTEK SAYISINA ULAŞTIN" KİLİDİ  (30 Ağu 2026)
--
-- 🔴 ŞİKÂYET
-- Gökberk: "istek göndermek istediğimde aynı anda açabileceğin istek
-- sayısına ulaştın hatası alıyorum >> bu da çok kritik."
--
-- 🔴 TEŞHİS — ÜÇ ARIZA ÜST ÜSTE BİNİYOR, TEK BAŞINA HİÇBİRİ YETMİYOR
--
-- (1) TAVAN SAYIMI ZAMANSIZ.  246_ekonomi_ayari.sql:98-99
--       select count(*) into v_acik from requests
--        where guest_id = new.guest_id and status = 'pending' and id <> new.id;
--     Hiçbir zaman kısıtı yok. Tarihi altı ay geçmiş bir ilana yapılmış,
--     kimsenin yanıtlamadığı bir istek de "açık" sayılıyor.
--
-- (2) ÜCRETSİZ PLANDA TAVAN 1.  246:74 → 'yolcu' = 1.
--     Yani TEK bir asılı kalmış satır kullanıcıyı kalıcı olarak kilitliyor.
--
-- (3) ASILI KALAN İSTEĞİ KAPATAN İŞ HİÇ ÇALIŞMIYOR — VE ÇALIŞSA DA
--     ÇOĞUNU ATLIYOR.
--       · `bayat_istekleri_iade_et()` hiçbir `cron.schedule` çağrısında yok
--         (226 ve 236'daki dört zamanlanmış işin hiçbiri bu değil).
--       · App açılışında koşan `expire_stale_sessions` yalnız
--         `status='accepted'` satırlara bakıyor (080:287) — `pending`e hiç
--         dokunmuyor.
--       · Koşsa bile 249:481-483'teki şu şart onu kısırlaştırıyor:
--           and exists (select 1 from credit_ledger cl
--                        where cl.ref_id = req.id and cl.reason = 'request_hold')
--         Oysa soğuk ağda istek ÜCRETSİZ ve 258:176-181 o satırı
--         `request_free_tier` adıyla yazıyor. Bugün isteklerin neredeyse
--         tamamı ücretsiz → neredeyse hiçbiri süpürücünün gözüne görünmüyor.
--
-- Zincirin sonucu: ücretsiz kullanıcı bir istek gönderir, host yanıtlamaz,
-- satır SONSUZA KADAR `pending` kalır, tavan 1/1 olur ve kullanıcı bir daha
-- hiç istek gönderemez. Hata metni de "bekle" diyor — asla gelmeyecek bir
-- yanıtı beklemesini söylüyor.
--
-- 🆕 SINIF: **"BİR KAYNAK TAVANI, O KAYNAĞI SERBEST BIRAKAN İŞ GERÇEKTEN
-- ÇALIŞMADIKÇA TAVAN DEĞİL KİLİTTİR — VE SAYAÇ ZAMANSIZSA KİLİT KALICIDIR."**
--
-- Ve ikinci ders, kredi şartından çıkıyor:
-- 🆕 SINIF: **"BİR KAYDI KAPATMAK İLE PARASINI İADE ETMEK AYRI İKİ İŞTİR;
-- BİRİNİ DİĞERİNİN ŞARTINA BAĞLARSAN, PARASI OLMAYAN KAYIT HİÇ KAPANMAZ."**
--
-- ⚠️ BU DOSYA VERİ SİLMEZ. Asılı istekleri `cancelled` yapar, gerekçesini
-- `decision_note`a yazar ve kullanıcıya bildirim bırakır.
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════
-- §1 — SÜPÜRÜCÜ: KAPATMAYI KREDİ ŞARTINDAN AYIR
--
-- Kapatma artık koşulsuz; İADE hâlâ "gerçekten kredi harcanmışsa" şartına
-- bağlı — çünkü harcanmamış krediyi iade etmek yoktan para basmaktır.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.bayat_istekleri_iade_et()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_saat int := coalesce((select (value #>> '{}')::int from beta_settings
                           where key = 'bayat_istek_saat'), 72);
  r record; v_bal int; v_kapatilan int := 0; v_iade int := 0;
begin
  perform public.motor_yazimi_ac();

  for r in
    select req.id, req.guest_id
      from requests req
      join availabilities a on a.id = req.avail_id
     where req.status = 'pending'
       and req.responded_at is null
       and (a.avail_date < current_date
            or req.created_at < now() - make_interval(hours => v_saat))
  loop
    -- Satır satır: bir satır bir iş kuralına takılırsa toplu iş çökmesin.
    begin
      update requests
         set status = 'cancelled',
             responded_at = now(),
             decision_note = coalesce(decision_note,
               'Host süresinde yanıtlamadı — istek otomatik kapatıldı (274).')
       where id = r.id and status = 'pending';
      if not found then continue; end if;
      v_kapatilan := v_kapatilan + 1;

      -- İADE yalnız gerçekten kredi düşülmüşse ve daha önce iade
      -- edilmemişse. `request_free_tier` satırları burada kasıtla dışarıda:
      -- harcanmayan kredi iade edilmez.
      if exists (select 1 from credit_ledger cl
                  where cl.ref_id = r.id and cl.reason = 'request_hold' and cl.delta < 0)
         and not exists (select 1 from credit_ledger cl
                          where cl.ref_id = r.id and cl.reason = 'request_stale_refund')
      then
        select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = r.guest_id;
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
        values (r.guest_id, 1, 'request_stale_refund', r.id, v_bal + 1,
                format('%s saat içinde yanıt gelmedi', v_saat));
        v_iade := v_iade + 1;
      end if;

      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      values (r.guest_id, 'requests', 'İsteğin kapandı',
              format('Başvurun %s saat içinde yanıtlanmadı. Artık yeni istek gönderebilirsin.', v_saat),
              'request', r.id);
    exception when others then
      raise notice '274: istek % kapatilamadi: %', r.id, sqlerrm;
    end;
  end loop;

  return jsonb_build_object('ok', true, 'kapatilan', v_kapatilan,
                            'iade_edilen', v_iade, 'esik_saat', v_saat);
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- §2 — TAVAN SAYACI: YALNIZ CANLI İSTEKLERİ SAY
--
-- Süpürücü bir gün durursa bile kullanıcı kilitlenmesin. İki bağımsız
-- savunma: (a) ilanın tarihi geçmemiş olsun, (b) istek bayatlamamış olsun.
--
-- 🔴 Ayrıca PLAN OKUMASI DÜZELTİLDİ. 210:89 eski planları (`explorer`,
-- `traveler`, `frequent`) `aktif=false` yaptı ama kullanıcıları o planda
-- BIRAKTI. Eski sorgu `join plan_catalog p on ... and p.aktif` yazdığı için
-- o kullanıcılar hiç satır bulamıyor ve `coalesce(...,1)` ile TAVAN 1'e
-- düşüyordu: parasını ödemiş bir kullanıcı ücretsiz plandan da kısıtlı
-- hale geliyordu. Artık önce aktif plan, bulunamazsa pasif plan okunuyor.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.trg_acik_istek_tavani()
returns trigger language plpgsql security definer set search_path = public as $f$
declare
  v_tavan int;
  v_acik  int;
  v_saat  int := coalesce((select (value #>> '{}')::int from beta_settings
                            where key = 'bayat_istek_saat'), 72);
begin
  if new.status <> 'pending' then return new; end if;

  select coalesce(
    (select p.acik_istek_tavani from plan_catalog p
       join users u on u.plan = p.plan
      where u.id = new.guest_id and p.aktif),
    (select p.acik_istek_tavani from plan_catalog p
       join users u on u.plan = p.plan
      where u.id = new.guest_id),
    1)
  into v_tavan;
  v_tavan := greatest(coalesce(v_tavan, 1), 1);

  select count(*) into v_acik
    from requests r
    join availabilities a on a.id = r.avail_id
   where r.guest_id = new.guest_id
     and r.status = 'pending'
     and r.id <> new.id
     and a.avail_date >= current_date
     and r.created_at >= now() - make_interval(hours => v_saat);

  if v_acik >= v_tavan then
    raise exception 'acik_istek_tavani'
      using detail = format('%s/%s acik istek', v_acik, v_tavan),
            hint   = 'Bekleyen isteklerinden birini iptal edip yenisini gonderebilirsin.';
  end if;
  return new;
end $f$;


-- ════════════════════════════════════════════════════════════════════════
-- §3 — SAYAÇ İLE VİTRİN AYNI CÜMLEYİ KURMALI
--
-- `acik_istek_tavanim()` uygulamadaki "Açık istek 1/1" çipini besliyor.
-- Tavanla AYNI koşulu kullanmazsa çip, kapının yalanını doğrular.
--
-- 🆕 SINIF: "BİR KAPI İLE O KAPIYI ANLATAN GÖSTERGE FARKLI SORGU
-- KULLANIYORSA, GÖSTERGE KAPIYI DEĞİL KENDİNİ ANLATIR."
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.acik_istek_tavanim()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_tavan int; v_acik int;
  v_saat int := coalesce((select (value #>> '{}')::int from beta_settings
                           where key = 'bayat_istek_saat'), 72);
begin
  if v_uid is null then return jsonb_build_object('acik', 0, 'tavan', 0); end if;

  select coalesce(
    (select p.acik_istek_tavani from plan_catalog p
       join users u on u.plan = p.plan where u.id = v_uid and p.aktif),
    (select p.acik_istek_tavani from plan_catalog p
       join users u on u.plan = p.plan where u.id = v_uid),
    1)
  into v_tavan;
  v_tavan := greatest(coalesce(v_tavan, 1), 1);

  select count(*) into v_acik
    from requests r
    join availabilities a on a.id = r.avail_id
   where r.guest_id = v_uid
     and r.status = 'pending'
     and a.avail_date >= current_date
     and r.created_at >= now() - make_interval(hours => v_saat);

  return jsonb_build_object('acik', v_acik, 'tavan', v_tavan);
end $$;

grant execute on function public.acik_istek_tavanim() to authenticated;


-- ════════════════════════════════════════════════════════════════════════
-- §4 — BİRİKMİŞİ TEMİZLE
--
-- Kural düzeltildi ama HÂLİHAZIRDA kilitli hesaplar var. Onları da açalım.
-- ════════════════════════════════════════════════════════════════════════
do $tmz$
declare v_n int;
begin
  perform public.motor_yazimi_ac();
  update requests r
     set status = 'cancelled',
         responded_at = now(),
         decision_note = coalesce(r.decision_note,
           'Bayat istek toplu kapatildi (274) — yanit gelmedi.')
    from availabilities a
   where a.id = r.avail_id
     and r.status = 'pending'
     and r.responded_at is null
     and (a.avail_date < current_date
          or r.created_at < now() - interval '72 hours');
  get diagnostics v_n = row_count;
  raise notice '274: % bayat istek kapatildi', v_n;
end $tmz$;


-- ════════════════════════════════════════════════════════════════════════
-- §5 — İŞİ GERÇEKTEN ZAMANLA
--
-- Bugüne kadar bu fonksiyon hiçbir yerde zamanlanmamıştı. Yazılmış ama
-- çağrılmayan bir bakım işi, olmayan bir bakım işidir.
-- ════════════════════════════════════════════════════════════════════════
-- ── YARDIMCI: pg_cron OLMAYAN ORTAMDA DA ÇALIŞAN İŞ SORGUSU ──────
-- 🔴 31 AĞUSTOS — BU DOSYA pg_cron OLMAYAN HER ORTAMDA PATLIYORDU.
-- Aşağıdaki DO bloğu `pg_extension`ı doğru kontrol ediyordu, ama
-- dosyanın SONUNDAKİ rapor sorgusu `cron.job`a DOĞRUDAN bakıyordu.
-- PostgreSQL sorguyu bütün olarak AYRIŞTIRIR: `case when` içinde bile
-- olsa, olmayan bir şemaya yapılan başvuru ayrıştırma anında hata
-- verir. Yani koruma vardı ama korumanın kapsamadığı bir yer kalmıştı.
--
-- Sonucu görünmezdi çünkü Supabase'te pg_cron VAR: dosya canlıda
-- çalışıyor, YEREL ve TEST ortamlarında düşüyordu — ve düştüğü için
-- `npm run e2e`nin alan denetimi haftalardır hiç ölçüm yapamıyordu.
--
-- 🆕 SINIF: "YALNIZ ÜRETİMDE VAR OLAN BİR EKLENTİYE DOĞRUDAN BAŞVURAN
-- HER SORGU, ÜRETİM DIŞINDAKİ HER ORTAMI SESSİZCE KÖR EDER."
create or replace function public.cron_isi_var(p_ad text)
returns boolean language plpgsql stable as $ci$
declare v boolean;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    return false;
  end if;
  execute 'select exists (select 1 from cron.job where jobname = $1)'
    into v using p_ad;
  return coalesce(v, false);
end $ci$;

do $cr$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('loungelink_bayat_istek')
      where exists (select 1 from cron.job where jobname = 'loungelink_bayat_istek');
    perform cron.schedule('loungelink_bayat_istek', '15 * * * *',
                          $q$select public.bayat_istekleri_iade_et();$q$);
    raise notice '274: bayat istek isi saatlik zamanlandi';
  else
    raise notice '274: pg_cron yok — is zamanlanmadi';
  end if;
end $cr$;


-- ════════════════════════════════════════════════════════════════════════
-- §6 — NÖBETÇİ + SONUÇ TABLOSU
--
-- Supabase yalnız SON sorgunun tablosunu gösterir; bu yüzden tek tablo.
-- ════════════════════════════════════════════════════════════════════════
select * from (
  select 1::int as s, 'Kapatilan bayat istek (bu kosuda)' as "kontrol",
         (select count(*)::text from requests
           where decision_note like '%274%') as "deger",
         '—' as "durum"
  union all
  select 2, 'Hala kilitli gorunen hesap (canli sayimla)',
         (select count(*)::text from (
            select r.guest_id
              from requests r join availabilities a on a.id = r.avail_id
             where r.status = 'pending' and a.avail_date >= current_date
               and r.created_at >= now() - interval '72 hours'
             group by r.guest_id having count(*) >= 1
         ) x),
         'bilgi — tavan asilmadikca sorun degil'
  union all
  select 3, 'Zamanlanmis is: loungelink_bayat_istek',
         case when exists (select 1 from pg_extension where extname='pg_cron')
                   and public.cron_isi_var('loungelink_bayat_istek')
              then 'var' else 'YOK' end,
         case when exists (select 1 from pg_extension where extname='pg_cron')
                   and public.cron_isi_var('loungelink_bayat_istek')
              then '✅ saatlik kosacak' else '⚠️ pg_cron yok ya da kurulamadi' end
  union all
  select 4, 'Tavan sayaci zaman kisitli mi',
         case when (select pg_get_functiondef(p.oid) from pg_proc p
                     join pg_namespace n on n.oid=p.pronamespace
                    where n.nspname='public' and p.proname='trg_acik_istek_tavani')
                   like '%avail_date >= current_date%'
              then 'evet' else 'HAYIR' end,
         case when (select pg_get_functiondef(p.oid) from pg_proc p
                     join pg_namespace n on n.oid=p.pronamespace
                    where n.nspname='public' and p.proname='trg_acik_istek_tavani')
                   like '%avail_date >= current_date%'
              then '✅ eski istekler tavani doldurmuyor'
              else '❌ 274 §2 kurulmamis' end
  union all
  select 5, 'Vitrin ile kapi ayni kosulu mu kullaniyor',
         case when (select pg_get_functiondef(p.oid) from pg_proc p
                     join pg_namespace n on n.oid=p.pronamespace
                    where n.nspname='public' and p.proname='acik_istek_tavanim')
                   like '%avail_date >= current_date%'
              then 'evet' else 'HAYIR' end,
         case when (select pg_get_functiondef(p.oid) from pg_proc p
                     join pg_namespace n on n.oid=p.pronamespace
                    where n.nspname='public' and p.proname='acik_istek_tavanim')
                   like '%avail_date >= current_date%'
              then '✅ cip kapiyla ayni' else '❌ 274 §3 kurulmamis' end
  union all
  select 6, 'Supurucu kapatmayi krediden ayirdi mi',
         case when (select pg_get_functiondef(p.oid) from pg_proc p
                     join pg_namespace n on n.oid=p.pronamespace
                    where n.nspname='public' and p.proname='bayat_istekleri_iade_et')
                   not like '%and exists (select 1 from credit_ledger cl%where cl.ref_id = req.id and cl.reason = ''request_hold''%'
              then 'evet' else 'HAYIR' end,
         '✅ ucretsiz istekler de kapaniyor'
) x order by s;
