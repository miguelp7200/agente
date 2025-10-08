# 🔧 Guía de Operaciones - Invoice Chatbot Backend

**Proyecto**: Invoice Chatbot Backend  
**Cliente**: Gasco  
**Versión**: 1.0  
**Fecha**: Octubre 2025  
**Audiencia**: Soporte L1/L2/L3, SRE, DevOps

---

## 🎯 Visión General

Esta guía proporciona procedimientos operacionales completos para **monitorear, mantener y resolver problemas** del Invoice Chatbot Backend en producción.

### Alcance Operacional

| Área | Componentes | Responsabilidad |
|------|-------------|-----------------|
| **Monitoreo** | Cloud Run, BigQuery, GCS, Gemini API | Detectar anomalías y degradación |
| **Troubleshooting** | Logs, métricas, traces | Diagnosticar y resolver issues |
| **Mantenimiento** | Updates, backups, limpieza | Mantener salud del sistema |
| **Soporte** | Tickets, escalamiento, documentación | Atender incidentes de usuarios |

### Servicios Bajo Operación

```
📊 SISTEMA COMPLETO
├── 🤖 ADK Agent (Cloud Run)
│   ├── Gemini 2.5 Flash (IA conversacional)
│   ├── Temperature 0.3 (producción)
│   └── Thinking Mode OFF (velocidad)
│
├── 🔧 MCP Toolbox (49 herramientas)
│   ├── BigQuery operations
│   ├── Invoice search & analytics
│   └── ZIP package creation
│
├── 📄 PDF Server (signed URLs)
│   ├── GCS proxy (miguel-test bucket)
│   ├── ZIP generation (agent-intelligence-zips)
│   └── URL validation & stability
│
└── 💾 Data Layer
    ├── BigQuery (6,641 facturas 2017-2025)
    ├── GCS buckets (PDFs + ZIPs)
    └── Conversation logs (analytics)
```

---

## 📊 Monitoreo del Sistema

### 1. Health Checks Críticos

#### Health Check Principal

**Endpoint**: `GET /list-apps`  
**URL Producción**: `https://invoice-backend-819133916464.us-central1.run.app/list-apps`

**Validación básica**:
```bash
# Health check simple
curl https://invoice-backend-819133916464.us-central1.run.app/list-apps

# Esperado:
{
  "apps": ["gcp-invoice-agent-app"]
}

# Con autenticación (Cloud Run)
TOKEN=$(gcloud auth print-identity-token)
curl -H "Authorization: Bearer $TOKEN" \
  https://invoice-backend-819133916464.us-central1.run.app/list-apps
```

**Estado del servicio**:
- ✅ **200 OK + JSON válido**: Sistema operacional
- ⚠️ **500 Internal Error**: ADK agent con problemas
- ❌ **502/503/504**: Cloud Run o MCP Toolbox no responden
- ❌ **Connection timeout**: Servicio no disponible

#### Health Check Detallado

**Test de sesión completa**:
```powershell
# Script: scripts/health_check_detailed.ps1
$token = gcloud auth print-identity-token
$sessionId = "health-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$url = "https://invoice-backend-819133916464.us-central1.run.app/run"

$body = @{
    appName = "gcp-invoice-agent-app"
    userId = "health-check"
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{ text = "dame las últimas 5 facturas" })
        role = "user"
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
  -Uri $url `
  -Method POST `
  -Headers @{ 
      "Authorization" = "Bearer $token"
      "Content-Type" = "application/json"
  } `
  -Body $body `
  -TimeoutSec 60
```

**Validaciones**:
- ✅ Respuesta en <60 segundos
- ✅ JSON válido con facturas
- ✅ PDFs signed URLs generadas
- ✅ Sin errores en response

---

### 2. Métricas de Cloud Run

#### Acceso a Métricas

**Cloud Console**:
```
URL: https://console.cloud.google.com/run/detail/us-central1/invoice-backend?project=agent-intelligence-gasco

Tabs importantes:
├── METRICS (principal)
├── LOGS (troubleshooting)
├── REVISIONS (deployment history)
└── YAML (configuration)
```

#### Métricas Críticas para Monitorear

| Métrica | Threshold Normal | Alerta | Crítico |
|---------|------------------|--------|---------|
| **Request Count** | 10-100/min | >500/min | >1000/min |
| **Request Latency P95** | <60s | >90s | >120s |
| **Error Rate** | <2% | >5% | >10% |
| **Instance Count** | 1-3 | >5 | >8 |
| **CPU Utilization** | <60% | >80% | >95% |
| **Memory Usage** | <3GB | >3.5GB | >3.8GB |
| **Container Startup Time** | <30s | >60s | >90s |

#### Ver Métricas vía gcloud

