@echo off
setlocal

cd /d "%~dp0"
title coolstats Rising Gods Log Updater

echo.
echo coolstats Rising Gods log updater
echo ---------------------------------
echo Windows / PowerShell launcher
echo This updates only the Rising Gods data addon: coolstats_Data_RisingGods
echo A confirmation screen will appear before any live addon files are replaced.
echo.
echo Preparing updater...

set "UPDATER_SCRIPT=%~dp0tools\update_rising_gods_live_logs.ps1"
if not exist "%UPDATER_SCRIPT%" set "UPDATER_SCRIPT=%~dp0coolstats_LogUpdater\tools\update_rising_gods_live_logs.ps1"
if not exist "%UPDATER_SCRIPT%" (
	echo.
	echo Update failed. Could not find update_rising_gods_live_logs.ps1.
	set EXIT_CODE=1
	goto finish
)

if not "%~1"=="" (
	powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER_SCRIPT%" %*
	goto after_update
)

if exist "%~dp0coolstats\coolstats.toc" if exist "%~dp0coolstats_Data_RisingGods\coolstats_Data_RisingGods.toc" if exist "%~dp0coolstats_LogUpdater\tools\update_rising_gods_live_logs.ps1" (
	echo Release install detected. The current folder will be used as Interface\AddOns.
	echo.
	powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER_SCRIPT%"
	goto after_update
)

echo.
echo Choose update mode:
echo   1. Preview UI and validate current generated data
echo   2. Update this working folder only, no live WoW install
echo   3. Update and install to a live WoW Interface\AddOns folder
echo.
set /p UPDATE_MODE="Type 1, 2, or 3 and press Enter: "

if "%UPDATE_MODE%"=="1" (
	powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER_SCRIPT%" -ValidateOnly
	goto after_update
)

if "%UPDATE_MODE%"=="2" (
	powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER_SCRIPT%" -NoInstall
	goto after_update
)

if "%UPDATE_MODE%"=="3" (
	powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER_SCRIPT%"
	goto after_update
)

echo.
echo Invalid choice. Nothing was changed.
set EXIT_CODE=1
goto finish

:after_update
set EXIT_CODE=%ERRORLEVEL%

:finish
echo.
if not "%EXIT_CODE%"=="0" (
	echo Update failed. The live addon is left on the last valid installed data when possible.
) else (
	echo Update complete. Reload World of Warcraft if it is currently running.
)
echo.
pause
exit /b %EXIT_CODE%
