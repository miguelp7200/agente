-- ================================================================
-- VALIDACIÓN: Token Usage Tracking en conversation_logs
-- ================================================================
-- Este query valida que los campos de tokens y métricas de texto
-- se estén guardando correctamente después del feature/token-usage-tracking
--
-- Tabla: agent-intelligence-gasco.chat_analytics.conversation_logs
-- Fecha: 2025-10-02

-- ================================================================
-- QUERY 1: Últimos 10 registros con métricas de tokens
-- ================================================================
SELECT
  -- Identificadores
  conversation_id,
  timestamp,
  FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', timestamp, 'America/Santiago') as timestamp_local,

  -- Pregunta y respuesta
  LEFT(user_question, 80) as user_question_preview,
  LEFT(agent_response, 80) as agent_response_preview,

  -- 🆕 TOKENS DE GEMINI API
  prompt_token_count,
  candidates_token_count,
  total_token_count,
  thoughts_token_count,
  cached_content_token_count,

  -- 🆕 MÉTRICAS DE TEXTO
  user_question_length,
  user_question_word_count,
  agent_response_length,
  agent_response_word_count,

  -- Métricas adicionales
  response_time_ms,
  success

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE prompt_token_count IS NOT NULL  -- Solo registros con tokens capturados
ORDER BY timestamp DESC
LIMIT 10;


-- ================================================================
-- QUERY 2: Estadísticas de captura de tokens (últimas 24 horas)
-- ================================================================
SELECT
  '=== ESTADÍSTICAS DE TOKEN TRACKING ===' as titulo,
  COUNT(*) as total_conversaciones,

  -- Porcentaje de registros con tokens
  COUNTIF(prompt_token_count IS NOT NULL) as con_tokens,
  COUNTIF(prompt_token_count IS NULL) as sin_tokens,
  ROUND(COUNTIF(prompt_token_count IS NOT NULL) * 100.0 / COUNT(*), 2) as porcentaje_con_tokens,

  -- Promedios de tokens
  ROUND(AVG(prompt_token_count), 1) as promedio_prompt_tokens,
  ROUND(AVG(candidates_token_count), 1) as promedio_candidates_tokens,
  ROUND(AVG(total_token_count), 1) as promedio_total_tokens,
  ROUND(AVG(thoughts_token_count), 1) as promedio_thoughts_tokens,

  -- Promedios de longitud de texto
  ROUND(AVG(user_question_length), 1) as promedio_pregunta_chars,
  ROUND(AVG(user_question_word_count), 1) as promedio_pregunta_palabras,
  ROUND(AVG(agent_response_length), 1) as promedio_respuesta_chars,
  ROUND(AVG(agent_response_word_count), 1) as promedio_respuesta_palabras,

  -- Máximos
  MAX(total_token_count) as max_tokens_consumidos,
  MAX(agent_response_length) as max_respuesta_longitud

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);


-- ================================================================
-- QUERY 3: Análisis de tokens por día (últimos 7 días)
-- ================================================================
SELECT
  DATE(timestamp) as fecha,
  COUNT(*) as total_conversaciones,

  -- Captura de tokens
  COUNTIF(prompt_token_count IS NOT NULL) as con_tokens,
  ROUND(COUNTIF(prompt_token_count IS NOT NULL) * 100.0 / COUNT(*), 2) as porcentaje_captura,

  -- Promedios de tokens por día
  ROUND(AVG(prompt_token_count), 1) as avg_prompt_tokens,
  ROUND(AVG(candidates_token_count), 1) as avg_candidates_tokens,
  ROUND(AVG(total_token_count), 1) as avg_total_tokens,

  -- Totales de tokens consumidos por día
  SUM(prompt_token_count) as total_prompt_tokens_dia,
  SUM(candidates_token_count) as total_candidates_tokens_dia,
  SUM(total_token_count) as total_tokens_dia,

  -- Thinking tokens (si está habilitado)
  SUM(thoughts_token_count) as total_thoughts_tokens_dia,
  ROUND(AVG(thoughts_token_count), 1) as avg_thoughts_tokens

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY fecha
ORDER BY fecha DESC;


-- ================================================================
-- QUERY 4: Top 10 conversaciones con mayor consumo de tokens
-- ================================================================
SELECT
  conversation_id,
  timestamp,
  FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', timestamp, 'America/Santiago') as timestamp_local,

  -- Pregunta
  LEFT(user_question, 100) as user_question_preview,

  -- Tokens
  prompt_token_count,
  candidates_token_count,
  total_token_count,
  thoughts_token_count,

  -- Métricas de texto
  user_question_length,
  agent_response_length,

  -- Performance
  response_time_ms,
  success

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE total_token_count IS NOT NULL
ORDER BY total_token_count DESC
LIMIT 10;


