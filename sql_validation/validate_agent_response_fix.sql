-- ================================================================
-- VALIDACIÓN: Fix de agent_response en conversation_logs
-- ================================================================
-- Este query valida que el campo agent_response ya no esté vacío
-- después del fix implementado en la rama debug/conversation-callbacks-empty-response

-- 1. ÚLTIMOS 10 REGISTROS CON TODOS LOS CAMPOS CLAVE
-- ================================================================
SELECT
  -- Identificadores
  conversation_id,
  message_id,
  user_id,
  session_id,

  -- Timestamps
  timestamp,
  FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', timestamp, 'America/Santiago') as timestamp_local,
  response_time_ms,

  -- Pregunta y respuesta
  user_question,
  agent_response,
  response_summary,

  -- Métricas de calidad
  success,
  error_message,
  results_count,

  -- Herramientas y categorización
  tools_used,
  detected_intent,
  query_category,
  question_complexity,
  response_quality_score,

  -- Descargas
  download_requested,
  download_type,
  zip_generated,
  pdf_links_provided

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
ORDER BY timestamp DESC
LIMIT 10;


-- 2. ANÁLISIS DE CAMPOS VACÍOS (ANTES vs DESPUÉS DEL FIX)
-- ================================================================
-- Identifica registros con agent_response vacío vs no vacío
SELECT
  DATE(timestamp) as fecha,
  COUNT(*) as total_registros,

  -- Análisis de agent_response
  COUNTIF(agent_response IS NULL OR agent_response = '') as agent_response_vacio,
  COUNTIF(agent_response IS NOT NULL AND agent_response != '') as agent_response_con_datos,

  -- Análisis de success
  COUNTIF(success = true) as success_true,
  COUNTIF(success = false) as success_false,
  COUNTIF(success IS NULL) as success_null,

  -- Análisis de results_count
  COUNTIF(results_count IS NOT NULL AND results_count > 0) as con_results_count,
  COUNTIF(results_count IS NULL OR results_count = 0) as sin_results_count,

  -- Porcentajes
  ROUND(COUNTIF(agent_response IS NOT NULL AND agent_response != '') * 100.0 / COUNT(*), 2) as porcentaje_con_respuesta,
  ROUND(COUNTIF(success = true) * 100.0 / COUNT(*), 2) as porcentaje_exitosas

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY fecha
ORDER BY fecha DESC;


-- 3. REGISTROS RECIENTES CON RESPUESTA VÁLIDA (POST-FIX)
-- ================================================================
-- Muestra solo registros donde agent_response tiene contenido
SELECT
  timestamp,
  user_question,
  LEFT(agent_response, 150) as agent_response_preview,
  LENGTH(agent_response) as agent_response_length,
  response_time_ms,
  success,
  results_count,
  ARRAY_LENGTH(tools_used) as num_herramientas_usadas,
  question_complexity

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE agent_response IS NOT NULL
  AND agent_response != ''
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY timestamp DESC
LIMIT 10;


-- 4. COMPARACIÓN: REGISTROS CON vs SIN agent_response
-- ================================================================
SELECT
  'CON agent_response' as categoria,
  COUNT(*) as cantidad,
  AVG(response_time_ms) as tiempo_promedio_ms,
  AVG(response_quality_score) as calidad_promedio,
  AVG(LENGTH(agent_response)) as longitud_promedio_respuesta

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE agent_response IS NOT NULL AND agent_response != ''
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)

UNION ALL

SELECT
  'SIN agent_response' as categoria,
  COUNT(*) as cantidad,
  AVG(response_time_ms) as tiempo_promedio_ms,
  AVG(response_quality_score) as calidad_promedio,
  NULL as longitud_promedio_respuesta

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE (agent_response IS NULL OR agent_response = '')
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)

ORDER BY categoria DESC;


