# 🚀 Paso 8: Ejecutar el Escaneo Combinado (Bandit + SonarQube)
### Asignatura: Modelos de Evaluación de Software
---
> ⬅️ **Anterior:** `07_INTEGRAR_BANDIT_SONARQUBE.md`
> ➡️ **Siguiente:** `09_INTERPRETAR_RESULTADOS_BANDIT.md`
---
## Objetivo
Ejecutar el flujo completo de SAST (**Bandit + sonar-scanner**) con un **único comando** apoyándote en los scripts que **ya vienen en el repo**:
- [scan.sh](../scan.sh) — para Linux / macOS
- [scan.ps1](../scan.ps1) — para Windows / PowerShell
No necesitas escribirlos: solo entender qué comandos contienen, cómo invocarlos, y qué variables de entorno esperan.
Lo que hacen, en orden:
1. Validan que `SONAR_TOKEN` (y, en cloud, `SONAR_ORG` + `SONAR_PROJECT_KEY`) estén exportadas.
2. Ejecutan Bandit y generan `bandit-report.json`.
3. Ejecutan `sonar-scanner` pasando todas las propiedades por línea de comandos (no dependen de los valores hardcodeados de `sonar-project.properties`).
4. Imprimen la URL del dashboard al terminar.
> 🧭 **Un mismo script sirve para los dos escenarios.** El modo se elige con el 1er argumento (`local` o `cloud`) o con la variable de entorno `SONAR_MODE`. El default es `local`.
---
## 1. Flujo del Escaneo
```
   ┌──────────────────────────────────────────────────────────────┐
   │                    ./scan.sh  (1 comando)                    │
   └──────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
    ┌───────────────────┐            ┌──────────────────┐
    │   1. Bandit       │            │  2. sonar-scanner│
    │   bandit -r .     │            │   lee:           │
    │   → JSON report   │───────────►│   - código .py   │
    │                   │            │   - bandit json  │
    └───────────────────┘            └────────┬─────────┘
                                              │
                                              ▼
                                   ┌──────────────────────┐
                                   │  SonarQube dashboard │
                                   │  http://localhost:9000│
                                   └──────────────────────┘
```
---
## 2. Anatomía de `scan.sh` (Linux / macOS)
El archivo [scan.sh](../scan.sh) ya está en el repo y es ejecutable. Estos son los **bloques relevantes** que conviene entender para usarlo con criterio:
### 2.1 Selección de modo (`local` | `cloud`)
```bash
SONAR_MODE="${1:-${SONAR_MODE:-local}}"
case "${SONAR_MODE}" in
    local)
        PROJECT_KEY="${SONAR_PROJECT_KEY:-vulnerable-api}"
        SONAR_URL="${SONAR_HOST_URL:-http://localhost:9000}"
        ;;
    cloud)
        PROJECT_KEY="${SONAR_PROJECT_KEY:-}"
        SONAR_ORG="${SONAR_ORG:-}"
        SONAR_URL="${SONAR_HOST_URL:-https://sonarcloud.io}"
        ;;
esac
```
- El modo se decide en este orden: **1) argumento posicional**, **2) variable `SONAR_MODE`**, **3) `local` por defecto**.
- En `cloud`, las variables `SONAR_ORG` y `SONAR_PROJECT_KEY` son obligatorias (sin ellas el script aborta).
### 2.2 Ejecución de Bandit
```bash
bandit -r . -c pyproject.toml -f json -o "${REPORT_FILE}" || true
```
- `-r .` recorre el repo completo aplicando las exclusiones de `pyproject.toml`.
- `-f json -o bandit-report.json` produce el formato que SonarQube ingiere.
- El `|| true` evita que el script aborte: Bandit devuelve un código ≠ 0 cuando encuentra hallazgos, lo cual es **el comportamiento esperado** en este repo vulnerable.
### 2.3 Invocación del scanner
```bash
SCANNER_ARGS=(
    -Dsonar.token="${SONAR_TOKEN}"
    -Dsonar.host.url="${SONAR_URL}"
    -Dsonar.projectKey="${PROJECT_KEY}"
)
if [ "${SONAR_MODE}" = "cloud" ]; then
    SCANNER_ARGS+=(-Dsonar.organization="${SONAR_ORG}")
fi
sonar-scanner "${SCANNER_ARGS[@]}"
```
- **Todas las propiedades se pasan por CLI**, así que los valores de `sonar-project.properties` (token hardcodeado, host fijo) **no afectan** lo que termina viéndose en SonarQube/SonarCloud.
- Solo se añade `-Dsonar.organization=...` cuando el modo es `cloud`.
### 2.4 Cómo ejecutarlo
```bash
# Modo local (default):
./scan.sh
./scan.sh local
# Modo SonarCloud:
./scan.sh cloud
# Equivalente vía variable de entorno:
SONAR_MODE=cloud ./scan.sh
```
> 🔑 **Antes de correrlo**, asegúrate de tener las variables del paso 7 exportadas (`SONAR_TOKEN` siempre; `SONAR_ORG` + `SONAR_PROJECT_KEY` solo en `cloud`). Si el archivo no es ejecutable: `chmod +x scan.sh`.
---
## 3. Anatomía de `scan.ps1` (Windows / PowerShell)
El archivo [scan.ps1](../scan.ps1) es el equivalente de PowerShell. Su lógica es idéntica; los bloques importantes son:
### 3.1 Selección de modo y parámetros
```powershell
param([string]$Mode)
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
}
```
### 3.2 Ejecución del scanner
```powershell
$SCANNER_ARGS = @(
    "-Dsonar.token=$env:SONAR_TOKEN"
    "-Dsonar.host.url=$SONAR_URL"
    "-Dsonar.projectKey=$PROJECT_KEY"
)
if ($SONAR_MODE -eq "cloud") { $SCANNER_ARGS += "-Dsonar.organization=$SONAR_ORG" }
& sonar-scanner @SCANNER_ARGS
```
### 3.3 Cómo ejecutarlo
```powershell
# Modo local (default):
.\scan.ps1
.\scan.ps1 local
# Modo SonarCloud:
.\scan.ps1 cloud
# Equivalente vía variable de entorno:
$env:SONAR_MODE = "cloud"; .\scan.ps1
```
> ⚠️ Si PowerShell bloquea la ejecución del script con un error de *Execution Policy*, ejecuta una vez (como administrador):
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```
---
## 4. Recordatorio — Variables de entorno que esperan los scripts
Las variables se definieron en detalle en el [paso 7](07_INTEGRAR_BANDIT_SONARQUBE.md). Aquí va el resumen práctico antes de correr el escaneo:
| Variable | Modo `local` | Modo `cloud` |
|---|---|---|
| `SONAR_TOKEN` | ✅ Obligatoria | ✅ Obligatoria |
| `SONAR_MODE` | opcional (default `local`) | ✅ Recomendada (o pasar `cloud` como argumento) |
| `SONAR_ORG` | — | ✅ Obligatoria |
| `SONAR_PROJECT_KEY` | opcional (default `vulnerable-api`) | ✅ Obligatoria |
| `SONAR_HOST_URL` | opcional (default `http://localhost:9000`) | opcional (default `https://sonarcloud.io`) |
**Ejemplo rápido — alternar entre los dos entornos sin editar archivos:**
```bash
# Linux / macOS — Server local
export SONAR_TOKEN="sqp_<token_local>"
./scan.sh local
# Linux / macOS — SonarCloud
export SONAR_TOKEN="sqp_<token_cloud>"
export SONAR_ORG="tu-org-key"
export SONAR_PROJECT_KEY="tu-org_vulnerable-api"
./scan.sh cloud
```
```powershell
# Windows — Server local
$env:SONAR_TOKEN = "sqp_<token_local>"
.\scan.ps1 local
# Windows — SonarCloud
$env:SONAR_TOKEN       = "sqp_<token_cloud>"
$env:SONAR_ORG         = "tu-org-key"
$env:SONAR_PROJECT_KEY = "tu-org_vulnerable-api"
.\scan.ps1 cloud
```
---
## 5. Salida Esperada
**Salida — modo `local` (Server en Docker):**
```
═══════════════════════════════════════════════════════════
 Modo Sonar: local
 Host:       http://localhost:9000
 ProjectKey: vulnerable-api
═══════════════════════════════════════════════════════════
═══════════════════════════════════════════════════════════
 1/2  Ejecutando Bandit (SAST)...
═══════════════════════════════════════════════════════════
[main]  INFO    using config: pyproject.toml
[main]  INFO    running on Python 3.11.x
[manager]  INFO    found 6 .py files
✅ Bandit completado — 9 hallazgos en bandit-report.json
═══════════════════════════════════════════════════════════
 2/2  Ejecutando sonar-scanner (local)...
═══════════════════════════════════════════════════════════
INFO: SonarScanner 6.x.x
INFO: Analyzing on SonarQube server 10.7
INFO: 6 files indexed
INFO: Sensor Bandit Sensor [python]
INFO: Importing report: bandit-report.json                  ← ✅ ¡Aquí!
INFO: Sensor Bandit Sensor [python] (done) | time=120ms
INFO: ANALYSIS SUCCESSFUL, you can find the results at:
INFO:   http://localhost:9000/dashboard?id=vulnerable-api
═══════════════════════════════════════════════════════════
 ✅ ESCANEO COMBINADO COMPLETADO (local)
═══════════════════════════════════════════════════════════
   Dashboard: http://localhost:9000/dashboard?id=vulnerable-api
   Issues:    http://localhost:9000/project/issues?id=vulnerable-api
```
**Salida — modo `cloud` (SonarCloud):**
```
═══════════════════════════════════════════════════════════
 Modo Sonar: cloud
 Host:       https://sonarcloud.io
 ProjectKey: tu-org_vulnerable-api
 Org:        tu-org-key
═══════════════════════════════════════════════════════════
... (mismas líneas de Bandit y del scanner) ...
INFO: Analyzing on SonarCloud
INFO: Sensor Bandit Sensor [python]
INFO: Importing report: bandit-report.json
INFO: ANALYSIS SUCCESSFUL, you can find the results at:
INFO:   https://sonarcloud.io/dashboard?id=tu-org_vulnerable-api
═══════════════════════════════════════════════════════════
 ✅ ESCANEO COMBINADO COMPLETADO (cloud)
═══════════════════════════════════════════════════════════
   Dashboard: https://sonarcloud.io/dashboard?id=tu-org_vulnerable-api
   Issues:    https://sonarcloud.io/project/issues?id=tu-org_vulnerable-api
```
> 🔎 La línea **`Sensor Bandit Sensor [python]`** en el log es la confirmación de que Sonar (Server local o Cloud) leyó el reporte. Si no aparece, revisa `sonar.python.bandit.reportPaths` en `sonar-project.properties`.
---
## 6. Verificación Rápida en el Dashboard
1. Abre la URL que mostró el script:
   - **Server local:** `http://localhost:9000/dashboard?id=vulnerable-api`
   - **SonarCloud:** `https://sonarcloud.io/dashboard?id=TU_PROJECT_KEY`
