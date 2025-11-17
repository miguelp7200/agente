-- Query simplificada para ver las últimas métricas de ZIPs
-- Ejecutar manualmente en la consola de BigQuery

SELECT
  FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', timestamp) as timestamp,
  SUBSTR(conversation_id, 1, 8) as conv_id,
  zip_generation_time_ms,
  zip_parallel_download_time_ms,
  zip_max_workers_used,
  zip_files_included,
  ROUND(zip_total_size_bytes / 1024 / 1024, 2) AS size_mb,
  ROUND(zip_generation_time_ms / NULLIF(zip_files_included, 0), 2) AS ms_per_file,
  CASE 
    WHEN zip_max_workers_used > 1 THEN 'Paralelo'
    WHEN zip_max_workers_used = 1 THEN 'Secuencial'
    ELSE 'Desconocido'
  END AS mode
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE 
  zip_generated = TRUE
  AND zip_generation_time_ms IS NOT NULL
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY timestamp DESC
LIMIT 20;