```bash
# Request count (última hora)
gcloud monitoring time-series list \
  --filter='resource.type="cloud_run_revision" AND 
            metric.type="run.googleapis.com/request_count" AND 
            resource.labels.service_name="invoice-backend"' \
  --format="table(metric.labels.response_code_class, points[0].value)" \
  --project=agent-intelligence-gasco

# Latencia P95
gcloud monitoring time-series list \
  --filter='resource.type="cloud_run_revision" AND 
            metric.type="run.googleapis.com/request_latencies"' \
  --format="value(points[0].value)" \
  --project=agent-intelligence-gasco
```

---

### 3. Logs Estructurados

#### Tipos de Logs

El sistema genera logs estructurados con prefijos específicos:

| Prefijo | Componente | Propósito |
|---------|------------|-----------|
| **📊** | Token Tracking | Monitoreo de consumo Gemini API |
| **🔧** | GCS Stability | Signed URLs y clock skew |
| **✅** | Success Operations | Operaciones exitosas |
| **❌** | Errors | Errores y excepciones |
| **⚠️** | Warnings | Advertencias y degradaciones |
| **🎯** | Business Logic | Decisiones de negocio |
| **🔍** | Debug | Información de debugging |

#### Consultar Logs

**Ver logs en tiempo real**:
```bash
# Logs streaming (tiempo real)
gcloud run services logs tail invoice-backend \
  --region=us-central1 \
  --project=agent-intelligence-gasco

# Solo errores
gcloud run services logs tail invoice-backend \
  --region=us-central1 \
  --filter="severity>=ERROR"

# Solo warnings y errores
gcloud run services logs tail invoice-backend \
  --region=us-central1 \
  --filter="severity>=WARNING"
```

**Logs históricos**:
```bash
# Últimas 100 líneas
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --limit=100

# Logs de las últimas 2 horas
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="timestamp>='$(date -u -d '2 hours ago' --iso-8601=seconds)'"

# Logs de sesión específica
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:session-20251006-140000"
```

#### Logs Críticos para Monitorear

**1. Token tracking (costos)**:
```bash
# Buscar logs de token usage
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:📊" \
  --limit=20
```

**Ejemplo de log esperado**:
```
📊 Token usage: prompt=1500, candidates=3200, total=4700
📊 Text metrics: question_chars=85, response_chars=12450
```

**2. GCS signed URLs (estabilidad)**:
```bash
# Buscar problemas con signed URLs
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:SignatureDoesNotMatch OR textPayload:clock skew" \
  --limit=50
```

**3. MCP Tool errors**:
```bash
# Errores de herramientas MCP
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="severity>=ERROR AND textPayload:toolbox" \
  --limit=20
```

**4. BigQuery query errors**:
```bash
# Errores de BigQuery
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="severity>=ERROR AND textPayload:BigQuery" \
  --limit=20
```

---

### 4. Alertas Recomendadas

#### Cloud Monitoring Policies

**Configurar alertas en Cloud Console**:
```
URL: https://console.cloud.google.com/monitoring/alerting?project=agent-intelligence-gasco
```

#### Alertas Críticas (L1)

**1. Error Rate Alto**:
```yaml
Condition: Error rate > 5%
Duration: 5 minutes
Notification: Email + PagerDuty
Severity: Critical
```

**2. Latency Excesiva**:
```yaml
Condition: P95 latency > 90 seconds
Duration: 10 minutes
Notification: Email + Slack
Severity: Warning
```

**3. Service Down**:
```yaml
Condition: Uptime check fails 3 consecutive times
Duration: 3 minutes
Notification: Email + PagerDuty + SMS
Severity: Critical
```

**4. Memory Near Limit**:
```yaml
Condition: Memory usage > 90%
Duration: 5 minutes
Notification: Email
Severity: Warning
```

#### Alertas de Negocio (L2)

**5. Token Usage Spike**:
```yaml
Condition: Total tokens > 10M in 1 hour
Duration: 1 hour
Notification: Email
Severity: Info
Reason: Posible uso inusual o ataque
```

**6. Zero Requests**:
```yaml
Condition: Request count = 0
Duration: 15 minutes
Notification: Email + Slack
Severity: Warning
Reason: Posible problema de conectividad
```

**7. High Instance Count**:
```yaml
Condition: Active instances > 5
Duration: 30 minutes
Notification: Email
Severity: Info
Reason: Carga inusual o leak de recursos
```

---

### 5. Monitoreo de Costos

#### Gemini API Token Usage