2. Compara con la primera corrida (solo Sonar, sin Bandit) — la misma vista que viste en el paso 4 de la guía base (`Sonar_local_or_cloud/.../04_INTERPRETAR_RESULTADOS.md`):
   - **Antes:** 0 vulnerabilidades, varios *Security Hotspots*.
   - **Después:** N vulnerabilidades visibles (las de Bandit, ingeridas como External Issues).
3. Ve a la pestaña **Issues** del proyecto. En el panel izquierdo de filtros (los mismos que describe el paso 4 de la guía base: **Type**, **Severity**, **Status**, **File**, **Rule**), selecciona **`Type` → `Vulnerability`**. La lista central mostrará solo los hallazgos clasificados como vulnerabilidad — entre ellos los nuevos aportados por Bandit. El procedimiento detallado (con la marca *Detected by: bandit* en el panel derecho) está en el paso 09.
   > ⚠️ En **SonarQube Server local (Docker)** el filtro `Rule = external_bandit` no devuelve resultados; usa siempre el filtro de **Type** descrito arriba (idéntico al recomendado en la guía base).
> 📊 Esta comparación **antes/después** es el punto central de la demo: muestra visualmente lo que se gana al complementar Sonar (Community o Cloud free) con un SAST especializado.
---
## 🔧 Solución de Problemas Comunes
| Problema | Causa probable | Solución |
|---|---|---|
| El script falla con `SONAR_TOKEN no está definida` | Olvidaste `export SONAR_TOKEN=...` | Exporta la variable y vuelve a correr |
| `bandit: command not found` durante el script | El `.venv` no está activo en la shell donde corres `./scan.sh` | Activa primero: `source .venv/bin/activate` |
| `sonar-scanner` no muestra `Bandit Sensor` | `sonar.python.bandit.reportPaths` no apunta al archivo correcto | Verifica que `bandit-report.json` está en la raíz junto al `.properties` |
| Hallazgos NO aparecen en el dashboard (Server local) | Análisis aún en cola del servidor | Espera 30 s y refresca; revisa `http://localhost:9000/admin/background_tasks` |
| Hallazgos NO aparecen en el dashboard (SonarCloud) | Procesamiento asíncrono en la nube | Revisa el estado en `https://sonarcloud.io/project/activity?id=<projectKey>` |
| `Connection refused http://localhost:9000` | Contenedor de SonarQube no levantado | `docker compose up -d` y reintenta |
| `You're not authorized to run analysis` (SonarCloud) | Falta `sonar.organization` o el token no pertenece a esa org | Revisa el `.properties` y regenera el token desde la org correcta |
| El script apunta al entorno equivocado | Olvidaste el argumento `local`/`cloud` o `SONAR_MODE` | Invócalo con `./scan.sh cloud` o `SONAR_MODE=cloud ./scan.sh` (ver sección 4) |
| `Permission denied: ./scan.sh` | Falta el bit ejecutable | `chmod +x scan.sh` |
| Script en Windows: `.\scan.ps1 cannot be loaded` | Política de ejecución de PowerShell | `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` |
---
## ✅ Verificación del Paso 8
```
[ ] scan.sh / scan.ps1 visibles en la raíz (vienen ya con el repo); scan.sh con permisos de ejecución
[ ] Variable SONAR_TOKEN exportada en la shell actual (del entorno correcto)
[ ] (Solo cloud) SONAR_ORG y SONAR_PROJECT_KEY exportadas
[ ] El script imprime el bloque "Modo Sonar / Host / ProjectKey" con los valores esperados
[ ] El script corre sin errores hasta "ESCANEO COMBINADO COMPLETADO"
[ ] El log de sonar-scanner muestra la línea "Sensor Bandit Sensor [python]"
[ ] El log muestra "Importing report: bandit-report.json"
[ ] El dashboard correcto (local o cloud) ya muestra vulnerabilidades (no solo hotspots)
```
---
## ➡️ Siguiente Paso
**📄 `09_INTERPRETAR_RESULTADOS_BANDIT.md`** → Cómo leer e interpretar los hallazgos de Bandit dentro del dashboard de SonarQube y comparar antes/después.
---
## 📚 Referencias
- [SonarQube — Background tasks](https://docs.sonarsource.com/sonarqube/latest/instance-administration/background-tasks/)
- [SonarPython — External issues import](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/languages/python/)
- [Bash scripting — set -e](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
