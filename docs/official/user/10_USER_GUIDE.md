#  Guía de Usuario - Sistema de Chatbot de Facturas Gasco

**Proyecto**: Invoice Chatbot Backend  
**Cliente**: Gasco  
**Versión**: 1.0  
**Fecha**: Octubre 2025  
**Audiencia**: Usuarios finales

---

##  Introducción

Bienvenido al **Sistema de Chatbot de Facturas Gasco**, una herramienta de inteligencia artificial que te permite buscar y descargar facturas usando lenguaje natural conversacional.

### ¿Qué puedo hacer con este sistema?

-  **Buscar facturas** por múltiples criterios (SAP, RUT, fecha, empresa, folio)
-  **Descargar PDFs** de manera individual o en archivos ZIP
-  **Obtener estadísticas** sobre facturas y clientes
-  **Consultar por períodos** específicos o rangos de fechas
-  **Analizar facturas** por monto, cliente, solicitante
-  **Acceder a múltiples versiones** de documentos (CF/SF, Tributaria/Cedible)

---

##  Cómo Hablar con el Chatbot

### Lenguaje Natural

El sistema entiende **español conversacional**. No necesitas memorizar comandos específicos.

**Ejemplos válidos**:
- *"dame la factura del SAP 12537749 para agosto 2025"*
- *"facturas de COMERCIALIZADORA PIMENTEL octubre 2023"*
- *"cuál es la factura de mayor monto del solicitante X en septiembre"*
- *"muéstrame las últimas 10 facturas"*
- *"estadísticas de facturas por año"*

### Variaciones Aceptadas

El sistema es **flexible** y entiende diferentes formas de pedir lo mismo:

| Lo que quieres | Puedes decir |
|----------------|--------------|
| Buscar por código | "SAP 12345", "código solicitante 12345", "solicitante 12345" |
| Buscar por fecha | "agosto 2025", "mes de julio", "julio de 2024", "facturas recientes" |
| Buscar por empresa | "cliente X", "empresa Y", "facturas de Z" |
| Descargar documentos | "dame los PDFs", "quiero descargar", "necesito las facturas" |

---

##  Tipos de Búsqueda

### 1. Búsqueda por Código SAP/Solicitante 

El **código SAP** (también llamado "código solicitante") identifica una unidad de negocio específica.

#### ¿Cómo buscar?

```
"dame la factura del SAP 12537749 para agosto 2025"
"facturas del código solicitante 12141289 en septiembre"
"para el solicitante 12537749 traeme todas las facturas"
```

#### ¿Qué necesito saber?

- **Formato del código**: Puedes escribir `12537749` o `0012537749`
  - El sistema **normaliza automáticamente** con ceros a la izquierda
- **Con fecha**: Especifica mes y año para resultados precisos
- **Sin fecha**: Obtendrás todas las facturas históricas de ese código

#### Ejemplo Real

**Consulta**: *"dame la factura del siguiente sap, para agosto 2025 - 12537749"*

**Resultado esperado**:
```
📋 Factura 0105481293 (2025-08-30)
👤 Cliente: CENTRAL GAS SPA (RUT: 76747198-K)
 Valor Total: $568,805 CLP
📁 Documentos disponibles:
• Copia Cedible con Fondo: [Enlace] (con logo Gasco)
• Copia Tributaria con Fondo: [Enlace] (con logo Gasco)
```

---

### 2. Búsqueda por RUT de Cliente 

Busca facturas asociadas a un RUT específico de cliente.

#### ¿Cómo buscar?

```
"facturas del RUT 96568740-8"
"dame facturas del RUT 9025012-4"
"buscar por RUT 76341146-K"
```

#### ¿Qué necesito saber?

- **Formato**: Incluye el guión (ej: `96568740-8`)
- **Múltiples resultados**: Un RUT puede tener muchas facturas
- **Descubrimiento de códigos SAP**: Puedes preguntar qué códigos SAP pertenecen a un RUT

#### Consulta Útil

**Pregunta**: *"qué solicitantes pertenecen al RUT 96568740-8"*

