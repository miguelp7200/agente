-- 📊 ANÁLISIS DE IMPACTO DE LÍMITES - BASE DE DATOS FACTURAS
-- Consultas SQL para evaluar cantidad real de facturas vs límites configurados
-- Dataset: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
-- Fecha: 2025-09-10
-- Propósito: Medir impacto de aumentar límites de 50 a 1000+ facturas

-- ==============================================================================
-- 1. ESTADÍSTICAS GENERALES DEL DATASET
-- ==============================================================================

-- Conteo total de registros
SELECT 
    COUNT(*) as total_facturas,
    COUNT(DISTINCT Factura) as facturas_unicas,
    COUNT(DISTINCT Rut) as ruts_unicos,
    COUNT(DISTINCT Solicitante) as solicitantes_unicos,
    COUNT(DISTINCT Nombre) as clientes_unicos,
    MIN(fecha) as fecha_mas_antigua,
    MAX(fecha) as fecha_mas_reciente
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`;

-- ==============================================================================
-- 2. ANÁLISIS TEMPORAL - FACTURAS POR AÑO Y MES
-- ==============================================================================

-- Facturas por año (para evaluar search_invoices_by_year)
SELECT 
    EXTRACT(YEAR FROM fecha) as year,
    COUNT(*) as total_facturas,
    COUNT(DISTINCT Rut) as ruts_distintos,
    COUNT(DISTINCT Solicitante) as solicitantes_distintos
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
GROUP BY EXTRACT(YEAR FROM fecha)
ORDER BY year DESC;

-- Facturas por mes en 2025 (año actual - evaluar search_invoices_by_month_year)
SELECT 
    EXTRACT(MONTH FROM fecha) as month,
    CASE EXTRACT(MONTH FROM fecha)
        WHEN 1 THEN 'Enero'
        WHEN 2 THEN 'Febrero'  
        WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Mayo'
        WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'
    END as mes_nombre,
    COUNT(*) as total_facturas,
    COUNT(DISTINCT Rut) as ruts_distintos
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025
GROUP BY EXTRACT(MONTH FROM fecha)
ORDER BY month;

-- CASO ESPECÍFICO: Julio 2025 (nuestro test case)
SELECT 
    DATE(fecha) as fecha_especifica,
    COUNT(*) as facturas_por_dia,
    COUNT(DISTINCT Rut) as ruts_por_dia,
    COUNT(DISTINCT Solicitante) as solicitantes_por_dia
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = 2025 
    AND EXTRACT(MONTH FROM fecha) = 7
GROUP BY DATE(fecha)
ORDER BY fecha_especifica;

-- ==============================================================================
-- 3. ANÁLISIS POR RUT - EVALUAR search_invoices_by_rut
-- ==============================================================================

-- Top 20 RUTs con más facturas (evaluar límite anterior de 20)
SELECT 
    Rut,
    Nombre,
    COUNT(*) as total_facturas,
    MIN(fecha) as primera_factura,
    MAX(fecha) as ultima_factura,
    COUNT(DISTINCT Solicitante) as solicitantes_distintos
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
GROUP BY Rut, Nombre
ORDER BY total_facturas DESC
LIMIT 20;

-- RUTs que exceden el límite anterior de 20 facturas
SELECT 
    'RUTs con >20 facturas' as categoria,
    COUNT(*) as cantidad_ruts,
    SUM(total_facturas) as facturas_afectadas,
    AVG(total_facturas) as promedio_facturas_por_rut,
    MAX(total_facturas) as max_facturas_un_rut
FROM (
    SELECT 
        Rut,
        COUNT(*) as total_facturas
    FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
    GROUP BY Rut
    HAVING COUNT(*) > 20
);

-- ==============================================================================
-- 4. ANÁLISIS POR SOLICITANTE - EVALUAR search_invoices_by_proveedor  
-- ==============================================================================

-- Top 20 Solicitantes con más facturas
SELECT 
    Solicitante,
    COUNT(*) as total_facturas,
    COUNT(DISTINCT Rut) as clientes_distintos,
    COUNT(DISTINCT Nombre) as nombres_distintos,
    MIN(fecha) as primera_factura,
    MAX(fecha) as ultima_factura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
GROUP BY Solicitante
ORDER BY total_facturas DESC
LIMIT 20;

-- Solicitantes que exceden límite anterior de 20 facturas
SELECT 
    'Solicitantes con >20 facturas' as categoria,
    COUNT(*) as cantidad_solicitantes,
    SUM(total_facturas) as facturas_afectadas,
    AVG(total_facturas) as promedio_facturas_por_solicitante
FROM (
    SELECT 
        Solicitante,
        COUNT(*) as total_facturas
    FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
    GROUP BY Solicitante
    HAVING COUNT(*) > 20
);

-- ==============================================================================
-- 5. ANÁLISIS DE BÚSQUEDAS COMBINADAS
-- ==============================================================================

-- Empresas por mes que exceden límite de 30 (search_invoices_by_company_name_and_date)
SELECT 
    EXTRACT(YEAR FROM fecha) as year,
    EXTRACT(MONTH FROM fecha) as month,
    Nombre as empresa,
    COUNT(*) as total_facturas
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) >= 2024  -- Solo años recientes
GROUP BY EXTRACT(YEAR FROM fecha), EXTRACT(MONTH FROM fecha), Nombre
HAVING COUNT(*) > 30
ORDER BY total_facturas DESC, year DESC, month DESC
LIMIT 50;

-- Rangos de fechas que exceden límite de 50 facturas
SELECT 
    'Días con >50 facturas' as categoria,
    COUNT(*) as dias_afectados,
    SUM(facturas_por_dia) as total_facturas_afectadas,
    AVG(facturas_por_dia) as promedio_facturas_por_dia,
    MAX(facturas_por_dia) as max_facturas_un_dia
FROM (
    SELECT 
        DATE(fecha) as fecha_dia,
        COUNT(*) as facturas_por_dia
    FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
    GROUP BY DATE(fecha)
    HAVING COUNT(*) > 50
);

-- ==============================================================================
-- 6. ANÁLISIS DE DISPONIBILIDAD DE PDFs
-- ==============================================================================

-- Conteo de PDFs disponibles por tipo
SELECT 
    'Copia_Tributaria_cf' as tipo_pdf,
    COUNT(*) as pdfs_disponibles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`), 2) as porcentaje_cobertura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Copia_Tributaria_cf IS NOT NULL

