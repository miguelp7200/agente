-- ============================================================================
-- Query 01: Validación de Conteos Generales del Dataset
-- ============================================================================
-- 
-- Propósito: Obtener métricas generales del dataset de facturas
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Resultados Esperados:
-- - Total de facturas: ~1,614,688
-- - RUTs únicos: ~2,000+
-- - Solicitantes únicos: ~1,000+
-- - Rango temporal: 2017-2025
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

SELECT
  -- Conteos principales
  COUNT(*) AS total_facturas,
  COUNT(DISTINCT Rut) AS ruts_unicos,
  COUNT(DISTINCT Nombre) AS nombres_unicos,
  COUNT(DISTINCT Solicitante) AS solicitantes_unicos,
  
  -- Rango temporal
  MIN(fecha) AS fecha_minima,
  MAX(fecha) AS fecha_maxima,
  DATE_DIFF(MAX(fecha), MIN(fecha), DAY) AS dias_cobertura,
  
  -- Conteos de PDFs disponibles
  COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) AS facturas_con_tributaria_cf,
  COUNT(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 END) AS facturas_con_cedible_cf,
  COUNT(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 END) AS facturas_con_tributaria_sf,
  COUNT(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 END) AS facturas_con_cedible_sf,
  COUNT(CASE WHEN Doc_Termico IS NOT NULL THEN 1 END) AS facturas_con_doc_termico,
  
  -- Porcentajes de disponibilidad
  ROUND(100.0 * COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) / COUNT(*), 2) AS porcentaje_tributaria_cf,
  ROUND(100.0 * COUNT(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 END) / COUNT(*), 2) AS porcentaje_cedible_cf,
  
  -- Promedios
  ROUND(AVG(CAST(JSON_EXTRACT_SCALAR(DetallesFactura, '$[0].ValorTotal') AS FLOAT64)), 2) AS valor_promedio_factura

FROM 
  `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

-- ============================================================================
-- Validaciones esperadas:
-- ✓ total_facturas > 1,500,000
-- ✓ ruts_unicos > 1,500
-- ✓ fecha_minima <= 2017-01-01
-- ✓ fecha_maxima >= 2025-01-01
-- ✓ porcentaje_tributaria_cf > 80%
-- ✓ porcentaje_cedible_cf > 80%
-- ============================================================================
