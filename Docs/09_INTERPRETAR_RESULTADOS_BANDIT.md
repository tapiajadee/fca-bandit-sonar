# 🔍 Paso 9: Interpretar los Resultados de Bandit en SonarQube
### Asignatura: Modelos de Evaluación de Software
---
> ⬅️ **Anterior:** `08_EJECUTAR_ESCANEO_COMBINADO.md`
> ➡️ **Siguiente:** `10_TROUBLESHOOTING_Y_SIGUIENTES_PASOS.md`
---
## Objetivo
Aprender a navegar los hallazgos que Bandit aportó al dashboard de Sonar, **comparar antes/después**, y relacionar cada vulnerabilidad con su CWE y con el modelo ISO/IEC 25010 visto en clase.
Este paso es la **continuación natural** del paso 4 de la guía base (`Sonar_local_or_cloud/<local|cloud>/04_INTERPRETAR_RESULTADOS.md`): los filtros del panel **Issues** (`Type`, `Severity`, `Status`, `File`, `Rule`) son exactamente los mismos; lo único que cambia es que ahora, además de los hallazgos nativos de Sonar, verás también los aportados por Bandit.
> 🧭 **Aplica a los dos escenarios.** La UI y los nombres de regla (`external_bandit:Bxxx`) son idénticos en **SonarQube Server local (Docker)** y en **SonarCloud**. Lo único que cambia es el dominio del dashboard y, en SonarCloud, que el `projectKey` lleva el prefijo de la organización (`TU_PROJECT_KEY`, normalmente con formato `<org>_vulnerable-api`).
---
## 1. Comparación Antes / Después
Esta es la diapositiva más importante del demo. En el dashboard de Sonar:
```
┌────────────────────────────────────────────────────────────────┐
│ Después de Bandit (Sonar + integración SAST) │
├────────────────────────────────────────────────────────────────┤
│ 🐛 Bugs: 1 │
│ 🔒 Vulnerabilities: 5+ ✅ ¡Ahora sí se ven! │
│ ├─ CRITICAL: B201 Flask debug=True │
│ ├─ MAJOR: B608 SQL Injection (sqli.py:16) │
│ ├─ MAJOR: B701 Jinja2 autoescape=False (ssti.py) │
│ ├─ MAJOR: B310 urllib remote include (rfi.py) │
│ └─ MAJOR: B704 unescaped output (xss.py) │
│ 🛡️ Security Hotspots: ~3 │
│ 💩 Code Smells: ~19 (Bandit añadió los LOW) │
└────────────────────────────────────────────────────────────────┘
```
> 💡 **Mensaje pedagógico:** ni Sonar Community ni SonarCloud free son "malos" — están hechos para *quality*, no para *security testing avanzado* (el *taint analysis* es feature de pago en ambos). Lo correcto en un pipeline real es **combinar herramientas**: cada una tiene un foco distinto.
---
## 2. Filtrar Issues por Tipo
Este es **exactamente el mismo flujo** que la sección 3 del paso 4 de la guía base (`04_INTERPRETAR_RESULTADOS.md`): vas a la pestaña **Issues** y usas el panel de filtros del lado izquierdo. La diferencia es que ahora, al filtrar por `Type → Vulnerability`, además de los hallazgos nativos de Sonar verás los que Bandit aportó como *External Issues*.
Pasos:
1. **Abre el dashboard de Sonar** según tu entorno:
 - **Server local (Docker):** `http://localhost:9000/dashboard?id=vulnerable-api`
 - **SonarCloud:** `https://sonarcloud.io/dashboard?id=TU_PROJECT_KEY`
2. **Entra a la pestaña `Issues`** del proyecto:
 - **Server local (Docker):** `http://localhost:9000/project/issues?id=vulnerable-api`
 - **SonarCloud:** `https://sonarcloud.io/project/issues?id=TU_PROJECT_KEY`
