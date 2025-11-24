# Schema de BigQuery: conversation_logs

**Tabla**: `agent-intelligence-gasco.chat_analytics.conversation_logs`  
**Propósito**: Tracking completo de conversaciones con métricas de tokens, texto y performance de ZIPs

---

## 📊 Estructura Completa (46 campos)

### 1️⃣ Identificadores y Sesión (4 campos)

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `conversation_id` | STRING | REQUIRED | ID único de la conversación/sesión |
| `message_id` | STRING | REQUIRED | ID único del mensaje individual |
| `user_id` | STRING | NULLABLE | ID del usuario (anónimo o identificado) |
| `session_id` | STRING | NULLABLE | ID de sesión técnica del sistema |

### 2️⃣ Campos Temporales (4 campos)

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `timestamp` | TIMESTAMP | REQUIRED | Momento exacto del mensaje |
| `date_partition` | DATE | NULLABLE | Partición por fecha para optimización |
| `hour_of_day` | INTEGER | NULLABLE | Hora del día (0-23) para análisis de uso |
| `day_of_week` | INTEGER | NULLABLE | Día de la semana (1-7) para patrones |

### 3️⃣ Contenido de la Conversación (4 campos)

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `message_type` | STRING | REQUIRED | Tipo: 'user_question', 'agent_response', 'system_message' |
| `user_question` | STRING | NULLABLE | Pregunta original del usuario |
| `agent_response` | STRING | NULLABLE | Respuesta completa del agente |
| `response_summary` | STRING | NULLABLE | Resumen corto de la respuesta (primeros 200 chars) |

### 4️⃣ Análisis Semántico (3 campos)

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `detected_intent` | STRING | NULLABLE | Intent detectado: 'search_invoice', 'count_invoices', 'download_request', etc. |
| `query_category` | STRING | NULLABLE | Categoría: 'basic_search', 'filtered_search', 'download', 'statistics', 'help' |
| `search_filters` | STRING | REPEATED | Filtros aplicados: ['date_range', 'emisor', 'rut', 'cliente'] |

### 5️⃣ Métricas de Ejecución (4 campos)

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `results_count` | INTEGER | NULLABLE | Número de facturas encontradas |
| `tools_used` | STRING | REPEATED | Herramientas MCP utilizadas |
| `response_time_ms` | INTEGER | NULLABLE | Tiempo de respuesta en milisegundos |
| `success` | BOOLEAN | NULLABLE | Si la consulta fue exitosa |
| `error_message` | STRING | NULLABLE | Mensaje de error si la consulta falló |

### 6️⃣ Gestión de Descargas (5 campos)

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `download_requested` | BOOLEAN | NULLABLE | Si se solicitó descarga de archivos |
| `download_type` | STRING | NULLABLE | Tipo: 'individual', 'zip', 'none' |
| `zip_generated` | BOOLEAN | NULLABLE | Si se generó un ZIP automáticamente |
| `zip_id` | STRING | NULLABLE | ID del ZIP generado (referencia a zip_packages) |
| `pdf_links_provided` | INTEGER | NULLABLE | Número de enlaces PDF proporcionados |

### 7️⃣ Metadatos del Sistema (5 campos)

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `agent_name` | STRING | NULLABLE | Nombre del agente que procesó la consulta |
| `api_version` | STRING | NULLABLE | Versión de la API utilizada |
| `client_info` | RECORD | NULLABLE | Información del cliente |
| `bigquery_project_used` | STRING | NULLABLE | Proyecto BigQuery consultado |
| `raw_mcp_response` | STRING | NULLABLE | Respuesta completa del MCP Toolbox para debugging |

### 8️⃣ Análisis de Calidad (3 campos)

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `user_satisfaction_inferred` | STRING | NULLABLE | Satisfacción inferida: 'positive', 'neutral', 'negative' |
| `question_complexity` | STRING | NULLABLE | Complejidad: 'simple', 'medium', 'complex' |
| `response_quality_score` | FLOAT | NULLABLE | Score de calidad de respuesta (0.0-1.0) |