UNION ALL

SELECT 
    'Copia_Cedible_cf' as tipo_pdf,
    COUNT(*) as pdfs_disponibles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`), 2) as porcentaje_cobertura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Copia_Cedible_cf IS NOT NULL

UNION ALL

SELECT 
    'Copia_Tributaria_sf' as tipo_pdf,
    COUNT(*) as pdfs_disponibles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`), 2) as porcentaje_cobertura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Copia_Tributaria_sf IS NOT NULL

UNION ALL

SELECT 
    'Copia_Cedible_sf' as tipo_pdf,
    COUNT(*) as pdfs_disponibles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`), 2) as porcentaje_cobertura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Copia_Cedible_sf IS NOT NULL

UNION ALL

SELECT 
    'Doc_Termico' as tipo_pdf,
    COUNT(*) as pdfs_disponibles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`), 2) as porcentaje_cobertura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Doc_Termico IS NOT NULL

ORDER BY pdfs_disponibles DESC;

-- ==============================================================================
-- 7. IMPACTO ESPECÍFICO DE LÍMITES AUMENTADOS
-- ==============================================================================

-- Simulación de consulta Julio 2025 con límite anterior vs nuevo
SELECT 
    'Julio 2025 - Límite Anterior (50)' as escenario,
    50 as limite_aplicado,
    (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo` 
     WHERE EXTRACT(YEAR FROM fecha) = 2025 AND EXTRACT(MONTH FROM fecha) = 7) as facturas_totales,
    CASE 
        WHEN (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo` 
              WHERE EXTRACT(YEAR FROM fecha) = 2025 AND EXTRACT(MONTH FROM fecha) = 7) > 50 
        THEN 'LIMITADO - Usuario no ve todas las facturas'
        ELSE 'OK - Usuario ve todas las facturas'
    END as status

