# 尝试修复 Docker Desktop 打不开（WSL 卡住时）
Write-Host "MATCHit Docker 修复" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. 结束 Docker 进程..." -ForegroundColor Yellow
Get-Process "Docker Desktop","com.docker.backend" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "2. 关闭 WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 3

Write-Host "3. 重启 Docker Desktop..." -ForegroundColor Yellow
$dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerExe) {
    Start-Process $dockerExe
    Write-Host "   已启动，请等待 1~2 分钟看能否变成 Running" -ForegroundColor Green
} else {
    Write-Host "   未找到 Docker Desktop" -ForegroundColor Red
}

Write-Host ""
Write-Host "若仍然打不开，建议改用无 Docker 方案:" -ForegroundColor Cyan
Write-Host "  双击 D:\project1\match_it_app\backend\启动后端-无Docker.bat"
Write-Host ""
