-- =====================================================
-- DIAGNÓSTICO URLs FIRMADAS FALLANDO - Q001
-- =====================================================
-- Issue: Factura 0105418626 URLs failing with SignatureDoesNotMatch
-- Date: 2025-09-15
-- Bucket: miguel-test/descargas/0105418626/

-- =====================================================
-- QUERY 1: Comparar rutas de archivos entre facturas
-- =====================================================

-- Facturas que funcionan vs que fallan
SELECT 
  Factura,
  fecha,
  Nombre AS cliente,
  
  -- Rutas de archivos
  Copia_Cedible_cf,
  Copia_Cedible_sf,
  Copia_Tributaria_cf,
  Copia_Tributaria_sf,
  Doc_Termico,
  
  -- Verificar patrones de rutas
  CASE 
    WHEN Copia_Cedible_sf LIKE '%0105418626%' THEN '❌ PROBLEMÁTICA'
    WHEN Copia_Cedible_sf LIKE '%0105481293%' THEN '✅ FUNCIONANDO'
    WHEN Copia_Cedible_sf LIKE '%0105443677%' THEN '✅ FUNCIONANDO'
    ELSE '❓ REVISAR'
  END AS status_ruta_cedible_sf,
  
  CASE 
    WHEN Copia_Tributaria_cf LIKE '%0105418626%' THEN '❌ PROBLEMÁTICA'
    WHEN Copia_Tributaria_cf LIKE '%0105481293%' THEN '✅ FUNCIONANDO'
    WHEN Copia_Tributaria_cf LIKE '%0105443677%' THEN '✅ FUNCIONANDO'
    ELSE '❓ REVISAR'
  END AS status_ruta_tributaria_cf

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

WHERE 
  Solicitante = '0012537749'
  AND fecha BETWEEN '2025-08-01' AND '2025-08-31'
  AND Factura IN ('0105481293', '0105443677', '0105418626')

ORDER BY fecha DESC;

-- =====================================================
-- QUERY 2: Análisis detallado de rutas problemáticas
-- =====================================================

SELECT 
  Factura,
  fecha,
  
  -- Longitud de rutas (detectar truncamiento)
  LENGTH(Copia_Cedible_cf) AS len_cedible_cf,
  LENGTH(Copia_Cedible_sf) AS len_cedible_sf,
  LENGTH(Copia_Tributaria_cf) AS len_tributaria_cf,
  LENGTH(Copia_Tributaria_sf) AS len_tributaria_sf,
  LENGTH(Doc_Termico) AS len_doc_termico,
  
  -- Verificar NULL o vacío
  CASE WHEN Copia_Cedible_sf IS NULL OR Copia_Cedible_sf = '' THEN '❌ NULL/EMPTY' ELSE '✅ OK' END AS check_cedible_sf,
  CASE WHEN Copia_Tributaria_cf IS NULL OR Copia_Tributaria_cf = '' THEN '❌ NULL/EMPTY' ELSE '✅ OK' END AS check_tributaria_cf,
  
  -- Verificar formato de ruta
  CASE 
    WHEN Copia_Cedible_sf LIKE 'descargas/%' THEN '✅ FORMATO_OK'
    WHEN Copia_Cedible_sf LIKE '%/descargas/%' THEN '✅ FORMATO_OK'
    ELSE '❌ FORMATO_RARO'
  END AS formato_cedible_sf,
  
  CASE 
    WHEN Copia_Tributaria_cf LIKE 'descargas/%' THEN '✅ FORMATO_OK'
    WHEN Copia_Tributaria_cf LIKE '%/descargas/%' THEN '✅ FORMATO_OK'
    ELSE '❌ FORMATO_RARO'
  END AS formato_tributaria_cf,
  
  -- Rutas completas para verificación manual
  Copia_Cedible_sf AS ruta_problemática_1,
  Copia_Tributaria_cf AS ruta_problemática_2

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

WHERE Factura = '0105418626';

-- =====================================================
-- QUERY 3: Comparar estructura de directorios
-- =====================================================

-- Extraer directorios base de todas las facturas de agosto 2025
SELECT 
  Factura,
  
  -- Extraer directorio de cada tipo de archivo
  REGEXP_EXTRACT(Copia_Cedible_cf, r'descargas/([^/]+)/') AS directorio_cedible_cf,
  REGEXP_EXTRACT(Copia_Cedible_sf, r'descargas/([^/]+)/') AS directorio_cedible_sf,
  REGEXP_EXTRACT(Copia_Tributaria_cf, r'descargas/([^/]+)/') AS directorio_tributaria_cf,
  REGEXP_EXTRACT(Copia_Tributaria_sf, r'descargas/([^/]+)/') AS directorio_tributaria_sf,
  REGEXP_EXTRACT(Doc_Termico, r'descargas/([^/]+)/') AS directorio_doc_termico,
  
  -- Verificar consistencia de directorios
  CASE 
    WHEN REGEXP_EXTRACT(Copia_Cedible_cf, r'descargas/([^/]+)/') = Factura 
    THEN '✅ CONSISTENTE' 
    ELSE '❌ INCONSISTENTE' 
  END AS consistencia_directorio

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

