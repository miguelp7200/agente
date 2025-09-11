-- Consulta para validar facturas de Julio 2025
-- Usar en BigQuery console para obtener contexto real

-- 1. Verificar si existen facturas en Julio 2025
SELECT 
  'Facturas en Julio 2025' as descripcion,
  COUNT(*) as total_facturas,
  COUNT(DISTINCT Rut) as ruts_unicos,
  COUNT(DISTINCT Solicitante) as solicitantes_unicos,
  MIN(fecha) as primera_fecha,
  MAX(fecha) as ultima_fecha
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
  AND EXTRACT(MONTH FROM fecha) = 7;

-- 2. Mostrar las primeras 10 facturas de Julio 2025 para contexto
SELECT 
  Factura,
  Solicitante,
  Rut,
  Nombre,
  fecha,
  CASE 
    WHEN Copia_Tributaria_cf IS NOT NULL THEN 'Disponible'
    ELSE 'No disponible'
  END as PDF_Tributaria_CF,
  CASE 
    WHEN Copia_Cedible_cf IS NOT NULL THEN 'Disponible'
    ELSE 'No disponible'
  END as PDF_Cedible_CF
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
  AND EXTRACT(MONTH FROM fecha) = 7
ORDER BY fecha DESC, Factura DESC
LIMIT 10;

-- 3. Verificar distribución por día en Julio 2025
SELECT 
  EXTRACT(DAY FROM fecha) as dia_julio,
  COUNT(*) as facturas_del_dia,
  COUNT(DISTINCT Rut) as clientes_distintos,
  MIN(Factura) as primera_factura,
  MAX(Factura) as ultima_factura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
  AND EXTRACT(MONTH FROM fecha) = 7
GROUP BY EXTRACT(DAY FROM fecha)
ORDER BY dia_julio ASC;

-- 4. Verificar el query exacto que debería usar search_invoices_by_month_year
SELECT
  Factura,
  Solicitante,
  Rut,
  Nombre,
  fecha,
  DetallesFactura,
  CASE 
    WHEN Copia_Tributaria_cf IS NOT NULL 
    THEN CONCAT('https://invoice-backend-819133916464.us-central1.run.app/invoice/', Factura, '/tributaria_cf.pdf')
    ELSE NULL
  END as Copia_Tributaria_cf_proxy,
  CASE 
    WHEN Copia_Cedible_cf IS NOT NULL 
    THEN CONCAT('https://invoice-backend-819133916464.us-central1.run.app/invoice/', Factura, '/cedible_cf.pdf')
    ELSE NULL
  END as Copia_Cedible_cf_proxy
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025
  AND EXTRACT(MONTH FROM fecha) = 7
ORDER BY fecha DESC, Factura DESC
LIMIT 50;