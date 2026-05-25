# MATCHit 后端一键启动：Docker Postgres + Go API
#
# 用法:
#   .\start-backend.ps1              # 启动 Postgres + 在新窗口启动 API
#   .\start-backend.ps1 -Foreground  # API 在当前窗口运行（可看日志）
#   .\start-backend.ps1 -SkipDocker  # 只启动 API（Postgres 已在跑）

param(
    [switch]$SkipDocker,
    [switch]$Foreground
)

$ErrorActionPreference = "Continue"
$BackendRoot = $PSScriptRoot
$ApiDir = Join-Path $BackendRoot "api"
$EnvFile = Join-Path $ApiDir ".env"
$HealthUrl = "http://localhost:8080/health"
$PostgresContainer = "matchit-postgres"
$RedisContainer = "matchit-redis"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "    OK  $Message" -ForegroundColor Green
}

function Write-WarnMsg([string]$Message) {
    Write-Host "    !!  $Message" -ForegroundColor Yellow
}

function Write-Err([string]$Message) {
    Write-Host "    ERR $Message" -ForegroundColor Red
}

function Test-DockerReady {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Err "docker not found. Install Docker Desktop first."
        return $false
    }
    docker info 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker is not running. Start Docker Desktop and wait until it is ready."
        return $false
    }
    return $true
}

function Import-DotEnv([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $eq = $line.IndexOf("=")
        if ($eq -lt 1) { return }
        $key = $line.Substring(0, $eq).Trim()
        $val = $line.Substring($eq + 1).Trim()
        if ($val.StartsWith('"') -and $val.EndsWith('"')) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        Set-Item -Path "Env:$key" -Value $val
    }
}

function Test-ApiHealthy {
    try {
        $resp = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 3
        return ($null -ne $resp.status) -and ($resp.status -eq "ok")
    } catch {
        return $false
    }
}

function Wait-RedisHealthy {
    param([int]$TimeoutSec = 60)

    Write-Step "Waiting for Redis ($RedisContainer) ..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)

    while ((Get-Date) -lt $deadline) {
        docker exec $RedisContainer redis-cli ping 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Redis is ready"
            return $true
        }
        Start-Sleep -Seconds 2
    }

    Write-Err "Redis not ready within ${TimeoutSec}s. Run: docker logs $RedisContainer"
    return $false
}

function Wait-PostgresHealthy {
    param([int]$TimeoutSec = 90)

    Write-Step "Waiting for Postgres ($PostgresContainer) ..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)

    while ((Get-Date) -lt $deadline) {
        $exists = docker ps -a --filter "name=^${PostgresContainer}$" --format "{{.Names}}" 2>$null
        if (-not $exists) {
            Start-Sleep -Seconds 2
            continue
        }

        $health = docker inspect --format "{{.State.Health.Status}}" $PostgresContainer 2>$null
        if ($health -eq "healthy") {
            Write-Ok "Postgres is healthy"
            return $true
        }

        $running = docker inspect --format "{{.State.Running}}" $PostgresContainer 2>$null
        if ($running -eq "true" -and [string]::IsNullOrWhiteSpace($health)) {
            docker exec $PostgresContainer pg_isready -U matchit -d matchit 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Postgres is ready (pg_isready)"
                return $true
            }
        }

        Start-Sleep -Seconds 2
    }

    Write-Err "Postgres not ready within ${TimeoutSec}s. Run: docker logs $PostgresContainer"
    return $false
}

