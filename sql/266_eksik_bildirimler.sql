-- ============================================================================
-- 266 — EKSİK BİLDİRİMLER: MESAJ · HATIRLATMA · ALICI DİLİ  (28 Ağustos 2026)
--
-- 265'ten SONRA çalıştır.
--
-- ----------------------------------------------------------------------------
-- 🔴 BULGU 1 — YENİ MESAJ HİÇBİR BİLDİRİM ÜRETMİYORDU
-- ----------------------------------------------------------------------------
-- Bildirim envanterini çıkardım: 41 fonksiyonda 62 bildirim yazma noktası
-- var. İstek, oturum, bağlantı, kredi, plan, ödül, SOS — hepsi kapsanmış.
--
-- `messages` tablosunda ise TEK tetikleyici var ve o bir İÇERİK SÜZGECİ
-- (`trg_sohbet_suzgeci`). Yani **yeni mesaj hiçbir bildirim üretmiyor.**
--
-- Bu, ürünün en kritik boşluğu. Düşün: misafirin isteği kabul edildi,
-- sohbet açıldı, ikisi de havalimanında ve buluşmaları gerekiyor.
-- "A7 kapısındayım, lacivert ceket" mesajı gidiyor — ve karşı taraf
-- uygulamayı o an açık tutmuyorsa **hiçbir şey olmuyor.**
--
-- Ürünün tamamı bu buluşmayı gerçekleştirmek için var; buluşmanın son
-- 10 metresi bildirimsiz.
--
-- 🆕 SINIF: "BİR ÜRÜNÜN BİLDİRİM ENVANTERİ, EN ÇOK BİLDİRİM ÜRETEN
-- OLAYLARLA DEĞİL, BİLDİRİM GELMEZSE İŞİN YARIM KALDIĞI OLAYLARLA
-- ÖLÇÜLÜR."
--
-- ----------------------------------------------------------------------------
-- 🔴 BULGU 2 — BİLDİRİM METİNLERİ YALNIZCA TÜRKÇEYDİ
-- ----------------------------------------------------------------------------
-- 62 yazma noktasının tamamında başlık/gövde Türkçe sabit. İngilizce
-- kullanan biri app'i İngilizce görüyor ama telefonuna Türkçe bildirim
-- düşüyordu.
--
-- ⚠️ VE BUNU 62 YERDE DÜZELTMEK YANLIŞ OLURDU: `dili_ayarla()` İŞLEM
-- YERELDİR. Bildirim, BAŞKASININ işleminde yazılıyor — misafir istek
-- gönderirken host'un bildirimi yazılıyor. `aktif_dil()` orada
-- MİSAFİRİN dilini döndürür ve host yanlış dilde bildirim alır.
--
-- 🆕 SINIF: "BİR BİLDİRİMİN DİLİ, ONU YAZAN İŞLEMİN DEĞİL ONU OKUYACAK
-- KİŞİNİN DİLİDİR — İSTEK BAĞLAMINDAN OKUNAN HER TERCİH, ÜÇÜNCÜ KİŞİYE
-- YANLIŞ UYGULANIR."
--
-- Çözüm tek yerde: çeviri `notify_push()` içinde, ALICININ `profiles.dil`
-- değerine göre yapılıyor. 62 çağrı yerinin hiçbirine dokunulmadı.
-- Karşılığı olmayan metin Türkçe kalır — yani en kötü ihtimalle bugünkü
-- davranış.
--
-- ----------------------------------------------------------------------------
-- 🔴 BULGU 3 — İKİ HATIRLATMA HİÇ YOKTU
-- ----------------------------------------------------------------------------
--   · Oturum tamamlandı ama kimse puanlamadı → güven puanı sisteminin
--     girdisi hiç gelmiyor. 24 saat sonra tek hatırlatma.
--   · Yarın lounge günü olan misafirin kabul edilmiş bir isteği var →
--     unutmaması için sabah hatırlatması.
-- İkisi de `zamanli_isler` üzerinden koşuyor (cron varsa otomatik).
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — YENİ MESAJ BİLDİRİMİ
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.trg_mesaj_bildirimi()
returns trigger language plpgsql security definer set search_path = public as $mb266$
declare
  v_alici  uuid;
  v_gonderen_ad text;
  v_ozet   text;
  v_kind   text;
  v_ref    uuid;
