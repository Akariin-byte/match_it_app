@echo off
chcp 65001 >nul
title MATCHit 后端（无 Docker）

echo.
echo ========================================
echo   MATCHit 后端 - 不依赖 Docker Desktop
echo   Postgres 装在 D:\Tools\PostgreSQL
echo ========================================
echo.

if not exist "D:\Tools\PostgreSQL\pgsql\bin\pg_ctl.exe" (
    echo [首次使用] 正在安装 D 盘 PostgreSQL，约 300MB...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-local-postgres.ps1"
    if errorlevel 1 (
        echo 安装失败，请检查网络或代理 127.0.0.1:7890
        pause
        exit /b 1
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-backend-local.ps1"

echo.
echo Flutter: cd D:\project1\match_it_app ^&^& flutter run -d chrome
echo.
pause