**Query BigQuery para costos diarios**:
```sql
-- Costos diarios por Gemini API
SELECT
  DATE(timestamp) as date,
  COUNT(*) as total_queries,
  SUM(prompt_token_count) as total_input_tokens,
  SUM(candidates_token_count) as total_output_tokens,
  SUM(total_token_count) as total_tokens,
  
  -- Estimación de costos ($0.075/1M input, $0.30/1M output)
  ROUND(SUM(prompt_token_count) * 0.075 / 1000000, 4) as estimated_input_cost_usd,
  ROUND(SUM(candidates_token_count) * 0.30 / 1000000, 4) as estimated_output_cost_usd,
  ROUND((SUM(prompt_token_count) * 0.075 + SUM(candidates_token_count) * 0.30) / 1000000, 4) as total_cost_usd
FROM
  `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND total_token_count IS NOT NULL
GROUP BY
  date
ORDER BY
  date DESC;
```

**Top conversaciones costosas**:
```sql
-- Identificar conversaciones con mayor consumo de tokens
SELECT
  session_id,
  user_id,
  COUNT(*) as messages_count,
  SUM(total_token_count) as total_tokens,
  ROUND(SUM(total_token_count) * 0.15 / 1000000, 4) as estimated_cost_usd,
  MAX(timestamp) as last_activity
FROM
  `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND total_token_count IS NOT NULL
GROUP BY
  session_id,
  user_id
HAVING
  total_tokens > 100000  -- Solo conversaciones costosas
ORDER BY
  total_tokens DESC
LIMIT 20;
```

#### Cloud Run Costs

**Ver costos estimados**:
```bash
# Cloud Billing report
# URL: https://console.cloud.google.com/billing/reports?project=agent-intelligence-gasco

# Filtrar por:
# - Service: Cloud Run
# - Resource: invoice-backend
# - Time range: Last 30 days
```

**Factores de costo Cloud Run**:
- ⚡ **CPU time**: 4 vCPU × tiempo activo
- 💾 **Memory**: 4GB × tiempo activo
- 📊 **Request count**: Número de invocaciones
- 🌐 **Network egress**: Tráfico saliente (PDFs, ZIPs)

---

## 🔍 Troubleshooting

### Procedimientos de Diagnóstico

#### Nivel 1: Quick Checks (5 minutos)

**1. Verificar health check**:
```bash
curl https://invoice-backend-819133916464.us-central1.run.app/list-apps
```

**2. Ver últimos errores**:
```bash
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="severity>=ERROR" \
  --limit=10
```

**3. Verificar instancias activas**:
```bash
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format="value(status.conditions)"
```

**4. Ver métricas básicas (último hora)**:
```bash
# Error rate
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=invoice-backend AND severity>=ERROR" \
  --limit=10 \
  --freshness=1h
```

#### Nivel 2: Deep Dive (15 minutos)

**1. Analizar patrón de errores**:
```bash
# Agrupar errores por tipo
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="severity>=ERROR AND timestamp>='$(date -u -d '1 hour ago' --iso-8601=seconds)'" \
  --format="value(textPayload)" | \
  sort | uniq -c | sort -rn
```

**2. Verificar revisiones activas**:
```bash
# Ver qué revisión está recibiendo tráfico
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format="table(status.traffic[].revisionName, status.traffic[].percent)"
```

**3. Verificar configuración**:
```bash
# Ver environment variables actuales
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format="value(spec.template.spec.containers[0].env)"
```

**4. Test de componente específico**:
```powershell
# Test MCP Toolbox
$body = @{
    appName = "gcp-invoice-agent-app"
    userId = "test"
    sessionId = "diag-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    newMessage = @{
        parts = @(@{ text = "dame la factura 0022792445" })
        role = "user"
    }
} | ConvertTo-Json -Depth 10

# Ejecutar y medir tiempo
Measure-Command {
    Invoke-RestMethod -Uri $url -Method POST -Body $body -Headers $headers
}
```

#### Nivel 3: Root Cause Analysis (30+ minutos)

**1. Análisis de trace completo**:
```bash
# Ver trace de sesión específica
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:session-ID_ESPECIFICO" \
  --format="table(timestamp, severity, textPayload)"
```

**2. Verificar dependencias externas**:
```bash
# BigQuery connectivity
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) as count FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo` LIMIT 1'

# GCS bucket access
gsutil ls gs://miguel-test/ | head -5
```

**3. Analizar performance**:
```bash
# Latency distribution
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_latencies"' \
  --format="csv(points[0].value.distribution_value.bucket_counts)"
```

---

### Problemas Comunes y Soluciones

#### Problema 1: Servicio No Responde (502/503)

**Síntomas**:
- ❌ Error 502 Bad Gateway
- ❌ Error 503 Service Unavailable
- ❌ Health check fails

**Diagnóstico**:
```bash
# Ver logs de startup
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:Iniciando OR textPayload:startup" \
  --limit=20

