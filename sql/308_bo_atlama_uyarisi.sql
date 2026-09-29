-- ════════════════════════════════════════════════════════════════════════
-- 308 · BO UYARISI — BİNİŞ KARTI ATLAMA (Gökberk, 29 Eylül)
--
-- 🔴 NEDEN VAR
-- 307 zarafet sınırını koydu (30 günde 2 sessiz atlama; 3.'den itibaren host
-- uyarısı + güven −3). Ama BO bunu GÖRMÜYORDU: aynı kullanıcı her oturumda
-- doğrulamayı atlasa da ekipte kimsenin haberi olmazdı.
-- Gökberk: "2 defa atladığında veya 3. defa atlayacağı zaman BO tarafında
-- bir bildirim/alert".
--
-- KARAR
--   · 30 günde 2 atlama  → seviye 'izle'      (sessiz hak doldu, bir sonraki cezalı)
--   · 30 günde ≥3 atlama → seviye 'mudahale' (kural motorunun verdiği hak aşıldı)
-- BO "Uyarılar" sayfası bu görünümü okur (servis rolü). Görünüm anon ve
-- authenticated'a KAPALI (242'nin kuralı: görünüm arka kapı olmaz).
-- Tekrar koşulabilir. Veri değiştirmez.
-- ════════════════════════════════════════════════════════════════════════

create or replace view public.binis_atlama_uyarilari as
  select sv.user_id,
         coalesce(p.name, 'Yolcu')                                   as ad,
         u.email,
         count(*)::int                                               as atlama_30g,
         max(sv.created_at)                                          as son_atlama,
         case when count(*) >= 3 then 'mudahale' else 'izle' end     as seviye,
         (array_agg(sv.request_id order by sv.created_at desc))[1]   as son_istek,
         coalesce(ts.score, 0)                                       as guven
    from public.session_verifications sv
    join public.users u on u.id = sv.user_id
    left join public.profiles p on p.user_id = sv.user_id
    left join public.trust_scores ts on ts.user_id = sv.user_id
   where sv.method = 'bypass'
     and sv.created_at > now() - interval '30 days'
   group by sv.user_id, p.name, u.email, ts.score
  having count(*) >= 2;

revoke all on public.binis_atlama_uyarilari from public, anon, authenticated;
grant select on public.binis_atlama_uyarilari to service_role;

select '308 kuruldu' as sonuc;
