-- ════════════════════════════════════════════════════════════════════════
-- 298 · İSTEMCİNİN TETİKLEDİĞİ SÜPÜRGE FRENLENDİ + SESSİZ SLOT AŞIMI
--        GÖRÜNÜR OLDU
--
-- 🔴 NEDEN VAR — 19 EYLÜL derin denetiminin iki orta seviye bulgusu.
--
-- ── (1) SÜPÜRGE ───────────────────────────────────────────────────────
-- `App.js:330` her açılışta `expire_stale_sessions()` çağırıyor. O
-- fonksiyon GLOBAL: herkesin bayat isteğini iptal ediyor, kredi iadesi
-- yazıyor ve gelmeyen tarafı `no_show` işaretliyor. `authenticated`a açık.
--
-- Zaman kapılı olduğu için kötü niyetli bir çağrı "erken" bir şey
-- yapamıyor — yani veri doğruluğu riski YOK. Riski yazma yükü: bir
-- istemci saniyede onlarca kez çağırırsa her çağrı bütün `requests` ve
-- `sessions` tablosunu tarıyor.
--
-- Doğru mimari bu işi bir ZAMANLANMIŞ İŞE vermek (pg_cron / Supabase
-- scheduled function). Oraya taşımak ayrı bir karar; bu dosya o karara
-- kadar geçerli olan freni koyuyor: gövde global olarak 5 dakikada bir
-- koşar, ara çağrılar hemen ve ucuz döner.
--
-- 🆕 SINIF: "İSTEMCİNİN TETİKLEYEBİLDİĞİ HER GLOBAL YAZMA BİR YÜK
-- ÇARPANIDIR — ZAMAN KAPISI VERİYİ KORUR, SUNUCUYU KORUMAZ."
--
-- ── (2) SESSİZ SLOT AŞIMI ─────────────────────────────────────────────
-- `sync_availability_filled()` sayacı `least(slots, gerçek)` ile
-- KIRPIYOR. Kırpma bilinçli ve doğru: `check (filled <= slots)` kısıtı
-- var ve geçmiş veri onu ihlal ediyordu.
--
-- Ama kırpma bir yan etki üretiyor: `filled > slots` sorgusu ARTIK HİÇ
-- SATIR DÖNDÜRMÜYOR. Yani aşım gerçekleştiğinde hiçbir panel, hiçbir
-- kapı, hiçbir alarm görmüyor. Yerelde ölçtüm — bu satır duruyor:
--
--     availability 306608ce-…  slots=1  filled=1  gerçek kabul: 2
--
-- Host kapıda ikinci misafiri içeri alamaz; misafir kredisini yakmıştır
-- ve kimse bunu bilmez.
--
-- 🆕 SINIF: "BİR SAYACI KIRPARAK KISITI KORUYORSAN, KIRPTIĞIN FARKI
-- BAŞKA BİR YERDE GÖRÜNÜR KILMAK ZORUNDASIN — YOKSA KISIT DEĞİL ALARM
-- SUSTURULMUŞ OLUR."
--
-- Tekrar koşulabilir. 297'den sonra koşulmalı.
-- ════════════════════════════════════════════════════════════════════════

-- ══ 1 · SÜPÜRGE FRENİ ══════════════════════════════════════════════════
-- Fren durumu `beta_settings`te tutuluyor: yeni tablo açmıyorum, çünkü
-- bu bir AYAR değil bir DAMGA ve tek satır. `rate_limits` da olmazdı —
-- o kullanıcı başına, bu global.
create table if not exists public.supurge_damgasi (
  ad          text primary key,
  son_kosum   timestamptz not null default now()
);
alter table public.supurge_damgasi enable row level security;
revoke all on table public.supurge_damgasi from anon, authenticated;

create or replace function public.expire_stale_sessions()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_req int := 0; v_sess int := 0;
  v_son timestamptz;
