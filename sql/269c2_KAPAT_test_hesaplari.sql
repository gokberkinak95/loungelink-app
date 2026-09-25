-- ============================================================================
-- 269c-2 — KAPAT: test hesaplarını Keşfet'ten çıkar   (DEĞİŞİKLİK YAPAR)
--
-- ⚠️ ÖNCE 269c1_BAK_test_hesaplari.sql çalıştır ve şu iki satıra bak:
--      ► KEŞFET'TE GÖRÜNEN SAHTE İLAN
--      ► GERÇEK KULLANICI ↔ TEST HESABI TEMASI
--    İkincisi 0 DEĞİLSE bu dosyayı ÇALIŞTIRMA — önce o taleplere ne
--    olacağına karar ver.
--
-- ----------------------------------------------------------------------------
-- NE YAPAR (ikisi de geri alınabilir)
--   1. `is_staff = true` → Keşfet'ten ve eşleşmeden çıkarlar.
--      Ölçüldü: is_staff=false → 12 ilan görünüyor · is_staff=true → 0.
--   2. auth onayı OLMAYANLARDA `email_verified = false` → ayna yalan
--      söylemeyi bırakır, güven puanı gerçeğe döner.
--
-- ⚠️ HESAP SİLMİYOR. Bu hesapların talepleri ve oturumları başka kayıtlara
-- bağlı; silmek zincirin ortasından halka çıkarmaktır. Görünmez yapmak
-- yeterli ve geri alınabilir. Ne değiştiyse `test_hesabi_kaydi` tablosunda.
--
-- 🆕 SINIF: "GÖRÜNMEZ YAPMAK İLE SİLMEK ARASINDA SEÇİM VARSA, GERİ
-- ALINABİLİR OLANI SEÇ — VERİ SİLMEK BİR KARAR DEĞİL, BİR KAYIPTIR."
--
-- ⚠️ E2E TESTLERİ: `@e2e.test` hesaplarını e2e testlerin CANLIYA bağlanarak
-- kullanıyorsa `is_staff` işareti onları etkileyebilir. Testler yerel
-- fikstür veritabanına bağlanıyorsa sorun yok.
--
-- GERİ ALMAK İSTERSEN:
--   update users u set is_staff = k.eski_staff
--     from test_hesabi_kaydi k where k.user_id = u.id;
-- ============================================================================

begin;

create table if not exists test_hesabi_kaydi (
  user_id     uuid primary key,
  email       text,
  eski_staff  boolean,
  eski_email_dogrulanmis boolean,
  sebep       text not null,
  yapildi_at  timestamptz not null default now()
);

insert into test_hesabi_kaydi (user_id, email, eski_staff, eski_email_dogrulanmis, sebep)
select u.id, u.email, u.is_staff, coalesce(v.email_verified,false),
       '269c: ic test alan adi (.test) — kesiften cikarildi'
  from users u
  left join verifications v on v.user_id = u.id
 where u.deleted_at is null
   and (u.email like '%@vitrin.loungelink.test'
     or u.email like '%@seed.loungelink.test'
     or u.email like '%@e2e.test')
on conflict (user_id) do nothing;

-- 1) Keşiften çıkar
update users u set is_staff = true
  from test_hesabi_kaydi k
 where k.user_id = u.id and not u.is_staff;

-- 2) Ayna yalan söylemeyi bıraksın: auth onayı YOKSA isaret de olmasin
update verifications v
   set email_verified = false, email_verified_at = null
  from test_hesabi_kaydi k
  left join auth.users au on au.id = k.user_id
 where v.user_id = k.user_id
   and coalesce(v.email_verified,false)
   and (au.id is null or au.email_confirmed_at is null);

select public.recompute_trust(user_id) from test_hesabi_kaydi;

-- NÖBETÇİ
do $nb269c$
declare v_gorunen int; v_sahte int;
begin
  select coalesce(sum((select count(*) from public.discover_availabilities() d
                        where d.host_id = k.user_id)), 0)
    into v_gorunen from test_hesabi_kaydi k;
  if v_gorunen > 0 then
    raise exception '269c NOBETCI: test hesaplarinin % ilani HALA Kesfette.', v_gorunen;
  end if;

  select count(*) into v_sahte
    from users u
    left join auth.users au on au.id = u.id
    left join verifications v on v.user_id = u.id
   where u.deleted_at is null and coalesce(v.email_verified,false)
     and (au.id is null or au.email_confirmed_at is null);
  if v_sahte > 0 then
    raise exception '269c NOBETCI: % hesap hala onaysiz oldugu halde dogrulanmis isaretli.', v_sahte;
  end if;

  raise notice '269c NOBETCI OK: test hesaplari Kesfette gorunmuyor, ayna dogru. (% hesap)',
    (select count(*) from test_hesabi_kaydi);
end $nb269c$;

commit;

select k.email as "hesap", k.eski_staff as "önce staff miydi",
       k.eski_email_dogrulanmis as "önce e-posta ✓ miydi",
       t.score as "yeni puan"
  from test_hesabi_kaydi k left join trust_scores t on t.user_id = k.user_id
 order by k.email;

    