begin
  -- Kanal iki türden biri: `lounge` (istek sohbeti) ya da `companion`
  -- (bağlantı sohbeti). İkisinde de karşı tarafı bulmak farklı.
  select c.kind, c.request_id, c.connection_id into v_kind, v_ref, v_alici
    from chat_channels c where c.id = NEW.channel_id;

  if coalesce(v_kind, 'lounge') = 'companion' then
    select case when cr.from_id = NEW.from_id then cr.to_id else cr.from_id end
      into v_alici
      from connection_requests cr where cr.id = v_alici;
  else
    select case when r.host_id = NEW.from_id then r.guest_id else r.host_id end
      into v_alici
      from requests r
      join chat_channels c on c.request_id = r.id
     where c.id = NEW.channel_id;
  end if;

  if v_alici is null or v_alici = NEW.from_id then
    return NEW;                       -- alıcı çözülemedi ya da kendine mesaj
  end if;

  -- 🔴 GÖNDERENİN ADI GÖSTERİLİYOR AMA MESAJ İÇERİĞİ **KISALTILARAK**.
  -- Kilit ekranı herkese açıktır: buluşma yerini ("A7 kapısındayım")
  -- tam metin olarak kilit ekranına basmak, kullanıcının konumunu
  -- omzundan bakan herkese vermektir.
  --
  -- 🆕 SINIF: "BİR BİLDİRİMİN GÖVDESİ KİLİT EKRANIDIR — ORAYA
  -- KOYULABİLECEK ŞEY, YANINDAKİ YABANCIYA GÖSTERİLEBİLECEK ŞEYDİR."
  select coalesce(nullif(btrim(p.name), ''), 'Bir kullanıcı')
    into v_gonderen_ad from profiles p where p.user_id = NEW.from_id;

  v_ozet := left(regexp_replace(coalesce(NEW.body, ''), '\s+', ' ', 'g'), 60);
  if length(coalesce(NEW.body, '')) > 60 then v_ozet := v_ozet || '…'; end if;

  -- ⚠️ GÜRÜLTÜ KAPISI: aynı sohbette son 2 dakikada zaten okunmamış bir
  -- mesaj bildirimi varsa yenisini yazma. Hızlı yazışan iki kişi
  -- telefonu titretmeye devam ederse kullanıcı bildirimi komple kapatır
  -- — ve o zaman ASIL bildirimleri de kaybederiz.
  if exists (
    select 1 from notifications n
     where n.user_id = v_alici
       and n.ref_type = 'message'
       and n.ref_id = NEW.channel_id
       and not n.read
       and n.created_at > now() - interval '2 minutes')
  then
    return NEW;
  end if;

  insert into notifications (user_id, category, title, body, ref_id, ref_type)
  values (v_alici, 'sessions',
          v_gonderen_ad || ' yazdı',
          v_ozet,
          NEW.channel_id, 'message');
  return NEW;
exception when others then
  -- 🔴 BİLDİRİM, MESAJI DÜŞÜREMEZ. Süzgeç için yazdığımız aynı ilke.
  raise warning 'trg_mesaj_bildirimi: % / %', sqlstate, sqlerrm;
  return NEW;
end $mb266$;

drop trigger if exists trg_mesaj_bildirimi on messages;
create trigger trg_mesaj_bildirimi after insert on messages
  for each row execute function public.trg_mesaj_bildirimi();

-- ════════════════════════════════════════════════════════════════════════
-- §2 — ALICININ DİLİNDE PUSH
--
-- Çeviri tablosu: Türkçe metin → İngilizce karşılığı. `notify_push()`
-- alıcının `profiles.dil` değeri 'en' ise çeviriyi uygular.
-- ════════════════════════════════════════════════════════════════════════
create table if not exists push_ceviri (
  tr text primary key,
  en text not null
);
alter table push_ceviri enable row level security;
revoke all on push_ceviri from anon, authenticated;

