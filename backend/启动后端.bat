@echo off
chcp 65001 >nul
title MATCHit 后端启动

echo.
echo ========================================
echo   MATCHit 后端一键启动
echo ========================================
echo.

docker info >nul 2>&1
if errorlevel 1 (
    echo [1/2] 请先打开 Docker Desktop，等左下角变成 Running 后再双击本脚本
    echo.
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe" 2>nul
    if errorlevel 1 start "" "D:\Docker\Docker\Docker Desktop.exe" 2>nul
    echo 已尝试帮你打开 Docker Desktop，请等待约 30 秒~1 分钟后重新双击本脚本
    pause
    exit /b 1
)

echo [1/2] Docker 已就绪
echo [2/2] 启动 Postgres + Redis + API ...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-backend.ps1"

echo.
echo 完成。API 地址: http://localhost:8080/health
echo Flutter 项目在项目根目录执行: flutter run -d chrome
echo.
pause
