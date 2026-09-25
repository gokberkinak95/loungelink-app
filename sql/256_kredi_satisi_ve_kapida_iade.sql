-- ============================================================================
-- 256 — KREDİ SATIŞI VE KAPIDA İADE (255'ten SONRA çalıştır)
--
-- Gökberk'in kararı: "Krediyi para karşılığı satacak mısın? evet, app'deki gibi
-- belli bir para karşılığı bence en mantıklısı."
--
-- ----------------------------------------------------------------------------
-- 🔴 KATILIYORUM — AMA BUGÜNKÜ HÂLİYLE SATMAK SAVUNMAYI ÇÜRÜTÜR
-- ----------------------------------------------------------------------------
-- Ürünün tek hukuki savunması şu cümle: "LoungeLink lounge erişimi satmaz ve
-- satamaz." Kredi satılınca sitenin iki cümlesi anında yalan olur:
--     "Kredi bir ödeme değil, bir TEMİNATTIR."
--     "LoungeLink bundan gelir elde etmez."
--
-- Savunmayı ayakta tutan çerçeve tek: **KREDİ ERİŞİMİ DEĞİL, İSTEME HAKKINI
-- SATIN ALIR.** Ve bu bir kelime oyunu olmaktan çıkıp GERÇEK olması için üç
-- şeyin fiilen öyle olması gerekir:
--
--   1. Host reddedebilir                     → VAR (`respond_request`)
--   2. Yanıtsız kalırsa kredi iade edilir    → VAR (SQL 249, 72 saat)
--   3. KAPIDA GİREMEZSEN KREDİ İADE EDİLİR   → **YOKTU.** İşte tam o vakada
--      satılan şey istek değil ERİŞİM olur — ve tutulmamış olur.
--
-- 🆕 SINIF: "BİR ŞEYİ 'SATMIYORUZ' DİYE SAVUNMAK, O ŞEY GERÇEKLEŞMEDİĞİNDE
-- PARAYI GERİ VERMEYİ GEREKTİRİR — YOKSA SATMIŞSINDIR."
--
-- Ve bu yalnız hukuk değil ÜRÜN: misafirin ilk isteği göndermesini engelleyen
-- korku "ya alınmazsam?" korkusudur. Cevabı "o zaman kredin geri" olduğunda o
-- korku kalkar. Aynı kayıt üstelik KURAL MOTORUNUN EN DEĞERLİ GERİ BESLEMESİ:
-- beş kişi "PP ile IST'te alınmadım" diyorsa kuralımız yanlıştır.
--
-- ----------------------------------------------------------------------------
-- 🔒 SATIN ALMA İSTEMCİDEN YAPILAMAZ — `change_plan` DERSİ
-- ----------------------------------------------------------------------------
-- 253 §2, ödeme kanıtı aramayan `change_plan`'ın 7 çağrıda 4 krediyi 48'e
-- çıkardığını ölçtü. Aynı hatayı ikinci kez yapmamak için kredi basan
-- fonksiyon `authenticated`e HİÇ AÇILMIYOR: yalnız `service_role`, yalnız
-- DOĞRULANMIŞ bir mağaza makbuzuyla, ve makbuz kimliği TEKİL.
--
-- Akış:  App → IAP (StoreKit / Play Billing) → makbuz
--             → Backoffice /api/iap (service key, Apple/Google'a doğrulatır)
--             → kredi_paketi_isle(...)
--
-- ⚠️ Apple Guideline 3.1.1: uygulama içinde satılan dijital hak IAP ile
-- satılmak ZORUNDA. iyzico/Stripe yalnız WEB satışı için kullanılabilir.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — SATIŞ DEFTERİ: MAKBUZ KİMLİĞİ TEKİLDİR
--
-- Tekillik kısıtı bir süs değil: mağaza makbuzu tekrar gönderilebilir
-- (ağ hatası, kullanıcı "geri yükle" der, saldırgan bilerek tekrarlar).
-- Tekil olmayan bir makbuz, sınırsız kredi demektir.
--
-- 🆕 SINIF: "BİR ÖDEME KANITI TEKRAR KULLANILABİLİYORSA, KANIT DEĞİL
-- BİR ŞABLONDUR."
-- ════════════════════════════════════════════════════════════════════════

create table if not exists kredi_satislari (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references users(id) on delete cascade,
  saglayici      text not null,
  makbuz_kimlik  text not null,
  paket_kod      text not null,
  kredi          int  not null,
  fiyat_try      numeric(10,2),
  para_birimi    text default 'TRY',
  durum          text not null default 'dogrulandi',
  makbuz_ham     jsonb,
  created_at     timestamptz not null default now()
);

alter table kredi_satislari drop constraint if exists kredi_satis_saglayici;
alter table kredi_satislari add constraint kredi_satis_saglayici
  check (saglayici in ('apple','google','web','manuel'));
alter table kredi_satislari drop constraint if exists kredi_satis_durum;
alter table kredi_satislari add constraint kredi_satis_durum
  check (durum in ('dogrulandi','iade','iptal'));

create unique index if not exists uq_kredi_makbuz
  on kredi_satislari (saglayici, makbuz_kimlik);

alter table kredi_satislari enable row level security;
drop policy if exists kredi_satis_kendi on kredi_satislari;
create policy kredi_satis_kendi on kredi_satislari for select to authenticated
  using (user_id = auth.uid());
revoke all on kredi_satislari from anon;
revoke insert, update, delete on kredi_satislari from authenticated;
grant select on kredi_satislari to authenticated;
grant select, insert, update on kredi_satislari to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — KREDİYİ BASAN TEK KAPI — İSTEMCİYE KAPALI
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.kredi_paketi_isle(
  p_user uuid, p_saglayici text, p_makbuz_kimlik text,
  p_paket_kod text, p_makbuz jsonb default null)
returns jsonb
language plpgsql security definer set search_path = public as $kpi256$
declare v_p kredi_paketleri%rowtype; v_bal int; v_id uuid;
begin
  -- 🔴 İSTEMCİ BURAYA HİÇ GELEMEZ. `auth.uid()` doluysa çağıran bir
  -- kullanıcıdır ve o yalnız YÖNETİCİ olabilir (manuel tanımlama için).
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  if coalesce(btrim(p_makbuz_kimlik),'') = '' then
    raise exception 'makbuz_kimligi_bos';
  end if;

  select * into v_p from kredi_paketleri where kod = p_paket_kod and aktif;
  if v_p.kod is null then raise exception 'paket_yok'; end if;

  -- Aynı makbuz ikinci kez gelirse: HATA DEĞİL, "zaten işlendi".
  -- Mağaza makbuzu ağ hatasında tekrar gönderilir; hata döndürmek
  -- kullanıcının parasını ödeyip kredisini alamamasına yol açardı.
  if exists (select 1 from kredi_satislari
              where saglayici = p_saglayici and makbuz_kimlik = p_makbuz_kimlik) then
    return jsonb_build_object('ok', true, 'zaten_islendi', true);
  end if;

  insert into kredi_satislari (user_id, saglayici, makbuz_kimlik, paket_kod,
                               kredi, fiyat_try, makbuz_ham)
  values (p_user, p_saglayici, p_makbuz_kimlik, v_p.kod, v_p.kredi, v_p.fiyat_try, p_makbuz)
  returning id into v_id;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = p_user;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
  values (p_user, v_p.kredi, 'kredi_satin_alma', v_id, v_bal + v_p.kredi,
          format('%s · %s kredi', v_p.ad, v_p.kredi));

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (p_user, 'credits', 'Kredin yüklendi',
          format('%s kredi cüzdanına eklendi.', v_p.kredi), 'credit', v_id);

  return jsonb_build_object('ok', true, 'kredi', v_p.kredi, 'satis_id', v_id);
end $kpi256$;

revoke all on function public.kredi_paketi_isle(uuid, text, text, text, jsonb) from public;
revoke all on function public.kredi_paketi_isle(uuid, text, text, text, jsonb) from anon;
revoke all on function public.kredi_paketi_isle(uuid, text, text, text, jsonb) from authenticated;
grant execute on function public.kredi_paketi_isle(uuid, text, text, text, jsonb) to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — KAPIDA GİREMEDİM: PARA GERİ, VE KURAL MOTORU ÖĞRENSİN
--
-- 🔴 SATIŞIN ŞARTI BU BÖLÜM. Kredi satılıyorsa, satılan şeyin "istek hakkı"
-- olduğu iddiası ancak buluşma gerçekleşmediğinde paranın geri dönmesiyle
-- doğru olur.
--
-- 🔵 VE BU BİR MALİYET DEĞİL, EN DEĞERLİ GERİ BESLEME:
-- Kural motoru "bu kart bu salona girer" diyorsa ve beş kişi kapıda
-- alınmadıysa, KURALIMIZ YANLIŞTIR. Bu tabloyu BO okuyor.
--
-- 🆕 SINIF: "BİR İADE KAYDI YALNIZ PARAYI GERİ VERİYORSA MALİYETTİR;
-- NEDENİNİ DE KAYDEDİYORSA ÖLÇÜM ALETİDİR."
-- ════════════════════════════════════════════════════════════════════════

create table if not exists kapida_retler (
  id           uuid primary key default uuid_generate_v4(),
  session_id   uuid not null references sessions(id) on delete cascade,
  guest_id     uuid not null references users(id),
  host_id      uuid not null references users(id),
  lounge_id    uuid,
  airport_code char(3),
  sebep        text not null,
  aciklama     text,
  iade_edildi  boolean not null default false,
  created_at   timestamptz not null default now()
);

alter table kapida_retler drop constraint if exists kapida_ret_sebep;
alter table kapida_retler add constraint kapida_ret_sebep check (
  sebep in ('kural_tutmadi','kapasite_dolu','host_gelmedi','belge_istendi','diger'));

create unique index if not exists uq_kapida_ret_oturum on kapida_retler (session_id);
create index if not exists kapida_ret_salon on kapida_retler (lounge_id, created_at desc);

alter table kapida_retler enable row level security;
drop policy if exists kapida_ret_taraf on kapida_retler;
create policy kapida_ret_taraf on kapida_retler for select to authenticated
  using (guest_id = auth.uid() or host_id = auth.uid());
revoke all on kapida_retler from anon;
revoke insert, update, delete on kapida_retler from authenticated;
grant select on kapida_retler to authenticated;
grant select, insert, update on kapida_retler to service_role;

insert into beta_settings (key, value) values
  ('kapida_ret_saat', to_jsonb(24)),
  ('kapida_ret_notu_tr', to_jsonb('Kapıda alınmadıysan kredin iade edilir. Bize ne olduğunu söyle — aynı hatayı bir daha kimseye yaşatmayalım.'::text)),
  ('kapida_ret_notu_tr_en', to_jsonb('If you were turned away at the door, your credit is refunded. Tell us what happened so nobody hits the same wall again.'::text))
on conflict (key) do nothing;

create or replace function public.kapida_giremedim(
  p_session_id uuid, p_sebep text, p_aciklama text default null)
returns jsonb
language plpgsql security definer set search_path = public as $kg256$
declare
  v_uid uuid := auth.uid(); v_s sessions%rowtype; v_req requests%rowtype;
  v_av availabilities%rowtype; v_saat int; v_bal int; v_id uuid; v_iade boolean := false;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if coalesce(p_sebep,'') not in
     ('kural_tutmadi','kapasite_dolu','host_gelmedi','belge_istendi','diger') then
    return jsonb_build_object('ok', false, 'reason', 'gecersiz_sebep');
  end if;

  select * into v_s from sessions where id = p_session_id;
  if v_s.id is null then raise exception 'session_not_found'; end if;
  select * into v_req from requests where id = v_s.request_id;

  -- Yalnız MİSAFİR bildirebilir: kapıda alınmayan odur.
  if v_uid <> v_req.guest_id then raise exception 'not_guest'; end if;

  v_saat := coalesce((select (value #>> '{}')::int from beta_settings
                       where key = 'kapida_ret_saat'), 24);
  -- Pencere: oturumun üstünden çok geçtiyse bildirim ölçüm değil iddia olur.
  if coalesce(v_s.completed_at, v_s.started_at) < now() - make_interval(hours => v_saat) then
    return jsonb_build_object('ok', false, 'reason', 'sure_doldu', 'saat', v_saat);
  end if;
  if exists (select 1 from kapida_retler where session_id = p_session_id) then
    return jsonb_build_object('ok', false, 'reason', 'zaten_bildirildi');
  end if;

  select * into v_av from availabilities where id = v_req.avail_id;

  insert into kapida_retler (session_id, guest_id, host_id, lounge_id, airport_code,
                             sebep, aciklama)
  values (p_session_id, v_req.guest_id, v_req.host_id, v_av.lounge_id,
          v_av.airport_code, p_sebep, nullif(btrim(p_aciklama),''))
  returning id into v_id;

  -- İade: yalnız gerçekten kredi HARCANMIŞSA ve daha önce iade edilmemişse.
  -- Soğuk ağda ya da ulaşılamayan host'ta bedel zaten 0'dı.
  if exists (select 1 from credit_ledger cl
              where cl.ref_id = v_req.id and cl.reason = 'request_hold' and cl.delta < 0)
     and not exists (select 1 from credit_ledger cl
                      where cl.ref_id = v_req.id
                        and cl.reason in ('request_refund','request_stale_refund','kapida_ret_iade'))
  then
    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_req.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
    values (v_req.guest_id, 1, 'kapida_ret_iade', v_req.id, v_bal + 1,
            'Kapıda alınmadın — kredin iade edildi.');
    update kapida_retler set iade_edildi = true where id = v_id;
    v_iade := true;
  end if;

  -- Oturumu da kapat: "tamamlandı" sayılan bir buluşma olmadı.
  update sessions set status = 'cancelled', cancel_reason = 'kapida_ret',
         completed_at = coalesce(completed_at, now())
   where id = p_session_id and status <> 'cancelled';

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_req.guest_id, 'credits',
          case when v_iade then 'Kredin iade edildi' else 'Bildirimin alındı' end,
          case when v_iade then 'Kapıda alınmadığın için kredin cüzdanına geri kondu.'
               else 'Bu istek zaten kredi harcamamıştı. Bildirimin kural kaydımıza düştü.' end,
          'session', p_session_id);

  return jsonb_build_object('ok', true, 'iade', v_iade, 'kayit', v_id);
end $kg256$;

grant execute on function public.kapida_giremedim(uuid, text, text) to authenticated;

-- Misafir bunu NE ZAMAN görebilir: yalnız kendi tamamlanmış/aktif oturumunda,
-- ve süre penceresi içinde. İstemci kendi karar vermesin, sunucu söylesin.
create or replace function public.kapida_ret_bildirebilir_mi(p_session_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $krb256$
declare v_uid uuid := auth.uid(); v_s sessions%rowtype; v_req requests%rowtype; v_saat int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_s from sessions where id = p_session_id;
  if v_s.id is null then return jsonb_build_object('olur', false); end if;
  select * into v_req from requests where id = v_s.request_id;
  if v_uid <> v_req.guest_id then return jsonb_build_object('olur', false); end if;
  if exists (select 1 from kapida_retler where session_id = p_session_id) then
    return jsonb_build_object('olur', false, 'sebep', 'zaten_bildirildi');
  end if;
  v_saat := coalesce((select (value #>> '{}')::int from beta_settings
                       where key = 'kapida_ret_saat'), 24);
  if coalesce(v_s.completed_at, v_s.started_at) < now() - make_interval(hours => v_saat) then
    return jsonb_build_object('olur', false, 'sebep', 'sure_doldu');
  end if;
  return jsonb_build_object('olur', true, 'not', public.metin('kapida_ret_notu_tr'));
end $krb256$;

grant execute on function public.kapida_ret_bildirebilir_mi(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — BO: KURAL MOTORU NEREDE YANILIYOR
--
-- Bu ekranın cevapladığı soru "kaç iade verdik" DEĞİL:
--     HANGİ SALONDA KURALIMIZ TUTMUYOR?
-- Aynı salonda tekrar eden `kural_tutmadi`, katalog kaydımızın yanlış
-- olduğunun en doğrudan kanıtıdır.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.bo_kapida_retler(p_gun int default 90)
returns jsonb
language plpgsql stable security definer set search_path = public as $bkr256$
declare v_bas timestamptz := now() - make_interval(days => greatest(coalesce(p_gun,90),1));
        v_salon jsonb; v_sebep jsonb; v_ozet jsonb;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;

  select jsonb_build_object(
      'toplam', count(*),
      'iade_edilen', count(*) filter (where iade_edildi),
      'kural_tutmadi', count(*) filter (where sebep = 'kural_tutmadi'))
    into v_ozet from kapida_retler where created_at >= v_bas;

  select jsonb_agg(x order by x->>'adet' desc) into v_salon from (
    select jsonb_build_object(
             'lounge_id', k.lounge_id,
             'salon', coalesce(l.name, '(bilinmiyor)'),
             'airport', k.airport_code,
             'adet', count(*),
             'kural_tutmadi', count(*) filter (where k.sebep = 'kural_tutmadi'))  as x
      from kapida_retler k
      left join lounges l on l.id = k.lounge_id
     where k.created_at >= v_bas
     group by k.lounge_id, l.name, k.airport_code) t;

  select jsonb_object_agg(sebep, adet) into v_sebep
    from (select sebep, count(*) as adet from kapida_retler
           where created_at >= v_bas group by sebep) s;

  return jsonb_build_object('gun', greatest(coalesce(p_gun,90),1),
                            'ozet', coalesce(v_ozet,'{}'::jsonb),
                            'salonlar', coalesce(v_salon,'[]'::jsonb),
                            'sebepler', coalesce(v_sebep,'{}'::jsonb));
end $bkr256$;

grant execute on function public.bo_kapida_retler(int) to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — DİL: "TEMİNAT" ÇERÇEVESİ "İSTEK HAKKI"NA GEÇİYOR
--
-- Kredi satılıyorsa "teminat" demek yanlıştır. Ama "erişim" demek de
-- yanlıştır — ve tehlikelidir. Doğru ad: İSTEK HAKKI.
-- ════════════════════════════════════════════════════════════════════════

insert into beta_settings (key, value) values
  ('kredi_cerceve_tr', to_jsonb('Kredi, bir host''a istek gönderme hakkıdır — erişim değil. Host reddedebilir, yanıtsız kalırsa iade edilir, kapıda alınmazsan yine iade edilir.'::text)),
  ('kredi_cerceve_tr_en', to_jsonb('A credit is the right to send a host a request — not access. The host may decline; if nobody answers it is refunded; if you are turned away at the door it is refunded too.'::text))
on conflict (key) do update set value = excluded.value;

-- ════════════════════════════════════════════════════════════════════════
-- §6 — NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════

do $n256$
declare
  v_h text[] := '{}'; v jsonb; v_ben uuid; v_sid uuid; v_rid uuid; v_bal1 int; v_bal2 int;
  v_ap char(3); v_hid uuid; v_avid uuid;
begin
  begin
    -- (1) 🔴 EN ÖNEMLİ KAPI: kredi basan fonksiyon istemciye AÇIK OLMAMALI.
    if has_function_privilege('authenticated',
         'public.kredi_paketi_isle(uuid,text,text,text,jsonb)', 'execute') then
      v_h := v_h || 'kredi_paketi_isle ISTEMCIYE ACIK — `change_plan` hatasi TEKRARLANDI'::text;
    end if;

    -- (2) Makbuz tekilliği: aynı makbuz iki kez kredi BASMAMALI.
    select u.id into v_ben from users u where u.deleted_at is null order by u.created_at limit 1;
    select coalesce(sum(delta),0) into v_bal1 from credit_ledger where user_id = v_ben;
    perform public.kredi_paketi_isle(v_ben, 'apple', 'NOBETCI_MAKBUZ_1', 'tek', null);
    perform public.kredi_paketi_isle(v_ben, 'apple', 'NOBETCI_MAKBUZ_1', 'tek', null);
    select coalesce(sum(delta),0) into v_bal2 from credit_ledger where user_id = v_ben;
    if v_bal2 - v_bal1 <> 1 then
      v_h := v_h || format('ayni makbuz %s kredi basti (1 olmaliydi)', v_bal2 - v_bal1)::text;
    end if;

    -- (3) Kapıda iade GERÇEKTEN krediyi geri veriyor mu — akışı ölç.
    --
    -- 🔴 İLK YAZIMDA HAZIR BİR OTURUM ARADIM VE BULAMADIM: fikstürde
    -- "kredi harcanmış ama iade edilmemiş" bir oturum yoktu. Nöbetçi
    -- "ölçülemedi" deyip GEÇTİ — yani satışın ŞARTI olan mekanizma
    -- hiç sınanmadan yeşil yandı.
    -- 🆕 SINIF: "ÖLÇEMEDİĞİNİ SÖYLEYEN BİR NÖBETÇİ DÜRÜSTTÜR AMA
    -- NÖBETÇİ DEĞİLDİR — ÖLÇÜLECEK DURUMU KENDİSİ ÜRETMELİDİR."
    -- Artık durumu KENDİM kuruyorum (blok geri alınıyor).
    select code into v_ap from airports limit 1;
    if v_ap is not null then
      insert into users (email, password_hash, role)
      values ('n256_host@ll.test', 'x', 'host') returning id into v_hid;
      insert into users (email, password_hash, role)
      values ('n256_guest@ll.test', 'x', 'guest') returning id into v_ben;
      insert into profiles (user_id, name) values (v_hid,'N256 H'), (v_ben,'N256 G');
      insert into availabilities (host_id, airport_code, avail_date, time_from, time_to, slots, active)
      values (v_hid, v_ap, current_date, '08:00', '22:00', 1, true) returning id into v_avid;
      insert into requests (guest_id, host_id, avail_id, status)
      values (v_ben, v_hid, v_avid, 'accepted') returning id into v_rid;
      -- Kredinin GERÇEKTEN harcandığı hâli kur:
      insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
      values (v_ben, -1, 'request_hold', v_rid, -1);
      -- `sessions` host/guest taşımıyor; taraflar `requests` üzerinden okunuyor.
      insert into sessions (request_id, status, completed_at)
      values (v_rid, 'completed', now()) returning id into v_sid;
    end if;
    if v_sid is not null then
      perform set_config('request.jwt.claims', json_build_object('sub', v_ben::text)::text, true);
      select coalesce(sum(delta),0) into v_bal1 from credit_ledger where user_id = v_ben;
      v := public.kapida_giremedim(v_sid, 'kural_tutmadi', 'nobetci');
      select coalesce(sum(delta),0) into v_bal2 from credit_ledger where user_id = v_ben;
      if coalesce(v ->> 'ok','') <> 'true' then
        v_h := v_h || ('kapida_giremedim calismadi: ' || coalesce(v::text,''))::text;
      elsif (v ->> 'iade')::boolean and v_bal2 - v_bal1 <> 1 then
        v_h := v_h || 'iade dendi ama BAKIYE ARTMADI'::text;
      end if;

      -- (3b) İKİNCİ bildirim reddedilmeli (çifte iade kapısı).
      v := public.kapida_giremedim(v_sid, 'kural_tutmadi', 'ikinci');
      if coalesce(v ->> 'ok','') <> 'false' then
        v_h := v_h || 'ayni oturum IKINCI kez bildirildi — cifte iade kapisi'::text;
      end if;
      perform set_config('request.jwt.claims', '', true);
    else
      -- Artık burası yalnız `airports` boşsa çalışır; o hâlde de SUSMUYORUZ.
      v_h := v_h || 'airports BOS — kapida iade akisi OLCULEMEDI'::text;
    end if;

    -- (4) Yalnız MİSAFİR bildirebilmeli.
    if v_sid is not null then
      select r.host_id into v_ben from requests r where r.id = v_rid;
      perform set_config('request.jwt.claims', json_build_object('sub', v_ben::text)::text, true);
      begin
        perform public.kapida_giremedim(v_sid, 'diger', null);
        v_h := v_h || 'HOST kapida ret bildirebildi — yalniz misafir bildirmeli'::text;
      exception when others then
        if sqlerrm not like '%not_guest%' and sqlerrm not like '%zaten_bildirildi%' then
          v_h := v_h || ('host kapisi beklenmeyen hata: ' || sqlerrm)::text;
        end if;
      end;
      perform set_config('request.jwt.claims', '', true);
    end if;

    -- (5) BO okunabiliyor mu.
    v := public.bo_kapida_retler(90);
    if v -> 'salonlar' is null then
      v_h := v_h || 'bo_kapida_retler eksik dondu'::text;
    end if;

    raise exception 'GERI_AL_256';
  exception when others then
    perform set_config('request.jwt.claims', '', true);
    if sqlerrm <> 'GERI_AL_256' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '256 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '256 OK · kredi basan kapi istemciye kapali · makbuz tekil · kapida iade calisiyor · cifte iade engelli';
end $n256$;

insert into rpc_client_surface (fn_name, client, note) values
  ('kapida_giremedim',           'app', 'Kapida alinmadim — kredi iadesi + kural geri beslemesi (256)'),
  ('kapida_ret_bildirebilir_mi', 'app', 'Bu oturum icin kapida ret bildirilebilir mi (256)')
on conflict (fn_name) do update set note = excluded.note;

select public.migration_kaydet('256_kredi_satisi_ve_kapida_iade.sql');

commit;

select '256 KURULDU' as sonuc,
       (select count(*) from kredi_paketleri where aktif) as paket,
       has_function_privilege('authenticated',
         'public.kredi_paketi_isle(uuid,text,text,text,jsonb)', 'execute') as istemciye_acik;