insert into push_ceviri (tr, en) values
  ('İstek kabul edildi! 🎉',        'Request accepted! 🎉'),
  ('İstek reddedildi',              'Request declined'),
  ('Yeni istek ✦',                  'New request ✦'),
  ('Bir misafir lounge isteği gönderdi.', 'A guest sent a lounge request.'),
  ('Yeni bağlantı isteği ◈',        'New connection request ◈'),
  ('Bir yolcu seninle bağlantı kurmak istiyor.', 'A traveller wants to connect with you.'),
  ('Bağlantı kabul edildi ✓',       'Connection accepted ✓'),
  ('Sohbet açıldı.',                'Chat is open.'),
  ('Oturum başladı ⏱',              'Session started ⏱'),
  ('Oturum tamamlandı ✓',           'Session completed ✓'),
  ('Oturum iptal edildi',           'Session cancelled'),
  ('Oturum onayı bekleniyor',       'Waiting for session confirmation'),
  ('Oturum başlatılmayı bekliyor',  'Waiting to start the session'),
  ('Kredin iade edildi',            'Your credit was refunded'),
  ('Kredin yüklendi',               'Credits added'),
  ('Kredi tanımlandı ✦',            'Credits granted ✦'),
  ('Aylık kredin yüklendi ✓',       'Your monthly credits are in ✓'),
  ('Hoş geldin ✦',                  'Welcome ✦'),
  ('Lounge daveti ✦',               'Lounge invitation ✦'),
  ('Davetin kabul edildi ✓',        'Your invitation was accepted ✓'),
  ('Davetin yanıtlandı',            'Your invitation was answered'),
  ('Davet reddedildi.',             'The invitation was declined.'),
  ('Başvurun alındı ✦',             'Application received ✦'),
  ('Host başvurun onaylandı ✦',     'You are approved as a host ✦'),
  ('Host başvurun sonuçlandı',      'Your host application was reviewed'),
  ('Havalimanında host var! ✦',     'There is a host at your airport! ✦'),
  ('Plan güncellendi 🎉',           'Plan updated 🎉'),
  ('İtirazın sonuçlandı',           'Your dispute was resolved'),
  ('Talebin alındı ✦',              'Your request was received ✦'),
  ('Kredi talebin alındı',          'Your credit request was received'),
  ('İlan kaldırıldı',               'Listing removed'),
  ('Başvurduğun ilan güncellendi',  'A listing you applied to has changed'),
  ('Beklediğin gün için ilan açıldı','A listing opened for the day you wanted'),
  ('Misafir hakkın soruluyor ◈',    'Someone is asking about your guest access ◈'),
  ('Soru iletildi ✦',               'Your question was delivered ✦'),
  ('Ödülün gönderildi 🎁',          'Your reward was sent 🎁'),
  ('Puanın iade edildi',            'Your points were returned'),
  ('Ücretsiz ayın doldu',           'Your free month has ended'),
  ('Plan hediyen kapatıldı',        'Your plan gift was closed'),
  ('SOS çağrısı',                   'SOS alert'),
  ('E-posta adresin güncellendi',   'Your email address was updated'),
  ('Telefon numaran güncellendi',   'Your phone number was updated'),
  ('Kredi yetersiz',                'Not enough credits'),
  ('Teşekkür kredisi',              'Thank-you credit'),
  ('Sana misafir hakkı hediye edildi ✦', 'Someone gifted you guest access ✦'),
  ('Sorduğun host hakkını güncelledi ✦', 'The host you asked has declared their access ✦'),
  ('Puanlamayı unutma ✦',           'Don''t forget to rate ✦'),
  ('Yarın lounge günün ✈',          'Your lounge day is tomorrow ✈')
on conflict (tr) do update set en = excluded.en;

