-- 📊 QUERY DE VALIDACIÓN: Factura de Mayor Monto - Septiembre 2025
-- Solicitante: 0012141289 (GASCO GLP S.A. (MAIPU))
-- Validar que efectivamente 0105505395 es la factura de mayor monto

WITH facturas_septiembre AS (
  SELECT 
    Factura,
    Solicitante,
    Nombre,
    Rut,
    fecha,
    -- Calcular total amount desde DetallesFactura
    (SELECT SUM(ValorTotal) FROM UNNEST(DetallesFactura)) as monto_numerico,
    FORMAT("$%'.0f", (SELECT SUM(ValorTotal) FROM UNNEST(DetallesFactura))) as monto_formateado,
    -- Contar PDFs disponibles
    (CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as total_pdfs_disponibles
  FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  WHERE Solicitante = '0012141289'
    AND EXTRACT(YEAR FROM fecha) = 2025
    AND EXTRACT(MONTH FROM fecha) = 9
),

ranking_facturas AS (
  SELECT *,
    ROW_NUMBER() OVER (ORDER BY monto_numerico DESC) as ranking_monto,
    MAX(monto_numerico) OVER () as monto_maximo
  FROM facturas_septiembre
)

SELECT 
  '🏆 FACTURA DE MAYOR MONTO - SEPTIEMBRE 2025' as titulo,
  '' as separador1,
  
  -- Información de la factura ganadora
  CONCAT('📋 Factura: ', Factura) as factura_numero,
  CONCAT('👤 Cliente: ', Nombre, ' (RUT: ', Rut, ')') as cliente_info,
  CONCAT('💰 Monto: ', monto_formateado, ' CLP') as valor_total,
  CONCAT('📅 Fecha: ', fecha) as fecha_factura,
  CONCAT('📁 PDFs Disponibles: ', total_pdfs_disponibles) as documentos_count,
  
  '' as separador2,
  
  -- Validaciones
  CASE 
    WHEN Factura = '0105505395' THEN '✅ CORRECTO: Factura 0105505395 identificada'
    ELSE '❌ ERROR: Factura incorrecta identificada'
  END as validacion_factura,
  
  CASE 
    WHEN monto_numerico = monto_maximo THEN '✅ CORRECTO: Es efectivamente el monto máximo'
    ELSE '❌ ERROR: No es el monto máximo'
  END as validacion_monto,
  
  CASE 
    WHEN total_pdfs_disponibles >= 5 THEN '✅ CORRECTO: Tiene 5+ PDFs (debe usar ZIP)'
    WHEN total_pdfs_disponibles <= 3 THEN '✅ CORRECTO: Tiene ≤3 PDFs (puede usar URLs individuales)'
    ELSE '⚠️ ZONA GRIS: Tiene 4 PDFs (en el límite)'
  END as validacion_zip_logic,
  
  '' as separador3,
  
  -- Comparación con otras facturas del mes
  CONCAT('🔍 Ranking: #', ranking_monto, ' de ', COUNT(*) OVER (), ' facturas en septiembre') as posicion_ranking,
  
  -- Información técnica
  CONCAT('🔧 Solicitante SAP: ', Solicitante) as codigo_sap,
  
  '' as separador4

FROM ranking_facturas
WHERE ranking_monto = 1  -- Solo la factura de mayor monto

UNION ALL

-- Mostrar resumen de todas las facturas del mes para contexto
SELECT 
  '📊 RESUMEN DE TODAS LAS FACTURAS - SEPTIEMBRE 2025' as titulo,
  '' as separador1,
  '' as factura_numero,
  '' as cliente_info,
  '' as valor_total,
  '' as fecha_factura,
  '' as documentos_count,
  '' as separador2,
  '' as validacion_factura,
  '' as validacion_monto,
  '' as validacion_zip_logic,
  '' as separador3,
  '' as posicion_ranking,
  '' as codigo_sap,
  '' as separador4
FROM (SELECT 1) -- Fila vacía para separar secciones

UNION ALL

SELECT 
  CONCAT('#', ranking_monto, ' - Factura ', Factura) as titulo,
  CONCAT('Monto: ', monto_formateado, ' CLP') as separador1,
  CONCAT('Fecha: ', fecha) as factura_numero,
  CONCAT('PDFs: ', total_pdfs_disponibles) as cliente_info,
  CASE 
    WHEN ranking_monto = 1 THEN '🥇 MAYOR MONTO ← Esta es la respuesta correcta'
    WHEN ranking_monto = 2 THEN '🥈 Segundo lugar'
    WHEN ranking_monto = 3 THEN '🥉 Tercer lugar'
    ELSE CONCAT('   Posición ', ranking_monto)
  END as valor_total,
  '' as fecha_factura,
  '' as documentos_count,
  '' as separador2,
  '' as validacion_factura,
  '' as validacion_monto,
  '' as validacion_zip_logic,
  '' as separador3,
  '' as posicion_ranking,
  '' as codigo_sap,
  '' as separador4
FROM ranking_facturas
ORDER BY 
  CASE 
    WHEN titulo LIKE '%MAYOR MONTO%' THEN 1
    WHEN titulo LIKE '%RESUMEN%' THEN 2
    ELSE 3
  END,
  CAST(REGEXP_EXTRACT(titulo, r'#(\d+)') AS INT64) -- Ordenar por ranking