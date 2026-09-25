-- ============================================================================
-- LoungeLink · 219_kredi_ve_ucret_dili.sql                (19 Ağustos 2026)
--
-- ÜÇ İŞ, HEPSİ CİHAZDA GÖRÜLDÜ:
--   1) Ücretli misafirde host'a aktarılan teşekkür kredisi 2 → 1
--   2) "Host ödüyor" dili gidiyor — ücret sohbette konuşulur
--   3) "Başvuru kapalı" derken "Başvurabilirsin" diyen metin/kapı çelişkisi
--
-- Üçü de aynı dosyada çünkü aynı ekranı anlatıyorlar: istek gönderme anı.
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- 1) TEŞEKKÜR KREDİSİ 2 → 1
--
-- Gökberk: "guestten hosta 2 kredi geçen durumda 2 kredi fazla."
--
-- 🔴 AYARI DEĞİŞTİRMEK YETMEZ — SESSİZ YEDEK AYARDAN UZUN YAŞAR.
-- 181 tarifeyi `beta_settings['paid_guest_credits']` anahtarına taşımıştı
-- ama fonksiyonun içinde ÜÇ yerde sabit 2 bıraktı:
--     select coalesce((value)::text::int, 2) ...   ← satır yoksa 2
--     return coalesce(v_n, 2);                     ← değer null ise 2
--     exception when others then return 2;         ← hata olursa 2
-- Yani ayarı 1 yapıp fonksiyona dokunmasaydım, anahtar bir gün silinse ya
-- da tipi bozulsa sistem sessizce 2 krediye dönerdi ve kimse görmezdi.
-- Bir ayarın yedeği, ayarın kendisiyle AYNI değeri taşımalı.
-- ════════════════════════════════════════════════════════════════════════

insert into beta_settings (key, value) values ('paid_guest_credits', '1'::jsonb)
on conflict (key) do update set value = '1'::jsonb;

-- sqlcheck: allow-replace paid_guest_credit  (dönüş tipi AYNI: int)
create or replace function public.paid_guest_credit(p_avail_id uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare v_n int; v_paid boolean;
begin
  select coalesce((public.lounge_access_decision(p_avail_id, null) ->> 'guest_policy') = 'paid', false)
    into v_paid;
  if not coalesce(v_paid, false) then return 0; end if;

  -- 🔴 219: üç yedeğin ÜÇÜ de 1. Ayar okunamazsa da doğru sayı çıkar.
  select coalesce((value)::text::int, 1) into v_n
    from beta_settings where key = 'paid_guest_credits';
  return coalesce(v_n, 1);
exception when others then
  return 1;
end $$;
-- 🔴 GRANT YOK — VE BU BİLEREK. İlk yazımda 181'e bakıp refleksle
-- `grant ... to authenticated` koydum; harness kırmızı yaktı:
--     "RPC yuzeyi ihlali: paid_guest_credit -> yuzeyde yok ama istemciye acik"
-- 108 ve 187 bir zamanlar grant vermiş, sonraki bir migration geri almış.
-- `create or replace` grant'ları düşürmediği için benim satırım kapıyı
-- yeniden açıyordu. Bu fonksiyon İÇ hesap: istemci tarifeyi doğrudan
-- sorgulamamalı, `request_precheck` üzerinden görmeli.
-- Ölçüm: 219'u dosya listesinden çıkarınca ihlal kayboluyor, geri koyunca
-- geliyor — yani sebep bendim, eski dosyalar değil.


-- ════════════════════════════════════════════════════════════════════════
-- 2) "HOST ÖDÜYOR" DİLİ GİDİYOR
--
-- Gökberk: "host öder demek host'u kaçırır, guest de yanlış anlar."
--
-- Ve bir sebep daha var — o cümle DOĞRU OLMAYABİLİR. Kartın kime fatura
-- ettiğini biz doğrulayamıyoruz; host da bilmiyor olabilir. "Host ödüyor"
-- bir bilgi değil, bir TAAHHÜT gibi okunuyor ve taahhüdü veremeyiz.
--
-- Söyleyebileceğimiz tek doğru şey: ücret VAR, tutarı aranızda konuşun.
-- LoungeLink ödeme almaz, aracılık etmez — bunu da açıkça yazıyoruz ki
-- kimse platformdan bir garanti beklemesin.
--
-- 🔴 DÖRT ANAHTAR, DÖRDÜ DE beta_settings İÇİNDE. Yani bu metinler
-- migration ile değişir; app build'i gerekmez. Metni koda gömmemiş
-- olmamız bugün işe yaradı.
-- ════════════════════════════════════════════════════════════════════════

