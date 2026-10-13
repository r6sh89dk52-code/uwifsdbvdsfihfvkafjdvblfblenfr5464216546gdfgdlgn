# DANPER Salud Movil - publicar v0.7 en repositorio PRIVADO
# Requiere crear antes el repo privado felipedav29/danper-salud-movil-pruebas
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$repo = 'https://github.com/felipedav29/danper-salud-movil-pruebas.git'
if (!(Test-Path '.\package.json')) { throw 'No aparece package.json. Ejecuta desde el proyecto extraido.' }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Instala Git para Windows primero.' }
function Invoke-Git { & git @args; if ($LASTEXITCODE -ne 0) { throw "Git devolvio error $LASTEXITCODE" } }
if (!(Test-Path '.git')) { Invoke-Git init -b main }
$remote = (& git remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0) { Invoke-Git remote add origin $repo }
elseif ($remote -ne $repo) { throw "Ya hay un remoto distinto: $remote. No se modificara." }
Invoke-Git add --all
$changes = (& git status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'No se pudo revisar cambios.' }
if ($changes) { Invoke-Git commit -m 'DANPER Salud Movil v0.7 - IPA de pruebas' }
Invoke-Git branch -M main
Invoke-Git push -u origin main
Write-Host 'Publicado. Consulta Actions en https://github.com/felipedav29/danper-salud-movil-pruebas/actions'