# Verificar si MCP Toolbox inició
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:toolbox" \
  --limit=10
```

**Causas comunes**:
1. **MCP Toolbox no inicia**: Binary corrupto o falta de permisos
2. **Timeout de startup**: Container tarda >60s en iniciar
3. **Port binding error**: Puerto 8080 no disponible
4. **Memory exhaustion**: OOMKilled durante startup

**Soluciones**:

**A. Restart del servicio**:
```bash
# Forzar restart (eliminar todas las instancias)
gcloud run services update invoice-backend \
  --region=us-central1 \
  --max-instances=0

sleep 10

gcloud run services update invoice-backend \
  --region=us-central1 \
  --max-instances=10
```

**B. Rollback a revisión anterior**:
```bash
# Identificar última revisión estable
gcloud run revisions list \
  --service=invoice-backend \
  --region=us-central1 \
  --limit=5

# Rollback
gcloud run services update-traffic invoice-backend \
  --to-revisions=REVISION_ESTABLE=100 \
  --region=us-central1
```

**C. Aumentar resources (si OOMKilled)**:
```bash
gcloud run services update invoice-backend \
  --memory=8Gi \
  --cpu=8 \
  --timeout=600s \
  --region=us-central1
```

---

#### Problema 2: Latencia Alta (>60s)

**Síntomas**:
- ⚠️ P95 latency > 60s
- ⚠️ Users reportan lentitud
- ⚠️ Timeouts frecuentes

**Diagnóstico**:
```bash
# Analizar distribución de latencia
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=invoice-backend" \
  --format="value(httpRequest.latency)" \
  --limit=100 | \
  sort -n | tail -20
```

**Causas comunes**:
1. **Cold starts**: Min instances = 0
2. **BigQuery queries lentas**: Consultas sin optimizar
3. **Gemini API latency**: Llamadas a IA lentas
4. **Memory pressure**: Swapping o GC excesivo
5. **Token limit prevention**: Sistema rechazando queries masivas

**Soluciones**:

**A. Eliminar cold starts**:
```bash
# Configurar min-instances
gcloud run services update invoice-backend \
  --min-instances=1 \
  --region=us-central1
```

**B. Optimizar BigQuery**:
```sql
-- Verificar queries lentas en logs
SELECT
  textPayload,
  timestamp
FROM
  `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE
  textPayload LIKE '%BigQuery%'
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY
  timestamp DESC
LIMIT 20;
```

**C. Aumentar concurrency**:
```bash
gcloud run services update invoice-backend \
  --concurrency=10 \
  --region=us-central1
```

---

#### Problema 3: SignatureDoesNotMatch (PDFs/ZIPs)

**Síntomas**:
- ❌ XML error al descargar PDFs
- ❌ "SignatureDoesNotMatch" en logs
- ❌ ZIPs no descargables

**Diagnóstico**:
```bash
# Buscar errores de signed URLs
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:SignatureDoesNotMatch OR textPayload:clock skew" \
  --limit=20
```

**Causas comunes**:
1. **Clock skew**: Diferencia de tiempo servidor-GCP
2. **Sistema robusto no disponible**: `src/` no copiado al container
3. **Credenciales expiradas**: Service account sin refresh

**Soluciones**:

**A. Verificar sistema robusto activo**:
```bash
# Buscar log específico
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:'🔧 [GCS] Usando sistema robusto'" \
  --limit=5

# Esperado: Log presente
# Si no aparece: Sistema robusto no disponible
```

**B. Redeploy con src/ incluido**:
```powershell
# Verificar Dockerfile contiene:
# COPY src/ ./src/

cd deployment/backend
.\deploy.ps1 -AutoVersion
```

**C. Aumentar buffer de signed URLs**:
```bash
# Actualizar environment variable
gcloud run services update invoice-backend \
  --update-env-vars="SIGNED_URL_BUFFER_MINUTES=10" \
  --region=us-central1
```

---

#### Problema 4: Error Rate Alto (>5%)

**Síntomas**:
- ⚠️ 5xx errors frecuentes
- ⚠️ Error rate > 5%
- ⚠️ Users reportan errores

**Diagnóstico**:
```bash
# Agrupar errores por código
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=invoice-backend AND httpRequest.status>=500" \
  --format="value(httpRequest.status)" \
  --limit=100 | \
  sort | uniq -c
```

**Causas comunes**:
1. **500 Internal Error**: Exceptions en código
2. **503 Service Unavailable**: Backend overload
3. **504 Gateway Timeout**: Request > timeout limit
4. **502 Bad Gateway**: Container crash

**Soluciones**:

**A. Identificar exception específica**:
```bash
# Ver stack traces
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="severity=ERROR" \
  --limit=5 \
  --format="value(textPayload)"
```

