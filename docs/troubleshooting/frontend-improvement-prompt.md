# GitHub Copilot Prompt: Adaptación del Frontend Existente para URLs Firmadas

## Contexto del Proyecto
Tengo un chatbot de facturas con frontend **YA IMPLEMENTADO** que funciona correctamente. Acabo de actualizar el backend para generar **URLs firmadas de Google Cloud Storage** en lugar de URLs proxy problemáticas. Necesito **ADAPTAR mi código frontend existente** para manejar correctamente estos nuevos formatos de respuesta sin romper la funcionalidad actual.

## CAMBIOS EN EL FORMATO DE RESPUESTA

### Formato ANTERIOR (que mi frontend maneja):
```
[Respuesta más simple con URLs proxy o básicas]
```

### Formato NUEVO (que necesito adaptar):
```markdown
Se encontraron X facturas para [criterio]. Período: [fechas].

[PARA MÚLTIPLES FACTURAS: URL ZIP FIRMADA]
Puedes descargar todas las facturas en un único archivo ZIP aquí: [Descargar ZIP](https://storage.googleapis.com/agent-intelligence-zips/zip_xxx.zip?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=...&X-Goog-Date=...&X-Goog-Expires=3599...)

---

📋 **Factura 0104298528** (2023-12-26)
👤 **Cliente:** DANIEL ANGEL GARCIA ROJAS (RUT: 14679681-8)
💰 **Valor Total:** $63.863 CLP
📁 **Documentos disponibles:**
• **Copia Cedible con Firma:** [Descargar PDF](https://storage.googleapis.com/miguel-test/descargas/0104298528/Copia_Cedible_cf.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=...&X-Goog-Date=...&X-Goog-Expires=3599...)
• **Copia Cedible sin Firma:** [Descargar PDF](https://storage.googleapis.com/miguel-test/descargas/0104298528/Copia_Cedible_sf.pdf?X-Goog-Algorithm=...)
• **Copia Tributaria con Firma:** [Descargar PDF](https://storage.googleapis.com/miguel-test/descargas/0104298528/Copia_Tributaria_cf.pdf?X-Goog-Algorithm=...)
• **Copia Tributaria sin Firma:** [Descargar PDF](https://storage.googleapis.com/miguel-test/descargas/0104298528/Copia_Tributaria_sf.pdf?X-Goog-Algorithm=...)
• **Documento Térmico:** [Descargar PDF](https://storage.googleapis.com/miguel-test/descargas/0104298528/Doc_Termico.pdf?X-Goog-Algorithm=...)
```

## Tipos de URLs Identificadas

### 1. URLs Firmadas Válidas ✅
- **Patrón**: `https://storage.googleapis.com/miguel-test/...?X-Goog-Algorithm=GOOG4-RSA-SHA256`
- **Características**: Incluye parámetros de firma (`X-Goog-Algorithm`, `X-Goog-Credential`, `X-Goog-Date`, `X-Goog-Expires`)
- **Acción**: Enlace directo - funcionan perfectamente
- **Expiración**: 3599 segundos (1 hora)

### 2. URLs ZIP Firmadas ✅
- **Patrón**: `https://storage.googleapis.com/agent-intelligence-zips/zip_xxx.zip?X-Goog-Algorithm=...`
- **Uso**: Para descargas múltiples (más de 5-10 facturas)
- **Acción**: Enlace directo con icono especial de ZIP

### 3. URLs gs:// Legacy ⚠️
- **Patrón**: `gs://miguel-test/descargas/.../file.pdf`
- **Problema**: No funcionan directamente en navegadores
- **Acción**: Convertir a URL firmada o mostrar error

## PROBLEMAS A RESOLVER EN MI CÓDIGO EXISTENTE

### 1. Parser de Enlaces
- **Problema**: Mi parser actual no reconoce URLs firmadas con parámetros `X-Goog-Algorithm`
- **Necesito**: Actualizar regex/lógica para detectar enlaces firmados vs legacy

### 2. Detección de URLs ZIP
- **Problema**: Mi código no detecta ni maneja URLs de ZIP para descargas masivas
- **Necesito**: Lógica para detectar `agent-intelligence-zips` y mostrar botón especial

### 3. Manejo de URLs gs://
- **Problema**: Algunas respuestas aún pueden contener URLs `gs://` que no funcionan en navegador
- **Necesito**: Fallback o conversión para estas URLs problemáticas

### 4. Parsing del Formato Markdown Actualizado
- **Problema**: El nuevo formato tiene más estructura (emojis, separadores, formato más rico)
- **Necesito**: Actualizar parser para extraer correctamente la información

## ADAPTACIONES NECESARIAS

### Necesito modificar mi código existente para:

1. **Actualizar Parser de URLs**:
   ```typescript
   // CÓDIGO ACTUAL (ejemplo):
   function extractPDFLinks(response: string) {
     // Lógica actual que no maneja URLs firmadas
   }
   
   // NECESITO ADAPTAR PARA:
   // - Detectar URLs con X-Goog-Algorithm
   // - Identificar URLs ZIP
   // - Manejar URLs gs:// legacy
   ```

2. **Modificar Componente de Enlaces**:
   ```typescript
   // MI COMPONENTE ACTUAL:
   const DownloadLink = ({ url, title }) => {
     // Lógica actual
   };
   
   // NECESITO ADAPTAR PARA:
   // - Mostrar iconos diferentes para ZIP vs PDF
   // - Manejar URLs firmadas directamente
   // - Detectar URLs expiradas
   ```

3. **Actualizar Parser de Respuestas**:
   ```typescript
   // MI PARSER ACTUAL:
   function parseInvoiceResponse(response: string) {
     // Parsing del formato anterior
   }
   
   // NECESITO ADAPTAR PARA:
   // - Nuevo formato con emojis y estructura
   // - Detectar URLs ZIP al inicio
   // - Manejar separadores "---"
   ```

## COMPATIBILIDAD REQUERIDA

- ✅ **Mantener compatibilidad** con formato anterior (por si hay respuestas legacy)
- ✅ **No romper** funcionalidad existente
- ✅ **Detectar automáticamente** qué formato está usando la respuesta
- ✅ **Mejorar UX** para aprovechar las nuevas URLs firmadas

## CASOS DE MIGRACIÓN

1. **URLs Legacy → URLs Firmadas**: Detección automática y manejo directo
2. **Respuestas Simples → Respuestas con ZIP**: Mostrar botón de descarga masiva
3. **Enlaces Rotos gs:// → Enlaces Funcionando**: Conversión o error graceful

## Ejemplos de Código Esperados

### 1. Función de Detección de Tipo de URL:
```typescript
type URLType = 'signed' | 'zip' | 'gs' | 'unknown';

function detectURLType(url: string): URLType {
  // Implementar lógica de detección
}
```

### 2. Componente de Enlace Inteligente:
```tsx
interface SmartLinkProps {
  url: string;
  fileName: string;
  documentType: string;
}

const SmartLink: React.FC<SmartLinkProps> = ({ url, fileName, documentType }) => {
  // Implementar componente que detecte tipo y renderice apropiadamente
};
```

### 3. Parser de Respuesta de Facturas:
```typescript
interface InvoiceResponse {
  totalFound: number;
  period: string;
  zipUrl?: string;
  invoices: Array<{
    number: string;
    date: string;
    client: string;
    rut: string;
    amount: string;
    documents: Array<{
      type: string;
      url: string;
    }>;
  }>;
}

function parseInvoiceResponse(markdownResponse: string): InvoiceResponse {
  // Implementar parser del formato markdown
}
```

## Casos de Uso Específicos

1. **Usuario hace consulta → Una factura**:
   - Mostrar datos de factura + enlaces directos a PDFs firmados

2. **Usuario hace consulta → Múltiples facturas**:
   - Mostrar botón de descarga ZIP prominente
   - Lista de facturas individuales con enlaces directos

3. **Usuario hace clic en enlace expirado**:
   - Detectar error 403/expired
   - Mostrar mensaje "Regenerando enlace..." 
   - Solicitar nueva URL firmada al backend

## Tecnologías del Proyecto
- Frontend: React + TypeScript
- Estilos: Tailwind CSS / Material-UI
- Estado: Redux/Zustand
- Backend: Express.js con endpoints ADK

## Objetivos de Rendimiento
- Enlaces directos para descarga inmediata
- Detección automática de tipo de URL
- UI responsiva y intuitiva
- Manejo graceful de errores

---

**Prompt Principal para GitHub Copilot**: 

"Tengo un frontend de chatbot de facturas funcionando que necesito ADAPTAR para el nuevo formato de respuestas del backend con URLs firmadas. Ayúdame a MODIFICAR mi código existente para manejar estos cambios sin romper la funcionalidad actual. Prioriza la compatibilidad hacia atrás y la detección automática del formato de respuesta."

**Prompts Específicos de Seguimiento**:

1. **Para Parser**: "Modifica mi función parseInvoiceResponse existente para manejar tanto el formato anterior como el nuevo con URLs firmadas"

2. **Para Enlaces**: "Actualiza mi componente DownloadLink para detectar y manejar URLs firmadas, ZIP y gs:// automáticamente"

3. **Para Compatibilidad**: "Agrega detección automática de formato de respuesta para mantener compatibilidad con respuestas legacy"