begin
  -- ── FREN ──────────────────────────────────────────────────────────
  -- `for update` ile alıyoruz: iki istemci aynı anda çağırırsa ikincisi
  -- birincinin damgasını bekler ve "atlandi" döner. Kilitsiz okuma
  -- olsaydı ikisi de aynı eski damgayı görüp ikisi de koşardı — frenin
  -- kendisi bir yarış durumu olurdu.
  select son_kosum into v_son from public.supurge_damgasi
   where ad = 'expire_stale_sessions' for update;

  if v_son is not null and v_son > now() - interval '5 minutes' then
    return jsonb_build_object('ok', true, 'durum', 'atlandi',
                              'sonraki', v_son + interval '5 minutes');
  end if;

  insert into public.supurge_damgasi (ad, son_kosum)
  values ('expire_stale_sessions', now())
  on conflict (ad) do update set son_kosum = now();

  -- ── GÖVDE (değişmedi) ─────────────────────────────────────────────
  -- (a) Hiç başlatılmamış kabuller: kimse gelmedi ya da unutuldu →
  --     cezasız kapanış + kredi iadesi.
  with stale as (
    select r.id, r.guest_id
      from requests r
      join availabilities a on a.id = r.avail_id
      left join sessions s on s.request_id = r.id
     where r.status = 'accepted' and s.id is null
       and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours'
  ), upd as (
    update requests set status = 'cancelled' where id in (select id from stale) returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select u.guest_id, 1, 'expired_refund', u.id,
         coalesce((select sum(delta) from credit_ledger c where c.user_id = u.guest_id), 0) + 1
    from upd u;
  get diagnostics v_req = row_count;

  -- (b) Tek taraf başlatmış ama diğeri hiç gelmemiş → 'expired'.
  update sessions s
     set status = 'expired',
         completed_at = now(),
         cancel_reason = 'no_show',
         no_show_user_id = case when s.host_started_at is null then r.host_id else r.guest_id end
    from requests r, availabilities a
   where r.id = s.request_id and a.id = r.avail_id
     and s.status = 'pending'
     and (s.host_started_at is null) <> (s.guest_started_at is null)
     and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours';
  get diagnostics v_sess = row_count;

  return jsonb_build_object('ok', true, 'durum', 'kosuldu',
                            'iptal_edilen', v_req, 'suresi_dolan', v_sess);
end $function$;

grant execute on function public.expire_stale_sessions() to authenticated;

-- ══ 2 · SLOT AŞIMI DEDEKTÖRÜ ═══════════════════════════════════════════
-- Kırpılan farkı GÖRÜNÜR kılan tek kaynak. BO bunu okuyor (service_role),
-- `verify.js` tarafındaki kapı da sayısına bakabiliyor.
create or replace function public.bo_slot_asimlari()
returns table (
  avail_id     uuid,
  host_id      uuid,
  airport_code text,
  avail_date   date,
  slots        int,
  sayac        int,
  gercek       int,
  asim         int
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select a.id, a.host_id, a.airport_code::text, a.avail_date,
         a.slots::int, a.filled::int, x.gercek::int, (x.gercek - a.slots)::int
    from availabilities a
    join lateral (
      select count(*) as gercek from requests r
       where r.avail_id = a.id and r.status in ('accepted','completed')
    ) x on true
   where x.gercek > a.slots
   order by (x.gercek - a.slots) desc, a.avail_date desc
$function$;

revoke execute on function public.bo_slot_asimlari() from anon, authenticated;
grant execute on function public.bo_slot_asimlari() to service_role;

-- ══ SINAMA ═════════════════════════════════════════════════════════════
do $$
declare v1 jsonb; v2 jsonb; v_asim int;
begin
  -- Damgayı sıfırla ki ilk çağrı gerçekten koşsun.
  delete from public.supurge_damgasi where ad = 'expire_stale_sessions';

  v1 := public.expire_stale_sessions();
  if (v1 ->> 'durum') <> 'kosuldu' then
    raise exception '298: ilk cagri kosmadi (%)', v1;
  end if;

  v2 := public.expire_stale_sessions();
  if (v2 ->> 'durum') <> 'atlandi' then
    raise exception '298: ikinci cagri FRENLENMEDI (%) — supurge hala her cagrida kosuyor', v2;
  end if;

  -- 6 dakika geriye al: fren açılmalı.
  update public.supurge_damgasi set son_kosum = now() - interval '6 minutes'
   where ad = 'expire_stale_sessions';
  v2 := public.expire_stale_sessions();
  if (v2 ->> 'durum') <> 'kosuldu' then
    raise exception '298: fren suresi dolunca kosmadi (%) — supurge kalici kilitlendi', v2;
  end if;

  select count(*) into v_asim from public.bo_slot_asimlari();
  raise notice '298 sinama: fren calisiyor · slot asimi tespit edilen ilan: %', v_asim;
  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
end $$;

select '298 kuruldu' as sonuc;
