@echo off
rem One bid-alerts run, started by Windows Task Scheduler every 15 minutes:
rem   1. update the code from GitHub, so changes pushed to main reach this PC
rem      on their own. If that fails (offline, local edits) the code already
rem      here still runs and the log says why;
rem   2. reinstall Python packages only when requirements-worker.txt changed;
rem   3. collect bids, send push / email / WhatsApp, and every 3 hours save
rem      new videos from the GeM YouTube channel.
rem Keys come from the .env file in the project folder. Output is appended to
rem logs\bid-worker.log (moved to logs\bid-worker.old.log past about 5 MB).
setlocal EnableDelayedExpansion
cd /d "%~dp0..\.."
if not exist logs mkdir logs
set "LOG=logs\bid-worker.log"
set "PY=.venv\Scripts\python.exe"
rem Logs contain Hindi and other scripts; make Python write UTF-8.
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
rem Never wait for a password prompt that nobody can answer.
set GIT_TERMINAL_PROMPT=0
set GCM_INTERACTIVE=never
where git >nul 2>nul || set "PATH=%PATH%;C:\Program Files\Git\cmd"
rem The task runs as SYSTEM, which does not own this folder; safe.directory
rem lets git work here anyway.
set "GIT=git -c safe.directory=*"
rem Everything below is one block: cmd reads all of it before running any of
rem it, so a git pull that rewrites this file cannot derail the run.
(
  if exist "%LOG%" for %%F in ("%LOG%") do if %%~zF GTR 5000000 move /y "%LOG%" logs\bid-worker.old.log >nul
  echo ==== %date% %time% ==== >> "%LOG%"
  set "REQ_OLD="
  for /f %%H in ('git -c safe.directory^=* rev-parse HEAD:scripts/requirements-worker.txt 2^>nul') do set "REQ_OLD=%%H"
  %GIT% pull --ff-only --quiet >> "%LOG%" 2>&1 || echo Code update skipped; running the code already here. >> "%LOG%"
  set "REQ_NEW="
  for /f %%H in ('git -c safe.directory^=* rev-parse HEAD:scripts/requirements-worker.txt 2^>nul') do set "REQ_NEW=%%H"
  if not "!REQ_OLD!"=="!REQ_NEW!" (
    echo Python packages changed; installing. >> "%LOG%"
    "%PY%" -m pip install --quiet -r scripts\requirements-worker.txt >> "%LOG%" 2>&1
  )
  "%PY%" scripts\bid_worker.py run >> "%LOG%" 2>&1
  exit /b !errorlevel!
)