-- 🔴 `notify_push()` YENİDEN YAZILIYOR — 210b'nin iki dayanıklılık
-- katmanı (şema yoksa deneme · her hata yutulur ama loglanır) AYNEN
-- korunuyor. Eklenen tek şey alıcı dili.
create or replace function public.notify_push()
returns trigger language plpgsql security definer set search_path = public as $np266$
declare
  v_body  jsonb;
  v_quiet boolean := false;
  v_dil   text;
  v_baslik text;
  v_govde  text;
  v_req   bigint;
begin
  begin
    select coalesce(
             (n.prefs -> NEW.category::text ->> 'push')::boolean = false, false)
      into v_quiet
      from notification_prefs n where n.user_id = NEW.user_id;
  exception when undefined_table or undefined_column then
    v_quiet := false;
  end;
  if v_quiet then return NEW; end if;

  -- ALICININ dili. `aktif_dil()` DEĞİL: o, bildirimi YAZAN işlemin dili.
  begin
    select lower(coalesce(p.dil, 'tr')) into v_dil
      from profiles p where p.user_id = NEW.user_id;
  exception when others then v_dil := 'tr';
  end;

  v_baslik := coalesce(NEW.title, 'LoungeLink');
  v_govde  := coalesce(NEW.body, '');
  if coalesce(v_dil, 'tr') = 'en' then
    -- Karşılığı yoksa Türkçe kalır: çeviri eksikliği bildirimi düşürmez.
    v_baslik := coalesce((select en from push_ceviri where tr = v_baslik), v_baslik);
    v_govde  := coalesce((select en from push_ceviri where tr = v_govde),  v_govde);
  end if;

  select jsonb_agg(jsonb_build_object(
           'to', t.token,
           'title', v_baslik,
           'body', v_govde,
           'sound', 'default',
           'channelId', 'default',
           'priority', 'high',
           'data', jsonb_build_object(
                     'category', NEW.category,
                     'ref_type', NEW.ref_type,
                     'ref_id',   NEW.ref_id,
                     'notification_id', NEW.id)))
    into v_body
    from push_tokens t
   where t.user_id = NEW.user_id
     and coalesce(t.active, true)
     and coalesce(t.token,'') like 'ExponentPushToken%';

  if v_body is null then return NEW; end if;

  if to_regnamespace('net') is null then
    raise warning 'notify_push: pg_net kurulu degil, push atlandi (bildirim kaydi DURUYOR)';
    return NEW;
  end if;

  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 GÖNDERİM DEFTERİ — VE BURADA KENDİ HATAMI DÜZELTİYORUM.
  --
  -- SQL 257 `notify_push`i METİN OLARAK YAMALIYORDU: `perform
  -- net.http_post(...)` çağrısını `select ... into v_req`e çevirip
  -- altına `push_gonderimleri` kaydı ekliyordu. Amaç Expo'nun MAKBUZUNU
  -- okuyabilmek: `DeviceNotRegistered` dönen token'ı pasife almak.
  --
  -- Bu dosyanın ilk hâli `notify_push`i SIFIRDAN yeniden yazdı ve
  -- 257'nin yamasını SESSİZCE GERİ ALDI. Ölçtüm ve doğruladım:
  --     select pg_get_functiondef(...) like '%push_gonderimleri%'  → f
  --
  -- Sonucu şu olurdu: silinmiş uygulamaların token'ları sonsuza kadar
  -- "aktif" kalır, her bildirimde onlara da gönderilir ve sağlık
  -- raporundaki "ULAŞILABİLEN kişi" sayısı zamanla YALAN SÖYLER.
  --
  -- 🆕 SINIF: "BİR FONKSİYONU YENİDEN YAZARKEN, ONA SONRADAN YAMA
  -- ATMIŞ DOSYALARI DA OKUMAK ZORUNDASIN — YAMA, KAYNAK DOSYADA
  -- GÖRÜNMEZ."
  --
  -- Ve kalıcı çözüm yamayı tekrar uygulamak DEĞİL, defteri buraya
  -- ASIL GÖVDEYE yazmak: metin yaması her yeniden yazımda tekrar
  -- düşecek bir bağımlılıktır.
  begin
    if to_regclass('public.push_gonderimleri') is not null then
      select net.http_post(
        url     := 'https://exp.host/--/api/v2/push/send',
        headers := jsonb_build_object('Content-Type', 'application/json',
                                      'Accept', 'application/json'),
        body    := v_body) into v_req;
      insert into push_gonderimleri (notification_id, user_id, net_request_id, token_sayisi)
      values (NEW.id, NEW.user_id, v_req, jsonb_array_length(v_body));
    else
      -- Defter yoksa (257 çalıştırılmamış) gönderim yine yapılır.
      perform net.http_post(
        url     := 'https://exp.host/--/api/v2/push/send',
        headers := jsonb_build_object('Content-Type', 'application/json',
                                      'Accept', 'application/json'),
        body    := v_body);
    end if;
  exception when others then
    raise warning 'notify_push: push gonderilemedi (% / %) — bildirim kaydi DURUYOR',
      sqlstate, sqlerrm;
  end;
  return NEW;
