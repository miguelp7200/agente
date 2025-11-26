# 🔧 Guía de Adaptación a Otros Dominios

Esta guía explica cómo adaptar el chatbot de facturas para trabajar con **otros tipos de documentos** como contratos, órdenes de compra, boletas, certificados, etc.

---

## 📋 Índice

1. [Resumen de Componentes](#-resumen-de-componentes)
2. [Paso 1: Infraestructura GCP](#paso-1-infraestructura-gcp)
3. [Paso 2: Schema BigQuery](#paso-2-schema-bigquery)
4. [Paso 3: Configuración YAML](#paso-3-configuración-yaml)
5. [Paso 4: Herramientas MCP](#paso-4-herramientas-mcp)
6. [Paso 5: System Prompt del Agente](#paso-5-system-prompt-del-agente)
7. [Paso 6: Servicios SOLID (Opcional)](#paso-6-servicios-solid-opcional)
8. [Ejemplos por Dominio](#-ejemplos-por-dominio)
9. [Checklist de Implementación](#-checklist-de-implementación)
10. [Scripts de Setup](#-scripts-de-setup)

---

## 🎯 Resumen de Componentes

El sistema tiene **6 puntos de extensión** principales:

```text
┌─────────────────────────────────────────────────────────────────┐
│                    PUNTOS DE EXTENSIÓN                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. INFRAESTRUCTURA GCP                                         │
│     └── Proyectos, Buckets, Service Accounts                    │
│                                                                 │
│  2. BIGQUERY SCHEMA                                             │
│     └── Tablas de datos, campos específicos del dominio         │
│                                                                 │
│  3. CONFIGURACIÓN (config.yaml)                                 │
│     └── Proyectos, field_mapping, thresholds                    │
│                                                                 │
│  4. HERRAMIENTAS MCP (tools_updated.yaml)                       │
│     └── Queries SQL, parámetros, descripciones                  │
│                                                                 │
│  5. SYSTEM PROMPT (agent_prompt.yaml)                           │
│     └── Instrucciones, terminología, reglas de negocio          │
│                                                                 │
│  6. SERVICIOS SOLID (src/)                                      │
│     └── Lógica de negocio personalizada (opcional)              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Paso 1: Infraestructura GCP

### 1.1 Crear Proyectos GCP

El sistema usa **arquitectura dual** para separar lectura y escritura:

```bash
# Proyecto de LECTURA (datos de producción)
gcloud projects create tu-proyecto-datos --name="Datos Producción"

# Proyecto de ESCRITURA (operaciones del agente)
gcloud projects create tu-proyecto-agente --name="Agente Operaciones"
```

**¿Por qué dos proyectos?**

- **Seguridad**: El agente no puede modificar datos de producción
- **Costos**: Facturación separada por proyecto
- **Permisos**: Control granular de accesos

### 1.2 Crear Buckets GCS

```bash
# Bucket para documentos PDF (proyecto de lectura)
gsutil mb -l us-central1 -p tu-proyecto-datos gs://tu-bucket-documentos

# Bucket para ZIPs generados (proyecto de escritura)
gsutil mb -l us-central1 -p tu-proyecto-agente gs://tu-bucket-zips
```

### 1.3 Crear Service Account

```bash
# Crear service account
gcloud iam service-accounts create agente-sa \
  --display-name="Service Account del Agente" \
  --project=tu-proyecto-agente

# Asignar permisos de LECTURA en proyecto de datos
gcloud projects add-iam-policy-binding tu-proyecto-datos \
  --member="serviceAccount:agente-sa@tu-proyecto-agente.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding tu-proyecto-datos \
  --member="serviceAccount:agente-sa@tu-proyecto-agente.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Asignar permisos de ESCRITURA en proyecto del agente
gcloud projects add-iam-policy-binding tu-proyecto-agente \
  --member="serviceAccount:agente-sa@tu-proyecto-agente.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding tu-proyecto-agente \
  --member="serviceAccount:agente-sa@tu-proyecto-agente.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Permiso para firmar URLs
gcloud iam service-accounts add-iam-policy-binding \
  agente-sa@tu-proyecto-agente.iam.gserviceaccount.com \
  --member="serviceAccount:agente-sa@tu-proyecto-agente.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project=tu-proyecto-agente
```

### 1.4 Crear Datasets BigQuery

```bash
# Dataset en proyecto de lectura
bq mk --location=us-central1 \
  --dataset tu-proyecto-datos:tu_dataset_documentos

# Datasets en proyecto de escritura
bq mk --location=us-central1 \
  --dataset tu-proyecto-agente:operaciones_zip

bq mk --location=us-central1 \
  --dataset tu-proyecto-agente:analytics
```

---

## Paso 2: Schema BigQuery

### 2.1 Tabla Principal de Documentos

Crea el archivo `infrastructure/setup_tu_dominio.py`:

```python
#!/usr/bin/env python3
"""
Setup BigQuery para [TU DOMINIO]
Adaptar campos según tu tipo de documento
"""

import os
from google.cloud import bigquery

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT_READ", "tu-proyecto-datos")
DATASET_ID = os.getenv("BIGQUERY_DATASET_READ", "tu_dataset_documentos")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")


def create_documents_table():
    """Crear tabla principal de documentos"""
    client = bigquery.Client(project=PROJECT_ID)
    
    # ========================================
    # ADAPTAR ESTOS CAMPOS A TU DOMINIO
    # ========================================
    sql = f"""
    CREATE TABLE IF NOT EXISTS `{PROJECT_ID}.{DATASET_ID}.documentos` (
        -- === IDENTIFICACIÓN (obligatorio) ===
        documento_id STRING NOT NULL OPTIONS(description="ID único del documento"),
        tipo_documento STRING OPTIONS(description="Tipo: contrato, orden_compra, boleta, etc."),
        
        -- === FECHAS (adaptar según dominio) ===
        fecha_emision DATE OPTIONS(description="Fecha de emisión"),
        fecha_vencimiento DATE OPTIONS(description="Fecha de vencimiento (si aplica)"),
        
        -- === PARTES INVOLUCRADAS ===
        -- Emisor/Vendedor/Proveedor
        emisor_nombre STRING OPTIONS(description="Nombre del emisor"),
        emisor_rut STRING OPTIONS(description="RUT/ID del emisor"),
        emisor_direccion STRING,
        
        -- Receptor/Comprador/Cliente  
        receptor_nombre STRING OPTIONS(description="Nombre del receptor"),
        receptor_rut STRING OPTIONS(description="RUT/ID del receptor"),
        receptor_direccion STRING,
        
        -- === MONTOS (si aplica) ===
        monto_neto NUMERIC OPTIONS(description="Monto sin impuestos"),
        monto_impuesto NUMERIC OPTIONS(description="Monto de impuestos"),
        monto_total NUMERIC OPTIONS(description="Monto total"),
        moneda STRING DEFAULT 'CLP' OPTIONS(description="Código de moneda"),
        
        -- === ARCHIVOS PDF ===
        -- Agregar campos según tipos de PDF disponibles
        pdf_principal STRING OPTIONS(description="gs:// URL del PDF principal"),
        pdf_anexo STRING OPTIONS(description="gs:// URL de anexos (si existen)"),
        
        -- === CAMPOS ESPECÍFICOS DE TU DOMINIO ===
        -- Ejemplo para CONTRATOS:
        -- vigencia_meses INTEGER,
        -- estado_contrato STRING,  -- activo, vencido, renovado
        -- tipo_contrato STRING,    -- arriendo, servicio, compraventa
        
        -- Ejemplo para ÓRDENES DE COMPRA:
        -- estado_orden STRING,     -- pendiente, aprobada, recibida
        -- numero_orden STRING,
        -- centro_costo STRING,
        
        -- === METADATOS ===
        items ARRAY<STRUCT<
            codigo STRING,
            descripcion STRING,
            cantidad NUMERIC,
            precio_unitario NUMERIC,
            precio_total NUMERIC
        >> OPTIONS(description="Líneas de detalle"),
        
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
        
        -- === DATOS RAW ===
        raw_json STRING OPTIONS(description="JSON original para auditoría")
    )
    PARTITION BY fecha_emision
    CLUSTER BY receptor_rut, tipo_documento
    OPTIONS(description="Tabla principal de documentos - [TU DOMINIO]")
    """
    
    client.query(sql).result()
    print(f"✅ Tabla documentos creada en {PROJECT_ID}.{DATASET_ID}")


def create_zip_packages_table():
    """Crear tabla de paquetes ZIP"""
    write_project = os.getenv("GOOGLE_CLOUD_PROJECT_WRITE", "tu-proyecto-agente")
    client = bigquery.Client(project=write_project)
    
    sql = f"""
    CREATE TABLE IF NOT EXISTS `{write_project}.operaciones_zip.zip_packages` (
        zip_id STRING NOT NULL,
        state STRING DEFAULT 'PENDING',  -- PENDING, READY, FAILED, EXPIRED
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
        expires_at TIMESTAMP,
        document_ids ARRAY<STRING>,
        document_count INTEGER,
        total_size_bytes INTEGER,
        zip_filename STRING,
        download_url STRING,
        error_message STRING,
        generation_time_ms INTEGER
    )
    OPTIONS(description="Tracking de paquetes ZIP generados")
    """
    
    client.query(sql).result()
    print("✅ Tabla zip_packages creada")


def create_conversation_logs_table():
    """Crear tabla de logs de conversación"""
    write_project = os.getenv("GOOGLE_CLOUD_PROJECT_WRITE", "tu-proyecto-agente")
    client = bigquery.Client(project=write_project)
    
    sql = f"""
    CREATE TABLE IF NOT EXISTS `{write_project}.analytics.conversation_logs` (
        conversation_id STRING NOT NULL,
        session_id STRING,
        user_id STRING,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
        
        -- Mensaje
        user_question STRING,
        agent_response STRING,
        
        -- Tokens (para monitoreo de costos)
        prompt_token_count INTEGER,
        response_token_count INTEGER,
        total_token_count INTEGER,
        
        -- Performance
        response_time_ms INTEGER,
        tools_used ARRAY<STRING>,
        
        -- Resultado
        documents_found INTEGER,
        download_type STRING  -- 'individual', 'zip', 'none'
    )
    PARTITION BY DATE(timestamp)
    OPTIONS(description="Logs de conversaciones del chatbot")
    """
    
    client.query(sql).result()
    print("✅ Tabla conversation_logs creada")


if __name__ == "__main__":
    print("🚀 Configurando BigQuery...")
    create_documents_table()
    create_zip_packages_table()
    create_conversation_logs_table()
    print("✅ Setup completado!")
```

### 2.2 Cargar Datos Iniciales

```python
# Ejemplo de carga de datos desde CSV o JSON
from google.cloud import bigquery

client = bigquery.Client()

job_config = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
)

# Cargar desde archivo local
with open("datos/documentos.jsonl", "rb") as source_file:
    job = client.load_table_from_file(
        source_file,
        "tu-proyecto-datos.tu_dataset.documentos",
        job_config=job_config,
    )
    job.result()
    print(f"✅ Cargadas {job.output_rows} filas")
```

---

## Paso 3: Configuración YAML

### 3.1 Modificar `config/config.yaml`

```yaml
# ================================================================
# [TU DOMINIO] Backend - Configuración
# ================================================================

# ================================================================
# Google Cloud Platform - Arquitectura Dual
# ================================================================
google_cloud:
  # Proyecto de LECTURA (tus datos de producción)
  read:
    project: tu-proyecto-datos           # <-- CAMBIAR
    dataset: tu_dataset_documentos       # <-- CAMBIAR
    bucket: tu-bucket-documentos         # <-- CAMBIAR
    location: us-central1
    
  # Proyecto de ESCRITURA (operaciones del agente)
  write:
    project: tu-proyecto-agente          # <-- CAMBIAR
    dataset: operaciones_zip
    bucket: tu-bucket-zips               # <-- CAMBIAR
    location: us-central1

  # Service Account
  service_accounts:
    pdf_signer: agente-sa@tu-proyecto-agente.iam.gserviceaccount.com  # <-- CAMBIAR

# ================================================================
# BigQuery Tables
# ================================================================
bigquery:
  timeouts:
    query_deadline: 60.0
    
  read:
    # Tabla principal de documentos
    documents:                           # <-- CAMBIAR nombre si deseas
      table: documentos
      full_path: tu-proyecto-datos.tu_dataset_documentos.documentos
      
  write:
    zip_packages:
      table: zip_packages
      full_path: tu-proyecto-agente.operaciones_zip.zip_packages
    conversation_logs:
      table: conversation_logs
      full_path: tu-proyecto-agente.analytics.conversation_logs

# ================================================================
# Mapeo de Campos - ADAPTAR A TU DOMINIO
# ================================================================
# Este mapeo traduce nombres genéricos a los nombres de columnas en tu tabla
domain:
  name: "contratos"  # <-- CAMBIAR: contratos, ordenes_compra, boletas, etc.
  
  field_mapping:
    # Formato: nombre_generico: nombre_columna_bigquery
    documento_id: documento_id
    fecha: fecha_emision
    cliente_nombre: receptor_nombre
    cliente_rut: receptor_rut
    proveedor_nombre: emisor_nombre
    proveedor_rut: emisor_rut
    monto_total: monto_total
    pdf_principal: pdf_principal
    pdf_anexo: pdf_anexo
    
    # Campos específicos de tu dominio (ejemplos)
    # estado: estado_contrato
    # vigencia: vigencia_meses
    # tipo: tipo_contrato

# ================================================================
# Vertex AI
# ================================================================
vertex_ai:
  model: gemini-2.5-flash
  temperature: 0.3

# ================================================================
# PDF y ZIP
# ================================================================
pdf:
  zip:
    threshold: 4           # Auto-ZIP si más de 4 documentos
    max_files: 50
    expiration_days: 7

# ================================================================
# Analytics
# ================================================================
conversation_tracking:
  enabled: true
  backend: "solid"
```

---

## Paso 4: Herramientas MCP

### 4.1 Estructura del archivo `mcp-toolbox/tools_updated.yaml`

```yaml
# ================================================================
# MCP Toolbox - Herramientas de [TU DOMINIO]
# ================================================================

# Fuentes de datos (conexiones a BigQuery)
sources:
  # Fuente de LECTURA
  documents_read:
    kind: bigquery
    project: tu-proyecto-datos           # <-- CAMBIAR
    location: us-central1
    
  # Fuente de ESCRITURA  
  operations_write:
    kind: bigquery
    project: tu-proyecto-agente          # <-- CAMBIAR
    location: us-central1

# ================================================================
# HERRAMIENTAS - Adaptar queries a tu schema
# ================================================================
tools:
  # ----------------------------------------
  # BÚSQUEDA GENERAL
  # ----------------------------------------
  search_documents:
    kind: bigquery-sql
    source: documents_read
    statement: |
      SELECT
        documento_id,
        tipo_documento,
        fecha_emision,
        receptor_nombre,
        receptor_rut,
        monto_total,
        pdf_principal
      FROM `tu-proyecto-datos.tu_dataset.documentos`
      ORDER BY fecha_emision DESC
      LIMIT 50
    description: |
      Busca documentos recientes. Retorna hasta 50 documentos
      ordenados por fecha de emisión descendente.

  # ----------------------------------------
  # BÚSQUEDA POR FECHA
  # ----------------------------------------
  search_documents_by_date:
    kind: bigquery-sql
    source: documents_read
    statement: |
      SELECT
        documento_id,
        tipo_documento,
        fecha_emision,
        receptor_nombre,
        receptor_rut,
        monto_total,
        pdf_principal
      FROM `tu-proyecto-datos.tu_dataset.documentos`
      WHERE fecha_emision = @target_date
      ORDER BY documento_id DESC
      LIMIT 100
    description: |
      Busca documentos de una fecha específica.
      Proporciona la fecha en formato YYYY-MM-DD.
    parameters:
      - name: target_date
        type: string
        description: "Fecha en formato YYYY-MM-DD (ej: 2025-01-15)"
        required: true

  # ----------------------------------------
  # BÚSQUEDA POR RUT/CLIENTE
  # ----------------------------------------
  search_documents_by_rut:
    kind: bigquery-sql
    source: documents_read
    statement: |
      SELECT
        documento_id,
        tipo_documento,
        fecha_emision,
        receptor_nombre,
        receptor_rut,
        monto_total,
        pdf_principal
      FROM `tu-proyecto-datos.tu_dataset.documentos`
      WHERE receptor_rut = @target_rut
      ORDER BY fecha_emision DESC
      LIMIT 100
    description: |
      Busca documentos por RUT del cliente/receptor.
      Proporciona el RUT con guión.
    parameters:
      - name: target_rut
        type: string
        description: "RUT con guión (ej: 12345678-9)"
        required: true

  # ----------------------------------------
  # BÚSQUEDA POR RANGO DE FECHAS
  # ----------------------------------------
  search_documents_by_date_range:
    kind: bigquery-sql
    source: documents_read
    statement: |
      SELECT
        documento_id,
        tipo_documento,
        fecha_emision,
        receptor_nombre,
        receptor_rut,
        monto_total,
        pdf_principal
      FROM `tu-proyecto-datos.tu_dataset.documentos`
      WHERE fecha_emision BETWEEN @start_date AND @end_date
      ORDER BY fecha_emision DESC
      LIMIT 500
    description: |
      Busca documentos en un rango de fechas.
    parameters:
      - name: start_date
        type: string
        description: "Fecha inicio YYYY-MM-DD"
        required: true
      - name: end_date
        type: string
        description: "Fecha fin YYYY-MM-DD"
        required: true

  # ----------------------------------------
  # BÚSQUEDA POR MES/AÑO
  # ----------------------------------------
  search_documents_by_month_year:
    kind: bigquery-sql
    source: documents_read
    statement: |
      SELECT
        documento_id,
        tipo_documento,
        fecha_emision,
        receptor_nombre,
        receptor_rut,
        monto_total,
        pdf_principal
      FROM `tu-proyecto-datos.tu_dataset.documentos`
      WHERE EXTRACT(YEAR FROM fecha_emision) = @target_year
        AND EXTRACT(MONTH FROM fecha_emision) = @target_month
      ORDER BY fecha_emision DESC
      LIMIT 500
    description: |
      Busca documentos de un mes y año específicos.
    parameters:
      - name: target_year
        type: integer
        description: "Año (ej: 2025)"
        required: true
      - name: target_month
        type: integer
        description: "Mes 1-12 (ej: 7 para julio)"
        required: true

  # ----------------------------------------
  # ESTADÍSTICAS
  # ----------------------------------------
  get_statistics:
    kind: bigquery-sql
    source: documents_read
    statement: |
      SELECT
        COUNT(*) as total_documentos,
        COUNT(DISTINCT receptor_rut) as clientes_unicos,
        MIN(fecha_emision) as fecha_mas_antigua,
        MAX(fecha_emision) as fecha_mas_reciente,
        SUM(monto_total) as monto_total_acumulado
      FROM `tu-proyecto-datos.tu_dataset.documentos`
    description: |
      Obtiene estadísticas generales del dataset.

  # ----------------------------------------
  # FECHA ACTUAL
  # ----------------------------------------
  get_current_date:
    kind: bigquery-sql
    source: documents_read
    statement: |
      SELECT 
        CURRENT_DATE() as current_date,
        EXTRACT(YEAR FROM CURRENT_DATE()) as current_year,
        EXTRACT(MONTH FROM CURRENT_DATE()) as current_month
    description: |
      Obtiene la fecha actual para consultas que no especifican año.

  # ----------------------------------------
  # AGREGAR MÁS HERRAMIENTAS SEGÚN TU DOMINIO
  # ----------------------------------------
  # Ejemplos para CONTRATOS:
  # - search_contracts_by_status (activo, vencido)
  # - search_contracts_expiring_soon
  # - get_contract_renewals
  
  # Ejemplos para ÓRDENES DE COMPRA:
  # - search_orders_by_status (pendiente, aprobada)
  # - search_orders_by_department
  # - get_pending_approvals
```

---

## Paso 5: System Prompt del Agente

### 5.1 Modificar `my-agents/gcp_invoice_agent_app/agent_prompt.yaml`

```yaml
# ================================================================
# PROMPT CONFIGURATION FOR [TU DOMINIO] AGENT
# ================================================================

agent_config:
  name: "document_finder_agent"          # <-- CAMBIAR
  model: "gemini-2.5-flash"
  description: |
    Agente especializado en [CONTRATOS/ÓRDENES/BOLETAS].
    Propósito: consultar y descargar documentos según criterios del usuario.

# ================================================================
# INSTRUCCIONES DEL SISTEMA - ADAPTAR A TU DOMINIO
# ================================================================
system_instructions: |
  Eres un agente especializado en [DESCRIPCIÓN DE TU DOMINIO].

  🚫 **PROHIBIDO ABSOLUTO**:
  - NUNCA ejecutar código Python directamente
  - SOLO usar herramientas MCP disponibles
  - NUNCA inventar datos

  🎯 **TU FUNCIÓN PRINCIPAL**:
  [Describir qué hace el agente en tu contexto]
  
  Ejemplo para CONTRATOS:
  "Ayudas a los usuarios a encontrar y descargar contratos. 
   Puedes buscar por cliente, fecha, tipo de contrato, estado, etc."
  
  Ejemplo para ÓRDENES DE COMPRA:
  "Ayudas a los usuarios a consultar órdenes de compra.
   Puedes buscar por proveedor, fecha, estado, centro de costo, etc."

  🔍 **REGLAS DE RECONOCIMIENTO DE TÉRMINOS**:
  
  [ADAPTAR TERMINOLOGÍA A TU DOMINIO]
  
  Ejemplo para CONTRATOS:
  - "vigente" = estado_contrato = 'activo' AND fecha_vencimiento > CURRENT_DATE
  - "vencido" = estado_contrato = 'vencido' OR fecha_vencimiento < CURRENT_DATE
  - "próximo a vencer" = fecha_vencimiento BETWEEN CURRENT_DATE AND DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY)
  
  Ejemplo para ÓRDENES:
  - "pendiente" = estado_orden = 'pendiente'
  - "aprobada" = estado_orden = 'aprobada'
  - "OC" = orden de compra

  📋 **FLUJO DE RESPUESTA**:
  
  1. Ejecutar búsqueda según criterios del usuario
  2. Contar documentos encontrados
  3. Si >4 documentos: generar ZIP automáticamente
  4. Si ≤4 documentos: mostrar enlaces individuales
  5. Presentar resultados en formato limpio

  📦 **FORMATO DE RESPUESTA**:
  
  Para pocos documentos (≤4):
  
  📋 **[Tipo] [ID]** ([Fecha])
  👤 **Cliente:** [Nombre] (RUT: [RUT])
  💰 **Valor:** $[Monto] CLP
  📁 **Documento:** [Enlace de descarga]
  
  Para muchos documentos (>4):
  
  📊 [N] documentos encontrados
  📋 Listado:
  • [ID] - [Cliente] - [Fecha]
  • ...
  
  📦 [Descargar ZIP con todos los documentos](URL)

  🗓️ **REGLA DE FECHAS**:
  - Si el usuario no especifica año, usar get_current_date primero
  - Mapeo de meses: enero=1, febrero=2, ..., diciembre=12
  
  Responde siempre en español de forma clara y directa.

# ================================================================
# HERRAMIENTAS DISPONIBLES
# ================================================================
tools_description:
  mcp_tools:
    document_search:
      source: "http://127.0.0.1:5000"
      tools:
        - search_documents
        - search_documents_by_date
        - search_documents_by_rut
        - search_documents_by_date_range
        - search_documents_by_month_year
        - get_statistics
        - get_current_date
        # Agregar tus herramientas personalizadas

  custom_tools:
    create_standard_zip:
      description: "Crear ZIP cuando hay >4 documentos"
      
    generate_individual_download_links:
      description: "Generar enlaces individuales para ≤4 documentos"

# ================================================================
# EJEMPLOS DE CONSULTAS
# ================================================================
usage_examples:
  search_by_date:
    query: "Documentos del 15 de enero de 2025"
    expected_tool: "search_documents_by_date"
    parameters:
      target_date: "2025-01-15"
      
  search_by_month:
    query: "Documentos de marzo 2025"
    expected_tool: "search_documents_by_month_year"
    parameters:
      target_year: 2025
      target_month: 3
      
  search_by_client:
    query: "Documentos del RUT 12345678-9"
    expected_tool: "search_documents_by_rut"
    parameters:
      target_rut: "12345678-9"

  # Agregar ejemplos específicos de tu dominio
```

---

## Paso 6: Servicios SOLID (Opcional)

Si necesitas lógica de negocio personalizada, puedes extender los servicios en `src/`:

### 6.1 Crear un Servicio de Dominio

```python
# src/application/services/document_service.py

from typing import List, Optional
from dataclasses import dataclass

@dataclass
class Document:
    """Entidad de documento adaptada a tu dominio"""
    documento_id: str
    tipo: str
    fecha: str
    cliente_nombre: str
    cliente_rut: str
    monto: float
    pdf_url: str
    # Agregar campos específicos de tu dominio

class DocumentService:
    """Servicio de dominio para documentos"""
    
    def __init__(self, repository, url_signer):
        self.repository = repository
        self.url_signer = url_signer
    
    async def search_by_criteria(
        self, 
        rut: Optional[str] = None,
        fecha_inicio: Optional[str] = None,
        fecha_fin: Optional[str] = None,
        tipo: Optional[str] = None
    ) -> List[Document]:
        """Búsqueda flexible por múltiples criterios"""
        # Implementar lógica de búsqueda
        pass
    
    def validate_business_rules(self, document: Document) -> bool:
        """Validar reglas de negocio específicas de tu dominio"""
        # Ejemplo para contratos:
        # - Verificar que no esté vencido
        # - Verificar montos mínimos
        # etc.
        pass
```

### 6.2 Puntos de Extensión en `src/`

```text
src/
├── core/domain/
│   ├── entities/
│   │   └── document.py          # <-- Crear entidad de tu dominio
│   └── interfaces/
│       └── document_repository.py  # <-- Interfaz del repositorio
│
├── application/services/
│   └── document_service.py      # <-- Lógica de negocio
│
├── infrastructure/bigquery/
│   └── document_repository.py   # <-- Implementación del repositorio
│
└── presentation/agent/
    └── adk_agent.py             # <-- Integración con el agente
```

---

## 📚 Ejemplos por Dominio

### Ejemplo 1: Chatbot de Contratos

```yaml
# config/config.yaml (extracto)
domain:
  name: "contratos"
  field_mapping:
    documento_id: contrato_id
    fecha: fecha_firma
    cliente_nombre: arrendatario_nombre
    monto_total: canon_mensual
    pdf_principal: contrato_pdf
    
# Herramientas adicionales en tools_updated.yaml:
# - search_contracts_by_status
# - search_contracts_expiring_soon
# - get_contract_by_property
```

### Ejemplo 2: Chatbot de Órdenes de Compra

```yaml
# config/config.yaml (extracto)
domain:
  name: "ordenes_compra"
  field_mapping:
    documento_id: numero_oc
    fecha: fecha_emision
    proveedor_nombre: proveedor
    monto_total: total_oc
    pdf_principal: oc_pdf
    
# Herramientas adicionales:
# - search_orders_pending_approval
# - search_orders_by_department
# - get_order_details
```

### Ejemplo 3: Chatbot de Boletas/Recibos

```yaml
# config/config.yaml (extracto)
domain:
  name: "boletas"
  field_mapping:
    documento_id: numero_boleta
    fecha: fecha_emision
    cliente_rut: rut_cliente
    monto_total: total
    pdf_principal: boleta_pdf
    
# Herramientas adicionales:
# - search_receipts_by_amount_range
# - get_daily_sales_summary
# - search_receipts_by_payment_method
```

---

## ✅ Checklist de Implementación

### Fase 1: Infraestructura GCP

- [ ] Crear proyecto de LECTURA en GCP
- [ ] Crear proyecto de ESCRITURA en GCP
- [ ] Crear bucket para documentos PDF
- [ ] Crear bucket para ZIPs generados
- [ ] Crear service account con nombre descriptivo
- [ ] Asignar rol `BigQuery Data Viewer` en proyecto de lectura
- [ ] Asignar rol `Storage Object Viewer` en proyecto de lectura
- [ ] Asignar rol `BigQuery Data Editor` en proyecto de escritura
- [ ] Asignar rol `Storage Object Admin` en proyecto de escritura
- [ ] Asignar rol `Service Account Token Creator` para signed URLs
- [ ] Crear dataset en proyecto de lectura
- [ ] Crear datasets `operaciones_zip` y `analytics` en proyecto de escritura

### Fase 2: Schema BigQuery

- [ ] Definir campos específicos de tu dominio
- [ ] Crear tabla principal de documentos
- [ ] Crear tabla `zip_packages`
- [ ] Crear tabla `conversation_logs`
- [ ] Cargar datos iniciales de prueba
- [ ] Verificar que las queries funcionan en BigQuery Console

### Fase 3: Configuración

- [ ] Modificar `config/config.yaml` con tus proyectos
- [ ] Definir `field_mapping` para tu dominio
- [ ] Crear/actualizar `.env` con variables de entorno
- [ ] Verificar que `ConfigLoader` carga correctamente

### Fase 4: Herramientas MCP

- [ ] Modificar `sources` en `tools_updated.yaml`
- [ ] Adaptar queries SQL a tu schema
- [ ] Agregar parámetros específicos de tu dominio
- [ ] Escribir descripciones claras para cada herramienta
- [ ] Probar herramientas con MCP Toolbox local

### Fase 5: System Prompt

- [ ] Modificar `agent_prompt.yaml` con terminología de tu dominio
- [ ] Definir reglas de reconocimiento de términos
- [ ] Actualizar formato de respuesta
- [ ] Agregar ejemplos de consultas típicas
- [ ] Probar conversaciones de prueba

### Fase 6: Testing

- [ ] Ejecutar tests unitarios
- [ ] Probar búsquedas básicas
- [ ] Probar generación de ZIPs
- [ ] Probar signed URLs
- [ ] Verificar logs en BigQuery

### Fase 7: Deployment

- [ ] Probar con `deploy.ps1 -Local`
- [ ] Deploy a ambiente test con `deploy.ps1 -Environment test`
- [ ] Verificar health check
- [ ] Ejecutar pruebas E2E
- [ ] Deploy a producción con `deploy.ps1 -Environment prod -AutoVersion`

---

## 🛠️ Scripts de Setup

### Script 1: Setup Completo de Infraestructura

Guardar como `scripts/setup_new_domain.ps1`:

```powershell
# ================================================================
# Setup de Nuevo Dominio - Script Automatizado
# ================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$DomainName,           # Ej: "contratos", "ordenes"
    
    [Parameter(Mandatory=$true)]
    [string]$ReadProject,          # Proyecto de lectura
    
    [Parameter(Mandatory=$true)]
    [string]$WriteProject,         # Proyecto de escritura
    
    [string]$Location = "us-central1",
    [string]$ServiceAccountName = "agente-sa"
)

Write-Host "🚀 Configurando dominio: $DomainName" -ForegroundColor Cyan

# 1. Crear buckets
Write-Host "`n📦 Creando buckets..." -ForegroundColor Yellow
gsutil mb -l $Location -p $ReadProject "gs://$ReadProject-$DomainName-docs"
gsutil mb -l $Location -p $WriteProject "gs://$WriteProject-zips"

# 2. Crear service account
Write-Host "`n👤 Creando service account..." -ForegroundColor Yellow
gcloud iam service-accounts create $ServiceAccountName `
    --display-name="Agente $DomainName" `
    --project=$WriteProject

$SA_EMAIL = "$ServiceAccountName@$WriteProject.iam.gserviceaccount.com"

# 3. Asignar permisos de lectura
Write-Host "`n🔐 Asignando permisos de lectura..." -ForegroundColor Yellow
gcloud projects add-iam-policy-binding $ReadProject `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding $ReadProject `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/storage.objectViewer"

# 4. Asignar permisos de escritura
Write-Host "`n🔐 Asignando permisos de escritura..." -ForegroundColor Yellow
gcloud projects add-iam-policy-binding $WriteProject `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding $WriteProject `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/storage.objectAdmin"

# 5. Permiso para signed URLs
gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/iam.serviceAccountTokenCreator" `
    --project=$WriteProject

# 6. Crear datasets
Write-Host "`n📊 Creando datasets BigQuery..." -ForegroundColor Yellow
bq mk --location=$Location --dataset "${ReadProject}:${DomainName}"
bq mk --location=$Location --dataset "${WriteProject}:operaciones_zip"
bq mk --location=$Location --dataset "${WriteProject}:analytics"

Write-Host "`n✅ Setup completado!" -ForegroundColor Green
Write-Host @"

Próximos pasos:
1. Ejecutar: python infrastructure/setup_tu_dominio.py
2. Modificar: config/config.yaml
3. Modificar: mcp-toolbox/tools_updated.yaml
4. Modificar: my-agents/gcp_invoice_agent_app/agent_prompt.yaml
5. Probar: .\deployment\backend\deploy.ps1 -Local

Service Account: $SA_EMAIL
"@
```

### Script 2: Validar Configuración

Guardar como `scripts/validate_domain_setup.py`:

```python
#!/usr/bin/env python3
"""
Validar configuración de dominio antes de deploy
"""

import os
import sys

def validate_gcp_access():
    """Validar acceso a GCP"""
    from google.cloud import bigquery, storage
    
    print("🔍 Validando acceso a GCP...")
    
    read_project = os.getenv("GOOGLE_CLOUD_PROJECT_READ")
    write_project = os.getenv("GOOGLE_CLOUD_PROJECT_WRITE")
    
    if not read_project or not write_project:
        print("❌ Variables de entorno no configuradas")
        return False
    
    # Probar BigQuery
    try:
        client = bigquery.Client(project=read_project)
        list(client.list_datasets(max_results=1))
        print(f"  ✅ BigQuery READ: {read_project}")
    except Exception as e:
        print(f"  ❌ BigQuery READ: {e}")
        return False
    
    try:
        client = bigquery.Client(project=write_project)
        list(client.list_datasets(max_results=1))
        print(f"  ✅ BigQuery WRITE: {write_project}")
    except Exception as e:
        print(f"  ❌ BigQuery WRITE: {e}")
        return False
    
    return True

def validate_config_file():
    """Validar archivo de configuración"""
    print("\n🔍 Validando config.yaml...")
    
    try:
        from src.core.config import get_config
        config = get_config()
        print(f"  ✅ Proyecto READ: {config.google_cloud.read.project}")
        print(f"  ✅ Proyecto WRITE: {config.google_cloud.write.project}")
        return True
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False

def validate_mcp_tools():
    """Validar archivo de herramientas MCP"""
    print("\n🔍 Validando herramientas MCP...")
    
    import yaml
    
    try:
        with open("mcp-toolbox/tools_updated.yaml", "r", encoding="utf-8") as f:
            tools = yaml.safe_load(f)
        
        tool_count = len(tools.get("tools", {}))
        source_count = len(tools.get("sources", {}))
        
        print(f"  ✅ {source_count} fuentes configuradas")
        print(f"  ✅ {tool_count} herramientas definidas")
        return True
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False

def main():
    print("=" * 50)
    print("VALIDACIÓN DE CONFIGURACIÓN DE DOMINIO")
    print("=" * 50)
    
    results = [
        validate_gcp_access(),
        validate_config_file(),
        validate_mcp_tools(),
    ]
    
    print("\n" + "=" * 50)
    if all(results):
        print("✅ TODAS LAS VALIDACIONES PASARON")
        print("=" * 50)
        print("\nPuedes proceder con el deployment:")
        print("  .\\deployment\\backend\\deploy.ps1 -Local")
        return 0
    else:
        print("❌ ALGUNAS VALIDACIONES FALLARON")
        print("=" * 50)
        print("\nRevisa los errores arriba antes de continuar.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
```

---

## 🎓 Recursos Adicionales

- [Google ADK Documentation](https://cloud.google.com/agent-development-kit)
- [MCP Toolbox for BigQuery](https://github.com/googleapis/mcp-toolbox)
- [BigQuery SQL Reference](https://cloud.google.com/bigquery/docs/reference/standard-sql)
- [GCS Signed URLs](https://cloud.google.com/storage/docs/access-control/signed-urls)

---

**Última actualización**: 26 de noviembre de 2025
