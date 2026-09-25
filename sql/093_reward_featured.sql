-- ============================================================
-- LoungeLink · 093_reward_featured.sql
-- MAĞAZADA "ÖNE ÇIKAN ÖDÜL"
--
-- ⚠️ App'i etkiler (v1.93 ile). Yeni NULLABLE-benzeri kolon + varsayılan
-- false, yani eski sürümler aynen çalışmaya devam eder.
--
-- ------------------------------------------------------------
-- NEDEN: Gokberk haklı — ödüller BO'dan yönetiliyorsa, "öne çıkar"
-- da BO'da bir düğme olmalı. Önceki turda bunu "içerik kararı" diye
-- ertelemiştim; oysa asıl eksik olan MEKANİZMAYDI. Karar sende kalır,
-- mekanizma bende — ikisini karıştırmışım.
--
-- Bugün mağazada sekiz ödül kartı EŞİT ağırlıkta duruyor. Eşit ağırlıklı
-- bir liste "hangisi bana göre?" sorusunu kullanıcıya yıkar; kullanıcı da
-- çoğu zaman hiçbirini seçmez. Tek bir kahraman kart, listenin geri kalanını
-- da okunur hale getirir.
--
-- 🔴 TEK KAHRAMAN KURALI VERİTABANINDA: `is_featured` için KISMİ BENZERSİZ
-- indeks var. İki ödül aynı anda öne çıkarılamaz — "kahraman" ancak tek
-- olursa kahramandır. BO ikinci bir kaydı öne çıkarınca öncekini otomatik
-- düşürür; indeks bunu garanti eder, yani BO'da bir hata olsa bile veri
-- tutarsız kalamaz.
-- ============================================================

alter table rewards add column if not exists is_featured boolean not null default false;
alter table rewards add column if not exists featured_note text;

comment on column rewards.is_featured is
  'Magazada kahraman kart olarak gosterilir. Ayni anda YALNIZ BIR odul (kismi benzersiz indeks).';
comment on column rewards.featured_note is
  'Kahraman kartta baslik altinda gorunen tek satir (or. "Bu ay 3 kisiye").';

-- Aynı anda tek kahraman
drop index if exists uq_rewards_featured;
create unique index uq_rewards_featured on rewards ((is_featured)) where is_featured;

-- Pasif bir ödül öne çıkarılamaz: mağazada görünmeyen bir kahraman,
-- boş bir alan bırakır ve neden boş olduğu hiçbir yerde yazmaz.
alter table rewards drop constraint if exists rewards_featured_active_chk;
alter table rewards add constraint rewards_featured_active_chk
  check (not is_featured or coalesce(active, true));

-- BO'nun çağırdığı tek fonksiyon: öncekini düşür, yenisini kaldır.
-- İki ayrı UPDATE yerine tek işlem — arada kalan durumda hiç kahraman
-- olmayan bir mağaza oluşmasın.
create or replace function public.set_featured_reward(p_reward_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_title text; v_active boolean;
begin
  if p_reward_id is null then
    update rewards set is_featured = false where is_featured;
    return jsonb_build_object('ok', true, 'featured', null);
  end if;

  select title, coalesce(active, true) into v_title, v_active
    from rewards where id = p_reward_id;
  if not found then raise exception 'reward_not_found'; end if;
  if not v_active then raise exception 'reward_inactive'; end if;

  update rewards set is_featured = false where is_featured and id <> p_reward_id;
  update rewards set is_featured = true  where id = p_reward_id;
  return jsonb_build_object('ok', true, 'featured', p_reward_id, 'title', v_title);
end $$;
revoke all on function public.set_featured_reward(uuid) from public, authenticated;
-- Yalnız sunucu (BO service_role) çağırır; son kullanıcı mağazayı düzenleyemez.

select id, title, is_featured, active from rewards order by is_featured desc, sort_order limit 10;

select '093 OK - one cikan odul mekanizmasi kuruldu (tek kahraman garantili)' as sonuc;
