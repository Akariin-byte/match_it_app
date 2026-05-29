# 修复「simulator not found」：英文路径入口 + 用户数据迁到 D 盘 + 清缓存
# 不往 C 盘重装，不占用额外 C 空间（仅保留指向 D 的目录联接）
$ErrorActionPreference = "Stop"

$DevToolsCn = "D:\微信web开发者工具"
$DevToolsEn = "D:\WeChatDevTools"
$UserDataOnD = "D:\WeChatDevToolsUserData"
$LocalCn = Join-Path $env:LOCALAPPDATA "微信开发者工具"
$Project = "D:\project1\match_it_app\apps\mini-program\dist\dev\mp-weixin"
$Cli = Join-Path $DevToolsEn "cli.bat"

function Stop-DevTools {
  Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
      $_.ProcessName -match 'wechatdevtools|微信|node|wxfilewatcher' -or
      $_.Path -like '*微信web开发者工具*' -or
      $_.Path -like '*WeChatDevTools*'
    } |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}

function Ensure-Junction($Link, $Target) {
  if (Test-Path $Link) {
    $item = Get-Item $Link -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return }
    throw "已存在且不是联接: $Link"
  }
  if (-not (Test-Path $Target)) {
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
  }
  cmd /c "mklink /J `"$Link`" `"$Target`""
}

Write-Host "`n==> 关闭微信开发者工具进程..." -ForegroundColor Cyan
Stop-DevTools

Write-Host "`n==> D 盘英文路径入口: $DevToolsEn" -ForegroundColor Cyan
if (-not (Test-Path $DevToolsEn)) {
  Ensure-Junction $DevToolsEn $DevToolsCn
  Write-Host "    OK 已创建安装目录联接" -ForegroundColor Green
} else {
  Write-Host "    OK 已存在" -ForegroundColor Green
}

Write-Host "`n==> 用户数据迁到 D 盘（释放 C 盘）: $UserDataOnD" -ForegroundColor Cyan
if (Test-Path $LocalCn) {
  $item = Get-Item $LocalCn -Force -ErrorAction SilentlyContinue
  $isLink = $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
  if (-not $isLink) {
    if (Test-Path $UserDataOnD) {
      Remove-Item $UserDataOnD -Recurse -Force
    }
    Move-Item -Path $LocalCn -Destination $UserDataOnD
    Write-Host "    OK 已移动原数据到 D 盘" -ForegroundColor Green
  }
  if (-not (Test-Path $LocalCn)) {
    Ensure-Junction $LocalCn $UserDataOnD
    Write-Host "    OK C 盘仅保留联接（不占双份空间）" -ForegroundColor Green
  }
} else {
  if (-not (Test-Path $UserDataOnD)) {
    New-Item -ItemType Directory -Force -Path (Join-Path $UserDataOnD "User Data") | Out-Null
  }
  Ensure-Junction $LocalCn $UserDataOnD
  Write-Host "    OK 已新建 D 盘用户数据 + C 盘联接" -ForegroundColor Green
}

# 删除可能损坏的 package 缓存，让工具下次启动重新解压
$userDataDir = Join-Path $UserDataOnD "User Data"
if (Test-Path $userDataDir) {
  Get-ChildItem $userDataDir -Directory | ForEach-Object {
    $code = Join-Path $_.FullName "WeappCode"
    if (Test-Path $code) {
      Remove-Item $code -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "    已清理损坏缓存: $($_.Name)\WeappCode" -ForegroundColor Yellow
    }
  }
}

Write-Host "`n==> 清理开发者工具缓存..." -ForegroundColor Cyan
if (Test-Path $Cli) {
  & cmd /c "`"$Cli`" cache --clean all"
  Write-Host "    OK cache cleaned" -ForegroundColor Green
}

Write-Host "`n==> 启动 IDE 并打开小程序项目（关闭 GPU 加速）..." -ForegroundColor Cyan
if (-not (Test-Path $Project)) {
  Write-Host "    WARN 项目目录不存在，请先运行: npm run dev:mp-weixin" -ForegroundColor Yellow
  Write-Host "    $Project" -ForegroundColor Yellow
} elseif (Test-Path $Cli) {
  Start-Process -FilePath "cmd.exe" -ArgumentList @(
    "/c", "`"$Cli`" open --project `"$Project`" --disable-gpu --lang zh"
  ) -WindowStyle Normal
  Write-Host "    OK 已发送打开命令" -ForegroundColor Green
}

Write-Host "`n完成。请使用桌面/开始菜单从以下路径启动工具（推荐）：" -ForegroundColor Cyan
Write-Host "  $DevToolsEn\微信开发者工具.exe" -ForegroundColor White
Write-Host "项目目录: $Project" -ForegroundColor White
