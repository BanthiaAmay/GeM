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

# The bid valuer: once a day at 02:41 (quiet hours, light load on GeM and the
# price sites). Needs its Python packages, Chromium for Playwright, and
# Tesseract OCR for scanned bid documents.
$py = Join-Path $project '.venv\Scripts\python.exe'
& $py -m pip install --quiet -r (Join-Path $project 'scripts\requirements-valuer.txt')
& $py -m playwright install chromium
if (-not (Test-Path 'C:\Program Files\Tesseract-OCR\tesseract.exe')) {
  winget install --id UB-Mannheim.TesseractOCR -e --silent --accept-source-agreements --accept-package-agreements
}
$valuerBat = Join-Path $project 'scripts\windows\run_valuer.bat'
$valuerAction = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$valuerBat`"" -WorkingDirectory $project
$daily = New-ScheduledTaskTrigger -Daily -At '02:41'
$valuerSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit (New-TimeSpan -Hours 4) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -WakeToRun
Register-ScheduledTask -TaskName 'Bid2Scale bid valuer' -Action $valuerAction `
  -Trigger $daily -Settings $valuerSettings -Principal $principal -Force | Out-Null
Write-Host "Installed the bid valuer. It runs daily at 02:41 (or as soon as the PC is on)."
Write-Host "Log: $project\logs\bid-valuer.log"
