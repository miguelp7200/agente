-- ============================================================================
-- CONSULTA SQL PARA VERIFICAR "GAS LAS NACIONES" EN BIGQUERY
-- ============================================================================

-- 1. BÚSQUEDA EXACTA (case-sensitive)
SELECT 
  COUNT(*) as facturas_exactas,
  'Búsqueda exacta case-sensitive' as tipo_busqueda
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Nombre = 'GAS LAS NACIONES'

UNION ALL

-- 2. BÚSQUEDA CASE-INSENSITIVE (recomendada)
SELECT 
  COUNT(*) as facturas_case_insensitive,
  'Búsqueda case-insensitive' as tipo_busqueda
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE UPPER(Nombre) = UPPER('GAS LAS NACIONES')

UNION ALL

-- 3. BÚSQUEDA PARCIAL (contiene el texto)
SELECT 
  COUNT(*) as facturas_contiene,
  'Búsqueda parcial (contiene)' as tipo_busqueda
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE UPPER(Nombre) LIKE '%GAS%LAS%NACIONES%'

UNION ALL

-- 4. BÚSQUEDA EN CAMPO SOLICITANTE
SELECT 
  COUNT(*) as facturas_solicitante,
  'Búsqueda en Solicitante' as tipo_busqueda
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE UPPER(Solicitante) LIKE '%GAS%LAS%NACIONES%'

ORDER BY facturas_exactas DESC;

-- ============================================================================
-- CONSULTA DETALLADA PARA VER VALORES SIMILARES
-- ============================================================================

-- Buscar todos los nombres que contengan "GAS" para ver las variaciones exactas
SELECT DISTINCT
  Nombre,
  Solicitante,
  COUNT(*) as total_facturas
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE 
  UPPER(Nombre) LIKE '%GAS%' 
  OR UPPER(Solicitante) LIKE '%GAS%'
GROUP BY Nombre, Solicitante
ORDER BY total_facturas DESC
LIMIT 20;

-- ============================================================================
-- CONSULTA ESPECÍFICA PARA JULIO 2025 (la fecha que estamos buscando)
-- ============================================================================

SELECT 
  Factura,
  Nombre,
  Solicitante,
  fecha,
  EXTRACT(YEAR FROM fecha) as año,
  EXTRACT(MONTH FROM fecha) as mes
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE 
  (UPPER(Nombre) LIKE '%GAS%LAS%NACIONES%' 
   OR UPPER(Solicitante) LIKE '%GAS%LAS%NACIONES%')
  AND EXTRACT(YEAR FROM fecha) = 2025
  AND EXTRACT(MONTH FROM fecha) = 7
ORDER BY fecha DESC
LIMIT 10;