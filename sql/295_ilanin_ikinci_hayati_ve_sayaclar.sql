-- ════════════════════════════════════════════════════════════════════════
-- 295 · İLANIN İKİNCİ HAYATI + ANA SAYFA SAYAÇLARININ 24 SAAT TUZAĞI
--
-- 🔴 NEDEN VAR — GÖKBERK'İN 18 EYLÜL LİSTESİ, MADDE 2 · 10 · 11
--
-- md.10  "ilanı kaldır tıklamama rağmen ilanı kaldırmıyor"
-- md.11  "ilanı düzenlemek istediğimde ilan artık yayında değil dönüyor"
-- md.2   "ana sayfadaki soru istek davet sohbet ekranları aslında dolu
--         olmasına rağmen 0 dönüyor"
--
-- ÖLÇÜM — ÜÇÜ DE AYNI KÖKTEN DEĞİL, AMA İKİSİ AYNI KÖKTEN:
--
--   1) `cancel_availability` ilanı SİLMİYOR, `active=false` yapıyor
--      (291, ölçüldü: gövdenin son satırı). Doğru karar — başvuru
--      geçmişi silinmemeli.
--   2) `my_availabilities` ve İlanlarım ekranı PASİF ilanları da
--      gösteriyor (v3.9.2, bilinçli). Yani ilan kaldırıldıktan sonra
--      listede DURUYOR, yalnız rozeti değişiyor.
--   3) ⇒ md.10 bir sunucu hatası DEĞİL: kaldırma çalışıyor. Ekran
--      "kaldırdım" demiyor, sadece rozeti değiştiriyor ve aynı
--      "Kaldır"/"Düzenle" düğmelerini bırakıyor. (İstemci tarafı ayrı
--      düzeltildi.)
--   4) md.11 ise GERÇEK bir sunucu kapısı: `update_availability`
--      koşulsuz `if not active then raise 'availability_inactive'`
--      diyordu. Host kaldırdığı ilanı ne düzeltebiliyor ne geri
--      açabiliyordu — ve geri açacak bir RPC HİÇ YOKTU.
--
-- 🆕 SINIF: "BİR DURUM GEÇİŞİNİN TERSİ YOKSA, O GEÇİŞ BİR DÜZENLEME
-- DEĞİL TEK YÖNLÜ BİR KAYIPTIR — VE KULLANICI ONU 'ÇALIŞMIYOR' DİYE
-- OKUR."
--
-- md.2'nin sunucu tarafı ayrı ve daha sinsi: `home_connections` 24
-- SAATLİK bir pencere uyguluyordu. Yani dün kabul edilmiş, bugün mesaj
-- yazılmamış bir bağlantı ana sayfadan DA sayaçtan DA düşüyordu.
-- Gökberk'in "mesaj atınca düzeliyor" (md.6) gözlemi bu pencerenin
-- diğer yüzü: mesaj, satırı pencereye geri sokuyor.
--
-- 🆕 SINIF: "BİR LİSTEYE ZAMAN PENCERESİ KOYARSAN, O LİSTEYİ SAYAN
-- ROZET DE ZAMANLA BOŞALIR — VE KULLANICI VERİSİNİN SİLİNDİĞİNİ SANIR."
--
-- BU DOSYA NE YAPIYOR
--   A) `update_availability` — pasif ilan artık düzenlenebilir;
--      yalnız GÜNÜ GEÇMİŞ pasif ilan reddediliyor.
--   B) `ilani_yeniden_yayinla(p_id)` — YENİ. Kaldırılan ilanı geri
--      yayına alır; create'in kapılarını (kapasite, geçmiş tarih,
--      kendi çakışman) aynen uygular.
--   C) `home_connections_prebfilter` — 24 saatlik pencere kalktı.
--   D) `ana_sayfa_akisi` — `sohbet` artık listeden değil, bağlantıların
--      KENDİSİNDEN sayılıyor (liste `limit 10` taşıyor; rozet 10'da
--      takılmamalı).
--
-- Tekrar koşulabilir. 294'ten sonra koşulmalı.
-- ════════════════════════════════════════════════════════════════════════

