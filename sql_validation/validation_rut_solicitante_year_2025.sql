-- Validación: Cuántas facturas existen para RUT 76262399-4, solicitante 12527236, año 2025
-- Propósito: Verificar la discrepancia entre 58 (obtenido) vs 131 (esperado)
-- Fecha: 2025-10-09

SELECT 
  COUNT(*) as total_facturas,
  MIN(fecha) as fecha_minima,
  MAX(fecha) as fecha_maxima,
  COUNT(DISTINCT Factura) as facturas_unicas,
  COUNT(DISTINCT EXTRACT(MONTH FROM fecha)) as meses_con_facturas
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '76262399-4'
  AND Solicitante = LPAD('12527236', 10, '0')  -- Normalizado: 0012527236
  AND EXTRACT(YEAR FROM fecha) = 2025;

-- Query adicional: Ver distribución mensual
SELECT 
  EXTRACT(MONTH FROM fecha) as mes,
  COUNT(*) as facturas_por_mes,
  COUNT(DISTINCT Factura) as facturas_unicas_mes
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '76262399-4'
  AND Solicitante = LPAD('12527236', 10, '0')
  AND EXTRACT(YEAR FROM fecha) = 2025
GROUP BY mes
ORDER BY mes;

-- Query adicional: Verificar si hay facturas con fecha futura
SELECT 
  COUNT(*) as facturas_futuras,
  MIN(fecha) as fecha_minima_futura,
  MAX(fecha) as fecha_maxima_futura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '76262399-4'
  AND Solicitante = LPAD('12527236', 10, '0')
  AND EXTRACT(YEAR FROM fecha) = 2025
  AND fecha > CURRENT_DATE();
