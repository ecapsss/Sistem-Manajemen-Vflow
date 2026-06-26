@echo off
setlocal

where node >NUL 2>NUL
if errorlevel 1 (
  echo Error: node is required for vflow-admin.bat
  exit /b 1
)

node "%~dp0vflow-admin.js" %*
