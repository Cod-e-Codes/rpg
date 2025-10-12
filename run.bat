@echo off
setlocal enabledelayedexpansion
set "LOVE_EXE=C:\Program Files\LOVE\love.exe"
if not exist "%LOVE_EXE%" (
  echo LOVE executable not found at: "%LOVE_EXE%"
  exit /b 1
)
set "GAMEDIR=%~dp0"
pushd "%GAMEDIR%" >nul
start "LOVE" /wait "%LOVE_EXE%" "%GAMEDIR%"
set ERR=%ERRORLEVEL%
popd >nul
exit /b %ERR%