**Obtendrás**:
- Lista de códigos SAP asociados a ese RUT
- Cantidad de facturas por cada código
- Rango de fechas disponibles

---

### 3. Búsqueda por Empresa/Cliente 

Busca por nombre de empresa (parcial o completo).

#### ¿Cómo buscar?

```
"facturas de COMERCIALIZADORA PIMENTEL"
"facturas del cliente Agrosuper"
"dame las facturas de Gas Las Naciones para julio 2025"
```

#### ¿Qué necesito saber?

- **Búsqueda parcial**: No necesitas el nombre completo exacto
- **Case-insensitive**: Mayúsculas/minúsculas no importan
- **Con fecha específica**: Más preciso si agregas mes/año

#### Ejemplo Completo

**Consulta**: *"dame las facturas del solicitante gas las naciones, para julio 2025"*

El sistema:
1. Busca por nombre parcial "gas las naciones"
2. Filtra por julio 2025
3. Retorna facturas ordenadas por fecha

---

### 4. Búsqueda por Fecha/Período 

Busca facturas en rangos temporales específicos.

#### ¿Cómo buscar?

**Mes específico**:
```
"dame las facturas de Julio 2025"
"facturas de octubre 2024"
"facturas del mes de diciembre 2019"
```

**Rango de fechas**:
```
"facturas entre diciembre 1 y 31 de 2019"
"facturas desde enero hasta marzo 2024"
```

**Facturas recientes**:
```
"últimas 10 facturas"
"facturas más recientes"
"dame las 20 facturas más nuevas"
```

#### ¿Qué necesito saber?

- **Mapeo de meses**: El sistema entiende meses en español
  - Enero=1, Febrero=2, Marzo=3... Diciembre=12
- **Año por defecto**: Si no especificas año, usa el año actual
- **Orden descendente**: Las facturas recientes se ordenan de más nueva a más antigua

####  Nota sobre Búsquedas Mensuales Grandes

Si pides facturas de un mes completo (ej: "facturas de julio 2025") que contenga muchas facturas (>50):

- **Formato resumido**: Recibirás un listado limpio sin detalles individuales
- **Descarga ZIP**: Se generará automáticamente un archivo ZIP con todos los PDFs
- **Validación preventiva**: El sistema validará que la consulta no exceda límites

---

### 5. Búsqueda por Folio/Referencia 

El **folio** (también llamado "factura referencia") es el número visible en la factura impresa.

#### ¿Cómo buscar?

```
"folio número 123456"
"referencia 8677072"
"factura referencia ABC123"
"buscar por folio 789"
```

#### ¿Qué necesito saber?

- **Diferencia crítica**:
  - **Factura**: ID interno del sistema
  - **Folio/Referencia**: Número visible en el documento impreso
- **Búsqueda específica**: Generalmente retorna 1 resultado exacto
- **Casos de uso**: Útil para notas de crédito/débito o correcciones

---

### 6. Búsqueda Financiera por Mayor Monto 

Busca la factura de mayor valor en un período específico para un solicitante.

#### ¿Cómo buscar?

```
"del solicitante 0012141289 para el mes de septiembre, cual es la factura de mayor monto"
"SAP 12345 en julio 2024, factura más cara"
"factura más costosa del solicitante X en agosto"
"código 12141289 en septiembre, factura de mayor valor"
```

#### ¿Qué necesito saber?

- **Requiere**:
  - Código SAP/solicitante
  - Mes específico
  - Opcionalmente año (usa año actual si no se especifica)
- **Resultado**: Una sola factura (la de mayor monto)
- **Uso**: Análisis financiero, identificación de transacciones grandes

#### Ejemplo Real

**Consulta**: *"del solicitante 0012141289 (GASCO GLP S.A. MAIPU), para el mes de septiembre, cual es la factura de mayor monto"*

**Resultado**:
```
📋 Se encontró la factura de mayor monto para el solicitante 0012141289 en septiembre 2025:

Factura [NÚMERO] 
 Valor máximo: $[MONTO] CLP
Cliente: GASCO GLP S.A. (MAIPU)
Fecha: [FECHA]
```

