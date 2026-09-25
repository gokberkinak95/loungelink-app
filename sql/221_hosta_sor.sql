-- ============================================================================
-- LoungeLink · 221_hosta_sor.sql                           (19 Ağustos 2026)
--
-- KAPALI KAPININ ARKASINDA BİR İNSAN VAR — ONA SORALIM
--
-- 219 dürüst bir cümle yazdı: "misafir hakkı görünmüyor, doğrulayamadık,
-- başvuru kapalı, host'a sohbetten sorabilirsin". Gökberk haklı olarak
-- şunu söyledi: **o ekranda sohbet butonu yok.** Yani doğru cümleyi
-- yazdık ama işaret ettiğimiz kapı yoktu.
--
-- ── ÜÇ SEÇENEK VARDI, ÜÇÜNÜ DE DÜŞÜNDÜM ─────────────────────────────
--
-- (1) "Bağlantı kur"a yönlendir. Çalışır ama YANLIŞ SORUYU sorar:
--     bağlantı "tanışalım" demektir, burada sorulan şey "kartında
--     misafir hakkı var mı".
-- (2) "Gerçekten kapalı mı?" butonu + host onayı + sohbet. Bu, bağlantı
--     mekanizmasının İKİNCİ BİR KOPYASI olurdu. Aynı işi yapan iki
--     makine, ikisi de yarım bakımlı.
-- (3) Aşağıdaki: (1)'in RAYLARINI kullan, (2)'nin NİYETİNİ taşı.
--
-- ── SEÇTİĞİM YOL VE NEDENİ ──────────────────────────────────────────
--
-- Buradaki asıl sorun "misafir sohbet etmek istiyor" değil.
-- **Bizim verimiz eksik ve onu düzeltebilecek tek kişi host.**
--
-- O yüzden bu bir sohbet açma değil, bir VERİ SORUSU. Var olan bağlantı
-- raylarında gidiyor (`connection_requests`, `intent='kural_sorusu'`) —
-- yeni bir onay/sohbet makinesi kurmuyorum. Ama niyeti taşıyor:
--   · misafire: çıkışsız "hayır" yerine kapısı olan "şimdilik hayır"
--   · host'a: tek dokunuşla hakkını beyan etme daveti (092'nin
--     `save_host_access` ekranı zaten var)
--   · bize: hangi salonda verimizin yanlış olduğunu gösteren KAYIT
--
-- Host hakkını beyan ederse karar motoru yeniden hesaplar ve kapı
-- KENDİLİĞİNDEN açılır — özel bir "bu ilana izin ver" kaçamağı YOK.
-- Yani her kapalı kapı, kural motorunu besleyen bir fırsata dönüşüyor.
-- Ürünün asıl varlığı kural motoru; onu büyüten şey bu döngü.
--
-- ── AÇIKÇA YAPMADIKLARIM ────────────────────────────────────────────
-- · Kapıyı açmıyorum. `create_request` hâlâ reddediyor (159:217).
-- · DOĞRULANMIŞ "misafir alınmıyor" durumunda buton ÇIKMIYOR. Resmî
--   kaynaktan doğruladığımız bir kuralı host'a sormak, host'u boşuna
--   rahatsız etmek olur — ve bizi de güvenilmez yapar.
-- · Host'un cevabı kuralı GENEL olarak değiştirmiyor; kendi beyanını
--   değiştiriyor. Bir host'un sözüyle bütün programın kuralını
--   çevirmek, bugüne kadar kaçındığımız tek şeyi yapmak olurdu.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- 1) HANGİ İLANDA SORULABİLİR — TEK KAYNAK
--
-- Hem rozet motoru (butonu göstermek için) hem de RPC (isteği kabul
-- etmek için) AYNI fonksiyonu çağırır. İki yerde iki koşul yazsaydım
-- bugün 219'da kapattığım çelişkinin aynısını yeniden açardım.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.kural_sorusu_uygun_mu(p_avail_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare d jsonb;
begin
  d := public.lounge_access_decision(p_avail_id, null);

  -- Bilinmeyen ilan: soracak bir şey yok.
  if not coalesce((d ->> 'known')::boolean, false) then return false; end if;

  -- Yalnız "misafir hakkı yok" durumunda sorulur.
  if coalesce(d ->> 'guest_policy','') <> 'not_allowed' then return false; end if;

  -- 🔴 KESİNLİK KAPISI. `confidence` 'verified' ise resmî kaynaktan
  -- doğrulamışız demektir; host'a sormak hem onu rahatsız eder hem
  -- bizim doğruladığımız bilgiyi tartışmaya açar.
  if coalesce(d ->> 'confidence','') = 'verified' then return false; end if;

  -- Charter / taşıyıcı uyuşmazlığı host'un beyanıyla çözülmez —
  -- bunlar misafirin KENDİ uçuşundan doğan engeller.
  if coalesce((d ->> 'charter')::boolean, false) then return false; end if;
  if coalesce(d ->> 'carrier_ok','') = 'false' then return false; end if;

  return true;
