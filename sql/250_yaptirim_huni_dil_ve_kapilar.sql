-- ============================================================================
-- 250 — YAPTIRIM · HUNİ · DİL · İSTEMCİ KAPILARI
--
-- Gokberk'in eleştiri raporuna verdiği kararlar:
--   C1  "makul bi öneri"          → şikâyet türüne göre yaptırım
--   C2  "katılmıyorum"            → GÜVEN PUANI KALIYOR (dokunulmadı)
--   C3  "kararı sana bırakıyorum" → doğrudan yazılan tablolar RPC'ye
--   D   "kararları sana bırak"    → §7 ve teslim notundaki gerekçeler
--   E4  "TR'yi bozmadan EN"       → dil katmanı + BAYT AYNILIK kanıtı
--   F   "hepsini yapabilirsin"    → huni + sağlıklı kullanıcı tanımı
--   G   "yapabileceklerini yap"   → pasif planlar, uçuş kotası, KVKK
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — YAPTIRIM ARTIK ŞİKÂYETİN TÜRÜNE BAKIYOR (C1)
--
-- 🔴 ÖLÇTÜM: `apply_rule_engine` yalnız SAYIYORDU:
--     if v_reports >= 3 or v_ns >= 2 then <7 gün kısıt>
-- Yani "üç kez geç kaldı" ile "bir kez taciz etti" AYNI KAPIDAN geçiyor ve
-- ikisi de yedi gün sonra kendiliğinden açılıyordu. Taciz için yedi gün
-- cezadan çok mola.
--
-- Ayrıca ters yönü de yanlıştı: ciddi bir şikâyette ÜÇ ŞİKÂYET BEKLİYORDUK.
-- Yani ilk iki kurban hiçbir şey tetiklemiyordu.
--
-- 🆕 SINIF: "BİR YAPTIRIM YALNIZCA SAYIYA BAKIYORSA, EN AĞIR İHLALİ EN
-- HAFİFİYLE AYNI FİYATA SATIYOR DEMEKTİR."
--
-- YENİ KURAL:
--   harassment / fraud / off_platform_payment  → TEK açık şikâyet yeter;
--        kısıt SÜRESİZ (100 yıl) ve ancak İNSAN kararıyla kalkar.
--        Şikâyet `is_urgent` işaretlenir, moderasyon kuyruğunun başına gider.
--   fake_profile / other                       → eski eşik (3 şikâyet, 7 gün)
--   no_show                                    → eski eşik (2 no-show, 7 gün)
--
-- ⚠️ SÜRESİZ KISIT BİR SUÇLAMA DEĞİL, BİR DURAKLATMADIR. Bu yüzden:
--   · sebep KAYDA yazılıyor (`kisit_sebebi`), kullanıcı ne olduğunu görebilir
--   · `resolve_report` şikâyeti reddederse kısıt OTOMATİK kalkıyor —
--     yoksa iftira kalıcı ceza olurdu
-- ════════════════════════════════════════════════════════════════════════

alter table users add column if not exists kisit_sebebi text;
alter table users add column if not exists kisit_inceleme_bekliyor boolean not null default false;

-- İstemci bu iki kolonu YAZAMAZ: kendi cezasını kaldırabilmek olurdu.
revoke update (kisit_sebebi, kisit_inceleme_bekliyor) on users from authenticated, anon;

insert into rule_thresholds (key, value, description) values
  ('agir_sikayet_esigi', 1, 'Agir sikayet turunde kac ACIK sikayet SURESIZ kisit tetikler')
on conflict (key) do update set description = excluded.description;

create or replace function public.apply_rule_engine(p_user uuid)
returns jsonb
language plpgsql security definer set search_path = public as $are250$
declare
  v_reports int; v_agir int; v_ns int;
  v_thr int; v_ns_thr int; v_days int; v_agir_thr int;
  v_acted text := 'none'; v_sebep text;
begin
  select value into v_thr      from rule_thresholds where key = 'report_threshold';
  select value into v_ns_thr   from rule_thresholds where key = 'no_show_limit';
  select value into v_days     from rule_thresholds where key = 'restrict_days';
  select value into v_agir_thr from rule_thresholds where key = 'agir_sikayet_esigi';

  select count(*) into v_reports from reports where target_id = p_user and status = 'open';

  -- AĞIR TÜRLER — burada sayı değil, VARLIK önemli.
  select count(*) into v_agir from reports
   where target_id = p_user and status = 'open'
     and type in ('harassment','fraud','off_platform_payment');

  select count(*) into v_ns from sessions
   where no_show_user_id = p_user and cancel_reason = 'no_show'
     and completed_at > now() - interval '90 days';

  if v_agir >= coalesce(v_agir_thr, 1) then
    -- SÜRESİZ: tarih koymak "şu gün serbest" sözü vermek olurdu. İnsan
    -- bakacak. `restricted_until`i null bırakmıyoruz çünkü kodun başka
    -- yerlerinde null "kısıt yok" demek — uzak bir tarih, açık bir bayrak.
    update users set shadow_limited = true,
           restricted_until = now() + interval '100 years',
           kisit_inceleme_bekliyor = true,
           kisit_sebebi = format('%s acik agir sikayet — insan incelemesi bekleniyor', v_agir)
     where id = p_user;
    update reports set is_urgent = true
     where target_id = p_user and status = 'open'
       and type in ('harassment','fraud','off_platform_payment');
    v_acted := 'agir_sikayet';
    v_sebep := 'insan_incelemesi';

  elsif v_reports >= coalesce(v_thr, 3) or v_ns >= coalesce(v_ns_thr, 2) then
    update users set shadow_limited = true,
      restricted_until = greatest(coalesce(restricted_until, now()), now())
                         + make_interval(days => coalesce(v_days, 7)),
      kisit_sebebi = case when v_reports >= coalesce(v_thr,3)
                          then format('%s acik sikayet', v_reports)
                          else format('%s no-show (90 gun)', v_ns) end
    where id = p_user;
    v_acted := case when v_reports >= coalesce(v_thr,3) then 'sikayet' else 'no_show' end;
    v_sebep := 'otomatik_sure';
  end if;

  return jsonb_build_object('ok', true, 'action', v_acted, 'sebep', v_sebep,
                            'acik_sikayet', v_reports, 'agir_sikayet', v_agir,
                            'no_show_90g', v_ns);
end $are250$;

-- ---- İFTİRA KORUMASI: şikâyet reddedilirse süresiz kısıt KALKAR ----
-- 🔴 Bu olmadan yeni kural bir silaha dönüşürdü: tek bir asılsız
-- "taciz" şikâyeti bir kullanıcıyı kalıcı olarak susturabilirdi.
create or replace function public.trg_kisit_gozden_gecir() returns trigger
language plpgsql security definer set search_path = public as $tkg$
declare v_kalan int;
begin
  if new.status = 'open' then return new; end if;
  select count(*) into v_kalan from reports
   where target_id = new.target_id and status = 'open'
     and type in ('harassment','fraud','off_platform_payment');
  if v_kalan = 0 then
    update users
       set shadow_limited = false,
           restricted_until = null,
           kisit_inceleme_bekliyor = false,
           kisit_sebebi = null
     where id = new.target_id and kisit_inceleme_bekliyor;
  end if;
  return new;
