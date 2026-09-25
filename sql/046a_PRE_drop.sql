-- ============================================================
-- 046a — 046'DAN ÖNCE ÇALIŞTIR
-- 046 recompute_trust'ın dönüş tipini değiştirmiyor ama
-- host_requests yeni; yine de eski bir sürüm varsa temizle.
-- ============================================================
drop function if exists public.host_requests();
drop function if exists public.host_requests(text);
