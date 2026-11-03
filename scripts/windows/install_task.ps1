# Registers the "Bid2Scale bid alerts" task: every 15 minutes, plus once at
# startup, whether or not anyone is logged in. Run in PowerShell as
# Administrator from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\install_task.ps1
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path "$PSScriptRoot\..\..").Path
$bat = Join-Path $project 'scripts\windows\run_worker.bat'
if (-not (Test-Path (Join-Path $project '.venv\Scripts\python.exe'))) {
  throw "Create the virtual environment first: py -3.12 -m venv .venv"
}
if (-not (Test-Path (Join-Path $project '.env'))) {
  throw "Create the .env file in $project first."
}
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$bat`"" -WorkingDirectory $project
$every15 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
  -RepetitionInterval (New-TimeSpan -Minutes 15)
$atStartup = New-ScheduledTaskTrigger -AtStartup
$atStartup.Delay = 'PT2M'   # let the network come up after a reboot
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 14) -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 5) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -WakeToRun
# SYSTEM runs it with nobody logged in and needs no stored password.
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'Bid2Scale bid alerts' -Action $action `
  -Trigger @($every15, $atStartup) -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "Installed. It runs every 15 minutes and after every restart."
Write-Host "Log: $project\logs\bid-worker.log"
