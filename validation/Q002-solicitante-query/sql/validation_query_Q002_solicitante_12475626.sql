-- Validación Q002: Facturas para solicitante 12475626
-- Query directa a BigQuery para comparación con respuesta del chatbot

SELECT 
    Factura,
    Solicitante,
    Nombre,
    fecha,
    Rut,
    Factura_Referencia,
    Copia_Tributaria_cf,
    Copia_Cedible_cf,
    Copia_Tributaria_sf,
    Copia_Cedible_sf,
    Doc_Termico
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Solicitante = '0012475626'  -- Normalizado con LPAD
ORDER BY fecha DESC;

-- Query de verificación de normalización
SELECT 
    COUNT(*) as total_facturas,
    MIN(fecha) as fecha_minima,
    MAX(fecha) as fecha_maxima
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Solicitante = '0012475626';