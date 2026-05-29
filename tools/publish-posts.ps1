$ErrorActionPreference = "Continue"
$base = "http://localhost:8080/api/v1"
$log = Join-Path $PSScriptRoot "publish-result.txt"
"" | Set-Content $log -Encoding UTF8

function Log($msg) { Add-Content $log $msg -Encoding UTF8; Write-Host $msg }

function Get-Token($json) {
    if ($json -match '"token"\s*:\s*"([^"]+)"') { return $matches[1] }
    return $null
}

Log "=== $(Get-Date -Format o) ==="
Log "Health: $(curl.exe -s http://localhost:8080/health)"
Log "Seed: $(curl.exe -s -X POST $base/seed)"

$guestFile = Join-Path $PSScriptRoot "api-guest.json"
$guestJson = curl.exe -s -X POST "$base/auth/guest-login" -H "Content-Type: application/json" --data-binary "@$guestFile"
Log "Guest: $guestJson"
$guestToken = Get-Token $guestJson

$bindFile = Join-Path $PSScriptRoot "api-bind.json"
$bindJson = curl.exe -s -X POST "$base/auth/bind-phone" `
    -H "Content-Type: application/json" `
    -H "Authorization: Bearer $guestToken" `
    --data-binary "@$bindFile"
Log "Bind: $bindJson"
$token = Get-Token $bindJson

if (-not $token) {
    $regFile = Join-Path $PSScriptRoot "api-register-new.json"
    $regJson = curl.exe -s -X POST "$base/auth/register" -H "Content-Type: application/json" --data-binary "@$regFile"
    Log "Register: $regJson"
    $token = Get-Token $regJson
}

if (-not $token) {
    Log "ERROR: could not obtain registered token"
    exit 1
}

$ok = 0
$publishDir = Join-Path $PSScriptRoot "publish-payloads"
Get-ChildItem $publishDir -Filter "*.json" | Sort-Object Name | ForEach-Object {
    $resp = curl.exe -s -w "`n__HTTP__%{http_code}" -X POST "$base/posts" `
        -H "Content-Type: application/json" `
        -H "Authorization: Bearer $token" `
        --data-binary "@$($_.FullName)"
    Log "`n$($_.Name): $resp"
    if ($resp -match "__HTTP__201" -or $resp -match "__HTTP__200") { $ok++ }
}

Log "`nPublished: $ok / $(@(Get-ChildItem $publishDir -Filter '*.json').Count)"
Log "Health final: $(curl.exe -s http://localhost:8080/health)"

$g2 = curl.exe -s -X POST "$base/auth/guest-login" -H "Content-Type: application/json" --data-binary "@$guestFile"
$gt = Get-Token $g2
$feed = curl.exe -s "$base/posts" -H "Authorization: Bearer $gt"
if ($feed -match '"data"\s*:\s*\[') {
    $count = ([regex]::Matches($feed, '"id"\s*:')).Count
    Log "Feed posts (approx): $count"
}
Log "Done."