**B. Aumentar resources**:
```bash
gcloud run services update invoice-backend \
  --memory=6Gi \
  --cpu=6 \
  --timeout=900s \
  --region=us-central1
```

**C. Aumentar max-instances (si scaling issue)**:
```bash
gcloud run services update invoice-backend \
  --max-instances=20 \
  --region=us-central1
```

---

#### Problema 5: Token Limit Exceeded

**Síntomas**:
- ❌ `input token count exceeds maximum`
- ❌ Query rechazada por sistema
- ⚠️ Guidance de "use filtros"

**Diagnóstico**:
```bash
# Buscar rechazos por token limit
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:'token count exceeds' OR textPayload:'supera el límite de procesamiento'" \
  --limit=10
```

**Causas comunes**:
1. **Query sin filtros**: "dame todas las facturas"
2. **Rango de fechas amplio**: "facturas de 2017-2025"
3. **Cliente con muchas facturas**: RUT con >1000 facturas
4. **Limit SQL alto**: Consultas que retornan >1000 registros

**Soluciones**:

**A. Guidance al usuario** (automático):
```
Sistema responde:
"Esta consulta requeriría procesar demasiadas facturas (>1000) 
lo que supera el límite de procesamiento del modelo.

Sugerencias:
- Especificar mes/año específico
- Usar RUT o código SAP
- Solicitar solo últimas N facturas"
```

**B. Ajustar límites SQL (si necesario)**:
```yaml
# mcp-toolbox/tools_updated.yaml
# Reducir limits:
search_invoices_by_month_year: 100  # Antes 200
get_yearly_invoice_statistics: 1000  # Antes 2000
```

**C. Implementar paginación** (futuro):
```python
# Dividir consulta en chunks de 100 facturas
# Procesar iterativamente
# Combinar resultados
```

---

#### Problema 6: BigQuery Quota Exceeded

**Síntomas**:
- ❌ "Quota exceeded" en logs
- ❌ BigQuery errors frecuentes
- ⚠️ Consultas lentas o fallando

**Diagnóstico**:
```bash
# Ver errores de BigQuery
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:quotaExceeded OR textPayload:rateLimitExceeded" \
  --limit=10
```

**Causas comunes**:
1. **Queries concurrentes**: Múltiples users simultáneos
2. **Queries pesadas**: Full table scans sin filtros
3. **API requests/day limit**: Límite de proyecto excedido

**Soluciones**:

**A. Ver quotas actuales**:
```bash
# BigQuery quotas
gcloud compute project-info describe \
  --project=datalake-gasco \
  --format="value(quotas)"
```

**B. Request quota increase**:
```
URL: https://console.cloud.google.com/iam-admin/quotas?project=datalake-gasco
Service: BigQuery API
Metric: Queries per day
```

**C. Optimizar queries** (agregar WHERE clauses):
```sql
-- ANTES (lento)
SELECT * FROM pdfs_modelo

-- DESPUÉS (rápido)
SELECT * FROM pdfs_modelo
WHERE Fecha_de_Emision >= '2025-01-01'
LIMIT 100
```

---

## 🔄 Mantenimiento Programado

### Tareas Diarias

#### 1. Verificación de Salud (Morning Check)

**Script automatizado**:
```powershell
# scripts/daily_health_check.ps1
Write-Host "🏥 Daily Health Check - $(Get-Date)" -ForegroundColor Cyan

# 1. Health endpoint
$health = Invoke-RestMethod "https://invoice-backend-819133916464.us-central1.run.app/list-apps"
if ($health.apps -contains "gcp-invoice-agent-app") {
    Write-Host "✅ Service UP" -ForegroundColor Green
} else {
    Write-Host "❌ Service DOWN" -ForegroundColor Red
}

# 2. Error rate (last 24h)
$errors = gcloud logging read `
  "resource.type=cloud_run_revision AND severity>=ERROR" `
  --limit=1000 `
  --freshness=24h `
  --format="value(severity)" | Measure-Object

Write-Host "📊 Errors (24h): $($errors.Count)"

# 3. Instance count
$instances = gcloud run services describe invoice-backend `
  --region=us-central1 `
  --format="value(status.observedGeneration)"

Write-Host "🖥️ Active instances: $instances"
```

#### 2. Limpieza de Logs

**Retención configurada**:
- **Cloud Run logs**: 30 días (automático)
- **BigQuery conversation_logs**: Limpieza manual recomendada

**Query para limpieza**:
```sql
-- Eliminar logs >90 días
DELETE FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY);

-- Verificar espacio liberado
SELECT
  ROUND(SUM(size_bytes) / 1024 / 1024 / 1024, 2) as size_gb
FROM
  `agent-intelligence-gasco.chat_analytics.__TABLES__`
WHERE
  table_id = 'conversation_logs';
```

