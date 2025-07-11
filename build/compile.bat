@echo off
echo Setting up RAD Studio environment...
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"

echo Navigating to package directory...
cd /d "%~dp0..\package"

echo Compiling RAD Studio Copilot Extension...
dcc32 -B -Q RADStudioCopilotExtension.dpk

echo Build completed.
pause
