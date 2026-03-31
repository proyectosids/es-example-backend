# Backend Roadmap de Ejecución (SaaS RBAC/Org)

Fecha: 2026-03-28  
Estado: activo

## 1. Paso 1: Pruebas E2E de BE-2 especializado

Objetivo:
- validar los endpoints:
  - `POST /api/v1/field-admin/pastors`
  - `POST /api/v1/church-admin/sabbath-directors`
  - `POST /api/v1/church-admin/small-group-leaders`
- validar respuestas esperadas:
  - `201` caso correcto
  - `403` actor sin alcance/rol correcto
  - `409` asignación duplicada

Entregables:
- script ejecutable de pruebas
- evidencia de resultados por caso

Estado:
- iniciado
- script preparado en `scripts/e2e_be2_step1.ps1`
- ejecución iniciada: 2026-03-28
- resultado actual: backend no disponible en `http://localhost:3000` durante health check
- reintento exitoso con runner automático: `scripts/e2e_be2_step1_auto.mjs`
- resultado final paso 1: `ok=9`, `fail=0`
- evidencia validada:
  - A1/A2/A3 (`field-admin/pastors`) => `201/409/403`
  - B1/B2/B3 (`church-admin/sabbath-directors`) => `201/409/403`
  - C1/C2/C3 (`church-admin/small-group-leaders`) => `201/409/403`

Comando de ejecución:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/e2e_be2_step1.ps1
```

Variables requeridas:

- `E2E_FIELD_EMAIL`
- `E2E_FIELD_PASS`
- `E2E_PASTOR_EMAIL`
- `E2E_PASTOR_PASS`
- `E2E_DIRECTOR_EMAIL`
- `E2E_DIRECTOR_PASS`
- `E2E_MEMBER_EMAIL`
- `E2E_MEMBER_PASS`
- `E2E_CHURCH_ID`
- `E2E_SMALL_GROUP_ID`
- `E2E_MEMBER_USER_ID`

Nota:
- para ejecución sin variables manuales se agregó `scripts/e2e_be2_step1_auto.mjs`, que:
  - auto-bootstrap de actores/scopes E2E
  - ejecuta los 9 casos esperados.

## 2. Paso 2: Ventanas por trimestre (QuarterlyMembershipPolicy)

Objetivo:
- habilitar ventana de cambio de grupo por trimestre
- bloquear altas/cambios fuera de ventana

Entregables:
- lógica de validación en endpoints de membresía
- respuestas de negocio consistentes (`409` / `422`)

Estado:
- completado
- enforcement agregado en `POST /api/v1/me/small-group-change-requests`
- enriquecimiento agregado en `GET /api/v1/me/small-group-membership`
- endpoint administrativo agregado:
  - `GET /api/v1/admin/quarterly-membership-policy/:quarterlyId`
  - `PUT /api/v1/admin/quarterly-membership-policy/:quarterlyId`
- script E2E agregado: `scripts/e2e_be3_step2_policy.mjs`
- resultado final paso 2: `ok=12`, `fail=0`

Casos validados:
- política futura: bloquea con `422`
- política abierta + aprobación requerida: crea `PENDING`
- política cerrada: bloquea con `422`
- política abierta + `requireLeaderApproval=false`: crea `APPROVED`

## 3. Paso 3: Auditoría mínima

Objetivo:
- registrar eventos críticos:
  - alta de usuario administrativo
  - asignación de rol
  - aprobación/rechazo de membresía de grupo pequeño

Entregables:
- tabla de auditoría
- helper/repo de escritura de eventos
- inclusión en endpoints críticos

Estado:
- completado
- migración agregada: `src/db/scritp_db/migration_be3_audit_events.sql`
- repositorio agregado: `src/repos/audit.repo.js`
- helper seguro agregado: `src/utils/audit.js`
- instrumentación aplicada en:
  - `POST /api/v1/users`
  - `POST /api/v1/users/:userId/roles`
  - `POST /api/v1/field-admin/pastors`
  - `POST /api/v1/church-admin/sabbath-directors`
  - `POST /api/v1/church-admin/small-group-leaders`
  - `POST /api/v1/small-groups/:smallGroupId/membership-requests/:requestId/approve`
  - `POST /api/v1/small-groups/:smallGroupId/membership-requests/:requestId/reject`
- script E2E agregado: `scripts/e2e_be4_step3_audit.mjs`
- resultado final paso 3: `ok=11`, `fail=0`

Eventos auditados:
- `ADMIN_USER_CREATED`
- `ROLE_ASSIGNED`
- `SMALL_GROUP_MEMBERSHIP_APPROVED`
- `SMALL_GROUP_MEMBERSHIP_REJECTED`

## 4. Paso 4: Integración frontend incremental

Objetivo:
- conectar frontend con registro público jerárquico
- conectar flujo de aprobación de grupo pequeño para líderes/directores

Entregables:
- llamadas API integradas sin romper lectura/offline actual
- guardas de pantalla por `me/screens`

## 5. Paso 5: Hardening

Objetivo:
- endurecer seguridad y operación:
  - rate limit login/registro
  - estandarización de errores
  - pruebas automáticas de permisos por alcance

Entregables:
- middleware de límite de tasa
- catálogo de códigos de error
- suite base automatizada
