# 用法: .\scripts\set-weixin-appid.ps1 wx1234567890abcdef
param(
  [Parameter(Mandatory = $true)]
  [string]$AppId
)

$MiniRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $MiniRoot ".env.local"
$lines = @()
if (Test-Path $envFile) {
  $lines = Get-Content $envFile | Where-Object { $_ -notmatch '^\s*VITE_MP_WEIXIN_APPID\s*=' }
}
$lines += "VITE_MP_WEIXIN_APPID=$AppId"
Set-Content -Path $envFile -Value ($lines -join "`n") -Encoding utf8
Write-Host "已写入 $envFile" -ForegroundColor Green
Set-Location $MiniRoot
node (Join-Path $PSScriptRoot "apply-weixin-appid.mjs")
Write-Host "`n请重新编译: npm run dev:mp-weixin" -ForegroundColor Cyan
Write-Host "微信开发者工具重新打开 dist\dev\mp-weixin" -ForegroundColor Cyan