UNION ALL

SELECT 
    'Julio 2025 - Límite Nuevo (1000)' as escenario,
    1000 as limite_aplicado,
    (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo` 
     WHERE EXTRACT(YEAR FROM fecha) = 2025 AND EXTRACT(MONTH FROM fecha) = 7) as facturas_totales,
    CASE 
        WHEN (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo` 
              WHERE EXTRACT(YEAR FROM fecha) = 2025 AND EXTRACT(MONTH FROM fecha) = 7) > 1000 
        THEN 'LIMITADO - Usuario no ve todas las facturas'
        ELSE 'OK - Usuario ve todas las facturas'
    END as status;

-- ==============================================================================
-- 8. CONSULTAS DE PERFORMANCE - ESTIMAR TIEMPO DE RESPUESTA
-- ==============================================================================

-- Facturas con todos los PDFs disponibles (consultas más pesadas)
SELECT 
    COUNT(*) as facturas_con_todos_pdfs,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`), 2) as porcentaje_dataset
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Copia_Tributaria_cf IS NOT NULL 
    AND Copia_Cedible_cf IS NOT NULL
    AND Copia_Tributaria_sf IS NOT NULL 
    AND Copia_Cedible_sf IS NOT NULL
    AND Doc_Termico IS NOT NULL;

-- Promedio de PDFs por factura (para estimar carga de descarga)
SELECT 
    AVG(pdfs_count) as promedio_pdfs_por_factura,
    MIN(pdfs_count) as min_pdfs,
    MAX(pdfs_count) as max_pdfs,
    COUNT(*) as total_facturas
FROM (
    SELECT 
        Factura,
        (CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as pdfs_count
    FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
);

-- ==============================================================================
-- 9. CASOS EXTREMOS - IDENTIFICAR CONSULTAS QUE PODRÍAN CAUSAR PROBLEMAS
-- ==============================================================================

-- RUT con mayor número de facturas (caso extremo para search_invoices_by_rut)
SELECT 
    'RUT con más facturas' as caso,
    Rut,
    Nombre,
    COUNT(*) as total_facturas,
    'Podría generar ZIP muy grande' as impacto_potencial
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
GROUP BY Rut, Nombre
ORDER BY total_facturas DESC
LIMIT 1;

-- Mes con mayor número de facturas (caso extremo para search_invoices_by_month_year)
SELECT 
    'Mes con más facturas' as caso,
    EXTRACT(YEAR FROM fecha) as year,
    EXTRACT(MONTH FROM fecha) as month,
    COUNT(*) as total_facturas,
    'Podría requerir mucho tiempo de procesamiento' as impacto_potencial
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
GROUP BY EXTRACT(YEAR FROM fecha), EXTRACT(MONTH FROM fecha)
ORDER BY total_facturas DESC
LIMIT 1;

-- ==============================================================================
-- NOTAS PARA ANÁLISIS:
-- ==============================================================================
/*
1. Ejecutar estas consultas en BigQuery console o herramienta SQL
2. Comparar resultados con límites anteriores (10, 20, 30, 50)
3. Identificar casos donde los límites anteriores ocultaban facturas
4. Evaluar impacto en performance y generación de ZIPs
5. Documentar hallazgos en debugging context
6. Considerar límites dinámicos basados en tipo de consulta

LÍMITES ANTERIORES vs NUEVOS:
- search_invoices: 10 → 200
- search_invoices_by_rut: 20 → 500  
- search_invoices_by_company_name_and_date: 30 → 1000
- search_invoices_by_month_year: 50 → 1000
- search_invoices_by_date_range: 50 → 1000

OBJETIVO: Determinar si los nuevos límites son apropiados o necesitan ajuste.
*/