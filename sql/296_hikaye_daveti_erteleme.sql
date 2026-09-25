-- ════════════════════════════════════════════════════════════════════════
-- 296 · "ŞİMDİ DEĞİL" ARTIK BİR YERE YAZILIYOR
--
-- 🔴 NEDEN VAR — GÖKBERK, 18 EYLÜL, MADDE 14
-- "ağırlaman nasıl geçti alanında gönder ve şimdi değil butonları
--  çalışmıyor."
--
-- ÖLÇÜM — "Şimdi değil" düğmesi (`HikayeDaveti`, ekranlar_yalin.js)
-- yalnızca `setBitti(true)` yapıyordu. Yani:
--   · sunucuya HİÇBİR ŞEY yazılmıyor,
--   · `bekleyen_hikaye_daveti` bir sonraki açılışta AYNI daveti geri
--     döndürüyor,
--   · `onDone` çağrılmadığı için üstteki liste de tazelenmiyor.
-- Kullanıcı sekme değiştirip döndüğünde panel geri geliyor. Ekranda
-- "kapandı", gerçekte hiçbir şey olmadı — kullanıcı bunu haklı olarak
-- "buton çalışmıyor" diye okuyor.
--
-- Kodun kendi belgesi de bunu vaat ediyordu (ekranlar_ana.js):
--   "'Şimdi değil' kalıcıdır: boş metinle kaydedilir, bir daha sorulmaz."
-- Ama `host_hikaye_yaz` boş kayda İZİN VERMİYOR:
--   `if coalesce(btrim(p_gorunen_ad),'') = '' then raise 'display_name_required'`
-- Yani vaat edilen yol SUNUCUDA KAPALIYDI. İstemci de bu yüzden hiç
-- denememiş.
--
-- 🆕 SINIF: "BİR DAVRANIŞI YORUMDA ANLATMAK ONU KURMAZ — VE ANLATILAN
-- YOL SUNUCUDA KAPALIYSA, YORUM BİR BELGE DEĞİL BİR YANLIŞ YÖNLENDİRMEDİR."
--
-- ÜRÜN KARARI — "ŞİMDİ DEĞİL" SİLMEZ, ERTELER.
-- `host_stories`a boş satır yazmak kolay olurdu ama o satır `session_id`
-- üzerinde TEKİL: host üç ay sonra o ağırlamayı yazmak istese yeri dolu
-- olurdu. Ret ile erteleme aynı şey değildir. Ayrı ve küçük bir tablo:
--   · "şimdi değil" → 30 gün boyunca sorulmaz
--   · 30 gün sonra bir kez daha sorulur (aynı ağırlama, yeni bir an)
--   · host yine de yazmak isterse yolu hiç kapanmadı
--
-- Tekrar koşulabilir. 295'ten sonra koşulmalı.
-- ════════════════════════════════════════════════════════════════════════

-- ⚠️ `user_id` `public.users`a bakıyor, `auth.users`a DEĞİL — bu
-- kod tabanındaki diğer kullanıcı tabloları (`host_stories` dahil)
-- öyle. İlk yazımda `auth.users` demiştim ve sınama FK ihlaliyle
-- düştü: tohum dünyasındaki host `public.users`ta var, `auth.users`ta
-- yok. Yeni bir tabloyu farklı bir kullanıcı köküne bağlamak, iki
-- ayrı "kullanıcı" gerçeği yaratmaktır.
create table if not exists public.hikaye_ertelemeleri (
  user_id     uuid not null references public.users(id) on delete cascade,
  session_id  uuid not null references public.sessions(id) on delete cascade,
  ertelendi_at timestamptz not null default now(),
  primary key (user_id, session_id)
);

alter table public.hikaye_ertelemeleri enable row level security;

-- Kendi ertelemesini gören/yazan: yalnız sahibi. Yazma yolu RPC'den
-- geçiyor (security definer) ama okuma doğrudan da olabilsin diye
-- politika açık bırakılıyor.
do $$ begin
  if not exists (select 1 from pg_policies
                  where schemaname='public' and tablename='hikaye_ertelemeleri'
                    and policyname='hikaye_erteleme_kendi') then
    create policy hikaye_erteleme_kendi on public.hikaye_ertelemeleri
      for select using (user_id = auth.uid());
  end if;
end $$;

grant select on public.hikaye_ertelemeleri to authenticated;

