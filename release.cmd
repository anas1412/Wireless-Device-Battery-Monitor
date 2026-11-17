@echo off
rem Gets upstream, pushes the fork and publishes the next release. See scripts\release.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release.ps1" %*
pause
