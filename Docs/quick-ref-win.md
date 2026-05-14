# ⚡ Referencia Rápida — Windows (PowerShell)
> Secuencia completa de comandos para ejecutar la guía base (00–04) + la guía extendida con Bandit (05–09) en **una sola pasada**. Cada bloque tiene 1 línea de descripción; los detalles están en los archivos numerados.
---
## 🧰 Prerequisitos (instalar una sola vez)
```powershell
# Java 17, Docker Desktop, sonar-scanner, Python, Git
winget install EclipseAdoptium.Temurin.17.JDK              # Java 17
winget install Docker.DockerDesktop                        # Docker (solo escenario A)
winget install SonarSource.SonarScanner                    # sonar-scanner CLI
winget install Python.Python.3.12                          # Python 3.8+
winget install Git.Git                                     # Git
# Verificar
python --version; pip --version; git --version; java -version
sonar-scanner.bat --version
```
> ⚠️ Si PowerShell bloquea scripts (`scan.ps1` o `Activate.ps1`) abre PowerShell **como administrador** una vez y ejecuta:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```
---
## 🅰️ Escenario A — SonarQube Server local (Docker)
### Paso 01 — Levantar SonarQube en Docker
```powershell
mkdir $HOME\sonarqube-lab -ErrorAction SilentlyContinue    # carpeta de trabajo
cd $HOME\sonarqube-lab
@"
version: "3"
services:
  sonarqube:
    image: sonarqube:community
    ports: ["9000:9000"]
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions
volumes:
  sonarqube_data:
  sonarqube_logs:
  sonarqube_extensions:
"@ | Out-File -FilePath docker-compose.yml -Encoding utf8  # define el servicio
docker compose up -d                                       # arranca el contenedor
docker ps                                                  # verifica que esté UP
# Abre http://localhost:9000  (admin / admin → cambia la contraseña)
```
### Paso 02 — Generar token (en la UI)
> Navega a `http://localhost:9000/account/security` → **Generate Token** → cópialo.
### Paso 03 — Clonar y primer escaneo (solo Sonar)
```powershell
cd $HOME\Documents
git clone https://github.com/michealkeines/Vulnerable-API.git
cd Vulnerable-API
$env:SONAR_TOKEN = "sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"   # token paso 02
sonar-scanner.bat -Dsonar.token=$env:SONAR_TOKEN           # primer análisis
# Abre http://localhost:9000/dashboard?id=vulnerable-api
```
---
## 🅱️ Escenario B — SonarCloud (en lugar de A)
### Paso 01–02 — Cuenta, organización, proyecto y token (en la UI)
> 1. Cuenta + organización en `https://sonarcloud.io`
> 2. **+ → Analyze new project** → importar `Vulnerable-API` desde GitHub
> 3. Copia el **Project Key** y **Organization Key** desde la página *Information*
> 4. Token en `https://sonarcloud.io/account/security`
### Paso 03 — Clonar y primer escaneo
```powershell
cd $HOME\Documents
git clone https://github.com/michealkeines/Vulnerable-API.git
cd Vulnerable-API
$env:SONAR_TOKEN       = "sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$env:SONAR_ORG         = "tu-org-key"
$env:SONAR_PROJECT_KEY = "tu-org_vulnerable-api"
sonar-scanner.bat `
  -Dsonar.host.url=https://sonarcloud.io `
  -Dsonar.organization=$env:SONAR_ORG `
  -Dsonar.projectKey=$env:SONAR_PROJECT_KEY `
  -Dsonar.token=$env:SONAR_TOKEN
# Abre https://sonarcloud.io/dashboard?id=tu-org_vulnerable-api
```
---
## 🐍 Guía extendida — Bandit (pasos 05–09, idénticos para A y B)
### Paso 05 — Instalar Bandit
```powershell
cd $HOME\Documents\Vulnerable-API                          # raíz del repo
python -m venv .venv                                       # entorno virtual aislado
.\.venv\Scripts\Activate.ps1                               # activarlo (prompt con (.venv))
type requirements-dev.txt                                  # verifica que existe (bandit[toml]==1.7.9)
pip install -r requirements-dev.txt                        # instalar Bandit
bandit --version                                           # debe mostrar 1.7.9
bandit -r . -x ./.venv,./.scannerwork                      # prueba rápida (sin config)
```
### Paso 06 — Configurar Bandit con `pyproject.toml`
```powershell
type pyproject.toml                                        # ya viene en el repo
bandit -r . -c pyproject.toml                              # corrida con la config (exclude_dirs)
bandit -r . -c pyproject.toml -f html -o bandit-report.html # (opcional) reporte HTML
@"
# Bandit / SAST
.venv/
bandit-report.json
bandit-report.html
.scannerwork/
"@ | Out-File -FilePath .gitignore -Encoding utf8 -Append  # evita commitear artefactos
```
### Paso 07 — Integrar Bandit con Sonar (variables de entorno)
> ⚠️ Elimina la línea `sonar.token=...` de `sonar-project.properties` si está hardcodeada.
```powershell
# --- Escenario A (local) ---
$env:SONAR_TOKEN = "sqp_<token_local>"                     # único obligatorio en local
# --- Escenario B (SonarCloud) ---
$env:SONAR_TOKEN       = "sqp_<token_cloud>"
$env:SONAR_MODE        = "cloud"
$env:SONAR_ORG         = "tu-org-key"
$env:SONAR_PROJECT_KEY = "tu-org_vulnerable-api"
# Persistir entre sesiones (opcional; requiere reabrir PowerShell)
[Environment]::SetEnvironmentVariable("SONAR_TOKEN", "sqp_...", "User")
# Generar el JSON que Sonar ingiere (se hace automáticamente en el paso 08)
bandit -r . -c pyproject.toml -f json -o bandit-report.json
```
### Paso 08 — Escaneo combinado (Bandit + sonar-scanner)
```powershell
# Escenario A — local (default)
.\scan.ps1
.\scan.ps1 local                                           # equivalente explícito
# Escenario B — SonarCloud (usa las env vars del paso 07)
.\scan.ps1 cloud
$env:SONAR_MODE = "cloud"; .\scan.ps1                      # equivalente
```
Verifica en el log: `Sensor Bandit Sensor [python]` + `Importing report: bandit-report.json`.
### Paso 09 — Interpretar resultados (en la UI)
> Dashboard → pestaña **Issues** → filtro **Type → Vulnerability**. Las nuevas marcadas *Detected by: bandit* son las que aportó la integración. Compara *antes/después* del paso 03.
---
## 🔁 Re-ejecutar el flujo en una nueva sesión de PowerShell
```powershell
cd $HOME\Documents\Vulnerable-API
.\.venv\Scripts\Activate.ps1                               # reactivar venv
$env:SONAR_TOKEN = "sqp_..."                               # re-exportar (no persiste salvo SetEnvironmentVariable)
# (cloud) $env:SONAR_MODE="cloud"; $env:SONAR_ORG="..."; $env:SONAR_PROJECT_KEY="..."
.\scan.ps1                                                 # o .\scan.ps1 cloud
```
---
## 🆘 Comandos de diagnóstico rápidos
```powershell
docker ps                                                  # ¿SonarQube corriendo?
docker compose logs -f sonarqube                           # logs del contenedor
Invoke-WebRequest http://localhost:9000 -Method Head       # ¿responde el server?
if ($env:SONAR_TOKEN) { "definido" } else { "FALTA" }      # ¿hay token exportado?
bandit --version; (Get-Command sonar-scanner.bat).Source   # herramientas en PATH
Get-Item bandit-report.json                                # ¿se generó el JSON?
```