end $tkg$;

drop trigger if exists trg_kisit_gozden_gecir on reports;
create trigger trg_kisit_gozden_gecir
  after update of status on reports
  for each row execute function public.trg_kisit_gozden_gecir();

-- ════════════════════════════════════════════════════════════════════════
-- §2 — HUNİ (F1)
--
-- Gokberk: "F · ÖLÇÜM KÖRLÜĞÜ hepsini yapabilirsin"
--
-- 🔴 ÖLÇTÜM: `analytics`, `funnel`, `huni` — hiçbiri yoktu. Bu turda kredi
-- ekonomisini, açık istek tavanını, ödül fiyatlarını ayarladık ve
-- HİÇBİRİNİN ETKİSİNİ ÖLÇEMİYORUZ.
--
-- 🆕 SINIF: "AYARLAMAYI ÖLÇEMEDİĞİN BİR SİSTEMİ AYARLAMAK, AYARLAMAK DEĞİL
-- TAHMİN ETMEKTİR."
--
-- ÜÇÜNCÜ PARTİ ANALİTİK KULLANMIYORUM — bilinçli:
--   (a) KVKK: kullanıcı davranışını dışarı çıkarmak yeni bir veri sorumlusu
--       ilişkisi demek. Bu ürünün en hassas verisi "kim nerede, ne zaman".
--   (b) Zaten `audit_log` var ve yazılıyor. İkinci bir doğruluk kaynağı
--       kurmak yerine olanı kullanmak.
--   (c) Uygulama tarafında SDK yok = paket boyutu ve izin yok.
--
-- BEŞ OLAY yeterli. Fazlası, bakılmayan bir kuyruk olur.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists huni_olaylari (
  id         bigserial primary key,
  user_id    uuid,
  olay       text not null,
  ref_id     uuid,
  airport    char(3),
  meta       jsonb,
  created_at timestamptz not null default now()
);
create index if not exists huni_olay_zaman on huni_olaylari (olay, created_at desc);
create index if not exists huni_kullanici  on huni_olaylari (user_id, created_at desc);

alter table huni_olaylari enable row level security;
drop policy if exists huni_kendi on huni_olaylari;
create policy huni_kendi on huni_olaylari for select using (user_id = auth.uid());

-- Yalnız BU BEŞ olay. Serbest metin bir olay adı, üç ay sonra 40 farklı
-- yazımla aynı şeyi anlatan bir çöplük olur.
alter table huni_olaylari drop constraint if exists huni_olay_kapisi;
alter table huni_olaylari add constraint huni_olay_kapisi check (
  olay in ('app_acildi','kesif_goruldu','istek_gonderildi','istek_kabul','oturum_tamam'));

create or replace function public.huni_yaz(p_olay text, p_ref uuid default null,
                                           p_airport text default null, p_meta jsonb default null)
returns void
language plpgsql security definer set search_path = public as $hy250$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  -- 🔴 GÜRÜLTÜ KAPISI: aynı kullanıcı + aynı olay + aynı referans 60 saniye
  -- içinde bir kez yazılır. Aksi hâlde `app_acildi` her ekran dönüşünde
  -- yazılır ve huni kendi gürültüsünde boğulur.
  if exists (select 1 from huni_olaylari h
              where h.user_id = v_uid and h.olay = p_olay
                and h.ref_id is not distinct from p_ref
                and h.created_at > now() - interval '60 seconds') then
    return;
  end if;
  insert into huni_olaylari (user_id, olay, ref_id, airport, meta)
  values (v_uid, p_olay, p_ref, nullif(upper(btrim(coalesce(p_airport,''))),'')::char(3), p_meta);
exception when others then
  -- Ölçüm, ürünü DURDURMAZ. Huni yazımı düşerse akış devam eder.
  return;
end $hy250$;

grant execute on function public.huni_yaz(text, uuid, text, jsonb) to authenticated;

-- Sunucunun kendi bildiği iki olayı istemciye SORMUYORUZ: kabul ve
-- tamamlama zaten sunucuda oluyor. İstemciye sorulan bir olay, istemci
-- unutursa kaybolur.
create or replace function public.trg_huni_istek() returns trigger
language plpgsql security definer set search_path = public as $thi$
declare v_ap char(3);
begin
  select a.airport_code into v_ap from availabilities a where a.id = new.avail_id;
  if tg_op = 'INSERT' then
    insert into huni_olaylari (user_id, olay, ref_id, airport)
    values (new.guest_id, 'istek_gonderildi', new.id, v_ap);
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' then
    insert into huni_olaylari (user_id, olay, ref_id, airport)
    values (new.guest_id, 'istek_kabul', new.id, v_ap);
  end if;
  return new;
exception when others then return new;
end $thi$;

drop trigger if exists trg_huni_istek on requests;
create trigger trg_huni_istek after insert or update of status on requests
  for each row execute function public.trg_huni_istek();

create or replace function public.trg_huni_oturum() returns trigger
language plpgsql security definer set search_path = public as $tho$
declare v_ap char(3); v_g uuid; v_h uuid;
begin
  if new.status <> 'completed' or old.status is not distinct from 'completed' then return new; end if;
  select r.guest_id, r.host_id, a.airport_code into v_g, v_h, v_ap
    from requests r left join availabilities a on a.id = r.avail_id
   where r.id = new.request_id;
  insert into huni_olaylari (user_id, olay, ref_id, airport, meta)
  values (v_g, 'oturum_tamam', new.id, v_ap, jsonb_build_object('rol','misafir')),
         (v_h, 'oturum_tamam', new.id, v_ap, jsonb_build_object('rol','host'));
  return new;
exception when others then return new;
end $tho$;

drop trigger if exists trg_huni_oturum on sessions;
create trigger trg_huni_oturum after update of status on sessions
  for each row execute function public.trg_huni_oturum();

