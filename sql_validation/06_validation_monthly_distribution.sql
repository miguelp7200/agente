-- ============================================================================
-- Query 06: Validación de Distribución Mensual
-- ============================================================================
-- 
-- Propósito: Analizar distribución de facturas por mes del año
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Análisis:
-- - Facturas por mes (agregado de todos los años)
-- - Identificar meses con mayor/menor actividad
-- - Patrones estacionales
-- - Comparación mes a mes
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

WITH monthly_data AS (
  SELECT
    EXTRACT(MONTH FROM fecha) AS mes,
    CASE EXTRACT(MONTH FROM fecha)
      WHEN 1 THEN 'Enero'
      WHEN 2 THEN 'Febrero'
      WHEN 3 THEN 'Marzo'
      WHEN 4 THEN 'Abril'
      WHEN 5 THEN 'Mayo'
      WHEN 6 THEN 'Junio'
      WHEN 7 THEN 'Julio'
      WHEN 8 THEN 'Agosto'
      WHEN 9 THEN 'Septiembre'
      WHEN 10 THEN 'Octubre'
      WHEN 11 THEN 'Noviembre'
      WHEN 12 THEN 'Diciembre'
    END AS mes_nombre,
    COUNT(*) AS facturas_mes,
    COUNT(DISTINCT EXTRACT(YEAR FROM fecha)) AS anos_con_datos,
    COUNT(DISTINCT Rut) AS ruts_distintos_mes,
    -- Promedio de facturas por año en ese mes
    ROUND(COUNT(*) / COUNT(DISTINCT EXTRACT(YEAR FROM fecha)), 2) AS facturas_promedio_por_ano
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  GROUP BY mes, mes_nombre
)

SELECT
  mes,
  mes_nombre,
  facturas_mes,
  anos_con_datos,
  ruts_distintos_mes,
  facturas_promedio_por_ano,
  ROUND(100.0 * facturas_mes / SUM(facturas_mes) OVER (), 2) AS porcentaje_del_total,
  -- Ranking de meses
  RANK() OVER (ORDER BY facturas_mes DESC) AS ranking_actividad
FROM monthly_data
ORDER BY mes

-- ============================================================================
-- Análisis Adicional: Variabilidad Mensual
-- ============================================================================

-- SELECT
--   'VARIABILIDAD MENSUAL' AS metrica,
--   MIN(facturas_mes) AS mes_minimo,
--   MAX(facturas_mes) AS mes_maximo,
--   ROUND(AVG(facturas_mes), 2) AS promedio_mensual,
--   ROUND(STDDEV(facturas_mes), 2) AS desviacion_estandar,
--   ROUND((MAX(facturas_mes) - MIN(facturas_mes)) / MIN(facturas_mes) * 100, 2) AS variacion_porcentual
-- FROM monthly_data

-- ============================================================================
-- Validaciones esperadas:
-- ✓ Todos los meses (1-12) tienen datos
-- ✓ anos_con_datos >= 8 para cada mes
-- ✓ Variabilidad mensual < 30% (operación relativamente estable)
-- ✓ No hay meses con 0 facturas
-- ✓ porcentaje_del_total entre 7-10% (distribución balanceada)
-- ============================================================================
