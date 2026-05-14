#!/usr/bin/env bash
# ===================================================
# Escaneo combinado: Bandit + SonarQube / SonarCloud
# Asignatura: Modelos de Evaluación de Software
# ---------------------------------------------------
# Soporta dos modos (ver Docs/Sonar_local_or_cloud/):
#   - local : SonarQube en Docker  (http://localhost:9000)
#   - cloud : SonarCloud           (https://sonarcloud.io)
#
# Selección del modo (en este orden de prioridad):
#   1. Primer argumento del script:  ./scan.sh local   |   ./scan.sh cloud
#   2. Variable de entorno SONAR_MODE
#   3. Valor por defecto: local
# ===================================================

set -e  # Aborta ante cualquier error inesperado

REPORT_FILE="bandit-report.json"

# ----- Selección del modo -----
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
    *)
        echo "❌ ERROR: SONAR_MODE='${SONAR_MODE}' inválido. Usa 'local' o 'cloud'."
        echo "   Ejemplos:"
        echo "     ./scan.sh local"
        echo "     ./scan.sh cloud"
        echo "     SONAR_MODE=cloud ./scan.sh"
        exit 1
        ;;
esac

# ----- Validaciones previas -----
if [ -z "${SONAR_TOKEN}" ]; then
    echo "❌ ERROR: la variable SONAR_TOKEN no está definida."
    echo "   Ejecuta primero: export SONAR_TOKEN=\"sqp_...\""
    exit 1
fi

if [ "${SONAR_MODE}" = "cloud" ]; then
    if [ -z "${SONAR_ORG}" ]; then
        echo "❌ ERROR: en modo 'cloud' debes definir SONAR_ORG (Organization Key de SonarCloud)."
        echo "   Ejecuta: export SONAR_ORG=\"tu-org-key\""
        exit 1
    fi
    if [ -z "${PROJECT_KEY}" ]; then
        echo "❌ ERROR: en modo 'cloud' debes definir SONAR_PROJECT_KEY (Project Key de SonarCloud)."
        echo "   Ejecuta: export SONAR_PROJECT_KEY=\"tu-project-key\""
        exit 1
    fi
fi

if ! command -v bandit >/dev/null 2>&1; then
    echo "❌ ERROR: bandit no está instalado o el .venv no está activado."
    echo "   Ejecuta: source .venv/bin/activate && pip install -r requirements-dev.txt"
    exit 1
fi

if ! command -v sonar-scanner >/dev/null 2>&1; then
    echo "❌ ERROR: sonar-scanner no está en el PATH."
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " Modo Sonar: ${SONAR_MODE}"
echo " Host:       ${SONAR_URL}"
echo " ProjectKey: ${PROJECT_KEY}"
if [ "${SONAR_MODE}" = "cloud" ]; then
    echo " Org:        ${SONAR_ORG}"
fi
echo "═══════════════════════════════════════════════════════════"

# ----- 1. Ejecutar Bandit -----
echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 1/2  Ejecutando Bandit (SAST)..."
echo "═══════════════════════════════════════════════════════════"

# Bandit retorna != 0 cuando encuentra issues (esperado en repo vulnerable)
# por eso usamos || true para no abortar el script
bandit -r . -c pyproject.toml -f json -o "${REPORT_FILE}" || true

if [ ! -s "${REPORT_FILE}" ]; then
    echo "❌ ERROR: ${REPORT_FILE} no se generó o está vacío."
    exit 1
fi

NUM_ISSUES=$(grep -c '"test_id"' "${REPORT_FILE}" || echo 0)
echo "✅ Bandit completado — ${NUM_ISSUES} hallazgos en ${REPORT_FILE}"

# ----- 2. Ejecutar sonar-scanner -----
echo ""
echo "═══════════════════════════════════════════════════════════"
echo " 2/2  Ejecutando sonar-scanner (${SONAR_MODE})..."
echo "═══════════════════════════════════════════════════════════"

# Pasamos todos los parámetros por línea de comandos para no depender
# de los valores que tenga el archivo sonar-project.properties (que en
# este repo está configurado para 'local'). Equivale a la "Opción C" de
# la documentación.
SCANNER_ARGS=(
    -Dsonar.token="${SONAR_TOKEN}"
    -Dsonar.host.url="${SONAR_URL}"
    -Dsonar.projectKey="${PROJECT_KEY}"
)

if [ "${SONAR_MODE}" = "cloud" ]; then
    SCANNER_ARGS+=(-Dsonar.organization="${SONAR_ORG}")
fi

sonar-scanner "${SCANNER_ARGS[@]}"

# ----- Resumen -----
echo ""
echo "═══════════════════════════════════════════════════════════"
echo " ✅ ESCANEO COMBINADO COMPLETADO (${SONAR_MODE})"
echo "═══════════════════════════════════════════════════════════"
echo "   Dashboard: ${SONAR_URL}/dashboard?id=${PROJECT_KEY}"
echo "   Issues:    ${SONAR_URL}/project/issues?id=${PROJECT_KEY}"
echo ""
