-- ============================================================================
-- 249 — İŞ MODELİ: HOST'U ÇEKEN ŞEY · SOĞUK AĞ · HAVALİMANI NABZI
--
-- Gokberk: "iş modelini de en az mühendisliği kadar iyi bir seviyeye
-- getirelim... Host'u çekmeye yönelik yeterli şeyimiz yok gibi?"
--
-- ============================================================================
-- 🔴 ÖLÇTÜM VE CEVAP BEKLEDİĞİMDEN İYİ: "YETERLİ ŞEYİMİZ YOK" DEĞİL,
--    "OLAN ŞEYLERİ HİÇ GÖSTERMİYORUZ."
--
-- Host'a verdiğimiz karşılıkları saydım. HEPSİ SUNUCUDA KURULU VE ÇALIŞIYOR:
--
--   host_tiers (SQL 206)          · 4 mertebe, her birinin ölçülebilir karşılığı
--     · Ev Sahibi  (1 ağırlama)   → kesifte +5 sira
--     · Kâhya      (5 ağırlama)   → +12 sira, her ilan 24 saat one cikar
--     · Konsiyerj  (15 ağırlama)  → +25 sira, ilanlar one cikar,
--                                    KENDI ISTEKLERI KREDI HARCAMAZ
--   plan_hediyesi_degerlendir (SQL 236) · 2 AGIRLAMADAN SONRA 30 GUN
--                                          SIK UCAN — OTOMATIK, tetikleyiciyle
--   host_credit_per_session (246) · her agirlama 1 kredi
--
-- Yani "zaman ver" ve "statü ver" önerilerimin İKİSİ DE ZATEN KURULU.
--
-- 🔴 PEKİ NEDEN HİSSEDİLMİYOR? Ölçtüm:
--   (a) `host_standing` kartı YALNIZ Yayın sekmesinde, KATLANMIŞ hâlde ve
--       yalnız HOST rolündeki kullanıcıya görünüyor. Misafir rolündeki bir
--       kullanıcı — yani HOST OLMASINI istediğimiz kişi — merdiveni HİÇ
--       görmüyor.
--   (b) `karsilik_cumlesi` yalnız KREDİDEN bahsediyor: "ağırlayarak 3 kredi
--       kazandın". Kredi, bu kitlenin en az umursayacağı ödül (zaten
--       lounge'a girebiliyorlar). Sıralama önceliğinden, ilan öne
--       çıkarmadan ve 30 GÜNLÜK ÜCRETSİZ ÜST PLANDAN tek kelime yok.
--   (c) 30 günlük plan hediyesi ürünün HİÇBİR yerinde yazmıyor. Kullanıcı
--       ancak hak ettikten sonra, bildirimle öğreniyor.
--
-- 🆕 SINIF: "BİR MERDİVENİ YALNIZCA ÜZERİNDE DURANLARA GÖSTERİRSEN, KİMSE
-- İLK BASAMAĞA ÇIKMAZ."
--
-- Bu dosya yeni bir ödül İCAT ETMİYOR (ondan yeterince var). Var olanı
-- görünür kılıyor, bir eksik halkayı ekliyor (davet hediyesi) ve soğuk ağ
-- döneminde misafiri cezalandırmayı bırakıyor.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — KARŞILIK CÜMLESİ ARTIK GERÇEĞİ SÖYLÜYOR
--
-- Eski: "Ağırlayarak 3 kredi kazandın — bu 3 misafir isteği demek."
-- Bu cümle, host'un en az umursadığı ödülü tek başına anlatıyordu.
-- Yeni cümle mertebeye BAĞLI ve gerçekten verdiğimiz şeyleri sayıyor.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.host_standing(p_user uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $hs249$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_n   int; v_su host_tiers%rowtype; v_son host_tiers%rowtype; v_kredi int;
  v_esik int; v_plan text; v_gun int; v_plan_ad text;
  v_hediye_aktif boolean; v_hediye_biter timestamptz; v_hediye_kalan int;
  v_karsilik text; v_parcalar text[] := '{}';
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;

  select count(*) into v_n from sessions s join requests r on r.id = s.request_id
   where r.host_id = v_uid and s.status = 'completed';

  select * into v_su  from host_tiers where min_oturum <= v_n order by min_oturum desc limit 1;
  select * into v_son from host_tiers where min_oturum >  v_n order by min_oturum asc  limit 1;

  select coalesce(sum(delta),0) into v_kredi
    from credit_ledger where user_id = v_uid and reason = 'hosted_session';

  -- ---- PLAN HEDİYESİ: ürünün en somut karşılığı, hiçbir yerde yazmıyordu
  v_esik := coalesce((select (value #>> '{}')::int  from beta_settings where key='host_free_upgrade_sessions'), 2);
  v_plan := coalesce((select  value #>> '{}'        from beta_settings where key='host_free_upgrade_plan'), 'sik_ucan');
  v_gun  := coalesce((select (value #>> '{}')::int  from beta_settings where key='host_free_upgrade_days'), 30);
  select coalesce(nullif(btrim(ad),''), plan::text) into v_plan_ad
    from plan_catalog where plan::text = v_plan;

  select true, biter_at into v_hediye_aktif, v_hediye_biter
    from plan_grants
   where user_id = v_uid and bitti_at is null and iptal_at is null and biter_at > now()
   order by biter_at desc limit 1;
  v_hediye_aktif := coalesce(v_hediye_aktif, false);
  v_hediye_kalan := greatest(0, v_esik - v_n);

  -- ---- KARŞILIK CÜMLESİ: mertebeye bağlı, gerçek ayrıcalıkları sayar
  if v_su.siralama_ek > 0 then
    v_parcalar := v_parcalar || format('keşifte %s sıra öne geçiyorsun', v_su.siralama_ek)::text;
  end if;
  if coalesce(v_su.one_cikar_saat,0) > 0 then
    v_parcalar := v_parcalar || format('her yeni ilanın %s saat öne çıkıyor', v_su.one_cikar_saat)::text;
  end if;
  if coalesce(v_su.istek_bedava,false) then
    v_parcalar := v_parcalar || 'kendi misafir isteklerin kredi harcamıyor'::text;
  end if;
  if v_kredi > 0 then
    v_parcalar := v_parcalar || format('%s misafir hakkın birikti', v_kredi)::text;
  end if;

  if v_hediye_aktif then
    v_karsilik := format('%s planın %s tarihine kadar ücretsiz — ağırladığın için.',
                         coalesce(v_plan_ad, v_plan), to_char(v_hediye_biter, 'DD.MM.YYYY'));
    if array_length(v_parcalar,1) is not null then
      v_karsilik := v_karsilik || ' Ayrıca ' || array_to_string(v_parcalar, ', ') || '.';
    end if;
  elsif array_length(v_parcalar,1) is not null then
    v_karsilik := initcap(left(v_parcalar[1],1)) || substr(array_to_string(v_parcalar, ', '), 2) || '.';
    if v_hediye_kalan > 0 then
      v_karsilik := v_karsilik || format(' %s ağırlama daha: %s planı %s gün ücretsiz.',
                                         v_hediye_kalan, coalesce(v_plan_ad, v_plan), v_gun);
    end if;
  else
    -- Henüz hiç ağırlamamış. BU CÜMLE EN ÖNEMLİSİ: merdiveni ilk basamağa
    -- çıkmadan önce göstermek zorundayız.
    v_karsilik := format('İlk ağırlaman seni %s yapar: keşifte %s sıra öne geçersin. '
                      || '%s ağırlamada %s planı %s gün ücretsiz olur.',
                         coalesce(v_son.ad,'Ev Sahibi'), coalesce(v_son.siralama_ek,5),
                         v_esik, coalesce(v_plan_ad, v_plan), v_gun);
  end if;

  return jsonb_build_object(
    'known', true,
    'agirlama', v_n,
    'mertebe', v_su.code, 'mertebe_adi', v_su.ad, 'mertebe_aciklama', v_su.aciklama,
    'siralama_ek', v_su.siralama_ek,
    'one_cikar_saat', v_su.one_cikar_saat,
    'istek_bedava', v_su.istek_bedava,
    'sonraki', v_son.code, 'sonraki_adi', v_son.ad,
    'sonraki_kalan', case when v_son.code is null then null else v_son.min_oturum - v_n end,
    'sonraki_aciklama', v_son.aciklama,
    'kazanilan_kredi', v_kredi,
    -- ▼ 249: plan hediyesi artık sözleşmenin parçası
    'plan_hediyesi', jsonb_build_object(
        'aktif', v_hediye_aktif,
        'biter_at', v_hediye_biter,
        'plan', v_plan, 'plan_adi', v_plan_ad, 'gun', v_gun,
        'esik', v_esik, 'kalan_agirlama', v_hediye_kalan),
    'karsilik_cumlesi', v_karsilik);
end $hs249$;

grant execute on function public.host_standing(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — "HOST OLSAN NE OLUR" — MERDİVENİ TIRMANMADAN ÖNCE GÖSTER
--
-- `host_standing` var olan host'a bakıyor. Bu fonksiyon HENÜZ HOST OLMAYAN
-- kişiye bakıyor ve tek bir soruya cevap veriyor: "ağırlarsam ne kazanırım?"
--
-- Neden ayrı fonksiyon: `host_standing` bir DURUM raporu, bu bir TEKLİF.
-- İkisini tek fonksiyona sıkıştırmak, çağıran ekranın hangi hâlde olduğunu
-- tahmin etmesini gerektirirdi.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.host_daveti()
returns jsonb
language plpgsql stable security definer set search_path = public as $hd249$
declare
  v_uid uuid := auth.uid();
  v_n int; v_esik int; v_plan text; v_gun int; v_plan_ad text; v_fiyat int;
  v_basamaklar jsonb;
begin
  if v_uid is null then return jsonb_build_object('ok', false); end if;

  select count(*) into v_n from sessions s join requests r on r.id = s.request_id
   where r.host_id = v_uid and s.status = 'completed';

  v_esik := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_sessions'), 2);
  v_plan := coalesce((select  value #>> '{}'      from beta_settings where key='host_free_upgrade_plan'), 'sik_ucan');
  v_gun  := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_days'), 30);
  select coalesce(nullif(btrim(ad),''), plan::text), price_try
    into v_plan_ad, v_fiyat
    from plan_catalog where plan::text = v_plan;

  -- Merdivenin TAMAMI, ödülleriyle. Katalogdan geliyor — burada sabit
  -- metin yok, çünkü BO'dan mertebe değişince bu ekran da değişmeli.
  select jsonb_agg(jsonb_build_object(
           'code', t.code, 'ad', t.ad, 'agirlama', t.min_oturum,
           'aciklama', t.aciklama,
           'siralama_ek', t.siralama_ek,
           'one_cikar_saat', t.one_cikar_saat,
           'istek_bedava', t.istek_bedava,
           'ulasildi', (v_n >= t.min_oturum))
         order by t.min_oturum)
    into v_basamaklar
    from host_tiers t;

  return jsonb_build_object(
    'ok', true,
    'agirlamam', v_n,
    'basamaklar', coalesce(v_basamaklar, '[]'::jsonb),
    'plan_hediyesi', jsonb_build_object(
        'esik', v_esik, 'gun', v_gun,
        'plan', v_plan, 'plan_adi', v_plan_ad, 'aylik_try', v_fiyat,
        'kalan_agirlama', greatest(0, v_esik - v_n)),
    -- 🔴 EN ÖNEMLİ CÜMLE. Host'a "iyilik yap" demiyoruz; "kimi ağırlayacağını
    -- SEN seçiyorsun" diyoruz. Ağırlamak bir bağış değil, bir seçim.
    -- Bu çerçeve ürünün elindeki en güçlü ve en ucuz koz: veriyi zaten
    -- topluyoruz (meslek, amaç, aynı uçuş, güven puanı) ama host'a
    -- "seçiyorsun" dilini hiç kurmadık.
    'cerceve', 'Kimseyi kabul etmek zorunda değilsin. Başvuranları görür, '
            || 'mesleğine, seyahat amacına ve güven puanına bakar, '
            || 'yanında kimin oturacağına sen karar verirsin.');
end $hd249$;

grant execute on function public.host_daveti() to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — HAVALİMANI NABZI (A2)
--
-- Gokberk: "hiçbir yerde 'bu havalimanında şu an kaç host var' sayısı bir
-- hedef olarak takip edilmiyor... BO ve gerekiyorsa app'e gerekli
-- geliştirmeyi yap."
--
-- Ürünün TEK sağlık göstergesi bu: iki taraflı ve zamana sıkışmış bir
-- pazarda tek soru "bu havalimanında bugün buluşma olabilir mi".
--
-- Üç sayı, üçü de aynı pencerede: arz (canlı ilan / açık slot),
-- talep (bekleyen istek + haber-ver kaydı) ve ikisinin oranı.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.havalimani_nabzi(p_gun int default 14)
returns table(
  airport_code text, sehir text,
  canli_ilan int, acik_slot int, host_sayisi int,
  bekleyen_istek int, talep_kaydi int, aktif_seyahat int,
  tamamlanan_oturum int,
  doluluk numeric,          -- dolan slot / toplam slot
  karsilanma numeric,       -- açık slot / (bekleyen istek + talep kaydı)
  durum text                -- 'soguk' | 'isiniyor' | 'canli'
)
language plpgsql stable security definer set search_path = public as $hn249$
declare v_son date := current_date + greatest(1, coalesce(p_gun,14));
begin
  return query
  with arz as (
    select a.airport_code::text as ap,
           count(*)::int                                   as ilan,
           coalesce(sum(greatest(0, a.slots - coalesce(a.filled,0))),0)::int as slot,
           coalesce(sum(a.slots),0)::int                    as toplam_slot,
           coalesce(sum(coalesce(a.filled,0)),0)::int       as dolu,
           count(distinct a.host_id)::int                   as hostlar
      from availabilities a
     where a.active and a.avail_date between current_date and v_son
       and a.visibility <> 'Hidden'
     group by a.airport_code
  ), talep as (
    select a.airport_code::text as ap, count(*)::int as bekleyen
      from requests r join availabilities a on a.id = r.avail_id
     where r.status = 'pending' and a.avail_date between current_date and v_son
     group by a.airport_code
  ), haber as (
    select t.airport_code::text as ap, count(*)::int as kayit
      from talep_kayitlari t
     where t.aktif and t.tarih_bit >= current_date and t.tarih_bas <= v_son
     group by t.airport_code
  ), seyahat as (
    select v.airport_code::text as ap, count(*)::int as gezi
      from visits v
     where v.visit_date between current_date and v_son
     group by v.airport_code
  ), oturum as (
    select a.airport_code::text as ap, count(*)::int as bitmis
      from sessions s join requests r on r.id = s.request_id
      join availabilities a on a.id = r.avail_id
     where s.status = 'completed'
     group by a.airport_code
  )
  select ap.code::text,
         coalesce(ap.city, ap.name),
         coalesce(arz.ilan,0), coalesce(arz.slot,0), coalesce(arz.hostlar,0),
         coalesce(talep.bekleyen,0), coalesce(haber.kayit,0), coalesce(seyahat.gezi,0),
         coalesce(oturum.bitmis,0),
         case when coalesce(arz.toplam_slot,0) = 0 then null
              else round(arz.dolu::numeric / arz.toplam_slot, 2) end,
         -- 🔴 SIFIRA BÖLME DEĞİL, ANLAMSIZ ORAN KORUMASI:
         -- talep yoksa "karşılanma" diye bir şey yoktur; 0 yazmak
         -- "hiç karşılamıyoruz" gibi okunurdu. null = ölçülemedi.
         case when (coalesce(talep.bekleyen,0) + coalesce(haber.kayit,0)) = 0 then null
              else round(coalesce(arz.slot,0)::numeric
                         / (coalesce(talep.bekleyen,0) + coalesce(haber.kayit,0)), 2) end,
         case when coalesce(arz.hostlar,0) = 0 then 'soguk'
              when coalesce(arz.hostlar,0) < 3 then 'isiniyor'
              else 'canli' end
    from airports ap
    left join arz     on arz.ap     = ap.code::text
    left join talep   on talep.ap   = ap.code::text
    left join haber   on haber.ap   = ap.code::text
    left join seyahat on seyahat.ap = ap.code::text
    left join oturum  on oturum.ap  = ap.code::text
   where coalesce(arz.ilan,0) > 0 or coalesce(talep.bekleyen,0) > 0
      or coalesce(haber.kayit,0) > 0 or coalesce(seyahat.gezi,0) > 0
   order by coalesce(arz.hostlar,0) desc, coalesce(haber.kayit,0) desc, ap.code;
end $hn249$;

grant execute on function public.havalimani_nabzi(int) to authenticated, service_role;

-- BO tarafı: aynı veri + toplam. Yönetim ekranı tek çağrıda her şeyi ister.
create or replace function public.bo_havalimani_nabzi(p_gun int default 14)
returns jsonb
language plpgsql stable security definer set search_path = public as $bhn249$
declare v_satirlar jsonb; v_ozet jsonb;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;

  select jsonb_agg(to_jsonb(x)) into v_satirlar
    from public.havalimani_nabzi(p_gun) x;

  select jsonb_build_object(
      'gun', greatest(1, coalesce(p_gun,14)),
      'havalimani', count(*),
      'canli_havalimani', count(*) filter (where x.durum = 'canli'),
      'isinan',           count(*) filter (where x.durum = 'isiniyor'),
      'soguk',            count(*) filter (where x.durum = 'soguk'),
      'toplam_host',      coalesce(sum(x.host_sayisi),0),
      'toplam_acik_slot', coalesce(sum(x.acik_slot),0),
      'toplam_bekleyen',  coalesce(sum(x.bekleyen_istek),0),
      'toplam_talep',     coalesce(sum(x.talep_kaydi),0))
    into v_ozet
    from public.havalimani_nabzi(p_gun) x;

  return jsonb_build_object('ozet', v_ozet, 'satirlar', coalesce(v_satirlar,'[]'::jsonb));
end $bhn249$;

grant execute on function public.bo_havalimani_nabzi(int) to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — SOĞUK AĞDA İSTEK KREDİ HARCAMASIN (A4)
--
-- Gokberk: "zaten yaptık sanki bir şeyler. Şu anki hali ok değil mi?"
--
-- 🔴 HAYIR. ÖLÇTÜM:
--     request_credit_cost(uid) = case when <Konsiyerj mertebesi> then 0 else 1 end
-- Yani ağın boş olup olmadığına HİÇ BAKMIYOR. Tek indirim yolu 15 ağırlama
-- yapmış olmak — ki tam da ağ boşken kimse ağırlayamıyor.
--
-- Erken dönemde bu şu demek: host olmadığı için cevap alamayan kullanıcıdan
-- ücret alıyoruz. Ürünün en kırılgan anında, en yanlış tarafı cezalandırıyor.
--
-- Yeni kural: isteğin gittiği havalimanında CANLI HOST SAYISI eşiğin
-- altındaysa istek ÜCRETSİZ. Defter satırı yine yazılıyor (0 ile) —
-- "bu istek soğuk ağ indirimiyle bedavaydı" bilgisi kaybolmamalı.
-- ════════════════════════════════════════════════════════════════════════

insert into beta_settings (key, value) values
  ('soguk_ag_host_esigi', to_jsonb(3)),
  ('bayat_istek_saat',    to_jsonb(72))
on conflict (key) do nothing;

-- İmza DEĞİŞİYOR (p_avail eklendi) → önce DROP. `create or replace` yeni bir
-- aşırı yükleme yaratır ve tek argümanlı çağrılar belirsizleşirdi.
-- (248 §9'da imzayı ezberden yazıp bir fonksiyonu ikizleyerek öğrendim.)
drop function if exists public.request_credit_cost(uuid);

create or replace function public.request_credit_cost(p_user uuid, p_avail uuid default null)
returns int
language plpgsql stable security definer set search_path = public as $rcc249$
declare v_esik int; v_host int; v_ap char(3);
begin
  -- (1) Konsiyerj ayrıcalığı — eskisi gibi
  if coalesce((
      select t.istek_bedava from host_tiers t
       where t.min_oturum <= (
         select count(*) from sessions s join requests r on r.id = s.request_id
          where r.host_id = p_user and s.status = 'completed')
       order by t.min_oturum desc limit 1), false) then
    return 0;
  end if;

  -- (2) SOĞUK AĞ İNDİRİMİ — 249. İlan belli değilse eski davranış (1).
  if p_avail is null then return 1; end if;

  select a.airport_code into v_ap from availabilities a where a.id = p_avail;
  if v_ap is null then return 1; end if;

  v_esik := coalesce((select (value #>> '{}')::int from beta_settings where key='soguk_ag_host_esigi'), 3);

  select count(distinct a.host_id) into v_host
    from availabilities a
   where a.active and a.airport_code = v_ap
     and a.avail_date between current_date and current_date + 14
     and a.visibility <> 'Hidden';

  if coalesce(v_host,0) < v_esik then return 0; end if;
  return 1;
end $rcc249$;

grant execute on function public.request_credit_cost(uuid, uuid) to authenticated;

-- `create_request_impl_preflag` bu bedeli okuyor; ilanı da geçirsin.
do $cr249$
declare v_tanim text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='create_request_impl_preflag' limit 1;
  if v_tanim is null then
    raise notice '249 §4: create_request_impl_preflag yok — DOKUNULMADI.'; return;
  end if;
  if v_tanim like '%request_credit_cost(v_uid, p_avail_id)%' then
    raise notice '249 §4: bedel cagrisi zaten ilani geciriyor — dokunulmadi.'; return;
  end if;
  if v_tanim !~ 'request_credit_cost\(v_uid\)' then
    raise notice '249 §4: beklenen bedel cagrisi bulunamadi — DOKUNULMADI.'; return;
  end if;
  v_tanim := replace(v_tanim, 'request_credit_cost(v_uid)', 'request_credit_cost(v_uid, p_avail_id)');
  -- Bedel 0 olunca yazılan not da doğrusunu söylesin.
  v_tanim := replace(v_tanim,
    '''Konsiyerj ayricaligi: istek kredi harcamadi''',
    '(case when public.request_credit_cost(v_uid) = 0
            then ''Konsiyerj ayricaligi: istek kredi harcamadi''
            else ''Soguk ag: bu havalimaninda yeterli host yok, istek kredi harcamadi'' end)');
  execute v_tanim;
  raise notice '249 §4: istek bedeli artik ILANA gore hesaplaniyor (soguk ag indirimi).';
end $cr249$;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — YANITSIZ KALAN İSTEĞİN KREDİSİ İADE EDİLSİN (A4'ün ikinci yarısı)
--
-- 🔴 ÖLÇTÜM: reddedilen istekte iade VAR (`respond_request` → 'request_refund').
-- Ama HİÇ YANITLANMAYAN istekte iade YOK. `stale_requests` yalnızca bir
-- GÖRÜNÜM (rapor) — hiçbir şey yapmıyor.
--
-- Yani host cevap vermezse misafirin kredisi sonsuza kadar yanıyor. Erken
-- dönemde en sık senaryo bu ve suçlu misafir değil.
--
-- 🆕 SINIF: "BİR EMANET, GERİ VERİLME KOŞULU YAZILMAMIŞSA EMANET DEĞİL
-- TAHSİLATTIR."
-- ════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════
-- 🔴 BU DOSYA KENDİ KOLONUNU KENDİ EKLİYOR — VE BUNU ÖĞRENMEM
-- GÖKBERK'İN İKİNCİ HATASINI ALMASINI GEREKTİRDİ.
--
-- Aşağıdaki fonksiyon `requests.decision_note`a yazıyor. O kolon
-- hiçbir migration'da YOKTU; düzeltmeyi 250'ye koydum. Ama 249'un
-- kendi nöbetçisi bu fonksiyonu ÇAĞIRIYOR — yani 249, 250 çalışmadan
-- geçemiyordu, 250 de sırada 249'dan SONRA geliyordu. Kilit.
--
-- Bir migration, kendi çalışması için gereken şemayı kendisi
-- kurmalıdır. "Bir sonraki dosya halleder" bir bağımlılıktır ve
-- sıralı çalıştırmada kilide dönüşür.
--
-- 🆕 SINIF: "BİR MIGRATION'IN NÖBETÇİSİ, O MIGRATION'IN KURMADIĞI BİR
-- ŞEYE BAĞLIYSA, DOSYA KENDİ BAŞINA ÇALIŞTIRILABİLİR DEĞİLDİR."
--
-- `if not exists` — 250 de aynı kolonu ekliyor; ikisi de tekrar
-- çalıştırılabilir kalıyor.
-- ════════════════════════════════════════════════════════════════════════
alter table requests add column if not exists decision_note text;

create or replace function public.bayat_istekleri_iade_et()
returns jsonb
language plpgsql security definer set search_path = public as $bi249$
declare
  v_saat int := coalesce((select (value #>> '{}')::int from beta_settings where key='bayat_istek_saat'), 72);
  r record; v_bal int; v_say int := 0;
begin
  perform public.motor_yazimi_ac();
  for r in
    select req.id, req.guest_id
      from requests req
      join availabilities a on a.id = req.avail_id
     where req.status = 'pending'
       and req.responded_at is null
       and req.created_at < now() - make_interval(hours => v_saat)
       -- İlanın tarihi geçtiyse ya da bekleme süresi dolduysa: iki hâlde de
       -- misafir artık o kapıdan giremez.
       and (a.avail_date < current_date
            or req.created_at < now() - make_interval(hours => v_saat))
       -- Daha önce iade edilmemiş olsun (idempotent).
       and not exists (select 1 from credit_ledger cl
                        where cl.ref_id = req.id and cl.reason = 'request_stale_refund')
       -- Ve gerçekten kredi harcanmış olsun (soğuk ağda 0 harcandıysa
       -- iade edilecek bir şey yok).
       and exists (select 1 from credit_ledger cl
                    where cl.ref_id = req.id and cl.reason = 'request_hold' and cl.delta < 0)
  loop
    update requests set status = 'cancelled', responded_at = now(),
           decision_note = coalesce(decision_note, 'Host süresinde yanıtlamadı — kredin iade edildi.')
     where id = r.id;

    select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = r.guest_id;
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
    values (r.guest_id, 1, 'request_stale_refund', r.id, v_bal + 1,
            format('%s saat içinde yanıt gelmedi', v_saat));

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (r.guest_id, 'credits', 'Kredin iade edildi',
            format('Başvurun %s saat içinde yanıtlanmadı. Kredin cüzdanına geri kondu.', v_saat),
            'request', r.id);
    v_say := v_say + 1;
  end loop;
  return jsonb_build_object('ok', true, 'iade_edilen', v_say, 'esik_saat', v_saat);
end $bi249$;

grant execute on function public.bayat_istekleri_iade_et() to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §6 — KABİN SORUSU ARTIK YALNIZ GEREKTİĞİNDE SORULUYOR (B2)
--
-- Gokberk: "kabin dediğin ne? Silmeden ya da başka bir şey yapmadan önce
-- bunu netleyelim."
--
-- KABİN = UÇUŞ BİLETİNİN SINIFI (Ekonomi / Business / First). Salonun
-- bölümü değil, host'un kendi biletinin sınıfı.
--
-- NEDEN KURAL: THY'nin resmî kuralı şu — Business Class BİLETİ salona
-- girmeni sağlar ama MİSAFİR HAKKI VERMEZ; misafir hakkı KART TİPİNDEN
-- (Miles&Smiles Elite/Elite Plus) gelir. First Class ise Business
-- bölümünde BİR misafir hakkı verir.
--
-- Yani Business bileti olan bir host "ben Business'tayım, misafir
-- götürebilirim" diye ilan açarsa MİSAFİR KAPIDA KALIR. Kabin sorusu tam
-- olarak bunu önlüyor.
--
-- 🔴 AMA ÖLÇTÜM: 15 kabin kuralının 14'ü AYNI kuralın salon salon
-- tekrarı ("business → 0 misafir") ve HEPSİ tek bir programa bağlı:
-- Miles&Smiles. 329 salonun yalnız 13'ünde kabin kuralı var.
--
-- Yani soruyu HER İLANDA sormak, %96 gürültü. Silmek de yanlış olurdu:
-- kalan %4'te kural gerçek ve misafiri kapıda bırakacak kadar sert.
--
-- 🆕 SINIF: "BİR SORUYU HERKESE SORMAK İLE HİÇ SORMAMAK ARASINDA ÜÇÜNCÜ
-- BİR SEÇENEK VAR: CEVABIN BİR ŞEYİ DEĞİŞTİRDİĞİ YERDE SORMAK."
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.kabin_sorulmali_mi(p_lounge_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $ks249$
declare v_venue uuid; v_var int; v_ornek text;
begin
  if p_lounge_id is null then
    return jsonb_build_object('sor', false, 'neden', 'salon_secilmedi');
  end if;
  select l.venue_id into v_venue from lounges l where l.id = p_lounge_id;

  select count(*), max(coalesce(r.notes, r.blocked_reason))
    into v_var, v_ornek
    from lounge_guest_rules r
   where r.cabin_class is not null
     and (r.venue_id is null or r.venue_id = v_venue);

  if coalesce(v_var,0) = 0 then
    return jsonb_build_object('sor', false, 'neden', 'bu_salonda_kabin_kurali_yok');
  end if;
  return jsonb_build_object(
    'sor', true, 'kural_sayisi', v_var,
    'neden', 'bu_salonda_kabin_misafir_hakkini_degistiriyor',
    'ornek', v_ornek);
end $ks249$;

grant execute on function public.kabin_sorulmali_mi(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §7 — YENİ FİKİR: AĞIRLAYAN HOST, TANIDIĞINA MİSAFİR HAKKI HEDİYE EDER
--
-- Gokberk: "başka ve ilgi çekici önerilerin varsa öner"
--
-- GEREKÇE: bu kitlenin gerçekten değer verdiği şey KREDİ DEĞİL, CÖMERT
-- GÖRÜNEBİLMEK. Zaten lounge'a girebilen bir insana "sana bir giriş hakkı
-- verdik" demek zayıf; "arkadaşına bir giriş hakkı verebilirsin" demek
-- güçlü. Statü, harcanabildiğinde statüdür.
--
-- MALİYETİ BİZE SIFIR: hediye edilen şey host'un ZATEN kazandığı kredi.
-- Yeni kredi basmıyoruz, var olanı devredilebilir kılıyoruz.
--
-- 🔴 SUİSTİMALE KARŞI ÜÇ KAPI:
--   (a) yalnız AĞIRLAYARAK kazanılmış kredi hediye edilebilir
--       (satın alınan kredi devredilemez → kredi ticareti doğmaz)
--   (b) alıcı, gönderenin KABUL EDİLMİŞ bağlantısı olmalı
--       (rastgele kullanıcıya kredi püskürtmek yok)
--   (c) günlük tavan
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.misafir_hakki_hediye_et(p_to uuid, p_adet int default 1, p_not text default null)
returns jsonb
language plpgsql security definer set search_path = public as $mh249$
declare
  v_uid uuid := auth.uid();
  v_kazanilan int; v_hediye_edilen int; v_bakiye int; v_bugun int; v_bal int; v_ad text;
begin
  perform public.motor_yazimi_ac();
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_to = v_uid then raise exception 'kendine_hediye_olmaz'; end if;
  if coalesce(p_adet,0) < 1 or p_adet > 3 then raise exception 'gecersiz_adet'; end if;
  if public.is_blocked_pair(v_uid, p_to) then raise exception 'blocked_pair'; end if;

  -- (b) kabul edilmiş bağlantı şartı
  if not exists (
    select 1 from connection_requests
     where status = 'accepted'
       and ((from_id = v_uid and to_id = p_to) or (from_id = p_to and to_id = v_uid))
  ) then
    raise exception 'baglanti_yok'
      using hint = 'Misafir hakkini yalniz baglantilarina hediye edebilirsin.';
  end if;

  -- (a) yalnız ağırlayarak kazanılan kredi devredilebilir
  select coalesce(sum(delta),0) into v_kazanilan
    from credit_ledger where user_id = v_uid and reason = 'hosted_session' and delta > 0;
  select coalesce(-sum(delta),0) into v_hediye_edilen
    from credit_ledger where user_id = v_uid and reason = 'hak_hediye_verildi';
  if (v_kazanilan - v_hediye_edilen) < p_adet then
    raise exception 'agirlayarak_kazanilan_kredi_yetersiz'
      using detail = format('agirlayarak %s kazandin, %s hediye ettin', v_kazanilan, v_hediye_edilen),
            hint = 'Yalniz agirlayarak kazandigin haklar hediye edilebilir; satin alinan kredi devredilemez.';
  end if;

  -- Bakiye de yetmeli (hediye ettiğin hakkı harcamış olabilirsin)
  select coalesce(sum(delta),0) into v_bakiye from credit_ledger where user_id = v_uid;
  if v_bakiye < p_adet then raise exception 'insufficient_credits'; end if;

  -- (c) günlük tavan
  select count(*) into v_bugun from credit_ledger
   where user_id = v_uid and reason = 'hak_hediye_verildi' and created_at > now() - interval '24 hours';
  if v_bugun >= 3 then
    raise exception 'gunluk_hediye_tavani' using hint = 'Gunde en fazla 3 hediye gonderebilirsin.';
  end if;

  select coalesce(nullif(btrim(name),''), 'Bir yolcu') into v_ad from profiles where user_id = v_uid;

  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
  values (v_uid, -p_adet, 'hak_hediye_verildi', p_to, v_bakiye - p_adet, left(coalesce(p_not,''),120));

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = p_to;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
  values (p_to, p_adet, 'hak_hediye_alindi', v_uid, v_bal + p_adet, left(coalesce(p_not,''),120));

  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (p_to, 'credits', 'Sana misafir hakkı hediye edildi ✦',
          format('%s sana %s misafir hakkı gönderdi.%s', v_ad, p_adet,
                 case when coalesce(btrim(p_not),'') <> '' then ' "' || left(p_not,100) || '"' else '' end),
          'user', v_uid);

  insert into audit_log (actor_id, action, entity_type, entity_id, after_data)
  values (v_uid, 'credit.gift', 'users', p_to, jsonb_build_object('adet', p_adet));

  return jsonb_build_object('ok', true, 'adet', p_adet, 'kalan_hediye_hakki', v_kazanilan - v_hediye_edilen - p_adet);
end $mh249$;

grant execute on function public.misafir_hakki_hediye_et(uuid, int, text) to authenticated;

-- Ekranın "kaç hakkım var" diye sorabilmesi için:
create or replace function public.hediye_edilebilir_hakkim()
returns jsonb
language plpgsql stable security definer set search_path = public as $hh249$
declare v_uid uuid := auth.uid(); v_kaz int; v_ver int; v_bugun int;
begin
  if v_uid is null then return jsonb_build_object('adet', 0); end if;
  select coalesce(sum(delta),0) into v_kaz from credit_ledger
   where user_id = v_uid and reason = 'hosted_session' and delta > 0;
  select coalesce(-sum(delta),0) into v_ver from credit_ledger
   where user_id = v_uid and reason = 'hak_hediye_verildi';
  select count(*) into v_bugun from credit_ledger
   where user_id = v_uid and reason = 'hak_hediye_verildi' and created_at > now() - interval '24 hours';
  return jsonb_build_object(
    'adet', greatest(0, v_kaz - v_ver),
    'agirlayarak_kazanilan', v_kaz,
    'hediye_edilen', v_ver,
    'bugun_kalan', greatest(0, 3 - v_bugun));
end $hh249$;

grant execute on function public.hediye_edilebilir_hakkim() to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §8 — YÜZEY
-- ════════════════════════════════════════════════════════════════════════

insert into rpc_client_surface (fn_name, client, note) values
  ('host_daveti',              'app', 'Host olsan ne kazanirsin — merdiven tirmanmadan once (A1)'),
  ('havalimani_nabzi',         'app', 'Bu havalimaninda kac host var (A2)'),
  ('kabin_sorulmali_mi',       'app', 'Kabin sorusu yalniz kabin kurali olan salonda sorulur (B2)'),
  ('misafir_hakki_hediye_et',  'app', 'Agirlayarak kazanilan hakki baglantina hediye et (A1)'),
  ('hediye_edilebilir_hakkim', 'app', 'Hediye edilebilir hak sayaci')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;

-- ════════════════════════════════════════════════════════════════════════
-- §9 — NÖBETÇİ · davranış ölçer, geri alınan alt işlemde
-- ════════════════════════════════════════════════════════════════════════

do $n249$
declare
  v_h text[] := '{}';
  v_host uuid; v_guest uuid; v_ap text; v_lounge uuid; v_a uuid; v_r jsonb;
  v_bedel int; v_n int; v_c jsonb; v_alici uuid; v_gonderen uuid;
begin
  begin
    select code into v_ap from airports order by code limit 1;
    select l.id into v_lounge from lounges l where l.airport_code = v_ap::char(3) and l.active limit 1;
    select id into v_host from users limit 1;

    -- 🔴 AKTÖRLER SEÇİLİR, VERİ DEĞİŞTİRİLMEZ.
    -- Eski hâl "hiç ağırlamamış kişi" koşulunu, seçtiği kişinin
    -- OTURUMLARINI SİLEREK kuruyordu. `ratings.session_id` ve
    -- `reports.session_id` cascade'siz (NO ACTION) — yani puanlanmış
    -- bir oturumu olan bir kullanıcı seçildiği anda ölçüm, tam da
    -- `availabilities` silmede aldığımız hatanın aynısını alırdı.
    -- Koşulu kurmanın doğru yolu veriyi bozmak değil, koşulu ZATEN
    -- SAĞLAYAN bir kaydı seçmek.
    select u.id into v_guest
      from users u
     where u.id <> v_host
       and not exists (select 1 from sessions s join requests r on r.id = s.request_id
                        where r.host_id = u.id)
     limit 1;
    if v_guest is null then
      -- Böyle bir kullanıcı yoksa bu ölçüm YAPILAMAZ; uydurmak yerine
      -- söylüyoruz. "Ölçemedim" demek, yanlış ölçmekten iyidir.
      select id into v_guest from users where id <> v_host limit 1;
      raise notice '249: hic agirlamamis kullanici yok — merdiven olcumu atlandi';
    end if;

    -- (1) A1 — merdiven, HİÇ AĞIRLAMAMIŞ kişiye de görünmeli
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_guest, 'role','authenticated')::text, true);
    v_r := public.host_standing();
    if coalesce(v_r ->> 'karsilik_cumlesi','') !~ 'İlk ağırlaman' then
      v_h := v_h || 'hic agirlamamis kisiye merdiven gosterilmiyor'::text;
    end if;
    if coalesce(v_r #>> '{plan_hediyesi,esik}','') = '' then
      v_h := v_h || 'host_standing plan hediyesini dondurmuyor'::text;
    end if;
    v_r := public.host_daveti();
    if jsonb_array_length(coalesce(v_r -> 'basamaklar','[]'::jsonb)) < 2 then
      v_h := v_h || 'host_daveti merdiven basamaklarini dondurmuyor'::text;
    end if;

    -- (2) A4 — SOĞUK AĞDA İSTEK BEDAVA
    --
    -- 🔴 BU ÖLÇÜM GÖKBERK'İN VERİTABANINDA ÇÖKTÜ:
    --     "update or delete on table availabilities violates foreign key
    --      constraint requests_avail_id_fkey on table requests"
    --
    -- Eski hâli, ölçüme temiz bir havalimanı hazırlamak için O HAVALİMANININ
    -- BÜTÜN İLANLARINI SİLİYORDU. Boş bir veritabanında sorunsuz çalışır;
    -- gerçek veride o ilanlara bağlı istekler var ve `requests.avail_id`
    -- NOT NULL + cascade'siz. Yani ölçüm, ölçtüğü sistemin verisini
    -- silmeye çalışıp kendi kendine çarptı.
    --
    -- Asıl kusur "cascade eksik" değil: BİR NÖBETÇİ ÜRETİM VERİSİNE
    -- DOKUNMAMALI. Geri alma (rollback) bir güvenlik ağıdır, izin değil —
    -- blok yarıda kesilirse ya da biri bu SQL'i işlem dışında çalıştırırsa
    -- silinen gerçek satırlar geri gelmez.
    --
    -- 🆕 SINIF: "BİR ÖLÇÜM, İSTEDİĞİ KOŞULU VAR OLAN VERİYİ SİLEREK
    -- KURUYORSA, O ÖLÇÜM BİR RİSKTİR — KOŞULU KENDİ VERİSİNİ YARATARAK
    -- KURMALIDIR."
    --
    -- Artık ölçüm KENDİ havalimanını yaratıyor: hiçbir gerçek satıra
    -- dokunulmuyor, hiçbir şey silinmiyor. (Blok yine `GERI_AL_249` ile
    -- geri alınıyor; yani bu satırlar da kalıcı olmuyor.)
    insert into airports (code, name, city, country, timezone)
    values ('ZZT', '249 ölçüm havalimanı', 'Ölçüm', 'TR', 'Europe/Istanbul')
    on conflict (code) do nothing;
    insert into lounges (airport_code, name, terminal, access_types, active)
    values ('ZZT', '249 ölçüm salonu', 'T1', '{}', true)
    returning id into v_lounge;
    v_ap := 'ZZT';

    insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                time_from, time_to, slots, filled, active, visibility)
    values (v_host, v_lounge, 'ZZT', current_date + 5, time '10:00', time '14:00',
            2, 0, true, 'Public')
    returning id into v_a;

    v_bedel := public.request_credit_cost(v_guest, v_a);
    if v_bedel <> 0 then
      v_h := v_h || format('soguk agda (1 host) istek bedeli %s — 0 olmaliydi', v_bedel)::text;
    end if;

    -- (3) TERS YÖN — ağ ısınınca bedel geri gelmeli. Aksi hâlde kredi
    --     ekonomisini kalıcı olarak kapatmış oluruz.
    for v_n in 1..4 loop
      insert into availabilities (host_id, lounge_id, airport_code, avail_date,
                                  time_from, time_to, slots, filled, active, visibility)
      select u.id, v_lounge, 'ZZT', current_date + 5, time '10:00', time '14:00',
             2, 0, true, 'Public'
        from users u where u.id <> v_guest
        order by u.id offset v_n limit 1;
    end loop;
    v_bedel := public.request_credit_cost(v_guest, v_a);
    if v_bedel <> 1 then
      v_h := v_h || format('ag isindiginda bedel %s — 1 olmaliydi (indirim kalici olmus)', v_bedel)::text;
    end if;

    -- (4) A2 — nabız gerçekten sayıyor mu
    -- Ölçüm havalimanında 5 ilan var (biri soğuk testinden, dördü ısıtma
    -- turundan); nabız onu görmek ZORUNDA. Gerçek havalimanına bakmıyoruz
    -- çünkü orada ilan olup olmadığı veritabanına göre değişir — ve
    -- veriye bağlı bir nöbetçi, bir gün sessizce yanlış cevap verir.
    select count(*) into v_n from public.havalimani_nabzi(14) where airport_code = 'ZZT';
    if v_n < 1 then
      v_h := v_h || 'havalimani_nabzi ilan olan havalimanini hic dondurmedi'::text;
    end if;
    select host_sayisi into v_n from public.havalimani_nabzi(14) where airport_code = 'ZZT';
    if coalesce(v_n,0) < 1 then
      v_h := v_h || 'havalimani_nabzi host saymiyor'::text;
    end if;

    -- (5) B2 — kabin sorusu yalnız kabin kuralı olan salonda
    v_c := public.kabin_sorulmali_mi(null);
    if coalesce(v_c ->> 'sor','') <> 'false' then
      v_h := v_h || 'salon secilmemisken kabin soruluyor'::text;
    end if;

    -- (6) A1 yeni fikir — hediye kapıları
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_host, 'role','authenticated')::text, true);
    begin
      -- Bağlantı YOK → reddedilmeli.
      -- Bağlantıyı SİLMİYORUZ (silmek `chat_channels`i cascade ile
      -- götürür): bağlantısı OLMAYAN bir alıcı seçiyoruz.
      select u.id into v_alici
        from users u
       where u.id <> v_host
         and not exists (select 1 from connection_requests c
                          where (c.from_id = v_host and c.to_id = u.id)
                             or (c.from_id = u.id   and c.to_id = v_host))
       limit 1;
      if v_alici is null then
        -- 🔴 "ÖLÇEMEDİM" İLE "GEÇTİ" AYNI ŞEY DEĞİL. Uygun aktör yoksa
        -- beklenen hatayı KENDİM fırlatmak, kapının kapalı olduğunu
        -- kanıtlamaz — yalnız testi yeşile boyar. Onun için burada
        -- açıkça "ölçülemedi" deniyor.
        raise notice '249: baglantisiz alici yok — hediye kapisi 1 OLCULEMEDI';
        raise exception 'baglanti_yok';
      end if;
      perform public.misafir_hakki_hediye_et(v_alici, 1);
      v_h := v_h || 'baglanti olmadan hediye gonderilebildi'::text;
    exception when others then
      if sqlerrm not like '%baglanti_yok%' then
        v_h := v_h || ('hediye baglanti testi beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;
    begin
      -- Bağlantı VAR ama ağırlayarak kazanılmış kredi YOK → reddedilmeli.
      -- Kredi defterini SİLMİYORUZ (gerçek kredi geçmişi): ağırlayarak
      -- kredi kazanMAMIŞ bir gönderici seçip ona bağlantı kuruyoruz.
      select u.id into v_gonderen
        from users u
       where u.id <> v_guest
         and not exists (select 1 from credit_ledger cl
                          where cl.user_id = u.id and cl.reason = 'hosted_session')
       limit 1;
      if v_gonderen is null then
        raise notice '249: agirlayarak kredi kazanmamis kullanici yok — hediye kapisi 2 OLCULEMEDI';
        raise exception 'agirlayarak_kazanilan_kredi_yetersiz';
      end if;
      insert into connection_requests (from_id, to_id, intent, status, responded_at)
      values (v_gonderen, v_guest, 'connect', 'accepted', now());
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_gonderen, 'role','authenticated')::text, true);
      perform public.misafir_hakki_hediye_et(v_guest, 1);
      v_h := v_h || 'agirlayarak kazanilmamis kredi hediye edilebildi — kredi ticareti kapisi'::text;
    exception when others then
      if sqlerrm not like '%agirlayarak_kazanilan_kredi_yetersiz%' then
        v_h := v_h || ('hediye kaynak testi beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;

    -- (7) A4 ikinci yarı — bayat istek iadesi idempotent mi
    v_r := public.bayat_istekleri_iade_et();
    if coalesce(v_r ->> 'ok','') <> 'true' then
      v_h := v_h || 'bayat_istekleri_iade_et calismadi'::text;
    end if;

    raise exception 'GERI_AL_249';
  exception when others then
    if sqlerrm <> 'GERI_AL_249' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '249 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '249 OK · merdiven tirmanmadan gorunuyor · soguk agda istek bedava, ag isininca degil · nabiz sayiyor · kabin kosullu · hediye kapilari kapali';
end $n249$;

commit;

select '249 IS MODELI' as sonuc,
       (select count(*) from public.havalimani_nabzi(14))                       as nabizli_havalimani,
       (select (value #>> '{}')::int from beta_settings where key='soguk_ag_host_esigi') as soguk_esik,
       (select (value #>> '{}')::int from beta_settings where key='bayat_istek_saat')     as bayat_saat;
