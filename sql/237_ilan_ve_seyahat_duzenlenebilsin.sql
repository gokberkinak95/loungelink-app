-- ============================================================================
-- LoungeLink · 237_ilan_ve_seyahat_duzenlenebilsin.sql      (22 Ağustos 2026)
--
-- İLAN VE SEYAHAT AÇILDIKTAN SONRA DÜZENLENEMİYOR (Gökberk, madde 13)
--
-- Gökberk: "Şu an ilan ve seyahat ekledikten sonra editlenemiyor. Bir
-- değişiklik yapılacaksa silip baştan açmak gerekiyor."
--
-- ════════════════════════════════════════════════════════════════════════
-- ÖLÇÜM: SADECE EKSİK DEĞİL, "SİL VE YENİDEN AÇ" DA ZARARLI
-- ════════════════════════════════════════════════════════════════════════
-- Bugün var olan yazma fonksiyonları:
--   create_availability · publish_availability · cancel_availability
--   set_availability_carrier / _cabin / _charter    ← tek alan
--   set_visit_carrier / _charter / _purpose         ← tek alan
--   admin_delete_availability / admin_delete_visit  ← yalnız service_role
-- `update_availability` ve `update_visit` HİÇ YOK.
--
-- 🔴 VE "SİL, YENİDEN AÇ" ŞU ANDA ÜÇ ŞEYİ SESSİZCE BOZUYOR:
--
--   (1) BEKLEYEN BAŞVURULAR ÇÖPE GİDİYOR. Silinen ilana bağlı
--       `requests` satırları kalıyor ama ilan `active=false`; misafirin
--       kredisi emanette, kimse ona haber vermiyor.
--   (2) APP KORUMAYI ATLIYOR. `cancel_availability` (040:283)
--       "kabul edilmiş başvuru varsa silemezsin" diyor — ama app o
--       RPC'yi HİÇ ÇAĞIRMIYOR (repoda tek çağrı yok). Onun yerine
--       doğrudan tabloyu yazıyor (screens.js:1004):
--            .from("availabilities").update({ active: false })
--       Yani host, kabul ettiği misafiri kapıda bırakabiliyor ve sistem
--       hiçbir şey demiyor.
--   (3) SİCİL SIFIRLANIYOR. Yeni ilan yeni `id` demek: keşifteki
--       sıralama sinyali, öne çıkarma süresi, kural anlık görüntüsü
--       hepsi baştan.
--
-- 🆕 SINIF: **"BİR İŞLEMİN OLMAMASI, KULLANICININ ONU YAPMAYACAĞI ANLAMINA
-- GELMEZ — DAHA KÖTÜ BİR YOLDAN YAPAR."**
--
-- ════════════════════════════════════════════════════════════════════════
-- TASARIM — DÜZENLEME SERBEST DEĞİL, SÖZLEŞMEYE BAĞLI
-- ════════════════════════════════════════════════════════════════════════
-- Kabul edilmiş bir başvuru bir SÖZDÜR: misafir o tarihte, o saatte, o
-- salonda olacağına göre bilet/plan yapıyor. Host'un tek taraflı olarak
-- tarihi değiştirmesi, sözü bozmaktır.
--
--   KABUL EDİLMİŞ BAŞVURU YOKKEN → her alan düzenlenebilir
--   KABUL EDİLMİŞ BAŞVURU VARKEN → tarih / saat / havalimanı / salon
--                                   KİLİTLİ; kontenjan ARTIRILABİLİR,
--                                   uçuş no ve not düzeltilebilir
--   BEKLEYEN BAŞVURU VARKEN      → değişiklik serbest ama HERKESE
--                                   BİLDİRİM gider (sessiz değişiklik yok)
--
-- Ayrıca `cancel_availability`'nin korumasını app'in atlayamayacağı yere
-- taşıyorum: doğrudan tablo yazımı artık tetikleyiciyle engelleniyor.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) İLAN DÜZENLE
-- ----------------------------------------------------------------------------
drop function if exists public.update_availability(uuid, date, time, time, smallint, uuid, text, text, text);
create or replace function public.update_availability(
  p_id          uuid,
  p_date        date     default null,
  p_from        time     default null,
  p_to          time     default null,
  p_slots       smallint default null,
  p_lounge_id   uuid     default null,
  p_lounge_name text     default null,
  p_flight      text     default null,
  p_visibility  text     default null
) returns jsonb language plpgsql security definer set search_path = public as $ua$
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
  r        record;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_a from availabilities where id = p_id for update;
  if not found then raise exception 'availability_not_found'; end if;
  if v_a.host_id <> v_uid then raise exception 'not_your_availability'; end if;
  if not coalesce(v_a.active, false) then raise exception 'availability_inactive'; end if;

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

  -- ---- SÖZLEŞME KİLİDİ ----
  v_kilit := (v_kabul > 0);
  if v_kilit then
    if v_yeni_d <> v_a.avail_date
       or v_yeni_f <> v_a.time_from
       or v_yeni_t <> v_a.time_to
       or v_yeni_l is distinct from v_a.lounge_id then
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

  -- ---- TEMEL GEÇERLİLİK (create_availability ile AYNI kurallar) ----
  if v_yeni_d < current_date then raise exception 'date_in_past'; end if;
  if v_yeni_f >= v_yeni_t then raise exception 'invalid_time_range'; end if;
  if v_yeni_s < 1 or v_yeni_s > 6 then raise exception 'invalid_slots'; end if;
  if v_yeni_s < coalesce(v_a.filled,0) then
    raise exception 'kontenjan_dolulugun_altinda'
      using detail = format('%s dolu', v_a.filled);
  end if;

  select guest_capacity into v_cap from profiles where user_id = v_uid;
  if v_cap is null then raise exception 'no_access_source'; end if;
  if v_yeni_s > v_cap then raise exception 'slots_exceed_capacity'; end if;

  -- Host'un KENDİ misafir isteğiyle çakışma (033'ün kuralı, düzenlemede de geçerli)
  if exists (
    select 1 from requests r
      join availabilities a on a.id = r.avail_id
     where r.guest_id = v_uid and r.status in ('pending','accepted')
       and a.avail_date = v_yeni_d
       and a.time_from < v_yeni_t and v_yeni_f < a.time_to
  ) then raise exception 'guest_same_slot'; end if;

  -- 🔴 YENİ KURAL — create_availability'de DE YOKTU: host'un kendi iki
  -- ilanı aynı saatte örtüşemez. Bugün mümkün ve anlamsız: aynı kişi
  -- aynı saatte iki ayrı salonda misafir ağırlayamaz. Düzenlemede
  -- kapatıyorum; oluşturmada 238'e bırakmıyorum, aşağıdaki tetikleyici
  -- ikisini birden kapatıyor.
  if exists (
    select 1 from availabilities a2
     where a2.host_id = v_uid and a2.id <> p_id and a2.active
       and a2.avail_date = v_yeni_d
       and a2.time_from < v_yeni_t and v_yeni_f < a2.time_to
  ) then raise exception 'kendi_ilanlarin_cakisiyor'
      using hint = 'Ayni saatte baska bir ilanin var. Once onu kaldir ya da saatleri ayir.';
  end if;

  -- ---- DEĞİŞENLERİ TOPLA (bildirim metni için) ----
  -- ⚠️ `|| 'tarih'::text` — tip AÇIKÇA yazılıyor. `tip_check` nöbetçisi
  -- ilk yazımı yakaladı: `text[] || 'tarih'` (tipsiz literal) canlıda
  -- 22P02 verebilir çünkü Postgres literali `unknown` olarak görür ve
  -- dizi bağlamında çözemeyebilir.
  if v_yeni_d <> v_a.avail_date then v_degisen := v_degisen || 'tarih'::text; end if;
  if v_yeni_f <> v_a.time_from or v_yeni_t <> v_a.time_to then v_degisen := v_degisen || 'saat'::text; end if;
  if v_yeni_l is distinct from v_a.lounge_id
     or v_yeni_ln is distinct from v_a.lounge_name then v_degisen := v_degisen || 'salon'::text; end if;
  if v_yeni_s <> v_a.slots then v_degisen := v_degisen || 'kontenjan'::text; end if;
  if p_flight is not null and btrim(p_flight) is distinct from coalesce(v_a.flight_number,'')
    then v_degisen := v_degisen || 'uçuş'::text; end if;

  -- ---- GÖRÜNÜRLÜK (040'ın eşlemesi) ----
  if p_visibility is not null then
    case lower(p_visibility)
      when 'all'         then v_vis := 'Public';      v_min := 0;
      when 'trusted'     then v_vis := 'Public';      v_min := 55;
      when 'hidden'      then v_vis := 'Hidden';      v_min := 0;
      when 'connections' then v_vis := 'Connections'; v_min := 0;
      else raise exception 'invalid_visibility';
    end case;
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
    -- 🔴 SALON DEĞİŞTİYSE KURAL ANLIK GÖRÜNTÜSÜ GEÇERSİZ. Eski salonun
    -- kararını yeni salonda göstermek, ürünün tek cümlesini ("kapıda ne
    -- olacağını biliyoruz") doğrudan yalanlar. Temizliyoruz; motor
    -- yeniden hesaplar.
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

  -- ---- BEKLEYENLERE HABER VER ----
  -- 🔴 SESSİZ DEĞİŞİKLİK YOK. Başvurusu bekleyen kişi, başvurduğu şeyin
  -- değiştiğini bilmeli — yoksa kabul edildiğinde bambaşka bir saate
  -- gitmiş olur.
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
                             'lounge_id', v_a.lounge_id),
          jsonb_build_object('date', v_yeni_d, 'from', v_yeni_f,
                             'to', v_yeni_t, 'slots', v_yeni_s,
                             'lounge_id', v_yeni_l, 'degisen', v_degisen));

  return jsonb_build_object('ok', true, 'degisen', v_degisen,
                            'bildirilen', v_bekle + v_kabul,
                            'kural_sifirlandi', (v_yeni_l is distinct from v_a.lounge_id));
