# 📖 Guía Extendida: Complementar SonarQube con Bandit (SAST)
### Asignatura: Modelos de Evaluación de Software
### Repositorio bajo análisis: `michealkeines/Vulnerable-API`
---
## ¿Por qué esta guía existe?
Esta guía es una **extensión** de la guía base `fca-lia-mes-evaluacion-codigo`
La guía base te lleva del paso **00 al 04**: instalación de SonarQube en Docker o la opción de sonar Cloud, generación de token, escaneo del repo y lectura del dashboard.
Al terminar el paso 04 te encuentras con que **ni SonarQube Community Edition (Docker) ni SonarCloud free detectan vulnerabilidades de seguridad reales** (SQLi, SSTI, XSS…) porque el motor de *taint analysis* es exclusivo de las ediciones Developer / planes pagos.
Esta guía cubre los pasos **05 al 09**, que añaden **Bandit** (SAST gratuito y open source) como complemento, para que las inyecciones del repo `Vulnerable-API` finalmente aparezcan en el dashboard — tanto en el escenario **SonarQube Server local (Docker)** como en **SonarCloud**.

> **Nota de aclaración:** Esta guía extendida asume que ya has completado los pasos 00 al 04 de la guía base y tienes el repositorio `michealkeines/Vulnerable-API` clonado localmente. Este repositorio actual (`fca-bandit-sonar`) es únicamente de documentación y contiene los archivos de configuración necesarios (como `scan.ps1`, `scan.sh`, `sonar-project.properties` y `requirements-dev.txt`) que debes copiar y pegar manualmente en tu repositorio clonado del paso anterior para integrar Bandit con SonarQube.

