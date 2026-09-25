-- ============================================================
-- LoungeLink · 094_admin_erasure.sql
-- BO'DAN KULLANICI SİLME — AMA "SİLME" DEĞİL, ANONİMLEŞTİRME
--
-- ⚠️ Uygulamayı ETKİLEMEZ (yeni fonksiyonlar, yalnız sunucu çağırır).
--
-- ------------------------------------------------------------
-- 🔴 GOKBERK'İN SORUSU: "BO'da kullanıcı silme özelliği de getirsek mi?"
-- CEVAP: evet, gerekli — ama HARD DELETE olarak DEĞİL.
-- ------------------------------------------------------------
-- Neden `delete from users` yanlış olur:
--
-- 1. VERİ BÜTÜNLÜĞÜ. Kullanıcı 40'a yakın tabloya bağlı: sessions,
--    ratings, credit_ledger, points_ledger, disputes, audit_log...
--    Cascade silersen KARŞI TARAFIN geçmişi de bozulur — silinen host'un
--    misafirinin oturum sayısı ve puanı düşer, güven skoru yeniden
--    hesaplanınca cezalanır. Bir kişinin ayrılması başkasının itibarını
--    eksiltmemeli.
--
-- 2. MUHASEBE VE İTİRAZ. credit_ledger ve points_ledger finansal
--    kayıttır; disputes hukuki. Bunları silmek, sonradan çıkacak bir
--    itirazda elimizde hiçbir şey bırakmaz.
--
-- 3. KVKK ZATEN BUNU İSTEMİYOR. Talep edilen "silme" değil, kişisel
--    verinin İLİŞKİLENDİRİLEMEZ hale getirilmesidir. Anonimleştirme
--    yükümlülüğü karşılar ve 1-2 numarayı da korur.
--
-- 4. GERİ ALINAMAZ. Yanlış satıra basılan bir "sil" düğmesinin dönüşü
--    yoktur. Anonimleştirme de geri alınamaz ama kayıt yerinde kalır,
--    en azından ne olduğu görülür.
--
-- BU YÜZDEN: `admin_anonymize_user()` — kişisel veriyi siler, ilişkileri
-- ve sayıları korur. Ayrıca `deletion_requests` akışıyla (SQL 084)
-- uyumludur: kullanıcının kendi talebi de aynı fonksiyona bağlanır.
-- ============================================================

alter table users add column if not exists anonymized_at timestamptz;
alter table users add column if not exists anonymized_by text;

create or replace function public.admin_anonymize_user(
  p_user_id uuid,
  p_admin   text,
  p_reason  text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_tag text;
begin
  perform 1 from users where id = p_user_id;
  if not found then raise exception 'user_not_found'; end if;
  if (select anonymized_at from users where id = p_user_id) is not null then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  -- Silinen kişiyi arayanların bir şey bulabilmesi için kısa bir etiket.
  -- Ham e-postanın hiçbir izi kalmaz; yalnız "kimdi" değil "kaçıncı"ydı.
  v_tag := 'silinmis-' || left(replace(p_user_id::text, '-', ''), 8);

  -- 1) KİMLİK
  update users
     set email = v_tag || '@silinmis.loungelink',
         phone = null,
         anonymized_at = now(),
         anonymized_by = p_admin
   where id = p_user_id;

  -- 2) PROFİL — serbest metinlerin hepsi kişisel veri taşıyabilir
  update profiles
     set name = 'Silinmiş kullanıcı',
         bio = null, profession = null, photo_url = null,
         linkedin_url = null, linkedin_verified = false,
         access_source = null,
         show_on_discovery = false, profile_visibility = 'Connections',
         updated_at = now()
   where user_id = p_user_id;

  -- 3) DOĞRULAMA İZLERİ
  update verifications
     set phone_verified = false, id_verified = false
   where user_id = p_user_id;

  -- 4) SERBEST METİN İÇEREN KAYITLAR
  -- Mesajlar SİLİNMEZ: karşı tarafın sohbeti delik deşik olur ve bir
  -- itiraz durumunda bağlam kaybolur. İçerik yerine yazarı anonimleşir.
  update reports set description = '[anonimlestirildi]'
   where reporter_id = p_user_id;
  update ratings set comment = null
   where rater_id = p_user_id;
  delete from push_tokens      where user_id = p_user_id;
  delete from otp_tokens       where user_id = p_user_id;
  delete from visits           where user_id = p_user_id and visit_date >= current_date;
  delete from availabilities   where host_id = p_user_id and avail_date >= current_date;
  delete from host_entitlements where user_id = p_user_id;

  -- 5) OTURUMU KAPAT — kullanıcı bir daha giremesin
  delete from auth.sessions  where user_id = p_user_id;
  delete from auth.identities where user_id = p_user_id;
  update auth.users
     set email = v_tag || '@silinmis.loungelink',
         phone = null,
         raw_user_meta_data = '{}'::jsonb,
         banned_until = 'infinity'
   where id = p_user_id;

  -- 🔴 Denetim kaydını BURADA yazmıyoruz. audit_log'un kolonları
  -- (actor_id uuid, entity_type, before_data, after_data) BO'nun audit()
  -- yardımcısıyla yazılıyor; buradan ikinci bir yol açmak iki farklı
  -- şemayla iki farklı kayıt üretirdi. Çağıran BO action'ı audit() çağırır.

  return jsonb_build_object('ok', true, 'tag', v_tag);
end $$;
revoke all on function public.admin_anonymize_user(uuid, text, text) from public, authenticated;
-- 🔴 Yalnız sunucu (service_role). İstemciye açık olsaydı bir kullanıcı
-- başkasının hesabını anonimleştirebilirdi.

-- Anonimleştirilmiş kullanıcı keşifte ve eşleşmede görünmemeli.
-- Fonksiyonlara dokunmuyoruz; görünürlük bayrağı zaten kapatıldı (profiles).
create or replace function public.anonymized_users()
returns table (user_id uuid, tag text, at timestamptz, by_admin text)
language sql stable security definer set search_path = public as $$
  select id, email, anonymized_at, anonymized_by
    from users where anonymized_at is not null
   order by anonymized_at desc;
$$;
grant execute on function public.anonymized_users() to authenticated;

select count(*) as anonimlestirilmis from users where anonymized_at is not null;

select '094 OK - anonimlestirme kuruldu (hard delete YOK, gerekcesi dosyada)' as sonuc;
