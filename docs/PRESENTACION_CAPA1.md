# 📊 Presentación Capa 1 - Invoice Chatbot Backend

---

## 🏢 **option**

**Retail**

---

## **Sistema de Chatbot de Búsqueda de Facturas con IA**

--## 🎨 PROMPT PARA LEONARDO AI / STABLE DIFFUSION (Gasco Energy Sector)

```
Positive prompt:
corporate energy sector illustration, AI chatbot factura system for Chilean gas distribution company, navy blue and vibrant orange color palette, isometric 2.5D design, glowing chat interface bubble, holographic factura document with gas flame watermark, industrial database server with cyan data streams, secure cloud storage with shield lock, energy pipeline network background, hexagonal molecular patterns, LPG gas cylinder icons, neural network connections, glass morphism effects, gradient overlays, soft glowing lighting, professional B2B style, clean minimal composition, high quality render, detailed digital artwork, modern tech meets traditional energy industry, trustworthy corporate aesthetic, enterprise software visualization, Chilean business context, 167 years heritage company, floating UI elements, isometric perspective, vibrant gradients

Negative prompt:
people, human faces, portraits, characters, anime, cartoon style, hand-drawn sketch, messy composition, cluttered design, text labels, company logos, words, letters, numbers on image, photorealistic 3D render, low quality, blurry, pixelated, dark gloomy mood, residential/consumer products, generic tech startup aesthetic, purple colors, pink colors, lime green, neon colors, grunge style, vintage retro, overly complex, too many elements, distracting background
```

**Especificaciones Stable Diffusion/Leonardo**:

- **Modelo recomendado**: Leonardo Diffusion XL, SDXL 1.0, or DreamShaper
- **Sampler**: DPM++ 2M Karras o Euler a
- **Steps**: 40-50 (mayor calidad para presentaciones corporativas)
- **CFG Scale**: 7-9 (balance creatividad/coherencia)
- **Dimensiones**: 1024x1024 → upscale a 1920x1080, o directamente 1792x1024
- **Seed**: Experimental (probar múltiples variantes)
- **Alchemy/PhotoReal**: DESACTIVADO (queremos ilustración, no foto)
- **Prompt Magic**: V3 ACTIVADO (Leonardo AI)

**Keywords Críticos para Gasco**:
- "energy sector" + "gas distribution" (contexto industrial)
- "navy blue and vibrant orange" (paleta específica)
- "Chilean business context" (localización cultural)
- "167 years heritage" (tradición corporativa)
- "B2B style" (profesionalismo enterprise)
- Negativos anti-consumer: evitar estética residencial/casual🎯 **SOLUCIÓN**
Sistema de chatbot conversacional para búsqueda inteligente de facturas

---

### 💡 **DESAFÍO**
Optimizar la búsqueda y acceso a facturas históricas mediante IA conversacional

---

### 📋 **DESCRIPCIÓN**

El sistema de chatbot de facturas es una herramienta diseñada para hacer más eficiente el acceso a información de facturación mediante lenguaje natural. Usando IA generativa (Gemini) y el protocolo MCP (Model Context Protocol), el sistema permite a los usuarios buscar facturas conversacionalmente sin necesidad de conocer queries SQL o navegar interfaces complejas.

La solución integra **49 herramientas MCP validadas** que permiten búsquedas por fecha, RUT, solicitante SAP, monto, proveedor, y múltiples combinaciones. El sistema maneja **1.6M+ facturas históricas** (2017-2025) con acceso a PDFs firmados mediante signed URLs de Google Cloud Storage.

El backend ha sido construido con **arquitectura dual-project** para separación de datos (datalake-gasco para lectura, agent-intelligence-gasco para operaciones), cumpliendo con políticas de seguridad y gobernanza de datos. Incluye sistema completo de testing con **100% de cobertura** (46 tests locales + 46 tests Cloud Run), sistema de prevención de consultas masivas, y monitoreo completo con BigQuery Analytics.

**Métricas clave**:
- ✅ 49/49 herramientas MCP operacionales (100%)
- ✅ 1,614,688 facturas indexadas
- ✅ 100% tasa de éxito en tests de validación
- ✅ Sistema de 4 capas de testing (JSON, PowerShell, Curl, SQL)
- ✅ Performance optimizada 60% (reducción campos PDF)
- ✅ Dual deployment: Local (desarrollo) + Cloud Run (producción)

