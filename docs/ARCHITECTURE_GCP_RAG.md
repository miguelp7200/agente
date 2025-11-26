# Invoice Chatbot Backend - Arquitectura GCP con RAG

```mermaid
flowchart TB
    %% === USUARIO ===
    User(("👤 Usuario"))
    
    %% === FRONTEND ===
    subgraph Frontend["🖥️ Frontend"]
        WebApp["React App<br/>Chat UI"]
    end
    
    %% === CLOUD RUN ===
    subgraph CloudRun["☁️ Cloud Run"]
        ADK["ADK Agent<br/>invoice-backend"]
        MCP["MCP Toolbox<br/>52+ tools"]
        ADK <--> MCP
    end
    
    %% === VERTEX AI ===
    subgraph VertexAI["🤖 Vertex AI"]
        Gemini["Gemini 2.5 Flash<br/>LLM"]
        Embeddings["Text Embeddings<br/>Gemini Embeddings"]
    end
    
    %% === BIGQUERY ===
    subgraph BigQuery["📊 BigQuery"]
        BQ_READ[("datalake-gasco<br/>READ")]
        BQ_WRITE[("agent-intelligence-gasco<br/>WRITE")]
        BQ_VECTORS[("agent-intelligence-gasco<br/>RAG Vectors")]
    end
    
    %% === CLOUD STORAGE ===
    subgraph GCS["📁 Cloud Storage"]
        GCS_PDF[("miguel-test<br/>PDFs")]
        GCS_ZIP[("agent-intelligence-zips<br/>ZIPs")]
    end
    
    %% === CONEXIONES PRINCIPALES ===
    User -->|"Browser"| WebApp
    WebApp -->|"REST API"| CloudRun
    ADK <-->|"LLM API"| Gemini
    MCP -->|"SQL queries"| BQ_READ
    MCP -->|"ZIP records"| BQ_WRITE
    BQ_READ -.->|"gs:// paths"| GCS_PDF
    ADK -->|"Create ZIP"| GCS_ZIP
    GCS_PDF -->|"Signed URLs"| WebApp
    GCS_ZIP -->|"Signed URLs"| WebApp
    
    %% === CONEXIONES RAG ===
    ADK -->|"Query embedding"| Embeddings
    Embeddings -->|"VECTOR_SEARCH"| BQ_VECTORS
    BQ_VECTORS -->|"Context chunks"| ADK
    GCS_PDF -.->|"Indexación batch"| Embeddings
    Embeddings -.->|"Store embeddings"| BQ_VECTORS
    
    %% === ESTILOS ===
    classDef userStyle fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef cloudrunStyle fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
    classDef vertexStyle fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef bqStyle fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef gcsStyle fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef ragStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    
    classDef frontendStyle fill:#e0f2f1,stroke:#00695c,stroke-width:2px
    
    class User userStyle
    class WebApp frontendStyle
    class ADK,MCP cloudrunStyle
    class Gemini,Embeddings vertexStyle
    class BQ_READ,BQ_WRITE bqStyle
    class BQ_VECTORS ragStyle
    class GCS_PDF,GCS_ZIP gcsStyle
```

---

## Leyenda

| Servicio | Proyecto/Bucket | Propósito |
|----------|-----------------|-----------|
| **Frontend** | React App | Chat UI para usuarios |
| **Cloud Run** | `us-central1` | API REST + ADK Agent |
| **MCP Toolbox** | interno | 52+ herramientas BigQuery |
| **Gemini 2.5 Flash** | Vertex AI | Procesamiento lenguaje natural |
| **Gemini Embeddings** | Vertex AI | Vectorización de texto |
| **BigQuery READ** | `datalake-gasco` | Consulta facturas (producción) |
| **BigQuery WRITE** | `agent-intelligence-gasco` | Operaciones ZIPs, logs |
| **BigQuery RAG** | `agent-intelligence-gasco.rag` | Embeddings vectoriales |
| **GCS PDFs** | `miguel-test` | PDFs originales de facturas |
| **GCS ZIPs** | `agent-intelligence-zips` | Paquetes ZIP generados |

---

## Flujos RAG

### 1. Indexación (Batch/Offline)
```
PDF → Extraer texto → Chunking → Vertex Embeddings → BigQuery Vectors
```

### 2. Query (Online)
```
User Query → Embedding → VECTOR_SEARCH() → Top-K chunks → Gemini + Context → Respuesta
```

### Tabla BigQuery Propuesta
```sql
CREATE TABLE `agent-intelligence-gasco.rag.document_embeddings` (
  doc_id STRING,
  factura_number STRING,
  chunk_text STRING,
  chunk_index INT64,
  embedding ARRAY<FLOAT64>,  -- 768 dims
  source_path STRING,        -- gs://miguel-test/...
  created_at TIMESTAMP
);
```

### Query Vectorial
```sql
SELECT chunk_text, factura_number
FROM `agent-intelligence-gasco.rag.document_embeddings`
ORDER BY ML.DISTANCE(embedding, @query_embedding, 'COSINE')
LIMIT 5;
```