insert into beta_settings (key, value) values
 -- 120:53'ten geliyor — "Misafir girişi ücretli — host ödüyor"
 ('head_fee_member', to_jsonb('Misafir girişi ücretli'::text)),

 -- 135:66'dan geliyor — "Ücret kapıda değil, host'un kartından çekilir."
 ('fee_note_member_card', to_jsonb(
   'Ücret kapıda değil, host''un üyeliği üzerinden işler. Tutarı ve nasıl '
   'ödeneceğini sohbette kararlaştırın.'::text)),

 -- 135:68 — kapıda ödenen durum. Burada "host ödüyor" zaten yoktu,
 -- yalnız "aranızda konuşun" yönlendirmesi eklendi.
 ('fee_note_guest_at_door', to_jsonb(
   'Misafir girişi kapıda ücretli. Tutarı buluşmadan önce sohbette '
   'netleştirin.'::text)),

 -- 135:70 — istek gönderme ekranındaki kredi notu
 ('paid_guest_notice', to_jsonb(
   'Bu salon misafirden giriş ücreti alıyor. Tutarı ve ödeme şeklini host '
   'ile sohbette kararlaştırın — LoungeLink ödeme almaz, aracılık etmez. '
   'Kabul edilirse {n} kredi host''a teşekkür olarak geçer.'::text))
on conflict (key) do update set value = excluded.value;


-- ════════════════════════════════════════════════════════════════════════
-- 3) ROZET METNİ İLE KAPI ARASINDAKİ ÇELİŞKİ
--
-- Cihazda görülen: kartın butonu "Başvuru kapalı" derken ⓘ kutusu
-- "Başvurabilirsin; girişi buluşmadan önce host ile teyit et" diyordu.
--
-- 🔴 BU BİR METİN HATASI DEĞİL — ÜÇ KATMAN AYRI ŞEY SÖYLÜYORDU:
--
--   rozet motoru (135:119)  yumuşak not_allowed → v_block FALSE
--                           yani "engellemiyoruz, başvurabilirsin"
--   app ekranı (screens.js:1139)
--                           guest_policy='not_allowed' → blocks_request TRUE
--   sunucu (159:214-218)    guest_policy='not_allowed' → guests_not_allowed
--
-- Üçten İKİSİ kapatıyor. Yani kapı gerçekten kapalı; yalan söyleyen metin.
--
-- 🔴 KAPIYI AÇMIYORUM, METNİ GERÇEĞE UYDURUYORUM. Kapıyı açsaydım
-- kullanıcı "Gönder"e basıp sunucudan ham `guests_not_allowed` yiyecekti —
-- bugünkü halinden kötü. Doğrulayamadığımız bir hakla kimseyi kapıya
-- göndermeyiz; bu ürünün tek satış argümanı bu.
--
-- Ama "doğrulayamadık" dürüstlüğü KAYBOLMUYOR. 135'in yorumunda yazan
-- "ENGELLEMIYORSAK KESIN KONUSMA" ilkesi hâlâ geçerli — yalnız burada
-- engelliyoruz, o yüzden neden engellediğimizi ve kullanıcının ne
-- yapabileceğini söylüyoruz. Çıkışsız bir "hayır" değil, kapısı olan bir
-- "şimdilik hayır".
-- ════════════════════════════════════════════════════════════════════════

do $$
declare v jsonb;
begin
  select value into v from beta_settings where key = 'badge_labels';
  if v is null then
    raise exception '219: badge_labels anahtari yok — 135 kurulmamis olabilir';
  end if;

  v := jsonb_set(v, '{guest_none_soft}', jsonb_build_object(
    'label', 'Misafir hakkı görünmüyor',
    'info',  'Elimizdeki bilgiye göre bu ilanda misafir hakkı yok. Bunu resmî '
             'kaynaktan doğrulayamadık, o yüzden kesin konuşmuyoruz — ama '
             'doğrulayamadığımız bir hakla seni kapıya göndermeyiz, başvuru '
             'kapalı. Host''a sohbetten sorabilirsin; hakkını teyit ederse '
             'ilanını güncellesin, başvuru açılır.'));

  -- guest_paid: "Ücreti kimin ödediğini istek gönderirken yazıyoruz" cümlesi
  -- artık yanlış — kimin ödediğini YAZMIYORUZ, konuşmalarını istiyoruz.
  v := jsonb_set(v, '{guest_paid}', jsonb_build_object(
    'label', 'Misafir ücretli',
    'info',  'Bu salon misafir girişinden ücret alıyor. Tutarı ve ödeme '
             'şeklini host ile sohbette kararlaştırın — LoungeLink ödeme '
             'almaz, aracılık etmez.'));

  update beta_settings set value = v where key = 'badge_labels';
  raise notice '219: rozet metinleri guncellendi (guest_none_soft, guest_paid)';
