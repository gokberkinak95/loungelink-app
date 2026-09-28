# ============================================================================
# LoungeLink - KUR.ps1 (26 Eylul 2026 - app 6.1 turu)
#
# Tek komut:
#   powershell -ExecutionPolicy Bypass -File C:\LoungeLink\KUR.ps1
#
# Secenekler:
#   -SadeceDenetim      build/push yok; yalniz denetimler
#   -Atla bo,site       listedeki bolumleri atla (bo, site, app)
#   -Guncelle           once GitHub'dan son hali cek (git pull) - bulut
#                       oturumunun degisiklikleri boyle gelir
#   -Uygula "mesaj"     BO ve site degisikliklerini commit + push et
#                       (vermezsen commit/push yapilmaz)
#
# KURAL: bu dosya YALNIZ ASCII. PowerShell 5.1 BOM'suz UTF-8'deki tek bir
# Turkce harfi ya da uzun tireyi sozdizimi hatasina cevirir.
# ============================================================================
param(
  [switch]$SadeceDenetim,
  [string]$Atla = "",
  [switch]$Guncelle,
  [string]$Uygula = ""
)

$ErrorActionPreference = "Stop"
$Kok = "C:\LoungeLink"
$atlanan = @()
if ($Atla -ne "") { $atlanan = $Atla.ToLower().Split(",") | ForEach-Object { $_.Trim() } }
$sonuc = @()

function Baslik($t) {
  Write-Host ""
  Write-Host ("=" * 70) -ForegroundColor DarkYellow
  Write-Host $t -ForegroundColor Yellow
  Write-Host ("=" * 70) -ForegroundColor DarkYellow
}

function Kos($klasor, $komut) {
  Write-Host ("> " + $komut) -ForegroundColor Gray
  Push-Location $klasor
  try {
    cmd /c $komut
    if ($LASTEXITCODE -ne 0) { throw ("basarisiz (kod " + $LASTEXITCODE + "): " + $komut) }
  } finally {
    Pop-Location
  }
}

function GitCek($klasor) {
  if (Test-Path (Join-Path $klasor ".git")) {
    Kos $klasor "git pull"
  } else {
    Write-Host ("  (git deposu degil, cekme atlandi: " + $klasor + ")") -ForegroundColor DarkGray
  }
}

function GitGonder($klasor, $mesaj) {
  if (-not (Test-Path (Join-Path $klasor ".git"))) {
    Write-Host ("  (git deposu degil, push atlandi: " + $klasor + ")") -ForegroundColor DarkGray
    return
  }
  Push-Location $klasor
  try {
    $degisen = cmd /c "git status --porcelain"
    if (-not $degisen) {
      Write-Host "  degisiklik yok, commit gerekmiyor" -ForegroundColor DarkGray
      return
    }
  } finally {
    Pop-Location
  }
  Kos $klasor "git add -A"
  Kos $klasor ("git commit -m """ + $mesaj + """")
  Kos $klasor "git push"
}

# ---------------------------------------------------------------- guncelle
if ($Guncelle) {
  Baslik "0 - GitHub'dan son hal"
  GitCek $Kok
  GitCek (Join-Path $Kok "website")
  GitCek (Join-Path $Kok "backoffice")
}

# ---------------------------------------------------------------- BO
if ($atlanan -notcontains "bo") {
  Baslik "1 - Backoffice"
  $bo = Join-Path $Kok "backoffice"
  Kos $bo "npm install"
  Kos $bo "node check.js"
  if (-not $SadeceDenetim) {
    Kos $bo "npm run build"
    if ($Uygula -ne "") { GitGonder $bo ("BO - " + $Uygula) }
  }
  $sonuc += "BO: tamam"
}

# ---------------------------------------------------------------- site
if ($atlanan -notcontains "site") {
  Baslik "2 - Web sitesi"
  $site = Join-Path $Kok "website"
  Kos $site "npm install"
  Kos $site "node verify.js"
  if (-not $SadeceDenetim) {
    Kos $site "npm run build"
    if ($Uygula -ne "") { GitGonder $site ("site - " + $Uygula) }
  }
  $sonuc += "site: tamam"
}

# ---------------------------------------------------------------- app
if ($atlanan -notcontains "app") {
  Baslik "3 - Uygulama"
  $app = Join-Path $Kok "rnapp"
  Kos $app "npm install"
  Kos $app "node check.js"
  if (-not $SadeceDenetim) {
    # preview profili: telefona kurulabilir APK; bitince Expo bir QR ve
    # indirme baglantisi verir (expo.dev > Builds'te de durur).
    Kos $app "npx eas build --platform android --profile preview"
  }
  $sonuc += "app: tamam"
}

Baslik "OZET"
$sonuc | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Green }
$surum = (Get-Content (Join-Path $Kok "rnapp\app.json") -Raw | ConvertFrom-Json).expo.version
Write-Host ("  Telefonda gorunmesi gereken app surumu: " + $surum) -ForegroundColor Green
Write-Host "  Supabase'de calistirilacak SQL listesi: C:\LoungeLink\sql\SQL_SIRA.txt" -ForegroundColor Green
