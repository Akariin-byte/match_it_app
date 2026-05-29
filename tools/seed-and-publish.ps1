$ErrorActionPreference = "Stop"
$base = "http://localhost:8080/api/v1"
$root = Split-Path $PSScriptRoot -Parent

Write-Host "=== Health (before) ==="
curl.exe -s "http://localhost:8080/health"

Write-Host "`n=== Seed ==="
curl.exe -s -X POST "$base/seed"
Write-Host ""

Write-Host "=== Health (after seed) ==="
curl.exe -s "http://localhost:8080/health"
Write-Host ""

$loginFile = Join-Path $PSScriptRoot "api-login.json"
Write-Host "=== Login ==="
$loginResp = curl.exe -s -X POST "$base/auth/login" -H "Content-Type: application/json" --data-binary "@$loginFile"
Write-Host $loginResp
$login = $loginResp | ConvertFrom-Json
$token = $login.token
if (-not $token) { $token = $login.data.token }
if (-not $token) { throw "No token in login response" }

$publishDir = Join-Path $PSScriptRoot "publish-payloads"
$created = 0
Get-ChildItem $publishDir -Filter "*.json" | ForEach-Object {
    Write-Host "=== POST $($_.Name) ==="
    $resp = curl.exe -s -w "`nHTTP:%{http_code}" -X POST "$base/posts" `
        -H "Content-Type: application/json" `
        -H "Authorization: Bearer $token" `
        --data-binary "@$($_.FullName)"
    Write-Host $resp
    if ($resp -match "HTTP:201" -or $resp -match "HTTP:200") { $created++ }
}

Write-Host "`n=== Created $created posts via publish API ==="

$guest = curl.exe -s -X POST "$base/auth/guest-login" -H "Content-Type: application/json" -d "{}"
$gToken = ($guest | ConvertFrom-Json).token
Write-Host "=== Guest feed count ==="
$feed = curl.exe -s "$base/posts" -H "Authorization: Bearer $gToken"
$feedObj = $feed | ConvertFrom-Json
$count = if ($feedObj.data) { $feedObj.data.Count } else { 0 }
Write-Host "posts in feed: $count"
