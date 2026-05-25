# Start MATCHit backend without Docker (local Postgres on D:)
param([switch]$Foreground)

$ErrorActionPreference = "Continue"
$BackendRoot = $PSScriptRoot
$ApiDir = Join-Path $BackendRoot "api"
$PgBin = "D:\Tools\PostgreSQL\pgsql\bin"
$PgData = "D:\Tools\PostgreSQL\data"
$HealthUrl = "http://localhost:8080/health"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Err($msg) { Write-Host "    ERR $msg" -ForegroundColor Red }

function Test-ApiHealthy {
    try {
        $r = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2
        return $r.status -eq "ok"
    } catch { return $false }
}

if (-not (Test-Path (Join-Path $PgBin "pg_ctl.exe"))) {
    Write-Err "Postgres not found on D:. Run setup-local-postgres.ps1 first."
    exit 1
}

Write-Step "Starting local PostgreSQL on D: ..."
$log = "D:\Tools\PostgreSQL\postgres.log"
& (Join-Path $PgBin "pg_ctl.exe") -D $PgData -l $log status 2>$null
if ($LASTEXITCODE -ne 0) {
    & (Join-Path $PgBin "pg_ctl.exe") -D $PgData -l $log start
    Start-Sleep -Seconds 2
}
Write-Ok "PostgreSQL localhost:5432"

if (Test-ApiHealthy) {
    Write-Ok "API already running: $HealthUrl"
    exit 0
}

$env:DATABASE_URL = "postgres://matchit:matchit@localhost:5432/matchit?sslmode=disable"
$env:JWT_SECRET = "matchit-local-dev-secret"
$env:SMS_MOCK = "true"
$env:PORT = "8080"

$exe = "D:\gopath\bin\matchit-api.exe"
if (-not (Test-Path $exe)) { $exe = Join-Path $ApiDir "matchit-api.exe" }

Write-Step "Starting Go API ..."
if ($Foreground) {
    Push-Location $ApiDir
    if (Test-Path $exe) { & $exe } else { go run . }
    Pop-Location
    exit 0
}

$cmd = @"
Set-Location '$ApiDir'
`$env:DATABASE_URL='postgres://matchit:matchit@localhost:5432/matchit?sslmode=disable'
`$env:JWT_SECRET='matchit-local-dev-secret'
`$env:SMS_MOCK='true'
`$env:PORT='8080'
Write-Host 'MATCHit API (no Docker) - Ctrl+C to stop' -ForegroundColor Cyan
if (Test-Path '$exe') { & '$exe' } else { go run . }
"@
Start-Process powershell -ArgumentList @("-NoExit", "-Command", $cmd) | Out-Null
Write-Ok "API started in a new window"

Start-Sleep -Seconds 4
try {
    Invoke-RestMethod $HealthUrl -TimeoutSec 5 | Out-Null
    Write-Ok "API ready: $HealthUrl"
} catch {
    Write-Host "    !!  API window opened; wait a few seconds if /health is not ready yet" -ForegroundColor Yellow
}