### 9️⃣ **TOKENS GEMINI API** (5 campos) 🆕

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `prompt_token_count` | INTEGER | NULLABLE | Tokens de entrada consumidos (prompt enviado al modelo Gemini) |
| `candidates_token_count` | INTEGER | NULLABLE | Tokens de salida consumidos (respuesta generada por Gemini) |
| `total_token_count` | INTEGER | NULLABLE | Total de tokens consumidos (entrada + salida + pensamiento interno) |
| `thoughts_token_count` | INTEGER | NULLABLE | Tokens de razonamiento interno del modelo (thinking mode) |
| `cached_content_token_count` | INTEGER | NULLABLE | Tokens de contenido cacheado reutilizado (optimización de costos) |

**Fuente**: `response.usage_metadata` de Gemini API  
**Implementado en Legacy**: `conversation_callbacks.py` línea 670-708

### 🔟 **MÉTRICAS DE TEXTO** (4 campos) 🆕

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `user_question_length` | INTEGER | NULLABLE | Número de caracteres en la pregunta del usuario |
| `user_question_word_count` | INTEGER | NULLABLE | Número de palabras en la pregunta del usuario |
| `agent_response_length` | INTEGER | NULLABLE | Número de caracteres en la respuesta del agente |
| `agent_response_word_count` | INTEGER | NULLABLE | Número de palabras en la respuesta del agente |

**Cálculo**: Python `len(text)` y `len(text.split())`

### 1️⃣1️⃣ **MÉTRICAS DE PERFORMANCE ZIP** (6 campos) 🆕

| Campo | Tipo | Modo | Descripción |
|-------|------|------|-------------|
| `zip_generation_time_ms` | INTEGER | NULLABLE | Tiempo total de generación del ZIP en milisegundos |
| `zip_parallel_download_time_ms` | INTEGER | NULLABLE | Tiempo de descarga paralela de PDFs en milisegundos |
| `zip_max_workers_used` | INTEGER | NULLABLE | Número de workers paralelos utilizados para descarga de PDFs |
| `zip_files_included` | INTEGER | NULLABLE | Número de archivos incluidos en el ZIP |
| `zip_files_missing` | INTEGER | NULLABLE | Número de archivos que no se pudieron incluir en el ZIP |
| `zip_total_size_bytes` | INTEGER | NULLABLE | Tamaño total del ZIP generado en bytes |

**Captura**: Durante generación de ZIP en `zip_service.py`

---

## 🎯 Campos Prioritarios para Migración a SOLID

### Alta Prioridad (Tokens + Texto)
- ✅ `prompt_token_count`
- ✅ `candidates_token_count`
- ✅ `total_token_count`
- ✅ `thoughts_token_count`
- ✅ `cached_content_token_count`
- ✅ `user_question_length`
- ✅ `user_question_word_count`
- ✅ `agent_response_length`
- ✅ `agent_response_word_count`

### Media Prioridad (ZIP Performance)
- 🔄 `zip_generation_time_ms`
- 🔄 `zip_parallel_download_time_ms`
- 🔄 `zip_max_workers_used`
- 🔄 `zip_files_included`
- 🔄 `zip_files_missing`
- 🔄 `zip_total_size_bytes`

### Baja Prioridad (Ya implementados en Legacy)
- ⏸️ Identificadores (conversation_id, message_id, etc.)
- ⏸️ Contenido conversacional (user_question, agent_response)
- ⏸️ Análisis semántico (detected_intent, query_category)

---

## 📁 Archivos SQL de Referencia

- `sql_schemas/add_token_usage_fields.sql` - ALTER TABLE para tokens
- `sql_schemas/add_zip_performance_metrics.sql` - ALTER TABLE para métricas ZIP

---

## 🔗 Referencias

- **Legacy Implementation**: `my-agents/gcp_invoice_agent_app/conversation_callbacks.py`
- **BigQuery Project**: `agent-intelligence-gasco`
- **Dataset**: `chat_analytics`
- **Table**: `conversation_logs`
