@echo off
rem One bid-alerts run (collect, then push / email / WhatsApp), started by
rem Windows Task Scheduler. Keys come from the .env file in the project folder.
rem Output is appended to logs\bid-worker.log next to the project.
setlocal
cd /d "%~dp0..\.."
if not exist logs mkdir logs
rem Logs contain Hindi and other scripts; make Python write UTF-8.
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
echo ==== %date% %time% ==== >> logs\bid-worker.log
".venv\Scripts\python.exe" scripts\bid_worker.py run >> logs\bid-worker.log 2>&1
endlocal