end $np266$;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — PUANLAMA HATIRLATMASI
--
-- Oturum tamamlandı, 24 saat geçti, kimse puanlamadı. Güven puanı bu
-- ürünün tek güvenlik mekanizması; girdisi gelmezse sistem kördür.
-- Kişi başına TEK hatırlatma: ikincisi rahatsızlıktır.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.puanlama_hatirlat()
returns jsonb language plpgsql security definer set search_path = public as $ph266$
declare v_n int := 0; r record;
begin
  for r in
    select s.id as session_id, x.uid
      from sessions s
      join requests q on q.id = s.request_id
      cross join lateral (values (q.host_id), (q.guest_id)) as x(uid)
     where s.status = 'completed'
       and s.completed_at between now() - interval '7 days' and now() - interval '24 hours'
       and not exists (select 1 from ratings ra
                        where ra.session_id = s.id and ra.rater_id = x.uid)
       and not exists (select 1 from notifications n
                        where n.user_id = x.uid and n.ref_type = 'rate_reminder'
                          and n.ref_id = s.id)
  loop
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (r.uid, 'ratings', 'Puanlamayı unutma ✦',
            'Dün tamamladığın oturumu puanlarsan karşı tarafın güven puanı oluşur.',
            r.session_id, 'rate_reminder');
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'hatirlatilan', v_n);
end $ph266$;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — YARINKİ LOUNGE GÜNÜ HATIRLATMASI
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.yarinki_lounge_hatirlat()
returns jsonb language plpgsql security definer set search_path = public as $yl266$
declare v_n int := 0; r record;
begin
  for r in
    select q.id as req_id, x.uid, a.airport_code, a.time_from
      from requests q
      join availabilities a on a.id = q.avail_id
      cross join lateral (values (q.host_id), (q.guest_id)) as x(uid)
     where q.status = 'accepted'
       and a.avail_date = current_date + 1
       and not exists (select 1 from notifications n
                        where n.user_id = x.uid and n.ref_type = 'trip_reminder'
                          and n.ref_id = q.id)
  loop
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (r.uid, 'sessions', 'Yarın lounge günün ✈',
            r.airport_code || ' · ' || coalesce(to_char(r.time_from, 'HH24:MI'), '')
              || ' — buluşmadan önce sohbetten haberleşin.',
            r.req_id, 'trip_reminder');
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'hatirlatilan', v_n);
end $yl266$;