function Resolve-ApiCommand {
    $candidates = @(
        (Join-Path $env:GOPATH "bin\matchit-api.exe"),
        "D:\gopath\bin\matchit-api.exe",
        (Join-Path $ApiDir "matchit-api.exe")
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    if ($candidates.Count -gt 0) {
        return @{ Type = "exe"; Path = $candidates[0] }
    }

    if (Get-Command go -ErrorAction SilentlyContinue) {
        return @{ Type = "go"; Path = "go run ." }
    }

    return $null
}

function Start-MatchitApi {
    $cmd = Resolve-ApiCommand
    if (-not $cmd) {
        Write-Err "No matchit-api.exe and no Go. Build with: cd api; go build -o D:\gopath\bin\matchit-api.exe ."
        exit 1
    }

    Import-DotEnv $EnvFile
    if (-not $env:DATABASE_URL) {
        $env:DATABASE_URL = "postgres://matchit:matchit@localhost:5432/matchit?sslmode=disable"
    }
    if (-not $env:PORT) {
        $env:PORT = "8080"
    }

    Write-Step "Starting Go API ..."
    if ($cmd.Type -eq "exe") {
        Write-Ok "Using $($cmd.Path)"
    } else {
        Write-Ok "Using go run . (first run may download modules)"
    }

    if ($Foreground) {
        Push-Location $ApiDir
        try {
            if ($cmd.Type -eq "exe") {
                & $cmd.Path
            } else {
                Invoke-Expression $cmd.Path
            }
        } finally {
            Pop-Location
        }
        return
    }

    $dbUrl = $env:DATABASE_URL
    $port = $env:PORT
    $apiDirEsc = $ApiDir -replace "'", "''"

    if ($cmd.Type -eq "exe") {
        $exeEsc = $cmd.Path -replace "'", "''"
        $command = "Set-Location '$apiDirEsc'; `$env:DATABASE_URL='$dbUrl'; `$env:PORT='$port'; Write-Host 'MATCHit API - Ctrl+C to stop' -ForegroundColor Cyan; & '$exeEsc'"
    } else {
        $command = "Set-Location '$apiDirEsc'; `$env:DATABASE_URL='$dbUrl'; `$env:PORT='$port'; Write-Host 'MATCHit API - Ctrl+C to stop' -ForegroundColor Cyan; go run ."
    }

    Start-Process powershell -ArgumentList @("-NoExit", "-Command", $command) | Out-Null
    Write-Ok "API started in a new PowerShell window"
}

Write-Host ""
Write-Host "MATCHit backend starter" -ForegroundColor White

if (Test-ApiHealthy) {
    Write-Ok "API already running: $HealthUrl"
    try {
        $h = Invoke-RestMethod $HealthUrl -TimeoutSec 3
        Write-Host "    postCount=$($h.postCount)  status=$($h.status)" -ForegroundColor DarkGray
    } catch { }
    Write-WarnMsg "To restart API, stop the process on port 8080 first."
    exit 0
}

if (-not $SkipDocker) {
    if (-not (Test-DockerReady)) { exit 1 }

    Write-Step "docker compose up -d (Postgres + Redis) ..."
    Push-Location $BackendRoot
    try {
        docker compose up -d 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -ne 0) {
            Write-Err "docker compose up failed"
            exit 1
        }
    } finally {
        Pop-Location
    }
    Write-Ok "docker compose up -d done"

    if (-not (Wait-PostgresHealthy)) { exit 1 }
    if (-not (Wait-RedisHealthy)) { exit 1 }
} else {
    Write-WarnMsg "Skipped Docker; assuming Postgres and Redis are already running"
}

Start-MatchitApi

if (-not $Foreground) {
    Write-Step "Waiting for API /health ..."
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        if (Test-ApiHealthy) {
            $h = Invoke-RestMethod $HealthUrl -TimeoutSec 3
            Write-Ok "API ready: $HealthUrl  (postCount=$($h.postCount))"
            Write-Host ""
            Write-Host "Database UI (Adminer): http://localhost:5050" -ForegroundColor DarkGray
            Write-Host "  System=PostgreSQL  Server=postgres  User=matchit  Password=matchit  DB=matchit" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor DarkGray
            Write-Host "  Invoke-RestMethod $HealthUrl"
            Write-Host "  Invoke-RestMethod 'http://localhost:8080/api/v1/posts?area=BoardGames'"
            Write-Host "  Invoke-RestMethod -Method Post http://localhost:8080/api/v1/seed"
            exit 0
        }
        Start-Sleep -Seconds 2
    }
    Write-WarnMsg "API window opened but /health not ready in 30s. Check the API window."
}
