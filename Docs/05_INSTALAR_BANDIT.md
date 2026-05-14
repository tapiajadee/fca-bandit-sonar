# 🐍 Paso 5: Instalar Bandit como Complemento de SAST
### Asignatura: Modelos de Evaluación de Software
---
> ⬅️ **Anterior:** `04_INTERPRETAR_RESULTADOS.md` (en el repo de la guía base)
> ➡️ **Siguiente:** `06_CONFIGURAR_BANDIT.md`
---
## Objetivo
Instalar **Bandit**, una herramienta SAST (Static Application Security Testing) gratuita y open source, especializada en encontrar vulnerabilidades de seguridad en código Python. La usarás para **complementar** los hallazgos de Sonar — tanto si trabajas con **SonarQube Server (Community Edition) en Docker** como con **SonarCloud (plan free)** — porque en ambos casos **no se detectan inyecciones** (SQLi, SSTI, XSS, LFI/RFI): el motor de *taint analysis* solo está disponible en SonarQube Developer Edition o en planes pagos de SonarCloud.
> 🧭 **Compatibilidad de esta guía:** los pasos 5 y 6 son idénticos en ambos escenarios. Las diferencias (URL del servidor, `organization`, generación de token) están señaladas explícitamente en los pasos 7 y 8 con bloques **Opción A — Server local** y **Opción B — SonarCloud**.
---
## ¿Por qué Bandit?
Sonar (tanto Community Edition local como SonarCloud free) deja huecos importantes en seguridad para Python. Bandit los cubre con reglas específicas:
| Necesidad | SonarQube Community / SonarCloud (free) | Bandit |
|---|---|---|
| Code smells y bugs generales | ✅ | ❌ |
| Métricas de mantenibilidad / duplicación | ✅ | ❌ |
| **SQL Injection (CWE-89)** | ❌ (solo *Hotspot*) | ✅ Regla `B608` |
| **Server-Side Template Injection** | ❌ | ✅ Regla `B701` |
| **Hardcoded passwords / tokens** | ⚠️ Limitado | ✅ Reglas `B105`/`B106` |
| **Flask debug=True en producción** | ❌ | ✅ Regla `B201` |
| **subprocess sin shell escaping** | ⚠️ Hotspot | ✅ Reglas `B602`–`B607` |
> 💡 Bandit emite hallazgos en JSON y SonarQube/SonarCloud los **ingieren de forma nativa** como *External Issues* (vía `sonar.python.bandit.reportPaths`). El resultado: una sola vista en el dashboard con lo mejor de los dos motores, sin importar si Sonar está en Docker local o en la nube. En el paso 9 los explorarás usando **exactamente los mismos filtros** del panel `Issues` que conociste en el paso 4 de la guía base (`Sonar_local_or_cloud/<local|cloud>/04_INTERPRETAR_RESULTADOS.md`) — concretamente `Type → Vulnerability`.
---
## 1. Verificar e Instalar Python y pip
Bandit es un paquete de Python; necesitas Python 3.8+ y `pip` funcionando. Verifica primero; si no lo tienes, instálalo con el gestor de paquetes recomendado de tu sistema.
#### Windows (PowerShell)
```powershell
# Verificar
python --version
pip --version
# Instalar (si falta)
winget install Python.Python.3.12                          # Python 3.8+
```
#### macOS
```bash
# Verificar
python3 --version
pip3 --version
# Instalar (si falta)
brew install python                                        # Python 3.8+
```
#### Linux (Ubuntu/Debian)
```bash
# Verificar
python3 --version
pip3 --version
# Instalar (si falta)
sudo apt-get install -y python3 python3-pip python3-venv
```
> 📦 Alternativa multiplataforma: descarga el instalador oficial desde <https://www.python.org/downloads/>.
---
## 2. (Recomendado) Crear un Entorno Virtual
Mantener las dependencias del laboratorio aisladas evita conflictos con otros proyectos Python.
#### Linux / macOS
```bash
# Asegúrate de estar dentro de la carpeta Vulnerable-API
cd ~/Vulnerable-API
python3 -m venv .venv
source .venv/bin/activate
# Tu prompt ahora debería empezar con (.venv)
```
#### Windows (PowerShell)
```powershell
cd $HOME\Documents\Vulnerable-API
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```
> ⚠️ Si PowerShell te bloquea con un error de *Execution Policy*, ejecútalo una vez como administrador:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```
---
## 3. Usar el Archivo `requirements-dev.txt` (ya incluido en el repo)
Para no mezclar las dependencias de seguridad con las de la aplicación, el repo ya trae un archivo separado: [requirements-dev.txt](../requirements-dev.txt). **No necesitas crearlo.** Su contenido actual es:
```text
# Herramientas de seguridad / SAST para el laboratorio
bandit[toml]==1.7.9
```
**Verificar que existe:**
```bash
# Linux / macOS
cat requirements-dev.txt
# Windows (PowerShell)
type requirements-dev.txt
```
> 📝 El extra `[toml]` permite a Bandit leer su configuración desde `pyproject.toml`, lo cual usaremos en el siguiente paso.
---
## 4. Instalar Bandit
```bash
# Linux / macOS
pip3 install -r requirements-dev.txt
# Windows
pip install -r requirements-dev.txt
```
Verás algo como:
```
Collecting bandit[toml]==1.7.9
  Downloading bandit-1.7.9-py3-none-any.whl (129 kB)
