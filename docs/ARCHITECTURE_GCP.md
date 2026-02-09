# Invoice Chatbot Backend - Arquitectura GCP

```mermaid
flowchart TB
    %% === USUARIO ===
    User(("Usuario"))

    %% === FRONTEND ===
    subgraph Frontend["Frontend"]
        WebApp["Next.js App<br/>Chat UI"]
        Proxy["API Proxy<br/>/api/redirect/{id}"]
    end

    %% === CLOUD RUN ===
    subgraph CloudRun["Cloud Run"]
        CustomServer["Custom Server<br/>custom_server.py"]
        ADK["ADK Agent<br/>Gemini 3 Flash"]
        MCP["MCP Toolbox<br/>49 tools"]
        Cache["URL Cache<br/>/r/{url_id}"]
        CustomServer --> ADK
        CustomServer --> Cache
        ADK <--> MCP
    end

    %% === VERTEX AI ===
    VertexAI["Vertex AI<br/>Gemini 3 Flash"]

    %% === BIGQUERY ===
    subgraph BigQuery["BigQuery"]
        BQ_READ[("datalake-gasco<br/>READ")]
        BQ_WRITE[("agent-intelligence-gasco<br/>WRITE")]
    end

    %% === CLOUD STORAGE ===
    subgraph GCS["Cloud Storage"]
        GCS_PDF[("miguel-test<br/>PDFs")]
        GCS_ZIP[("agent-intelligence-zips<br/>ZIPs")]
    end

    %% === CONEXIONES ===
    User -->|"Browser"| WebApp
    WebApp -->|"POST /run"| CustomServer
    ADK <-->|"LLM API"| VertexAI
    MCP -->|"SQL queries"| BQ_READ
    MCP -->|"ZIP records"| BQ_WRITE
    BQ_READ -.->|"gs:// paths"| GCS_PDF
    ADK -->|"Signed URLs"| GCS_PDF
    ADK -->|"Create ZIP"| GCS_ZIP
    ADK -->|"Store URL"| Cache
    Cache -->|"Redirect URLs"| WebApp
    Proxy -->|"Resolve /r/{id}"| Cache
    Cache -.->|"Signed URL"| User

    %% === ESTILOS ===
    classDef userStyle fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef cloudrunStyle fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
    classDef vertexStyle fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef bqStyle fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef gcsStyle fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef frontendStyle fill:#e0f2f1,stroke:#00695c,stroke-width:2px
    classDef cacheStyle fill:#f1f8e9,stroke:#33691e,stroke-width:2px

    class User userStyle
    class WebApp,Proxy frontendStyle
    class CustomServer,ADK,MCP cloudrunStyle
    class Cache cacheStyle
    class VertexAI vertexStyle
    class BQ_READ,BQ_WRITE bqStyle
    class GCS_PDF,GCS_ZIP gcsStyle
```

---

## Leyenda

| Servicio | Proyecto/Bucket | Proposito |
|----------|-----------------|-----------|
| **Frontend** | Next.js App | Chat UI + proxy de autenticacion |
| **Custom Server** | `custom_server.py` | FastAPI que extiende ADK con redirect |
| **ADK Agent** | `us-central1` | Agente conversacional con Gemini 3 Flash |
| **MCP Toolbox** | interno (port 5000) | 49 herramientas BigQuery |
| **URL Cache** | in-memory | Signed URLs con IDs cortos (8 chars) |
| **Vertex AI** | Gemini 3 Flash | Procesamiento lenguaje natural |
| **BigQuery READ** | `datalake-gasco` | Consulta facturas (produccion) |
| **BigQuery WRITE** | `agent-intelligence-gasco` | Operaciones ZIPs, logs, analytics |
| **GCS PDFs** | `miguel-test` | PDFs originales de facturas |
| **GCS ZIPs** | `agent-intelligence-zips` | Paquetes ZIP generados (TTL 7 dias) |

## Flujo de Descarga (Redirect URLs)

```
1. ADK genera signed URL para PDF
2. Signed URL se almacena en URL Cache → ID corto (8 chars)
3. Agente responde con redirect URL: /r/abc12345
4. Frontend muestra boton "Cedible" / "Tributaria"
5. Usuario hace clic → Frontend proxy /api/redirect/abc12345
6. Proxy llama backend /r/abc12345 con autenticacion
7. Backend resuelve signed URL desde cache
8. Usuario recibe el PDF
```
