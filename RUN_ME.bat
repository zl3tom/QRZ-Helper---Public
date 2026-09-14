@echo off
title QRZ Confirmation Email Helper - Created by ZL3TOM
cd /d "%~dp0"
echo.
echo QRZ Confirmation Email Helper
echo Created by Thomas Bernard - ZL3TOM
echo https://zl3tom.com
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0QRZ_Confirmation_Email_Helper.ps1"
echo.
echo Program closed. If it stopped with an error, check error_log.txt
echo.
pause
