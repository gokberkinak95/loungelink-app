-- ============================================================================
-- 255 — MAĞAZA ŞARTLARI (254'ten SONRA çalıştır)
--
-- Mağaza gönderimi denetiminin sunucu tarafı gerektiren üç maddesi.
--
--  §1  SOHBET İÇERİK SÜZGECİ. Apple Guideline 1.2, kullanıcı üretimi
--      içerik barındıran uygulamalardan "sakıncalı içeriği SÜZME yöntemi"
--      ister. Bizde şikâyet ve engelleme VAR, süzgeç YOKTU — ve bu ikisi
--      1.2'nin tamamı değil.
--      Ölçüm: `rnapp` içinde profanity/filter/mask araması → 0 sonuç.
--
--      Süzgeç aynı anda ÜRÜNÜN KENDİ KURALINI da uyguluyor: platform dışı
--      ödeme yasak (Platform Sözleşmesi md.7) ve kayıtta ayrıca onaylanıyor
--      — ama hiçbir yerde TESPİT edilmiyordu.
--
--  §2  18 YAŞ ONAYI. Sözleşme 18 yaş sınırı koyuyor, akış hiç sormuyordu.
--
--  §3  ÖDÜL KATALOĞUNDA HUKUKİ ÇELİŞKİ. Site altı yerde "misafir hakkını
--      paylaşana ödül olarak misafir hakkı vermek, programların yasakladığı
--      bir takastır" diyor; katalogda `+2 Misafir İsteği Kredisi` duruyordu.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — SOHBET SÜZGECİ: MASKELE, İŞARETLE, ENGELLEME
--
-- 🔵 TASARIM KARARI: mesajı REDDETMİYORUZ, MASKELİYORUZ.
-- Reddetmek, iki yabancının kapıda 40 dakikası varken konuşmayı kesmek
-- demek — ve yanlış pozitif bir süzgeç ürünü kilitler. Maskelemek hem
-- riski kaldırıyor hem konuşmayı sürdürüyor; işaretlenen mesaj moderasyona
-- düşüyor.
--
-- 🆕 SINIF: "BİR SÜZGEÇ, YANLIŞ POZİTİFİNDE ÜRÜNÜ DURDURUYORSA, SÜZGEÇ
-- DEĞİL FREN'DİR."
--
-- ⚠️ TELEFON NUMARASI NEDEN MASKELENİYOR: platform dışına çıkan bir
-- konuşma, uyuşmazlıkta kanıtsız kalır ve güvenlik akışı (SOS, şikâyet,
-- oturum kaydı) devre dışı kalır. Kullanıcıya bunu SÖYLÜYORUZ — sessizce
-- silmiyoruz.
-- ════════════════════════════════════════════════════════════════════════

insert into beta_settings (key, value) values
  ('sohbet_maske_notu_tr', to_jsonb('İletişim bilgisi ve ödeme bilgisi sohbette gizlenir. Platform dışına çıkan bir buluşmada güvenlik akışımız (SOS, şikâyet, oturum kaydı) seni koruyamaz.'::text)),
  ('sohbet_maske_notu_tr_en', to_jsonb('Contact and payment details are hidden in chat. If you move off-platform, our safety flow (SOS, reporting, session record) cannot protect you.'::text))
on conflict (key) do nothing;

create or replace function public.sohbet_temizle(p_body text)
returns jsonb
language plpgsql immutable set search_path = public as $st255$
declare v text := coalesce(p_body, ''); v_sebep text[] := '{}';
begin
  -- IBAN (TR + genel) — platform dışı ödeme talebinin en net işareti.
  if v ~* '\m[A-Z]{2}[0-9]{2}[ ]?([0-9A-Z][ ]?){10,30}\M' then
    v := regexp_replace(v, '\m[A-Z]{2}[0-9]{2}[ ]?([0-9A-Z][ ]?){10,30}\M', '••• IBAN gizlendi •••', 'gi');
    v_sebep := v_sebep || 'iban'::text;
  end if;

  -- Kart numarası (13-19 hane, arada boşluk/tire olabilir)
  if v ~ '(\d[ -]?){13,19}' then
    v := regexp_replace(v, '(\d[ -]?){13,19}', '••• kart no gizlendi •••', 'g');
    v_sebep := v_sebep || 'kart_no'::text;
  end if;

  -- Telefon: +90..., 05..., ya da 10+ haneli dizi
  if v ~ '(\+?\d[ ()\-]?){10,15}' then
    v := regexp_replace(v, '(\+?\d[ ()\-]?){10,15}', '••• numara gizlendi •••', 'g');
    v_sebep := v_sebep || 'telefon'::text;
  end if;

  -- E-posta
  if v ~* '[[:alnum:]._%%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' then
    v := regexp_replace(v, '[[:alnum:]._%%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}', '••• e-posta gizlendi •••', 'gi');
    v_sebep := v_sebep || 'eposta'::text;
  end if;

  -- Platform dışı ödeme dili — MASKELENMEZ, yalnız İŞARETLENİR.
  -- Cümleyi gizlemek konuşmayı anlamsızlaştırırdı; moderasyon görsün yeter.
  if coalesce(p_body,'') ~* '(havale|eft|iban|papara|nakit|elden öde|elden odeme|kapıda öde|dışarıdan öde|whatsapp|telegram|instagram)' then
    v_sebep := v_sebep || 'platform_disi'::text;
  end if;

  return jsonb_build_object('body', v, 'sebep', v_sebep,
                            'degisti', (v is distinct from coalesce(p_body,'')));
end $st255$;

create or replace function public.trg_sohbet_suzgeci() returns trigger
language plpgsql security definer set search_path = public as $tss255$
declare v jsonb;
begin
  v := public.sohbet_temizle(new.body);
  new.body := v ->> 'body';
  if jsonb_array_length(coalesce(v -> 'sebep', '[]'::jsonb)) > 0 then
    new.flagged := true;
    new.flag_reason := array_to_string(
      array(select jsonb_array_elements_text(v -> 'sebep')), ',');
  end if;
  return new;
exception when others then
  -- 🔴 SÜZGEÇ, MESAJI DÜŞÜREMEZ. Bir moderasyon aracının arızası
  -- kullanıcının konuşmasını kesmemeli.
  return new;
end $tss255$;

drop trigger if exists trg_sohbet_suzgeci on messages;
create trigger trg_sohbet_suzgeci before insert on messages
  for each row execute function public.trg_sohbet_suzgeci();

grant execute on function public.sohbet_temizle(text) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — 18 YAŞ ONAYI KAYIT AKIŞINA GİRDİ (istemci v2.99)
--
-- Platform Sözleşmesi 18 yaş sınırı koyuyor; akış hiç sormuyordu.
-- Mağaza yaş derecelendirmesi (yabancılarla sohbet + yüz yüze buluşma)
-- ile sözleşme arasındaki boşluk buydu.
--
-- 🆕 SINIF: "SÖZLEŞMEDE YAZAN AMA AKIŞTA SORULMAYAN BİR ŞART, ŞART DEĞİL
-- TEMENNİDİR."
--
-- ⚠️ DOĞUM TARİHİ SORMUYORUZ — bilerek. Doğrulanamayan bir doğum tarihi
-- toplamak, KVKK açısından gereksiz veri toplamaktır; beyan yeterli ve
-- sözleşmenin dayanağı olur.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.yas_onayim()
returns boolean
language sql stable security definer set search_path = public as $yo255$
  select exists (select 1 from consents c
                  where c.user_id = auth.uid() and c.type = 'age_18');
$yo255$;

grant execute on function public.yas_onayim() to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §2b — CİNSİYET BEYANI İÇİN KAPI (253 §5'in doğal sonucu)
--
-- 🔴 253 `users.gender` yazma hakkını istemciden aldı — doğru karar:
-- erkek bir hesap tek `update` ile kadın güvenlik modundaki kadınların
-- listesine giriyordu. Ama "Profili Düzenle" ekranı o kolona DOĞRUDAN
-- yazıyordu (`screens.js:6186`); hak kapanınca ekran 42501 alacaktı.
--
-- Nöbetçi (`rpc_field_e2e`) bunu ölçüp söyledi: "uygulama bu tabloya
-- yazıyor ama `authenticated` yetkisi YOK".
--
-- 🆕 SINIF: "BİR HAKKI KAPATMAK, ONU KULLANAN EKRANI DA KAPATIR —
-- KAPATIRKEN YERİNE NE KOYDUĞUNU BİLMİYORSAN, GÜVENLİK DEĞİL KESİNTİ
-- YAPMIŞ OLURSUN."
--
-- Kapı: beyan BİR KEZ yazılır (253'teki tetikleyici zaten bunu zorluyor),
-- değişiklik yönetim işidir ve denetim kaydına düşer.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.cinsiyetimi_bildir(p_gender text)
returns jsonb
language plpgsql security definer set search_path = public as $cb255$
declare v_uid uuid := auth.uid(); v_eski text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if coalesce(p_gender,'') not in ('female','male','other') then
    return jsonb_build_object('ok', false, 'reason', 'gecersiz_cinsiyet');
  end if;

  select gender::text into v_eski from users where id = v_uid;
  if v_eski is not null and v_eski is distinct from p_gender then
    -- Kullanıcıya sebebini SÖYLÜYORUZ; sessizce yok saymak,
    -- "kaydedildi" deyip kaydetmemek olurdu.
    return jsonb_build_object('ok', false, 'reason', 'cinsiyet_degistirilemez');
  end if;
  if v_eski is not null then
    return jsonb_build_object('ok', true, 'degisiklik', false);
  end if;

  update users set gender = p_gender::user_gender, updated_at = now() where id = v_uid;
  return jsonb_build_object('ok', true, 'degisiklik', true);
end $cb255$;

grant execute on function public.cinsiyetimi_bildir(text) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — ÖDÜL KATALOĞUNDAKİ HUKUKİ ÇELİŞKİ
--
-- 🔴 Web sitesi ALTI ayrı yerde şunu söylüyor:
--     "misafir hakkını paylaşan kişiye ÖDÜL OLARAK MİSAFİR HAKKI vermek,
--      ilişkiyi programların YASAKLADIĞI bir takasa çevirirdi."
-- Ve katalogda `+2 Misafir İsteği Kredisi · 500 puan` AKTİF duruyordu.
-- Yani ürün, kendi yazdığı yasağı 500 puana satıyordu:
--     ağırla → puan → misafir olma hakkı.
--
-- Bir program (THY M&S, Priority Pass) hukuk birimi bu iki ekranı yan yana
-- koyduğunda savunma kalmaz.
--
-- 🆕 SINIF: "ÜRÜNÜN HUKUKİ SAVUNMASI METİNDE DEĞİL MEKANİZMADA YAŞAR —
-- METİN 'YASAK' DERKEN MEKANİZMA SATIYORSA, GEÇERLİ OLAN MEKANİZMADIR."
--
-- ⚠️ YALNIZ BU KALEM KAPATILIYOR. `Sık Uçan Planı · 1 ay` DOKUNULMADI ve
-- kapatılmadı: SQL 236'da Gökberk'in ONAYLADIĞI "2 ağırlamada 30 gün
-- ücretsiz üst plan" mekanizması zaten var; katalogdaki kalem onun puanla
-- alınabilen hâli. Bu, benim tek başıma vereceğim bir karar değil — üst
-- planın aylık KREDİSİ olduğu için aynı döngüyü bir adım dolaylı kuruyor
-- olabilir. Ölçtüm, işaretledim, KARARI GÖKBERK'E VE AVUKATINA BIRAKTIM.
-- ════════════════════════════════════════════════════════════════════════

update rewards set active = false
 where lower(title) like '%misafir isteği kredisi%'
    or lower(title) like '%misafir istegi kredisi%';

insert into beta_settings (key, value) values
  ('odul_hukuki_soru', to_jsonb(
    'AÇIK KARAR: `Sık Uçan Planı · 1 ay` ödülü katalogda AKTİF. Üst plan aylık '
    'kredi taşıdığı için "ağırla → puan → misafir olma hakkı" döngüsünü bir adım '
    'dolaylı kuruyor olabilir. SQL 236''daki otomatik plan hediyesi de aynı soruyu '
    'taşıyor. Avukat görüşü alınana kadar bu satır burada duruyor ki karar '
    'unutulmasın.'::text))
on conflict (key) do update set value = excluded.value;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════

do $n255$
declare v_h text[] := '{}'; v jsonb; v_ben uuid; v_kanal uuid; v_mid uuid; v_govde text;
begin
  begin
    -- (1) Maskeleme gerçekten çalışıyor mu — HER SINIF ayrı ayrı.
    v := public.sohbet_temizle('IBAN TR330006100519786457841326 gonderirim');
    if (v ->> 'body') like '%TR33%' then v_h := v_h || 'IBAN maskelenmedi'::text; end if;

    v := public.sohbet_temizle('numaram 05321234567 arayin');
    if (v ->> 'body') like '%05321234567%' then v_h := v_h || 'telefon maskelenmedi'::text; end if;

    v := public.sohbet_temizle('mail: kisi@ornek.com');
    if (v ->> 'body') like '%@ornek.com%' then v_h := v_h || 'eposta maskelenmedi'::text; end if;

    -- (2) 🔴 YANLIŞ POZİTİF TESTİ. Bir süzgecin en tehlikeli hâli, masum
    -- cümleyi bozmasıdır. Normal bir mesaj DEĞİŞMEMELİ.
    v := public.sohbet_temizle('Merhaba, saat 14:30 gibi kapida bulusalim mi?');
    if (v ->> 'degisti')::boolean then
      v_h := v_h || format('MASUM MESAJ BOZULDU: %s', v ->> 'body')::text;
    end if;

    -- (3) Platform dışı ödeme dili İŞARETLENMELİ ama MASKELENMEMELİ.
    v := public.sohbet_temizle('elden odeme yapalim');
    if (v ->> 'degisti')::boolean then
      v_h := v_h || 'platform disi ifade MASKELENDI — maskelenmemeliydi'::text;
    end if;
    if not (v -> 'sebep' ? 'platform_disi') then
      v_h := v_h || 'platform disi odeme dili ISARETLENMEDI'::text;
    end if;

    -- (4) TETİKLEYİCİ gerçekten devrede mi — fonksiyonu değil AKIŞI ölç.
    select m.channel_id, m.from_id into v_kanal, v_ben
      from messages m order by m.created_at desc limit 1;
    if v_kanal is not null then
      insert into messages (channel_id, from_id, body)
      values (v_kanal, v_ben, 'numaram 05329998877')
      returning id, body into v_mid, v_govde;
      if v_govde like '%05329998877%' then
        v_h := v_h || 'TETIKLEYICI devrede degil — mesaj maskelenmeden yazildi'::text;
      end if;
      if not (select flagged from messages where id = v_mid) then
        v_h := v_h || 'maskelenen mesaj ISARETLENMEDI (moderasyon gormez)'::text;
      end if;
    end if;

    -- (4b) Cinsiyet kapısı: ikinci yazma REDDEDİLMELİ.
    select u.id into v_ben from users u where u.gender is not null limit 1;
    if v_ben is not null then
      perform set_config('request.jwt.claims', json_build_object('sub', v_ben::text)::text, true);
      v := public.cinsiyetimi_bildir(
             case when (select gender::text from users where id=v_ben) = 'female'
                  then 'male' else 'female' end);
      if coalesce(v ->> 'ok','') <> 'false' then
        v_h := v_h || 'cinsiyet DEGISTIRILEBILDI — kadin guvenlik modu hala atlatilabilir'::text;
      end if;
      perform set_config('request.jwt.claims', '', true);
    end if;

    -- (5) Ödül kataloğundaki çelişki kapandı mı.
    if exists (select 1 from rewards
                where active and lower(title) like '%misafir isteği kredisi%') then
      v_h := v_h || 'odul katalogunda `misafir istegi kredisi` HALA AKTIF'::text;
    end if;

    raise exception 'GERI_AL_255';
  exception when others then
    if sqlerrm <> 'GERI_AL_255' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '255 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '255 OK · sohbet suzgeci calisiyor · masum mesaj bozulmuyor · odul celiskisi kapandi';
end $n255$;

insert into rpc_client_surface (fn_name, client, note) values
  ('yas_onayim', 'app', '18 yas onayi verilmis mi (255)'),
  ('cinsiyetimi_bildir', 'app', 'Cinsiyet beyani — bir kez yazilir (255)')
on conflict (fn_name) do update set note = excluded.note;

select public.migration_kaydet('255_magaza_sartlari.sql');

commit;

select '255 KURULDU' as sonuc,
       (select count(*) from rewards where active) as aktif_odul,
       (select count(*) from pg_trigger where tgname = 'trg_sohbet_suzgeci') as suzgec;
