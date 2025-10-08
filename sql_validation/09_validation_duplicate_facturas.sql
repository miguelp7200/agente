-- ============================================================================
-- Query 09: Validación de Facturas Duplicadas
-- ============================================================================
-- 
-- Propósito: Detectar posibles duplicados en el dataset
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Análisis:
-- - Duplicados por número de factura
-- - Duplicados por combinación Factura + RUT + Fecha
-- - Facturas con números idénticos pero clientes diferentes
-- - Validar unicidad de registros
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

-- 1. Detectar números de factura duplicados
WITH factura_counts AS (
  SELECT
    Factura,
    COUNT(*) AS veces_aparece,
    COUNT(DISTINCT Rut) AS ruts_distintos,
    COUNT(DISTINCT fecha) AS fechas_distintas,
    STRING_AGG(DISTINCT Rut ORDER BY Rut LIMIT 5) AS ruts_muestra,
    STRING_AGG(DISTINCT CAST(fecha AS STRING) ORDER BY fecha LIMIT 5) AS fechas_muestra
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  GROUP BY Factura
  HAVING COUNT(*) > 1  -- Solo duplicados
),

-- 2. Analizar severidad de duplicados
duplicate_analysis AS (
  SELECT
    CASE 
      WHEN ruts_distintos = 1 AND fechas_distintas = 1 THEN 'Duplicado exacto (mismo RUT, misma fecha)'
      WHEN ruts_distintos = 1 AND fechas_distintas > 1 THEN 'Mismo RUT, fechas diferentes'
      WHEN ruts_distintos > 1 AND fechas_distintas = 1 THEN 'Misma fecha, RUTs diferentes'
      ELSE 'Múltiples RUTs y fechas diferentes'
    END AS tipo_duplicado,
    COUNT(*) AS cantidad_facturas_duplicadas,
    SUM(veces_aparece) AS total_registros_duplicados
  FROM factura_counts
  GROUP BY tipo_duplicado
)

-- Resumen de duplicados por tipo
SELECT
  tipo_duplicado,
  cantidad_facturas_duplicadas,
  total_registros_duplicados,
  ROUND(100.0 * cantidad_facturas_duplicadas / SUM(cantidad_facturas_duplicadas) OVER (), 2) AS porcentaje_del_total
FROM duplicate_analysis
ORDER BY cantidad_facturas_duplicadas DESC

-- ============================================================================
-- Top facturas más duplicadas
-- ============================================================================

-- UNION ALL

-- SELECT
--   'TOP DUPLICADOS' AS tipo_duplicado,
--   NULL AS cantidad_facturas_duplicadas,
--   NULL AS total_registros_duplicados,
--   NULL AS porcentaje_del_total
-- FROM (SELECT 1)  -- Separador

-- UNION ALL

-- SELECT
--   Factura AS tipo_duplicado,
--   veces_aparece AS cantidad_facturas_duplicadas,
--   ruts_distintos AS total_registros_duplicados,
--   fechas_distintas AS porcentaje_del_total
-- FROM factura_counts
-- ORDER BY veces_aparece DESC
-- LIMIT 20

-- ============================================================================
-- Validación de unicidad completa (Factura + RUT + Fecha)
-- ============================================================================

-- SELECT
--   'VALIDACIÓN UNICIDAD' AS metrica,
--   COUNT(*) AS total_registros,
--   COUNT(DISTINCT CONCAT(Factura, '|', Rut, '|', CAST(fecha AS STRING))) AS combinaciones_unicas,
--   COUNT(*) - COUNT(DISTINCT CONCAT(Factura, '|', Rut, '|', CAST(fecha AS STRING))) AS registros_duplicados_exactos,
--   ROUND(100.0 * (COUNT(*) - COUNT(DISTINCT CONCAT(Factura, '|', Rut, '|', CAST(fecha AS STRING)))) / COUNT(*), 4) AS porcentaje_duplicados
-- FROM 
--   `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

-- ============================================================================
-- Validaciones esperadas:
-- ✓ < 1% de facturas tienen números duplicados
-- ✓ Mayoría de "duplicados" son: Misma factura para RUTs diferentes (normal)
-- ✓ "Duplicado exacto" (mismo número, RUT y fecha) < 0.01%
-- ✓ Si existen duplicados exactos, verificar si son reemisiones o errores
-- ✓ registros_duplicados_exactos idealmente = 0
-- ============================================================================
