# 在 D 盘安装本地 PostgreSQL（不依赖 Docker）
# 用法: powershell -ExecutionPolicy Bypass -File .\setup-local-postgres.ps1

$ErrorActionPreference = "Stop"
$PgRoot = "D:\Tools\PostgreSQL"
$PgData = Join-Path $PgRoot "data"
$PgBin  = Join-Path $PgRoot "pgsql\bin"
$ZipUrl = "https://get.enterprisedb.com/postgresql/postgresql-16.9-1-windows-x64-binaries.zip"
$ZipPath = "D:\Tools\postgresql-bin.zip"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

if (Test-Path (Join-Path $PgBin "pg_ctl.exe")) {
    Write-Host "本地 Postgres 已存在: $PgBin" -ForegroundColor Green
} else {
    Write-Step "下载 PostgreSQL 到 D 盘（约 300MB，需联网）..."
    New-Item -ItemType Directory -Force -Path "D:\Tools" | Out-Null
    $proxy = "http://127.0.0.1:7890"
    try {
        Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -Proxy $proxy -ProxyUseDefaultCredentials
    } catch {
        Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath
    }
    Write-Step "解压..."
    Expand-Archive -Path $ZipPath -DestinationPath $PgRoot -Force
    Remove-Item $ZipPath -Force
    if (-not (Test-Path (Join-Path $PgBin "pg_ctl.exe"))) {
        throw "解压后未找到 pg_ctl.exe，请检查 $PgRoot"
    }
}

if (-not (Test-Path (Join-Path $PgData "PG_VERSION"))) {
    Write-Step "初始化数据库目录 $PgData ..."
    New-Item -ItemType Directory -Force -Path $PgData | Out-Null
    $pwFile = Join-Path $env:TEMP "matchit-pg-pw.txt"
    Set-Content -Path $pwFile -Value "matchit" -NoNewline
    & (Join-Path $PgBin "initdb.exe") -D $PgData -U matchit --pwfile=$pwFile -A scram-sha-256 -E UTF8 --locale=C
    Remove-Item $pwFile -Force

    $conf = Join-Path $PgData "postgresql.conf"
    Add-Content $conf "`nlisten_addresses = 'localhost'`nport = 5432"

    $hba = Join-Path $PgData "pg_hba.conf"
    Add-Content $hba "`nhost all all 127.0.0.1/32 scram-sha-256`nhost all all ::1/128 scram-sha-256"
}

Write-Step "启动 PostgreSQL..."
$log = Join-Path $PgRoot "postgres.log"
& (Join-Path $PgBin "pg_ctl.exe") -D $PgData -l $log status 2>$null
if ($LASTEXITCODE -ne 0) {
    & (Join-Path $PgBin "pg_ctl.exe") -D $PgData -l $log start
    Start-Sleep -Seconds 3
}

Write-Step "创建 matchit 数据库..."
$env:PGPASSWORD = "matchit"
& (Join-Path $PgBin "psql.exe") -U matchit -h localhost -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='matchit'" |
    ForEach-Object {
        if ($_.Trim() -ne "1") {
            & (Join-Path $PgBin "createdb.exe") -U matchit -h localhost matchit
        }
    }

Write-Host ""
Write-Host "Done. Local Postgres on D: is ready." -ForegroundColor Green
Write-Host "  Bin : $PgBin"
Write-Host "  Data: $PgData"
Write-Host "  URL : postgres://matchit:matchit@localhost:5432/matchit?sslmode=disable"
Write-Host ""
Write-Host "Next: run start-backend-local.ps1 or double-click the no-docker bat file." -ForegroundColor Yellow
