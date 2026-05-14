# ⚡ Referencia Rápida — macOS / Linux
> Secuencia completa de comandos para ejecutar la guía base (00–04) + la guía extendida con Bandit (05–09) en **una sola pasada**. Cada bloque tiene 1 línea de descripción; los detalles están en los archivos numerados.
---
## 🧰 Prerequisitos (instalar una sola vez)
```bash
# Java 17 (requerido por sonar-scanner)
brew install openjdk@17                                    # macOS
sudo apt-get install -y openjdk-17-jdk                     # Ubuntu/Debian
# Docker (solo para escenario A — local)
brew install --cask docker                                 # macOS
# Linux: https://docs.docker.com/engine/install/
# sonar-scanner CLI
brew install sonar-scanner                                 # macOS
# Linux: descarga desde https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/scanners/sonarscanner/
# Python 3.8+ (requerido por Bandit)
brew install python                                        # macOS
sudo apt-get install -y python3 python3-pip python3-venv   # Ubuntu/Debian
# Git
brew install git                                           # macOS
sudo apt-get install -y git                                # Ubuntu/Debian
# Verificar
python3 --version && pip3 --version && git --version && java -version
sonar-scanner --version
```
---
## 🅰️ Escenario A — SonarQube Server local (Docker)
### Paso 01 — Levantar SonarQube en Docker
```bash
mkdir -p ~/sonarqube-lab && cd ~/sonarqube-lab             # carpeta de trabajo
cat > docker-compose.yml << 'EOF'                          # define el servicio
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
EOF
docker compose up -d                                       # arranca el contenedor
docker ps                                                  # verifica que esté UP
# Abre http://localhost:9000  (admin / admin → cambia la contraseña)
```
### Paso 02 — Generar token (en la UI)
> Navega a `http://localhost:9000/account/security` → **Generate Token** → cópialo.
### Paso 03 — Clonar y primer escaneo (solo Sonar)
```bash
cd ~ && git clone https://github.com/michealkeines/Vulnerable-API.git
cd Vulnerable-API
export SONAR_TOKEN="sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"   # token paso 02
sonar-scanner -Dsonar.token="${SONAR_TOKEN}"               # primer análisis
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
```bash
cd ~ && git clone https://github.com/michealkeines/Vulnerable-API.git
cd Vulnerable-API
export SONAR_TOKEN="sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export SONAR_ORG="tu-org-key"
export SONAR_PROJECT_KEY="tu-org_vulnerable-api"
sonar-scanner \
  -Dsonar.host.url=https://sonarcloud.io \
  -Dsonar.organization="${SONAR_ORG}" \
  -Dsonar.projectKey="${SONAR_PROJECT_KEY}" \
  -Dsonar.token="${SONAR_TOKEN}"
# Abre https://sonarcloud.io/dashboard?id=tu-org_vulnerable-api
```
---
## 🐍 Guía extendida — Bandit (pasos 05–09, idénticos para A y B)
### Paso 05 — Instalar Bandit
```bash
cd ~/Vulnerable-API                                        # raíz del repo
python3 -m venv .venv                                      # entorno virtual aislado
source .venv/bin/activate                                  # activarlo (prompt con (.venv))
cat requirements-dev.txt                                   # verifica que existe (bandit[toml]==1.7.9)
pip3 install -r requirements-dev.txt                       # instalar Bandit
bandit --version                                           # debe mostrar 1.7.9
bandit -r . -x ./.venv,./.scannerwork                      # prueba rápida (sin config)
```
### Paso 06 — Configurar Bandit con `pyproject.toml`
```bash
cat pyproject.toml                                         # ya viene en el repo
bandit -r . -c pyproject.toml                              # corrida con la config (exclude_dirs)
bandit -r . -c pyproject.toml -f html -o bandit-report.html # (opcional) reporte HTML
cat >> .gitignore << 'EOF'                                 # evita commitear artefactos
# Bandit / SAST
.venv/
bandit-report.json
bandit-report.html
.scannerwork/
EOF
```
### Paso 07 — Integrar Bandit con Sonar (variables de entorno)
> ⚠️ Elimina la línea `sonar.token=...` de `sonar-project.properties` si está hardcodeada.
```bash
# --- Escenario A (local) ---
export SONAR_TOKEN="sqp_<token_local>"                     # único obligatorio en local
# --- Escenario B (SonarCloud) ---
export SONAR_TOKEN="sqp_<token_cloud>"
export SONAR_MODE="cloud"
export SONAR_ORG="tu-org-key"
export SONAR_PROJECT_KEY="tu-org_vulnerable-api"
# Generar el JSON que Sonar ingiere (se hace automáticamente en el paso 08)
bandit -r . -c pyproject.toml -f json -o bandit-report.json
```
### Paso 08 — Escaneo combinado (Bandit + sonar-scanner)
```bash
chmod +x scan.sh                                           # primera vez: bit ejecutable
# Escenario A — local (default)
./scan.sh
./scan.sh local                                            # equivalente explícito
# Escenario B — SonarCloud (usa las env vars del paso 07)
./scan.sh cloud
SONAR_MODE=cloud ./scan.sh                                 # equivalente
```
Verifica en el log: `Sensor Bandit Sensor [python]` + `Importing report: bandit-report.json`.
### Paso 09 — Interpretar resultados (en la UI)
> Dashboard → pestaña **Issues** → filtro **Type → Vulnerability**. Las nuevas marcadas *Detected by: bandit* son las que aportó la integración. Compara *antes/después* del paso 03.
---
## 🔁 Re-ejecutar el flujo en un nuevo shell
```bash
cd ~/Vulnerable-API
source .venv/bin/activate                                  # reactivar venv
export SONAR_TOKEN="sqp_..."                               # re-exportar (no persiste)
# (cloud) export SONAR_MODE=cloud SONAR_ORG=... SONAR_PROJECT_KEY=...
./scan.sh                                                  # o ./scan.sh cloud
```
---
## 🆘 Comandos de diagnóstico rápidos
```bash
docker ps                                                  # ¿SonarQube corriendo?
docker compose logs -f sonarqube                           # logs del contenedor
curl -I http://localhost:9000                              # ¿responde el server?
echo "${SONAR_TOKEN:+definido}"                            # ¿hay token exportado?
bandit --version && which sonar-scanner                    # herramientas en PATH
ls -lh bandit-report.json                                  # ¿se generó el JSON?
```