-- 5. DETALLE DE UN REGISTRO ESPECÍFICO (PARA DEBUG)
-- ================================================================
-- Reemplaza el conversation_id con uno real de tus pruebas
SELECT
  conversation_id,
  message_id,
  timestamp,

  -- Pregunta
  '=== PREGUNTA ===' as separator_1,
  user_question,

  -- Respuesta completa
  '=== RESPUESTA COMPLETA ===' as separator_2,
  agent_response,
  LENGTH(agent_response) as response_length,

  -- Resumen
  '=== RESUMEN ===' as separator_3,
  response_summary,

  -- Métricas
  '=== MÉTRICAS ===' as separator_4,
  success,
  error_message,
  results_count,
  response_time_ms,
  response_quality_score,

  -- Herramientas
  '=== HERRAMIENTAS ===' as separator_5,
  tools_used,
  ARRAY_LENGTH(tools_used) as num_tools,

  -- Categorización
  '=== CATEGORIZACIÓN ===' as separator_6,
  detected_intent,
  query_category,
  question_complexity,
  user_satisfaction_inferred

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE conversation_id = 'REEMPLAZAR_CON_CONVERSATION_ID_REAL'
-- O usar ORDER BY timestamp DESC LIMIT 1 para ver el más reciente
ORDER BY timestamp DESC
LIMIT 1;


-- 6. VALIDACIÓN DE CAMPOS DERIVADOS (results_count, detected_intent)
-- ================================================================
-- Verifica que los campos extraídos de agent_response funcionen correctamente
SELECT
  timestamp,
  user_question,

  -- Verificar que results_count se extraiga correctamente
  results_count,
  REGEXP_CONTAINS(agent_response, r'(\d+)\s*facturas?') as tiene_patron_resultados,

  -- Verificar detected_intent
  detected_intent,

  -- Preview de respuesta
  LEFT(agent_response, 100) as response_preview,

  success

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE agent_response IS NOT NULL
  AND agent_response != ''
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
ORDER BY timestamp DESC
LIMIT 15;


-- 7. ESTADÍSTICAS GENERALES POST-FIX
-- ================================================================
SELECT
  '=== ESTADÍSTICAS ÚLTIMAS 24 HORAS ===' as titulo,
  COUNT(*) as total_conversaciones,

  -- Agent response
  COUNTIF(agent_response IS NOT NULL AND agent_response != '') as con_respuesta,
  COUNTIF(agent_response IS NULL OR agent_response = '') as sin_respuesta,
  ROUND(COUNTIF(agent_response IS NOT NULL AND agent_response != '') * 100.0 / COUNT(*), 2) as porcentaje_con_respuesta,

  -- Success rate
  COUNTIF(success = true) as exitosas,
  COUNTIF(success = false) as fallidas,
  ROUND(COUNTIF(success = true) * 100.0 / COUNT(*), 2) as tasa_exito,

  -- Métricas de respuesta
  ROUND(AVG(response_time_ms), 0) as tiempo_promedio_ms,
  ROUND(AVG(response_quality_score), 3) as calidad_promedio,
  ROUND(AVG(LENGTH(agent_response)), 0) as longitud_promedio_respuesta,

  -- Results count
  ROUND(AVG(results_count), 1) as promedio_resultados_por_query

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);


-- ================================================================
-- INSTRUCCIONES DE USO:
-- ================================================================
-- 1. Ejecuta el query #1 primero para ver los últimos 10 registros
-- 2. Ejecuta el query #2 para ver tendencia de campos vacíos por día
-- 3. Ejecuta el query #3 para confirmar que hay respuestas recientes
-- 4. Ejecuta el query #7 para ver estadísticas generales
--
-- VALIDACIÓN EXITOSA SI:
-- ✅ Query #1 muestra agent_response con contenido (no NULL ni vacío)
-- ✅ Query #2 muestra porcentaje_con_respuesta alto para hoy
-- ✅ Query #3 retorna registros con agent_response_length > 0
-- ✅ Query #7 muestra porcentaje_con_respuesta cercano a 100%
-- ================================================================