WHERE 
  Solicitante = '0012537749'
  AND fecha BETWEEN '2025-08-01' AND '2025-08-31'

ORDER BY Factura;

-- =====================================================
-- QUERY 4: Análisis de archivos faltantes potenciales
-- =====================================================

-- Buscar facturas con campos de archivos NULL o vacíos
SELECT 
  Factura,
  fecha,
  Nombre AS cliente,
  
  -- Conteo de archivos NULL por factura
  CASE WHEN Copia_Cedible_cf IS NULL OR Copia_Cedible_cf = '' THEN 1 ELSE 0 END +
  CASE WHEN Copia_Cedible_sf IS NULL OR Copia_Cedible_sf = '' THEN 1 ELSE 0 END +
  CASE WHEN Copia_Tributaria_cf IS NULL OR Copia_Tributaria_cf = '' THEN 1 ELSE 0 END +
  CASE WHEN Copia_Tributaria_sf IS NULL OR Copia_Tributaria_sf = '' THEN 1 ELSE 0 END +
  CASE WHEN Doc_Termico IS NULL OR Doc_Termico = '' THEN 1 ELSE 0 END AS total_archivos_faltantes,
  
  -- Detalles de archivos faltantes
  CASE WHEN Copia_Cedible_cf IS NULL OR Copia_Cedible_cf = '' THEN '❌ CF' ELSE '✅ CF' END AS cedible_cf_status,
  CASE WHEN Copia_Cedible_sf IS NULL OR Copia_Cedible_sf = '' THEN '❌ SF' ELSE '✅ SF' END AS cedible_sf_status,
  CASE WHEN Copia_Tributaria_cf IS NULL OR Copia_Tributaria_cf = '' THEN '❌ CF' ELSE '✅ CF' END AS tributaria_cf_status,
  CASE WHEN Copia_Tributaria_sf IS NULL OR Copia_Tributaria_sf = '' THEN '❌ SF' ELSE '✅ SF' END AS tributaria_sf_status,
  CASE WHEN Doc_Termico IS NULL OR Doc_Termico = '' THEN '❌ TERMICO' ELSE '✅ TERMICO' END AS doc_termico_status

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

WHERE 
  Solicitante = '0012537749'
  AND fecha BETWEEN '2025-08-01' AND '2025-08-31'

ORDER BY total_archivos_faltantes DESC, fecha DESC;

-- =====================================================
-- QUERY 5: Verificar integridad general del bucket
-- =====================================================

-- Buscar patrones problemáticos en todo el dataset
SELECT 
  'TOTAL_FACTURAS_AGOSTO_2025' AS metric,
  COUNT(*) AS value
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE fecha BETWEEN '2025-08-01' AND '2025-08-31'

UNION ALL

SELECT 
  'FACTURAS_CON_CEDIBLE_SF_NULL' AS metric,
  COUNT(*) AS value
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE 
  fecha BETWEEN '2025-08-01' AND '2025-08-31'
  AND (Copia_Cedible_sf IS NULL OR Copia_Cedible_sf = '')

UNION ALL

SELECT 
  'FACTURAS_CON_TRIBUTARIA_CF_NULL' AS metric,
  COUNT(*) AS value
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE 
  fecha BETWEEN '2025-08-01' AND '2025-08-31'
  AND (Copia_Tributaria_cf IS NULL OR Copia_Tributaria_cf = '')

UNION ALL

SELECT 
  'FACTURAS_SOLICITANTE_12537749' AS metric,
  COUNT(*) AS value
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE 
  Solicitante = '0012537749'
  AND fecha BETWEEN '2025-08-01' AND '2025-08-31'

ORDER BY metric;

-- =====================================================
-- INSTRUCCIONES DE DIAGNÓSTICO
-- =====================================================

/*
PASOS PARA DIAGNOSTICAR URLs FIRMADAS FALLANDO:

1. EJECUTAR QUERY 1: Comparar rutas entre facturas funcionando vs fallando
   → Identificar diferencias en patrones de rutas

2. EJECUTAR QUERY 2: Análisis detallado de rutas problemáticas
   → Verificar si hay truncamiento, formato incorrecto, o NULL

3. EJECUTAR QUERY 3: Verificar estructura de directorios
   → Confirmar que directorio = número de factura

4. EJECUTAR QUERY 4: Buscar archivos faltantes
   → Identificar si el problema es sistemático

5. EJECUTAR QUERY 5: Integridad general
   → Obtener métricas globales del dataset

PROBLEMA DETECTADO:
- Factura 0105418626: Copia_Cedible_sf y Copia_Tributaria_cf fallan
- Error: SignatureDoesNotMatch
- Posible causa: Archivos no existen en Cloud Storage

PRÓXIMOS PASOS DESPUÉS DEL SQL:
1. Verificar existencia de archivos en bucket miguel-test
2. Comprobar permisos de service account
3. Revisar logs de generación de signed URLs
4. Comparar timestamps de creación de archivos
*/