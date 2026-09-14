@echo off
title Reset QRZ Confirmation Email Helper Setup
cd /d "%~dp0"
echo.
echo This removes your saved station/email setup.
echo It does NOT delete sent_history.csv.
echo.
choice /M "Continue"
if errorlevel 2 goto end
if exist "%~dp0helper_config.xml" del "%~dp0helper_config.xml"
echo.
echo Setup removed. RUN_ME.bat will start the setup wizard next time.
:end
echo.
pause
