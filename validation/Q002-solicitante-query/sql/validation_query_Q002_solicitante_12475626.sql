/* Query SQL para validar solicitante 12475626 en BigQuery */
SELECT 
  Factura,
  Solicitante,
  Nombre,
  Rut,
  fecha,
  Copia_Tributaria_cf,
  Copia_Cedible_cf,
  Copia_Tributaria_sf,
  Copia_Cedible_sf,
  Doc_Termico
FROM datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
WHERE Solicitante = '0012475626'
ORDER BY fecha DESC
LIMIT 20;