---

### 7. Búsqueda con Monto Mínimo 💵

Filtra facturas por un valor mínimo específico.

#### ¿Cómo buscar?

```
"facturas del RUT X con monto superior a 1000000"
"facturas mayores a 500000 pesos"
"buscar facturas con valor mínimo de 2 millones"
```

#### ¿Qué necesito saber?

- **Monto en pesos chilenos (CLP)**
- **Formato**: Puedes usar números con o sin separadores de miles
- **Combinable**: Funciona con RUT, fecha, empresa

---

##  Consultas de Estadísticas

### Estadísticas de RUTs Únicos

**Consulta**: *"dame estadísticas de RUTs únicos"*

**Obtendrás**:
- Total de RUTs distintos en el sistema
- Cantidad de facturas por RUT
- Rango temporal de facturas por RUT
- Cobertura temporal del dataset completo

### Estadísticas Anuales

**Consulta**: *"cuántas facturas corresponden a cada año"* o *"desglose anual de facturas"*

**Obtendrás**:
```
 Desglose de facturas por año:
• Año 2017: 234 facturas (3.5% del total)
• Año 2018: 567 facturas (8.5% del total)
...
• Año 2025: 890 facturas (13.4% del total)
 Total verificado: 6,641 facturas
```

### Estadísticas Mensuales

**Consulta**: *"cuántas facturas tienes por mes durante 2025"*

**Obtendrás**:
```
 Estadísticas mensuales para 2025:
• Enero: 123 facturas
• Febrero: 145 facturas
• Marzo: 167 facturas
...
 Total año 2025: 1,234 facturas
```

---

##  Descarga de Documentos

### Tipos de Documentos Disponibles

Cada factura puede tener hasta **5 tipos de PDFs**:

| Tipo de Documento | Código | Descripción |
|-------------------|--------|-------------|
| **Copia Tributaria Con Fondo (CF)** | `Copia_Tributaria_cf` | Con logo de Gasco en el fondo |
| **Copia Tributaria Sin Fondo (SF)** | `Copia_Tributaria_sf` | Sin logo de Gasco |
| **Copia Cedible Con Fondo (CF)** | `Copia_Cedible_cf` | Con logo de Gasco en el fondo |
| **Copia Cedible Sin Fondo (SF)** | `Copia_Cedible_sf` | Sin logo de Gasco |
| **Documento Térmico** | `Doc_termico` | Versión para impresión térmica |

### Documentos por Defecto

**Por defecto**, el sistema entrega **2 tipos de PDF**:
-  Copia Tributaria Con Fondo (CF)
-  Copia Cedible Con Fondo (CF)

### Solicitar Tipos Específicos

Si necesitas otras versiones, especifícalo en tu consulta:

```
"dame las facturas tributarias sin fondo"
"necesito copias cedibles sin fondo"
"quiero documentos térmicos"
"dame todas las versiones de PDFs"
```

El sistema usará herramientas especializadas:
- `get_tributaria_sf_pdfs`: Tributarias sin fondo
- `get_cedible_sf_pdfs`: Cedibles sin fondo
- `get_doc_termico_pdfs`: Documentos térmicos

### Terminología: CF/SF

 **Importante**: 
- **CF** = **Con Fondo** (logo Gasco de fondo)
- **SF** = **Sin Fondo** (sin logo)

 **NO significa** "con firma" o "sin firma"

---

##  Formatos de Descarga

### Descargas Individuales (≤3 facturas)

Cuando encuentres **3 o menos facturas**, recibirás:

```
📋 Factura 0105481293 (2025-08-30)
👤 Cliente: CENTRAL GAS SPA (RUT: 76747198-K)
 Valor Total: $568,805 CLP
📁 Documentos disponibles:
• Copia Cedible con Fondo: [Enlace firmado] (con logo Gasco)
• Copia Tributaria con Fondo: [Enlace firmado] (con logo Gasco)
```

