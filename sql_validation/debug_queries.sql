-- ==============================================
-- CONSULTAS SQL PARA DEBUGGEAR EL PROBLEMA DE TRUNCAMIENTO DE URLs
-- Corregidas según esquema real de la tabla pdfs_modelo
-- ==============================================

-- 1. CONSULTA PRINCIPAL: Verificar los 5 PDFs de la factura problemática
SELECT 
  Factura as numero_factura,
  Solicitante,
  Nombre as cliente_nombre,
  Rut as cliente_rut,
  fecha as fecha_factura,
  
  -- Contar PDFs disponibles (no NULL)
  (CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as total_pdfs,
  
  -- URLs individuales (primeros 200 chars para visualización)
  SUBSTR(Copia_Tributaria_cf, 1, 200) as tributaria_cf_preview,
  SUBSTR(Copia_Cedible_cf, 1, 200) as cedible_cf_preview, 
  SUBSTR(Copia_Tributaria_sf, 1, 200) as tributaria_sf_preview,
  SUBSTR(Copia_Cedible_sf, 1, 200) as cedible_sf_preview,
  SUBSTR(Doc_Termico, 1, 200) as doc_termico_preview,
  
  -- Validar que el Doc_Termico (que falla) existe
  CASE 
    WHEN Doc_Termico IS NOT NULL THEN 'SÍ EXISTE' 
    ELSE 'NO EXISTE' 
  END as doc_termico_status,
  
  -- Verificar longitud de URLs (para detectar truncamiento)
  LENGTH(Copia_Tributaria_cf) as len_tributaria_cf,
  LENGTH(Copia_Cedible_cf) as len_cedible_cf,
  LENGTH(Copia_Tributaria_sf) as len_tributaria_sf, 
  LENGTH(Copia_Cedible_sf) as len_cedible_sf,
  LENGTH(Doc_Termico) as len_doc_termico,
  
  -- Calcular valor total de la factura (suma de DetallesFactura)
  (SELECT SUM(detalle.ValorTotal) 
   FROM UNNEST(DetallesFactura) as detalle) as valor_total_factura

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Factura = '0105505395'
  AND Solicitante = '0012141289';

-- ==============================================
-- 2. ANÁLISIS GENERAL: Distribución de PDFs por factura para el solicitante
-- ==============================================

WITH pdf_counts AS (
  SELECT 
    Factura,
    fecha,
    -- Contar PDFs por factura
    (CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as total_pdfs_por_factura
  FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  WHERE Solicitante = '0012141289'
    AND EXTRACT(YEAR FROM fecha) = 2025
    AND EXTRACT(MONTH FROM fecha) = 9
)

SELECT 
  total_pdfs_por_factura,
  COUNT(*) as cantidad_facturas,
  
  -- Clasificar según ZIP_THRESHOLD=3
  CASE 
    WHEN total_pdfs_por_factura > 3 
    THEN 'DEBERÍA USAR ZIP'
    ELSE 'DEBERÍA USAR URLs INDIVIDUALES'
  END as recomendacion_sistema,
  
  -- Mostrar algunas facturas como ejemplo
  STRING_AGG(Factura, ', ' LIMIT 5) as facturas_ejemplo,
  
  -- Fechas para contexto
  MIN(fecha) as fecha_min,
  MAX(fecha) as fecha_max

FROM pdf_counts
GROUP BY total_pdfs_por_factura
ORDER BY total_pdfs_por_factura DESC;

-- ==============================================
-- 3. VERIFICACIÓN DE CAMPOS NULL Y DETALLES DE FACTURA
-- ==============================================

SELECT 
  Factura,
  fecha,
  
  -- Verificar nulls específicos en PDFs
  CASE WHEN Copia_Tributaria_cf IS NULL THEN 'NULL' ELSE 'OK' END as tributaria_cf_status,
  CASE WHEN Copia_Cedible_cf IS NULL THEN 'NULL' ELSE 'OK' END as cedible_cf_status,
  CASE WHEN Copia_Tributaria_sf IS NULL THEN 'NULL' ELSE 'OK' END as tributaria_sf_status,
  CASE WHEN Copia_Cedible_sf IS NULL THEN 'NULL' ELSE 'OK' END as cedible_sf_status,
  CASE WHEN Doc_Termico IS NULL THEN 'NULL' ELSE 'OK' END as doc_termico_status,
  
  -- URLs reales (primeros 100 caracteres para verificar formato)
  SUBSTR(Copia_Tributaria_cf, 1, 100) as tributaria_cf_preview,
  SUBSTR(Doc_Termico, 1, 100) as doc_termico_preview,
  
  -- Información de detalles de factura
  ARRAY_LENGTH(DetallesFactura) as cantidad_lineas_detalle,
  (SELECT SUM(detalle.ValorTotal) FROM UNNEST(DetallesFactura) as detalle) as valor_total_calculado

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Factura = '0105505395'
  AND Solicitante = '0012141289';

-- ==============================================
-- 4. ANÁLISIS DE LONGITUD DE URLs (PROBLEMA DE TRUNCAMIENTO)
-- ==============================================

SELECT 
  Factura,
  'Copia_Tributaria_cf' as tipo_documento,
  Copia_Tributaria_cf as url_completa,
  LENGTH(Copia_Tributaria_cf) as longitud_chars,
  CASE 
    WHEN LENGTH(Copia_Tributaria_cf) > 2000 THEN '⚠️ ANORMALMENTE LARGA'
    WHEN LENGTH(Copia_Tributaria_cf) > 1000 THEN '🟡 LARGA'
    ELSE '✅ NORMAL'
  END as clasificacion_longitud

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Factura = '0105505395' AND Copia_Tributaria_cf IS NOT NULL

UNION ALL

SELECT 
  Factura,
  'Doc_Termico' as tipo_documento,
  Doc_Termico as url_completa,
  LENGTH(Doc_Termico) as longitud_chars,
  CASE 
    WHEN LENGTH(Doc_Termico) > 2000 THEN '⚠️ ANORMALMENTE LARGA'
    WHEN LENGTH(Doc_Termico) > 1000 THEN '🟡 LARGA'
    ELSE '✅ NORMAL'
  END as clasificacion_longitud

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Factura = '0105505395' AND Doc_Termico IS NOT NULL

ORDER BY tipo_documento;

-- ==============================================
-- 5. VERIFICAR SI EL ARCHIVO REALMENTE EXISTE EN GCS
-- ==============================================

-- Esta consulta muestra las URLs exactas tal como están almacenadas
SELECT 
  Factura,
  'Doc_Termico' as documento_problematico,
  Doc_Termico as url_storage_original,
  
  -- Extraer solo el path del archivo
  REGEXP_EXTRACT(Doc_Termico, r'gs://[^/]+/(.+)') as archivo_path_gcs,
  
  -- Verificar formato de la URL
  CASE 
    WHEN Doc_Termico LIKE 'gs://miguel-test/%' THEN '✅ FORMATO CORRECTO'
    ELSE '❌ FORMATO INCORRECTO'
  END as validacion_formato

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Factura = '0105505395'
  AND Doc_Termico IS NOT NULL;