...
Successfully installed bandit-1.7.9 PyYAML-6.0.2 rich-13.x stevedore-5.x ...
```
---
## 5. Verificar la Instalación
```bash
bandit --version
```
Salida esperada (la versión exacta puede variar):
```
bandit 1.7.9
  python version = 3.11.x
```
---
## 6. Primera Ejecución de Prueba (sin configuración)
Antes de configurar Bandit, hagamos una corrida rápida para confirmar que detecta vulnerabilidades en `Vulnerable-API`:
```bash
bandit -r . -x ./.venv,./.scannerwork
```
Salida esperada (resumen al final):
```
Test results:
>> Issue: [B608:hardcoded_sql_expressions] Possible SQL injection vector
   Severity: Medium   Confidence: Low
   CWE: CWE-89 (https://cwe.mitre.org/data/definitions/89.html)
   Location: ./sqli.py:16:25
>> Issue: [B201:flask_debug_true] A Flask app appears to be run with debug=True
   Severity: High   Confidence: Medium
   CWE: CWE-94
   Location: ./app.py:24
...
Code scanned:
        Total lines of code: ~120
        Total lines skipped (#nosec): 0
Run metrics:
        Total issues (by severity):
                Undefined: 0
                Low: 4
                Medium: 3
                High: 2
```
> ✅ Si ves **al menos 1 hallazgo de severidad `High` o `Medium`**, Bandit está funcionando correctamente.
---
## 🔧 Solución de Problemas Comunes
| Problema | Causa probable | Solución |
|---|---|---|
| `bandit: command not found` | El entorno virtual no está activado | `source .venv/bin/activate` (Linux/macOS) o `.\.venv\Scripts\Activate.ps1` (Windows) |
| `pip: command not found` | Python instalado sin `pip` | Reinstala Python marcando "Add to PATH" e incluyendo `pip` |
| `error: externally-managed-environment` | Distros recientes bloquean `pip` global | Usa el entorno virtual (Sección 2) — es la forma correcta |
| `ModuleNotFoundError: No module named 'pkg_resources'` | `setuptools` desactualizado | `pip install --upgrade pip setuptools` |
| `UnicodeDecodeError` al escanear | Algún archivo binario en el repo | Lo arreglaremos en el siguiente paso con `exclude_dirs` |
---
## ✅ Verificación del Paso 5
```
[ ] python3 --version  → muestra 3.8 o superior
[ ] Entorno virtual creado y activado (prompt con (.venv))
[ ] requirements-dev.txt creado en la raíz del proyecto
[ ] pip install -r requirements-dev.txt sin errores
[ ] bandit --version  → muestra 1.7.9
[ ] Primera ejecución muestra al menos 1 hallazgo High/Medium
```
---
## ➡️ Siguiente Paso
**📄 `06_CONFIGURAR_BANDIT.md`** → Crear `pyproject.toml` con la configuración de Bandit para que ignore archivos irrelevantes y produzca un reporte limpio para SonarQube.
---
## 📚 Referencias
- [Bandit — documentación oficial](https://bandit.readthedocs.io/en/latest/)
- [Lista completa de plugins/reglas de Bandit](https://bandit.readthedocs.io/en/latest/plugins/index.html)
- [PyPI — bandit](https://pypi.org/project/bandit/)
- [CWE Top 25](https://cwe.mitre.org/top25/) — Categorías que Bandit cubre
