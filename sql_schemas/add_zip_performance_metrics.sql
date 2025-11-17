-- Script para agregar métricas de performance de ZIP a conversation_logs
-- Fecha: 2025-11-11
-- Propósito: Capturar métricas de descarga paralela y generación de ZIPs

-- Tabla: agent-intelligence-gasco.chat_analytics.conversation_logs

-- 1. Métricas de performance de generación de ZIP
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS zip_generation_time_ms INT64
OPTIONS(description="Tiempo total de generación del ZIP en milisegundos");

ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS zip_parallel_download_time_ms INT64
OPTIONS(description="Tiempo de descarga paralela de PDFs en milisegundos");

ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS zip_max_workers_used INT64
OPTIONS(description="Número de workers paralelos utilizados para descarga de PDFs");

-- 2. Métricas de archivos en ZIP
ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS zip_files_included INT64
OPTIONS(description="Número de archivos incluidos en el ZIP");

ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS zip_files_missing INT64
OPTIONS(description="Número de archivos que no se pudieron incluir en el ZIP");

ALTER TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs`
ADD COLUMN IF NOT EXISTS zip_total_size_bytes INT64
OPTIONS(description="Tamaño total del ZIP generado en bytes");