**Enlaces individuales** para cada documento.

### Descarga en ZIP (>3 facturas)

Cuando encuentres **más de 3 facturas**, recibirás:

```
 24 facturas encontradas (período: 2025-07-01 - 2025-07-31)

📋 Listado de facturas:
• Factura 0105481293 - CENTRAL GAS SPA (RUT: 76747198-K) - Fecha: 2025-07-30
• Factura 0105481294 - AGROSUPER (RUT: 96568740-8) - Fecha: 2025-07-29
... (22 facturas más)

 Descarga completa:
🔗 [Descargar ZIP con todas las facturas](URL_ZIP)

El archivo ZIP contiene todos los documentos disponibles de las 24 facturas encontradas.
```

**Un solo archivo ZIP** que contiene todos los PDFs.

### URLs Firmadas

Todos los enlaces de descarga son **URLs firmadas** con:
-  **Seguridad**: Acceso temporal controlado
-  **Expiración**: 24 horas de validez
-  **Sin autenticación adicional**: Solo necesitas el enlace

---

##  Ejemplos Prácticos de Uso

### Caso 1: Buscar Factura Específica por SAP y Fecha

**Situación**: Necesitas la factura del código SAP 12537749 para agosto 2025.

**Consulta**:
```
"dame la factura del SAP 12537749 para agosto 2025"
```

**Resultado**:
- Factura específica con detalles completos
- Enlaces de descarga individuales
- Cliente, RUT, monto, fecha

---

### Caso 2: Todas las Facturas de un Mes

**Situación**: Necesitas todas las facturas de julio 2025 para contabilidad.

**Consulta**:
```
"dame las facturas de julio 2025"
```

**Resultado**:
- El sistema valida que la consulta no exceda límites
- Si hay >50 facturas: formato resumido
- Archivo ZIP automático con todos los PDFs

---

### Caso 3: Última Factura de un SAP

**Situación**: Necesitas la factura más reciente de un código específico.

**Consulta**:
```
"para el solicitante 12540245 dame la última factura"
```

**Resultado**:
- Solo la factura más reciente (aunque haya más)
- Ordenada por fecha descendente
- Mención explícita de "la más reciente"

---

### Caso 4: Descubrir Códigos SAP de un Cliente

**Situación**: Conoces el RUT pero no los códigos SAP asociados.

**Consulta**:
```
"qué solicitantes pertenecen al RUT 96568740-8"
```

**Resultado**:
```
 Códigos solicitantes para RUT 96568740-8:

1. Código: 0012537749
   • Total facturas: 45
   • Período: 2020-03-15 hasta 2025-08-30
   • Cliente: CENTRAL GAS SPA

2. Código: 0012540245
   • Total facturas: 23
   • Período: 2021-01-10 hasta 2025-09-15
   • Cliente: CENTRAL GAS SPA
```

---

### Caso 5: Análisis Financiero - Mayor Monto

**Situación**: Necesitas identificar la factura de mayor valor de un solicitante en un mes.

**Consulta**:
```
"del solicitante 0012141289 para el mes de septiembre, cual es la factura de mayor monto"
```

**Resultado**:
- Una sola factura (la de mayor monto)
- Detalle financiero completo
- Cliente, fecha, monto exacto

---

### Caso 6: Búsqueda por Folio/Referencia

**Situación**: Tienes el número de folio impreso en una factura física.

**Consulta**:
```
"folio número 8677072"
```

**Resultado**:
- Factura exacta asociada a ese folio
- Todos los detalles y PDFs disponibles

---

### Caso 7: Facturas Recientes del Sistema

**Situación**: Necesitas ver las últimas facturas ingresadas.

**Consulta**:
```
"dame las últimas 10 facturas"
```

**Resultado**:
- 10 facturas más recientes
- Ordenadas por fecha descendente
- Mención explícita del orden temporal

---

### Caso 8: Estadísticas Mensuales de un Año

**Situación**: Necesitas un reporte mensual de 2025.

