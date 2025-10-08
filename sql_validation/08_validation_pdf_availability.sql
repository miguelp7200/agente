-- ============================================================================
-- Query 08: Validación de Disponibilidad de PDFs
-- ============================================================================
-- 
-- Propósito: Validar que las URLs de PDFs apuntan a archivos válidos en GCS
-- Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- 
-- Análisis:
-- - URLs de GCS bien formadas (gs://miguel-test/...)
-- - Combinaciones de tipos de PDF disponibles
-- - Facturas con PDFs completos vs parciales
-- - Patrones de disponibilidad por tipo
-- 
-- Última actualización: 3 de octubre de 2025
-- ============================================================================

WITH pdf_patterns AS (
  SELECT
    Factura,
    Rut,
    fecha,
    -- Flags de disponibilidad
    CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END AS tiene_tributaria_cf,
    CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END AS tiene_cedible_cf,
    CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END AS tiene_tributaria_sf,
    CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END AS tiene_cedible_sf,
    CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END AS tiene_doc_termico,
    -- Validar formato de URLs
    CASE 
      WHEN Copia_Tributaria_cf LIKE 'gs://miguel-test/%' THEN 1 
      WHEN Copia_Tributaria_cf IS NULL THEN 0
      ELSE 0 
    END AS tributaria_cf_valida,
    CASE 
      WHEN Copia_Cedible_cf LIKE 'gs://miguel-test/%' THEN 1 
      WHEN Copia_Cedible_cf IS NULL THEN 0
      ELSE 0 
    END AS cedible_cf_valida
  FROM 
    `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
),

combination_patterns AS (
  SELECT
    CONCAT(
      CASE WHEN tiene_tributaria_cf = 1 THEN 'T-CF ' ELSE '' END,
      CASE WHEN tiene_cedible_cf = 1 THEN 'C-CF ' ELSE '' END,
      CASE WHEN tiene_tributaria_sf = 1 THEN 'T-SF ' ELSE '' END,
      CASE WHEN tiene_cedible_sf = 1 THEN 'C-SF ' ELSE '' END,
      CASE WHEN tiene_doc_termico = 1 THEN 'DOC-TERM' ELSE '' END
    ) AS patron_disponibilidad,
    COUNT(*) AS cantidad_facturas,
    (tiene_tributaria_cf + tiene_cedible_cf + tiene_tributaria_sf + tiene_cedible_sf + tiene_doc_termico) AS total_pdfs_disponibles
  FROM pdf_patterns
  GROUP BY patron_disponibilidad, total_pdfs_disponibles
)

-- Patrones de combinación más comunes
SELECT
  patron_disponibilidad,
  total_pdfs_disponibles,
  cantidad_facturas,
  ROUND(100.0 * cantidad_facturas / SUM(cantidad_facturas) OVER (), 2) AS porcentaje,
  RANK() OVER (ORDER BY cantidad_facturas DESC) AS ranking
FROM combination_patterns
WHERE patron_disponibilidad != ''  -- Excluir facturas sin PDFs
ORDER BY cantidad_facturas DESC
LIMIT 20

-- ============================================================================
-- Validación de URLs GCS
-- ============================================================================

-- SELECT
--   'VALIDACIÓN URLs' AS patron_disponibilidad,
--   NULL AS total_pdfs_disponibles,
--   SUM(CASE WHEN tributaria_cf_valida = 1 THEN 1 ELSE 0 END) AS cantidad_facturas,
--   ROUND(100.0 * SUM(tributaria_cf_valida) / COUNT(*), 2) AS porcentaje,
--   1 AS ranking
-- FROM pdf_patterns
-- WHERE tiene_tributaria_cf = 1

-- UNION ALL

-- SELECT
--   'URLs Cedible CF válidas' AS patron_disponibilidad,
--   NULL AS total_pdfs_disponibles,
--   SUM(CASE WHEN cedible_cf_valida = 1 THEN 1 ELSE 0 END) AS cantidad_facturas,
--   ROUND(100.0 * SUM(cedible_cf_valida) / COUNT(*), 2) AS porcentaje,
--   2 AS ranking
-- FROM pdf_patterns
-- WHERE tiene_cedible_cf = 1

-- ============================================================================
-- Validaciones esperadas:
-- ✓ Patrón más común: 'T-CF C-CF' (Tributaria + Cedible con Fondo)
-- ✓ > 80% de facturas tienen al menos T-CF y C-CF
-- ✓ Todas las URLs comienzan con 'gs://miguel-test/'
-- ✓ < 5% de facturas sin ningún PDF (patron_disponibilidad vacío)
-- ✓ Facturas con 5 PDFs (todos los tipos) representan < 10%
-- ============================================================================
