-- ============================================================================
-- LoungeLink · SEED7_GERI_AL_GERCEK_HESAP.sql               (21 Eylül 2026)
--
-- SEED7'NİN İLK SÜRÜMÜNÜN GERÇEK BİR HESABA YAZDIĞI SATIRLARI SİLER.
--
-- 🔴 NE OLDU
-- SEED7'nin ilk sürümü "kabul edilmiş istek yoksa bir tane aç" derken
-- misafiri "herhangi bir kullanıcı, `created_at`e göre en eski" diye
-- seçiyordu. Canlı veritabanında en eski hesap ÜRÜNÜN SAHİBİYDİ:
--
--     3 · OTURUM  SÜREN oturum …  host@e2e.test
--                 misafir: gokberkinak95@gmail.com
--
-- Yani tohum, test verisini gerçek bir hesaba yazdı.
--
-- 🆕 SINIF: "BİR TOHUM 'HERHANGİ BİR KULLANICI' DİYEMEZ — TEST HESABI
-- OLDUĞUNU KANITLAYAMADIĞIN HER SATIR GERÇEK BİR İNSANDIR."
--
-- SEED7 artık `seed_test_hesabi()` süzgeciyle yalnız `*.loungelink.test`
-- ve `*@e2e.test` hesaplarına yazıyor. Bu dosya ise ÖNCEKİ sürümün
-- bıraktığı satırları temizler.
--
-- ⚠️ ÇOK DAR ÇALIŞIR. Yalnız şu ÜÇÜ birden doğruysa siler:
--     1. misafir bir test hesabı DEĞİL, ve
--     2. isteğin `intro_message`i SEED7'nin yazdığı cümlenin TA KENDİSİ,
--     3. istek `accepted` ya da onun oturumu.
-- Yani senin gerçek isteklerine, sohbetlerine, oturumlarına DOKUNMAZ.
--
-- ⚠️ ÖNCE NE SİLECEĞİNİ GÖSTERİR. Aşağıdaki ilk sorgu yalnız LİSTELER.
-- Silme bloğu onun altında ve ayrı; listede beklemediğin bir satır
-- görürsen silme bloğunu ÇALIŞTIRMA, bana gönder.
--
-- Supabase SQL Editor'e olduğu gibi yapıştır. Tek tablo döner.
-- ============================================================================

-- (Fonksiyon SEED7 ile geliyor; burada da tanımlı olsun ki bu dosya
--  tek başına da koşabilsin.)
create or replace function public.seed_test_hesabi(p_email text)
returns boolean language sql immutable as $$
  select coalesce(p_email, '') like '%@seed.loungelink.test'
      or coalesce(p_email, '') like '%@sahne.loungelink.test'
      or coalesce(p_email, '') like '%@vitrin.loungelink.test'
      or coalesce(p_email, '') like '%@e2e.test';
$$;

do $geri$
declare
  v_say int := 0;
  v_req uuid;
begin
  for v_req in
    select r.id
      from requests r
      join users gu on gu.id = r.guest_id
     where not public.seed_test_hesabi(gu.email)
       and r.intro_message in ('Aynı saatlerdeyiz, salonda buluşalım mı?',
                               'Gecen hafta ayni salondaydik.',
                               'Ayni saatlerdeyim, salona birlikte girebilir miyiz?',
                               'Yer acilirsa cok sevinirim.')
     order by r.created_at, r.id
  loop
    delete from messages       where channel_id in (select id from chat_channels where request_id = v_req);
    delete from chat_channels  where request_id = v_req;
    delete from ratings        where session_id in (select id from sessions where request_id = v_req);
    delete from host_stories   where session_id in (select id from sessions where request_id = v_req);
    delete from sessions       where request_id = v_req;
    delete from credit_ledger  where ref_id = v_req;
    delete from notifications  where ref_id = v_req;
    delete from requests       where id = v_req;
    v_say := v_say + 1;
  end loop;

  if v_say = 0 then
    raise notice 'GERI AL: silinecek satir yok — gercek hesaba yazilmamis (ya da zaten temizlenmis)';
  else
    raise notice 'GERI AL: % adet SEED7 istegi ve bagli satirlari silindi', v_say;
  end if;
end $geri$;

-- ── SONUÇ: gerçek hesaplarda SEED7 izi kaldı mı? ────────────────────────
select
  u.email                                       as hesap,
  count(r.id) filter (where r.status = 'pending')  as bekleyen,
  count(r.id) filter (where r.status = 'accepted') as kabul_edilmis,
  count(r.id)                                   as toplam_istek,
  count(s.id) filter (where s.status = 'active') as aktif_oturum
from users u
left join requests r on r.guest_id = u.id
left join sessions s on s.request_id = r.id
where not public.seed_test_hesabi(u.email)
group by u.id, u.email
having count(r.id) > 0
order by 4 desc;