**Consulta**:
```
"cuántas facturas tienes por mes durante 2025"
```

**Resultado**:
```
 Estadísticas mensuales para 2025:
• Enero: 123 facturas
• Febrero: 145 facturas
• Marzo: 167 facturas
• Abril: 134 facturas
• Mayo: 156 facturas
• Junio: 178 facturas
• Julio: 189 facturas
• Agosto: 201 facturas
• Septiembre: 167 facturas
 Total año 2025: 1,500 facturas
```

---

##  Terminología Clave

### SAP vs Código Solicitante

- **SAP** = **Código Solicitante** (sinónimos)
- Identificador de 10 dígitos (ej: `0012537749`)
- Identifica una unidad de negocio específica
- Puede tener ceros a la izquierda (normalización automática)

### Factura vs Factura Referencia (Folio)

| Término | Campo en Sistema | Descripción |
|---------|------------------|-------------|
| **Factura** | `Factura` | ID interno del sistema |
| **Factura Referencia (Folio)** | `Factura_Referencia` | Número visible en la factura impresa |

### CF/SF: Con Fondo / Sin Fondo

- **CF (Con Fondo)**: Documento con logo de Gasco en el fondo
- **SF (Sin Fondo)**: Documento sin logo de Gasco
-  **NO confundir** con "con firma" o "sin firma"

### Tipos de Documentos

1. **Copia Tributaria**: Versión fiscal del documento
2. **Copia Cedible**: Versión negociable del documento
3. **Documento Térmico**: Versión para impresión térmica

---

##  Notas Importantes

### Límites de Contexto

Para consultas muy grandes (ej: "facturas de julio 2025" con >200 resultados):

1. **El sistema validará primero** si la consulta excede límites
2. **Si excede**: Te pedirá refinar la búsqueda
   - Ejemplo: Especifica un SAP, RUT o empresa
3. **Recomendación automática**: El sistema sugiere filtros específicos

### Formato de Respuestas

**Formato Detallado** (≤3 facturas):
- Detalles completos de cada factura
- Enlaces individuales por documento
- Cliente, RUT, monto, fecha

**Formato Resumido** (>3 facturas):
- Lista limpia de facturas sin detalles extensos
- Un solo archivo ZIP con todos los PDFs
- Resumen ejecutivo (cantidad, período)

### Validez de Enlaces

- **URLs firmadas**: Válidas por 24 horas
- **Después de 24h**: Solicita nuevamente los documentos
- **Sin límite de descargas**: Usa el enlace cuantas veces necesites durante su validez

### Año por Defecto

Si NO especificas año en tu consulta:
- El sistema usa el **año actual** automáticamente
- Ejemplo: "facturas de septiembre" → septiembre del año actual

---

##  Consejos de Uso Efectivo

### 1. Sé Específico para Mejores Resultados

 **Bueno**: *"dame facturas del SAP 12537749 para agosto 2025"*  
 **Menos preciso**: *"dame facturas de agosto"*

### 2. Combina Múltiples Filtros

Puedes combinar:
- SAP + Fecha
- RUT + Rango de fechas
- Empresa + Mes/Año
- RUT + Monto mínimo

### 3. Usa Nombres Parciales

No necesitas el nombre completo exacto de empresas:
- "Agrosuper" funciona igual que "AGROSUPER S.A."
- "Gas Naciones" encuentra "GAS LAS NACIONES S.A."

### 4. Aprovecha las Estadísticas

Antes de buscar facturas específicas:
1. Pregunta estadísticas para conocer el dataset
2. Descubre códigos SAP asociados a RUTs
3. Analiza distribución temporal

### 5. Refina Búsquedas Grandes

Si una consulta retorna muchos resultados:
- Agrega filtro de fecha más específico
- Usa código SAP en lugar de solo empresa
- Especifica RUT para mayor precisión

---

##  Soporte y Ayuda

### ¿Tienes Problemas?

**Si el sistema no encuentra facturas**:
1. Verifica el formato del SAP (normalización automática)
2. Confirma que la fecha existe en el período 2017-2025
3. Prueba con nombres parciales de empresas