---

### 🔧 **SERVICIO**
Google ADK / MCP Toolbox / BigQuery / Cloud Storage / Cloud Run / Python

---

### 📦 **TIPO PROYECTO**
AI/ML Application / Conversational Interface / Backend API

---

### 💻 **TECNOLOGÍAS**
Python / Google Cloud Platform / ADK / BigQuery / Cloud Storage / Docker / MCP Protocol

---

### 👥 **EQUIPO**
AI/ML Engineers / Backend Developers / Cloud Engineers / DevOps

---

### 📸 **VISUAL**

## 🎨 PROMPT PARA GENERADOR DE IMÁGENES (DALL-E / Midjourney / Stable Diffusion)

### **Contexto del Cliente: Gasco (Empresa Energética Chilena)**
- **Sector**: Energía y gas (GLP/GN) desde 1856
- **Valores**: Confiabilidad, tradición, innovación, calidad
- **Aplicación**: Sistema de chatbot IA para búsqueda inteligente de facturas

```
Create a modern, professional technology illustration for an AI-powered factura chatbot system designed for GASCO, a Chilean energy distribution company with 167 years of history. The image should balance corporate tradition with cutting-edge AI technology, using an energy-sector inspired color palette.

**Color Palette (Energy Sector Corporate)**:
- Primary: Deep Navy Blue (#003C71) - Trust, professionalism, Gasco corporate
- Secondary: Vibrant Orange (#FF6B35) - Energy, gas flame, warmth
- Accent 1: Electric Cyan (#00D9FF) - Technology, innovation, digital
- Accent 2: Bright Green (#10B981) - Sustainability, efficiency, success
- Neutral: Slate Gray (#475569) - Industrial strength, stability

**Main Composition (Balanced Isometric Layout)**:
- **CENTER**: Large glowing chat bubble icon with AI neural network pattern inside, colored in navy blue gradient transitioning to electric cyan, representing the conversational AI interface
- **UPPER RIGHT**: Floating holographic factura/document icon with subtle gas flame symbol watermark, rendered in orange-to-cyan gradient with digital grid lines
- **LEFT SIDE**: Stylized industrial database/server stack with flowing data streams in cyan, representing BigQuery (1.6M+ facturas), with small gas cylinder icons floating around
- **LOWER RIGHT**: Secure cloud storage icon with shield and lock, showing stacked PDF documents, rendered in navy blue with green security indicators
- **BACKGROUND**: Abstract energy network grid with connecting nodes resembling gas distribution pipelines, neural network patterns, and subtle molecular structures suggesting LPG/natural gas

**Industry-Specific Elements**:
- Subtle gas flame icons integrated into the design (small, stylized)
- Pipeline/network connections between main elements (representing distribution logistics)
- Small floating icons: Chilean flag colors subtly incorporated, checkmarks (✓), magnifying glass (search), lightning bolt (⚡ performance), shield (🛡️ security), gas cylinder silhouettes
- Hexagonal patterns reminiscent of molecular structures (propane/butane molecules)
- Industrial-grade geometric shapes with clean edges

**Visual Style**:
- Corporate energy sector aesthetic (professional, trustworthy, robust)
- Modern flat design with isometric 2.5D depth and subtle industrial textures
- Glass morphism effect with frosted translucency on main elements
- Soft glowing effects suggesting both energy (warmth) and AI processing (cool tech)
- Balance between traditional industrial strength and modern digital innovation

**Style References**:
- Shell/BP/Chevron corporate presentation materials (energy sector professionalism)
- Google Cloud Platform marketing visuals (tech credibility)
- SAP/Oracle enterprise software illustrations (B2B sophistication)
- Clean, minimal design with industrial-grade robustness

**Technical Specifications**:
- Resolution: 1920x1080 (16:9 presentation format) or 1200x1200 (square)
- Format: PNG with alpha channel transparency
- Color mode: RGB, high contrast for projector visibility
- Style: Professional corporate illustration, suitable for executive presentations
- No text labels or company logos (visual metaphors and icons only)

**Mood & Message**:
- Trustworthy and reliable (167 years of energy service)
- Innovative and modern (cutting-edge AI technology)
- Efficient and powerful (streamlined factura search)
- Enterprise-grade quality (B2B energy sector standards)
- Chilean corporate professionalism with global tech standards
```

