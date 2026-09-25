-- ============================================================
-- 205 · BACKOFFICE ADRESİNİ KENDİSİ KAYDEDER — elle adım kalktı
-- 17 Ağustos 2026
--
-- 🔴 BU DOSYA BİR İTİRAZLA DOĞDU. Gokberk sordu:
--   "Ayrıca sen onu doğrudan ekleyemiyor musun, neden bana ekletiyorsun ki?"
--
-- Haklıydı. Önceki turda `app.json` içindeki `expo.extra.backofficeUrl`
-- alanını ONUN doldurmasını istemiştim. Bunun tek meşru gerekçesi
-- "adresi ben bilemem" olabilirdi; ölçtüm:
--   grep -rn "loungelink-bo.vercel.app" .
--   → yalnız teslim/TUR5_RAPOR.md — yani BENİM uydurduğum örnek.
-- Adres gerçekten bilinmiyor. AMA bilmesi gereken ben değilim:
-- BACKOFFICE KENDİ ADRESİNİ BİLİYOR (`headers().get('host')`) ve
-- uygulamanın da Supabase bağlantısı var. Aradaki insan gereksiz.
--
-- YENİ AKIŞ:
--   1. BO herhangi bir sayfası açıldığında kendi adresini
--      `beta_settings.backoffice_url`e yazar (service_role ile).
--   2. Uygulama açılışta `service_endpoints()` RPC'sini okur.
--   3. `app.json` alanı SADECE geçersiz kılma (override) olarak kalır.
--
-- Gokberk'in yapacağı bir şey yok: BO'yu bir kez açması yeterli, o da
-- zaten yapacağı bir şey.
--
-- DAHA GENEL DERS: bir kuruluma "kullanıcı şunu yazsın" adımı
-- eklemeden önce sorulacak soru "bu bilgiyi sistemin bir parçası
-- zaten biliyor mu?" Cevap çoğu zaman evet.
-- ============================================================

insert into beta_settings (key, value)
values ('backoffice_url', to_jsonb(''::text))
on conflict (key) do nothing;