3. En el panel izquierdo de filtros, ubica el criterio **`Type`** y **selecciona `Vulnerability`** (el mismo filtro Type → {Bug, Vulnerability, Code Smell, Security Hotspot} descrito en la tabla del paso 4 de la guía base). La lista central se actualizará para mostrar solo los hallazgos clasificados como vulnerabilidad.
4. (Opcional) Combina con el filtro **`Severity`** (Blocker, Critical, Major, Minor, Info) para priorizar primero los `CRITICAL` y `MAJOR`.
5. **Haz clic en cada hallazgo** y revisa el detalle en el panel derecho. Los aportados por Bandit se reconocen por la marca **`Detected by: bandit`** y por el `Rule` con prefijo **`external_bandit:Bxxx`** (p. ej. `external_bandit:B608`).
> 💡 **¿Por qué `Type` y no `Rule`?** El filtro `Rule` *sí* funciona en SonarCloud (puedes escribir `external_bandit` y autocompleta cada `Bxxx`), pero en **SonarQube Server local (Docker)** no devuelve resultados para issues externos. Para que la guía sea idéntica en ambos escenarios — igual que la guía base — usamos siempre **`Type → Vulnerability`** y confirmamos la procedencia en el detalle del issue.
Listado de reglas Bandit que aparecerán con la marca en el detalle de cada issue:
| Rule key (en Sonar) | Bandit ID | Descripción |
|---|---|---|
| `external_bandit:B201` | B201 | flask_debug_true |
| `external_bandit:B608` | B608 | hardcoded_sql_expressions |
| `external_bandit:B701` | B701 | jinja2_autoescape_false |
| `external_bandit:B704` | B704 | markupsafe / xss vector |
| `external_bandit:B310` | B310 | urllib_urlopen with user input |
| `external_bandit:B105` | B105 | hardcoded_password_string |
| `external_bandit:B110` | B110 | try_except_pass |
---
## 3. Anatomía de un Issue Externo
Haz clic en cualquier hallazgo con `Rule: external_bandit:Bxxx`. La estructura del panel derecho es **la misma** que la del paso 4 de la guía base (`[VULNERABILITY] ... | severidad | archivo:línea | Why is this an issue? | How to fix it`), con dos diferencias propias de los *External Issues*:
```
┌─────────────────────────────────────────────────────────────┐
│ [VULNERABILITY] Possible SQL injection vector through │
│ string-based query construction │
│ MAJOR │
│ │
│ sqli.py, line 16 │
│ │
│ 16 │ cur.execute(f"SELECT * FROM USERS WHERE │
│ │ USERNAME='{username}'") │
│ │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ │
│ │
│ Why is this an issue? │
│ Possible SQL injection vector through string-based query │
│ construction. — More info: B608 │
│ │
│ External issue │
│ Detected by: bandit │
│ Rule: external_bandit:B608 │
│ │
│ Tags: external │
└─────────────────────────────────────────────────────────────┘
```
**Diferencias frente a un issue nativo de Sonar (las que viste en la guía base):**
1. El campo **`External issue` / `Detected by: bandit`** identifica el origen — los issues nativos no lo tienen.
2. **No hay sección "How to fix it" automática** (a diferencia de las reglas nativas mostradas en el paso 4 de la guía base). Para guía de remediación, abre el [link al CWE](https://cwe.mitre.org/data/definitions/89.html) o la [doc de la regla en Bandit](https://bandit.readthedocs.io/en/latest/plugins/b608_hardcoded_sql_expressions.html).
---
## 4. Mapeo Vulnerabilidad → Archivo en `Vulnerable-API`
Recorrido completo del demo (usa esta tabla en clase):
| Vulnerabilidad OWASP | Archivo | Línea | Regla Bandit | Severidad |
|---|---|---|---|---|
| **A03 Injection — SQLi** | [sqli.py](../sqli.py) | 16 | B608 | MAJOR |
| **A03 Injection — SSTI** | [ssti.py](../ssti.py) | — | B701 / B704 | MAJOR |
| **A03 Injection — XSS** | [xss.py](../xss.py) | — | B704 | MAJOR |
| **A01 BAC — LFI** | [lfi.py](../lfi.py) | — | (parcial) | MINOR |
| **A10 SSRF — RFI** | [rfi.py](../rfi.py) | — | B310 | MAJOR |
| **A05 Misconfig — Debug ON** | [app.py](../app.py) | 24 | B201 | CRITICAL |
| **A05 Misconfig — except: pass** | [app.py](../app.py) | 7-9 | B110 | MINOR |
> ℹ️ **Caso interesante:** la vulnerabilidad de **HOST Header Injection** ([hhi.py](../hhi.py)) no está cubierta por una regla específica de Bandit. Esto demuestra que **ni siquiera dos herramientas combinadas son suficientes** — siempre hay huecos. Se recomienda complementar con:
> - **Pruebas dinámicas (DAST)** — p. ej., OWASP ZAP.
> - **Code review humano**.
> - **Otras SAST** como Semgrep (ver paso 10).
---
## 5. Mapeo a ISO/IEC 25010
Continuando la tabla del paso 4 (`04_INTERPRETAR_RESULTADOS.md`), ahora con los hallazgos de Bandit:
| Característica ISO 25010 | Sub-característica | Métricas Sonar | Aporte de Bandit |
|---|---|---|---|
| **Seguridad** | Confidencialidad | Vulnerabilities | ✅ SQLi, SSTI, XSS, RFI (que Sonar Community no veía) |
| **Seguridad** | Integridad | Vulnerabilities | ✅ Inyecciones que permitirían modificar datos |
| **Seguridad** | No-repudio | (no cubierto) | ⚠️ Requiere logs y auditoría |
| **Seguridad** | Responsabilidad | Hotspots | Parcial |
| **Seguridad** | Autenticidad | Vulnerabilities | ✅ Hardcoded credentials (B105/B106) |
| **Fiabilidad** | Tolerancia a fallos | Bugs | ✅ B110 (`except: pass` oculta errores) |
| **Mantenibilidad** | Analizabilidad | Code Smells | ✅ Bandit aporta los LOW |
---
## 6. Exportar Resultados Combinados
### Opción A — Vía API de Sonar (incluye Bandit)
La API es idéntica en Server local y SonarCloud (es la misma `/api/issues/search` que usaste en la sección 8 del paso 4 de la guía base); solo cambian el host base y el `projectKey`. Para evitar duplicar comandos, exporta dos variables:
```bash
# Server local (Docker)
export SONAR_HOST_URL="http://localhost:9000"
export SONAR_PROJECT_KEY="vulnerable-api"
# — o bien — SonarCloud
export SONAR_HOST_URL="https://sonarcloud.io"
export SONAR_PROJECT_KEY="TU_PROJECT_KEY"
# Mismo curl para los dos escenarios:
curl -u "${SONAR_TOKEN}:" \
 "${SONAR_HOST_URL}/api/issues/search?projectKeys=${SONAR_PROJECT_KEY}&ps=500&rules=external_bandit" \
 | python3 -m json.tool > issues-bandit.json
```
> 🔑 En **SonarCloud** la autenticación también admite `-H "Authorization: Bearer ${SONAR_TOKEN}"` como alternativa al esquema `user:password` con el token en el usuario.
### Opción B — JSON nativo de Bandit (más legible)
Ya lo tienes: `bandit-report.json`. Si quieres una versión HTML para incluir en la entrega:
```bash
bandit -r . -c pyproject.toml -f html -o bandit-report.html
```
### Opción C — Markdown para reportes
```bash
bandit -r . -c pyproject.toml -f screen -o bandit-summary.txt
```
---
## 7. Preguntas de Reflexión para el Laboratorio
1. **¿Cuántas vulnerabilidades nuevas apareció después de añadir Bandit?** Cita la métrica antes/después del dashboard.
2. **Identifica una vulnerabilidad que Sonar Community SÍ marcó (como Hotspot) y Bandit elevó a Vulnerability.** ¿Por qué la diferencia de clasificación?
3. **La regla `B608` (SQLi) tiene confianza `LOW` en Bandit. ¿Por qué LOW si el código es claramente vulnerable?** Pista: Bandit es un análisis sintáctico, no de *taint*; no puede saber si `username` realmente viene del usuario o de una constante. Reflexiona sobre los falsos positivos en SAST.
4. **¿Qué vulnerabilidad de `Vulnerable-API` no fue detectada por NINGUNA de las dos herramientas?** ¿Cómo la detectarías tú? (sugerencias: DAST, fuzzing, code review).
5. **Costo vs. beneficio:** ¿Vale la pena pagar SonarQube Developer (con taint analysis) si Bandit es gratis y cubre lo mismo para Python? Argumenta considerando: lenguajes soportados, falsos positivos, mantenibilidad del pipeline.
---
## 🔧 Solución de Problemas Comunes
| Problema | Causa probable | Solución |
|---|---|---|
| Filtro `Rule = external_bandit` no muestra resultados en Server local (Docker) | Comportamiento conocido del filtro `Rule` con issues externos en Docker | Filtra por `Type = Vulnerability` (el mismo filtro descrito en el paso 4 de la guía base) y verifica la marca *Detected by: bandit* en el panel derecho (ver Sección 2) |
| No aparece ninguna vulnerabilidad de Bandit (ni con filtro de Type) | El sensor de Bandit no corrió | Vuelve al paso 8 y verifica el log "Sensor Bandit Sensor" |
| Las severidades parecen mal mapeadas | Distinto criterio Bandit vs. Sonar | Es esperado: Bandit `LOW` → Sonar `Code Smell`, no `Vulnerability` |
| Hallazgos en archivos que NO existen | Path relativo distinto | Re-ejecuta `bandit` desde la raíz del repo (no desde `Docs/`) |
| Cambios en código no se reflejan (Server local) | Cache del scanner | `rm -rf .scannerwork/` y vuelve a correr `./scan.sh local` (o `./scan.sh cloud`) |
| Cambios en código no se reflejan (SonarCloud) | Análisis aún en cola en la nube | Espera 1-2 min; revisa `https://sonarcloud.io/project/activity?id=<projectKey>` |
| Dashboard muestra "Project not found" | URL apunta al entorno equivocado | Confirma que `sonar.host.url` y `sonar.projectKey` corresponden al entorno donde sí existe el proyecto |
---
## ✅ Verificación del Paso 9
```
[ ] Filtro "Type → Vulnerability" aplicado en la pestaña Issues (mismo flujo que el paso 4 de la guía base)
[ ] Identifiqué al menos 5 hallazgos con la marca "Detected by: bandit" (Rule: external_bandit:Bxxx)
[ ] Comparé el dashboard antes/después y noté el aumento de Vulnerabilities
[ ] Tabla de mapeo vulnerabilidad-archivo completa
[ ] Respondí las preguntas de reflexión de la Sección 7
[ ] Generé al menos un reporte exportable (JSON, HTML o CSV)
[ ] Identifiqué qué vulnerabilidades NO fueron detectadas por ninguna herramienta
```
---
## ➡️ Siguiente Paso
**📄 `10_TROUBLESHOOTING_Y_SIGUIENTES_PASOS.md`** → Errores comunes de la integración completa, ideas para extender el laboratorio (Semgrep, CI/CD, pre-commit hooks) y limpieza final del entorno.
---
## 📚 Referencias
- [SonarQube Server — External Issues](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/external-analyzer-reports/)
- [SonarCloud — External Analyzer Reports](https://docs.sonarsource.com/sonarcloud/enriching/external-analyzer-reports/)
- [SonarCloud — Web API (`/api/issues/search`)](https://sonarcloud.io/web_api/api/issues/search)
- [Bandit Plugins (referencia de cada regla)](https://bandit.readthedocs.io/en/latest/plugins/index.html)
