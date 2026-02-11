# Godot 无头模式（守护进程）启动脚本，日志输出到文件
# 用法: .\run_server_daemon.ps1  或  pwsh -File run_server_daemon.ps1

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot
$LogDir     = Join-Path $ProjectDir "logs"
$StdoutLog  = Join-Path $LogDir "server_stdout.log"
$StderrLog  = Join-Path $LogDir "server_stderr.log"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# 使用系统 PATH 中的 godot；若用指定路径可改下面变量，例如 "C:\Godot\Godot_v4.x_win64.exe"
$GodotExe = "godot"
$GodotArgs = "--headless --server --path `"$ProjectDir`""

Write-Host "Starting Godot headless server (daemon)..."
Write-Host "  Project: $ProjectDir"
Write-Host "  Stdout:  $StdoutLog"
Write-Host "  Stderr:  $StderrLog"
Write-Host "  Engine file log: %APPDATA%\Godot\app_userdata\yearend\logs\godot.log"
Write-Host ""

# 无窗口启动，标准输出/错误重定向到项目 logs 目录（进程与当前 shell 分离）
$proc = Start-Process -FilePath $GodotExe -ArgumentList "--headless", "--server", "--path", $ProjectDir `
    -RedirectStandardOutput $StdoutLog -RedirectStandardError $StderrLog `
    -WindowStyle Hidden -PassThru

$proc.Id | Set-Content -Path (Join-Path $LogDir "server.pid")
Write-Host "Server started in background. PID: $($proc.Id)"
Write-Host "  Stop: Stop-Process -Id $($proc.Id)"
Write-Host "  Tail log: Get-Content $StdoutLog -Wait"