-- ── Erteleme RPC'si ─────────────────────────────────────────────────────
create or replace function public.hikaye_davetini_ertele(p_session uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_r   requests%rowtype;
  v_s   sessions%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_s from sessions where id = p_session;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_r from requests where id = v_s.request_id;
  if not found or v_r.host_id <> v_uid then raise exception 'not_host_of_session'; end if;

  insert into public.hikaye_ertelemeleri (user_id, session_id)
  values (v_uid, p_session)
  on conflict (user_id, session_id) do update set ertelendi_at = now();

  return jsonb_build_object('ok', true, 'tekrar_sorulacak', (now() + interval '30 days')::date);
end $function$;

grant execute on function public.hikaye_davetini_ertele(uuid) to authenticated;

-- ── bekleyen_hikaye_daveti: ertelenmişi 30 gün sormaz ───────────────────
create or replace function public.bekleyen_hikaye_daveti()
returns table (session_id uuid, salon text, tarih date, misafir text)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  return query
  select s.id,
         coalesce(a.lounge_name, a.airport_code),
         a.avail_date,
         coalesce(p.name, 'Misafirin')
    from sessions s
    join requests r      on r.id = s.request_id
    left join availabilities a on a.id = r.avail_id
    left join profiles p on p.user_id = r.guest_id
   where s.status = 'completed'
     and r.host_id = v_uid
     and not exists (select 1 from host_stories h where h.session_id = s.id)
     -- 🔴 296 — "Şimdi değil" burada karşılığını buluyor.
     and not exists (
       select 1 from public.hikaye_ertelemeleri e
        where e.session_id = s.id and e.user_id = v_uid
          and e.ertelendi_at > now() - interval '30 days')
   order by s.completed_at desc nulls last
   limit 1;
end $function$;

grant execute on function public.bekleyen_hikaye_daveti() to authenticated;

-- ── Kendi sınaması ──────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════
-- 🔴 21 EYLÜL — BU SINAMA GÖKBERK'İN VERİTABANINDA DÜŞTÜ, ÜRÜN DOĞRUYKEN.
--
--     ERROR:  P0001: 296: 31 gun sonra tekrar sorulmadi (erteleme kalici oldu)
--
-- Yerelde geçiyordu. Sebebini bulup BİREBİR ürettim: `bekleyen_hikaye_daveti()`
-- TEK bir davet döndürür (`order by completed_at desc ... limit 1`) — çünkü
-- ürün aynı anda tek davet gösteriyor. Sınama ise BAŞKA bir `limit 1` ile,
-- SIRASIZ olarak rastgele bir tamamlanmış oturum seçip "fonksiyon TAM BU
-- oturumu döndürecek" diye varsayıyordu.
--
-- Bir host'un birden çok hikâyesiz tamamlanmış oturumu varsa iki `limit 1`
-- FARKLI satırı gösterir ve sınama, ürün kusursuz çalışırken patlar.
-- Ölçtüm: yerelde bir host'ta 3 bekleyen oturum var; sınamayı o host'a
-- sabitleyip en ESKİ oturumu seçtirdiğimde Gökberk'in aldığı hatanın
-- AYNISI çıktı.
--
-- ⚠️ BU SINIF BU PROJEDE İKİNCİ KEZ: SQL 211'in kendi sınama bloğu da
-- sırasız `limit 1` yüzünden bir kez düşmüştü. O zaman "sıra sabitlendi"
-- diye çözülmüştü — yani SEMPTOM düzeltilmiş, SINIF düzeltilmemişti.
-- `order by` eklemek de yetmez: doğru cevap, sınamanın kendi satırını
-- SEÇMEMESİ, FONKSİYONUN DÖNDÜRDÜĞÜ satırı almasıdır. Fonksiyonun sırası
-- yarın değişse bile sınama yine doğru satıra bakar.
--
-- 🆕 SINIF: "BİR FONKSİYONUN DÖNDÜRECEĞİ SATIRI SINAMADA YENİDEN SEÇERSEN,
-- İKİ SEÇİMİN AYNI SATIRA DÜŞTÜĞÜNÜ DE VARSAYMIŞ OLURSUN — SEÇME, SOR."
-- ════════════════════════════════════════════════════════════════════════
do $$
declare v_sid uuid; v_host uuid; v_ikinci uuid; v_sonra int;
begin
  -- Yalnız KİMLİK için bir aday: hangi host'un bekleyen daveti var?
  select r.host_id into v_host
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed'
     and not exists (select 1 from host_stories h where h.session_id = s.id)
   order by r.host_id
   limit 1;
  if v_host is null then raise notice '296 sinama: uygun tamamlanmis oturum yok, atlandi'; return; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_host::text, 'role','authenticated')::text, true);

  -- ⚠️ SATIRI SEÇMİYORUZ, SORUYORUZ. Sınamanın tamamı bu satıra dayanıyor.
  select session_id into v_sid from public.bekleyen_hikaye_daveti();
  if v_sid is null then raise notice '296 sinama: davet zaten gorunmuyor, atlandi'; return; end if;

  perform public.hikaye_davetini_ertele(v_sid);

  -- 1) Ertelenen davet ARTIK SORULMAMALI.
  select count(*) into v_sonra from public.bekleyen_hikaye_daveti()
   where session_id = v_sid;
  if v_sonra <> 0 then
    raise exception '296: ertelenen davet HALA soruluyor';
  end if;

  -- 2) "Şimdi değil" TEK daveti erteler, HEPSİNİ SUSTURMAZ.
  --    (Bu ölçü eskiden yoktu; ürünün asıl vaadi bu ve sınanmıyordu.)
  select session_id into v_ikinci from public.bekleyen_hikaye_daveti();
  if v_ikinci is not null and v_ikinci = v_sid then
    raise exception '296: erteleme sonrasi AYNI davet geri geldi';
  end if;

  -- 3) 30 günden eski bir erteleme TEKRAR sorulabilmeli.
  --    Diğer bekleyenleri de erteleyip alanı boşaltıyoruz ki fonksiyonun
  --    tek satırlık penceresi v_sid'i göstermek zorunda kalsın — yoksa
  --    bu adım yine "hangi satır döndü" kumarına dönerdi.
  insert into public.hikaye_ertelemeleri (session_id, user_id, ertelendi_at)
  select s.id, v_host, now()
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'completed' and r.host_id = v_host and s.id <> v_sid
     and not exists (select 1 from host_stories h where h.session_id = s.id)
  on conflict do nothing;

  update public.hikaye_ertelemeleri set ertelendi_at = now() - interval '31 days'
   where session_id = v_sid and user_id = v_host;

  select count(*) into v_sonra from public.bekleyen_hikaye_daveti()
   where session_id = v_sid;
  if v_sonra = 0 then
    raise exception '296: 31 gun sonra tekrar sorulmadi (erteleme kalici oldu)';
  end if;

  raise notice '296 sinama: erteleme 30 gun tutuyor, tek daveti susturuyor, sonra geri geliyor — OK';
  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
end $$;

select '296 kuruldu' as sonuc;
