# 🔗 Paso 7: Integrar Bandit con SonarQube
### Asignatura: Modelos de Evaluación de Software
---
> ⬅️ **Anterior:** `06_CONFIGURAR_BANDIT.md`
> ➡️ **Siguiente:** `08_EJECUTAR_ESCANEO_COMBINADO.md`
---
## Objetivo
Hacer que **Sonar ingiera el reporte JSON de Bandit** y muestre sus hallazgos como *External Issues* directamente en el dashboard del proyecto. Así obtienes una sola vista unificada con:
- Las métricas de Sonar (bugs, code smells, duplicación, cobertura).
- **Las vulnerabilidades reales que Sonar Community / SonarCloud free no detectan** (SQLi, SSTI, XSS, etc.), aportadas por Bandit.
> 💡 Tanto **SonarQube Server** como **SonarCloud** tienen **soporte nativo** para Bandit a través de la propiedad `sonar.python.bandit.reportPaths`. No necesitas plugins adicionales — viene de fábrica con el analizador `SonarPython`.
>
> 🧭 **Este paso cubre los dos escenarios.** Verás bloques marcados como **Opción A — Server local (Docker)** y **Opción B — SonarCloud**. Sigue solo el que aplique a tu entorno.
---
## 1. Cómo Funciona la Integración
```
   ┌──────────┐        ┌──────────────────┐        ┌────────────────┐
   │  Bandit  │──────► │ bandit-report.   │──────► │ sonar-scanner  │
   │  (SAST)  │        │ json             │  lee   │                │
   └──────────┘        └──────────────────┘        └────────┬───────┘
                                                            │
                                                            ▼
                                                  ┌────────────────────┐
                                                  │   SonarQube UI     │
                                                  │                    │
                                                  │  Issues → External │
                                                  │  ▸ B608 SQLi       │
                                                  │  ▸ B201 Flask debug│
                                                  │  ▸ B701 SSTI       │
                                                  │  ...               │
                                                  └────────────────────┘
```
**Mapeo automático de severidades:**
| Bandit severity | SonarQube severity | SonarQube type |
|---|---|---|
| HIGH    | CRITICAL  | Vulnerability |
| MEDIUM  | MAJOR     | Vulnerability |
| LOW     | MINOR     | Code Smell    |
---
## 2. Generar el Reporte JSON de Bandit
A diferencia del HTML del paso anterior, ahora generamos el formato que SonarQube entiende:
```bash
# Linux / macOS / Windows
bandit -r . -c pyproject.toml -f json -o bandit-report.json
```
> ⚠️ **Importante:** Bandit retorna **código de salida ≠ 0** cuando encuentra hallazgos. Esto es **el comportamiento esperado** en un proyecto vulnerable. En el siguiente paso (script `scan.sh`) lo manejaremos con `|| true` para no abortar el pipeline.
**Verifica que el archivo se generó:**
```bash
# Linux / macOS
ls -lh bandit-report.json
head -50 bandit-report.json
# Windows
Get-Item bandit-report.json
Get-Content bandit-report.json -Head 50
```
Verás una estructura JSON parecida a:
```json
{
  "errors": [],
  "generated_at": "2026-05-06T...",
  "metrics": {
    "_totals": {
      "SEVERITY.HIGH": 2,
      "SEVERITY.MEDIUM": 3,
      "SEVERITY.LOW": 4
    }
  },
  "results": [
    {
      "code": "16  cur.execute(f\"SELECT * FROM USERS WHERE USERNAME='{username}'\")\n",
      "col_offset": 8,
      "filename": "./sqli.py",
      "issue_confidence": "LOW",
      "issue_cwe": { "id": 89, "link": "https://cwe.mitre.org/..." },
      "issue_severity": "MEDIUM",
      "issue_text": "Possible SQL injection vector through string-based query construction.",
      "line_number": 16,
      "test_id": "B608",
      "test_name": "hardcoded_sql_expressions"
    },
    ...
  ]
}
```
---
## 3. Revisar `sonar-project.properties` (ya configurado en el repo)
El archivo [sonar-project.properties](../sonar-project.properties) **ya viene en el repo con la integración de Bandit habilitada** (línea `sonar.python.bandit.reportPaths=bandit-report.json`). Está configurado por defecto para el escenario **A — Server local (Docker)**.
Contenido actual relevante:
```properties
sonar.projectKey=vulnerable-api
sonar.projectName=Vulnerable-API
sonar.projectVersion=1.0
sonar.sources=.
sonar.host.url=http://localhost:9000
# 🚨 Token hardcodeado — ver advertencia abajo
sonar.token=sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
sonar.sourceEncoding=UTF-8
sonar.exclusions=**/__pycache__/**,**/*.pyc,**/node_modules/**,**/.git/**,**/.venv/**,bandit-report.json,bandit-report.html
sonar.language=py
# Integración con Bandit (External Issues)
sonar.python.bandit.reportPaths=bandit-report.json
```
> ⚠️ **Seguridad — quita la línea `sonar.token=...`** del archivo: en el repo actual está hardcodeada ([sonar-project.properties:22](../sonar-project.properties#L22)) y es una vulnerabilidad real (un Bandit "real" la detectaría como `B105 hardcoded_password_string`). Vamos a pasarla por la variable de entorno `SONAR_TOKEN`, que es lo que los scripts [scan.sh](../scan.sh) y [scan.ps1](../scan.ps1) esperan.
### ¿Y para SonarCloud?
**No necesitas duplicar el archivo.** Los scripts [scan.sh](../scan.sh) y [scan.ps1](../scan.ps1) pasan `sonar.host.url`, `sonar.projectKey` y `sonar.organization` **por línea de comandos** (`-D...`), por lo que el `.properties` solo se usa como fallback. Para apuntar a SonarCloud basta con:
1. Ejecutar el script con el argumento `cloud` (o exportar `SONAR_MODE=cloud`).
2. Exportar `SONAR_ORG` y `SONAR_PROJECT_KEY` con los valores que aparecen en la página **Information** del proyecto en sonarcloud.io (engranaje en la barra lateral).
El detalle de cómo invocarlos está en el [paso 8](08_EJECUTAR_ESCANEO_COMBINADO.md).
> 🆔 **¿Dónde obtengo `Organization Key` y `Project Key` en SonarCloud?**
> Entra al proyecto en `https://sonarcloud.io` → **Information** (parte inferior izquierda). Cópialos tal cual; no incluyas espacios.
---
## 4. Exportar las Variables de Entorno que usan los Scripts
Los scripts [scan.sh](../scan.sh) y [scan.ps1](../scan.ps1) leen su configuración exclusivamente de variables de entorno y del argumento posicional (`local` | `cloud`). Estas son las variables que reconocen:
| Variable | Obligatoria | Modo | Descripción | Ejemplo |
|---|---|---|---|---|
| `SONAR_TOKEN` | ✅ Sí | local + cloud | Token de autenticación (genéralo en el panel del entorno) | `sqp_xxxxxxxx…` |
| `SONAR_MODE` | ⚠️ Opcional | local + cloud | `local` (default) o `cloud`. También se puede pasar como 1er argumento del script | `cloud` |
| `SONAR_ORG` | ✅ Sí en cloud | cloud | *Organization Key* de SonarCloud | `mi-org` |
| `SONAR_PROJECT_KEY` | ✅ Sí en cloud | cloud | *Project Key* de SonarCloud (en local el default es `vulnerable-api`) | `mi-org_vulnerable-api` |
| `SONAR_HOST_URL` | ⚠️ Opcional | local + cloud | Sobreescribe la URL por defecto del modo elegido | `https://sonarcloud.io` |
**Tokens — dónde generarlos:**
| Escenario | URL |
|---|---|
| **A — Server local (Docker)** | `http://localhost:9000/account/security` |
| **B — SonarCloud** | `https://sonarcloud.io/account/security` |
### Linux / macOS
```bash
# --- Escenario A: Server local (Docker) ---
export SONAR_TOKEN="sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
# (SONAR_MODE=local es el default; no es necesario exportarlo)
# --- Escenario B: SonarCloud ---
export SONAR_TOKEN="sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export SONAR_MODE="cloud"
export SONAR_ORG="tu-org-key"
export SONAR_PROJECT_KEY="tu-org_vulnerable-api"
# Permanente: añade los exports a ~/.bashrc o ~/.zshrc
```
### Windows (PowerShell)
```powershell
# --- Escenario A: Server local (Docker) ---
$env:SONAR_TOKEN = "sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
# --- Escenario B: SonarCloud ---
$env:SONAR_TOKEN       = "sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$env:SONAR_MODE        = "cloud"
$env:SONAR_ORG         = "tu-org-key"
$env:SONAR_PROJECT_KEY = "tu-org_vulnerable-api"
# Permanente (requiere reabrir PowerShell):
[Environment]::SetEnvironmentVariable("SONAR_TOKEN", "sqp_...", "User")
```
> 🔐 Si ya hiciste commit del token que viene en `sonar-project.properties`, **revócalo** en el panel correspondiente y genera uno nuevo. Luego limpia el historial de git si el repo es público.
---
## 5. Verificar la Configuración
Antes de ejecutar los scripts del paso siguiente, asegúrate de que los archivos del repo están en su sitio y de que las variables de entorno están exportadas según el modo elegido.
```bash
# Linux / macOS
ls sonar-project.properties pyproject.toml scan.sh requirements-dev.txt
echo "SONAR_TOKEN:       $(if [ -n "$SONAR_TOKEN" ]; then echo "✅ definido"; else echo "❌ falta"; fi)"
echo "SONAR_MODE:        ${SONAR_MODE:-local (default)}"
echo "SONAR_ORG:         ${SONAR_ORG:-(no aplica en local)}"
echo "SONAR_PROJECT_KEY: ${SONAR_PROJECT_KEY:-vulnerable-api (default en local)}"
grep -E "sonar\.python\.bandit" sonar-project.properties
```
```powershell
# Windows
Get-Item sonar-project.properties, pyproject.toml, scan.ps1, requirements-dev.txt
if ($env:SONAR_TOKEN) { "✅ SONAR_TOKEN definido" } else { "❌ Falta SONAR_TOKEN" }
"SONAR_MODE:        $($env:SONAR_MODE -as [string])"
"SONAR_ORG:         $($env:SONAR_ORG -as [string])"
"SONAR_PROJECT_KEY: $($env:SONAR_PROJECT_KEY -as [string])"
Select-String "sonar\.python\.bandit" sonar-project.properties
```
Salida esperada — **Opción A (Server local)**:
```
sonar-project.properties  pyproject.toml  scan.sh  requirements-dev.txt
SONAR_TOKEN:       ✅ definido
SONAR_MODE:        local (default)
SONAR_PROJECT_KEY: vulnerable-api (default en local)
sonar.python.bandit.reportPaths=bandit-report.json
```
Salida esperada — **Opción B (SonarCloud)**:
```
sonar-project.properties  pyproject.toml  scan.sh  requirements-dev.txt
SONAR_TOKEN:       ✅ definido
SONAR_MODE:        cloud
SONAR_ORG:         tu-org-key
SONAR_PROJECT_KEY: tu-org_vulnerable-api
sonar.python.bandit.reportPaths=bandit-report.json
```
> 🧪 `bandit-report.json` todavía **no** existe — se genera en el paso 8 al correr el script.
---
## 6. ¿Qué pasa si NO genero el reporte antes de ejecutar el scanner?
SonarQube no falla, pero ignora la integración. Verás en el log:
```
WARN: File 'bandit-report.json' not found for property 'sonar.python.bandit.reportPaths'
```
Por eso en el siguiente paso encadenamos **bandit → sonar-scanner** en un solo script.
---
## 🔧 Solución de Problemas Comunes
| Problema | Causa probable | Solución |
|---|---|---|
| `WARN: File 'bandit-report.json' not found` | No corriste Bandit antes del scanner | Ejecuta `bandit -r . -c pyproject.toml -f json -o bandit-report.json` primero |
| Los hallazgos NO aparecen en Sonar | Path relativo incorrecto en el reporte | Verifica que las rutas en el JSON sean relativas a la raíz (Bandit las pone como `./archivo.py`, lo cual es correcto) |
| `Authentication failed` | `SONAR_TOKEN` no exportado o caducado | Re-exporta o regenera el token (en el panel del entorno que estés usando) |
| Aparecen hallazgos duplicados | Tienes el token en el `.properties` y en env var | Deja solo uno (preferible env var) |
| El JSON está vacío `{...,"results": []}` | Bandit no encontró nada (mal config) | Vuelve al paso 6 y verifica `exclude_dirs` |
| **SonarCloud:** `You're not authorized to run analysis` | Falta `sonar.organization` o el token no pertenece a esa org | Añade `sonar.organization=<tu-org>` y verifica que el token se generó dentro de esa organización |
| **SonarCloud:** `Project not found` | El `projectKey` no coincide con el creado en sonarcloud.io | Copia exactamente el *Project Key* desde la página **Information** del proyecto |
| **Server local:** `Connection refused http://localhost:9000` | Contenedor de SonarQube no levantado | `docker compose up -d` (o `docker ps` para confirmar) |
---
## ✅ Verificación del Paso 7
```
[ ] sonar-project.properties existe en la raíz con sonar.python.bandit.reportPaths
[ ] sonar.token ELIMINADO de sonar-project.properties (estaba hardcodeado en el repo)
[ ] Variable de entorno SONAR_TOKEN exportada (generada en el panel del entorno correspondiente)
[ ] (Solo cloud) SONAR_MODE=cloud, SONAR_ORG y SONAR_PROJECT_KEY exportados
[ ] scan.sh / scan.ps1 visibles en la raíz del repo
[ ] bandit-report.json y .venv presentes en la línea sonar.exclusions
```
---
## ➡️ Siguiente Paso
**📄 `08_EJECUTAR_ESCANEO_COMBINADO.md`** → Ejecutar los scripts [scan.sh](../scan.sh) / [scan.ps1](../scan.ps1) que ya vienen en el repo y encadenan Bandit + sonar-scanner.
---
## 📚 Referencias
- [SonarQube Server — Importing external issues (Python / Bandit)](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/external-analyzer-reports/)
- [SonarCloud — Importing external issues](https://docs.sonarsource.com/sonarcloud/enriching/external-analyzer-reports/)
- [SonarPython — sonar.python.bandit.reportPaths](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/languages/python/)
- [Bandit — Output formatters](https://bandit.readthedocs.io/en/latest/formatters/index.html)
