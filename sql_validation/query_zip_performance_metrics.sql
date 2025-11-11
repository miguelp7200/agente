-- Consulta para analizar métricas de performance de generación de ZIPs
-- Compara performance entre diferentes configuraciones (paralelo vs secuencial)

SELECT
  -- Identificación
  conversation_id,
  timestamp,
  session_id,
  user_id,
  
  -- Consulta del usuario
  user_question,
  
  -- Métricas de performance del ZIP
  zip_generation_time_ms,
  zip_parallel_download_time_ms,
  zip_max_workers_used,
  
  -- Archivos en el ZIP
  zip_files_included,
  zip_files_missing,
  zip_total_size_bytes,
  
  -- Cálculos derivados
  ROUND(zip_total_size_bytes / 1024 / 1024, 2) AS zip_size_mb,
  ROUND(zip_generation_time_ms / 1000, 2) AS zip_generation_seconds,
  
  -- Performance por archivo
  ROUND(zip_generation_time_ms / NULLIF(zip_files_included, 0), 2) AS ms_per_file,
  
  -- Eficiencia de descarga paralela
  CASE 
    WHEN zip_parallel_download_time_ms IS NOT NULL AND zip_generation_time_ms > 0 THEN
      ROUND((zip_parallel_download_time_ms / zip_generation_time_ms) * 100, 2)
    ELSE NULL
  END AS parallel_download_percentage,
  
  -- Indicador de configuración
  CASE 
    WHEN zip_max_workers_used > 1 THEN 'Paralelo'
    WHEN zip_max_workers_used = 1 THEN 'Secuencial'
    ELSE 'Desconocido'
  END AS download_mode,
  
  -- Resultado
  success,
  zip_id

FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`

WHERE 
  -- Solo conversaciones con ZIP generado
  zip_generated = TRUE
  AND zip_generation_time_ms IS NOT NULL
  
  -- Últimas 24 horas
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)

ORDER BY timestamp DESC

LIMIT 100;
