-- ============================================
-- ANÁLISIS COMPLETO DE PDFs - JULIO 2025
-- Consultas para evaluar disponibilidad real de documentos
-- ============================================

-- 1. CONTEO TOTAL DE PDFs DISPONIBLES POR TIPO (Julio 2025)
SELECT 
  'PDFs disponibles por tipo - Julio 2025' as descripcion,
  COUNT(*) as total_facturas,
  
  -- Conteo por tipo de PDF
  SUM(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END) as cedible_cf_count,
  SUM(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END) as cedible_sf_count,
  SUM(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END) as tributaria_cf_count,
  SUM(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END) as tributaria_sf_count,
  SUM(CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as doc_termico_count,
  
  -- Total de PDFs individuales
  (SUM(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END)) as total_pdfs_disponibles
   
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
  AND EXTRACT(MONTH FROM fecha) = 7;

-- 2. ANÁLISIS DETALLADO: FACTURAS CON MÚLTIPLES PDFs (Top 10)
SELECT 
  Factura,
  Solicitante,
  Rut,
  Nombre,
  fecha,
  
  -- Indicadores de disponibilidad
  CASE WHEN Copia_Cedible_cf IS NOT NULL THEN '✅' ELSE '❌' END as tiene_cedible_cf,
  CASE WHEN Copia_Cedible_sf IS NOT NULL THEN '✅' ELSE '❌' END as tiene_cedible_sf,
  CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN '✅' ELSE '❌' END as tiene_tributaria_cf,
  CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN '✅' ELSE '❌' END as tiene_tributaria_sf,
  CASE WHEN Doc_Termico IS NOT NULL THEN '✅' ELSE '❌' END as tiene_doc_termico,
  
  -- Conteo de PDFs por factura
  (CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as pdfs_por_factura
   
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
  AND EXTRACT(MONTH FROM fecha) = 7
ORDER BY pdfs_por_factura DESC, fecha DESC
LIMIT 10;

-- 3. DISTRIBUCIÓN DE PDFs POR FACTURA (Estadísticas)
WITH pdf_counts AS (
  SELECT 
    Factura,
    (CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as pdfs_count
  FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  WHERE EXTRACT(YEAR FROM fecha) = 2025 
    AND EXTRACT(MONTH FROM fecha) = 7
)
SELECT 
  'Distribución PDFs por factura - Julio 2025' as descripcion,
  pdfs_count as pdfs_por_factura,
  COUNT(*) as cantidad_facturas,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pdf_counts), 2) as porcentaje
FROM pdf_counts
GROUP BY pdfs_count
ORDER BY pdfs_count;

-- 4. COMPARACIÓN: FACTURAS TOTALES vs LÍMITE ANTERIOR (50)
SELECT 
  'Impacto del aumento de límites' as analisis,
  
  -- Con límite anterior de 50
  50 as limite_anterior,
  LEAST(COUNT(*), 50) as facturas_con_limite_50,
  LEAST(COUNT(*), 50) * 8.1 as pdfs_estimados_limite_50,
  
  -- Sin límite (actual)
  COUNT(*) as facturas_sin_limite,
  (SUM(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END)) as pdfs_reales_sin_limite,
   
  -- Incremento
  ROUND(
    ((SUM(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END) +
      SUM(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END) +
      SUM(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END) +
      SUM(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END) +
      SUM(CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END)) - (LEAST(COUNT(*), 50) * 8.1)) 
    / (LEAST(COUNT(*), 50) * 8.1) * 100, 2
  ) as incremento_porcentual
  
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
  AND EXTRACT(MONTH FROM fecha) = 7;

-- 5. VERIFICACIÓN: ¿Por qué solo 60 facturas si hay 2,864?
SELECT 
  'Análisis de discrepancia' as investigacion,
  COUNT(*) as total_facturas_julio_2025,
  COUNT(CASE WHEN fecha = '2025-07-31' THEN 1 END) as facturas_31_julio,
  ROUND(COUNT(CASE WHEN fecha = '2025-07-31' THEN 1 END) * 100.0 / COUNT(*), 2) as porcentaje_31_julio,
  
  -- Distribución por días
  COUNT(DISTINCT fecha) as dias_con_facturas,
  MIN(fecha) as primera_fecha,
  MAX(fecha) as ultima_fecha
  
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
  AND EXTRACT(MONTH FROM fecha) = 7;

-- 6. TOP 5 DÍAS CON MÁS FACTURAS EN JULIO 2025
SELECT 
  fecha,
  COUNT(*) as facturas_del_dia,
  COUNT(DISTINCT Rut) as ruts_unicos,
  
  -- PDFs del día
  (SUM(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END) +
   SUM(CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END)) as pdfs_del_dia
   
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
  AND EXTRACT(MONTH FROM fecha) = 7
GROUP BY fecha
ORDER BY facturas_del_dia DESC
LIMIT 5;