-- İkisi de zamanlanmış iş defterine giriyor (265'te `zamanli_is_kos`
-- service_role'a kilitlendi; cron postgres olarak koşar).
-- ⚠️ `beklenen_saat` = bu iş en fazla kaç saatte bir koşmalı. 251'in
-- cron nöbetçisi bu değeri okuyup "iş gecikti mi" diye bakıyor; NULL
-- bırakmak nöbetçiyi kör ederdi (tablo zaten NOT NULL diyor ve haklı).
insert into zamanli_isler (is_adi, beklenen_saat, aciklama) values
  ('puanlama_hatirlat', 26,
   'Tamamlanan oturum 24 saattir puanlanmadiysa TEK hatirlatma (266)'),
  ('yarinki_lounge_hatirlat', 26,
   'Yarin lounge gunu olan kabul edilmis istekler icin hatirlatma (266)')
on conflict (is_adi) do nothing;

revoke execute on function public.puanlama_hatirlat()        from public, anon, authenticated;
revoke execute on function public.yarinki_lounge_hatirlat()  from public, anon, authenticated;
grant  execute on function public.puanlama_hatirlat()        to service_role;
grant  execute on function public.yarinki_lounge_hatirlat()  to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §4b — HEDEF ÇÖZÜCÜ: `ref_type` DE OKUNUYOR
--
-- 🔴 `bildirim_hedefi` YALNIZ KATEGORİYE bakıyordu. Mesaj bildirimi
-- `category='sessions'` taşıyor — yani dokununca "İlanlarım"a giderdi.
-- Oysa mesaj bildiriminin tek doğru hedefi SOHBETİN KENDİSİDİR.
--
-- 🆕 SINIF: "BİR YÖNLENDİRME TABLOSU TEK ALANA BAKIYORSA, O ALANI
-- PAYLAŞAN İKİNCİ BİR OLAY EKLENDİĞİ GÜN SESSİZCE YANLIŞ YERE GÖNDERİR."
--
-- Yeni hatırlatmalar da burada: puanlama → Değerlendirmeler,
-- yarınki gün → Planım.
create or replace function public.bildirim_hedefi(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $bh266$
declare v_uid uuid := auth.uid(); n record;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into n from notifications where id = p_id and user_id = v_uid;
  if n.id is null then return jsonb_build_object('ekran', null); end if;

  -- ÖNCE ref_type: en özel eşleşme kazanır.
  if n.ref_type = 'message' then
    return jsonb_build_object('ekran', 'sohbet', 'ref', n.ref_id);
  elsif n.ref_type = 'rate_reminder' then
    return jsonb_build_object('ekran', 'degerlendirmeler', 'ref', n.ref_id);
  elsif n.ref_type = 'trip_reminder' then
    return jsonb_build_object('ekran', 'plan', 'alt', 'seyahat', 'ref', n.ref_id);
  end if;

  return case n.category::text
    when 'requests'    then jsonb_build_object('ekran','plan','alt','ilan','ref', n.ref_id)
    when 'sessions'    then jsonb_build_object('ekran','plan','alt','ilan','ref', n.ref_id)
    when 'invites'     then jsonb_build_object('ekran','plan','alt','seyahat','ref', n.ref_id)
    when 'connections' then jsonb_build_object('ekran','tanis','ref', n.ref_id)
    when 'credits'     then jsonb_build_object('ekran','cuzdan')
    when 'ratings'     then jsonb_build_object('ekran','degerlendirmeler','ref', n.ref_id)
    when 'safety'      then jsonb_build_object('ekran','guvenlik')
    else jsonb_build_object('ekran', null) end;
end $bh266$;

grant execute on function public.bildirim_hedefi(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — NÖBETÇİ
--
-- 🔴 "Tetikleyici kuruldu" ile "bildirim üretiliyor" aynı şey değil.
-- Nöbetçi GERÇEK BİR MESAJ yazıp bildirimin doğduğunu görüyor, sonra
-- geri alıyor.
-- ════════════════════════════════════════════════════════════════════════
do $nb266$
declare
  v_host uuid; v_guest uuid; v_av uuid; v_req uuid; v_ch uuid;
  v_once int; v_sonra int; v_dil_ok boolean;
begin
  -- Çeviri katmanı yerinde mi
  select exists (select 1 from push_ceviri where tr = 'Yeni istek ✦') into v_dil_ok;
  if not v_dil_ok then
    raise exception '266 NOBETCI: push_ceviri bos — dil katmani kurulmadi.';
  end if;

  if not exists (select 1 from pg_trigger tg join pg_class c on c.oid = tg.tgrelid
                  where c.relname='messages' and tg.tgname='trg_mesaj_bildirimi') then
    raise exception '266 NOBETCI: mesaj bildirim tetikleyicisi kurulmadi.';
  end if;

  -- ══════════════════════════════════════════════════════════════════
  -- GERÇEK AKIŞ DENEMESİ — ALT İŞLEMDE, HER HÂLÜKÂRDA GERİ ALINIYOR.
  --
  -- 🔴 İLK YAZIMIM DENEME KAYITLARINI `delete` İLE TEMİZLİYORDU ve
  -- sıfırdan kurulan bir veritabanında PATLADI:
  --     ERROR: update or delete on table "requests" violates foreign key
  --            constraint "sessions_request_id_fkey"
  -- Çünkü `requests` satırını eklediğim anda bir tetikleyici `sessions`
  -- satırı da üretiyor; benim temizliğim onu bilmiyordu. Yani nöbetçi,
  -- ölçtüğü sistemin kendi yan etkilerini takip etmek zorunda kalıyordu.
  --
  -- 🆕 SINIF: "BİR TESTİN TEMİZLİĞİNİ ELLE YAZARSAN, TEST ETTİĞİN
  -- SİSTEMİN HER YENİ YAN ETKİSİNİ DE ELLE TAKİP ETMEK ZORUNDA
  -- KALIRSIN — GERİ ALMAYI VERİTABANINA BIRAK."
  --
  -- PL/pgSQL'de `begin ... exception` bir ALT İŞLEM açar. Sonunda
  -- bilerek istisna fırlatıyoruz: alt işlem geri alınır, ne eklediysek
  -- (tetikleyicilerin ürettikleri dahil) yok olur.
  begin
    select id into v_host  from users order by created_at limit 1;
    select id into v_guest from users where id <> v_host order by created_at limit 1;
    if v_host is null or v_guest is null then
      raise notice '266 NOBETCI: iki kullanici yok, canli akis denemesi ATLANDI.';
    else
      insert into availabilities (host_id, airport_code, avail_date, time_from, time_to, slots, active)
      values (v_host, (select code from airports limit 1), current_date + 3, '10:00', '12:00', 1, true)
      returning id into v_av;
      insert into requests (avail_id, guest_id, host_id, status)
      values (v_av, v_guest, v_host, 'accepted') returning id into v_req;
      insert into chat_channels (request_id, kind) values (v_req, 'lounge') returning id into v_ch;

      select count(*) into v_once from notifications
       where user_id = v_host and ref_type = 'message';
      insert into messages (channel_id, from_id, body) values (v_ch, v_guest, 'A7 kapisindayim');
      select count(*) into v_sonra from notifications
       where user_id = v_host and ref_type = 'message';

      if v_sonra <= v_once then
        raise exception '266 NOBETCI KIRMIZI: mesaj yazildi ama BILDIRIM URETILMEDI (% → %).', v_once, v_sonra;
      end if;
      raise notice '266 NOBETCI: mesaj → bildirim zinciri CALISIYOR (% → %).', v_once, v_sonra;
    end if;
    -- Denemeyi geri al.
    raise exception 'NOBETCI_GERI_AL';
  exception
    when others then
      if sqlerrm <> 'NOBETCI_GERI_AL' then raise; end if;
  end;

  raise notice '266 NOBETCI OK: mesaj bildirimi · alici dili · iki hatirlatma · hedef cozucu.';
end $nb266$;

-- (Nöbetçinin deneme kayıtları artık ALT İŞLEMDE geri alınıyor — yukarıya
--  bak. Elle `delete` yazan eski blok kaldırıldı: `requests` silmek
--  tetikleyicinin ürettiği `sessions` satırına takılıyordu ve nöbetçi,
--  ölçtüğü sistemin yan etkilerini takip etmek zorunda kalıyordu.)

commit;
