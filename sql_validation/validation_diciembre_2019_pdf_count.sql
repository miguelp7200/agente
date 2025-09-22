-- ===== VALIDACIÓN DICIEMBRE 2019: CONTEO DE PDFs ESPERADOS =====
-- Query para validar cuántos PDFs deberían devolverse para "Busca facturas de diciembre 2019"
-- Basado en el test ejecutado: 4 facturas encontradas

-- 1. CONTEO BÁSICO DE FACTURAS DICIEMBRE 2019
SELECT 
    'FACTURAS_DICIEMBRE_2019' as metric_type,
    COUNT(*) as total_facturas,
    MIN(fecha) as fecha_primera,
    MAX(fecha) as fecha_ultima
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2019 
  AND EXTRACT(MONTH FROM fecha) = 12;

-- 2. ANÁLISIS DETALLADO DE PDFs POR FACTURA (DICIEMBRE 2019)
SELECT 
    'PDF_ANALYSIS_DIC_2019' as metric_type,
    Factura,
    fecha,
    Nombre,
    Rut,
    -- Conteo de PDFs disponibles por factura
    (CASE WHEN Copia_Tributaria_cf IS NOT NULL AND Copia_Tributaria_cf != '' THEN 1 ELSE 0 END) +
    (CASE WHEN Copia_Cedible_cf IS NOT NULL AND Copia_Cedible_cf != '' THEN 1 ELSE 0 END) +
    (CASE WHEN Copia_Tributaria_sf IS NOT NULL AND Copia_Tributaria_sf != '' THEN 1 ELSE 0 END) +
    (CASE WHEN Copia_Cedible_sf IS NOT NULL AND Copia_Cedible_sf != '' THEN 1 ELSE 0 END) +
    (CASE WHEN Doc_Termico IS NOT NULL AND Doc_Termico != '' THEN 1 ELSE 0 END) as total_pdfs_por_factura,
    
    -- Detalle de qué PDFs están disponibles
    CASE WHEN Copia_Tributaria_cf IS NOT NULL AND Copia_Tributaria_cf != '' THEN 'CT_CF, ' ELSE '' END ||
    CASE WHEN Copia_Cedible_cf IS NOT NULL AND Copia_Cedible_cf != '' THEN 'CC_CF, ' ELSE '' END ||
    CASE WHEN Copia_Tributaria_sf IS NOT NULL AND Copia_Tributaria_sf != '' THEN 'CT_SF, ' ELSE '' END ||
    CASE WHEN Copia_Cedible_sf IS NOT NULL AND Copia_Cedible_sf != '' THEN 'CC_SF, ' ELSE '' END ||
    CASE WHEN Doc_Termico IS NOT NULL AND Doc_Termico != '' THEN 'DOC_TERMICO' ELSE '' END as tipos_pdfs_disponibles
    
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2019 
  AND EXTRACT(MONTH FROM fecha) = 12
ORDER BY fecha DESC;

