-- ============================================================================
-- Query 04: Validación de Estadísticas por RUT
-- ============================================================================
-- 
-- Propósito: Analizar distribución de facturas por RUT de clientes
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Análisis:
-- - Top RUTs con más facturas
-- - Distribución de facturas por RUT
-- - RUTs con actividad reciente vs histórica
-- - Cobertura temporal por RUT
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

WITH rut_stats AS (
  SELECT
    Rut,
    Nombre,
    COUNT(*) AS total_facturas,
    MIN(fecha) AS primera_factura,
    MAX(fecha) AS ultima_factura,
    DATE_DIFF(MAX(fecha), MIN(fecha), DAY) AS dias_actividad,
    COUNT(DISTINCT Solicitante) AS solicitantes_distintos,
    -- Contar PDFs disponibles
    COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) AS pdfs_tributaria_cf,
    COUNT(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 END) AS pdfs_cedible_cf
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  GROUP BY Rut, Nombre
),

rut_distribution AS (
  SELECT
    CASE 
      WHEN total_facturas >= 10000 THEN '10,000+'
      WHEN total_facturas >= 5000 THEN '5,000-9,999'
      WHEN total_facturas >= 1000 THEN '1,000-4,999'
      WHEN total_facturas >= 500 THEN '500-999'
      WHEN total_facturas >= 100 THEN '100-499'
      WHEN total_facturas >= 50 THEN '50-99'
      WHEN total_facturas >= 10 THEN '10-49'
      ELSE '1-9'
    END AS rango_facturas,
    COUNT(*) AS cantidad_ruts
  FROM rut_stats
  GROUP BY rango_facturas
)

-- Top 20 RUTs con más facturas
SELECT
  'TOP RUTs' AS seccion,
  Rut,
  Nombre,
  total_facturas,
  CAST(primera_factura AS STRING) AS primera_factura,
  CAST(ultima_factura AS STRING) AS ultima_factura,
  dias_actividad,
  solicitantes_distintos,
  pdfs_tributaria_cf,
  pdfs_cedible_cf
FROM rut_stats
ORDER BY total_facturas DESC
LIMIT 20

-- ============================================================================
-- Métricas adicionales - Distribución
-- ============================================================================

-- UNION ALL

-- SELECT
--   'DISTRIBUCIÓN' AS seccion,
--   rango_facturas AS Rut,
--   '' AS Nombre,
--   cantidad_ruts AS total_facturas,
--   '' AS primera_factura,
--   '' AS ultima_factura,
--   0 AS dias_actividad,
--   0 AS solicitantes_distintos,
--   0 AS pdfs_tributaria_cf,
--   0 AS pdfs_cedible_cf
-- FROM rut_distribution
-- ORDER BY 
--   CASE rango_facturas
--     WHEN '10,000+' THEN 1
--     WHEN '5,000-9,999' THEN 2
--     WHEN '1,000-4,999' THEN 3
--     WHEN '500-999' THEN 4
--     WHEN '100-499' THEN 5
--     WHEN '50-99' THEN 6
--     WHEN '10-49' THEN 7
--     ELSE 8
--   END

-- ============================================================================
-- Validaciones esperadas:
-- ✓ Top RUT tiene > 5,000 facturas
-- ✓ Top 10 RUTs representan ~30-40% del total
-- ✓ Mayoría de RUTs tienen actividad multi-año (dias_actividad > 365)
-- ✓ pdfs_tributaria_cf y pdfs_cedible_cf > 80% de total_facturas
-- ============================================================================
