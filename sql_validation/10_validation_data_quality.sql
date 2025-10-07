-- ============================================================================
-- Query 10: Validación de Calidad de Datos General
-- ============================================================================
-- 
-- Propósito: Analizar calidad general del dataset
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Análisis:
-- - Campos NULL o vacíos
-- - Valores atípicos (outliers)
-- - Consistencia de datos
-- - Integridad referencial
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

WITH data_quality_metrics AS (
  SELECT
    -- Conteo total
    COUNT(*) AS total_registros,
    
    -- Campos críticos NULL
    COUNT(CASE WHEN Factura IS NULL OR Factura = '' THEN 1 END) AS factura_null,
    COUNT(CASE WHEN Rut IS NULL OR Rut = '' THEN 1 END) AS rut_null,
    COUNT(CASE WHEN Nombre IS NULL OR Nombre = '' THEN 1 END) AS nombre_null,
    COUNT(CASE WHEN Solicitante IS NULL OR Solicitante = '' THEN 1 END) AS solicitante_null,
    COUNT(CASE WHEN fecha IS NULL THEN 1 END) AS fecha_null,
    
    -- Campos opcionales NULL
    COUNT(CASE WHEN DetallesFactura IS NULL THEN 1 END) AS detalles_null,
    COUNT(CASE WHEN Factura_Referencia IS NULL OR Factura_Referencia = '' THEN 1 END) AS referencia_null,
    
    -- PDFs NULL (esperado para algunos)
    COUNT(CASE WHEN Copia_Tributaria_cf IS NULL THEN 1 END) AS tributaria_cf_null,
    COUNT(CASE WHEN Copia_Cedible_cf IS NULL THEN 1 END) AS cedible_cf_null,
    
    -- Facturas completamente sin PDFs
    COUNT(CASE 
      WHEN Copia_Tributaria_cf IS NULL 
        AND Copia_Cedible_cf IS NULL 
        AND Copia_Tributaria_sf IS NULL 
        AND Copia_Cedible_sf IS NULL 
        AND Doc_Termico IS NULL 
      THEN 1 
    END) AS sin_ningun_pdf,
    
    -- Validaciones de formato RUT
    COUNT(CASE 
      WHEN Rut IS NOT NULL 
        AND NOT REGEXP_CONTAINS(Rut, r'^[0-9]+-[0-9Kk]$') 
      THEN 1 
    END) AS rut_formato_invalido,
    
    -- Validaciones de longitud Solicitante
    COUNT(CASE 
      WHEN Solicitante IS NOT NULL 
        AND LENGTH(Solicitante) != 10 
      THEN 1 
    END) AS solicitante_longitud_invalida,
    
    -- Fechas futuras (anomalía)
    COUNT(CASE 
      WHEN fecha > CURRENT_DATE() 
      THEN 1 
    END) AS fechas_futuras,
    
    -- Fechas muy antiguas (pre-2000, sospechoso)
    COUNT(CASE 
      WHEN fecha < '2000-01-01' 
      THEN 1 
    END) AS fechas_muy_antiguas
    
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
)

-- Reporte de calidad de datos
SELECT
  'Total Registros' AS metrica,
  total_registros AS cantidad,
  ROUND(100.0 * total_registros / total_registros, 2) AS porcentaje,
  'Baseline' AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Factura NULL o vacía' AS metrica,
  factura_null AS cantidad,
  ROUND(100.0 * factura_null / total_registros, 4) AS porcentaje,
  CASE WHEN factura_null > 0 THEN 'CRÍTICO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'RUT NULL o vacío' AS metrica,
  rut_null AS cantidad,
  ROUND(100.0 * rut_null / total_registros, 4) AS porcentaje,
  CASE WHEN rut_null > 0 THEN 'CRÍTICO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Nombre NULL o vacío' AS metrica,
  nombre_null AS cantidad,
  ROUND(100.0 * nombre_null / total_registros, 4) AS porcentaje,
  CASE WHEN nombre_null > total_registros * 0.01 THEN 'ALTO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Solicitante NULL o vacío' AS metrica,
  solicitante_null AS cantidad,
  ROUND(100.0 * solicitante_null / total_registros, 4) AS porcentaje,
  CASE WHEN solicitante_null > 0 THEN 'CRÍTICO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Fecha NULL' AS metrica,
  fecha_null AS cantidad,
  ROUND(100.0 * fecha_null / total_registros, 4) AS porcentaje,
  CASE WHEN fecha_null > 0 THEN 'CRÍTICO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Sin ningún PDF disponible' AS metrica,
  sin_ningun_pdf AS cantidad,
  ROUND(100.0 * sin_ningun_pdf / total_registros, 4) AS porcentaje,
  CASE WHEN sin_ningun_pdf > total_registros * 0.05 THEN 'ALTO' ELSE 'MEDIO' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'RUT formato inválido' AS metrica,
  rut_formato_invalido AS cantidad,
  ROUND(100.0 * rut_formato_invalido / total_registros, 4) AS porcentaje,
  CASE WHEN rut_formato_invalido > 0 THEN 'ALTO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Solicitante longitud inválida' AS metrica,
  solicitante_longitud_invalida AS cantidad,
  ROUND(100.0 * solicitante_longitud_invalida / total_registros, 4) AS porcentaje,
  CASE WHEN solicitante_longitud_invalida > 0 THEN 'ALTO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Fechas futuras (anomalía)' AS metrica,
  fechas_futuras AS cantidad,
  ROUND(100.0 * fechas_futuras / total_registros, 4) AS porcentaje,
  CASE WHEN fechas_futuras > 0 THEN 'ALTO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Fechas muy antiguas (pre-2000)' AS metrica,
  fechas_muy_antiguas AS cantidad,
  ROUND(100.0 * fechas_muy_antiguas / total_registros, 4) AS porcentaje,
  CASE WHEN fechas_muy_antiguas > 0 THEN 'MEDIO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Tributaria CF NULL' AS metrica,
  tributaria_cf_null AS cantidad,
  ROUND(100.0 * tributaria_cf_null / total_registros, 2) AS porcentaje,
  CASE WHEN tributaria_cf_null > total_registros * 0.20 THEN 'MEDIO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

UNION ALL

SELECT
  'Cedible CF NULL' AS metrica,
  cedible_cf_null AS cantidad,
  ROUND(100.0 * cedible_cf_null / total_registros, 2) AS porcentaje,
  CASE WHEN cedible_cf_null > total_registros * 0.20 THEN 'MEDIO' ELSE 'OK' END AS severidad
FROM data_quality_metrics

ORDER BY 
  CASE severidad
    WHEN 'CRÍTICO' THEN 1
    WHEN 'ALTO' THEN 2
    WHEN 'MEDIO' THEN 3
    WHEN 'OK' THEN 4
    ELSE 5
  END,
  porcentaje DESC

-- ============================================================================
-- Validaciones esperadas:
-- ✓ Campos críticos (Factura, RUT, Solicitante, fecha) = 0% NULL
-- ✓ sin_ningun_pdf < 5%
-- ✓ rut_formato_invalido = 0
-- ✓ solicitante_longitud_invalida = 0
-- ✓ fechas_futuras = 0
-- ✓ fechas_muy_antiguas = 0
-- ✓ Todas las métricas con severidad = 'OK'
-- ============================================================================
