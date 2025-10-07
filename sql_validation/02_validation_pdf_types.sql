-- ============================================================================
-- Query 02: Validación de Tipos de PDF Disponibles
-- ============================================================================
-- 
-- Propósito: Analizar disponibilidad de cada tipo de PDF en el dataset
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Tipos de PDF:
-- - Copia_Tributaria_cf (Tributaria con Fondo - logo Gasco)
-- - Copia_Cedible_cf (Cedible con Fondo - logo Gasco)
-- - Copia_Tributaria_sf (Tributaria sin Fondo)
-- - Copia_Cedible_sf (Cedible sin Fondo)
-- - Doc_Termico (Documento Térmico)
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

WITH pdf_availability AS (
  SELECT
    Factura,
    Rut,
    fecha,
    -- Flags de disponibilidad
    CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END AS tiene_tributaria_cf,
    CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END AS tiene_cedible_cf,
    CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END AS tiene_tributaria_sf,
    CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END AS tiene_cedible_sf,
    CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END AS tiene_doc_termico
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
)

SELECT
  -- Estadísticas por tipo de PDF
  'Copia Tributaria CF' AS tipo_pdf,
  SUM(tiene_tributaria_cf) AS cantidad_disponible,
  ROUND(100.0 * SUM(tiene_tributaria_cf) / COUNT(*), 2) AS porcentaje_disponibilidad,
  COUNT(*) - SUM(tiene_tributaria_cf) AS cantidad_faltante
FROM pdf_availability

UNION ALL

SELECT
  'Copia Cedible CF' AS tipo_pdf,
  SUM(tiene_cedible_cf) AS cantidad_disponible,
  ROUND(100.0 * SUM(tiene_cedible_cf) / COUNT(*), 2) AS porcentaje_disponibilidad,
  COUNT(*) - SUM(tiene_cedible_cf) AS cantidad_faltante
FROM pdf_availability

UNION ALL

SELECT
  'Copia Tributaria SF' AS tipo_pdf,
  SUM(tiene_tributaria_sf) AS cantidad_disponible,
  ROUND(100.0 * SUM(tiene_tributaria_sf) / COUNT(*), 2) AS porcentaje_disponibilidad,
  COUNT(*) - SUM(tiene_tributaria_sf) AS cantidad_faltante
FROM pdf_availability

UNION ALL

SELECT
  'Copia Cedible SF' AS tipo_pdf,
  SUM(tiene_cedible_sf) AS cantidad_disponible,
  ROUND(100.0 * SUM(tiene_cedible_sf) / COUNT(*), 2) AS porcentaje_disponibilidad,
  COUNT(*) - SUM(tiene_cedible_sf) AS cantidad_faltante
FROM pdf_availability

UNION ALL

SELECT
  'Documento Térmico' AS tipo_pdf,
  SUM(tiene_doc_termico) AS cantidad_disponible,
  ROUND(100.0 * SUM(tiene_doc_termico) / COUNT(*), 2) AS porcentaje_disponibilidad,
  COUNT(*) - SUM(tiene_doc_termico) AS cantidad_faltante
FROM pdf_availability

ORDER BY porcentaje_disponibilidad DESC

-- ============================================================================
-- Validaciones esperadas:
-- ✓ Copia Tributaria CF y Cedible CF > 80% disponibilidad
-- ✓ Copia Tributaria SF y Cedible SF < 50% disponibilidad (menos común)
-- ✓ Documento Térmico < 30% disponibilidad (específico)
-- ============================================================================
