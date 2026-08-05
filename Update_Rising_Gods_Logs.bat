@echo off
setlocal EnableExtensions

cd /d "%~dp0"
title coolstats Rising Gods Log Updater
color 0B

for /F "delims=" %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "C_RESET=%ESC%[0m"
set "C_DIM=%ESC%[90m"
set "C_BLUE=%ESC%[96m"
set "C_CYAN=%ESC%[36m"
set "C_GREEN=%ESC%[92m"
set "C_YELLOW=%ESC%[93m"
set "C_RED=%ESC%[91m"

echo.
echo %C_BLUE%============================================================%C_RESET%
echo %C_BLUE%                c o o l s t a t s%C_RESET%
echo %C_CYAN%                Rising Gods Logs%C_RESET%
echo %C_BLUE%============================================================%C_RESET%
echo %C_DIM%Windows / PowerShell launcher%C_RESET%
echo.
echo %C_GREEN%Data-only updater for the Rising Gods addon family.%C_RESET%
echo %C_DIM%Target: coolstats_Data_RisingGods plus generated UWU shard folders.%C_RESET%
echo %C_DIM%No admin rights, no credentials, no GitHub publishing.%C_RESET%
echo %C_DIM%Includes duplicate-name safeguards for reused Rising Gods character names.%C_RESET%
echo %C_YELLOW%A confirmation screen will appear before live addon files are replaced.%C_RESET%
echo.
echo %C_BLUE%Preparing updater...%C_RESET%

set "UPDATER_SCRIPT=%~dp0tools\update_rising_gods_live_logs.ps1"
if not exist "%UPDATER_SCRIPT%" set "UPDATER_SCRIPT=%~dp0coolstats_LogUpdater\tools\update_rising_gods_live_logs.ps1"
if not exist "%UPDATER_SCRIPT%" (
	echo.
	echo %C_RED%Update failed. Could not find update_rising_gods_live_logs.ps1.%C_RESET%
	set EXIT_CODE=1
	goto finish
)

if not "%~1"=="" (
	powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER_SCRIPT%" %*
	goto after_update
)

if exist "%~dp0coolstats\coolstats.toc" if exist "%~dp0coolstats_Data_RisingGods\coolstats_Data_RisingGods.toc" if exist "%~dp0coolstats_LogUpdater\tools\update_rising_gods_live_logs.ps1" (
	echo %C_GREEN%Release install detected. The current folder will be used as Interface\AddOns.%C_RESET%
	echo.
	powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER_SCRIPT%"
	goto after_update
)

echo.
echo %C_BLUE%Choose update mode:%C_RESET%
echo   %C_YELLOW%1.%C_RESET% Preview UI and validate current generated data
echo   %C_YELLOW%2.%C_RESET% Update this working folder only, no live WoW install
echo   %C_YELLOW%3.%C_RESET% Update and install to a live WoW Interface\AddOns folder
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
echo %C_RED%Invalid choice. Nothing was changed.%C_RESET%
set EXIT_CODE=1
goto finish

:after_update
set EXIT_CODE=%ERRORLEVEL%

:finish
echo.
if not "%EXIT_CODE%"=="0" (
	echo %C_RED%Update failed. The live addon is left on the last valid installed data when possible.%C_RESET%
) else (
	echo %C_GREEN%Update complete. Reload World of Warcraft if it is currently running.%C_RESET%
)
echo.
pause
exit /b %EXIT_CODE%
