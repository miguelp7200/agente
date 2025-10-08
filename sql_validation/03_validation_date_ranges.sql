-- ============================================================================
-- Query 03: Validación de Rangos Temporales
-- ============================================================================
-- 
-- Propósito: Validar cobertura temporal del dataset y distribución de facturas
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Análisis:
-- - Rango temporal completo (primera y última factura)
-- - Años con cobertura
-- - Períodos con mayor/menor actividad
-- - Gaps temporales (si existen)
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

WITH temporal_stats AS (
  SELECT
    MIN(fecha) AS primera_factura,
    MAX(fecha) AS ultima_factura,
    DATE_DIFF(MAX(fecha), MIN(fecha), DAY) AS dias_totales,
    DATE_DIFF(MAX(fecha), MIN(fecha), MONTH) AS meses_totales,
    DATE_DIFF(MAX(fecha), MIN(fecha), YEAR) AS anos_totales,
    COUNT(*) AS total_facturas,
    ROUND(COUNT(*) / DATE_DIFF(MAX(fecha), MIN(fecha), DAY), 2) AS facturas_por_dia_promedio
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
),

yearly_coverage AS (
  SELECT
    EXTRACT(YEAR FROM fecha) AS ano,
    COUNT(*) AS facturas_ano,
    MIN(fecha) AS primera_fecha_ano,
    MAX(fecha) AS ultima_fecha_ano,
    COUNT(DISTINCT EXTRACT(MONTH FROM fecha)) AS meses_con_datos
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  GROUP BY ano
  ORDER BY ano
)

-- Resumen temporal general
SELECT
  'RESUMEN TEMPORAL' AS seccion,
  CAST(primera_factura AS STRING) AS valor1,
  CAST(ultima_factura AS STRING) AS valor2,
  CAST(dias_totales AS STRING) AS valor3,
  CAST(meses_totales AS STRING) AS valor4,
  CAST(anos_totales AS STRING) AS valor5,
  CAST(total_facturas AS STRING) AS valor6,
  CAST(facturas_por_dia_promedio AS STRING) AS valor7
FROM temporal_stats

UNION ALL

-- Detalle por año
SELECT
  'AÑO ' || CAST(ano AS STRING) AS seccion,
  CAST(facturas_ano AS STRING) AS valor1,
  CAST(primera_fecha_ano AS STRING) AS valor2,
  CAST(ultima_fecha_ano AS STRING) AS valor3,
  CAST(meses_con_datos AS STRING) AS valor4,
  CAST(ROUND(100.0 * facturas_ano / (SELECT SUM(facturas_ano) FROM yearly_coverage), 2) AS STRING) AS valor5,
  '' AS valor6,
  '' AS valor7
FROM yearly_coverage
ORDER BY seccion

-- ============================================================================
-- Interpretación de columnas:
-- RESUMEN TEMPORAL:
--   valor1: primera_factura
--   valor2: ultima_factura  
--   valor3: dias_totales
--   valor4: meses_totales
--   valor5: anos_totales
--   valor6: total_facturas
--   valor7: facturas_por_dia_promedio
--
-- AÑO XXXX:
--   valor1: facturas_ano
--   valor2: primera_fecha_ano
--   valor3: ultima_fecha_ano
--   valor4: meses_con_datos
--   valor5: porcentaje_del_total
--
-- Validaciones esperadas:
-- ✓ primera_factura <= 2017-12-31
-- ✓ ultima_factura >= 2025-01-01
-- ✓ anos_totales >= 8
-- ✓ facturas_por_dia_promedio > 100
-- ✓ Todos los años tienen meses_con_datos = 12
-- ============================================================================