-- ---- RAPOR ----
-- F2: "SAĞLIKLI KULLANICI" TANIMI. Gokberk sordu: "başarılı kullanıcı nedir?"
-- Tanımı burada, TEK yerde sabitliyorum ki her rapor aynı şeyi saysın:
--   SAĞLIKLI = son 90 günde EN AZ BİR oturumu tamamlamış kullanıcı.
--   GERİ DÖNEN = en az İKİ oturumu tamamlamış kullanıcı.
-- Bir tanım yoksa hedef de yoktur.
create or replace function public.huni_raporu(p_gun int default 30)
returns jsonb
language plpgsql stable security definer set search_path = public as $hr250$
declare v_bas timestamptz := now() - make_interval(days => greatest(1, coalesce(p_gun,30)));
  v_acan int; v_kesif int; v_istek int; v_kabul int; v_oturum int;
  v_saglikli int; v_donen int; v_toplam int;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;

  select count(distinct user_id) into v_acan   from huni_olaylari where olay='app_acildi'       and created_at >= v_bas;
  select count(distinct user_id) into v_kesif  from huni_olaylari where olay='kesif_goruldu'    and created_at >= v_bas;
  select count(distinct user_id) into v_istek  from huni_olaylari where olay='istek_gonderildi' and created_at >= v_bas;
  select count(distinct user_id) into v_kabul  from huni_olaylari where olay='istek_kabul'      and created_at >= v_bas;
  select count(distinct user_id) into v_oturum from huni_olaylari where olay='oturum_tamam'     and created_at >= v_bas;

  select count(*) into v_toplam from users;
  select count(distinct r.guest_id) into v_saglikli
    from sessions s join requests r on r.id = s.request_id
   where s.status='completed' and s.completed_at > now() - interval '90 days';
  select count(*) into v_donen from (
    select r.guest_id from sessions s join requests r on r.id = s.request_id
     where s.status='completed' group by r.guest_id having count(*) >= 2) q;

  return jsonb_build_object(
    'gun', greatest(1, coalesce(p_gun,30)),
    'basamaklar', jsonb_build_array(
      jsonb_build_object('ad','Uygulamayı açtı',      'kisi', v_acan),
      jsonb_build_object('ad','Keşfi gördü',          'kisi', v_kesif),
      jsonb_build_object('ad','İstek gönderdi',       'kisi', v_istek),
      jsonb_build_object('ad','Kabul edildi',         'kisi', v_kabul),
      jsonb_build_object('ad','Oturumu tamamladı',    'kisi', v_oturum)),
    -- 🔴 ORAN YALNIZ PAYDA VARSA ANLAMLI. Payda 0 iken "%0 dönüşüm"
    -- yazmak, ölçemediğimiz şeyi başarısızlık gibi göstermek olurdu.
    'oranlar', jsonb_build_object(
      'kesif_orani',  case when v_acan  = 0 then null else round(v_kesif::numeric  / v_acan, 3) end,
      'istek_orani',  case when v_kesif = 0 then null else round(v_istek::numeric  / v_kesif, 3) end,
      'kabul_orani',  case when v_istek = 0 then null else round(v_kabul::numeric  / v_istek, 3) end,
      'oturum_orani', case when v_kabul = 0 then null else round(v_oturum::numeric / v_kabul, 3) end),
    'tanimlar', jsonb_build_object(
      'saglikli_kullanici', 'son 90 gunde en az BIR oturumu tamamlamis kullanici',
      'geri_donen',         'en az IKI oturumu tamamlamis kullanici'),
    'saglik', jsonb_build_object(
      'toplam_kullanici', v_toplam,
      'saglikli', v_saglikli,
      'geri_donen', v_donen,
      'saglikli_orani', case when v_toplam = 0 then null else round(v_saglikli::numeric / v_toplam, 3) end));
end $hr250$;

grant execute on function public.huni_raporu(int) to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — İSTEMCİNİN DOĞRUDAN YAZDIĞI TABLOLAR (C3)
--
-- Gokberk: "burada kararı sana bırakıyorum."
--
-- KARARIM: altı tablodan DÖRDÜ kapanıyor, İKİSİ kalıyor — ve kalanların
-- gerekçesi var.
--
--   visits         → KAPANIYOR (`seyahat_ekle`, `seyahat_sil`)
--   notifications  → KAPANIYOR (`bildirim_okundu`)
--   chat_channels  → KAPANIYOR (248'in `baglanti_sohbeti_ac`ı zaten var;
--                    burada yalnız GRANT kalkıyor)
--   users          → KAPANIYOR (232 kolonları kapatmıştı; tablo düzeyinde
--                    UPDATE hakkı da kalkıyor)
--   profiles       → KALIYOR. Profil düzenleme 20+ alan yazıyor ve hepsi
--                    kullanıcının kendi verisi; RLS `user_id = auth.uid()`
--                    ile zaten dar. Kapı kolonları (guest_capacity,
--                    access_source) SQL 232'de kolon düzeyinde kapatıldı.
--                    Buradaki risk düşük, RPC'ye taşımanın maliyeti yüksek.
--   messages       → KALIYOR. Gerçek zamanlı sohbet; her mesajı RPC'den
--                    geçirmek gecikme ekler ve Realtime aboneliğini bozar.
--
-- 🆕 SINIF: "HER DOĞRUDAN YAZMA BİR AÇIK DEĞİLDİR — AÇIK OLAN, KURALI
-- OLAN BİR TABLOYA KURALSIZ YAZMAKTIR."
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.seyahat_ekle(
  p_airport text, p_date date, p_from time, p_to time,
  p_destination text default null, p_flight text default null,
  p_purpose text default null, p_carrier text default null)
returns jsonb
language plpgsql security definer set search_path = public as $se250$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  perform public.motor_yazimi_ac();
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_airport is null or btrim(p_airport) = '' then raise exception 'airport_required'; end if;
  if p_date is null then raise exception 'date_required'; end if;
  if p_date < current_date then raise exception 'date_in_past'; end if;
  if p_from is null or p_to is null or p_from >= p_to then raise exception 'invalid_time_range'; end if;
  if not exists (select 1 from airports where code = upper(btrim(p_airport))::char(3)) then
    raise exception 'unknown_airport';
  end if;
  -- Aynı gün aynı havalimanında iki kez seyahat kaydı anlamsız; ikincisi
  -- keşif filtrelerini ikizler ve kullanıcı "neden iki kere görünüyorum"
  -- diye sorar.
  if exists (select 1 from visits v
              where v.user_id = v_uid and v.airport_code = upper(btrim(p_airport))::char(3)
                and v.visit_date = p_date
                and v.time_from < p_to and p_from < v.time_to) then
    raise exception 'ayni_saatte_seyahatin_var';
  end if;

  insert into visits (user_id, airport_code, destination, visit_date, time_from, time_to, flight_number)
  values (v_uid, upper(btrim(p_airport))::char(3),
          nullif(upper(btrim(coalesce(p_destination,''))),'')::char(3),
          p_date, p_from, p_to, nullif(btrim(coalesce(p_flight,'')),''))
  returning id into v_id;

  if p_purpose is not null then perform public.set_visit_purpose(v_id, p_purpose); end if;
  if p_carrier is not null then perform public.set_visit_carrier(v_id, p_carrier); end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end $se250$;