---
## 📚 Índice de la Guía Extendida
| Archivo | Contenido | Tiempo estimado |
|---|---|---|
| [ARQUITECTURA.md](ARQUITECTURA.md) | Material de apoyo: stack tecnológico, estructura de carpetas, flujo de una petición y propósito de cada componente del repo `Vulnerable-API`. Consúltalo para tener contexto técnico mientras avanzas por los pasos 05–09. | 15 min (lectura) |
| [05_INSTALAR_BANDIT.md](05_INSTALAR_BANDIT.md) | Crear `.venv`, `requirements-dev.txt` e instalar Bandit | 10 min |
| [06_CONFIGURAR_BANDIT.md](06_CONFIGURAR_BANDIT.md) | `pyproject.toml` con exclusiones y reglas | 10 min |
| [07_INTEGRAR_BANDIT_SONARQUBE.md](07_INTEGRAR_BANDIT_SONARQUBE.md) | Modificar `sonar-project.properties` (Server local / SonarCloud) y mover el token a env var | 15 min |
| [08_EJECUTAR_ESCANEO_COMBINADO.md](08_EJECUTAR_ESCANEO_COMBINADO.md) | Script `scan.sh` / `scan.ps1` que encadena Bandit + sonar-scanner (válido para ambos entornos) | 15 min |
| [09_INTERPRETAR_RESULTADOS_BANDIT.md](09_INTERPRETAR_RESULTADOS_BANDIT.md) | Filtrar issues por `Type = Vulnerabilities`, identificar la marca *Detected by: bandit* y mapear a CWE / ISO 25010 | 20 min |
> ⚠️ **Sigue los archivos numerados en orden.** Cada paso depende del estado dejado por el anterior.
>
> 📎 **[ARQUITECTURA.md](ARQUITECTURA.md)** es material de apoyo, no un paso del flujo: puedes leerlo antes de empezar o consultarlo puntualmente cuando necesites contexto técnico sobre el repo bajo análisis.
---
## 🔄 Posición de esta guía dentro del flujo completo
```
   ┌─────────────────────────────────────────────────────┐
   │  Guía base (otro repo)                              │
   │  ─────────────────────────────────────              │
   │  00 — Índice y prerequisitos                        │
   │  01 — Setup Docker + SonarQube                      │
   │  02 — Generar token                                 │
   │  03 — Clonar y escanear                             │
   │  04 — Interpretar resultados                        │
   └─────────────────────┬───────────────────────────────┘
                         │
                         │ ⚠️  "¿Por qué Sonar no ve mi SQLi?"
                         ▼
   ┌─────────────────────────────────────────────────────┐
   │  Guía extendida (este Docs/)                        │
   │  ─────────────────────────────────────              │
   │  05 — Instalar Bandit                               │
   │  06 — Configurar Bandit                             │
   │  07 — Integrar Bandit con SonarQube / SonarCloud    │
   │  08 — Ejecutar el escaneo combinado                 │
   │  09 — Interpretar resultados de Bandit              │
   └─────────────────────────────────────────────────────┘
```
---
## 🧰 Prerequisitos
Antes de empezar el paso 05, debes haber completado los pasos **00–04** de la guía base, en cualquiera de los dos escenarios soportados:
### Opción A — SonarQube Server local (Docker)
```
[ ] SonarQube corriendo en http://localhost:9000
[ ] Proyecto "vulnerable-api" creado en SonarQube
[ ] Token generado en http://localhost:9000/account/security (SONAR_TOKEN)
[ ] sonar-scanner CLI instalado y en PATH
[ ] Repo Vulnerable-API clonado localmente
[ ] Primer escaneo con sonar-scanner ejecutado al menos una vez
```
### Opción B — SonarCloud
```
[ ] Cuenta y organización creadas en https://sonarcloud.io
[ ] Proyecto importado con projectKey "<org>_vulnerable-api"
[ ] Token generado en https://sonarcloud.io/account/security (SONAR_TOKEN)
[ ] sonar-scanner CLI instalado y en PATH
[ ] Repo Vulnerable-API clonado localmente
[ ] Primer escaneo con sonar-scanner ejecutado al menos una vez
```
Adicional para esta guía:
```
[ ] Python 3.8+ instalado
[ ] pip funcionando
```
## Archivos de configuración a copiar
Para integrar Bandit con SonarQube, copia y pega manualmente los siguientes archivos desde este repositorio (`fca-bandit-sonar`) al directorio raíz de tu repositorio clonado `michealkeines/Vulnerable-API`:
- `scan.ps1` (para Windows)
- `scan.sh` (para Linux/Mac)
- `sonar-project.properties`
- `requirements-dev.txt`
Asegúrate de que estos archivos estén en el directorio raíz del repo `/Vulnerable-API`.
---


## 🎯 Qué aprenderás
Al terminar el paso 09:
1. **Comprenderás los límites de Sonar Community / SonarCloud free** y por qué hace falta complementarlos en proyectos con código sensible.
2. Sabrás **integrar dos herramientas SAST** (Sonar + Bandit) en un único dashboard, sin duplicar trabajo, tanto en Server local (Docker) como en SonarCloud.
3. Tendrás un **script reutilizable** (`scan.sh` / `scan.ps1`) que automatiza el escaneo combinado y funciona para ambos entornos.
4. Sabrás **localizar las vulnerabilidades aportadas por Bandit** en el dashboard usando el filtro `Type = Vulnerabilities` y la marca *Detected by: bandit*.
5. Podrás **mapear vulnerabilidades a CWE y a ISO/IEC 25010** — competencia clave de la asignatura.
---
## ➡️ Empezar
**📄 [05_INSTALAR_BANDIT.md](05_INSTALAR_BANDIT.md)** → Instalación y primera corrida de Bandit.
---
## 📚 Referencias generales
- 🔗 Guía base: adanestrada/fca-lia-mes-evaluacion-codigo
- 🔗 Repo bajo análisis: https://github.com/michealkeines/Vulnerable-API
- 🔗 Bandit: https://bandit.readthedocs.io/
- 🔗 SonarQube docs: https://docs.sonarsource.com/sonarqube/
- 🔗 OWASP Top 10: https://owasp.org/www-project-top-ten/
- 🔗 ISO/IEC 25010: https://iso25000.com/index.php/normas-iso-25000/iso-25010