---

### Tareas Semanales

#### 1. Revisión de Métricas

**Checklist**:
- [ ] Revisar dashboard semanal en Cloud Console
- [ ] Analizar top 10 queries más lentas
- [ ] Verificar error rate trend
- [ ] Validar costos Gemini API vs presupuesto
- [ ] Revisar instancias promedio (optimizar min/max)

**Query de análisis semanal**:
```sql
-- Top queries más costosas (última semana)
SELECT
  DATE(timestamp) as date,
  COUNT(*) as query_count,
  AVG(total_token_count) as avg_tokens,
  MAX(total_token_count) as max_tokens,
  SUM(total_token_count) as total_tokens
FROM
  `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND total_token_count IS NOT NULL
GROUP BY
  date
ORDER BY
  date DESC;
```

#### 2. Limpieza de Revisiones Viejas

**Eliminar revisiones antiguas** (mantener últimas 10):
```bash
# Listar revisiones
gcloud run revisions list \
  --service=invoice-backend \
  --region=us-central1 \
  --sort-by=~metadata.creationTimestamp \
  --limit=20

# Eliminar revisiones >30 días
gcloud run revisions list \
  --service=invoice-backend \
  --region=us-central1 \
  --filter="metadata.creationTimestamp<'2025-09-06'" \
  --format="value(metadata.name)" | \
  xargs -I {} gcloud run revisions delete {} \
    --region=us-central1 \
    --quiet
```

---

### Tareas Mensuales

#### 1. Análisis de Costos Detallado

**Report mensual**:
```sql
-- Cost breakdown por mes
SELECT
  FORMAT_TIMESTAMP('%Y-%m', timestamp) as month,
  COUNT(DISTINCT session_id) as unique_sessions,
  COUNT(*) as total_queries,
  SUM(total_token_count) as total_tokens,
  ROUND((SUM(prompt_token_count) * 0.075 + SUM(candidates_token_count) * 0.30) / 1000000, 2) as gemini_cost_usd,
  ROUND(SUM(total_token_count) / COUNT(*), 0) as avg_tokens_per_query
FROM
  `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 MONTH)
  AND total_token_count IS NOT NULL
GROUP BY
  month
ORDER BY
  month DESC;
```

#### 2. Backup de Configuraciones

**Backup mensual**:
```bash
# Export de configuraciones críticas
mkdir -p backups/$(date +%Y%m)

# 1. Cloud Run YAML
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format=yaml > backups/$(date +%Y%m)/cloud-run-config.yaml

# 2. MCP Tools
cp mcp-toolbox/tools_updated.yaml \
   backups/$(date +%Y%m)/tools_updated.yaml

# 3. Agent Prompt
cp my-agents/gcp-invoice-agent-app/agent_prompt.yaml \
   backups/$(date +%Y%m)/agent_prompt.yaml

# 4. Environment config
cp config.py backups/$(date +%Y%m)/config.py
```

#### 3. Revisión de Seguridad

**Checklist**:
- [ ] Verificar service account permissions (no excesivos)
- [ ] Revisar access logs para anomalías
- [ ] Validar IAM policies actualizadas
- [ ] Verificar no hay secrets en logs
- [ ] Confirmar signed URLs no expuestas públicamente

---

## 📞 Soporte y Escalamiento

### Niveles de Soporte

#### Nivel 1 (L1): First Response

**Responsabilidades**:
- Atender tickets iniciales
- Ejecutar health checks básicos
- Restarts de servicio si necesario
- Escalamiento a L2 si no resuelve en 15min

**Acciones permitidas**:
- ✅ Restart de Cloud Run service
- ✅ Consultar logs básicos
- ✅ Health check manual
- ❌ Cambiar configuración
- ❌ Rollback de revisiones
- ❌ Modificar código

**Escalamiento a L2 cuando**:
- Error persiste después de restart
- Logs muestran exceptions complejas
- Problema afecta múltiples usuarios
- Métricas muestran degradación sistémica

---

#### Nivel 2 (L2): Technical Support

**Responsabilidades**:
- Troubleshooting avanzado
- Análisis de logs detallado
- Rollback de revisiones
- Ajuste de configuraciones
- Escalamiento a L3 si requiere código

**Acciones permitidas**:
- ✅ Rollback a revisión anterior
- ✅ Ajustar CPU/Memory/Timeout
- ✅ Modificar environment variables
- ✅ Analizar queries BigQuery
- ❌ Modificar código fuente
- ❌ Cambiar IAM policies

