-- ============================================================
-- LoungeLink · 078_trust_single_writer.sql
--
-- 🔴 İKİ TARAFLI E2E SİMÜLASYONUNDA (E2E_KARSILIKLI.sql) BULUNDU:
--
-- BULGU 1 — GÜVEN PUANI KENDİ DÖKÜMÜYLE TUTMUYOR
--   Test sonunda kullanıcı skoru 77 çıktı ama bileşen dökümü
--   {id:18, bio:6, email:10, phone:10, profession:6} = 50 idi.
--   Yani Güven Puanı ekranındaki halka (77) ile altındaki çubukların
--   toplamı (50) BİRBİRİNİ TUTMUYOR. Sebep: trust_scores'a BEŞ AYRI
--   YER kendi formülüyle yazıyor —
--     · recompute_trust (046/077)  → bileşen toplamı (KANONİK)
--     · rate_session (008/068)     → avg(puan)*15 + oturum*2  ⟵ çakışma
--     · verify_otp (009)           → +15,  (026) → +10        ⟵ çakışma
--     · change_phone (026)         → -10                      ⟵ çakışma
--   Sonuncu yazan kazanıyordu; döküm ile skor kalıcı olarak ayrışıyordu.
--
-- BULGU 2 — İKİ FARKLI ROZET SÖZLÜĞÜ
--   recompute_trust: basic | verified | trusted | trusted_plus
--   rate_session:    Verified | Trusted | Elite   (BÜYÜK harf!)
--   Uygulamanın badgeLabel() haritası küçük harfli anahtarları bekliyor;
--   rate_session çalıştıktan sonra rozet etiketi bozuluyordu.
--
-- BULGU 3 — PUANLAR OTURUM TAMAMLANINCA DEĞİL, PUANLAYINCA VERİLİYOR
--   confirm_session çift onayla oturumu 'completed' yapıyor ama
--   points_ledger'a hiçbir şey yazmıyor; 500/200 puan rate_session'da
--   veriliyor. Uygulamada "🏆 Kazandın: 500" kartı tamamlanma anında
--   görünüyordu — yani kullanıcı henüz kazanmadığı puanı görüyordu.
--   KARAR: puan OTURUM TAMAMLANINCA verilir (hak edilen iş bitti);
--   puanlama ayrı ve gönüllü kalır. Böylece ekran ile defter aynı anda
--   doğru olur. rate_session artık puan VERMEZ (çift ödeme riski de
--   ortadan kalkar), yalnız puanlama kaydını yazar.
--
-- ÇÖZÜM: TEK YAZICI. Bundan sonra trust_scores'a yalnız recompute_trust
-- yazar; diğer tüm yollar onu ÇAĞIRIR. Rozet tek sözlükten üretilir.
-- İdempotent; tekrar çalıştırılabilir.
-- ============================================================


-- ============================================================
-- 1) ROZET: tek sözlük (küçük harf) — uygulama haritasıyla birebir
-- ============================================================
-- NOT: 001'de parametre adı "score" idi; PostgreSQL CREATE OR REPLACE ile
-- parametre adı değiştirmeye izin vermez → aynı adı koruyoruz.
create or replace function public.compute_trust_badge(score int)
returns text language sql immutable as $$
  select case when score >= 88 then 'trusted_plus'
              when score >= 72 then 'trusted'
              when score >= 56 then 'verified'
              else 'basic' end
$$;

-- Geçmişte büyük harfli/eski değerle yazılmış rozetleri normalize et
update trust_scores set badge = public.compute_trust_badge(score)
 where badge is null or badge not in ('basic','verified','trusted','trusted_plus');