end $$;


-- ---- Rozet motoru: yumuşak not_allowed artık KAPI olarak raporlanıyor ----
--
-- 🔴 ETİKET DEĞİŞMİYOR, YALNIZ blocks_request DEĞİŞİYOR. v_block'u
-- anahtar seçiminden ÖNCE true yapsaydım, yumuşak durum 'guest_none'
-- etiketini alırdı — o etiketin metni "Bu kuralı resmî kaynaktan
-- DOĞRULADIK" diyor ve doğrulamadık. Yani doğru davranışı yanlış cümleyle
-- söylemiş olurdum. Anahtar seçimi bittikten SONRA kapıyı kapatıyorum.
--
-- ════════════════════════════════════════════════════════════════════
-- 🔴 19 AĞUSTOS — GÖKBERK'İN CANLIDA ALDIĞI HATA. BENİM HATAM.
--
--   ERROR: 42P13 cannot change return type of existing function
--   DETAIL: Row type defined by OUT parameters is different.
--   HINT: Use DROP FUNCTION discovery_rule_badges(uuid[]) first.
--
-- Burada `-- sqlcheck: allow-replace discovery_rule_badges (returns
-- table AYNI)` yazıyordu. O iddia YANLIŞTI — daha doğrusu YARIM
-- doğruydu:
--   · 135'e göre AYNI (8 kolon)          → doğru
--   · 221'e göre FARKLI (9 kolon, can_ask_host) → yanlış
--
-- Yani "aynı" derken DOSYA SIRASINA bakmışım: boş bir veritabanına
-- 1'den 226'ya kurulunca 219 her zaman 135'in 8 kolonlu hâlini görür
-- ve `create or replace` çalışır. Benim harness'ım tam olarak bunu
-- yapıyor — bu yüzden 255 dosya "temiz" dedi.
--
-- Ama CANLI veritabanı bir sıra değil, bir DURUM. Gökberk turu bir kez
-- kurmuş (221 koşmuş, fonksiyon 9 kolona çıkmış), sonra 219'dan
-- yeniden başlamış. O anda canlıdaki şekil 9, dosyadaki 8 → 42P13.
--
-- 🆕 SINIF: **"AYNI" BİR KARŞILAŞTIRMADIR VE NEYE GÖRE OLDUĞU
-- SÖYLENMEDİKÇE BOŞTUR.** allow-replace işareti ancak fonksiyonun
-- dönüş şekli TÜM dosyalarda (öncekiler VE sonrakiler) aynıysa
-- güvenlidir. sqlcheck.py bunu artık kendisi ölçüyor: aynı fonksiyonun
-- iki farklı dönüş şekli varsa allow-replace REDDEDİLİYOR.
--
-- Bu, kayıtlı "yerel yeşil ≠ canlı yeşil" sınıfının (SQL 166) üçüncü
-- örneği. Oradaki ders "eşikleri kendi sandbox verime göre ayarladım"
-- idi; buradaki "sırayı durum sandım".
--
-- drop güvenli: hemen altındaki create ve 229. satırdaki grant aynı
-- betikte, PostgreSQL'de DDL işlemseldir — arada açık kalan an yok.
-- ════════════════════════════════════════════════════════════════════
drop function if exists public.discovery_rule_badges(uuid[]);
create or replace function public.discovery_rule_badges(p_ids uuid[])
returns table (
  avail_id uuid, severity text, label text, info text, detail text,
  same_flight_match boolean, blocks_request boolean, sort_boost int
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

    -- 🔴 219 — KAPI HİZASI. `create_request` (159:214) guest_policy
    -- 'not_allowed' olan HER ilanı reddediyor; kesinlik düzeyine bakmıyor.
    -- Rozet "engellemiyorum" derse app ile sunucu ayrışıyor ve kullanıcı
    -- ham hata görüyor. Etiket yumuşak kalıyor, kapı gerçeği söylüyor.
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
    return next;
  end loop;
end $$;
grant execute on function public.discovery_rule_badges(uuid[]) to authenticated;


-- ════════════════════════════════════════════════════════════════════════
-- NÖBETÇİ — rozet ile sunucu kapısı bir daha ayrışmasın
--
-- 🔴 BU DENETİMİ YAZMASAYDIM DÜZELTME BİR SÜRÜM SONRA GERİ GELİRDİ.
-- Bugünkü çelişki tam olarak böyle doğdu: 135 kapıyı açık bıraktı,
-- 159 kapattı, ikisi birbirinden habersizdi ve arada geçen sürümlerde
-- kimse ikisini yan yana koymadı.
--
-- Kural: rozet motorunun `blocks_request` cevabı ile `create_request`'in
-- reddetme koşulu AYNI ilan için aynı sonucu vermeli.
-- ════════════════════════════════════════════════════════════════════════

do $$
declare
  v_ayrisan int := 0; v_bakilan int := 0; v_ornek text := '';
  r record; v_sunucu boolean; d jsonb;
begin
  for r in
    select b.avail_id, b.blocks_request
      from availabilities a
      join lateral public.discovery_rule_badges(array[a.id]) b on true
     where a.active
  loop
    v_bakilan := v_bakilan + 1;
    d := public.lounge_access_decision(r.avail_id, null);
    -- 159:215-216 ile BİREBİR aynı koşul
    v_sunucu := (d ->> 'guest_policy') = 'not_allowed'
                or ((d ->> 'severity') = 'block'
                    and coalesce((d ->> 'fits')::text,'') <> 'false');
    if coalesce(r.blocks_request,false) <> coalesce(v_sunucu,false) then
      v_ayrisan := v_ayrisan + 1;
      if v_ornek = '' then
        v_ornek := left(r.avail_id::text,8) || ' rozet=' || coalesce(r.blocks_request::text,'-')
                || ' sunucu=' || coalesce(v_sunucu::text,'-')
                || ' politika=' || coalesce(d ->> 'guest_policy','-')
                || ' siddet='   || coalesce(d ->> 'severity','-');
      end if;
    end if;
  end loop;

  -- Sıfır satır karşılaştıran bir denetim "0 ayrışma" diye yeşil yanar.
  -- Bu turda tam olarak o tuzağa bir kez düştüm; burada kapatıyorum.
  if v_bakilan = 0 then
    raise notice '219: aktif ilan yok — kapi hizasi OLCULEMEDI (bos veritabani)';
  elsif v_ayrisan > 0 then
    raise exception '219: % / % ilanda rozet ile sunucu kapisi AYRISIYOR → %',
      v_ayrisan, v_bakilan, v_ornek;
  else
    raise notice '219: % ilanda rozet ile sunucu kapisi hizali', v_bakilan;
  end if;
end $$;


-- ---- Kredi tutarı gerçekten 1 mi ----
do $$
declare v_ayar int; v_fn int; v_ornek uuid;
begin
  select (value)::text::int into v_ayar from beta_settings where key = 'paid_guest_credits';
  if coalesce(v_ayar, -1) <> 1 then
    raise exception '219: paid_guest_credits ayari % (1 bekleniyor)', v_ayar;
  end if;

  -- Ücretli bir ilan bulup fonksiyonun gerçekten 1 döndürdüğünü ölç.
  -- Ayarı okumak fonksiyonu ölçmez; fonksiyonun kendi yedekleri de var.
  select a.id into v_ornek
    from availabilities a
   where a.active
     and (public.lounge_access_decision(a.id, null) ->> 'guest_policy') = 'paid'
   limit 1;

  if v_ornek is null then
    raise notice '219: ucretli misafirli aktif ilan yok — fonksiyon CANLI olculemedi (ayar=1 dogrulandi)';
  else
    v_fn := public.paid_guest_credit(v_ornek);
    if v_fn <> 1 then
      raise exception '219: paid_guest_credit() % dondu (1 bekleniyor), ilan %', v_fn, v_ornek;
    end if;
    raise notice '219: paid_guest_credit() canli ilanda 1 dondurdu';
  end if;
end $$;

select '219 OK — tesekkur kredisi 1, ucret dili sohbete tasindi, kapi hizalandi' as sonuc;