---

## 🎨 PROMPT ALTERNATIVO (Midjourney Optimizado - Gasco Energy Sector)

```
AI chatbot factura system for Chilean energy company, corporate navy blue and vibrant orange color scheme, isometric 2.5D perspective, glowing chat interface bubble with neural network patterns, floating holographic factura with gas flame watermark, industrial database server with cyan data streams, secure cloud storage with shield lock, energy distribution pipeline network background, hexagonal molecular patterns, gas cylinder icons, Chilean corporate aesthetic, professional energy sector style, glass morphism effects, soft glowing gradients, industrial-grade design, trustworthy and innovative mood, clean minimal composition, high tech meets traditional energy --ar 16:9 --style raw --v 6 --q 2
```

**Keywords Clave Gasco-Specific**:
- "Chilean energy company" (contexto geográfico e industria)
- "gas flame watermark" (identidad energética)
- "industrial database" (robustez B2B)
- "energy distribution pipeline network" (core business visual)
- "navy blue and vibrant orange" (paleta energética corporativa)
- "traditional energy meets high tech" (167 años + IA moderna)

---

## 🎨 PROMPT PARA DALL-E 3 (Narrativo - Gasco Energy Context)

```
Create a sleek, modern corporate illustration for an AI-powered factura management chatbot system designed for GASCO, a leading Chilean energy distribution company with 167 years of history in the gas sector. 

The composition features a central navy blue glowing chat interface bubble with intricate AI circuit patterns and neural network lines inside, symbolizing the conversational intelligence. 

Orbiting around it in an isometric layout: a vibrant orange holographic factura document with subtle gas flame watermark and flowing digital data streams; a robust teal-colored industrial database server icon with cyan connections representing 1.6 million factura records; and a secure cloud storage symbol in deep blue with a protective shield and lock showing stacked PDF documents with green security indicators.

The background displays an abstract energy distribution network grid resembling gas pipelines, with connecting nodes, hexagonal molecular patterns suggesting LPG molecules, and small stylized gas cylinder silhouettes floating subtly. 

Style: Professional corporate energy sector illustration with modern digital innovation elements, clean minimal design using navy blue (#003C71), vibrant orange (#FF6B35), electric cyan (#00D9FF), and bright green (#10B981) colors. Isometric 2.5D perspective with glass morphism aesthetic, soft glowing effects balancing warmth (energy) and coolness (technology), suitable for executive presentation in the Chilean B2B energy industry. No text labels or logos, only visual metaphors and icons.
```

**Características DALL-E 3 Optimizadas**:
- Narrativa descriptiva completa (DALL-E 3 prefiere lenguaje natural)
- Contexto explícito: "Chilean energy distribution company"
- Balance tradición/innovación: "167 years + AI-powered"
- Elementos específicos Gasco: gas flames, pipelines, LPG molecules
- Mood energético-profesional para sector B2B

---

## 🎨 PROMPT PARA GOOGLE IMAGEN 3 / ImageFX (Recomendado para Gasco)

