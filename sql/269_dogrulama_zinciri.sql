-- ============================================================================
-- 269 — DOĞRULAMA ZİNCİRİ: PUAN, KAYNAK VE KANAL   (28 Ağustos 2026)
--
-- ⚠️ 268'den SONRA çalıştır.
--
-- ----------------------------------------------------------------------------
-- 🔴 GÖKBERK: "E-posta ve telefon doğrulamalarımız gerçekten çalışıyor mu?
--    Doğrulama sonrasında puanını hemen veriyor muyuz? Bu kritik bence."
--
-- Haklı. Zinciri uçtan uca açtım. ÜÇ kırık halka var, ikisi ciddi.
-- ----------------------------------------------------------------------------
--
-- ══════════════════════════════════════════════════════════════════════════
-- BULGU 1 — E-POSTA DOĞRULAMASI SIFIR PUAN GETİRİYOR.
-- ══════════════════════════════════════════════════════════════════════════
-- `recompute_trust` gövdesi:
--
--     v_c := v_c || '{"email":10}'::jsonb;                          ← KOŞULSUZ
--     if coalesce(v_v.phone_verified,false) then … '{"phone":10}' … ← koşullu
--     if coalesce(v_v.id_verified,false)    then … '{"id":18}'   … ← koşullu
--
-- E-posta bileşeni HİÇBİR ŞEYE BAĞLI DEĞİL. Deney (geri alındı):
--
--     hiç doğrulama yok     → puan 10
--     e-posta doğrulandı    → puan 10   (fark 0)
--     telefon da doğrulandı → puan 20   (fark 10)
--
-- Yani kullanıcı e-postasını doğrulamak için ekrandan geçiyor, kod giriyor,
-- "✓ doğrulandı" görüyor — ve puanı KIPIRDAMIYOR. Puan zaten verilmişti.
-- Ürün, yapılmamış bir işin karşılığını peşin ödüyor ve yapılan işin
-- karşılığını hiç ödemiyor.
--
-- 🆕 SINIF: "KOŞULSUZ VERİLEN BİR PUAN, O PUANI KAZANDIRAN EYLEMİ
-- ANLAMSIZLAŞTIRIR — KULLANICI EMEĞİNİN KARŞILIĞINI DEĞİL, HİÇBİR ŞEYİN
-- KARŞILIĞINI GÖRÜR."
--
-- ══════════════════════════════════════════════════════════════════════════
-- BULGU 2 — VE SEBEBİ: AYNI GERÇEĞİN İKİ KAYNAĞI VAR.
-- ══════════════════════════════════════════════════════════════════════════
-- "Bu kullanıcının e-postası doğrulanmış mı?" sorusunun İKİ cevabı var:
--
--   `auth.users.email_confirmed_at`   → Supabase'in kendi gerçeği. Kayıt
--                                        onay maili tıklanınca dolar.
--   `verifications.email_verified`    → BİZİM tablomuz. YALNIZCA kullanıcı
--                                        "Telefonu Doğrula" ekranına girip
--                                        e-posta yolunu seçerse yazılır.
--
-- Kayıt olan herkes birinciyi doldurur; ikinciyi neredeyse kimse
-- doldurmaz. `recompute_trust` ikinciye baksaydı doğrulanmış kullanıcılar
-- 10 puan kaybederdi — o yüzden birileri koşulu KALDIRMIŞ. Yani BULGU 1,
-- BULGU 2'nin üstünü örten bir yamaymış.
--
-- 🆕 SINIF: "BİR KOŞUL 'HERKESİ YANLIŞ CEZALANDIRDIĞI İÇİN' KALDIRILDIYSA,
-- ASIL SORUN KOŞULDA DEĞİL BAKTIĞI KAYNAKTADIR — YANLIŞ KAYNAĞA BAKAN BİR
-- KURAL, KURALI SİLEREK DEĞİL KAYNAĞI DÜZELTEREK ONARILIR."
--
-- ÇÖZÜM: TEK KAYNAK. `auth.users.email_confirmed_at` gerçektir; bizim
-- tablomuz onun AYNASI olur ve aynayı bir tetikleyici güncel tutar.
--
-- ══════════════════════════════════════════════════════════════════════════
-- BULGU 3 — `otp_channel` AYARINI HİÇBİR YER OKUMUYOR.
-- ══════════════════════════════════════════════════════════════════════════
--     select key, value from beta_settings where key like '%otp%';
--     → otp_channel | "email"
--
-- Ürün "doğrulama kanalı e-posta" diyor. Uygulama ise telefon numarası
-- ekranını açıyor, "Kodu gönder" düğmesi gösteriyor ve kod ekranına
-- geçiyor. `send_otp` kodu üretip SAKLIYOR ama HİÇBİR YERE GÖNDERMİYOR —
-- depoda tek bir SMS sağlayıcı çağrısı yok (`009_phone_otp.sql`de
-- "ileride Netgsm/Twilio eklenir" diye bir yorum var, eklenmemiş).
--
-- Yani kullanıcı 8 ayrı ekrandan bu akışa yönlendiriliyor, kod ekranına
-- düşüyor ve ASLA GELMEYECEK bir SMS'i bekliyor.
--
-- 🆕 SINIF: "BİR AYAR HİÇBİR YERDEN OKUNMUYORSA, O AYAR BİR KARARIN KAYDI
-- DEĞİL BİR KARARIN MEZAR TAŞIDIR."
--
-- Bu dosya ayarı CANLI hâle getiriyor: istemci `service_endpoints` üzerinden
-- kanalı okuyacak (§4). SMS sağlayıcı bağlandığı gün ayar `sms` yapılır ve
-- yol UYGULAMA GÜNCELLEMESİ OLMADAN açılır.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — AYNAYI DOLDUR: `verifications.email_verified` GERÇEĞE EŞİTLENİYOR
--
-- 🔴 Bu bir "veri düzeltme" değil, BİR YALANIN GİDERİLMESİ. Backoffice
-- `verifications.email_verified` okuyor (kyc/page.jsx, users/[id]).
-- Bugün orada e-postasını çoktan onaylamış kullanıcılar "—" görünüyor.
-- BO'ya bakan insan yanlış bilgiyle karar veriyor.
-- ════════════════════════════════════════════════════════════════════════
insert into verifications (user_id, email_verified, email_verified_at)
select u.id, true, au.email_confirmed_at
  from users u
  join auth.users au on au.id = u.id
 where au.email_confirmed_at is not null
