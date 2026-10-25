@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
 echo Instala Node.js 22.12 o posterior y vuelve a abrir este archivo.
 pause
 exit /b 1
)
node -e "const [a,b]=process.versions.node.split('.').map(Number);process.exit(a>22||a===22&&b>=12?0:1)"
if errorlevel 1 (
 echo Se necesita Node.js 22.12 o posterior.
 pause
 exit /b 1
)
if not exist node_modules (
 call npm.cmd ci
 if errorlevel 1 (
  pause
  exit /b 1
 )
)
call npm.cmd run generate
if errorlevel 1 (
 pause
 exit /b 1
)
call npm.cmd run dev -- --open --port 5173 --strictPort
if errorlevel 1 pause
