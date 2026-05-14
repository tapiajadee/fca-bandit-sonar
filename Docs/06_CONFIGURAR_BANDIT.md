# ⚙️ Paso 6: Configurar Bandit para el Proyecto
### Asignatura: Modelos de Evaluación de Software
---
> ⬅️ **Anterior:** `05_INSTALAR_BANDIT.md`
> ➡️ **Siguiente:** `07_INTEGRAR_BANDIT_SONARQUBE.md`
---
## Objetivo
Crear el archivo `pyproject.toml` con la configuración de Bandit para que:
1. **Excluya** carpetas que no aportan valor (entorno virtual, caché, base de datos SQLite, reportes).
2. **Incluya** todas las reglas relevantes con la severidad mínima en `LOW` (queremos que el demo muestre **el máximo** de hallazgos).
3. Sea **reproducible**: cualquiera que clone el repo obtiene el mismo resultado.
---
## 1. ¿Por qué `pyproject.toml` y no `.bandit`?
Bandit acepta tres formatos de configuración:
| Formato | Pros | Contras |
|---|---|---|
| `.bandit` (INI) | Simple | Formato propietario, solo Bandit lo lee |
| `bandit.yaml` | Más expresivo | Otro archivo más en la raíz |
| **`pyproject.toml`** | **Estándar PEP 518**, lo comparten muchas herramientas (black, ruff, mypy, etc.) | Requiere el extra `bandit[toml]` (ya instalado en el paso 5) |
Usaremos **`pyproject.toml`** por ser el estándar moderno de Python.
---
## 2. Usar `pyproject.toml` (ya incluido en el repo)
El archivo [pyproject.toml](../pyproject.toml) **ya está creado en la raíz del proyecto**. No necesitas escribirlo a mano; solo conviene revisar su contenido para entender qué hace:
```toml
[tool.bandit]
# Carpetas a excluir del escaneo
exclude_dirs = [
    ".venv",
    ".scannerwork",
    ".git",
    "__pycache__",
    "templates",   # Plantillas Jinja, no son Python
]
# Severidad mínima a reportar (LOW = todo, HIGH = solo lo crítico)
# Para el laboratorio queremos el máximo de hallazgos: LOW
# severity = "LOW"   # opcional, LOW es el default
# Confianza mínima a reportar
# confidence = "LOW" # opcional, LOW es el default
# Reglas a saltar (ninguna en el demo — queremos verlo todo)
skips = []
```
**Verificar el contenido:**
```bash
# Linux / macOS
cat pyproject.toml
# Windows
type pyproject.toml
```
> 🛠️ Si necesitas personalizarlo (silenciar reglas, subir el `severity` mínimo, etc.) edita directamente este archivo y vuelve a ejecutar el escaneo.
---
## 3. Probar la Configuración
Ejecuta Bandit sin pasar `-x`; ahora debe leer `pyproject.toml` automáticamente.
```bash
bandit -r . -c pyproject.toml
```
> 🔎 El parámetro `-c pyproject.toml` es necesario porque Bandit no lo descubre solo (a diferencia de otras herramientas como `ruff` o `black`).
Salida esperada (resumen):
```
[main]  INFO    profile include tests: None
[main]  INFO    profile exclude tests: None
[main]  INFO    cli include tests: None
[main]  INFO    cli exclude tests: None
[main]  INFO    using config: pyproject.toml
[main]  INFO    running on Python 3.11.x
[manager]  INFO    found 6 .py files
Code scanned:
        Total lines of code: ~120
Run metrics:
        Total issues (by severity):
                Undefined: 0
                Low: 4
                Medium: 3
                High: 2
```
> ✅ **Compara con la corrida anterior.** Las carpetas excluidas (`.venv`, `.scannerwork`) ya no deberían aparecer en los hallazgos — verás solo los archivos del propio proyecto.
---
## 4. Hallazgos Esperados en `Vulnerable-API`
Si todo está bien, Bandit debe reportar **al menos** estos hallazgos:
| Archivo | Línea aprox. | Regla | Severidad | Descripción |
|---|---|---|---|---|
| `sqli.py` | 16 | **B608** | Medium | SQL Injection via f-string |
| `app.py` | 24 | **B201** | High | Flask `debug=True` |
| `ssti.py` | — | **B701** / **B704** | Medium/High | Jinja2 `autoescape=False` |
| `xss.py` | — | **B704** | Medium | `MarkupSafe` mal usado |
| `lfi.py` | — | **B108** / general | Low/Medium | Path traversal |
| `rfi.py` | — | **B310** | Medium | `urllib.urlopen` con input |
| `app.py` | 7-9 | **B110** | Low | `try/except: pass` (silencia errores) |
> ℹ️ Los números de línea pueden variar si el código del repo cambia. Lo importante es que aparezcan **las reglas listadas**.
---
## 5. Generar un Reporte HTML (Opcional, para clase)
Antes de integrarlo a SonarQube, puedes generar un HTML legible para mostrar en la presentación:
```bash
bandit -r . -c pyproject.toml -f html -o bandit-report.html
```
Abre `bandit-report.html` en tu navegador. Verás algo como:
```
┌────────────────────────────────────────────────────────────┐
│  Bandit Report                                             │
│                                                            │
│  Test results: 9 issues found                              │
│  Severity: 2 High, 3 Medium, 4 Low                         │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ [B608] Hardcoded SQL Expressions                     │  │
│  │ Severity: Medium | Confidence: Low | CWE-89          │  │
│  │ File: sqli.py, line 16                               │  │
│  │                                                      │  │
│  │   16 │  cur.execute(f"SELECT * FROM USERS ... ")     │  │
│  │      │  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^      │  │
│  └──────────────────────────────────────────────────────┘  │
│  ...                                                       │
└────────────────────────────────────────────────────────────┘
```
---
## 6. Actualizar `.gitignore`
Para no versionar archivos generados (reportes, entorno virtual):
```bash
# Linux / macOS
cat >> .gitignore << 'EOF'
# Bandit / SAST
.venv/
bandit-report.json
bandit-report.html
.scannerwork/
EOF
```
```powershell
# Windows
@"
# Bandit / SAST
.venv/
bandit-report.json
bandit-report.html
.scannerwork/
"@ | Out-File -FilePath .gitignore -Encoding utf8 -Append
```
---
## 🔧 Solución de Problemas Comunes
| Problema | Causa probable | Solución |
|---|---|---|
| `[bandit] WARNING reading config file: pyproject.toml` | Falta el extra `[toml]` | `pip install bandit[toml]` |
| Sigue escaneando `.venv` | Olvidaste `-c pyproject.toml` o el path está mal | Verifica con `pwd` que estás en la raíz del proyecto |
| 0 hallazgos | `exclude_dirs` excluyó demasiado | Revisa que no incluiste `.` o `*` por error |
| Hallazgos cambian entre corridas | Tu `pyproject.toml` no se está leyendo | Confirma con `bandit --help` que ves "config: pyproject.toml" en INFO |
---
## ✅ Verificación del Paso 6
```
[ ] pyproject.toml creado en la raíz del proyecto
[ ] bandit -r . -c pyproject.toml lee la config (mensaje "using config: pyproject.toml")
[ ] Hallazgos en sqli.py (B608) y app.py (B201) aparecen
[ ] No hay hallazgos provenientes de .venv, .scannerwork, ni templates
[ ] (Opcional) bandit-report.html generado y revisable en navegador
[ ] .gitignore actualizado para no commitear reportes
```
---
## ➡️ Siguiente Paso
**📄 `07_INTEGRAR_BANDIT_SONARQUBE.md`** → Hacer que SonarQube/SonarCloud ingiera los hallazgos de Bandit como *External Issues* y los muestre en el dashboard. Una vez ingeridos, los verás aplicando el filtro `Type → Vulnerability` en la pestaña `Issues` — el mismo flujo descrito en el paso 4 de la guía base (`Sonar_local_or_cloud/<local|cloud>/04_INTERPRETAR_RESULTADOS.md`).
---
## 📚 Referencias
- [Bandit — Configuration](https://bandit.readthedocs.io/en/latest/config.html)
- [PEP 518 — pyproject.toml](https://peps.python.org/pep-0518/)
- [Bandit — Test Plugins (catálogo de reglas)](https://bandit.readthedocs.io/en/latest/plugins/index.html)