-- 3. RESUMEN ESTADÍSTICO DE PDFs DICIEMBRE 2019
SELECT 
    'ESTADISTICAS_PDFs_DIC_2019' as metric_type,
    COUNT(*) as total_facturas,
    SUM(
        (CASE WHEN Copia_Tributaria_cf IS NOT NULL AND Copia_Tributaria_cf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Cedible_cf IS NOT NULL AND Copia_Cedible_cf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Tributaria_sf IS NOT NULL AND Copia_Tributaria_sf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Cedible_sf IS NOT NULL AND Copia_Cedible_sf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Doc_Termico IS NOT NULL AND Doc_Termico != '' THEN 1 ELSE 0 END)
    ) as total_pdfs_disponibles,
    
    -- Promedio de PDFs por factura
    ROUND(
        SUM(
            (CASE WHEN Copia_Tributaria_cf IS NOT NULL AND Copia_Tributaria_cf != '' THEN 1 ELSE 0 END) +
            (CASE WHEN Copia_Cedible_cf IS NOT NULL AND Copia_Cedible_cf != '' THEN 1 ELSE 0 END) +
            (CASE WHEN Copia_Tributaria_sf IS NOT NULL AND Copia_Tributaria_sf != '' THEN 1 ELSE 0 END) +
            (CASE WHEN Copia_Cedible_sf IS NOT NULL AND Copia_Cedible_sf != '' THEN 1 ELSE 0 END) +
            (CASE WHEN Doc_Termico IS NOT NULL AND Doc_Termico != '' THEN 1 ELSE 0 END)
        ) / COUNT(*), 2
    ) as promedio_pdfs_por_factura,
    
    -- Facturas con 5 PDFs completos
    COUNTIF(
        (CASE WHEN Copia_Tributaria_cf IS NOT NULL AND Copia_Tributaria_cf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Cedible_cf IS NOT NULL AND Copia_Cedible_cf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Tributaria_sf IS NOT NULL AND Copia_Tributaria_sf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Cedible_sf IS NOT NULL AND Copia_Cedible_sf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Doc_Termico IS NOT NULL AND Doc_Termico != '' THEN 1 ELSE 0 END) = 5
    ) as facturas_con_5_pdfs,
    
    -- Porcentaje con PDFs completos
    ROUND(
        COUNTIF(
            (CASE WHEN Copia_Tributaria_cf IS NOT NULL AND Copia_Tributaria_cf != '' THEN 1 ELSE 0 END) +
            (CASE WHEN Copia_Cedible_cf IS NOT NULL AND Copia_Cedible_cf != '' THEN 1 ELSE 0 END) +
            (CASE WHEN Copia_Tributaria_sf IS NOT NULL AND Copia_Tributaria_sf != '' THEN 1 ELSE 0 END) +
            (CASE WHEN Copia_Cedible_sf IS NOT NULL AND Copia_Cedible_sf != '' THEN 1 ELSE 0 END) +
            (CASE WHEN Doc_Termico IS NOT NULL AND Doc_Termico != '' THEN 1 ELSE 0 END) = 5
        ) * 100.0 / COUNT(*), 2
    ) as porcentaje_con_5_pdfs

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2019 
  AND EXTRACT(MONTH FROM fecha) = 12;

-- 4. VALIDACIÓN ESPECÍFICA DE LAS 4 FACTURAS DEL TEST
SELECT 
    'VALIDACION_4_FACTURAS_TEST' as metric_type,
    Factura,
    fecha,
    Nombre,
    -- Conteo específico para las 4 facturas del test
    (CASE WHEN Copia_Tributaria_cf IS NOT NULL AND Copia_Tributaria_cf != '' THEN 1 ELSE 0 END) +
    (CASE WHEN Copia_Cedible_cf IS NOT NULL AND Copia_Cedible_cf != '' THEN 1 ELSE 0 END) +
    (CASE WHEN Copia_Tributaria_sf IS NOT NULL AND Copia_Tributaria_sf != '' THEN 1 ELSE 0 END) +
    (CASE WHEN Copia_Cedible_sf IS NOT NULL AND Copia_Cedible_sf != '' THEN 1 ELSE 0 END) +
    (CASE WHEN Doc_Termico IS NOT NULL AND Doc_Termico != '' THEN 1 ELSE 0 END) as pdfs_disponibles
    
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Factura IN ('0101531734', '0101552280', '0101514836', '0101507588')
ORDER BY fecha DESC;

-- 5. CÁLCULO FINAL ESPERADO PARA EL ZIP
SELECT 
    'CALCULO_ZIP_ESPERADO' as metric_type,
    COUNT(*) as facturas_en_zip,
    SUM(
        (CASE WHEN Copia_Tributaria_cf IS NOT NULL AND Copia_Tributaria_cf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Cedible_cf IS NOT NULL AND Copia_Cedible_cf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Tributaria_sf IS NOT NULL AND Copia_Tributaria_sf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Copia_Cedible_sf IS NOT NULL AND Copia_Cedible_sf != '' THEN 1 ELSE 0 END) +
        (CASE WHEN Doc_Termico IS NOT NULL AND Doc_Termico != '' THEN 1 ELSE 0 END)
    ) as total_pdfs_en_zip
    
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Factura IN ('0101531734', '0101552280', '0101514836', '0101507588');

-- INTERPRETACIÓN DE RESULTADOS:
-- Si el test encontró 4 facturas y según las estadísticas del debugging context:
-- - 86.72% tienen 5 PDFs → ~3-4 facturas tendrán 5 PDFs cada una
-- - Expected total: 4 facturas × ~4.8 PDFs promedio = ~19-20 PDFs en el ZIP
-- 
-- Para validar: El ZIP generado debería contener entre 16-20 PDFs
-- Si contiene exactamente 20 PDFs (4×5), todas las facturas tienen PDFs completos
-- Si contiene menos, algunas facturas tienen PDFs faltantes (normal ~13.28% según stats)