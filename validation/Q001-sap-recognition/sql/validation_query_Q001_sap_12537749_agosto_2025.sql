-- =====================================================
-- Q001 VALIDACIÓN: SAP Código Solicitante Agosto 2025
-- =====================================================
-- Query: "dame la factura del siguiente sap, para agosto 2025 - 12537749"
-- Expected: Factura 0105481293, CENTRAL GAS SPA, $568,805 CLP
-- Date: 2025-09-15
-- Validation Status: ✅ PASSED (chatbot test successful)

-- =====================================================
-- QUERY PRINCIPAL - Validación exacta Q001
-- =====================================================

SELECT 
  -- Campos principales de identificación
  Factura,
  Solicitante,
  Rut,
  Nombre AS cliente_nombre,
  fecha,
  
  -- Cálculo del valor total de la factura
  (
    SELECT SUM(CAST(detalle.ValorTotal AS NUMERIC))
    FROM UNNEST(DetallesFactura) AS detalle
  ) AS valor_total_factura,
  
  -- Información de moneda (tomamos la primera)
  (
    SELECT detalle.Moneda
    FROM UNNEST(DetallesFactura) AS detalle
    LIMIT 1
  ) AS moneda,
  
  -- Verificación de PDFs disponibles
  CASE WHEN Copia_Cedible_cf IS NOT NULL THEN '✅' ELSE '❌' END AS tiene_cedible_cf,
  CASE WHEN Copia_Cedible_sf IS NOT NULL THEN '✅' ELSE '❌' END AS tiene_cedible_sf,
  CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN '✅' ELSE '❌' END AS tiene_tributaria_cf,
  CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN '✅' ELSE '❌' END AS tiene_tributaria_sf,
  CASE WHEN Doc_Termico IS NOT NULL THEN '✅' ELSE '❌' END AS tiene_doc_termico,
  
  -- Rutas de archivos para verificación
  Copia_Cedible_cf,
  Copia_Cedible_sf,
  Copia_Tributaria_cf,
  Copia_Tributaria_sf,
  Doc_Termico

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

WHERE 
  -- Filtro por solicitante normalizado (LPAD aplicado)
  Solicitante = '0012537749'
  
  -- Filtro por período: Agosto 2025
  AND fecha BETWEEN '2025-08-01' AND '2025-08-31'

ORDER BY fecha DESC;

-- =====================================================
-- QUERY AUXILIAR - Verificación normalización SAP
-- =====================================================

-- Verificar si existen registros con código sin normalizar
SELECT 
  COUNT(*) as registros_sin_normalizar,
  'Verificar si existen códigos 12537749 sin LPAD' AS comentario
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Solicitante = '12537749'
  AND fecha BETWEEN '2025-08-01' AND '2025-08-31';

-- =====================================================
-- QUERY AUXILIAR - Resumen estadístico del solicitante
-- =====================================================

SELECT 
  Solicitante,
  COUNT(*) as total_facturas,
  COUNT(DISTINCT Rut) as total_clientes_distintos,
  MIN(fecha) as fecha_factura_mas_antigua,
  MAX(fecha) as fecha_factura_mas_reciente,
  
  -- Valor total histórico
  SUM(
    (SELECT SUM(CAST(detalle.ValorTotal AS NUMERIC))
     FROM UNNEST(DetallesFactura) AS detalle)
  ) AS valor_total_historico,
  
  -- Facturas en agosto 2025
  COUNTIF(fecha BETWEEN '2025-08-01' AND '2025-08-31') as facturas_agosto_2025

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Solicitante = '0012537749'
GROUP BY Solicitante;

-- =====================================================
-- QUERY ESPERADA - Resultados de validación Q001
-- =====================================================

/*
RESULTADOS ESPERADOS SEGÚN TEST CASE JSON:

Factura: 0105481293
Cliente: CENTRAL GAS SPA  
RUT: 76747198-K
Fecha: 2025-08-30
Valor: 568805 (sin separador de miles en BigQuery)
Moneda: CLP

RESULTADOS OBTENIDOS DEL CHATBOT (15-09-2025):
✅ Factura: 0105481293 ← CORRECTO
✅ Cliente: CENTRAL GAS SPA ← CORRECTO  
✅ RUT: 76747198-K ← CORRECTO
✅ Fecha: 2025-08-30 ← CORRECTO
✅ Valor: $568.805 CLP ← CORRECTO (formateado)
✅ PDFs: 5 tipos disponibles ← CORRECTO
✅ URLs firmadas: Funcionando ← CORRECTO

FACTURAS ADICIONALES ENCONTRADAS:
- 0105443677 (2025-08-13): $3.425.266 CLP
- 0105418626 (2025-08-01): $2.242.164 CLP

STATUS: ✅ VALIDACIÓN EXITOSA
*/

-- =====================================================
-- INSTRUCCIONES DE USO
-- =====================================================

/*
1. EJECUTAR EN BIGQUERY CONSOLE:
   - Copiar la "QUERY PRINCIPAL" 
   - Pegar en BigQuery Console
   - Ejecutar contra datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo

2. VERIFICACIONES:
   ✅ Debe retornar al menos 1 fila (factura 0105481293)
   ✅ Cliente debe ser "CENTRAL GAS SPA"
   ✅ RUT debe ser "76747198-K" 
   ✅ Fecha debe ser "2025-08-30"
   ✅ Valor debe ser 568805 (numeric)
   ✅ Todos los PDFs deben tener ✅

3. COMPARACIÓN CON CHATBOT:
   - Los resultados SQL deben coincidir exactamente
   - con los datos que retorna el chatbot
   - El chatbot formatea valores con separador de miles
   - Las URLs firmadas son generadas dinámicamente

4. TROUBLESHOOTING:
   - Si no hay resultados: verificar tabla y dataset
   - Si código no normalizado: ejecutar query auxiliar
   - Si fechas incorrectas: verificar formato DATE
*/