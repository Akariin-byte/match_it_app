# 一键：启动后端 + 应用 AppID + 编译微信小程序
$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$MiniRoot = Join-Path $RepoRoot "apps\mini-program"
$HealthUrl = "http://127.0.0.1:8080/health"

function Test-ApiUp {
  try {
    $r = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2
    return $r.status -eq "ok"
  } catch { return $false }
}

Write-Host "`n==> [1/4] 启动后端 API ..." -ForegroundColor Cyan
if (-not (Test-ApiUp)) {
  Start-Process powershell -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $RepoRoot "backend\start-backend-local.ps1")
  ) -WindowStyle Minimized
  $deadline = (Get-Date).AddSeconds(90)
  while ((Get-Date) -lt $deadline) {
    if (Test-ApiUp) { break }
    Start-Sleep -Seconds 2
  }
}
if (Test-ApiUp) {
  Write-Host "    OK  $HealthUrl" -ForegroundColor Green
} else {
  Write-Host "    WARN 后端未就绪，请手动运行: backend\start-backend-local.ps1" -ForegroundColor Yellow
}

Write-Host "`n==> [2/4] 应用微信 AppID（若有 .env.local）..." -ForegroundColor Cyan
Set-Location $MiniRoot
node (Join-Path $MiniRoot "scripts\apply-weixin-appid.mjs")

Write-Host "`n==> [3/4] 生成 Tab 图标 ..." -ForegroundColor Cyan
node (Join-Path $MiniRoot "scripts\gen-tab-icons.mjs")

Write-Host "`n==> [4/4] 编译 mp-weixin（需已安装 Node/npm）..." -ForegroundColor Cyan
$npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npm) { $npm = Get-Command npm -ErrorAction SilentlyContinue }
if ($npm) {
  & $npm.Source run dev:mp-weixin
} else {
  Write-Host "    未找到 npm，请在本机执行: cd apps\mini-program && npm run dev:mp-weixin" -ForegroundColor Yellow
  Write-Host "    然后用微信开发者工具打开: $MiniRoot\dist\dev\mp-weixin" -ForegroundColor Yellow
}