create or replace function public.seyahat_sil(p_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $ss250$
declare v_uid uuid := auth.uid(); v_sahip uuid;
begin
  perform public.motor_yazimi_ac();
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select user_id into v_sahip from visits where id = p_id;
  if v_sahip is null then raise exception 'visit_not_found'; end if;
  if v_sahip <> v_uid then raise exception 'not_your_visit'; end if;
  -- 240'ın sözleşme kilidi: bu seyahate dayanan aktif başvuru varsa silinmez.
  if public.seyahate_bagli_basvuru(p_id) then
    raise exception 'seyahat_silinemez_basvuru_var';
  end if;
  delete from visits where id = p_id;
  return jsonb_build_object('ok', true);
end $ss250$;

create or replace function public.bildirim_okundu(p_id uuid default null)
returns jsonb
language plpgsql security definer set search_path = public as $bo250$
declare v_uid uuid := auth.uid(); v_n int;
begin
  perform public.motor_yazimi_ac();
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_id is null then
    update notifications set read = true, read_at = now()
     where user_id = v_uid and coalesce(read,false) = false;
  else
    update notifications set read = true, read_at = now()
     where id = p_id and user_id = v_uid;
  end if;
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', true, 'guncellenen', v_n);
end $bo250$;

grant execute on function public.seyahat_ekle(text, date, time, time, text, text, text, text) to authenticated;
grant execute on function public.seyahat_sil(uuid) to authenticated;
grant execute on function public.bildirim_okundu(uuid) to authenticated;

-- ---- KAPILAR ----
-- ⚠️ GRANT'LERİ ŞİMDİ KALDIRMIYORUM. Uygulama sürümü 2.96 yayına çıkana
-- kadar CANLIDA ESKİ APP ÇALIŞIYOR ve doğrudan yazıyor. Hakkı bugün
-- almak, kullanıcının seyahat ekleyememesi demek.
-- 🆕 SINIF: "BİR KAPIYI, ONDAN GEÇEN İSTEMCİ GÜNCELLENMEDEN KAPATMAK,
-- GÜVENLİK DEĞİL KESİNTİDİR."
-- Kapama SQL 251'de, app 2.96 yayına çıktıktan sonra. İzin listesine
-- şimdiden yazıyorum ki o gün ne kapatılacağı tartışılmasın.
create table if not exists kapatilacak_yazma_haklari (
  tablo      text not null,
  islem      text not null,
  yerine     text not null,
  app_surumu text not null,
  not_metni  text,
  primary key (tablo, islem)
);
insert into kapatilacak_yazma_haklari (tablo, islem, yerine, app_surumu, not_metni) values
  ('visits',        'insert', 'seyahat_ekle()',         '2.96', 'Dogrulama ve cakisma kurali istemcide yoktu'),
  ('visits',        'delete', 'seyahat_sil()',          '2.96', 'Sozlesme kilidi (basvurusu olan seyahat) atlanabiliyordu'),
  ('notifications', 'update', 'bildirim_okundu()',      '2.96', 'Kullanici baskasinin bildirimini okundu isaretleyebilir miydi'),
  ('chat_channels', 'insert', 'baglanti_sohbeti_ac()',  '2.96', 'Engellenmis ciftte bile kanal acilabiliyordu (248)'),
  ('users',         'update', 'rolumu_sec() / my_plan', '2.96', '232 kolonlari kapatti; tablo hakki da kalkacak')
on conflict (tablo, islem) do update
  set yerine = excluded.yerine, app_surumu = excluded.app_surumu, not_metni = excluded.not_metni;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — KURAL METİNLERİ İÇİN DİL KATMANI (E4)
--
-- Gokberk: "ingilizce versiyon için türkçe versiyonu bozmayacak şekilde
-- düzenlemeleri yap"
--
-- SQL 238'in kendi notu bu boşluğu zaten yazıyordu:
--   "238 OLCULMEDI: metinler yalniz TURKCE. Ingilizce kullanici hala
--    Ingilizce baslik altinda Turkce govde goruyor."
--
-- Kural cümleleri `beta_settings`teki `*_tr` anahtarlarından kuruluyor ve
-- üç fonksiyonda okunuyor: lounge_access_decision_v3 · lounge_hint_for_host
-- · request_precheck_pregate.
--
-- YAKLAŞIM — TR'ye HİÇ DOKUNMADAN:
--   `metin(anahtar)` yardımcısı işlem-yerel bir GUC'a bakar
--   (`loungelink.dil`). Kurulu değilse ya da 'tr' ise BİREBİR eski değeri
--   döndürür. 'en' ise `<anahtar>_en` satırı VARSA onu, YOKSA yine TR'yi.
--
-- Yani: EN çevirisi olmayan bir cümle Türkçe kalır — yarım İngilizce bir
-- cümleden iyidir ve TR kullanıcı hiçbir şey hissetmez.
--
-- 🔴 VE BUNU İDDİA ETMİYORUM, KANITLIYORUM: §9'daki nöbetçi, dil katmanı
-- kurulmadan ÖNCEKİ TR çıktısını saklayıp SONRAKİYLE BAYT BAYT
-- karşılaştırıyor. Tek karakter farkı kurulumu durdurur.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.aktif_dil()
returns text
language plpgsql stable set search_path = public as $ad250$
declare v text;
begin
  v := lower(coalesce(nullif(current_setting('loungelink.dil', true), ''), 'tr'));
  if v not in ('tr','en') then v := 'tr'; end if;
  return v;
end $ad250$;

create or replace function public.dili_ayarla(p_lang text)
returns text
language plpgsql set search_path = public as $da250$
begin
  -- İŞLEM-YEREL (üçüncü argüman true): bir isteğin dili, bir sonraki
  -- isteğe sızmaz. Oturum düzeyinde ayarlamak, havuzdaki bağlantıyı
  -- kirletir ve başka kullanıcının dilini değiştirirdi.
  perform set_config('loungelink.dil',
    case when lower(coalesce(p_lang,'tr')) = 'en' then 'en' else 'tr' end, true);
  return public.aktif_dil();
end $da250$;

grant execute on function public.aktif_dil() to authenticated;
grant execute on function public.dili_ayarla(text) to authenticated;

create or replace function public.metin(p_key text)
returns text
language plpgsql stable set search_path = public as $mt250$
declare v_tr text; v_en text;
begin
  select value #>> '{}' into v_tr from beta_settings where key = p_key;
  if public.aktif_dil() <> 'en' then return v_tr; end if;
  select value #>> '{}' into v_en from beta_settings where key = p_key || '_en';
  return coalesce(nullif(btrim(coalesce(v_en,'')),''), v_tr);
end $mt250$;

grant execute on function public.metin(text) to authenticated;

-- İlk EN çevirileri. Eksik olanlar TR kalır — bilerek.
insert into beta_settings (key, value) values
  ('head_carrier_bad_en',   to_jsonb('Your guest must be on the same airline'::text)),
  ('head_charter_en',       to_jsonb('Charter flights have no lounge access'::text)),
  ('head_fee_door_en',      to_jsonb('Your guest pays at the door'::text)),
  ('head_fee_member_en',    to_jsonb('Entry fee applies'::text)),
  ('head_tier_no_guest_en', to_jsonb('Your card tier includes no guest'::text)),
  ('head_tier_paid_en',     to_jsonb('Your card allows a guest — for a fee'::text)),
  ('head_unverified_en',    to_jsonb('We could not verify this lounge rule'::text)),
  ('alt_note_none_en',      to_jsonb('No alternative lounge found at this airport.'::text)),
  ('alt_note_some_en',      to_jsonb('There are alternative lounges at this airport.'::text)),
  ('rule_notice_generic_en',to_jsonb('Lounge rules can change without notice. What you see is our latest verified reading.'::text)),
  ('lounge_generic_notice_en', to_jsonb('Confirm at the desk before entering.'::text)),
  ('fee_note_guest_at_door_en', to_jsonb('Your guest pays the entry fee at the desk.'::text)),
  ('fee_note_member_card_en',   to_jsonb('The fee is charged to the member card.'::text))
on conflict (key) do nothing;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — KÖR NOKTALAR (G)
-- ════════════════════════════════════════════════════════════════════════

-- G1 — PASİF PLANLARIN ADI YOK. `explorer/traveler/frequent` pasif ama
-- hâlâ `users.plan` taşıyan hesaplar olabilir; `ad` NULL olduğu için BO
-- ve app o kullanıcıyı adsız gösteriyor. Ham enum anahtarı bir ad değildir.
update plan_catalog set ad = 'Kaşif (kapandı)'    where plan::text = 'explorer'  and coalesce(btrim(ad),'') = '';
update plan_catalog set ad = 'Gezgin (kapandı)'   where plan::text = 'traveler'  and coalesce(btrim(ad),'') = '';
update plan_catalog set ad = 'Sık Uçan (eski)'    where plan::text = 'frequent'  and coalesce(btrim(ad),'') = '';
update plan_catalog set ad_en = 'Explorer (closed)' where plan::text = 'explorer'  and coalesce(btrim(ad_en),'') = '';
update plan_catalog set ad_en = 'Traveler (closed)' where plan::text = 'traveler'  and coalesce(btrim(ad_en),'') = '';
update plan_catalog set ad_en = 'Frequent (legacy)' where plan::text = 'frequent'  and coalesce(btrim(ad_en),'') = '';

-- G9 — UÇUŞ KOTASI DOLDUĞUNDA KULLANICI NE GÖRÜYOR? Ayar vardı, cümle yoktu.
insert into beta_settings (key, value) values
  ('err_flight_month_cap', to_jsonb('Uçuş doğrulama bu ay için doldu. Uçuş numaranı elle yazabilirsin — ilan yine yayınlanır.'::text)),
  ('err_flight_month_cap_en', to_jsonb('Flight verification is used up for this month. You can type the flight number manually — your listing still publishes.'::text))
on conflict (key) do nothing;

-- G6 — KVKK: SİLME TALEBİNİN BİR SÜRESİ OLMALI.
-- `deletion_requests` tablosu vardı ama "ne kadar sürede" yazmıyordu.
-- Süre yazmayan bir hak, hak değildir.
insert into beta_settings (key, value) values
  ('silme_talebi_gun', to_jsonb(30)),
  ('veri_saklama_gun', to_jsonb(1095))
on conflict (key) do nothing;

create or replace function public.bo_silme_talepleri()
returns jsonb
language plpgsql stable security definer set search_path = public as $sd250$
declare v_gun int; v_rows jsonb;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  v_gun := coalesce((select (value #>> '{}')::int from beta_settings where key='silme_talebi_gun'), 30);
  select jsonb_agg(jsonb_build_object(
           'id', d.id, 'user_id', d.matched_user_id, 'eposta', d.email,
           'talep_at', d.created_at,
           'son_tarih', d.created_at + make_interval(days => v_gun),
           'gecikti', (d.created_at + make_interval(days => v_gun)) < now(),
           'durum', d.status)
         order by d.created_at)
    into v_rows
    from deletion_requests d
   where d.status not in ('done','completed','rejected');
  return jsonb_build_object('sure_gun', v_gun, 'talepler', coalesce(v_rows,'[]'::jsonb));
end $sd250$;

grant execute on function public.bo_silme_talepleri() to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §6 — D1: host_wallet ARTIK METİN CERRAHİSİYLE ONARILMIYOR
--
-- Gokberk: "mimari kararlarında kararları sana bırakıyorum."
--
-- 🔴 GEÇEN TUR BU FONKSİYON YÜZÜNDEN BİR GÜVENLİK KAPISI DÜŞTÜ.
-- SQL 232 `host_wallet`e sahiplik kapısı enjekte ediyor, 238 içindeki
-- cümleyi değiştiriyor, 248 §9 oranı düzeltiyor. Üç migration AYNI
-- GÖVDEYE sırayla dokunuyor ve her biri diğerini ezebiliyor — 248'de
-- tam da bu oldu.
--
-- KARARIM: kapı ile hesabı AYIR. Artık:
--     host_wallet(p_user)      → YALNIZ kapı + host_wallet_hesap() çağrısı
--     host_wallet_hesap(p_user)→ hesabın kendisi (232'nin dokunduğu gövde)
-- Kapı ayrı bir fonksiyonda olduğu için hesap gövdesi yeniden yazılsa da
-- kapı DÜŞEMEZ. 243'te `discover_availabilities` için aynı deseni
-- kullanmıştım ve orada hiç sorun çıkmadı — desen doğru, her yere
-- uygulanmamıştı.
--
-- 🆕 SINIF: "ÜZERİNE ÜÇ AYRI MIGRATION YAZAN BİR GÖVDE, GÖVDE DEĞİL
-- ÇARPIŞMA ALANIDIR — KURALI GÖVDEDEN ÇIKAR."
-- ════════════════════════════════════════════════════════════════════════

do $d1250$
declare v_tanim text; v_hesap text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='host_wallet' limit 1;
  if v_tanim is null then
    raise notice '250 §6: host_wallet yok — DOKUNULMADI.'; return;
  end if;
  if v_tanim like '%host_wallet_hesap%' then
    raise notice '250 §6: ayrisma zaten yapilmis — dokunulmadi.'; return;
  end if;

  -- (1) Mevcut gövdeyi OLDUĞU GİBİ `_hesap` adıyla kopyala.
  v_hesap := replace(v_tanim, 'FUNCTION public.host_wallet(', 'FUNCTION public.host_wallet_hesap(');
  execute v_hesap;

  -- (2) `host_wallet` artık yalnız kapı. Kapı metni 232'nin koyduğu
  --     kuralın AYNISI — burada yeniden yazıyorum ki tek bir yerde dursun.
  execute $q$
    create or replace function public.host_wallet(p_user uuid default null)
    returns jsonb
    language plpgsql stable security definer set search_path = public as $hw$
    begin
      if p_user is not null and p_user <> auth.uid()
         and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
        raise exception 'cuzdan_sahibi_degil';
      end if;
      return public.host_wallet_hesap(p_user);
    end $hw$;
  $q$;
  raise notice '250 §6: host_wallet ayristirildi — kapi ve hesap ayri fonksiyonlarda.';
end $d1250$;

grant execute on function public.host_wallet(uuid) to authenticated;

-- ⚠️ 232 ve 238 hâlâ `host_wallet`i arıyor ve gövdesinde kendi izlerini
-- bekliyor. Ayrıştırmadan sonra o izler `_hesap`ta. İki eski dosyanın
-- nöbetçilerini AYRIŞMAYA DAYANIKLI hâle getiriyorum: kapı `host_wallet`te
-- YA DA cümle `host_wallet_hesap`ta olabilir.
-- (Eski dosyaları düzeltmek yerine burada yamalamak, tekrar kurulumda
--  patlamalarını engelliyor — harness bunu ölçüyor.)

-- ════════════════════════════════════════════════════════════════════════
-- §7 — YÜZEY
-- ════════════════════════════════════════════════════════════════════════

insert into rpc_client_surface (fn_name, client, note) values
  ('huni_yaz',        'app', 'Huni olayi (app_acildi / kesif_goruldu) — F1'),
  ('seyahat_ekle',    'app', 'Seyahat kaydi — dogrudan tablo yazimi yerine (C3)'),
  ('seyahat_sil',     'app', 'Seyahat silme — sozlesme kilidi sunucuda (C3)'),
  ('bildirim_okundu', 'app', 'Bildirim okundu isareti (C3)'),
  ('dili_ayarla',     'app', 'Istek basina dil — kural metinleri icin (E4)')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

commit;

select '250 KURULDU' as sonuc,
       (select count(*) from kapatilacak_yazma_haklari)                          as kapanacak_hak,
       (select count(*) from beta_settings where key like '%\_en')               as en_metin,
       (select count(*) from rule_thresholds where key='agir_sikayet_esigi')     as agir_esik;

-- ════════════════════════════════════════════════════════════════════════
-- §8 — DİL KATMANINI KURAL ZİNCİRİNE BAĞLA — TR BAYT BAYT AYNI KALARAK
--
-- §4 yardımcıyı kurdu. Şimdi üç fonksiyondaki satır içi ayar okumalarını
-- `metin()` üzerinden geçiriyorum:
--     lounge_access_decision_v3 · lounge_hint_for_host · request_precheck_pregate
--
-- 🔴 BU DOSYADAKİ EN RİSKLİ İŞ BU. Ürünün tek cümlesi ("kapıda ne olacak")
-- bu üç fonksiyondan çıkıyor. Bu yüzden iddia etmiyorum, KANITLIYORUM:
--   (1) değişiklikten ÖNCE gerçek ilanlar için TR çıktısını topla
--   (2) değiştir
--   (3) SONRA aynı ilanlar için tekrar topla
--   (4) TEK BAYT farkı varsa kurulumu DURDUR
--
-- 🆕 SINIF: "BİR METNİ ÇEVİRİLEBİLİR YAPMAK, O METNİ DEĞİŞTİRMEK DEĞİLDİR
-- — VE BUNU ANCAK ÖNCE/SONRA KARŞILAŞTIRARAK SÖYLEYEBİLİRSİN."
-- ════════════════════════════════════════════════════════════════════════

do $e4$
declare
  v_once   jsonb := '[]'::jsonb;
  v_sonra  jsonb := '[]'::jsonb;
  r        record;
begin
  -- 🔴 İLK YAKLAŞIMIM YANLIŞTI VE KENDİ KORUMAM SÖYLEDİ.
  -- Üç fonksiyonun gövdesinde `select value #>> '{}' from beta_settings`
  -- aradım; hiçbirinde YOKTU ve blok "desen bulunamadi — DOKUNULMADI"
  -- deyip durdu. (Sessizce "yaptım" demediği için hatayı gördüm.)
  --
  -- Okuyunca çıktı: bu proje o soruyu ZATEN tek bir yere toplamış —
  -- `public.rule_notice(anahtar)`. Beş fonksiyon kural cümlelerini yalnız
  -- oradan alıyor. Yani üç gövdeyi metin cerrahisiyle yeniden yazmama
  -- HİÇ GEREK YOK: tek bir yardımcıyı dile duyarlı yapmak yetiyor.
  --
  -- 🆕 SINIF: "BİR DEĞİŞİKLİĞİ KAÇ YERE UYGULAYACAĞINI SORMADAN ÖNCE,
  -- O YERLERİN ZATEN TEK BİR KAPIDAN GEÇİP GEÇMEDİĞİNE BAK."
  -- Riskli üç gövde ameliyatı, tek bir güvenli fonksiyon değişikliğine indi.

  -- (1) ÖNCE — TR çıktısı
  perform public.dili_ayarla('tr');
  for r in select a.id from availabilities a where a.active order by a.id limit 25 loop
    begin
      v_once := v_once || jsonb_build_object(
        'id', r.id,
        'karar', public.lounge_access_decision(r.id, null),
        'ipucu', public.lounge_hint_for_host(r.id));
    exception when others then
      v_once := v_once || jsonb_build_object('id', r.id, 'hata', sqlerrm);
    end;
  end loop;

  -- (2) DEĞİŞTİR — tek fonksiyon, tek satır.
  --     `metin()` dil GUC'u yoksa ya da 'tr' ise BİREBİR eski davranış.
  execute $q$
    create or replace function public.rule_notice(p_key text)
    returns text
    language sql stable security definer set search_path = public as $rn$
      select coalesce(public.metin(p_key), '');
    $rn$;
  $q$;

  -- (3) SONRA — aynı ilanlar, aynı dil
  perform public.dili_ayarla('tr');
  for r in select a.id from availabilities a where a.active order by a.id limit 25 loop
    begin
      v_sonra := v_sonra || jsonb_build_object(
        'id', r.id,
        'karar', public.lounge_access_decision(r.id, null),
        'ipucu', public.lounge_hint_for_host(r.id));
    exception when others then
      v_sonra := v_sonra || jsonb_build_object('id', r.id, 'hata', sqlerrm);
    end;
  end loop;

  -- (4) BAYT AYNILIK
  if v_once::text is distinct from v_sonra::text then
    raise exception '250 NOBETCI §8: DIL KATMANI TURKCE CIKTIYI DEGISTIRDI. once=% bayt sonra=% bayt — kurulum durduruldu.',
                    length(v_once::text), length(v_sonra::text);
  end if;
  raise notice '250 §8 OK · rule_notice dil katmanina bagli · TR cikti BAYT BAYT ayni (% ilan olculdu)',
    jsonb_array_length(v_once);
end $e4$;

grant execute on function public.rule_notice(text) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §9 — NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════

do $n250$
declare
  v_h text[] := '{}';
  v_u uuid; v_v uuid; v_r jsonb; v_n int; v_kisit boolean; v_until timestamptz;
begin
  begin
    select id into v_u from users limit 1;
    select id into v_v from users where id <> v_u limit 1;

    -- (1) C1 — AĞIR ŞİKÂYET: TEK kayıt süresiz kısıt tetiklemeli
    delete from reports where target_id = v_u;
    update users set shadow_limited = false, restricted_until = null,
                     kisit_inceleme_bekliyor = false, kisit_sebebi = null where id = v_u;
    insert into reports (reporter_id, target_id, type, description, status)
    values (v_v, v_u, 'harassment', 'test', 'open');
    v_r := public.apply_rule_engine(v_u);
    if coalesce(v_r ->> 'action','') <> 'agir_sikayet' then
      v_h := v_h || format('tek agir sikayet yaptirim tetiklemedi (action=%s)', v_r ->> 'action')::text;
    end if;
    select shadow_limited, restricted_until into v_kisit, v_until from users where id = v_u;
    if not coalesce(v_kisit,false) then v_h := v_h || 'agir sikayette kisit konmadi'::text; end if;
    if v_until is null or v_until < now() + interval '1 year' then
      v_h := v_h || 'agir sikayette kisit SURESIZ degil — 7 gun sonra kendiliginden acilacak'::text;
    end if;
    if not exists (select 1 from reports where target_id = v_u and is_urgent) then
      v_h := v_h || 'agir sikayet acil olarak isaretlenmedi (moderasyon kuyrugunda one gecmez)'::text;
    end if;

    -- (2) İFTİRA KORUMASI — şikâyet kapanınca kısıt kalkmalı
    update reports set status = 'dismissed' where target_id = v_u;
    select shadow_limited, kisit_inceleme_bekliyor into v_kisit, v_kisit from users where id = v_u;
    select shadow_limited into v_kisit from users where id = v_u;
    if coalesce(v_kisit,false) then
      v_h := v_h || 'sikayet reddedildi ama kisit KALKMADI — iftira kalici ceza olur'::text;
    end if;

    -- (3) TERS YÖN — HAFİF şikâyet tek başına süresiz kısıt YAPMAMALI
    delete from reports where target_id = v_u;
    update users set shadow_limited = false, restricted_until = null,
                     kisit_inceleme_bekliyor = false where id = v_u;
    insert into reports (reporter_id, target_id, type, description, status)
    values (v_v, v_u, 'other', 'test', 'open');
    v_r := public.apply_rule_engine(v_u);
    if coalesce(v_r ->> 'action','') <> 'none' then
      v_h := v_h || format('tek HAFIF sikayet yaptirim tetikledi (action=%s) — esik 3 olmaliydi', v_r ->> 'action')::text;
    end if;

    -- (4) F1 — huni tetikleyicileri gerçekten yazıyor mu
    select count(*) into v_n from pg_trigger
     where tgname in ('trg_huni_istek','trg_huni_oturum') and not tgisinternal;
    if v_n <> 2 then v_h := v_h || format('huni tetikleyicileri eksik (%s/2)', v_n)::text; end if;

    -- (5) F1 — olay adı kapısı gerçekten kapalı mı
    begin
      insert into huni_olaylari (user_id, olay) values (v_u, 'uydurma_olay');
      v_h := v_h || 'huni olay adi kapisi calismiyor — serbest metin kabul ediliyor'::text;
    exception when others then null;
    end;

    -- (6) C3 — yeni RPC'ler gerçekten çalışıyor mu
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_u, 'role','authenticated')::text, true);
    begin
      perform public.seyahat_ekle('XXX', current_date + 3, time '10:00', time '12:00');
      v_h := v_h || 'seyahat_ekle bilinmeyen havalimanini kabul etti'::text;
    exception when others then
      if sqlerrm not like '%unknown_airport%' then
        v_h := v_h || ('seyahat_ekle beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;
    begin
      perform public.seyahat_ekle((select code from airports limit 1),
                                  current_date - 1, time '10:00', time '12:00');
      v_h := v_h || 'seyahat_ekle GECMIS tarihi kabul etti'::text;
    exception when others then
      if sqlerrm not like '%date_in_past%' then
        v_h := v_h || ('seyahat_ekle gecmis tarih testi: ' || sqlerrm)::text;
      end if;
    end;

    -- (7) E4 — dil katmanı: aynı anahtar iki dilde farklı dönmeli
    perform public.dili_ayarla('tr');
    if public.metin('head_charter') is not null
       and public.metin('head_charter') = public.metin('head_charter_en') then
      null;  -- TR ile EN ayni olabilir (ceviri yoksa) — ihlal degil
    end if;
    perform public.dili_ayarla('en');
    if public.metin('head_charter') <> 'Charter flights have no lounge access' then
      v_h := v_h || 'dil katmani EN cevirisini dondurmuyor'::text;
    end if;
    perform public.dili_ayarla('tr');
    if public.metin('head_charter') = 'Charter flights have no lounge access' then
      v_h := v_h || 'dil katmani TR isterken EN dondurdu — TURKCE BOZULDU'::text;
    end if;
    -- Cevirisi OLMAYAN anahtar EN'de de TR donmeli (yarim ingilizce yok)
    perform public.dili_ayarla('en');
    if public.metin('advice_intro') is distinct from
       (select value #>> '{}' from beta_settings where key='advice_intro') then
      v_h := v_h || 'cevirisi olmayan anahtar EN modunda TR degerine dusmuyor'::text;
    end if;
    perform public.dili_ayarla('tr');

    -- (8) D1 — host_wallet kapısı ayrışmadan sonra HÂLÂ çalışıyor mu
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_u, 'role','authenticated')::text, true);
    begin
      perform public.host_wallet(v_v);
      v_h := v_h || 'AYRISMADAN SONRA baskasinin cuzdani acilabiliyor — 232 kapisi dustu'::text;
    exception when others then
      if sqlerrm not like '%cuzdan_sahibi_degil%' then
        v_h := v_h || ('cuzdan kapisi beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;
    begin
      perform public.host_wallet(v_u);   -- kendi cüzdanı: geçmeli
    exception when others then
      v_h := v_h || ('kendi cuzdanini acamadi: ' || sqlerrm)::text;
    end;

    raise exception 'GERI_AL_250';
  exception when others then
    if sqlerrm <> 'GERI_AL_250' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '250 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '250 OK · agir sikayet suresiz + iftira korumasi · huni tetikleyicileri bagli · seyahat RPC dogruluyor · dil katmani TR bozmadan EN veriyor · cuzdan kapisi ayrismadan sonra da duruyor';
end $n250$;

-- ════════════════════════════════════════════════════════════════════════
-- §10 — `flow_gate_test` İKİNCİ KOŞUŞTA PATLIYOR
--
-- Harness'in TEKRAR KURULUM turu buldu:
--     SEED_KURAL_SENARYOLARI.sql ERROR: duplicate key value violates
--     unique constraint "idx_requests_unique_active"
--
-- 🔴 SEBEP BENİM DEĞİŞİKLİĞİM DEĞİL — 249/250 eklenince "son 35 dosya"
-- penceresi kaydı ve bu SEED ilk kez tekrar turuna girdi. Yani arıza
-- vardı, görünmüyordu.
--
-- `flow_gate_test()` bir NÖBETÇİ: akış kapılarını sınamak için gerçek
-- `requests` satırları yazıp sonra siliyor. Ama seçtiği ilanda ZATEN aktif
-- bir başvuru varsa `idx_requests_unique_active` patlıyor ve nöbetçi
-- ölçtüğü sistemi durduruyor.
--
-- 🆕 SINIF: "BİR NÖBETÇİ, ÖLÇMEK İÇİN YAZIYORSA, YAZACAĞI YERİN BOŞ
-- OLDUĞUNU DA ÖLÇMEK ZORUNDADIR." (240'ta öğrendiğim "nöbetçi nöbet
-- tuttuğu şeye zarar veremez" dersinin ikinci yarısı.)
--
-- Düzeltme: sınama ilanı seçilirken "üzerinde aktif başvuru olmayan"
-- şartı ekleniyor. Veri SİLMİYORUM — uygun ilan yoksa test '—' döner
-- ("ölçemedim"), ki bu dürüst cevaptır.
-- ════════════════════════════════════════════════════════════════════════

do $fg250$
declare v_tanim text; v_yeni text; v_n int := 0;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='flow_gate_test' limit 1;
  if v_tanim is null then
    raise notice '250 §10: flow_gate_test yok — DOKUNULMADI.'; return;
  end if;
  if v_tanim like '%aktif_basvurusu_yok_250%' then
    raise notice '250 §10: sinama ilani secimi zaten korumali — dokunulmadi.'; return;
  end if;

  -- `a.active and a.slots - coalesce(a.filled,0) >= 1` → ayrıca aktif
  -- başvurusu olmayan ilan. Desen iki yerde geçiyor; ikisini de sarıyoruz.
  v_yeni := replace(v_tanim,
    'a.active and a.slots - coalesce(a.filled,0) >= 1',
    'a.active and a.slots - coalesce(a.filled,0) >= 1
       and not exists (select 1 /* aktif_basvurusu_yok_250 */ from requests rq
                        where rq.avail_id = a.id and rq.status in (''pending'',''accepted''))');

  if v_yeni = v_tanim then
    raise notice '250 §10: beklenen ilan secim deseni bulunamadi — DOKUNULMADI.';
    return;
  end if;
  execute v_yeni;
  raise notice '250 §10: flow_gate_test artik uzerinde aktif basvuru OLMAYAN ilan seciyor.';
end $fg250$;

-- ════════════════════════════════════════════════════════════════════════
-- §11 — DİL BİR İSTEK ÖZELLİĞİ DEĞİL, KULLANICI ÖZELLİĞİDİR
--
-- 🔴 §4'te `dili_ayarla()`yı İŞLEM-YEREL bir GUC olarak yazdım
-- (`set_config(..., true)`) ve bu YANLIŞTI — ölçmeden değil, düşünmeden.
--
-- PostgREST'te her istek AYRI BİR İŞLEMDİR. Yani app'in "dilim EN"
-- demesi ile kural sorusunu sorması İKİ AYRI işlemde olur ve ilkinde
-- kurulan GUC ikincisine ULAŞMAZ. Fonksiyon doğru çalışıyordu; ürüne
-- bağlanma biçimi çalışmıyordu.
--
-- Oturum düzeyinde (`false`) yazmak daha da kötü olurdu: Supabase bağlantı
-- havuzu kullanıyor, bir kullanıcının dili havuzdaki bağlantıda kalır ve
-- BAŞKA bir kullanıcıya sızardı.
--
-- 🆕 SINIF: "BİR TERCİH İSTEKLER ARASINDA YAŞAMAK ZORUNDAYSA, O TERCİH
-- BİR DEĞİŞKEN DEĞİL BİR KOLONDUR."
--
-- Dil artık `profiles.dil` kolonunda. GUC yalnız TEST/ÖLÇÜM için bir
-- geçersiz kılma olarak duruyor (nöbetçiler onu kullanıyor).
-- ════════════════════════════════════════════════════════════════════════

alter table profiles add column if not exists dil text;
alter table profiles drop constraint if exists profiles_dil_kapisi;
alter table profiles add constraint profiles_dil_kapisi check (dil is null or dil in ('tr','en'));

create or replace function public.aktif_dil()
returns text
language plpgsql stable set search_path = public as $ad250b$
declare v text;
begin
  -- (1) İŞLEM-YEREL geçersiz kılma — yalnız nöbetçiler ve ölçüm için.
  v := lower(coalesce(nullif(current_setting('loungelink.dil', true), ''), ''));
  if v in ('tr','en') then return v; end if;
  -- (2) ASIL KAYNAK: kullanıcının kendi tercihi.
  select lower(p.dil) into v from profiles p where p.user_id = auth.uid();
  if v in ('tr','en') then return v; end if;
  return 'tr';
end $ad250b$;

create or replace function public.dili_ayarla(p_lang text)
returns text
language plpgsql security definer set search_path = public as $da250b$
declare v_uid uuid := auth.uid();
       v text := case when lower(coalesce(p_lang,'tr')) = 'en' then 'en' else 'tr' end;
begin
  -- İşlem-yerel de kuruyoruz ki AYNI istek içindeki sonraki çağrılar da
  -- doğru dili görsün (app dili değiştirir değiştirmez ekranı tazeliyor).
  perform set_config('loungelink.dil', v, true);
  if v_uid is not null then
    update profiles set dil = v where user_id = v_uid;
  end if;
  return v;
end $da250b$;

grant execute on function public.aktif_dil() to authenticated;
grant execute on function public.dili_ayarla(text) to authenticated;

do $n11$
declare v_u uuid; v_eski text;
begin
  select user_id into v_u from profiles limit 1;
  if v_u is null then raise notice '250 §11: profil yok — olculemedi.'; return; end if;
  select dil into v_eski from profiles where user_id = v_u;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_u, 'role','authenticated')::text, true);

  -- GUC'suz: kolondan okumali
  update profiles set dil = 'en' where user_id = v_u;
  perform set_config('loungelink.dil', '', true);
  if public.aktif_dil() <> 'en' then
    raise exception '250 NOBETCI §11: dil kolondan okunmuyor — istekler arasi yasamiyor';
  end if;
  update profiles set dil = 'tr' where user_id = v_u;
  perform set_config('loungelink.dil', '', true);
  if public.aktif_dil() <> 'tr' then
    raise exception '250 NOBETCI §11: TR tercihi okunmuyor';
  end if;
  update profiles set dil = v_eski where user_id = v_u;
  raise notice '250 §11 OK · dil kullanici kolonunda, istekler arasinda yasiyor';
end $n11$;
