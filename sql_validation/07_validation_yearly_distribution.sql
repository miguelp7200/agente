-- ============================================================================
-- Query 07: Validación de Distribución Anual
-- ============================================================================
-- 
-- Propósito: Analizar distribución de facturas por año
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Análisis:
-- - Facturas por año (2017-2025)
-- - Crecimiento/decrecimiento año a año
-- - Cobertura completa de meses por año
-- - Identificar años con actividad anormal
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

WITH yearly_data AS (
  SELECT
    EXTRACT(YEAR FROM fecha) AS ano,
    COUNT(*) AS facturas_ano,
    COUNT(DISTINCT EXTRACT(MONTH FROM fecha)) AS meses_con_datos,
    COUNT(DISTINCT Rut) AS ruts_distintos_ano,
    COUNT(DISTINCT Solicitante) AS solicitantes_distintos_ano,
    MIN(fecha) AS primera_fecha,
    MAX(fecha) AS ultima_fecha,
    -- Contar PDFs disponibles
    COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) AS pdfs_tributaria_cf,
    COUNT(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 END) AS pdfs_cedible_cf,
    -- Promedio diario
    ROUND(COUNT(*) / DATE_DIFF(MAX(fecha), MIN(fecha), DAY), 2) AS facturas_por_dia_promedio
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  GROUP BY ano
),

yearly_growth AS (
  SELECT
    ano,
    facturas_ano,
    LAG(facturas_ano) OVER (ORDER BY ano) AS facturas_ano_anterior,
    ROUND(
      100.0 * (facturas_ano - LAG(facturas_ano) OVER (ORDER BY ano)) / 
      NULLIF(LAG(facturas_ano) OVER (ORDER BY ano), 0), 
      2
    ) AS crecimiento_porcentual
  FROM yearly_data
)

SELECT
  y.ano,
  y.facturas_ano,
  ROUND(100.0 * y.facturas_ano / SUM(y.facturas_ano) OVER (), 2) AS porcentaje_del_total,
  g.crecimiento_porcentual,
  y.meses_con_datos,
  y.ruts_distintos_ano,
  y.solicitantes_distintos_ano,
  CAST(y.primera_fecha AS STRING) AS primera_fecha,
  CAST(y.ultima_fecha AS STRING) AS ultima_fecha,
  ROUND(100.0 * y.pdfs_tributaria_cf / y.facturas_ano, 2) AS porcentaje_tributaria_cf,
  ROUND(100.0 * y.pdfs_cedible_cf / y.facturas_ano, 2) AS porcentaje_cedible_cf,
  y.facturas_por_dia_promedio
FROM yearly_data y
JOIN yearly_growth g ON y.ano = g.ano
ORDER BY y.ano

-- ============================================================================
-- Resumen Agregado
-- ============================================================================

-- SELECT
--   'RESUMEN' AS ano,
--   SUM(facturas_ano) AS facturas_ano,
--   100.0 AS porcentaje_del_total,
--   NULL AS crecimiento_porcentual,
--   COUNT(DISTINCT ano) AS meses_con_datos,  -- Años con datos
--   NULL AS ruts_distintos_ano,
--   NULL AS solicitantes_distintos_ano,
--   CAST(MIN(primera_fecha) AS STRING) AS primera_fecha,
--   CAST(MAX(ultima_fecha) AS STRING) AS ultima_fecha,
--   ROUND(AVG(porcentaje_tributaria_cf), 2) AS porcentaje_tributaria_cf,
--   ROUND(AVG(porcentaje_cedible_cf), 2) AS porcentaje_cedible_cf,
--   ROUND(AVG(facturas_por_dia_promedio), 2) AS facturas_por_dia_promedio
-- FROM yearly_data

-- ============================================================================
-- Validaciones esperadas:
-- ✓ Años consecutivos sin gaps (2017, 2018, 2019... 2025)
-- ✓ meses_con_datos = 12 para años completos
-- ✓ Crecimiento relativo < ±50% año a año (sin cambios dramáticos)
-- ✓ porcentaje_tributaria_cf y porcentaje_cedible_cf > 85%
-- ✓ facturas_por_dia_promedio > 100 (operación activa)
-- ✓ 2025 puede tener meses_con_datos < 12 (año incompleto)
-- ============================================================================
