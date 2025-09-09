-- CONSULTA SIMPLE PARA BIGQUERY: Verificar "Gas Las Naciones"

-- 1. Ver todos los nombres únicos que contengan "GAS"
SELECT DISTINCT
  Nombre,
  COUNT(*) as total_facturas
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE UPPER(Nombre) LIKE '%GAS%'
GROUP BY Nombre
ORDER BY total_facturas DESC;

-- 2. Verificar específicamente "GAS LAS NACIONES" (case-insensitive)
SELECT 
  COUNT(*) as total_facturas,
  MIN(fecha) as fecha_mas_antigua,
  MAX(fecha) as fecha_mas_reciente
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE UPPER(Nombre) = 'GAS LAS NACIONES';

-- 3. Buscar variaciones aproximadas
SELECT DISTINCT
  Nombre,
  Solicitante,
  COUNT(*) as facturas
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE 
  UPPER(Nombre) LIKE '%GAS%NACION%' 
  OR UPPER(Solicitante) LIKE '%GAS%NACION%'
GROUP BY Nombre, Solicitante
ORDER BY facturas DESC;