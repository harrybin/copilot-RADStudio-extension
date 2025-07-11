@echo off
cd /d "d:\harrybin\copilot-RADStudio-extension\package"
dcc32 -B -Q RADStudioCopilotExtension.dpk
echo Build completed with exit code: %ERRORLEVEL%
pause
