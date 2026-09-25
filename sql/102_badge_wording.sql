-- ============================================================
-- LoungeLink · 102_badge_wording.sql
-- KEŞİF ROZETLERİNİN DİLİ
--
-- ⚠️ Uygulamayı ETKİLER (metin). Şema değişikliği YOK.
--
-- 🔴 SORUN: "Kural doğrulanmadı" rozeti kullanıcıyı İTİYOR.
-- İki nedenden:
--   1. NEYİN kuralı olduğu belli değil — kullanıcı ilanın ya da host'un
--      doğrulanmadığını sanıyor. Oysa doğrulanmayan şey SALONUN misafir
--      kuralı; ilanla da host'la da ilgisi yok.
--   2. Rozet bir HÜKÜM gibi okunuyor ama aslında bir NOT. Başvuru
--      engellenmiyor; sadece "kapıda teyit et" diyoruz.
--
-- Rozet metinleri artık tek yerden geliyor ve BO'dan değiştirilebilir.
-- Her rozetin bir de AÇIKLAMASI var; app ⓘ ile gösteriyor.
-- ============================================================

insert into beta_settings (key, value) values
 ('badge_labels', '{
    "same_flight":  {"label":"AYNI UÇUŞ",
                     "info":"Bu host seninle aynı uçuşta. Kabul oranı en yüksek eşleşme türü budur — hem kural açısından en güvenli hem de kalkıştan önce tanışmak için en doğal fırsat."},
    "flight_bad":   {"label":"Uçuşun bu ilana uymuyor",
                     "info":"Bu salonun kuralı misafirin belirli bir havayolunda (bazen aynı uçuşta) olmasını istiyor; senin uçuşun bu koşulu karşılamıyor. Başvurabilirsin ama kapıda geri çevrilme ihtimalin yüksek."},
    "guest_paid":   {"label":"Misafir girişi ücretli",
                     "info":"Bu salonda misafir girişi ücretsiz değil. Ücreti kimin ödediği programa göre değişiyor — istek gönderirken tam olarak ne olacağını yazacağız."},
    "guest_none":   {"label":"Bu ilan misafir alamıyor",
                     "info":"Host bu salona girebiliyor ama yanında misafir götürme hakkı yok. Başka bir ilan seçmen daha doğru olur."},
    "unverified":   {"label":"Lounge kuralı doğrulanmadı",
                     "info":"Bu SALONUN misafir kuralını henüz resmî bir kaynaktan doğrulamadık — ilanla ya da host ile ilgili bir sorun DEĞİL. Başvurabilirsin; girişi buluşmadan önce host ile teyit etmen yeterli. Kapıda ne olduğunu bize bildirirsen bir sonraki kullanıcı doğru bilgiyi görür."},
    "guest_free":   {"label":"Misafir ücretsiz",
                     "info":"Host''un hakkı misafiri kapsıyor; kapıda ek ücret çıkmaz."}
  }'::jsonb)
on conflict (key) do update set value = excluded.value;

create or replace function public.badge_text(p_key text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((select value -> p_key from beta_settings where key = 'badge_labels'),
                  jsonb_build_object('label', p_key, 'info', null));
$$;
grant execute on function public.badge_text(text) to authenticated;

-- 🔴 ONCE DUSUR: RETURNS TABLE'a `info` kolonu eklendi, yani DONUS TIPI
-- degisti. PostgreSQL `create or replace` ile dönüş tipini degistirmez:
--   42P13 cannot change return type of existing function
-- 086'da bu adim ayri dosyadaydi ve ATLANDI; dersi almistik ama 102'yi
-- yazarken uygulamadim. Artik ayni dosyanin icinde.
drop function if exists public.discovery_rule_badges(uuid[]);

-- Keşif rozetleri: etiket + açıklama birlikte dönüyor
create or replace function public.discovery_rule_badges(p_ids uuid[])
returns table (
  avail_id uuid, severity text, label text, info text, detail text,
  same_flight_match boolean, sort_boost int
) language plpgsql stable security definer set search_path = public as $$
declare
  r record; d jsonb; b jsonb; v_flight text; v_key text; v_boost int; v_same boolean;
begin
  foreach avail_id in array coalesce(p_ids, '{}'::uuid[]) loop
    select * into r from availabilities where id = avail_id;
    continue when not found;

    select v.flight_number into v_flight from visits v
     where v.user_id = auth.uid() and v.airport_code = r.airport_code
       and v.visit_date = r.avail_date and coalesce(v.flight_number,'') <> ''
     order by v.created_at desc limit 1;

    d := public.lounge_access_decision_v4(avail_id, v_flight);

    v_same := coalesce(v_flight,'') <> '' and coalesce(r.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(r.flight_number,' ',''));

    v_boost := 0;
    if v_same then                                   v_key := 'same_flight'; v_boost := 100;
    elsif (d ->> 'fits') = 'false' then              v_key := 'flight_bad';  v_boost := -100;
    elsif (d ->> 'guest_policy') = 'not_allowed' then v_key := 'guest_none'; v_boost := -200;
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
    sort_boost := v_boost;
    return next;
  end loop;
end $$;
grant execute on function public.discovery_rule_badges(uuid[]) to authenticated;

select public.badge_text('unverified');
select '102 OK - rozet dili duzeltildi, aciklamalar BO''dan yonetiliyor' as sonuc;