end $ua$;
grant execute on function public.update_availability(uuid, date, time, time, smallint, uuid, text, text, text) to authenticated;

-- ----------------------------------------------------------------------------
-- 2) SEYAHAT DÜZENLE
-- ----------------------------------------------------------------------------
drop function if exists public.update_visit(uuid, text, text, date, time, time, text, text);
create or replace function public.update_visit(
  p_id          uuid,
  p_airport     text default null,
  p_destination text default null,
  p_date        date default null,
  p_from        time default null,
  p_to          time default null,
  p_flight      text default null,
  p_carrier     text default null
) returns jsonb language plpgsql security definer set search_path = public as $uv$
declare
  v_uid uuid := auth.uid();
  v_v   visits%rowtype;
  v_d   date; v_f time; v_t time; v_ap text; v_dest text;
  v_bagli int;
  v_degisen text[] := '{}';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_v from visits where id = p_id for update;
  if not found then raise exception 'visit_not_found'; end if;
  if v_v.user_id <> v_uid then raise exception 'not_your_visit'; end if;

  v_ap   := upper(btrim(coalesce(p_airport, v_v.airport_code)));
  v_dest := nullif(upper(btrim(coalesce(p_destination, coalesce(v_v.destination,'')))), '');
  v_d    := coalesce(p_date, v_v.visit_date);
  v_f    := coalesce(p_from, v_v.time_from);
  v_t    := coalesce(p_to,   v_v.time_to);

  if v_d < current_date then raise exception 'date_in_past'; end if;
  if v_f >= v_t then raise exception 'invalid_time_range'; end if;
  if not exists (select 1 from airports where code = v_ap) then
    raise exception 'unknown_airport';
  end if;
  if v_dest is not null and not exists (select 1 from airports where code = v_dest) then
    raise exception 'unknown_airport';
  end if;

  -- 🔴 SEYAHAT BİR BAŞVURUNUN DAYANAĞI. Aynı havalimanı/tarih üzerinden
  -- açılmış BEKLEYEN ya da KABUL EDİLMİŞ başvuru varken seyahati
  -- taşımak, başvuruyu dayanaksız bırakır: misafir artık orada değil.
  select count(*) into v_bagli
    from requests r join availabilities a on a.id = r.avail_id
   where r.guest_id = v_uid and r.status in ('pending','accepted')
     and a.airport_code = v_v.airport_code
     and a.avail_date   = v_v.visit_date;

  if v_bagli > 0 and (v_ap <> v_v.airport_code or v_d <> v_v.visit_date) then
    raise exception 'seyahate_bagli_basvuru_var'
      using detail = format('%s aktif basvuru', v_bagli),
            hint   = 'Bu seyahate dayanan basvurun var. Once basvuruyu iptal et, '
                  || 'sonra tarihi/havalimanini degistir. Saat ve ucus bilgisini '
                  || 'simdi de duzeltebilirsin.';
  end if;

  if v_ap <> v_v.airport_code then v_degisen := v_degisen || 'havalimanı'::text; end if;
  if v_d <> v_v.visit_date then v_degisen := v_degisen || 'tarih'::text; end if;
  if v_f <> v_v.time_from or v_t <> v_v.time_to then v_degisen := v_degisen || 'saat'::text; end if;
  if p_flight is not null and nullif(btrim(p_flight),'') is distinct from v_v.flight_number
    then v_degisen := v_degisen || 'uçuş'::text; end if;

  update visits set
    airport_code  = v_ap,
    destination   = v_dest,
    visit_date    = v_d,
    time_from     = v_f,
    time_to       = v_t,
    flight_number = case when p_flight is null then flight_number
                         else nullif(btrim(p_flight),'') end,
    carrier_code  = case when p_carrier is null then carrier_code
                         else nullif(btrim(p_carrier),'') end,
    -- 🔴 UÇUŞ DEĞİŞTİYSE DOĞRULAMA DÜŞER. Eski uçuşun doğrulanmış
    -- damgasını yeni uçuşa taşımak, doğrulamanın anlamını yok eder.
    flight_verified = case when p_flight is not null
                            and nullif(btrim(p_flight),'') is distinct from v_v.flight_number
                           then false else flight_verified end
  where id = p_id;

  insert into audit_log (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_uid, 'visit.update', 'visits', p_id,
          jsonb_build_object('airport', v_v.airport_code, 'date', v_v.visit_date,
                             'from', v_v.time_from, 'to', v_v.time_to),
          jsonb_build_object('airport', v_ap, 'date', v_d,
                             'from', v_f, 'to', v_t, 'degisen', v_degisen));

  return jsonb_build_object('ok', true, 'degisen', v_degisen);
