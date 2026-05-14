# 🏗️ Arquitectura y Stack del Proyecto
### Asignatura: Modelos de Evaluación de Software
### Repositorio bajo análisis: `michealkeines/Vulnerable-API`
---
> 📎 **Material de apoyo de la guía extendida.** Este documento describe el stack y la estructura del repo para que tengas contexto técnico mientras avanzas por los pasos **05–09** (ver [README.md](README.md)).
---
## 1. Visión general
`Vulnerable-API` es una API HTTP en Python que expone, de forma intencional, seis familias de vulnerabilidades clásicas (XSS, SQLi, LFI, RFI, HHI, SSTI). Cada vulnerabilidad se entrega en dos variantes: una "no vulnerable" (`*novuln`) y otra explotable (`*vuln`), de modo que los escáneres SAST puedan ser entrenados y comparados.
La aplicación se construye sobre **Flask** (vía **Connexion**), define sus rutas en un **contrato OpenAPI 3.0** ([swagger.yml](../swagger.yml)) y usa una **base de datos SQLite** efímera que se recrea en cada arranque.
El pipeline de análisis combina **Bandit** (SAST gratuito para Python) con **SonarQube** — en cualquiera de sus dos sabores soportados por la guía: **Server local en Docker** o **SonarCloud**. La unión se concreta en un script multiplataforma ([scan.sh](../scan.sh) / [scan.ps1](../scan.ps1)) que encadena ambas herramientas y publica los hallazgos como un único dashboard.
---
## 2. Stack tecnológico
| Capa | Tecnología | Versión / Origen |
|---|---|---|
| Lenguaje | Python | 3.8+ |
| Framework web | Flask (embebido en Connexion) | — |
| Enrutado por contrato | Connexion[swagger-ui] | 2.14.1 ([req.txt](../req.txt)) |
| Especificación de API | OpenAPI 3.0 ([swagger.yml](../swagger.yml)) | — |
| Plantillas HTML | Jinja2 | (transitiva de Flask) |
| Base de datos | SQLite 3 | módulo estándar |
| Cliente HTTP saliente | `requests` | (usado por [rfi.py](../rfi.py)) |
| SAST | Bandit | 1.7.9 ([requirements-dev.txt](../requirements-dev.txt)) |
| Calidad/SAST integrado | SonarQube Server (Community / Docker) **o** SonarCloud | configurado en [sonar-project.properties](../sonar-project.properties) |
| Orquestación de escaneo | Bash ([scan.sh](../scan.sh)) / PowerShell ([scan.ps1](../scan.ps1)) | — |
---
## 3. Diagrama de alto nivel
```
                ┌──────────────────────────────────────────┐
                │              Cliente HTTP                │
                │       (curl, Postman, Burp, Swagger UI)  │
                └────────────────────┬─────────────────────┘
                                     │  /api/<endpoint>
                                     ▼
   ┌────────────────────────────────────────────────────────────┐
   │                       app.py                               │
   │   - Inicializa Connexion                                   │
   │   - Carga swagger.yml                                      │
   │   - Llama setup_db() (recrea vulns.db)                     │
   │   - Sirve "/" → templates/home.html                        │
   └────────────────────┬───────────────────────────────────────┘
                        │ resolución por operationId
        ┌───────────────┼────────────────┬─────────────┬─────────────┐
        ▼               ▼                ▼             ▼             ▼
     xss.py          sqli.py          lfi.py        rfi.py        ...
   reflected()     sqlivuln()       lfivuln()    rfivuln()
                        │                              │
                        ▼                              ▼
                 ┌──────────────┐               ┌─────────────┐
                 │  vulns.db    │               │  Internet   │
                 │  (SQLite)    │               │  (requests) │
                 └──────────────┘               └─────────────┘
   ┌────────────────────────────────────────────────────────────┐
   │  Pipeline de análisis (offline)                            │
   │                                                            │
   │  scan.sh / scan.ps1  ──► Bandit (bandit-report.json) ──┐   │
   │  (arg: local|cloud)                                    │   │
   │                      ──► sonar-scanner ────────────────┤   │
   │                                                        ▼   │
   │     ┌───────────────────────────┐    ┌───────────────┐     │
   │     │ SonarQube Server (Docker) │ ó  │  SonarCloud   │     │
   │     │  http://localhost:9000    │    │ sonarcloud.io │     │
   │     └───────────────────────────┘    └───────────────┘     │
   └────────────────────────────────────────────────────────────┘
```
---
## 4. Estructura de carpetas
```
Vulnerable-API/
├── app.py                       # Punto de entrada
├── swagger.yml                  # Contrato OpenAPI 3.0
├── custom_db.py                 # Bootstrap de SQLite
├── xss.py / sqli.py / lfi.py /
│   rfi.py / hhi.py / ssti.py    # Handlers vulnerables
├── templates/
│   └── home.html                # Plantilla Jinja del root "/"
├── req.txt                      # Dependencias de runtime
├── requirements-dev.txt         # Herramientas SAST (Bandit)
├── pyproject.toml               # Configuración de Bandit
├── sonar-project.properties     # Configuración de SonarQube / SonarCloud
├── scan.sh                      # Orquestador Bandit + Sonar (Linux / macOS)
├── scan.ps1                     # Orquestador Bandit + Sonar (Windows / PowerShell)
└── Docs/                        # Guía extendida (pasos 05–09)
    ├── README.md                          # Índice de la guía extendida
    ├── ARQUITECTURA.md                    # Este documento
    ├── 05_INSTALAR_BANDIT.md
    ├── 06_CONFIGURAR_BANDIT.md
    ├── 07_INTEGRAR_BANDIT_SONARQUBE.md
    ├── 08_EJECUTAR_ESCANEO_COMBINADO.md
    ├── 09_INTERPRETAR_RESULTADOS_BANDIT.md
    ├── INSTRUCCIONES_MACOS_LINUX.md       # Referencia rápida (todos los comandos)
    ├── INSTRUCCIONES_WINDOWS.md           # Referencia rápida (todos los comandos)
    └── Sonar_local_or_cloud/              # Pasos 00–04 reproducidos por escenario
        ├── local/                         # SonarQube Server (Docker)
        └── cloud/                         # SonarCloud
```
---
## 5. Flujo de una petición
1. El cliente envía `POST /api/sqlivuln` con `{"username": "...", "password": "..."}`.
2. **Connexion** valida el cuerpo contra el schema definido en [swagger.yml](../swagger.yml).
3. El `operationId` (`sqli.sqlivuln`) se resuelve a la función `sqlivuln` del módulo [sqli.py](../sqli.py).
4. El handler interpola directamente la entrada del usuario en una consulta SQL (vulnerabilidad intencional) y consulta `vulns.db`.
5. La respuesta JSON se devuelve al cliente.
> El mismo patrón aplica a las otras cinco familias: el contrato OpenAPI mapea cada endpoint a un `operationId` que vive en un módulo por familia de vulnerabilidad.
---
## 6. Propósito de los componentes clave
### Runtime (la aplicación)
- **[app.py](../app.py)** — Punto de entrada. Crea la aplicación Connexion, monta `swagger.yml` bajo `/api`, expone una ruta extra `/` que renderiza `home.html` y arranca el servidor en `0.0.0.0:8000` con `debug=True` (detectado por Bandit como `B201`). También borra y vuelve a crear `vulns.db` en cada arranque, garantizando un estado limpio para el laboratorio.
- **[swagger.yml](../swagger.yml)** — **Único contrato fuente** de la API. Define los doce endpoints (seis pares `novuln`/`vuln`), sus métodos, schemas de request y el `operationId` que Connexion usa para enrutar a las funciones Python. Cambiar la API significa editar este archivo, no `app.py`.
- **[custom_db.py](../custom_db.py)** — Bootstrap de la base de datos. Crea las tablas `USERS` y `vulns` en SQLite y siembra datos de prueba (`admin/admin`, `mike/kaines`). Se ejecuta una sola vez al arranque desde `app.py`.
- **[xss.py](../xss.py)** — Implementa el endpoint reflejado de Cross-Site Scripting. La función `reflected()` devuelve la entrada del usuario en la respuesta sin escaparla.
- **[sqli.py](../sqli.py)** — Implementa el endpoint de SQL Injection. La función `sqlivuln()` interpola `username` directamente en una consulta `SELECT` (concatenación de strings), reproduciendo el patrón clásico de SQLi por concatenación (Bandit: `B608`, CWE-89).
- **[lfi.py](../lfi.py)** — Implementa Local File Inclusion. La función `lfivuln()` recibe un `filename` arbitrario y lo abre con `open()` sin sanear la ruta, permitiendo path traversal.
- **[rfi.py](../rfi.py)** — Implementa Remote File Inclusion. La función `rfivuln()` toma una URL arbitraria (`imagelink`) y realiza un `requests.get(..., verify=False)`, exponiéndose a SSRF y descargas de fuentes no confiables.
- **[hhi.py](../hhi.py)** — Implementa Host Header Injection. La función `hhivuln()` toma el header `Host` de la petición y lo refleja sin validación dentro de un atributo `href`, habilitando envenenamiento de enlaces de reseteo. **Nota:** ninguna regla específica de Bandit cubre este patrón; queda como ejemplo del límite del SAST (ver paso 09).
- **[ssti.py](../ssti.py)** — Implementa Server-Side Template Injection. La función `sstivuln()` construye una `jinja2.Template` concatenando entrada del usuario y la renderiza, lo que permite ejecución arbitraria de código del lado del servidor (Bandit: `B701` / `B704`).
- **[templates/home.html](../templates/home.html)** — Plantilla Jinja mínima servida en `/`. Existe principalmente para verificar que la aplicación arrancó.
- **`vulns.db`** — Archivo SQLite generado en runtime. **No** debe versionarse: se recrea con cada `python app.py`.
### Dependencias
- **[req.txt](../req.txt)** — Dependencias mínimas de runtime (`connexion[swagger-ui]==2.14.1`). Es lo que necesita un alumno para hacer correr la API.
- **[requirements-dev.txt](../requirements-dev.txt)** — Herramientas de análisis (`bandit[toml]==1.7.9`). Separado del runtime para que el contenedor de la app no cargue herramientas de seguridad innecesariamente. El extra `[toml]` permite a Bandit leer su configuración desde `pyproject.toml` (ver paso 06).
### Pipeline de análisis (la parte académica)
- **[pyproject.toml](../pyproject.toml)** — Configuración de Bandit (carpetas excluidas, severidad mínima en `LOW` por defecto, reglas a saltar). Centraliza el comportamiento del SAST para que `bandit -r . -c pyproject.toml` produzca resultados reproducibles.
- **[sonar-project.properties](../sonar-project.properties)** — Configuración base de Sonar: `projectKey`, `host.url`, exclusiones y, lo más importante, `sonar.python.bandit.reportPaths=bandit-report.json`, que indica a Sonar que ingiera los hallazgos de Bandit como **External Issues**. ⚠️ El repo trae también una línea `sonar.token=sqp_...` hardcodeada que **debe eliminarse** (ver paso 07): los scripts [scan.sh](../scan.sh) / [scan.ps1](../scan.ps1) pasan el token y las demás propiedades sensibles por línea de comandos (`-D...`), tomándolas de variables de entorno.
- **[scan.sh](../scan.sh) / [scan.ps1](../scan.ps1)** — Script multiplataforma que encadena las dos herramientas: primero corre Bandit y produce `bandit-report.json`, luego dispara `sonar-scanner` que publica todo (hallazgos propios + los importados de Bandit) en el dashboard correspondiente. Soporta dos modos seleccionables por argumento posicional o por la variable `SONAR_MODE`. El script también valida prerrequisitos (`SONAR_TOKEN` presente, binarios disponibles) y termina mostrando las URLs del dashboard.
| Modo | Comando | Destino | Variables obligatorias |
| --- | --- | --- | --- |
| `local` (default) | `./scan.sh` o `./scan.sh local` | `http://localhost:9000` | `SONAR_TOKEN` |
| `cloud` | `./scan.sh cloud` | `https://sonarcloud.io` | `SONAR_TOKEN`, `SONAR_ORG`, `SONAR_PROJECT_KEY` |
- **`bandit-report.json` / `bandit-report.html`** — Salidas generadas por Bandit. **No** son fuente: se regeneran en cada corrida y están excluidas del análisis de Sonar (vía `sonar.exclusions`) para evitar que las cuente como código.
### Documentación
- **[Docs/](.)** — Guía extendida (pasos 05–09) que enseña cómo complementar SonarQube Community / SonarCloud free con Bandit, dado que ninguno de los dos detecta inyecciones por sí solo (el *taint analysis* es feature de pago). Su índice es [Docs/README.md](README.md).
- **[Docs/INSTRUCCIONES_MACOS_LINUX.md](INSTRUCCIONES_MACOS_LINUX.md) / [Docs/INSTRUCCIONES_WINDOWS.md](INSTRUCCIONES_WINDOWS.md)** — Referencias rápidas con la secuencia completa de comandos (00–09) para cada plataforma, pensadas para ejecutar la guía de principio a fin sin pasar por la versión narrada.
- **[Docs/Sonar_local_or_cloud/](Sonar_local_or_cloud/)** — Reproducción de los pasos **00–04** de la guía base, separados por escenario (`local/` para SonarQube Server en Docker, `cloud/` para SonarCloud). Es el prerequisito antes de empezar el paso 05.
- **[README.md](../README.md)** (raíz) — Descripción del propósito educativo del repo, instrucciones de instalación y catálogo de vulnerabilidades.
---
## 7. Cómo levantar todo localmente
> ℹ️ **Nota:** Levantar la API (sección 7.1) es **opcional** y solo necesario si quieres comprobar las vulnerabilidades en vivo (con `curl`, Postman, Burp, etc.). El **propósito central de esta documentación es el Análisis SAST** (secciones 7.2 y 7.3): Bandit + SonarQube analizan el código fuente de forma estática, sin necesidad de ejecutar la aplicación.
### 7.1 Runtime (la API)
```bash
pip install -r req.txt
python app.py                      # API en http://localhost:8000
```
### 7.2 Análisis SAST — Linux / macOS
```bash
# Entorno virtual + Bandit
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
# --- Escenario A: SonarQube Server local (Docker) ---
export SONAR_TOKEN="sqp_..."
./scan.sh                          # equivale a ./scan.sh local
# --- Escenario B: SonarCloud ---
export SONAR_TOKEN="sqp_..."
export SONAR_ORG="tu-org-key"
export SONAR_PROJECT_KEY="tu-org_vulnerable-api"
./scan.sh cloud
```
### 7.3 Análisis SAST — Windows (PowerShell)
```powershell
# Entorno virtual + Bandit
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
# --- Escenario A: SonarQube Server local (
