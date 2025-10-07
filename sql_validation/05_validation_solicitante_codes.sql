-- ============================================================================
-- Query 05: Validación de Códigos de Solicitante
-- ============================================================================
-- 
-- Propósito: Analizar códigos de solicitante (SAP) y su distribución
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Análisis:
-- - Códigos de solicitante únicos
-- - Distribución de facturas por solicitante
-- - Relación Solicitante-RUT (1:N)
-- - Validación de formato de códigos (10 dígitos con ceros leading)
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

WITH solicitante_stats AS (
  SELECT
    Solicitante,
    COUNT(*) AS total_facturas,
    COUNT(DISTINCT Rut) AS ruts_distintos,
    MIN(Nombre) AS nombre_cliente,
    MIN(fecha) AS primera_factura,
    MAX(fecha) AS ultima_factura,
    DATE_DIFF(MAX(fecha), MIN(fecha), DAY) AS dias_actividad,
    -- Contar PDFs
    COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) AS pdfs_disponibles
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  GROUP BY Solicitante
),

formato_validation AS (
  SELECT
    Solicitante,
    LENGTH(Solicitante) AS longitud_codigo,
    CASE 
      WHEN LENGTH(Solicitante) = 10 THEN 'Formato correcto (10 dígitos)'
      WHEN LENGTH(Solicitante) < 10 THEN 'Formato incorrecto (< 10 dígitos)'
      ELSE 'Formato incorrecto (> 10 dígitos)'
    END AS validacion_formato,
    CASE 
      WHEN REGEXP_CONTAINS(Solicitante, r'^[0-9]+$') THEN 'Solo números'
      ELSE 'Contiene caracteres no numéricos'
    END AS validacion_caracteres
  FROM (
    SELECT DISTINCT Solicitante 
    FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  )
)

-- Top 30 Solicitantes con más facturas
SELECT
  'TOP SOLICITANTES' AS seccion,
  s.Solicitante,
  s.nombre_cliente,
  s.total_facturas,
  s.ruts_distintos,
  CAST(s.primera_factura AS STRING) AS primera_factura,
  CAST(s.ultima_factura AS STRING) AS ultima_factura,
  s.dias_actividad,
  ROUND(100.0 * s.pdfs_disponibles / s.total_facturas, 2) AS porcentaje_pdfs,
  f.validacion_formato
FROM solicitante_stats s
JOIN formato_validation f ON s.Solicitante = f.Solicitante
ORDER BY s.total_facturas DESC
LIMIT 30

-- ============================================================================
-- Resumen de validación de formatos
-- ============================================================================

-- UNION ALL

-- SELECT
--   'FORMATO' AS seccion,
--   validacion_formato AS Solicitante,
--   '' AS nombre_cliente,
--   COUNT(*) AS total_facturas,
--   0 AS ruts_distintos,
--   '' AS primera_factura,
--   '' AS ultima_factura,
--   0 AS dias_actividad,
--   0.0 AS porcentaje_pdfs,
--   validacion_caracteres
-- FROM formato_validation
-- GROUP BY validacion_formato, validacion_caracteres

-- ============================================================================
-- Validaciones esperadas:
-- ✓ Todos los códigos Solicitante tienen longitud = 10 caracteres
-- ✓ Todos los códigos Solicitante son numéricos (0-9)
-- ✓ Códigos comienzan con ceros leading (ej: 0012537749)
-- ✓ Cada Solicitante puede tener múltiples RUTs (ruts_distintos > 1 posible)
-- ✓ porcentaje_pdfs > 85% para top solicitantes
-- ============================================================================