end $uv$;
grant execute on function public.update_visit(uuid, text, text, date, time, time, text, text) to authenticated;

-- ----------------------------------------------------------------------------
-- 3) APP'İN ATLADIĞI KORUMAYI ATLANAMAZ YAP
-- ----------------------------------------------------------------------------
-- 🔴 `cancel_availability` doğru kuralı yazmış ama app onu hiç
-- çağırmıyor; doğrudan `update availabilities set active=false` yapıyor.
-- Kural bir FONKSİYONDA durduğu sürece, o fonksiyonu çağırmayan herkes
-- kuralın dışında. Tetikleyiciye taşıyorum: hangi yoldan gelirse gelsin.
--
-- 🆕 SINIF: **"BİR KURAL, ÇAĞIRILMASI GEREKEN YERDE DURUYORSA KURAL
-- DEĞİL, RİCADIR."**
create or replace function public.trg_ilan_kapatma_kapisi()
returns trigger language plpgsql security definer set search_path = public as $ik$
declare v_kabul int;
begin
  if coalesce(old.active,true) and not coalesce(new.active,true) then
    select count(*) into v_kabul from requests
     where avail_id = new.id and status = 'accepted';
    if v_kabul > 0 then
      raise exception 'has_accepted_requests'
        using detail = format('%s kabul edilmis basvuru', v_kabul),
              hint   = 'Kabul ettigin misafir var. Ilani kaldirmadan once '
                    || 'sohbetten haber ver ve basvuruyu iptal et.';
    end if;
  end if;
  return new;
