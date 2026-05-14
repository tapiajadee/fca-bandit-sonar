# ===================================================
# Escaneo combinado: Bandit + SonarQube / SonarCloud
# Asignatura: Modelos de Evaluacion de Software
# ---------------------------------------------------
# Version PowerShell para Windows
#
# Soporta dos modos (ver Docs/Sonar_local_or_cloud/):
#   - local : SonarQube en Docker  (http://localhost:9000)
#   - cloud : SonarCloud           (https://sonarcloud.io)
#
# Seleccion del modo (en este orden de prioridad):
#   1. Primer argumento del script:  .\scan.ps1 local   |   .\scan.ps1 cloud
#   2. Variable de entorno SONAR_MODE
#   3. Valor por defecto: local
#
# Uso:
#   .\scan.ps1 local
#   .\scan.ps1 cloud
#   $env:SONAR_MODE="cloud"; .\scan.ps1
#
# Si PowerShell bloquea la ejecucion del script, ejecuta una vez:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# ===================================================
param(
    [string]$Mode
)
$ErrorActionPreference = "Stop"
$REPORT_FILE = "bandit-report.json"
# ----- Seleccion del modo -----
if ([string]::IsNullOrEmpty($Mode)) {
    if ($env:SONAR_MODE) {
        $SONAR_MODE = $env:SONAR_MODE
    } else {
        $SONAR_MODE = "local"
    }
} else {
    $SONAR_MODE = $Mode
}
switch ($SONAR_MODE) {
    "local" {
        if ($env:SONAR_PROJECT_KEY) { $PROJECT_KEY = $env:SONAR_PROJECT_KEY } else { $PROJECT_KEY = "vulnerable-api" }
        if ($env:SONAR_HOST_URL)    { $SONAR_URL   = $env:SONAR_HOST_URL }    else { $SONAR_URL   = "http://localhost:9000" }
    }
    "cloud" {
        if ($env:SONAR_PROJECT_KEY) { $PROJECT_KEY = $env:SONAR_PROJECT_KEY } else { $PROJECT_KEY = "" }
        if ($env:SONAR_ORG)         { $SONAR_ORG   = $env:SONAR_ORG }         else { $SONAR_ORG   = "" }
        if ($env:SONAR_HOST_URL)    { $SONAR_URL   = $env:SONAR_HOST_URL }    else { $SONAR_URL   = "https://sonarcloud.io" }
    }
    default {
        Write-Host "ERROR: SONAR_MODE='$SONAR_MODE' invalido. Usa 'local' o 'cloud'." -ForegroundColor Red
        Write-Host "   Ejemplos:"
        Write-Host "     .\scan.ps1 local"
        Write-Host "     .\scan.ps1 cloud"
        Write-Host "     `$env:SONAR_MODE='cloud'; .\scan.ps1"
        exit 1
    }
}
# ----- Validaciones previas -----
if ([string]::IsNullOrEmpty($env:SONAR_TOKEN)) {
    Write-Host "ERROR: la variable SONAR_TOKEN no esta definida." -ForegroundColor Red
    Write-Host "   Ejecuta primero: `$env:SONAR_TOKEN='sqp_...'"
    exit 1
}
if ($SONAR_MODE -eq "cloud") {
    if ([string]::IsNullOrEmpty($SONAR_ORG)) {
        Write-Host "ERROR: en modo 'cloud' debes definir SONAR_ORG (Organization Key de SonarCloud)." -ForegroundColor Red
        Write-Host "   Ejecuta: `$env:SONAR_ORG='tu-org-key'"
        exit 1
    }
    if ([string]::IsNullOrEmpty($PROJECT_KEY)) {
        Write-Host "ERROR: en modo 'cloud' debes definir SONAR_PROJECT_KEY (Project Key de SonarCloud)." -ForegroundColor Red
        Write-Host "   Ejecuta: `$env:SONAR_PROJECT_KEY='tu-project-key'"
        exit 1
    }
}
if (-not (Get-Command bandit -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: bandit no esta instalado o el .venv no esta activado." -ForegroundColor Red
    Write-Host "   Ejecuta: .\.venv\Scripts\Activate.ps1 ; pip install -r requirements-dev.txt"
    exit 1
}
if (-not (Get-Command sonar-scanner -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: sonar-scanner no esta en el PATH." -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "==========================================================="
Write-Host " Modo Sonar: $SONAR_MODE"
Write-Host " Host:       $SONAR_URL"
Write-Host " ProjectKey: $PROJECT_KEY"
if ($SONAR_MODE -eq "cloud") {
    Write-Host " Org:        $SONAR_ORG"
}
Write-Host "==========================================================="
# ----- 1. Ejecutar Bandit -----
Write-Host ""
Write-Host "==========================================================="
Write-Host " 1/2  Ejecutando Bandit (SAST)..."
Write-Host "==========================================================="
# Bandit retorna != 0 cuando encuentra issues (esperado en repo vulnerable)
# por eso ignoramos el codigo de salida para no abortar el script
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& bandit -r . -c pyproject.toml -f json -o $REPORT_FILE
$ErrorActionPreference = $prevEAP
if (-not (Test-Path $REPORT_FILE) -or (Get-Item $REPORT_FILE).Length -eq 0) {
    Write-Host "ERROR: $REPORT_FILE no se genero o esta vacio." -ForegroundColor Red
    exit 1
}
$NUM_ISSUES = (Select-String -Path $REPORT_FILE -Pattern '"test_id"' -AllMatches | Measure-Object).Count
Write-Host "Bandit completado - $NUM_ISSUES hallazgos en $REPORT_FILE" -ForegroundColor Green
# ----- 2. Ejecutar sonar-scanner -----
Write-Host ""
Write-Host "==========================================================="
Write-Host " 2/2  Ejecutando sonar-scanner ($SONAR_MODE)..."
Write-Host "==========================================================="
# Pasamos todos los parametros por linea de comandos para no depender
# de los valores que tenga el archivo sonar-project.properties (que en
# este repo esta configurado para 'local'). Equivale a la "Opcion C" de
# la documentacion.
$SCANNER_ARGS = @(
    "-Dsonar.token=$env:SONAR_TOKEN"
    "-Dsonar.host.url=$SONAR_URL"
    "-Dsonar.projectKey=$PROJECT_KEY"
)
if ($SONAR_MODE -eq "cloud") {
    $SCANNER_ARGS += "-Dsonar.organization=$SONAR_ORG"
}
& sonar-scanner @SCANNER_ARGS
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: sonar-scanner fallo con codigo $LASTEXITCODE." -ForegroundColor Red
    exit $LASTEXITCODE
}
# ----- Resumen -----
Write-Host ""
Write-Host "==========================================================="
Write-Host " ESCANEO COMBINADO COMPLETADO ($SONAR_MODE)" -ForegroundColor Green
Write-Host "==========================================================="
Write-Host "   Dashboard: $SONAR_URL/dashboard?id=$PROJECT_KEY"
Write-Host "   Issues:    $SONAR_URL/project/issues?id=$PROJECT_KEY"
Write-Host ""