exception when others then
  -- Emin olamadığımız yerde buton GÖSTERMEYİZ. Yanlışlıkla gösterip
  -- host'a gereksiz bildirim yollamaktansa fırsatı kaçırmak yeğdir.
  return false;
end $$;
grant execute on function public.kural_sorusu_uygun_mu(uuid) to authenticated;


-- ════════════════════════════════════════════════════════════════════════
-- 2) ROZET ÇIKTISINA `can_ask_host` EKLENİYOR
--
-- App bugüne kadar "engelli mi" biliyordu ama "sorulabilir mi"
-- bilmiyordu. Kolonu eklemek `returns table`'ı değiştiriyor, o yüzden
-- drop+create gerekiyor.
--
-- 🔴 App tarafındaki YEDEK YOL bu alanı `false` kabul edecek: rozet
-- RPC'si düşerse buton hiç çıkmaz. Sessizce yanlış buton göstermektense
-- butonu hiç göstermemek doğru bozulma yönü.
-- ════════════════════════════════════════════════════════════════════════

-- sqlcheck: allow-replace discovery_rule_badges  (yeni kolon: can_ask_host)
drop function if exists public.discovery_rule_badges(uuid[]);
create or replace function public.discovery_rule_badges(p_ids uuid[])
returns table (
  avail_id uuid, severity text, label text, info text, detail text,
  same_flight_match boolean, blocks_request boolean, sort_boost int,
  can_ask_host boolean
) language plpgsql stable security definer set search_path = public as $$
declare
  r record; d jsonb; b jsonb; v_flight text; v_key text;
  v_boost int; v_same boolean; v_block boolean; v_prog lounge_programs%rowtype;
begin
  foreach avail_id in array coalesce(p_ids, '{}'::uuid[]) loop
    select * into r from availabilities where id = avail_id;
    continue when not found;

    select v.flight_number into v_flight from visits v
     where v.user_id = auth.uid() and v.airport_code = r.airport_code
       and v.visit_date = r.avail_date and coalesce(v.flight_number,'') <> ''
     order by v.created_at desc limit 1;

    d := public.lounge_access_decision_v5(avail_id, v_flight, public.guest_carrier_for(avail_id));
    select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

    v_same := coalesce(v_flight,'') <> '' and coalesce(r.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(r.flight_number,' ',''));

    v_block := coalesce((d ->> 'severity') = 'block' and (d ->> 'enforcement') = 'block', false)
               or coalesce((d ->> 'carrier_ok') = 'false', false)
               or coalesce((d ->> 'charter') = 'true', false);
    if v_prog.id is null or v_prog.entitlement_model = 'bank_card' then
      v_block := false;
    end if;

    v_boost := 0;
    if v_block then                                  v_key := 'guest_none';  v_boost := -1000;
    elsif v_same then                                v_key := 'same_flight'; v_boost := 100;
    elsif (d ->> 'fits') = 'false' then              v_key := 'flight_bad';  v_boost := -100;
    elsif (d ->> 'guest_policy') = 'not_allowed' then
      v_key := 'guest_none_soft'; v_boost := -200;
    elsif (d ->> 'guest_policy') = 'paid' then       v_key := 'guest_paid';  v_boost := -20;
    elsif (d ->> 'confidence') in ('unknown','assumed') then v_key := 'unverified'; v_boost := -10;
    elsif (d ->> 'guest_policy') = 'included' then   v_key := 'guest_free';  v_boost := 20;
    else v_key := null;
    end if;

    -- 219 kapı hizası korunuyor
    if (d ->> 'guest_policy') = 'not_allowed' then
      v_block := true;
    end if;

    b := case when v_key is null then null else public.badge_text(v_key) end;

    severity := coalesce(d ->> 'severity','info');
    label    := b ->> 'label';
    info     := b ->> 'info';
    detail   := d ->> 'headline';
    same_flight_match := v_same;
    blocks_request := v_block;
    sort_boost := v_boost;
    can_ask_host := public.kural_sorusu_uygun_mu(avail_id);
    return next;
  end loop;
end $$;
grant execute on function public.discovery_rule_badges(uuid[]) to authenticated;


