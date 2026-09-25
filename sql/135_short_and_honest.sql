-- ============================================================
-- LoungeLink · 135_short_and_honest.sql
-- KISA METIN + ROZET KESINLIK DUZEYINE UYSUN
--
-- ⚠️ Uygulamayi ETKILER (metinler + rozet mantigi).
--
-- ------------------------------------------------------------
-- 🔴 SORUN 1: "MISAFIR ALINMIYOR" DIYIP BASVURUYA IZIN VERIYORUZ
-- ------------------------------------------------------------
-- Gokberk hakli: rozet "Bu ilan misafir alamiyor" diyor ama buton
-- aktif. Bu bir MANTIK hatasi degil, DIL hatasi:
--
--   enforcement = 'block' -> kesin biliyoruz, engelliyoruz
--   enforcement = 'warn'  -> oyle GORUNUYOR ama dogrulamadik
--
-- Ikisine de AYNI kesin cumleyi yazmisim. Kullanici "alinmiyor"
-- okuyup butonu aktif gorunce ya urunun bozuk oldugunu ya da
-- uyarinin ciddiye alinmayacagini dusunuyor. Ikisi de kotu.
--
-- Cozum: emin OLMADIGIMIZDA emin gibi konusma. Engellemeyi
-- sikilastirmak DEGIL — dogrulanmamis veriye dayanip kullaniciyi
-- engellemek, kendi veri eksigimizi ona fatura etmek olur (bu
-- karari 115'te vermistik ve dogruydu).
--
-- ------------------------------------------------------------
-- 🔴 SORUN 2: METINLER 157-284 KARAKTER
-- ------------------------------------------------------------
-- "Kullanici bu kadar uzun metni okuyamaz, okusa da anlayamaz."
-- Dogru. Uzun metin, okunmamis metindir — ve icindeki gercekten
-- onemli cumle de okunmamis olur.
--
-- Yeni hedef: ANA CUMLE en fazla ~90 karakter, gerisi ⓘ arkasinda.
-- Kullanicinin kapida ihtiyaci olan TEK cumleyi one al.
-- ============================================================

-- ---- Kesinlik duzeyine gore rozet ----
insert into beta_settings (key, value) values
 ('badge_labels', '{
    "same_flight":  {"label":"AYNI UÇUŞ",
                     "info":"Bu host seninle aynı uçuşta. Kural açısından en güvenli eşleşme türü."},
    "flight_bad":   {"label":"Uçuşun uymuyor",
                     "info":"Bu salon misafirin belirli bir havayolunda olmasını istiyor; senin uçuşun bu koşulu karşılamıyor. Kapıda geri çevrilme ihtimalin yüksek."},
    "guest_paid":   {"label":"Misafir ücretli",
                     "info":"Misafir girişi ücretsiz değil. Ücreti kimin ödediğini istek gönderirken yazıyoruz."},
    "guest_none":   {"label":"Misafir alınmıyor",
                     "info":"Host bu salona girebiliyor ama yanında misafir götürme hakkı yok. Bu kuralı resmî kaynaktan doğruladık."},
    "guest_none_soft": {"label":"Misafir hakkı görünmüyor",
                     "info":"Elimizdeki bilgiye göre bu ilanda misafir hakkı yok — ama bunu resmî kaynaktan DOĞRULAYAMADIK. Başvurabilirsin; girişi buluşmadan önce host ile teyit et."},
    "unverified":   {"label":"Kural doğrulanmadı",
                     "info":"Bu SALONUN misafir kuralını resmî kaynaktan doğrulayamadık — ilanla ya da host ile ilgili bir sorun değil. Başvurabilirsin, girişi teyit et."},
    "guest_free":   {"label":"Misafir ücretsiz",
                     "info":"Host''un hakkı misafiri kapsıyor; kapıda ek ücret çıkmaz."}
  }'::jsonb)
on conflict (key) do update set value = excluded.value;

-- ---- KISA METINLER ----
-- 🔴 Her biri TEK CUMLE ve ~90 karakter. Uzun aciklama ⓘ''ye tasindi.
insert into beta_settings (key, value) values
 ('rule_notice_generic', to_jsonb(
   'Bu salonun misafir kuralını doğrulayamadık — girişi host ile teyit et.'::text)),
 ('card_notice_guest', to_jsonb(
   'Hak bir kredi kartından geliyor; koşulları banka belirler, biz doğrulayamıyoruz.'::text)),
 ('card_notice_host', to_jsonb(
   'Kart koşullarını banka belirler ve değişebilir — hakkını önce kendin teyit et.'::text)),
 ('fee_note_member_card', to_jsonb(
   'Ücret kapıda değil, host''un kartından çekilir. Bunu aranızda konuşun.'::text)),
 ('fee_note_guest_at_door', to_jsonb(
   'Misafir girişi kapıda ücretli; tutarı önceden teyit edin.'::text)),
 ('paid_guest_notice', to_jsonb(
   'Ücreti host ödüyor. Kabul edilirse {n} kredi ona aktarılır — bir teşekkür, tazminat değil.'::text)),
 ('quota_note_guest_shape', to_jsonb(
   'Host''un misafir hakkı sınırlı; kaç hakkı kaldığını doğrulayamıyoruz.'::text)),
 ('quota_note_guest_exhausted', to_jsonb(
   'Host beyanına göre bu dönemki misafir hakkını tüketmiş — mutlaka konuşun.'::text)),
 ('quota_note_host', to_jsonb(
   'Beyanına göre {left}/{total} hakkın kaldı. Ara sıra bankandan teyit et.'::text))
on conflict (key) do update set value = excluded.value;

-- ---- Rozet secimi kesinlige duyarli ----
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
    -- 🔴 ENGELLEMIYORSAK KESIN KONUSMA. Ayni durum, iki farkli
    -- kesinlik duzeyi, iki farkli cumle.
    elsif (d ->> 'guest_policy') = 'not_allowed' then
      v_key := 'guest_none_soft'; v_boost := -200;
    elsif (d ->> 'guest_policy') = 'paid' then       v_key := 'guest_paid';  v_boost := -20;
    elsif (d ->> 'confidence') in ('unknown','assumed') then v_key := 'unverified'; v_boost := -10;
    elsif (d ->> 'guest_policy') = 'included' then   v_key := 'guest_free';  v_boost := 20;
    else v_key := null;
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

select key, length(value #>> '{}') as uzunluk
  from beta_settings
 where key in ('rule_notice_generic','card_notice_guest','fee_note_member_card',
               'paid_guest_notice','quota_note_guest_shape')
 order by 2 desc;

select '135 OK - metinler kisaldi, rozet kesinlige uydu' as sonuc;