on conflict (user_id) do update
  set email_verified    = true,
      email_verified_at = coalesce(verifications.email_verified_at,
                                   excluded.email_verified_at);

-- ════════════════════════════════════════════════════════════════════════
-- §2 — AYNAYI GÜNCEL TUT: TETİKLEYİCİ
--
-- Kullanıcı onay bağlantısını YARIN tıklarsa da ayna dolsun. Tek yazıcı
-- kuralı korunuyor: puanı yalnız `recompute_trust` yazar, bu tetikleyici
-- yalnız bayrağı yazıp onu çağırır.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.trg_email_onayi_aynala()
returns trigger
language plpgsql security definer set search_path = public as $ea269$
begin
  if NEW.email_confirmed_at is not null
     and (OLD.email_confirmed_at is null) then
    insert into verifications (user_id, email_verified, email_verified_at)
    values (NEW.id, true, NEW.email_confirmed_at)
    on conflict (user_id) do update
      set email_verified = true,
          email_verified_at = coalesce(verifications.email_verified_at, excluded.email_verified_at);
    -- Puan ANINDA güncellensin: kullanıcı onay bağlantısına tıklayıp
    -- uygulamaya döndüğünde puanı çoktan artmış olmalı.
    perform public.recompute_trust(NEW.id);
  end if;
  return NEW;
end $ea269$;

drop trigger if exists on_auth_email_confirmed on auth.users;
create trigger on_auth_email_confirmed
  after update of email_confirmed_at on auth.users
  for each row execute function public.trg_email_onayi_aynala();