**Escalamiento a L3 cuando**:
- Bug en código identificado
- Cambio arquitectural requerido
- Problema de diseño del sistema
- Requiere modificación de MCP tools

---

#### Nivel 3 (L3): Engineering

**Responsabilidades**:
- Resolución de bugs en código
- Cambios arquitecturales
- Performance optimization
- Nuevas features
- Documentación técnica

**Acciones permitidas**:
- ✅ Modificar código fuente
- ✅ Actualizar MCP tools
- ✅ Cambiar agent prompts
- ✅ Modificar IAM policies
- ✅ Arquitectura y diseño

---

### Matriz de Escalamiento

| Problema | L1 | L2 | L3 |
|----------|----|----|-----|
| **Service Down** | Restart | Rollback | Fix código |
| **Latency Alta** | Health check | Ajustar resources | Optimizar queries |
| **Error Rate Alto** | Ver logs | Analizar pattern | Fix bugs |
| **SignatureDoesNotMatch** | Restart | Verificar config | Fix signed URLs |
| **Token Limit** | Informar usuario | Ajustar limits | Implementar paginación |
| **BigQuery Quota** | Restart | Request increase | Optimizar queries |
| **MCP Tool Error** | - | Ver logs MCP | Fix tool YAML |
| **Deployment Failed** | - | Rollback | Fix Dockerfile |

---

### Contactos y Comunicación

#### Canales de Comunicación

| Canal | Uso | Urgencia |
|-------|-----|----------|
| **Email** | soporte-tech@option.cl | No urgente |
| **Slack** | #invoice-chatbot-alerts | Medio |
| **PagerDuty** | Production critical issues | Alta |
| **Jira** | Ticket tracking | Todas |

#### Escalation Matrix

| Rol | Nombre | Email | Teléfono | Horario |
|-----|--------|-------|----------|---------|
| **L1 Lead** | [Nombre] | [email] | [phone] | 24/7 |
| **L2 Lead** | [Nombre] | [email] | [phone] | Lun-Vie 9-18 |
| **L3 Architect** | [Nombre] | [email] | [phone] | On-call |
| **Product Owner** | [Nombre] | [email] | [phone] | Lun-Vie 9-18 |

---

### Plantillas de Comunicación

#### Template: Incident Report

```markdown
# Incident Report: [TÍTULO BREVE]

**Fecha/Hora**: 2025-10-06 14:30 CLT
**Severidad**: [Critical/High/Medium/Low]
**Estado**: [Investigating/Identified/Resolved]
**Duración**: XX minutos

## Resumen
[Descripción breve del problema]

## Impacto
- Usuarios afectados: XX
- Servicios impactados: [Lista]
- Degradación: [Descripción]

## Timeline
- 14:30 - Alerta recibida
- 14:32 - Investigación iniciada
- 14:40 - Causa identificada
- 14:45 - Fix aplicado
- 14:50 - Servicio restaurado

## Root Cause
[Causa raíz identificada]

## Solución Aplicada
[Descripción del fix]

## Acciones Preventivas
1. [Acción 1]
2. [Acción 2]

## Responsable
[Nombre] - L[1/2/3]
```

#### Template: Maintenance Window

```markdown
# Maintenance Window Notice

**Fecha**: 2025-10-15
**Horario**: 02:00 - 04:00 CLT (2 horas)
**Impacto**: Downtime parcial esperado

## Trabajos a Realizar
1. Actualización de Cloud Run a nueva revisión
2. Aplicación de fix para [problema]
3. Optimización de configuración

## Impacto Esperado
- Downtime: 5-10 minutos durante deployment
- Degradación: Latency +20% durante 30min post-deployment

## Rollback Plan
Si problemas detectados en primeros 30 minutos:
- Rollback automático a revisión anterior
- Tiempo estimado: 5 minutos

## Contactos
- Lead: [Nombre] - [Teléfono]
- Backup: [Nombre] - [Teléfono]
```

---

## 📚 Runbooks Específicos

### Runbook 1: Deployment Fallido

**Trigger**: Deployment a Cloud Run falla

**Pasos**:
1. **Identificar error**:
   ```bash
   gcloud run services describe invoice-backend \
     --region=us-central1 \
     --format="value(status.conditions[0].message)"
   ```

2. **Verificar imagen**:
   ```bash
   gcloud artifacts docker images describe \
     us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:VERSION
   ```

3. **Rollback inmediato**:
   ```bash
   gcloud run services update-traffic invoice-backend \
     --to-revisions=REVISION_ANTERIOR=100 \
     --region=us-central1
   ```

4. **Analizar causa**:
   - Ver logs de build
   - Verificar Dockerfile
   - Validar dependencies

5. **Fix y redeploy**:
   ```powershell
   cd deployment/backend
   .\deploy.ps1 -AutoVersion
   ```

