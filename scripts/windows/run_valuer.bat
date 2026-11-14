@echo off
rem One bid-valuer run, started by Windows Task Scheduler once a day:
rem   1. update the code from GitHub (the alerts task does the same);
rem   2. reinstall Python packages only when requirements-valuer.txt changed;
rem   3. value open matched bids closing in the next 10 days.
rem Output is appended to logs\bid-valuer.log (rotated past about 5 MB).
setlocal EnableDelayedExpansion
cd /d "%~dp0..\.."
if not exist logs mkdir logs
set "LOG=logs\bid-valuer.log"
set "PY=.venv\Scripts\python.exe"
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
set GIT_TERMINAL_PROMPT=0
set GCM_INTERACTIVE=never
where git >nul 2>nul || set "PATH=%PATH%;C:\Program Files\Git\cmd"
set "GIT=git -c safe.directory=*"
(
  if exist "%LOG%" for %%F in ("%LOG%") do if %%~zF GTR 5000000 move /y "%LOG%" logs\bid-valuer.old.log >nul
  echo ==== %date% %time% ==== >> "%LOG%"
  set "REQ_OLD="
  for /f %%H in ('git -c safe.directory^=* rev-parse HEAD:scripts/requirements-valuer.txt 2^>nul') do set "REQ_OLD=%%H"
  %GIT% pull --ff-only --quiet >> "%LOG%" 2>&1 || echo Code update skipped; running the code already here. >> "%LOG%"
  set "REQ_NEW="
  for /f %%H in ('git -c safe.directory^=* rev-parse HEAD:scripts/requirements-valuer.txt 2^>nul') do set "REQ_NEW=%%H"
  if not "!REQ_OLD!"=="!REQ_NEW!" (
    echo Python packages changed; installing. >> "%LOG%"
    "%PY%" -m pip install --quiet -r scripts\requirements-valuer.txt >> "%LOG%" 2>&1
    "%PY%" -m playwright install chromium >> "%LOG%" 2>&1
  )
  "%PY%" scripts\bid_valuer\run.py run >> "%LOG%" 2>&1
  exit /b !errorlevel!
)