-- ── A · update_availability: pasif ama günü gelmemiş ilan düzenlenebilir ──
CREATE OR REPLACE FUNCTION public.update_availability(p_id uuid, p_date date DEFAULT NULL::date, p_from time without time zone DEFAULT NULL::time without time zone, p_to time without time zone DEFAULT NULL::time without time zone, p_slots smallint DEFAULT NULL::smallint, p_lounge_id uuid DEFAULT NULL::uuid, p_lounge_name text DEFAULT NULL::text, p_flight text DEFAULT NULL::text, p_visibility text DEFAULT NULL::text, p_carrier text DEFAULT NULL::text, p_cabin text DEFAULT NULL::text, p_charter boolean DEFAULT NULL::boolean, p_min_trust integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid    uuid := auth.uid();
  v_a      availabilities%rowtype;
  v_kabul  int;
  v_bekle  int;
  v_cap    int;
  v_yeni_d date; v_yeni_f time; v_yeni_t time; v_yeni_s smallint;
  v_yeni_l uuid;  v_yeni_ln text;
  v_kilit  boolean;
  v_degisen text[] := '{}';
  v_vis    availability_visibility;
  v_min    int;
  v_zaman_degisti boolean;
  v_cakisma_once  int;
  v_cakisma_sonra int;
  r        record;
begin
  perform public.motor_yazimi_ac();
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_a from availabilities where id = p_id for update;
  if not found then raise exception 'availability_not_found'; end if;
  if v_a.host_id <> v_uid then raise exception 'not_your_availability'; end if;
  -- 🔴 18 EYLÜL (Gökberk md.11) — KAPI ÇOK GENİŞTİ.
  -- Eski satır: `if not active then raise 'availability_inactive'`.
  -- Ölçüldü: Gökberk "İlanı kaldır"a bastı (291 ilanı `active=false`
  -- yapıyor), ilan listede PASİF rozetiyle kaldı, "Düzenle"ye bastı ve
  -- 'availability_inactive' yedi. Yani kaldırdığı ilanı bir daha ne
  -- düzeltebiliyor ne geri açabiliyordu — tek çıkış silip yeniden
  -- yazmaktı, ki o da başvuru geçmişini çöpe atıyor.
  -- 248'de aynı ders tarihte alınmıştı: kapı yalnız GERÇEKTEN geçersiz
  -- olan durumu kapatmalı. Pasif ama GÜNÜ GELMEMİŞ bir ilan geçersiz
  -- değil, yalnız yayında değil — host onu düzeltip yeniden yayınlar.
  -- Kapanan tek durum: pasif VE günü geçmiş (artık geri açılamaz).
  -- 🆕 SINIF: "BİR KAYDI 'KAPALI' DİYE DÜZENLEMEYE KAPATIRSAN, KULLANICIYI
  -- ONU AÇMAK İÇİN SİLMEYE ZORLARSIN."
  if not coalesce(v_a.active, false) and v_a.avail_date < current_date then
    raise exception 'availability_inactive'
      using hint = 'Bu ilanin gunu gecti; geri acilamaz. Yeni ilan olustur.';
  end if;

  select count(*) filter (where status = 'accepted'),
         count(*) filter (where status = 'pending')
    into v_kabul, v_bekle
    from requests where avail_id = p_id;

  v_yeni_d  := coalesce(p_date, v_a.avail_date);
  v_yeni_f  := coalesce(p_from, v_a.time_from);
  v_yeni_t  := coalesce(p_to,   v_a.time_to);
  v_yeni_s  := coalesce(p_slots, v_a.slots);
  v_yeni_l  := coalesce(p_lounge_id, v_a.lounge_id);
  v_yeni_ln := coalesce(nullif(btrim(coalesce(p_lounge_name,'')),''), v_a.lounge_name);

  v_zaman_degisti := (v_yeni_d <> v_a.avail_date
                      or v_yeni_f <> v_a.time_from
                      or v_yeni_t <> v_a.time_to);

  -- ---- SÖZLEŞME KİLİDİ (degismedi) ----
  v_kilit := (v_kabul > 0);
  if v_kilit then
    if v_zaman_degisti or v_yeni_l is distinct from v_a.lounge_id then
      raise exception 'kabul_edilmis_basvuru_var'
        using detail = format('%s kabul edilmis basvuru var', v_kabul),
              hint   = 'Tarih, saat ve salon degistirilemez. Kontenjani artirabilir, '
                    || 'ucus numarasini duzeltebilirsin. Degistirmen sartsa once '
                    || 'misafirle sohbetten konus.';
    end if;
    if v_yeni_s < v_a.slots then
      raise exception 'kontenjan_azaltilamaz'
        using hint = 'Kabul edilmis misafir varken kontenjan dusurulemez.';
    end if;
  end if;

  -- ---- TEMEL GEÇERLİLİK ----
  -- 🔴 248: `v_yeni_d < current_date` KOSULSUZDU. Gecmis tarihli bir ilan
  -- (ornegin dun acilmis, hala active) artik hic duzenlenemiyordu — oysa
  -- host o ilanin ucus numarasini duzeltmek isteyebilir. Kural yalniz
  -- TARIHI DEGISTIRIYORSAN gecerli: gecmise TASIYAMAZSIN.
  if p_date is not null and v_yeni_d <> v_a.avail_date and v_yeni_d < current_date then
    raise exception 'date_in_past';
  end if;
  if v_yeni_f >= v_yeni_t then raise exception 'invalid_time_range'; end if;
  if v_yeni_s < 1 or v_yeni_s > 6 then raise exception 'invalid_slots'; end if;
  if v_yeni_s < coalesce(v_a.filled,0) then
    raise exception 'kontenjan_dolulugun_altinda'
      using detail = format('%s dolu', v_a.filled);
  end if;

  -- ---- KAPASİTE KAPISI — ARTIK KOŞULLU (madde 14'un kok nedeni) ----
  -- Kapasite beyani SLOT SAYISININ kuralidir. Slot sayisina dokunmayan
  -- bir duzenleme bu kapidan gecmez.
  if v_yeni_s > v_a.slots then
    select guest_capacity into v_cap from profiles where user_id = v_uid;
    if v_cap is null then
      raise exception 'no_access_source'
        using hint = 'Kontenjani artirmak icin once misafir hakki kaynagini '
                  || 'beyan etmen gerekiyor. Diger alanlari duzenlemek icin gerekmiyor.';
    end if;
    if v_yeni_s > v_cap then raise exception 'slots_exceed_capacity'; end if;
  end if;

  -- ---- HOST'UN KENDİ MİSAFİR İSTEĞİYLE ÇAKIŞMA ----
  -- Bu da yalniz ZAMAN DEGISTIYSE anlamli: degismeyen bir saat icin
  -- "cakisiyor" demek, var olan durumu duzenlenemez kilmaktir.
  if v_zaman_degisti and exists (
    select 1 from requests r2
      join availabilities a on a.id = r2.avail_id
     where r2.guest_id = v_uid and r2.status in ('pending','accepted')
       and a.avail_date = v_yeni_d
       and a.time_from < v_yeni_t and v_yeni_f < a.time_to
  ) then raise exception 'guest_same_slot'; end if;

  -- ---- HOST'UN KENDİ İKİ İLANI ÇAKIŞAMAZ — "KÖTÜLEŞTİRME" TESTİ ----
  -- 🔴 Eski hali: cakisma VARSA hata. Kural sonradan konuldugu icin
  -- kuraldan ONCE acilmis cakisan ilanlari da duzenlenemez yapiyordu.
  -- Yeni hali: cakisan ilan SAYISI artiyorsa hata. Var olan cakismayi
  -- buyutmeyen duzenleme (ucus, kontenjan, gorunurluk, hatta saati
  -- daraltmak) gecer.
  -- 🔴 İLK YAZIMIM SAYIYORDU — VE KENDİ NÖBETÇİM YAKALADI.
  -- `count(once) < count(sonra)` yazmistim. Nobetci sunu denedi: a1 zaten
  -- a2 ile cakisiyordu (once=1); a1'i BASKA bir gunde BASKA bir ilanla
  -- cakisan saate tasidim (sonra=1). 1 > 1 yanlis → duzenleme GECTI.
  -- Yani "eski cakismam vardi" kredisiyle YEPYENI bir cakisma acilabiliyordu.
  -- Dogru olcut sayi degil KUME: sonradan cakisanlar, oncekilerin ALT
  -- KUMESI olmali. Yeni bir ilan kumeye giriyorsa hata.
  -- 🆕 SINIF: "BIR DURUMUN KOTULESIP KOTULESMEDIGINI SAYIYLA OLCMEK,
  -- AYNI SAYIDA AMA BASKA BIR KOTULUGE KAPI ACAR."
  select count(*) into v_cakisma_sonra
    from availabilities a2
   where a2.host_id = v_uid and a2.id <> p_id and a2.active
     and a2.avail_date = v_yeni_d
     and a2.time_from < v_yeni_t and v_yeni_f < a2.time_to
     and not exists (
       select 1 from availabilities a3
        where a3.id = a2.id
          and a3.avail_date = v_a.avail_date
          and a3.time_from < v_a.time_to and v_a.time_from < a3.time_to);
  v_cakisma_once := 0;

  if v_cakisma_sonra > v_cakisma_once then
    raise exception 'kendi_ilanlarin_cakisiyor'
      using hint = 'Bu saatte baska bir ilanin var. Once onu kaldir ya da saatleri ayir.';
  end if;

  -- ---- DEĞİŞENLERİ TOPLA ----
  if v_yeni_d <> v_a.avail_date then v_degisen := v_degisen || 'tarih'::text; end if;
  if v_yeni_f <> v_a.time_from or v_yeni_t <> v_a.time_to then v_degisen := v_degisen || 'saat'::text; end if;
  if v_yeni_l is distinct from v_a.lounge_id
     or v_yeni_ln is distinct from v_a.lounge_name then v_degisen := v_degisen || 'salon'::text; end if;
  if v_yeni_s <> v_a.slots then v_degisen := v_degisen || 'kontenjan'::text; end if;
  if p_flight is not null and btrim(p_flight) is distinct from coalesce(v_a.flight_number,'')
    then v_degisen := v_degisen || 'uçuş'::text; end if;

  -- ---- GÖRÜNÜRLÜK ----
  -- 🔴 248: 'all' ARTIK min_trust'a DOKUNMUYOR. Eskiden v_min := 0 olup
  -- host'un guven esigini sessizce siliyordu (hata sinifi 3).
  if p_visibility is not null then
    case lower(p_visibility)
      when 'all'         then v_vis := 'Public';      v_min := null;
      when 'trusted'     then v_vis := 'Public';
                             v_min := coalesce(p_min_trust, 55);
      when 'hidden'      then v_vis := 'Hidden';      v_min := null;
      when 'connections' then v_vis := 'Connections'; v_min := null;
      else raise exception 'invalid_visibility';
    end case;
  end if;
  -- Acik istek her zaman gorunurluk esleminin onunde: host chip'e bastiysa
  -- dedigi olur.
  if p_min_trust is not null then
    if p_min_trust < 0 or p_min_trust > 100 then raise exception 'invalid_min_trust'; end if;
    v_min := p_min_trust;
  end if;

  -- ---- YAZ ----
  update availabilities set
    avail_date    = v_yeni_d,
    time_from     = v_yeni_f,
    time_to       = v_yeni_t,
    slots         = v_yeni_s,
    lounge_id     = v_yeni_l,
    lounge_name   = v_yeni_ln,
    flight_number = case when p_flight is null then flight_number
                         else nullif(btrim(p_flight),'') end,
    visibility    = coalesce(v_vis, visibility),
    min_trust     = coalesce(v_min, min_trust),
    rule_guest_policy    = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_guest_policy end,
    rule_flight_coupling = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_flight_coupling end,
    rule_severity        = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_severity end,
    rule_headline        = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_headline end,
    rule_note            = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_note end,
    rule_checked_at      = case when v_yeni_l is distinct from v_a.lounge_id then null else rule_checked_at end,
    venue_id             = case when v_yeni_l is distinct from v_a.lounge_id
                                then (select l.venue_id from lounges l where l.id = v_yeni_l)
                                else venue_id end,
    updated_at    = now()
  where id = p_id;

  -- ---- TAŞIYICI / KABİN / CHARTER — KURALIN KENDİ KAPISINDAN ----
  -- 🔴 Bu uc alani BURADA `update availabilities set` ile yazmiyorum.
  -- Ucunun de kendi SECURITY DEFINER fonksiyonu var ve o fonksiyonlar
  -- kural motorunu yeniden tetikliyor (kabin notu, tasiyici eslesmesi).
  -- Kolonu dogrudan yazmak, kurali atlamak olurdu — 240'ta ogrendigim ders.
  if p_carrier is not null then
    perform public.set_availability_carrier(p_id, nullif(btrim(p_carrier),''));
    v_degisen := v_degisen || 'havayolu'::text;
  end if;
  if p_cabin is not null then
    perform public.set_availability_cabin(p_id, nullif(btrim(p_cabin),''));
    v_degisen := v_degisen || 'kabin'::text;
  end if;
  if p_charter is not null then
    perform public.set_availability_charter(p_id, p_charter);
  end if;

  -- ---- BEKLEYENLERE HABER VER ----
  if array_length(v_degisen,1) is not null and (v_bekle > 0 or v_kabul > 0) then
    for r in select distinct guest_id from requests
              where avail_id = p_id and status in ('pending','accepted')
    loop
      insert into notifications (user_id, category, title, body, ref_type, ref_id)
      values (r.guest_id, 'requests', 'Başvurduğun ilan güncellendi',
              format('Host %s bilgisini değiştirdi. Yeni hâli: %s · %s–%s%s. '
                  || 'Sana uymuyorsa başvurunu iptal edebilirsin — kredin iade edilir.',
                  array_to_string(v_degisen, ', '),
                  to_char(v_yeni_d,'DD.MM.YYYY'),
                  to_char(v_yeni_f,'HH24:MI'), to_char(v_yeni_t,'HH24:MI'),
                  coalesce(' · ' || v_yeni_ln, '')),
              'availability', p_id);
    end loop;
  end if;

  insert into audit_log (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_uid, 'availability.update', 'availabilities', p_id,
          jsonb_build_object('date', v_a.avail_date, 'from', v_a.time_from,
                             'to', v_a.time_to, 'slots', v_a.slots,
                             'lounge_id', v_a.lounge_id, 'min_trust', v_a.min_trust),
          jsonb_build_object('date', v_yeni_d, 'from', v_yeni_f,
                             'to', v_yeni_t, 'slots', v_yeni_s,
                             'lounge_id', v_yeni_l, 'degisen', v_degisen,
                             'min_trust', coalesce(v_min, v_a.min_trust)));

  return jsonb_build_object('ok', true, 'degisen', v_degisen,
                            'bildirilen', v_bekle + v_kabul,
                            'kural_sifirlandi', (v_yeni_l is distinct from v_a.lounge_id));
end $function$;


-- ── B · ilani_yeniden_yayinla — KALDIRILAN İLANIN GERİ DÖNÜŞ YOLU ────────
-- 🔴 Bu RPC bugüne kadar YOKTU. `cancel_availability` tek yönlüydü:
-- host "bugün gelemeyeceğim" deyip ilanı kapatıyor, planı değişince geri
-- açamıyordu. Tek çıkış yeni ilan açmaktı — yani başvuru geçmişi,
-- kural anlık görüntüsü ve ilanın kimliği çöpe gidiyordu.
--
-- KAPILAR — `create_availability_base` NE SORUYORSA O:
--   · iletişim doğrulanmış mı        (is_contact_verified)
--   · kontenjan kapasiteyi aşıyor mu (profiles.guest_capacity)
--   · tarih geçmiş mi                (avail_date < current_date)
--   · kendi ilanlarınla çakışıyor mu (aynı gün, kesişen saat, aktif)
--   · misafir olarak aynı saatte açık isteğin var mı (033'ün kuralı)
-- Kapıları burada TEKRAR sormak, "zaten bir kez sormuştuk" demekten
-- daha ucuz: ilan kapalıyken kapasite düşmüş, başka ilan açılmış ya da
-- gün geçmiş olabilir. Bir kaydı geri açmak, onu YENİDEN açmaktır.
create or replace function public.ilani_yeniden_yayinla(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_a   availabilities%rowtype;
  v_cap int;
  v_cakisma int;
  v_guest_cakisma boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);

  select * into v_a from availabilities where id = p_id for update;
  if not found then raise exception 'availability_not_found'; end if;
  if v_a.host_id <> v_uid then raise exception 'not_your_availability'; end if;

  -- Zaten yayındaysa bu bir hata değil, bir NO-OP: iki kez basılan düğme
  -- kullanıcıya kırmızı göstermemeli.
  if coalesce(v_a.active, false) then
    return jsonb_build_object('ok', true, 'zaten_yayinda', true);
  end if;

  if v_a.avail_date < current_date then
    raise exception 'date_in_past'
      using hint = 'Bu ilanin gunu gecti; yeniden yayinlanamaz.';
  end if;

  if not public.is_contact_verified(v_uid) then
    raise exception 'contact_not_verified';
  end if;

  select guest_capacity into v_cap from profiles where user_id = v_uid;
  if v_cap is null then raise exception 'no_access_source'; end if;
  if v_a.slots > v_cap then
    raise exception 'slots_exceed_capacity'
      using hint = 'Kapasiten bu ilani acarken oldugundan dusuk. Once kontenjani azalt.';
  end if;

  select count(*) into v_cakisma
    from availabilities a2
   where a2.host_id = v_uid and a2.id <> p_id and a2.active
     and a2.avail_date = v_a.avail_date
     and a2.time_from < v_a.time_to and v_a.time_from < a2.time_to;
  if v_cakisma > 0 then
    raise exception 'kendi_ilanlarin_cakisiyor'
      using hint = 'Bu saatte baska bir aktif ilanin var. Once onu kaldir ya da saatleri ayir.';
  end if;

  select exists (
    select 1 from requests r
      join availabilities a on a.id = r.avail_id
     where r.guest_id = v_uid and r.status in ('pending','accepted')
       and a.avail_date = v_a.avail_date
       and a.time_from < v_a.time_to and v_a.time_from < a.time_to
  ) into v_guest_cakisma;
  if v_guest_cakisma then raise exception 'guest_same_slot'; end if;

  update availabilities
     set active = true, updated_at = now()
   where id = p_id;

  insert into audit_log (actor_id, action, entity_type, entity_id, after_data)
  values (v_uid, 'availability.republish', 'availabilities', p_id,
          jsonb_build_object('date', v_a.avail_date, 'from', v_a.time_from,
                             'to', v_a.time_to, 'slots', v_a.slots));

  return jsonb_build_object('ok', true, 'zaten_yayinda', false,
                            'tarih', v_a.avail_date);
end $function$;

grant execute on function public.ilani_yeniden_yayinla(uuid) to authenticated;

-- ── C · home_connections: 24 SAATLİK PENCERE KALKTI ─────────────────────
-- 🔴 Eski `where` iki koşuldan birini arıyordu:
--       coalesce(responded_at, created_at) > now() - interval '24 hours'
--    or exists (24 saat icinde mesaj)
-- Ölçüm: bu, "bağlantılarım" listesini bir AKIŞ'a çeviriyordu. Bir
-- bağlantı kurulduktan 25 saat sonra, hiç mesaj yazılmadıysa, listeden
-- VE ana sayfadaki sohbet rozetinden düşüyordu. Kullanıcı bunu "verim
-- kayboldu" diye okur — ki Gökberk tam olarak öyle okudu (md.2).
-- Sıralama zaten en son hareketi üste alıyor ve `limit 10` var: yani
-- "yeni olan üstte" işini PENCERE değil SIRALAMA yapıyordu. Pencere
-- yalnız eskiyi siliyordu.
create or replace function public.home_connections_prebfilter()
-- ⚠️ SÜTUN ADLARI BİREBİR KORUNDU (conn_id/last_msg_at). `create or replace`
-- OUT parametre adı değişirse "cannot change return type" ile düşer; ölçtüm,
-- düştü. Bir imzayı "daha okunaklı" yapmak, onu değiştirmektir.
returns table (conn_id uuid, peer_id uuid, peer_name text, peer_photo text,
               channel_id uuid, last_msg_at timestamptz)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select cr.id,
         case when cr.from_id = auth.uid() then cr.to_id else cr.from_id end,
         p.name, p.photo_url, ch.id,
         (select max(m.created_at) from messages m where m.channel_id = ch.id)
    from connection_requests cr
    left join chat_channels ch on ch.connection_id = cr.id
    left join profiles p
      on p.user_id = case when cr.from_id = auth.uid() then cr.to_id else cr.from_id end
   where cr.status = 'accepted'
     and (cr.from_id = auth.uid() or cr.to_id = auth.uid())
   order by coalesce((select max(m.created_at) from messages m where m.channel_id = ch.id),
                     cr.responded_at, cr.created_at) desc
   limit 10
$function$;

-- ── D · ana_sayfa_akisi: `sohbet` artık listeden değil kaynaktan sayılıyor ─
-- 🔴 Eski hâl `select count(*) from home_connections()` idi ve o fonksiyon
-- `limit 10` taşıyor. Yani 30 bağlantısı olan bir kullanıcının rozeti
-- 10'da takılıyordu — rozet, listeyi değil GERÇEĞİ söylemeli. Liste
-- "son 10" göstermeye devam ediyor; ikisi artık FARKLI şeyler söylüyor
-- ve ikisi de doğru.
create or replace function public.ana_sayfa_akisi()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_sohbet int := 0;
  v_istek  int := 0;
  v_davet  int := 0;
  v_soru   int := 0;
  v_baglanti int := 0;
  v_ilan   int := 0;
begin
  if v_uid is null then
    return jsonb_build_object('sohbet',0,'istek',0,'davet',0,'soru',0,'baglanti',0,'ilan',0);
  end if;

  -- SOHBETLER: kabul edilmis TUM baglantilarim (engellenenler haric).
  select count(*)::int into v_sohbet
    from connection_requests cr
   where cr.status = 'accepted'
     and (cr.from_id = v_uid or cr.to_id = v_uid)
     and not public.is_blocked_pair(v_uid,
           case when cr.from_id = v_uid then cr.to_id else cr.from_id end);

  -- ISTEKLER: bekleyen misafir istekleri — hem bana gelen hem gonderdigim.
  select count(*)::int into v_istek
    from requests r
   where r.status = 'pending'
     and (r.host_id = v_uid or r.guest_id = v_uid);

  select count(*) filter (where pa.kind = 'invite')::int
    into v_davet
    from public.pending_actions() pa;

  select count(*)::int into v_soru
    from public.sorularim() s
   where coalesce(s.cevap_durumu, '') not in ('yanitlandi', 'acildi');

  select count(*)::int into v_ilan
    from availabilities a
   where a.host_id = v_uid and a.active and a.avail_date >= current_date;

  -- BAGLANTI: bana gelen bekleyen baglanti istekleri.
  select count(*)::int into v_baglanti
    from connection_requests cr
   where cr.to_id = v_uid and cr.status = 'pending';

  return jsonb_build_object(
    'sohbet', coalesce(v_sohbet, 0),
    'istek',  coalesce(v_istek, 0),
    'davet',  coalesce(v_davet, 0),
    'soru',   coalesce(v_soru, 0),
    'baglanti', coalesce(v_baglanti, 0),
    'ilan', coalesce(v_ilan, 0)
  );
end $function$;

grant execute on function public.ana_sayfa_akisi() to authenticated;
grant execute on function public.home_connections_prebfilter() to authenticated;


-- ── Kendi sınaması ──────────────────────────────────────────────────────
do $$
declare
  hd uuid; av uuid; sonuc jsonb; v_once boolean;
begin
  -- 1) Pasif ama gunu gelmemis ilan: once kaldir, sonra DUZENLE, sonra AC.
  -- ⚠️ HOST'UN `guest_capacity`'si OLMALI: `ilani_yeniden_yayinla`
  -- `create_availability_base`'in kapilarini aynen soruyor ve tohum verisi
  -- ilanlari o kapidan gecmeden DOGRUDAN insert ediyor. Ilk yazimimda bunu
  -- atlamistim ve sinama 'no_access_source' ile dustu — kapi dogru
  -- calisiyordu, SINAMA temsili degildi.
  select a.host_id, a.id into hd, av
    from availabilities a
    join profiles pr on pr.user_id = a.host_id
   where a.active and a.avail_date > current_date
     and pr.guest_capacity is not null
     and a.slots <= pr.guest_capacity
     and public.is_contact_verified(a.host_id)
   limit 1;
  if av is null then raise notice '295 sinama: kapilardan gecen ilan yok, atlandi'; return; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', hd::text, 'role','authenticated')::text, true);

  perform public.cancel_availability(av, true);
  if (select active from availabilities where id = av) then
    raise exception '295: ilan pasife dusmedi';
  end if;

  -- ESKIDEN BURASI 'availability_inactive' ATIYORDU (md.11).
  sonuc := public.update_availability(av, p_flight => 'TK9999');
  if (sonuc ->> 'ok') is distinct from 'true' then
    raise exception '295: pasif ilan duzenlenemedi';
  end if;
  if (select flight_number from availabilities where id = av) <> 'TK9999' then
    raise exception '295: duzenleme yazilmadi';
  end if;

  sonuc := public.ilani_yeniden_yayinla(av);
  if (sonuc ->> 'ok') is distinct from 'true' then
    raise exception '295: yeniden yayinlama dustu';
  end if;
  if not (select active from availabilities where id = av) then
    raise exception '295: ilan yayina donmedi';
  end if;

  -- Ikinci basis NO-OP olmali, hata degil.
  sonuc := public.ilani_yeniden_yayinla(av);
  if (sonuc ->> 'zaten_yayinda') is distinct from 'true' then
    raise exception '295: ikinci basis no-op degil';
  end if;

  -- 2) Gunu gecmis pasif ilan HALA reddedilmeli.
  update availabilities set active = false, avail_date = current_date - 1 where id = av;
  begin
    perform public.update_availability(av, p_flight => 'TK0001');
    raise exception '295: gunu gecmis pasif ilan duzenlenebildi (kapi acik kaldi)';
  exception when others then
    if SQLERRM <> 'availability_inactive' then raise; end if;
  end;

  raise notice '295 sinama: pasif duzenleme + yeniden yayin + gecmis kapisi OK';
  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
end $$;

-- ── Sayac sinamasi: 24 saatlik pencere gercekten kalkti mi ──────────────
do $$
declare v_uid uuid; v_kabul int; v_liste int;
begin
  select cr.from_id into v_uid from connection_requests cr
   where cr.status = 'accepted'
     and coalesce(cr.responded_at, cr.created_at) < now() - interval '24 hours'
   limit 1;
  if v_uid is null then
    -- Sinama verisi uret: var olan bir kabul satirini 3 gun geriye al.
    update connection_requests set responded_at = now() - interval '3 days',
                                   created_at   = now() - interval '3 days'
     where id = (select id from connection_requests where status='accepted' limit 1)
    returning from_id into v_uid;
  end if;
  if v_uid is null then raise notice '295 sayac sinamasi: kabul edilmis baglanti yok, atlandi'; return; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role','authenticated')::text, true);

  select count(*) into v_liste from public.home_connections();
  if v_liste = 0 then
    raise exception '295: 24 saatten eski baglanti listede hala gorunmuyor';
  end if;
  select (public.ana_sayfa_akisi() ->> 'sohbet')::int into v_kabul;
  if v_kabul = 0 then
    raise exception '295: sohbet sayaci hala 0';
  end if;
  raise notice '295 sayac sinamasi: eski baglanti listede (%), sayac % — OK', v_liste, v_kabul;
  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
end $$;

select '295 kuruldu' as sonuc;