-- ════════════════════════════════════════════════════════════════════════
-- 3) SORUYU GÖNDER
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.ilan_kurali_sor(p_avail_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_av availabilities%rowtype;
  v_salon text; v_konu text; v_intro text;
  v_ok boolean; v_id uuid; v_mevcut connection_requests%rowtype;
  v_gunluk int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_av from availabilities where id = p_avail_id;
  if not found or not v_av.active then raise exception 'availability_not_found'; end if;
  if v_av.host_id = v_uid then raise exception 'self_connect_blocked'; end if;

  -- Kapı 1: bu ilanda soru sorulabilir mi (tek kaynak)
  if not public.kural_sorusu_uygun_mu(p_avail_id) then
    raise exception 'rule_ask_not_applicable';
  end if;

  -- Kapı 2: telefon doğrulaması — `send_connection` ile AYNI eşik.
  -- Farklı eşik koysaydım, aynı sonuca (sohbet) iki farklı güven
  -- seviyesiyle varılan iki yol olurdu.
  select phone_verified into v_ok from verifications where user_id = v_uid;
  if not coalesce(v_ok,false) then raise exception 'phone_not_verified'; end if;

  -- Kapı 3: günlük tavan. Host'ları koruyoruz — bir misafir bütün
  -- kapalı ilanlara tek tek soru yağdıramaz.
  select count(*) into v_gunluk from connection_requests
   where from_id = v_uid and intent = 'kural_sorusu'
     and created_at > now() - interval '24 hours';
  if v_gunluk >= 5 then raise exception 'rule_ask_daily_limit'; end if;

  v_salon := coalesce(v_av.lounge_name, v_av.airport_code);

  -- Zaten bir bağlantı varsa yenisini kurmuyoruz; app sohbeti açsın.
  -- (`connection_requests` üzerinde unique(from_id,to_id) var — bu yüzden
  --  ikinci satır zaten mümkün değil; sessizce hata vermek yerine
  --  kullanıcıya nereye gideceğini söylüyoruz.)
  select * into v_mevcut from connection_requests
   where (from_id = v_uid and to_id = v_av.host_id)
      or (from_id = v_av.host_id and to_id = v_uid)
   order by created_at desc limit 1;

  if found then
    return jsonb_build_object(
      'ok', true,
      'durum', case when v_mevcut.status::text = 'accepted' then 'baglanti_var' else 'zaten_soruldu' end,
      'baglanti_id', v_mevcut.id,
      'salon', v_salon);
  end if;

  v_intro := left('“' || v_salon || '” ilanında misafir hakkı görünmüyor ama bunu '
             || 'doğrulayamadık. Kartında misafir hakkın var mı?', 140);

  insert into connection_requests (from_id, to_id, intent, intro, status)
  values (v_uid, v_av.host_id, 'kural_sorusu', v_intro, 'pending')
  returning id into v_id;

  -- 🔴 BİLDİRİM METNİ HOST'A NE YAPACAĞINI SÖYLÜYOR. "Bir yolcu seninle
  -- bağlantı kurmak istiyor" burada işe yaramaz — host'un yapacağı iş
  -- bir sohbet değil, bir BEYAN. 092'nin `save_host_access` ekranı zaten
  -- duruyor; bildirim oraya işaret ediyor.
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (v_av.host_id, 'connections',
          'Misafir hakkın soruluyor ◈',
          'Bir yolcu “' || v_salon || '” ilanında misafir götürüp götüremediğini '
          || 'soruyor. Elimizdeki bilgi “hayır” diyor ama doğrulayamadık. '
          || 'Kart hakkını Profil → Lounge hakkı kaynağı ekranından '
          || 'güncellersen ilanın başvuruya açılır.',
          'connection', v_id);

  -- 🔴 VERİ SİNYALİ. Her soru, bir salonda verimizin şüpheli olduğunu
  -- gösteren bir kayıt. 191'in defterine yazıyorum ki hangi salonlarda
  -- kaynak taraması yapmamız gerektiği ölçülebilsin — "kullanıcı sordu"
  -- bizim en ucuz araştırma sinyalimiz.
  v_konu := 'hosta_sorulan_misafir_hakki:' || coalesce(v_av.lounge_id::text, v_av.airport_code);
  insert into rule_source_conflicts (konu, detay, kaynak_a, kaynak_b, sinif, karar, durum, etki)
  values (v_konu,
          'Misafir “' || v_salon || '” ilanında misafir hakkı olup olmadığını host''a sordu. '
          || 'Karar motoru not_allowed diyor ama kesinlik verified değil.',
          'LoungeLink karar motoru: misafir hakki yok (dogrulanmadi)',
          'Kullanici sorusu (' || to_char(now(),'YYYY-MM-DD') || ')',
          'kaynak_sessiz',
          'Kaynak taramasi bekliyor — bu salonun resmi misafir kurali bulunmali.',
          'veri_bekliyor',
          'Misafir basvuramiyor; host beyan etmezse ilan olu kaliyor.')
  on conflict (konu) do update set
    detay = rule_source_conflicts.detay,
    kaynak_b = 'Kullanici sorusu (son: ' || to_char(now(),'YYYY-MM-DD') || ')',
    updated_at = now();

  return jsonb_build_object('ok', true, 'durum', 'soruldu',
                            'baglanti_id', v_id, 'salon', v_salon);
end $$;
grant execute on function public.ilan_kurali_sor(uuid) to authenticated;


-- ---- Hata karşılıkları (app ham hata göstermesin) ----
insert into beta_settings (key, value) values
 ('err_rule_ask_not_applicable', to_jsonb(
   'Bu ilanda soracak bir şey yok — kuralı resmî kaynaktan doğruladık.'::text)),
 ('err_rule_ask_daily_limit', to_jsonb(
   'Günde en fazla 5 host''a soru gönderebilirsin. Yarın tekrar dene.'::text))
on conflict (key) do update set value = excluded.value;


-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════
do $$
declare
  v_bakilan int := 0; v_uygun int := 0; v_celiski int := 0; v_ornek text := '';
  r record; d jsonb;
begin
  for r in
    select b.avail_id, b.can_ask_host, b.blocks_request
      from availabilities a
      join lateral public.discovery_rule_badges(array[a.id]) b on true
     where a.active
  loop
    v_bakilan := v_bakilan + 1;
    if coalesce(r.can_ask_host,false) then v_uygun := v_uygun + 1; end if;

    -- 🔴 DEĞİŞMEZ: "sorulabilir" olan her ilan AYNI ZAMANDA "engelli"
    -- olmalı. Engelli olmayan bir ilanda soru butonu göstermek,
    -- kullanıcıya başvurabileceği yerde soru sordurmak demektir.
    if coalesce(r.can_ask_host,false) and not coalesce(r.blocks_request,false) then
      v_celiski := v_celiski + 1;
      if v_ornek = '' then v_ornek := left(r.avail_id::text,8); end if;
    end if;

    -- 🔴 DEĞİŞMEZ 2: doğrulanmış kuralda soru SORULMAMALI.
    d := public.lounge_access_decision(r.avail_id, null);
    if coalesce(r.can_ask_host,false) and coalesce(d ->> 'confidence','') = 'verified' then
      v_celiski := v_celiski + 1;
      if v_ornek = '' then v_ornek := left(r.avail_id::text,8) || ' (verified)'; end if;
    end if;
  end loop;

  if v_bakilan = 0 then
    raise notice '221: aktif ilan yok — OLCULEMEDI';
  elsif v_celiski > 0 then
    raise exception '221: % ilanda soru-kapisi tutarsiz → %', v_celiski, v_ornek;
  else
    raise notice '221: % ilan tarandi · % tanesinde host''a sorulabilir · celiski yok',
      v_bakilan, v_uygun;
  end if;
end $$;

select '221 OK — kapali kapinin arkasindaki insana soru yolu acildi' as sonuc;


-- ════════════════════════════════════════════════════════════════════════
-- İSTEMCİ YÜZEYİ — 203'ün sınırı
--
-- 🔴 HARNESS BENİ YAKALADI:
--     "RPC yuzeyi ihlali: kural_sorusu_uygun_mu -> yuzeyde yok ama
--      istemciye acik, ilan_kurali_sor -> yuzeyde yok ama istemciye acik"
-- `grant execute ... to authenticated` yazmak yetmiyor: 203 ayrıca
-- BEYAN edilmiş bir liste tutuyor ve listede olmayan her açık fonksiyon
-- ihlal sayılıyor. Doğru davranış bu — "yanlışlıkla açık kalmış" ile
-- "bilerek açılmış" arasındaki farkı ancak bir beyan gösterir.
--
-- İkisi de gerçekten istemciden çağrılıyor:
--   ilan_kurali_sor        → Keşfet kartındaki "Host'a sor" butonu
--   kural_sorusu_uygun_mu  → doğrudan çağrılmıyor ama rozet fonksiyonu
--                            içinden çalışıyor; SECURITY DEFINER zinciri
--                            için açık kalması gerekiyor.
-- ════════════════════════════════════════════════════════════════════════
insert into rpc_client_surface (fn_name, client, note) values
  ('ilan_kurali_sor','app','Kapali ilanda host''a misafir hakki sorusu (221)'),
  ('kural_sorusu_uygun_mu','app','Soru butonu gosterilsin mi (221) — rozet fonksiyonu icinden')
on conflict (fn_name) do update set note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '221: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;