-- ════════════════════════════════════════════════════════════════════════
-- §3 — PUAN ARTIK KOŞULLU
--
-- `recompute_trust` metin üzerinden yamalanıyor: gövdenin tamamını
-- yeniden yazmak, aradan geçen 8 sürümün (rozet eşikleri, ceza mantığı,
-- oturum sayısı) üstüne yazma riski taşırdı.
--
-- ⚠️ Yamanın TUTTUĞU DOĞRULANIYOR: satır bulunamazsa dosya UYARI verir ve
-- hiçbir şey değiştirmez — sessizce "yaptım" demez.
-- 🆕 SINIF: "METİN ÜZERİNDEN YAMA, YAMANIN TUTTUĞUNU KANITLAMADIĞI SÜRECE
-- BİR DEĞİŞİKLİK DEĞİL BİR TEMENNİDİR."
-- ════════════════════════════════════════════════════════════════════════
do $rt269$
declare
  v_eski text; v_yeni text;
  v_ara  text := 'v_c := v_c || ''{"email":10}''::jsonb;';
  v_yer  text := 'if coalesce(v_v.email_verified,false) then'
              || ' v_c := v_c || ''{"email":10}''::jsonb; end if;';
begin
  select pg_get_functiondef(p.oid) into v_eski
    from pg_proc p where p.oid = to_regprocedure('public.recompute_trust(uuid)');
  if v_eski is null then
    raise exception '269 §3: recompute_trust YOK.';
  end if;

  if v_eski like '%coalesce(v_v.email_verified,false) then v_c%' then
    raise notice '269 §3: e-posta puani zaten kosullu — dokunulmadi.';
    return;
  end if;

  if position(v_ara in v_eski) = 0 then
    raise warning '269 §3: beklenen satir BULUNAMADI — recompute_trust ELLE bakilmali.';
    return;
  end if;

  v_yeni := replace(v_eski, v_ara, v_yer);
  execute v_yeni;
  raise notice '269 §3: e-posta puani artik dogrulamaya bagli. ✓';