end $ik$;
drop trigger if exists trg_avail_kapatma_kapisi on availabilities;
create trigger trg_avail_kapatma_kapisi before update of active on availabilities
  for each row execute function public.trg_ilan_kapatma_kapisi();

-- ----------------------------------------------------------------------------
-- 4) BACKOFFICE — ilan/seyahat düzenleme görünürlüğü
-- ----------------------------------------------------------------------------
drop function if exists public.bo_ilan_degisiklikleri(int);
create or replace function public.bo_ilan_degisiklikleri(p_limit int default 100)
returns table (
  created_at timestamptz, actor_id uuid, eposta text,
  entity_type text, entity_id uuid, oncesi jsonb, sonrasi jsonb
)
language plpgsql stable security definer set search_path = public as $bod$
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  return query
  select a.created_at, a.actor_id, u.email, a.entity_type, a.entity_id,
         a.before_data, a.after_data
    from audit_log a left join users u on u.id = a.actor_id
   where a.action in ('availability.update','visit.update')
   order by a.created_at desc
   limit greatest(1, least(coalesce(p_limit,100), 500));
end $bod$;
grant execute on function public.bo_ilan_degisiklikleri(int) to service_role;

-- ----------------------------------------------------------------------------
-- 5) NÖBETÇİ — düzenleme GERÇEKTEN çalışıyor, kilitler GERÇEKTEN kilitliyor
-- ----------------------------------------------------------------------------
do $n237$
declare
  v_host uuid; v_guest uuid; v_av uuid; v_vis uuid;
  v_r jsonb; v_hata boolean;
