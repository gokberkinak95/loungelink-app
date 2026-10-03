# Windows'ta e2e testlerini koşturan sarmalayıcı (test dosyalarına dokunmaz).
# Neden: testler psql'i yalnız {PATH, HOME} ortamıyla çağırıyor (Linux varsayımı). Windows'ta
# SYSTEMROOT olmadan psql ağ katmanını açamıyor ve hata metni cp1254 geldiği için UTF-8 çözümü
# patlıyordu. Burada alt süreçlere tam Windows ortamı + PGCLIENTENCODING=UTF8 verilir.
# Kullanım: python render_check/e2e_win_kos.py render_check/iptal_akisi_e2e.py
import os, runpy, subprocess, sys

_orig = subprocess.run


def _run(*a, **k):
    # Windows psql'i URI'den SONRAKİ seçenekleri yok sayıyor ("extra command-line argument
    # ignored") → sorgular ve migration'lar hiç koşmuyordu. URI'yi `-d` ile başa al.
    if a and isinstance(a[0], (list, tuple)) and a[0] and str(a[0][0]).lower().rstrip(".exe").endswith("psql"):
        cmd = list(a[0])
        uri = next((x for x in cmd[1:] if str(x).startswith("postgres")), None)
        if uri is not None:
            cmd.remove(uri)
            cmd = [cmd[0], "-d", uri] + cmd[1:]
        # Windows komut satırı UTF-8 SQL'i cp1254'e çeviriyor ("—" → 0x97, geçersiz UTF8):
        # ASCII dışı -c argümanları geçici dosyaya yazılıp -f ile verilir (sıra korunur).
        yeni = []
        i = 0
        while i < len(cmd):
            if cmd[i] == "-c" and i + 1 < len(cmd) and any(ord(ch) > 127 for ch in str(cmd[i + 1])):
                import tempfile
                fd, yol = tempfile.mkstemp(suffix=".sql")
                with os.fdopen(fd, "w", encoding="utf-8") as f:
                    f.write(str(cmd[i + 1]))
                yeni += ["-f", yol]
                i += 2
                continue
            yeni.append(cmd[i]); i += 1
        a = (yeni,) + tuple(a[1:])
    if k.get("env") is not None:
        e = dict(os.environ)
        for kk, vv in k["env"].items():
            if kk not in ("PATH", "HOME"):
                e[kk] = vv
        e["PGCLIENTENCODING"] = "UTF8"
        e["LC_MESSAGES"] = "C"
        k["env"] = e
    if k.get("text") or k.get("universal_newlines"):
        k.setdefault("encoding", "utf-8")
        k.setdefault("errors", "replace")
    r = _orig(*a, **k)
    try:
        cmd = a[0] if a else []
        if os.environ.get("E2E_LOG") and ("-f" in cmd or "-c" in cmd) and r.returncode != 0:
            with open(os.environ["E2E_LOG"], "a", encoding="utf-8") as f:
                f.write(str(cmd[(cmd.index("-f") if "-f" in cmd else cmd.index("-c")) + 1])[:120] + " :: " + str(r.stderr)[:600] + chr(10))
    except Exception:
        pass
    return r


subprocess.run = _run
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name="__main__")