end $rt269$;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — KANAL AYARI İSTEMCİYE AÇILIYOR
--
-- `service_endpoints` zaten istemcinin okuyabildiği (265 beyaz listesi)
-- ayar yüzeyi. Doğrulama kanalı oraya taşınıyor: uygulama artık
-- "SMS var mı" sorusunu KOD İÇİNDEN DEĞİL SUNUCUDAN öğrenecek.
--
-- Netgsm/Twilio bağlandığı gün yapılacak tek şey:
--     update beta_settings set value = to_jsonb('sms'::text) where key='otp_channel';
-- Uygulama güncellemesi GEREKMEZ.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.dogrulama_kanali()
returns jsonb
language sql stable security definer set search_path = public as $dk269$
  select jsonb_build_object(
    'kanal', coalesce((select value #>> '{}' from beta_settings where key = 'otp_channel'), 'email'),
    -- 🔴 `sms_hazir`: kanal 'sms' OLSA BİLE gönderici yoksa yalan söylemeyelim.
    -- Bugün gönderici yok; bu bayrak bir gönderici eklendiğinde
    -- `otp_sms_saglayici` ayarıyla açılacak.
    'sms_hazir', coalesce((select value #>> '{}' from beta_settings
                            where key = 'otp_sms_saglayici'), '') <> '',
    'not', coalesce((select value #>> '{}' from beta_settings
                      where key = 'otp_notice_phone_declared'), '')
  );
$dk269$;
revoke execute on function public.dogrulama_kanali() from public;
grant execute on function public.dogrulama_kanali() to authenticated, anon;

insert into beta_settings (key, value)
values ('otp_sms_saglayici', to_jsonb(''::text))
on conflict (key) do nothing;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — `send_otp` ARTIK SESSİZCE BAŞARILI OLMUYOR
--
-- 🔴 EN SİNSİ HALKA BURASIYDI. Fonksiyon kodu üretiyor, saklıyor ve
-- `{ok:true}` dönüyor. Uygulama `ok` görüp kod ekranına geçiyor.
-- Hiçbir yerde hata YOK — ama SMS de yok. Sistem "çalıştı" diyor,
-- kullanıcı boş ekrana bakıyor.
--
-- 🆕 SINIF: "GÖNDERMEYEN BİR GÖNDERİCİNİN 'TAMAM' DEMESİ, HATA VERMESİNDEN
-- DAHA KÖTÜDÜR — HATA GÖRÜLÜR, SESSİZ BAŞARI GÖRÜLMEZ."
--
-- Artık gönderici tanımlı değilse `sms_not_configured` fırlatıyor.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.send_otp(p_phone text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $so269$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_recent int;
  v_saglayici text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_phone !~ '^\+[1-9][0-9]{9,14}$' then raise exception 'bad_phone_format'; end if;

  -- 🔴 GÖNDERİCİ YOKSA BAŞTAN SÖYLE. Kod üretip saklamanın da anlamı yok:
  -- kimsenin okuyamayacağı bir kod, `otp_tokens` tablosunu şişiren bir
  -- kayıttan başka bir şey değil.
  select coalesce(value #>> '{}', '') into v_saglayici
    from beta_settings where key = 'otp_sms_saglayici';
  if coalesce(v_saglayici, '') = '' then
    raise exception 'sms_not_configured';
  end if;

  select count(*) into v_recent from otp_tokens
   where user_id = v_uid and created_at > now() - interval '1 minute';
  if v_recent >= 1 then raise exception 'too_many_requests'; end if;

  v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');

  update otp_tokens set used_at = now()
   where user_id = v_uid and used_at is null and purpose = 'phone_verify';

  insert into otp_tokens (user_id, phone_e164, code_hash, purpose, expires_at)
  values (v_uid, p_phone, crypt(v_code, gen_salt('bf')), 'phone_verify', now() + interval '5 minutes');

  -- ⚠️ SMS GÖNDERİMİ BURAYA GELECEK (Edge Function / pg_net → sağlayıcı).
  -- Kodu YANITTA DÖNDÜRME: 253 §3 tam olarak o arka kapıyı kapattı.
  return jsonb_build_object('ok', true, 'expires_in', 300);
end $so269$;
grant execute on function public.send_otp(text) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §6 — NÖBETÇİ: ZİNCİRİN HER HALKASI DENENİYOR
-- ════════════════════════════════════════════════════════════════════════
do $nb269$
declare
  u uuid; s0 int; s1 int; v_kanal jsonb; v_hata text := '';
begin
  select id into u from users where deleted_at is null order by id limit 1;
  if u is null then raise notice '269 NOBETCI: kullanici yok — atlandi.'; return; end if;

  -- (a) E-POSTA DOĞRULAMASI ARTIK PUAN GETİRİYOR
  insert into verifications (user_id, email_verified, phone_verified)
  values (u, false, false)
  on conflict (user_id) do update set email_verified=false, phone_verified=false;
  s0 := public.recompute_trust(u);
  update verifications set email_verified = true, email_verified_at = now() where user_id = u;
  s1 := public.recompute_trust(u);
  raise notice '269 NOBETCI: dogrulanmamis % → dogrulanmis %  (fark %)', s0, s1, s1 - s0;
  if s1 - s0 <> 10 then
    v_hata := v_hata || format('e-posta dogrulamasi %s puan getiriyor (10 olmali); ', s1 - s0);
  end if;

  -- (b) TERS YÖN: doğrulanmamış kullanıcı e-posta puanı ALMAMALI
  if (select (components ? 'email') from trust_scores where user_id = u) is null then
    v_hata := v_hata || 'trust_scores yazilmamis; ';
  end if;

  -- (c) SMS GÖNDERİCİSİ YOKKEN `send_otp` SESSİZCE BAŞARILI OLMAMALI
  begin
    perform public.send_otp('+905551112233');
    v_hata := v_hata || 'send_otp saglayici yokken OK donuyor; ';
  exception
    when sqlstate 'P0001' then
      if sqlerrm not in ('sms_not_configured', 'not_authenticated') then
        v_hata := v_hata || format('send_otp beklenmeyen hata: %s; ', sqlerrm);
      end if;
  end;

  -- (d) KANAL İSTEMCİYE OKUNABİLİR
  v_kanal := public.dogrulama_kanali();
  raise notice '269 NOBETCI: kanal = % · sms_hazir = %',
    v_kanal ->> 'kanal', v_kanal ->> 'sms_hazir';
  if (v_kanal ->> 'kanal') is null then
    v_hata := v_hata || 'dogrulama_kanali kanal dondurmuyor; ';
  end if;

  if v_hata <> '' then
    raise exception '269 NOBETCI: %', v_hata;
  end if;
  raise notice '269 NOBETCI OK — dogrulama zinciri butun.';

  raise exception 'NOBETCI_GERI_AL';
exception when others then
  if sqlerrm = 'NOBETCI_GERI_AL' then
    raise notice '269 NOBETCI: deney satirlari geri alindi.';
  else
    raise;
  end if;
end $nb269$;

-- ════════════════════════════════════════════════════════════════════════
-- §7 — ARTIK OKUNMAYAN İKİ AYAR: SİL, AMA GEREKÇESİNİ BIRAK
--
-- 🔴 §5 `send_otp`ı yeniden yazınca `otp_demo_mode` okuması ORTADAN
-- KALKTI — yani ayar artık HİÇBİR ŞEYİ KONTROL ETMİYOR. Bırakmak
-- tehlikeli: bir gün biri onu `yes` yapıp "demo modu açtım" sanır ve
-- hiçbir şey olmaz; ya da tersine, `no` gördüğü için arka kapının
-- kapalı olduğunu sanır — oysa kapıyı kapatan artık gövdenin kendisi.
--
-- 🆕 SINIF: "İŞLEVİNİ KAYBETMİŞ BİR AYARI SİLMEZSEN, O AYAR BİR KONTROL
-- SANILIR — VE YANLIŞ YERE BAKAN BİR GÜVENLİK KONTROLÜ, HİÇ KONTROL
-- OLMAMASINDAN DAHA KÖTÜDÜR."
--
-- Anahtarı siliyoruz; kararın KAYDI `_note` olarak kalıyor (nöbetçi
-- `_note` ile bitenleri ölü saymıyor — çünkü onlar okunmak için değil,
-- okunmak istenmeyen bir soruya cevap vermek için var).
-- ════════════════════════════════════════════════════════════════════════
insert into beta_settings (key, value) values
  ('otp_demo_mode_note', to_jsonb(
     'Kaldırıldı (269): send_otp artık kodu yanıtta hiç üretmiyor; arka '
     'kapı ayarla değil gövdeyle kapatıldı. Anahtar bırakılsaydı, olmayan '
     'bir kontrolü kontrol sanan biri yanlış güvenceye kapılırdı.'::text))
on conflict (key) do nothing;

delete from beta_settings where key = 'otp_demo_mode';

-- ════════════════════════════════════════════════════════════════════════
-- §8 — `mark_email_verified` İSTEMCİ YÜZEYİNDEN ÇIKIYOR
--
-- 🔴 Gövdesi `verify_email_contact` ile BİREBİR AYNI: ikisi de
-- `auth.users.email_confirmed_at`e bakıp `verifications`a yazıp
-- `recompute_trust` çağırıyor. Uygulama İKİSİNİ DE art arda çağırıyordu —
-- bir tur fazladan bekleme ve iki kez puan hesabı.
--
-- Uygulama tarafındaki ikinci çağrı kaldırıldı; fonksiyon artık istemci
-- yüzeyinde durmasın. Kendi nöbetçim (`sozlesme_check`) bunu hemen
-- yakaladı: "yüzeye yazılmış ama app HİÇ çağırmıyor".
--
-- ⚠️ Fonksiyon SİLİNMİYOR: `service_role` ya da bir bakım işi çağırabilir.
-- Kapanan şey İSTEMCİ YÜZEYİ — yani anon/authenticated'in görebildiği
-- yüzey. Bir fonksiyonu silmekle onu istemciye kapatmak aynı şey değil.
-- 🆕 SINIF: "KULLANILMAYAN BİR UCU SİLMEK İLE KAPATMAK FARKLI KARARLARDIR
-- — SİLMEK GERİ ALINAMAZ, KAPATMAK ALINABİLİR."
-- ════════════════════════════════════════════════════════════════════════
delete from rpc_client_surface where fn_name = 'mark_email_verified';
revoke execute on function public.mark_email_verified() from anon, authenticated;

commit;

-- ⚠️ COMMIT SONRASI: nöbetçi kendi deneyini geri aldı ama §1'in doldurduğu
-- ayna KALICI. Puanları gerçeğe göre yeniden hesapla:
select public.recompute_trust(id) from users where deleted_at is null;
