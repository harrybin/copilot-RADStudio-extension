@echo off
echo.
echo =================================================
echo      RAD Studio Copilot Extension Compiler
echo =================================================
echo.
echo This script must be run from a RAD Studio Command Prompt.
echo.

echo Setting up environment...
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"

echo Navigating to package directory...
cd /d "%~dp0..\package"

echo Compiling RAD Studio Copilot Extension...
dcc32 -B -Q RADStudioCopilotExtension.dpk

if errorlevel 1 (
    echo.
    echo =================================================
    echo      BUILD FAILED
    echo =================================================
    echo.
    pause
    exit /b 1
)

echo.
echo =================================================
echo      BUILD SUCCEEDED
echo =================================================
echo.
pause
exit /b 0