**Si los enlaces no funcionan**:
1. Verifica que no hayan pasado 24 horas
2. Solicita nuevamente los documentos
3. Contacta soporte técnico si persiste

### Contacto de Soporte

- **Email**: soporte-tech@option.cl
- **Nivel de soporte**: L1, L2, L3 disponibles
- **Horario**: Lunes a Viernes 9:00-18:00

---

##  Recursos Adicionales

### Documentación Relacionada

-  **Executive Summary**: `docs/official/executive/00_EXECUTIVE_SUMMARY.md`
-  **Architecture**: `docs/official/architecture/20_SYSTEM_ARCHITECTURE.md`
-  **Deployment Guide**: `docs/official/deployment/40_DEPLOYMENT_GUIDE.md`
-  **Operations Guide**: `docs/official/operations/50_OPERATIONS_GUIDE.md`

### Datasets Disponibles

| Métrica | Valor |
|---------|-------|
| Total de facturas | 6,641 |
| Período temporal | 2017-2025 |
| RUTs únicos | 1,234 |
| Códigos SAP únicos | 567 |

---

##  Checklist de Primeros Pasos

Para nuevos usuarios:

- [ ] Prueba una búsqueda simple por SAP
- [ ] Descarga una factura individual
- [ ] Solicita estadísticas anuales
- [ ] Descubre códigos SAP de un RUT conocido
- [ ] Prueba una búsqueda mensual completa
- [ ] Descarga un archivo ZIP de múltiples facturas
- [ ] Prueba búsqueda por empresa + fecha
- [ ] Solicita la factura de mayor monto de un período

---

## 📝 Preguntas Frecuentes (FAQ)

### ¿Cuántas facturas tiene el sistema?

**R**: El sistema tiene **6,641 facturas** del período 2017-2025.

### ¿Puedo buscar facturas de cualquier año?

**R**: Sí, desde 2017 hasta 2025 (datos actuales).

### ¿Cuánto tiempo son válidos los enlaces de descarga?

**R**: 24 horas desde su generación.

### ¿Puedo descargar todas las facturas de un mes?

**R**: Sí, el sistema generará automáticamente un archivo ZIP si hay más de 3 facturas.

### ¿Qué hago si no conozco el código SAP?

**R**: Pregunta por el RUT del cliente: *"qué solicitantes pertenecen al RUT X"*

### ¿Por qué no encuentro facturas de un SAP específico?

**R**: Verifica:
1. El código SAP existe en el sistema (2017-2025)
2. El período de fecha es correcto
3. La normalización automática funciona (prueba con/sin ceros)

### ¿Puedo buscar por nombre parcial de empresa?

**R**: Sí, el sistema hace búsqueda parcial case-insensitive.

### ¿Qué significa "factura de mayor monto"?

**R**: La factura con el valor total más alto en el período/solicitante especificado.

### ¿Puedo obtener solo documentos tributarios sin fondo?

**R**: Sí, especifica: *"dame facturas tributarias sin fondo"*

### ¿Cómo obtengo estadísticas de mi empresa?

**R**: Usa RUT para filtrar: *"estadísticas del RUT 96568740-8"*

---

##  ¡Listo para Empezar!

Ahora estás listo para usar el **Sistema de Chatbot de Facturas Gasco**. 

**Recuerda**:
-  Usa lenguaje natural conversacional
-  Sé específico para mejores resultados
-  Las descargas grandes se automatizan en ZIP
- 🔗 Enlaces válidos por 24 horas
-  Aprovecha las estadísticas para explorar

**¡Comienza ahora con tu primera consulta!**

---

**Versión**: 1.0  
**Última actualización**: 6 de octubre de 2025  
**Audiencia**: Usuarios finales  
**Nivel**: Usuario  

---

## 📝 Historial de Cambios

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 1.0 | 2025-10-06 | Option Team | Guía de usuario completa - Primera versión |

---

**© 2025 Option - Todos los derechos reservados**  
**Cliente**: Gasco