```
Create a sophisticated corporate technology illustration for GASCO, Chile's historic energy distribution company (founded 1856). This is for an executive presentation showcasing their new AI-powered factura (invoice) search chatbot system.

Visual Concept:
Design a clean, professional isometric illustration that balances traditional industrial energy heritage with cutting-edge AI innovation. The composition should feel trustworthy, modern, and distinctly Chilean B2B energy sector.

Central Element:
A large, glowing conversational AI chat bubble in deep navy blue (#003C71) transitioning to electric cyan (#00D9FF), with visible neural network patterns and circuit lines inside, representing intelligent conversation.

Surrounding Elements (arranged in balanced isometric layout):
- Upper right: A floating holographic factura document rendered in vibrant orange (#FF6B35) gradient with a subtle stylized gas flame watermark, showing flowing digital data streams
- Left side: An industrial-grade database server stack in teal with cyan data streams, decorated with small floating LPG gas cylinder icons, representing 1.6 million invoice records in BigQuery
- Lower right: A secure cloud storage icon in navy blue with a bright green (#10B981) shield and lock, showing stacked PDF documents

Background & Atmosphere:
Abstract energy distribution network grid resembling gas pipelines connecting all elements, with hexagonal molecular patterns (propane/butane molecules), subtle Chilean flag color accents (red, white, blue), and a clean gradient background (white to light navy).

Additional Details:
Small floating icons: magnifying glass (search), lightning bolt (performance), checkmark (validation), shield (security), all in the corporate color palette. Include glass morphism effects with soft glows suggesting both energy warmth and digital coolness.

Style Direction:
Google Material Design meets corporate energy sector - clean, minimal, professional illustration with subtle industrial textures, isometric 2.5D depth, suitable for executive boardroom presentations. Similar aesthetic to Shell/BP/Chevron corporate materials combined with Google Cloud Platform visuals.

Technical Requirements:
16:9 aspect ratio (1920x1080), high contrast for projector visibility, PNG format, no text labels or company logos, only visual metaphors and abstract icons.

Color Palette (strict):
Navy Blue #003C71, Vibrant Orange #FF6B35, Electric Cyan #00D9FF, Bright Green #10B981, Slate Gray #475569, White background.

Mood: Trustworthy (167 years heritage) + Innovative (AI technology) + Efficient + Chilean corporate professionalism.
```

**Por qué Imagen 3 es ideal para este proyecto:**
- ✅ Excelente comprensión de conceptos corporativos complejos
- ✅ Genera ilustraciones limpias estilo Material Design (Google native)
- ✅ Maneja muy bien especificaciones de color hex
- ✅ Entiende contexto cultural (Chilean B2B energy sector)
- ✅ Produce imágenes de alta calidad para presentaciones ejecutivas
- ✅ Acceso gratuito vía Google AI Studio / ImageFX