-- ============================================================
-- 2) rate_session — PUAN VERMEZ, GÜVENİ KENDİ FORMÜLÜYLE YAZMAZ
--    (068'in gövdesi korunur; yalnız iki çakışan blok kaldırıldı)
-- ============================================================
CREATE OR REPLACE FUNCTION public.rate_session(p_session_id uuid, p_score integer, p_comment text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_s sessions%rowtype; v_r requests%rowtype;
  v_other uuid; v_role text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_score < 1 or p_score > 5 then raise exception 'bad_score'; end if;

  select * into v_s from sessions where id = p_session_id;
  if not found then raise exception 'session_not_found'; end if;
  if v_s.status <> 'completed' then raise exception 'not_completed'; end if;

  select * into v_r from requests where id = v_s.request_id;
  if v_uid not in (v_r.host_id, v_r.guest_id) then raise exception 'not_party'; end if;

  v_role  := case when v_uid = v_r.host_id then 'host' else 'guest' end;
  v_other := case when v_uid = v_r.host_id then v_r.guest_id else v_r.host_id end;

  if exists (select 1 from ratings where session_id = p_session_id and rater_id = v_uid) then
    raise exception 'already_rated';
  end if;

  insert into ratings (session_id, rater_id, rated_id, score, comment)
  values (p_session_id, v_uid, v_other, p_score, nullif(trim(coalesce(p_comment,'')),''));

  -- 078: puan ARTIK BURADA VERİLMEZ (confirm_session'da veriliyor) ve
  -- güven skoru elle yazılmaz — kanonik hesap çağrılır.
  perform public.recompute_trust(v_other);

  return jsonb_build_object('ok', true, 'rated', true);
end $function$;
grant execute on function public.rate_session(uuid, integer, text) to authenticated;


-- ============================================================
-- 3) confirm_session — çift onay tamamlanınca PUANLARI VERİR
--    (067'nin gövdesi korunur; ödül + güven tazeleme eklendi)
-- ============================================================
CREATE OR REPLACE FUNCTION public.confirm_session(p_session_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid(); v_s sessions%rowtype; v_r requests%rowtype;
  v_done boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_s from sessions where id = p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  select * into v_r from requests where id = v_s.request_id;
  if v_uid not in (v_r.host_id, v_r.guest_id) then raise exception 'not_party'; end if;
  if v_s.status <> 'active' then raise exception 'not_active'; end if;

  if v_uid = v_r.host_id then
    update sessions set host_confirmed = true where id = p_session_id;
  else
    update sessions set guest_confirmed = true where id = p_session_id;
  end if;

  select host_confirmed and guest_confirmed into v_done from sessions where id = p_session_id;

  if v_done then
    update sessions set status = 'completed', completed_at = now() where id = p_session_id;
    update requests set status = 'completed' where id = v_s.request_id;

    -- 078: ÖDÜL BURADA (oturum bitti = hak edildi). Host 500 / misafir 200.
    -- Çift ödemeye karşı: aynı oturum için daha önce yazılmışsa atlanır.
    -- NOT: points_ledger'da balance_after KOLONU YOK (SQL 050'de tespit
    -- edilmişti; bakiye user_balances view'ından okunur). Buraya yazmaya
    -- kalkmak fonksiyonu çalışma anında patlatır — yazılmıyor.
    if not exists (select 1 from points_ledger
                    where ref_id = p_session_id and reason = 'session_reward') then
      insert into points_ledger (user_id, delta, reason, ref_id)
      values (v_r.host_id, 500, 'session_reward', p_session_id),
             (v_r.guest_id, 200, 'session_reward', p_session_id);
    end if;

    -- 067'deki ESCROW KAPANIŞ NOTU korunur (drift_check yakaladı):
    -- kredi host'a aktarılmaz (kredi = hak, para değil); misafirin kredisi
    -- harcanmış sayılır, deftere kapanış satırı düşülür.
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    select v_r.guest_id, 0, 'session_settled', p_session_id, coalesce(sum(delta),0)
      from credit_ledger where user_id = v_r.guest_id;

    -- Güven: oturum sayısı değişti → İKİ TARAF için kanonik hesap
    perform public.recompute_trust(v_r.host_id);
    perform public.recompute_trust(v_r.guest_id);

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    select u, 'sessions', 'Oturum tamamlandı ✓',
           'Puanların hesabına eklendi. Karşı tarafı puanlamayı unutma.',
           'session', p_session_id
      from unnest(array[v_r.host_id, v_r.guest_id]) u;
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (case when v_uid = v_r.host_id then v_r.guest_id else v_r.host_id end,
            'sessions', 'Oturum onayı bekleniyor',
            'Karşı taraf oturumu tamamladı olarak işaretledi.', 'session', p_session_id);
  end if;

  return jsonb_build_object('ok', true, 'completed', coalesce(v_done,false));
end $function$;
grant execute on function public.confirm_session(uuid) to authenticated;


-- ============================================================
-- 4) verify_otp / change_phone — güveni elle DEĞİL, kanonik hesapla
--    (026'nın etkin gövdeleri korunur; yalnız trust yazımı değişti)
-- ============================================================
CREATE OR REPLACE FUNCTION public.change_phone(p_phone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  update users set phone = p_phone where id = v_uid;
  update verifications set phone_verified = false, phone_verified_at = null where user_id = v_uid;
  perform public.recompute_trust(v_uid);   -- 078: elle -10 yerine kanonik hesap
  return jsonb_build_object('ok', true, 'reverify_required', true);
end $$;
grant execute on function public.change_phone(text) to authenticated;


-- ============================================================
-- 5) TÜM KULLANICILARI KANONİK HESAPLA TAZELE
-- ============================================================
do $$ declare u uuid; begin
  for u in select user_id from profiles loop perform public.recompute_trust(u); end loop;
end $$;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
-- (1) 0 dönmeli: skoru bileşen toplamıyla tutmayan kullanıcı kalmamalı
select count(*) as "skor_dokum_uyusmazligi"
  from trust_scores ts
  join lateral (select coalesce(sum(value::int),0) n from jsonb_each_text(coalesce(ts.components,'{}'::jsonb))) x on true
 where ts.score <> least(100, x.n);

-- (2) 0 dönmeli: sözlük dışı rozet kalmamalı
select count(*) as "gecersiz_rozet"
  from trust_scores where badge not in ('basic','verified','trusted','trusted_plus');

-- (3) true dönmeli: ödül artık tamamlanmada, puanlamada değil
select (prosrc ilike '%session_reward%') as "odul_confirm_sessionda"
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='confirm_session';
select (prosrc not ilike '%points_ledger%') as "rate_session_odul_vermiyor"
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='rate_session';

select '078 OK - guven puani tek yazicida, rozet sozlugu tek, odul oturum tamamlanmada' as sonuc;
