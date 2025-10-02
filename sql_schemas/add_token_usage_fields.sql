-- ================================================================
-- SCHEMA UPDATE: Agregar campos de Token Usage y Text Metrics
-- ================================================================
-- Tabla: agent-intelligence-gasco.chat_analytics.conversation_logs
-- Fecha: 2025-10-02
-- Objetivo: Agregar tracking completo de tokens consumidos por Gemini API
--           y métricas de texto (caracteres, palabras) para análisis de costos

-- ================================================================
-- PASO 1: Agregar campos de Token Usage (Gemini API)
-- ================================================================

-- 1.1 Tokens de entrada (prompt enviado al modelo)
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS prompt_token_count INTEGER
OPTIONS(description="Tokens de entrada consumidos (prompt enviado al modelo Gemini)");

-- 1.2 Tokens de salida (respuesta generada por el modelo)
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS candidates_token_count INTEGER
OPTIONS(description="Tokens de salida consumidos (respuesta generada por Gemini)");

-- 1.3 Total de tokens (suma de entrada + salida + pensamiento)
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS total_token_count INTEGER
OPTIONS(description="Total de tokens consumidos (entrada + salida + pensamiento interno)");

-- 1.4 Tokens de pensamiento interno del modelo (thinking tokens)
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS thoughts_token_count INTEGER
OPTIONS(description="Tokens de razonamiento interno del modelo (thinking mode)");

-- 1.5 Tokens de contenido cacheado (si el modelo usa cache)
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS cached_content_token_count INTEGER
OPTIONS(description="Tokens de contenido cacheado reutilizado (optimización de costos)");

-- ================================================================
-- PASO 2: Agregar métricas de texto - Pregunta del Usuario
-- ================================================================

-- 2.1 Longitud en caracteres de la pregunta del usuario
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS user_question_length INTEGER
OPTIONS(description="Número de caracteres en la pregunta del usuario");

-- 2.2 Número de palabras en la pregunta del usuario
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS user_question_word_count INTEGER
OPTIONS(description="Número de palabras en la pregunta del usuario");

-- ================================================================
-- PASO 3: Agregar métricas de texto - Respuesta del Agente
-- ================================================================

-- 3.1 Longitud en caracteres de la respuesta del agente
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS agent_response_length INTEGER
OPTIONS(description="Número de caracteres en la respuesta del agente");

-- 3.2 Número de palabras en la respuesta del agente
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS agent_response_word_count INTEGER
OPTIONS(description="Número de palabras en la respuesta del agente");

-- ================================================================
-- VERIFICACIÓN: Confirmar que las columnas se agregaron correctamente
-- ================================================================

SELECT
  column_name,
  data_type,
  is_nullable,
  description
FROM `agent-intelligence-gasco.chat_analytics.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE table_name = 'conversation_logs'
  AND column_name IN (
    'prompt_token_count',
    'candidates_token_count',
    'total_token_count',
    'thoughts_token_count',
    'cached_content_token_count',
    'user_question_length',
    'user_question_word_count',
    'agent_response_length',
    'agent_response_word_count'
  )
ORDER BY column_name;

-- ================================================================
-- EXPECTED OUTPUT:
-- ================================================================
-- column_name                     | data_type | is_nullable | description
-- --------------------------------|-----------|-------------|------------------
-- agent_response_length           | INT64     | YES         | Número de caracteres en la respuesta del agente
-- agent_response_word_count       | INT64     | YES         | Número de palabras en la respuesta del agente
-- cached_content_token_count      | INT64     | YES         | Tokens de contenido cacheado reutilizado (optimización de costos)
-- candidates_token_count          | INT64     | YES         | Tokens de salida consumidos (respuesta generada por Gemini)
-- prompt_token_count              | INT64     | YES         | Tokens de entrada consumidos (prompt enviado al modelo Gemini)
-- thoughts_token_count            | INT64     | YES         | Tokens de razonamiento interno del modelo (thinking mode)
-- total_token_count               | INT64     | YES         | Total de tokens consumidos (entrada + salida + pensamiento interno)
-- user_question_length            | INT64     | YES         | Número de caracteres en la pregunta del usuario
-- user_question_word_count        | INT64     | YES         | Número de palabras en la pregunta del usuario

-- ================================================================
-- NOTAS IMPORTANTES:
-- ================================================================
-- 1. Estos campos son NULLABLE porque no todos los registros históricos
--    tendrán esta información (solo los nuevos registros la tendrán)
--
-- 2. Los tokens se obtienen de response.usage_metadata de la API de Gemini
--
-- 3. Las métricas de texto se calculan en Python antes de insertar en BigQuery
--
-- 4. Para análisis de costos, usar:
--    - prompt_token_count: Costo de entrada
--    - candidates_token_count: Costo de salida
--    - total_token_count: Costo total (incluye thinking si está habilitado)
--
-- 5. El campo thoughts_token_count será 0 si ENABLE_THINKING_MODE=false
--
-- 6. Para validar que los datos se están guardando correctamente, ejecutar:
--    SELECT * FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
--    WHERE prompt_token_count IS NOT NULL
--    ORDER BY timestamp DESC LIMIT 10;