---

### Runbook 2: Memory Exhaustion

**Trigger**: OOMKilled events en logs

**Pasos**:
1. **Confirmar OOMKilled**:
   ```bash
   gcloud run services logs read invoice-backend \
     --region=us-central1 \
     --filter="textPayload:OOMKilled" \
     --limit=5
   ```

2. **Aumentar memory limit inmediatamente**:
   ```bash
   gcloud run services update invoice-backend \
     --memory=6Gi \
     --region=us-central1
   ```

3. **Monitorear si persiste**:
   ```bash
   gcloud run services logs tail invoice-backend \
     --region=us-central1
   ```

4. **Si persiste, aumentar más**:
   ```bash
   gcloud run services update invoice-backend \
     --memory=8Gi \
     --cpu=8 \
     --region=us-central1
   ```

5. **Investigar memory leak**:
   - Analizar logs de conversaciones largas
   - Verificar si hay sessions sin cleanup
   - Revisar código para leaks

---

### Runbook 3: Zero Traffic

**Trigger**: Request count = 0 por >15 minutos

**Pasos**:
1. **Verificar health endpoint público**:
   ```bash
   curl https://invoice-backend-819133916464.us-central1.run.app/list-apps
   ```

2. **Si falla, verificar revision activa**:
   ```bash
   gcloud run services describe invoice-backend \
     --region=us-central1 \
     --format="value(status.traffic)"
   ```

3. **Si no hay tráfico asignado, activar**:
   ```bash
   gcloud run services update-traffic invoice-backend \
     --to-latest \
     --region=us-central1
   ```

4. **Verificar DNS/Firewall** (si aplica):
   ```bash
   nslookup invoice-backend-819133916464.us-central1.run.app
   ```

5. **Test manual**:
   ```powershell
   # Test completo de sesión
   .\scripts\health_check_detailed.ps1
   ```

---

## 📖 Referencias y Recursos

### Documentación Relacionada

- 📊 **Executive Summary**: `docs/official/executive/00_EXECUTIVE_SUMMARY.md`
- 📘 **User Guide**: `docs/official/user/10_USER_GUIDE.md`
- 🏗️ **System Architecture**: `docs/official/architecture/20_SYSTEM_ARCHITECTURE.md`
- 🚀 **Deployment Guide**: `docs/official/deployment/40_DEPLOYMENT_GUIDE.md`
- 💻 **Developer Guide**: `docs/official/developer/30_DEVELOPER_GUIDE.md`

### Enlaces Útiles

- **Cloud Run Console**: https://console.cloud.google.com/run/detail/us-central1/invoice-backend?project=agent-intelligence-gasco
- **Cloud Logging**: https://console.cloud.google.com/logs?project=agent-intelligence-gasco
- **Cloud Monitoring**: https://console.cloud.google.com/monitoring?project=agent-intelligence-gasco
- **BigQuery Console**: https://console.cloud.google.com/bigquery?project=datalake-gasco
- **IAM Console**: https://console.cloud.google.com/iam-admin/iam?project=agent-intelligence-gasco

### Scripts de Soporte

```powershell
# Health checks
.\scripts\health_check_detailed.ps1

# Test específicos
.\scripts\test_sap_codigo_solicitante_agosto_2025.ps1
.\scripts\test_comercializadora_pimentel_agosto_2025.ps1

# Diagnosis
.\scripts\diagnose_service.ps1
```

---

## ✅ Checklist Operacional

### Daily Operations

- [ ] Morning health check ejecutado
- [ ] Dashboard revisado (errores, latency, instances)
- [ ] Alerts revisadas y atendidas
- [ ] Logs de errores analizados
- [ ] Tickets pendientes actualizados

### Weekly Operations

- [ ] Métricas semanales revisadas
- [ ] Top queries lentas analizadas
- [ ] Error rate trend validado
- [ ] Costos Gemini API vs budget
- [ ] Revisiones viejas eliminadas
- [ ] Backup de configuraciones

### Monthly Operations

- [ ] Cost report generado y analizado
- [ ] Backup completo de configuraciones
- [ ] Revisión de seguridad completada
- [ ] Cleanup de logs BigQuery
- [ ] Optimizaciones identificadas
- [ ] Documentación actualizada

---

**Versión**: 1.0  
**Última actualización**: 6 de octubre de 2025  
**Audiencia**: Soporte L1/L2/L3, SRE, DevOps  
**Nivel**: Operacional  

---

## 📝 Historial de Cambios

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 1.0 | 2025-10-06 | Option Team | Guía de operaciones completa - Primera versión |

---

**© 2025 Option - Todos los derechos reservados**  
**Cliente: Gasco**