-- ================================================================
-- QUERY 5: Correlación entre longitud de texto y tokens
-- ================================================================
SELECT
  '=== CORRELACIÓN TEXTO <-> TOKENS ===' as titulo,

  -- Promedios generales
  ROUND(AVG(user_question_length), 1) as avg_pregunta_chars,
  ROUND(AVG(user_question_word_count), 1) as avg_pregunta_palabras,
  ROUND(AVG(prompt_token_count), 1) as avg_prompt_tokens,

  -- Ratio caracteres por token (pregunta)
  ROUND(AVG(user_question_length) / NULLIF(AVG(prompt_token_count), 0), 2) as chars_por_token_pregunta,

  -- Ratio palabras por token (pregunta)
  ROUND(AVG(user_question_word_count) / NULLIF(AVG(prompt_token_count), 0), 2) as palabras_por_token_pregunta,

  -- Promedios respuesta
  ROUND(AVG(agent_response_length), 1) as avg_respuesta_chars,
  ROUND(AVG(agent_response_word_count), 1) as avg_respuesta_palabras,
  ROUND(AVG(candidates_token_count), 1) as avg_candidates_tokens,

  -- Ratio caracteres por token (respuesta)
  ROUND(AVG(agent_response_length) / NULLIF(AVG(candidates_token_count), 0), 2) as chars_por_token_respuesta,

  -- Ratio palabras por token (respuesta)
  ROUND(AVG(agent_response_word_count) / NULLIF(AVG(candidates_token_count), 0), 2) as palabras_por_token_respuesta

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE prompt_token_count IS NOT NULL
  AND candidates_token_count IS NOT NULL
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY);


-- ================================================================
-- QUERY 6: Detalle completo de una conversación específica
-- ================================================================
-- Reemplaza el conversation_id con uno real de tus pruebas
SELECT
  '=== INFORMACIÓN GENERAL ===' as seccion_1,
  conversation_id,
  message_id,
  user_id,
  session_id,
  timestamp,
  FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', timestamp, 'America/Santiago') as timestamp_local,

  '=== PREGUNTA USUARIO ===' as seccion_2,
  user_question,
  user_question_length,
  user_question_word_count,

  '=== RESPUESTA AGENTE ===' as seccion_3,
  agent_response,
  agent_response_length,
  agent_response_word_count,

  '=== TOKENS CONSUMIDOS ===' as seccion_4,
  prompt_token_count,
  candidates_token_count,
  total_token_count,
  thoughts_token_count,
  cached_content_token_count,

  '=== MÉTRICAS ===' as seccion_5,
  response_time_ms,
  success,
  response_quality_score,
  tools_used,
  results_count

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
-- WHERE conversation_id = 'REEMPLAZAR_CON_CONVERSATION_ID_REAL'
ORDER BY timestamp DESC
LIMIT 1;


-- ================================================================
-- QUERY 7: Thinking Mode Analysis (tokens de pensamiento)
-- ================================================================
SELECT
  '=== ANÁLISIS DE THINKING MODE ===' as titulo,
  COUNT(*) as total_conversaciones,

  -- Conversaciones con thinking tokens
  COUNTIF(thoughts_token_count > 0) as con_thinking_tokens,
  COUNTIF(thoughts_token_count = 0 OR thoughts_token_count IS NULL) as sin_thinking_tokens,

  -- Porcentaje de uso de thinking mode
  ROUND(COUNTIF(thoughts_token_count > 0) * 100.0 / COUNT(*), 2) as porcentaje_thinking_mode,

  -- Estadísticas de thinking tokens
  MIN(thoughts_token_count) as min_thinking_tokens,
  ROUND(AVG(thoughts_token_count), 1) as avg_thinking_tokens,
  MAX(thoughts_token_count) as max_thinking_tokens,

  -- Total de thinking tokens consumidos
  SUM(thoughts_token_count) as total_thinking_tokens_consumidos,

  -- Porcentaje de thinking tokens sobre total
  ROUND(SUM(thoughts_token_count) * 100.0 / NULLIF(SUM(total_token_count), 0), 2) as porcentaje_thinking_sobre_total

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY);


-- ================================================================
-- QUERY 8: Análisis de costos (estimación)
-- ================================================================
-- NOTA: Precios de Gemini 2.5 Flash (ejemplo, verificar precios actuales)
-- Input: $0.075 por 1M tokens
-- Output: $0.30 por 1M tokens
SELECT
  DATE(timestamp) as fecha,
  COUNT(*) as total_conversaciones,

  -- Tokens consumidos
  SUM(prompt_token_count) as total_input_tokens,
  SUM(candidates_token_count) as total_output_tokens,
  SUM(total_token_count) as total_tokens,

  -- Estimación de costos (USD)
  ROUND(SUM(prompt_token_count) / 1000000.0 * 0.075, 4) as costo_input_usd,
  ROUND(SUM(candidates_token_count) / 1000000.0 * 0.30, 4) as costo_output_usd,
  ROUND((SUM(prompt_token_count) / 1000000.0 * 0.075) +
        (SUM(candidates_token_count) / 1000000.0 * 0.30), 4) as costo_total_usd

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE prompt_token_count IS NOT NULL
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY fecha
ORDER BY fecha DESC;


-- ================================================================
-- VALIDACIÓN EXITOSA SI:
-- ================================================================
-- ✅ Query #1 muestra registros con prompt_token_count, candidates_token_count, total_token_count
-- ✅ Query #2 muestra porcentaje_con_tokens cercano a 100% para registros nuevos
-- ✅ Query #3 muestra tendencia creciente de captura de tokens
-- ✅ Query #4 identifica conversaciones con mayor consumo
-- ✅ Query #5 muestra ratios razonables (ej: ~4 chars/token, ~0.75 palabras/token)
-- ✅ Query #7 muestra thinking_tokens > 0 solo si ENABLE_THINKING_MODE=true
-- ✅ Query #8 permite estimar costos mensuales de uso de Gemini API