**Cómo usar:**
1. Ir a [ImageFX](https://aitestkitchen.withgoogle.com/tools/image-fx) o Google AI Studio
2. Copiar el prompt completo
3. Generar 4-8 variantes
4. Seleccionar la mejor y descargar en alta resolución

---

## 🎨 PROMPT PARA LEONARDO AI / Stable Diffusion

```
Positive prompt:
corporate technology illustration, AI chatbot system, factura management, modern flat design, purple and cyan color palette, chat bubble interface, holographic document icons, database visualization, cloud storage, network connections, geometric patterns, hexagonal elements, isometric perspective, glass morphism, gradient overlays, glowing effects, professional style, high quality, detailed, vibrant colors, tech aesthetic, enterprise software, data flow visualization

Negative prompt:
people, faces, text, words, letters, numbers, logos, photorealistic, 3D render, low quality, blurry, messy, cluttered, dark, gloomy, hand-drawn, sketch, cartoon characters, anime style
```

---

## 📐 ESPECIFICACIONES TÉCNICAS (Actualizadas para Gasco)

**Dimensiones Recomendadas**:

- Presentación 16:9: 1920x1080 px
- Cuadrado (Instagram style): 1200x1200 px
- Vertical (Story style): 1080x1920 px

**Elementos Clave a Incluir (Gasco Energy Context)**:

1. 💬 Chat bubble (navy blue) - central con patrones IA
2. 📄 Factura/documento (orange gradient) - con watermark llama de gas
3. 🗄️ Database industrial (teal) - robusto, con cilindros de gas flotantes
4. ☁️ Cloud storage (deep blue) - con candado verde seguridad
5. 🔗 Pipeline network - conexiones energéticas tipo red distribución gas
6. 🔥 Gas flame icons - sutiles, integrados en diseño
7. ⚡ Iconografía secundaria - checkmarks, lightning, shield, molecular hexagons

**Colores Exactos (Paleta Energética Gasco)**:

- **Navy Blue Corporativo**: #003C71 (confianza, profesionalismo Gasco)
- **Vibrant Orange Energético**: #FF6B35 (llama gas, energía, calidez)
- **Electric Cyan Tecnológico**: #00D9FF (innovación digital, datos)
- **Bright Green Sustentabilidad**: #10B981 (eficiencia, éxito, seguridad)
- **Slate Gray Industrial**: #475569 (fortaleza, estabilidad)
- **Background**: White (#FFFFFF) o Deep Navy (#1E293B) para contraste

**Diferencias vs. Paleta Option Original**:

- ❌ Eliminado: Purple #7B2CBF (reemplazado por Navy Blue corporativo)
- ✅ Agregado: Vibrant Orange #FF6B35 (identidad sector energético)
- ✅ Mantenido: Cyan #00D9FF (tecnología universal)
- ✅ Modificado: Verde más brillante para mejor visibilidad

**Mood y Valores Gasco**:

- Confiabilidad (167 años de historia energética)
- Innovación (IA conversacional cutting-edge)
- Profesionalismo B2B (sector industrial/comercial)
- Tradición + Modernidad (balanceado)

---

```
[Factura Chatbot Architecture - Diagrama ASCII de respaldo]
┌─────────────────────────────────────┐
│   Frontend (Conversational UI)     │
│   "dame facturas de julio 2025"    │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│   ADK Agent (localhost:8001)        │
│   Google Gemini + Function Calling  │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│   MCP Toolbox (49 herramientas)     │
│   BigQuery Queries + GCS URLs       │
└──────────────┬──────────────────────┘
               │
         ┌─────┴─────┐
         ↓           ↓
┌─────────────┐ ┌──────────────┐
│  BigQuery   │ │ Cloud Storage│
│ (1.6M rows) │ │  (Signed URLs)│
└─────────────┘ └──────────────┘

Testing: 46 tests × 2 environments = 92 validations
```

---

### 🏆 **LOGROS RECIENTES**

**Sistema de Testing Completo (Oct 2025)**:
- 4 capas de validación implementadas
- 100% cobertura de 49 herramientas MCP
- Tests duales: Local + Cloud Run
- 3 bugs críticos identificados y resueltos
- Documentación técnica completa

**Optimizaciones de Performance**:
- 60% reducción en tamaño de respuestas (filtrado PDF)
- Sistema de prevención de queries masivas
- Token validation system (250 tokens/factura)
- Timeouts extendidos para consultas complejas

**Production Ready**:
- Deployment en Cloud Run validado
- Sistema de signed URLs estable
- Analytics y logging completo en BigQuery
- Backward compatibility garantizada

---

**Propiedad de Option, área Knowledge Management**

---

## 📄 Formato Presentación

Para crear la diapositiva visual en PowerPoint/Google Slides:

1. **Header**: Logo Option + tag "Retail" (esquina superior derecha, fondo morado)
2. **Título Principal**: "Sistema de Chatbot de Búsqueda de Facturas con IA"
3. **Sección Izquierda**: Tabla con campos (SOLUCIÓN, DESAFÍO, DESCRIPCIÓN, SERVICIO, TIPO PROYECTO, TECNOLOGÍAS, EQUIPO)
4. **Sección Derecha**: Visual del diagrama de arquitectura + iconos representativos
5. **Footer**: "Propiedad de Option, área Knowledge Management" + logo

### 🎨 Paleta de Colores Sugerida
- **Morado Option**: #7B2CBF (header)
- **Verde Success**: #10B981 (métricas positivas)
- **Azul Tech**: #3B82F6 (componentes técnicos)
- **Gris Texto**: #4B5563 (descripción)

### 📊 Iconos Sugeridos
- 💬 Chatbot conversacional
- 📄 Facturas/documentos
- ⚡ Performance/velocidad
- ✅ Tests/validación
- ☁️ Cloud infrastructure
- 🔐 Seguridad/gobernanza

---

## 📎 Archivos de Referencia

Para completar la presentación, consulta:
- `DEBUGGING_CONTEXT.md` - Historial técnico completo
- `TEST_EXECUTION_RESULTS.md` - Métricas de testing
- `TESTING_COVERAGE_INVENTORY.md` - Cobertura de herramientas
- `README.md` - Overview del proyecto
- `tests/local/README.md` - Tests locales
- `tests/cloudrun/README.md` - Tests Cloud Run

---

**Última actualización**: 3 de octubre de 2025
**Branch**: feature/pdf-type-filter
**Estado**: Production Ready ✅
