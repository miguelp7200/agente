#!/usr/bin/env python3
"""
Test script para verificar el filtrado de PDFs en las herramientas MCP
"""

import yaml
import json
from pathlib import Path

def test_pdf_filtering():
    """
    Verifica que las herramientas modificadas solo devuelvan los campos CF requeridos
    """
    yaml_file = Path('mcp-toolbox/tools_updated.yaml')

    with open(yaml_file, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)

    # Verificar herramientas principales modificadas
    test_tools = [
        'search_invoices_by_factura_number',
        'search_invoices_by_date',
        'search_invoices_by_rut',
        'search_invoices_by_month_year'
    ]

    print("=== VERIFICACIÓN DE FILTRADO PDF ===\n")

    for tool_name in test_tools:
        if tool_name in data['tools']:
            tool = data['tools'][tool_name]
            statement = tool.get('statement', '')

            # Verificar que solo contiene CF fields
            cf_count = statement.count('Copia_Tributaria_cf_proxy') + statement.count('Copia_Cedible_cf_proxy')
            sf_count = statement.count('Copia_Tributaria_sf_proxy') + statement.count('Copia_Cedible_sf_proxy')
            termico_count = statement.count('Doc_Termico_proxy')

            print(f"TOOL: {tool_name}:")
            print(f"   - CF fields (con fondo): {cf_count}")
            print(f"   - SF fields (sin fondo): {sf_count}")
            print(f"   - Doc termico: {termico_count}")

            if cf_count == 2 and sf_count == 0 and termico_count == 0:
                print("   OK CORRECTO: Solo CF fields")
            else:
                print("   ERROR: Campos incorrectos")
            print()

    # Verificar herramientas especializadas
    specialized_tools = [
        'get_tributaria_sf_pdfs',
        'get_cedible_sf_pdfs',
        'get_doc_termico_pdfs'
    ]

    print("=== VERIFICACIÓN HERRAMIENTAS ESPECIALIZADAS ===\n")

    for tool_name in specialized_tools:
        if tool_name in data['tools']:
            print(f"OK {tool_name}: ENCONTRADA")
        else:
            print(f"ERROR {tool_name}: FALTA")

    print(f"\n=== RESUMEN GENERAL ===")
    print(f"Total de herramientas: {len(data['tools'])}")
    print(f"Herramientas especializadas agregadas: {len([t for t in specialized_tools if t in data['tools']])}")

    return True

if __name__ == '__main__':
    test_pdf_filtering()