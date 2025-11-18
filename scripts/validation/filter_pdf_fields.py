#!/usr/bin/env python3
"""
Script para filtrar los campos PDF en tools_updated.yaml
Solo mantiene Copia_Tributaria_cf y Copia_Cedible_cf por defecto
"""

import yaml
import re
from pathlib import Path

def filter_pdf_fields_in_sql(sql_statement):
    """
    Modifica las consultas SQL para devolver solo los campos CF requeridos
    """
    # Patrones para identificar los bloques de campos PDF
    pdf_fields_pattern = r'(\s+)(CASE\s+WHEN\s+Copia_Tributaria_cf[\s\S]*?END\s+as\s+Doc_Termico_proxy)'

    # Reemplazo: solo CF fields (con fondo)
    cf_only_replacement = r'''\1CASE
\1  WHEN Copia_Tributaria_cf IS NOT NULL
\1  THEN Copia_Tributaria_cf
\1  ELSE NULL
\1END as Copia_Tributaria_cf_proxy,
\1CASE
\1  WHEN Copia_Cedible_cf IS NOT NULL
\1  THEN Copia_Cedible_cf
\1  ELSE NULL
\1END as Copia_Cedible_cf_proxy'''

    modified_sql = re.sub(pdf_fields_pattern, cf_only_replacement, sql_statement, flags=re.MULTILINE)
    return modified_sql

def update_tool_descriptions(tool_data):
    """
    Actualiza las descripciones para reflejar que solo devuelve CF (con fondo)
    """
    if 'description' in tool_data:
        # Actualizar descripción para mencionar solo CF
        desc = tool_data['description']
        if 'Los PDFs están en campos separados' in desc:
            tool_data['description'] = desc.replace(
                'Los PDFs están en campos separados: Copia_Tributaria_cf, Copia_Cedible_cf, Copia_Tributaria_sf, Copia_Cedible_sf, Doc_Termico.',
                'Los PDFs están en campos: Copia_Tributaria_cf (Tributaria con Fondo), Copia_Cedible_cf (Cedible con Fondo). Para otros tipos específicos usar herramientas especializadas.'
            )

    return tool_data

def create_specialized_tools():
    """
    Define herramientas especializadas para casos específicos
    """
    return {
        'get_tributaria_sf_pdfs': {
            'kind': 'bigquery-sql',
            'source': 'gasco_invoices_read',
            'description': 'Obtiene PDFs de Copia Tributaria Sin Fondo (SF) para facturas específicas.',
            'statement': '''SELECT
              Factura,
              CASE
                WHEN Copia_Tributaria_sf IS NOT NULL
                THEN Copia_Tributaria_sf
                ELSE NULL
              END as Copia_Tributaria_sf_proxy
              FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
              WHERE Copia_Tributaria_sf IS NOT NULL
              AND Factura IN UNNEST(@invoice_numbers)
              LIMIT 50''',
            'parameters': [
                {
                    'name': 'invoice_numbers',
                    'type': 'array',
                    'description': 'Lista de números de factura'
                }
            ]
        },
        'get_cedible_sf_pdfs': {
            'kind': 'bigquery-sql',
            'source': 'gasco_invoices_read',
            'description': 'Obtiene PDFs de Copia Cedible Sin Fondo (SF) para facturas específicas.',
            'statement': '''SELECT
              Factura,
              CASE
                WHEN Copia_Cedible_sf IS NOT NULL
                THEN Copia_Cedible_sf
                ELSE NULL
              END as Copia_Cedible_sf_proxy
              FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
              WHERE Copia_Cedible_sf IS NOT NULL
              AND Factura IN UNNEST(@invoice_numbers)
              LIMIT 50''',
            'parameters': [
                {
                    'name': 'invoice_numbers',
                    'type': 'array',
                    'description': 'Lista de números de factura'
                }
            ]
        },
        'get_doc_termico_pdfs': {
            'kind': 'bigquery-sql',
            'source': 'gasco_invoices_read',
            'description': 'Obtiene documentos térmicos para facturas específicas.',
            'statement': '''SELECT
              Factura,
              CASE
                WHEN Doc_Termico IS NOT NULL
                THEN Doc_Termico
                ELSE NULL
              END as Doc_Termico_proxy
              FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
              WHERE Doc_Termico IS NOT NULL
              AND Factura IN UNNEST(@invoice_numbers)
              LIMIT 50''',
            'parameters': [
                {
                    'name': 'invoice_numbers',
                    'type': 'array',
                    'description': 'Lista de números de factura'
                }
            ]
        }
    }

def main():
    yaml_file = Path('mcp-toolbox/tools_updated.yaml')

    # Cargar el YAML
    with open(yaml_file, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)

    # Filtrar todas las herramientas existentes
    tools_modified = 0
    for tool_name, tool_data in data['tools'].items():
        if 'statement' in tool_data and 'Copia_' in tool_data['statement']:
            # Modificar consulta SQL
            original_statement = tool_data['statement']
            modified_statement = filter_pdf_fields_in_sql(original_statement)

            if original_statement != modified_statement:
                tool_data['statement'] = modified_statement
                tool_data = update_tool_descriptions(tool_data)
                tools_modified += 1
                print(f"OK Modificada herramienta: {tool_name}")

    # Agregar herramientas especializadas
    specialized_tools = create_specialized_tools()
    for tool_name, tool_data in specialized_tools.items():
        data['tools'][tool_name] = tool_data
        print(f"OK Agregada herramienta especializada: {tool_name}")

    # Guardar el archivo modificado
    with open(yaml_file, 'w', encoding='utf-8') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    print(f"\nRESUMEN:")
    print(f"   - {tools_modified} herramientas existentes modificadas")
    print(f"   - {len(specialized_tools)} herramientas especializadas agregadas")
    print(f"   - Archivo actualizado: {yaml_file}")
    print(f"\nCOMPORTAMIENTO NUEVO:")
    print(f"   - Por defecto: solo Copia_Tributaria_cf y Copia_Cedible_cf")
    print(f"   - Para SF o térmicos: usar herramientas especializadas")

if __name__ == '__main__':
    main()