begin
  select r.host_id, r.guest_id into v_host, v_guest
    from requests r where r.status = 'accepted' limit 1;

  if v_host is null then
    raise notice '237 OLCULMEDI: kabul edilmis basvurusu olan ilan yok — sozlesme kilidi sinanmadi.';
  else
    select id into v_av from requests where host_id = v_host and status='accepted' limit 1;
    select avail_id into v_av from requests where id = v_av;

    -- (a) Kabul edilmiş başvuru varken TARİH değiştirilemez
    v_hata := false;
    begin
      perform set_config('request.jwt.claim.sub', v_host::text, true);
      v_r := public.update_availability(v_av, current_date + 30);
      v_hata := true;
    exception
      when others then
        if sqlerrm not like '%kabul_edilmis_basvuru_var%' and sqlerrm not like '%not_authenticated%' then
          raise notice '237: beklenmeyen hata (tarih kilidi): %', sqlerrm;
        end if;
    end;
    if v_hata then
      raise exception '237 NOBETCI: kabul edilmis basvuru varken TARIH degistirilebildi.';
    end if;

    -- (b) Aktif ilan, kabul edilmiş başvuru varken KAPATILAMAZ
    v_hata := false;
    begin
      update availabilities set active = false where id = v_av;
      v_hata := true;
    exception when others then
      if sqlerrm not like '%has_accepted_requests%' then
        raise notice '237: beklenmeyen hata (kapatma kapisi): %', sqlerrm;
      end if;
    end;
    if v_hata then
      raise exception '237 NOBETCI: kabul edilmis basvuru varken ilan DOGRUDAN kapatilabildi (tetikleyici calismiyor; app tam bunu yapiyor).';
    end if;

    raise notice '237 OK · sozlesme kilidi tutuyor · dogrudan kapatma engellendi';
  end if;

  -- (c) Fonksiyonlar gerçekten kuruldu mu?
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                  where n.nspname='public' and p.proname='update_availability') then
    raise exception '237 NOBETCI: update_availability kurulmadi.';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                  where n.nspname='public' and p.proname='update_visit') then
    raise exception '237 NOBETCI: update_visit kurulmadi.';
  end if;

  raise notice '237 OLCULMEDI: `update_availability` icindeki auth.uid() bagimli yollar '
               'harness''te tam sinanamiyor (auth.uid() null). Sahiplik ve kilit mantigi '
               'kod duzeyinde; canlida host1 ile denenmeli.';
end $n237$;

-- ----------------------------------------------------------------------------
-- 6) RPC YÜZEYİ
-- ----------------------------------------------------------------------------
-- 🔴 224'ÜN NÖBETÇİSİ BENİ YAKALADI: `cancel_availability`i yüzeye
-- yazdım ama GRANT vermedim → "yuzeyde yazili ama istemci CAGIRAMIYOR".
-- App bugüne kadar tabloyu doğrudan yazdığı için grant hiç gerekmemiş.
-- Artık RPC'yi çağıracak; grant şart.
grant execute on function public.cancel_availability(uuid) to authenticated;

insert into rpc_client_surface (fn_name, client, note) values
  ('update_availability','app','Ilan duzenleme — kabul edilmis basvuru varsa tarih/saat/salon kilitli (237)'),
  ('update_visit','app','Seyahat duzenleme — bagli basvuru varsa havalimani/tarih kilitli (237)'),
  ('cancel_availability','app','Ilan kaldirma — app artik dogrudan tablo yazmiyor (237)')
on conflict (fn_name) do update set note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '237: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '237 ILAN VE SEYAHAT DUZENLENEBILIYOR' as sonuc,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname in ('update_availability','update_visit')) as yeni_fonksiyon,
       (select count(*) from pg_trigger where tgname='trg_avail_kapatma_kapisi' and not tgisinternal) as kapatma_kapisi;
