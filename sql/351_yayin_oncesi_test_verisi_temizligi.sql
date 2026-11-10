-- ============================================================================
-- 351 · YAYIN ÖNCESİ TEST VERİSİ TEMİZLİĞİ   (10 Kasım 2026)
--
-- Gökberk (10 Kasım, Apple onayı sonrası): "Yeni kaydolan birisi, benim kendi
-- hesabımdan oluşturduklarım dahil, fake bir data görmemeli."
--
-- SİLİNEN HESAPLAR (hesap + ona bağlı her kayıt + giriş kaydı auth.users):
--   · fikstür: @vitrin.loungelink.test · @seed.loungelink.test · @e2e.test
--   · diğer test alan adları: *.test (ör. @sahne.loungelink.test)
--   · otomatik inceleme robotu hesapları: @example.com
--   · EK_SIL listesindeki açık adresler (TEMIZLIK_ENVANTER 10 Kasım: test@loungelink.com ve
--     Gökberk'in açtığı iki deneme hesabı). Kapalı test kullanıcıları (gmail) LİSTEDE YOK.
--   · Panel yetkisi (admin_roles) olan hesap hiçbir koşulda silinmez, yalnız içeriği temizlenir.
-- KALAN HESAPLAR (hesap durur, İÇERİĞİ silinir: ilan, seyahat, istek, oturum, mesaj,
--   bağlantı, bildirim, puanlama, soru, davet, hikâye):
--   · KORU listesi: gokberkinak95@gmail.com (kurucu), inceleme@loungelink.co (Apple/Google
--     incelemesi; sonraki sürüm incelemelerinde de lazım)
-- DOKUNULMAYAN: yukarıdaki kalıplara uymayan HER hesap (gerçek kullanıcı, kapalı test
--   kullanıcıları). Kalıba uymayan bir hesap asla silinmez.
--
-- Nasıl: `temizlik_derin_sil(tablo, koşul)` yabancı anahtar ağacını katalogdan okur;
-- önce çocuk satırları (her düzeyde), sonra satırın kendisini siler. "…_by / actor"
-- gibi işlem yapanı gösteren boş bırakılabilir kolonlar silinmez, boşaltılır.
-- Yerelde (001..350 + SEED'ler, 62 hesap) denendi; sonuç DEVIR'de.
-- Tekrar koşulabilir. Doğrulama: son sorgu, 5 satır, hepsi tamam = true.
-- Avatar dosyaları (Storage) SQL ile silinmez; sahipsiz dosya kalır, zararsız.
-- ============================================================================

-- 1 · Yardımcı: yabancı anahtar ağacını izleyerek sil
create or replace function public.temizlik_derin_sil(p_tablo regclass, p_kosul text, p_derinlik int default 0)
returns bigint language plpgsql security definer set search_path = public as $tds351$
declare r record; v_n bigint; v_alt text;
begin
  if p_derinlik > 8 then raise exception 'temizlik_derinlik_asildi: %', p_tablo; end if;
  for r in
    select c.conrelid::regclass as cocuk, a.attname::text as kol, af.attname::text as hedef_kol,
           c.confdeltype, not a.attnotnull as bos_olur
      from pg_constraint c
      join pg_attribute a  on a.attrelid  = c.conrelid  and a.attnum  = c.conkey[1]
      join pg_attribute af on af.attrelid = c.confrelid and af.attnum = c.confkey[1]
     where c.contype = 'f' and c.confrelid = p_tablo and array_length(c.conkey, 1) = 1
  loop
    v_alt := format('%I in (select %I from %s where %s)', r.kol, r.hedef_kol, p_tablo, p_kosul);
    if r.confdeltype = 'n' then
      continue;                                             -- Postgres kendisi boşaltır
    elsif r.bos_olur and (r.cocuk = p_tablo
          or r.kol ~ '(_by$|^actor_id$|^karar_veren$|^matched_user_id$|^referred_by$|^cancelled_by$|^no_show_user_id$)') then
      execute format('update %s set %I = null where %s', r.cocuk, r.kol, v_alt);
    elsif r.cocuk = p_tablo then
      raise exception 'temizlik_oz_baglanti: %.%', p_tablo, r.kol;
    else
      perform public.temizlik_derin_sil(r.cocuk, v_alt, p_derinlik + 1);
    end if;
  end loop;
  execute format('delete from %s where %s', p_tablo, p_kosul);
  get diagnostics v_n = row_count;
  return v_n;
end $tds351$;
revoke all on function public.temizlik_derin_sil(regclass, text, int) from public, anon, authenticated;

-- 2 · Hedef listesi (kalıcı tezgah tablosu: Editor her ifadeyi ayrı işlemde koşar)
create schema if not exists tezgah;
create table if not exists tezgah.temizlik_351 (
  user_id uuid primary key, email text, karar text not null, kayit_at timestamptz default now()
);
delete from tezgah.temizlik_351;

insert into tezgah.temizlik_351 (user_id, email, karar)
select u.id, u.email,
       case when lower(u.email) in ('gokberkinak95@gmail.com', 'inceleme@loungelink.co') then 'koru'
            -- panel yetkisi olan hesap ASLA silinmez (auth silinince admin_roles da gider)
            when exists (select 1 from admin_roles ar where ar.user_id = u.id) then 'koru'
            else 'sil' end
  from users u
 where lower(u.email) in ('gokberkinak95@gmail.com', 'inceleme@loungelink.co')
    or u.email like '%.test'
    or u.email like '%@example.com'
    or lower(u.email) in (                       -- EK_SIL: envanter sonucu (10 Kasım, Gökberk)
         'test@loungelink.com',
         'mustafa.emre.alimoglu@gmail.com',      -- Gökberk'in açtığı deneme hesabı
         'gzmdmz@gmail.com'                      -- Gökberk'in açtığı deneme hesabı ("Merve B.")
       );

-- auth'ta olup public.users'ta olmayan test girişleri de
insert into tezgah.temizlik_351 (user_id, email, karar)
select a.id, a.email, 'sil'
  from auth.users a
 where not exists (select 1 from users u where u.id = a.id)
   and (a.email like '%.test' or a.email like '%@example.com' or lower(a.email) in ('test@loungelink.com'))
on conflict (user_id) do nothing;

-- 2b · DIŞARIDAKİ HESAPLARIN KİLİDİ (kapalı test kullanıcıları ve her gerçek hesap)
--  · Listede olmayan her hesabın hesap / içerik sayıları önceden fotoğraflanır; doğrulama
--    aynı sayıları yeniden sayar ve birebir eşit olmasını ister.
--  · Listedeki bir hesapla listede OLMAYAN bir hesap arasında bağ varsa (istek, bağlantı,
--    mesaj, puanlama, davet, engel, soru) silme o bağı da götürürdü: o zaman liste
--    BOŞALTILIR ve hiçbir şey silinmez (aşağıdaki adımlar boş listeyle hiçbir şey yapmaz).
create table if not exists tezgah.temizlik_351_dis (
  ad text primary key, sayi bigint not null, kayit_at timestamptz default now()
);
delete from tezgah.temizlik_351_dis;
insert into tezgah.temizlik_351_dis (ad, sayi)
select 'hesap', count(*) from users u where u.id not in (select user_id from tezgah.temizlik_351)
union all select 'giris', count(*) from auth.users a where a.id not in (select user_id from tezgah.temizlik_351)
union all select 'ilan', count(*) from availabilities a where a.host_id not in (select user_id from tezgah.temizlik_351)
union all select 'seyahat', count(*) from visits v where v.user_id not in (select user_id from tezgah.temizlik_351)
union all select 'kredi_satiri', count(*) from credit_ledger l where l.user_id not in (select user_id from tezgah.temizlik_351)
union all select 'profil', count(*) from profiles p where p.user_id not in (select user_id from tezgah.temizlik_351);

do $s351b$
declare v_bag bigint;
begin
  select
    (select count(*) from requests r
      where (r.guest_id in (select user_id from tezgah.temizlik_351)) <> (r.host_id in (select user_id from tezgah.temizlik_351)))
  + (select count(*) from connection_requests c
      where (c.from_id in (select user_id from tezgah.temizlik_351)) <> (c.to_id in (select user_id from tezgah.temizlik_351)))
  + (select count(*) from ratings x
      where (x.rater_id in (select user_id from tezgah.temizlik_351)) <> (x.rated_id in (select user_id from tezgah.temizlik_351)))
  + (select count(*) from invites i
      where (i.guest_id in (select user_id from tezgah.temizlik_351)) <> (i.host_id in (select user_id from tezgah.temizlik_351)))
  + (select count(*) from blocks b
      where (b.blocker in (select user_id from tezgah.temizlik_351)) <> (b.blocked in (select user_id from tezgah.temizlik_351)))
  + (select count(*) from kural_sorulari k
      where (k.soran_id in (select user_id from tezgah.temizlik_351)) <> (k.host_id in (select user_id from tezgah.temizlik_351)))
    into v_bag;
  if v_bag > 0 then
    delete from tezgah.temizlik_351;
    raise notice '351 DURDU: listedeki hesaplarla listede olmayan hesaplar arasinda % bag var; HICBIR SEY SILINMEDI. Sonucu Claudea ilet.', v_bag;
  else
    raise notice '351: disaridaki hesaplarla bag yok, devam';
  end if;
end $s351b$;

-- 3 · İÇERİK: listedeki HER hesabın (kalan + silinecek) içeriği, iş kuralı sırasıyla
--     (önce istekler, sonra ilan/seyahat: seyahat kapısı başvurusu olan seyahati sildirmez)
do $s351c$
declare v_koru text := 'select user_id from tezgah.temizlik_351';
begin
  perform public.temizlik_derin_sil('public.requests',            format('guest_id in (%s) or host_id in (%s)', v_koru, v_koru));
  perform public.temizlik_derin_sil('public.availabilities',      format('host_id in (%s)', v_koru));
  perform public.temizlik_derin_sil('public.visits',              format('user_id in (%s)', v_koru));
  perform public.temizlik_derin_sil('public.connection_requests', format('from_id in (%s) or to_id in (%s)', v_koru, v_koru));
  perform public.temizlik_derin_sil('public.invites',             format('guest_id in (%s) or host_id in (%s)', v_koru, v_koru));
  perform public.temizlik_derin_sil('public.ratings',             format('rater_id in (%s) or rated_id in (%s)', v_koru, v_koru));
  perform public.temizlik_derin_sil('public.messages',            format('from_id in (%s)', v_koru));
  perform public.temizlik_derin_sil('public.notifications',       format('user_id in (%s)', v_koru));
  perform public.temizlik_derin_sil('public.kural_sorulari',      format('soran_id in (%s) or host_id in (%s)', v_koru, v_koru));
  perform public.temizlik_derin_sil('public.host_stories',        format('user_id in (%s)', v_koru));
  perform public.temizlik_derin_sil('public.blocks',              format('blocker in (%s) or blocked in (%s)', v_koru, v_koru));
  -- Yabancı anahtarı olmayan olay tabloları: panel hunisi test etkinliğiyle şişmesin.
  delete from public.huni_olaylari where user_id in (select user_id from tezgah.temizlik_351);
  delete from public.rc_olaylari   where user_id in (select user_id from tezgah.temizlik_351 where karar = 'sil');
  raise notice '351: listedeki hesaplarin icerigi silindi';
end $s351c$;

-- 4 · Test hesaplarını tamamen sil (önce bizim tablo ağacı, sonra giriş kaydı)
do $s351d$
declare v_n bigint;
begin
  v_n := public.temizlik_derin_sil('public.users',
           'id in (select user_id from tezgah.temizlik_351 where karar = ''sil'')');
  raise notice '351: % test hesabi (public.users) silindi', v_n;
  delete from auth.users where id in (select user_id from tezgah.temizlik_351 where karar = 'sil');
  get diagnostics v_n = row_count;
  raise notice '351: % giris kaydi (auth.users) silindi', v_n;
end $s351d$;

-- 5 · Vitrin tazeleme işi artık gereksiz (350)
do $s351e$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'll-vitrin-tazele') then
      perform cron.unschedule('ll-vitrin-tazele');
    end if;
  end if;
end $s351e$;

-- DOĞRULAMA
select 'test kalibina uyan hesap kalmadi' as kontrol,
       not exists (select 1 from users where email like '%.test' or email like '%@example.com'
                    or lower(email) in ('test@loungelink.com', 'mustafa.emre.alimoglu@gmail.com', 'gzmdmz@gmail.com'))
   and not exists (select 1 from auth.users where email like '%.test' or email like '%@example.com'
                    or lower(email) = 'test@loungelink.com') as tamam
union all
select 'kurucu ve inceleme hesabi duruyor',
       (select count(*) from users where lower(email) in ('gokberkinak95@gmail.com', 'inceleme@loungelink.co')) = 2
union all
select 'kalan hesaplarin ilani / seyahati / istegi yok',
       not exists (select 1 from availabilities a join tezgah.temizlik_351 t on t.user_id = a.host_id)
   and not exists (select 1 from visits v join tezgah.temizlik_351 t on t.user_id = v.user_id)
   and not exists (select 1 from requests r join tezgah.temizlik_351 t on t.user_id in (r.guest_id, r.host_id))
union all
select 'listede olmayan hesaplara dokunulmadi (hesap, giris, ilan, seyahat, kredi, profil ayni)',
       not exists (
         select 1 from tezgah.temizlik_351_dis d
          where d.sayi <> case d.ad
            when 'hesap'        then (select count(*) from users u where u.id not in (select user_id from tezgah.temizlik_351))
            when 'giris'        then (select count(*) from auth.users a where a.id not in (select user_id from tezgah.temizlik_351))
            when 'ilan'         then (select count(*) from availabilities a where a.host_id not in (select user_id from tezgah.temizlik_351))
            when 'seyahat'      then (select count(*) from visits v where v.user_id not in (select user_id from tezgah.temizlik_351))
            when 'kredi_satiri' then (select count(*) from credit_ledger l where l.user_id not in (select user_id from tezgah.temizlik_351))
            when 'profil'       then (select count(*) from profiles p where p.user_id not in (select user_id from tezgah.temizlik_351))
          end)
   and exists (select 1 from tezgah.temizlik_351)
union all
select 'kalan hesap sayisi: ' || (select count(*) from users)::text
       || ' · kalan ilan: ' || (select count(*) from availabilities)::text
       || ' · kalan seyahat: ' || (select count(*) from visits)::text, true;