-- ============================================================
-- 1) BO KENDİNİ KAYDEDER
-- ============================================================
-- service_role dışında kimse çağıramaz (203'ün sınırı). Aksi hâlde
-- herhangi bir kullanıcı adresi kendi sunucusuna çevirip uygulamanın
-- oturum jetonunu kendine yönlendirebilirdi — bu bir kimlik hırsızlığı
-- yolu olurdu. Yüzey tablosuna EKLEMİYORUM; kasıtlı.
create or replace function public.bo_register_url(p_url text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_tmz text; v_onceki text;
begin
  v_tmz := rtrim(btrim(coalesce(p_url,'')), '/');

  -- Biçim kontrolü: yalnız https (ya da yerel geliştirme için http://localhost).
  if v_tmz = '' then raise exception 'bos_adres'; end if;
  if v_tmz !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?$'
     and v_tmz !~ '^http://localhost(:[0-9]+)?$'
     and v_tmz !~ '^http://127\.0\.0\.1(:[0-9]+)?$' then
    raise exception 'gecersiz_adres: %', v_tmz;
  end if;

  select value #>> '{}' into v_onceki from beta_settings where key = 'backoffice_url';
  if coalesce(v_onceki,'') = v_tmz then
    return jsonb_build_object('ok', true, 'degisti', false, 'url', v_tmz);
  end if;

  update beta_settings set value = to_jsonb(v_tmz), updated_at = now()
   where key = 'backoffice_url';

  return jsonb_build_object('ok', true, 'degisti', true, 'url', v_tmz, 'onceki', v_onceki);
end $fn$;

comment on function public.bo_register_url(text) is
  'Backoffice kendi genel adresini buraya yazar (yalniz service_role). Uygulama service_endpoints() ile okur. Elle app.json duzenlemesi gerekmez.';


-- ============================================================
-- 2) UYGULAMA OKUR
-- ============================================================
-- Yalnız uçuş sorgusu için gereken TEK alanı döndürür. "Ayar okuma"
-- adında genel bir kapı açmıyorum: `beta_settings` içinde kural
-- anahtarları da var (`ajet_intl_guest_right`, `otp_demo_mode`) ve
-- onların istemciye gitmesi için hiçbir sebep yok.
create or replace function public.service_endpoints()
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'backoffice_url', coalesce((select value #>> '{}' from beta_settings where key = 'backoffice_url'), ''),
    'flight_lookup_ready',
      coalesce((select value #>> '{}' from beta_settings where key = 'backoffice_url'), '') <> ''
  );
$fn$;

insert into rpc_client_surface (fn_name, client, note)
values ('service_endpoints','app','BO adresini uygulamaya bildirir — elle app.json adimini kaldirir')
on conflict (fn_name) do nothing;


-- ============================================================
-- 3) SINIRI YENİDEN UYGULA (203'ün kuralı)
-- ============================================================
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '205: sinir uygulandi — % fonksiyon kapatildi', v ->> 'kilitlenen';
end $$;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) YAZ → OKU YUVARLAK GİDİYOR MU
do $$
declare v jsonb; v_eski text;
begin
  select value #>> '{}' into v_eski from beta_settings where key = 'backoffice_url';

  perform public.bo_register_url('https://ornek-bo.vercel.app/');
  v := public.service_endpoints();
  if (v ->> 'backoffice_url') <> 'https://ornek-bo.vercel.app' then
    raise exception '205: yazilan adres geri okunamadi → %', v;
  end if;
  if (v ->> 'flight_lookup_ready') <> 'true' then
    raise exception '205: adres var ama hazir bayragi false → %', v;
  end if;

  update beta_settings set value = to_jsonb(coalesce(v_eski,'')) where key = 'backoffice_url';
  raise notice '205: BO adresi yazilip okunabiliyor (sondaki / temizleniyor)';
end $$;

-- 2) BOŞ ADRESTE BAYRAK FALSE OLMALI — yoksa uygulama var olmayan
--    bir sunucuya istek atar ve kullanıcı sebepsiz bekler.
do $$
declare v jsonb; v_eski text;
begin
  select value #>> '{}' into v_eski from beta_settings where key = 'backoffice_url';
  update beta_settings set value = to_jsonb(''::text) where key = 'backoffice_url';
  v := public.service_endpoints();
  if (v ->> 'flight_lookup_ready') <> 'false' then
    raise exception '205: adres BOSKEN hazir bayragi true → %', v;
  end if;
  update beta_settings set value = to_jsonb(coalesce(v_eski,'')) where key = 'backoffice_url';
  raise notice '205: adres yokken ozellik dogru sekilde KAPALI gorunuyor';
end $$;

-- 3) KÖTÜ ADRES REDDEDİLİYOR MU
-- 🔴 Bu nöbetçi bir güvenlik nöbetçisi: adres alanı bir yönlendirme
-- hedefidir. `javascript:` ya da saldırganın sunucusu yazılabilseydi,
-- uygulama Supabase oturum jetonunu oraya taşırdı.
do $$
declare v_gecen text := '';
begin
  begin perform public.bo_register_url('javascript:alert(1)'); v_gecen := v_gecen || 'javascript '; exception when others then null; end;
  begin perform public.bo_register_url('http://saldirgan.example.com'); v_gecen := v_gecen || 'duz-http '; exception when others then null; end;
  begin perform public.bo_register_url(''); v_gecen := v_gecen || 'bos '; exception when others then null; end;
  begin perform public.bo_register_url('https://x.com/api?a=1'); v_gecen := v_gecen || 'yollu '; exception when others then null; end;
  if v_gecen <> '' then
    raise exception '205: su gecersiz adresler KABUL EDILDI: %', v_gecen;
  end if;
  raise notice '205: gecersiz adres bicimleri reddediliyor (yalniz https ve localhost)';
end $$;

-- 4) SIRADAN KULLANICI ADRESİ DEĞİŞTİREMEZ
do $$
declare v_gecti boolean := false;
begin
  set local role authenticated;
  begin
    perform public.bo_register_url('https://saldirgan.vercel.app');
    v_gecti := true;
  exception when others then null;
  end;
  reset role;
  if v_gecti then
    raise exception '205: siradan kullanici BO adresini degistirebiliyor — oturum jetonu calinabilirdi';
  end if;
  raise notice '205: adres yalniz service_role tarafindan yazilabiliyor';
end $$;

select '205 OK - BO adresi kendini kaydediyor, elle app.json adimi kalkti' as sonuc;
