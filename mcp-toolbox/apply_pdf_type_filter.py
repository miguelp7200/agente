#!/usr/bin/env python3
"""
Script para aplicar filtrado por tipo de PDF a herramientas MCP Toolbox
Modifica tools_updated.yaml agregando parámetro pdf_type a herramientas de búsqueda
"""

import re
import yaml
from pathlib import Path

# Herramientas que deben ser modificadas (columnas directas sin proxy)
TOOLS_DIRECT_COLUMNS = [
    'search_invoices',
    'search_invoices_by_proveedor',
    'search_invoices_by_cliente',
    'search_invoices_by_minimum_amount',
    'get_invoices_with_pdf_info'
]

# Herramientas que devuelven columnas con _proxy
TOOLS_WITH_PROXY = [
    'search_invoices_by_date',
    'search_invoices_by_rut',
    'search_invoices_by_date_range',
    'search_invoices_by_rut_and_date_range',
    'search_invoices_by_month_year',
    'search_invoices_by_multiple_ruts',
    'search_invoices_recent_by_date',
    'search_invoices_by_factura_number',
    'search_invoices_by_referencia_number',
    'search_invoices_by_any_number',
    'search_invoices_by_solicitante_and_date_range',
    'search_invoices_by_solicitante_max_amount_in_month',
    'search_invoices_by_rut_and_amount',
    'search_invoices_by_company_name_and_date'
]

def modify_direct_columns_statement(statement: str) -> str:
    """
    Modifica statements SQL que devuelven columnas directas (sin _proxy)
    Aplica filtrado con CASE WHEN usando @pdf_type
    """
    # Patrón para Copia_Tributaria_cf
    statement = re.sub(
        r'Copia_Tributaria_cf,',
        "CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') THEN Copia_Tributaria_cf ELSE NULL END as Copia_Tributaria_cf,",
        statement
    )
    
    # Patrón para Copia_Cedible_cf
    statement = re.sub(
        r'Copia_Cedible_cf,',
        "CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') THEN Copia_Cedible_cf ELSE NULL END as Copia_Cedible_cf,",
        statement
    )
    
    # Patrón para Copia_Tributaria_sf
    statement = re.sub(
        r'Copia_Tributaria_sf,',
        "CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') THEN Copia_Tributaria_sf ELSE NULL END as Copia_Tributaria_sf,",
        statement
    )
    
    # Patrón para Copia_Cedible_sf
    statement = re.sub(
        r'Copia_Cedible_sf,',
        "CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') THEN Copia_Cedible_sf ELSE NULL END as Copia_Cedible_sf,",
        statement
    )
    
    return statement

def modify_proxy_columns_statement(statement: str) -> str:
    """
    Modifica statements SQL que devuelven columnas con _proxy
    Aplica filtrado con CASE WHEN usando @pdf_type
    """
    # Patrón para Copia_Tributaria_cf_proxy
    statement = re.sub(
        r'WHEN Copia_Tributaria_cf IS NOT NULL\s+THEN Copia_Tributaria_cf',
        "WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') AND Copia_Tributaria_cf IS NOT NULL\n\n    THEN Copia_Tributaria_cf",
        statement,
        flags=re.MULTILINE
    )
    
    # Patrón para Copia_Cedible_cf_proxy
    statement = re.sub(
        r'WHEN Copia_Cedible_cf IS NOT NULL\s+THEN Copia_Cedible_cf',
        "WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') AND Copia_Cedible_cf IS NOT NULL\n\n    THEN Copia_Cedible_cf",
        statement,
        flags=re.MULTILINE
    )
    
    # Patrón para Copia_Tributaria_sf_proxy
    statement = re.sub(
        r'WHEN Copia_Tributaria_sf IS NOT NULL\s+THEN Copia_Tributaria_sf',
        "WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') AND Copia_Tributaria_sf IS NOT NULL\n       THEN Copia_Tributaria_sf",
        statement,
        flags=re.MULTILINE
    )
    
    # Patrón para Copia_Cedible_sf_proxy
    statement = re.sub(
        r'WHEN Copia_Cedible_sf IS NOT NULL\s+THEN Copia_Cedible_sf',
        "WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') AND Copia_Cedible_sf IS NOT NULL\n       THEN Copia_Cedible_sf",
        statement,
        flags=re.MULTILINE
    )
    
    return statement

def add_pdf_type_parameter(tool_config: dict) -> dict:
    """
    Agrega parámetro pdf_type a la configuración de la herramienta
    """
    pdf_type_param = {
        'name': 'pdf_type',
        'type': 'string',
        'description': """Tipo de PDF a retornar (OPCIONAL):
- 'both' (default): Retorna facturas tributarias Y cedibles
- 'tributaria_only': Solo facturas tributarias (CF y SF)
- 'cedible_only': Solo facturas cedibles (CF y SF)""",
        'required': False
    }
    
    if 'parameters' not in tool_config:
        tool_config['parameters'] = []
    
    # Verificar si ya existe el parámetro
    if not any(p.get('name') == 'pdf_type' for p in tool_config['parameters']):
        tool_config['parameters'].append(pdf_type_param)
    
    # Agregar nota en la descripción si no existe
    if 'description' in tool_config and 'NUEVO: Soporta filtrado por tipo de PDF' not in tool_config['description']:
        tool_config['description'] += "\n\nNUEVO: Soporta filtrado por tipo de PDF mediante parámetro opcional pdf_type.\n"
    
    return tool_config

def process_yaml_file(yaml_path: Path):
    """
    Procesa el archivo YAML y aplica modificaciones
    """
    print(f"📝 Leyendo {yaml_path}...")
    
    # Leer archivo como texto para preservar formato
    with open(yaml_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Backup del archivo original
    backup_path = yaml_path.with_suffix('.yaml.backup')
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Backup creado: {backup_path}")
    
    # Cargar YAML
    data = yaml.safe_load(content)
    
    if 'tools' not in data:
        print("❌ No se encontró sección 'tools' en el YAML")
        return
    
    modified_count = 0
    
    # Procesar herramientas con columnas directas
    for tool_name in TOOLS_DIRECT_COLUMNS:
        if tool_name in data['tools']:
            print(f"🔧 Modificando {tool_name} (columnas directas)...")
            tool = data['tools'][tool_name]
            
            if 'statement' in tool:
                tool['statement'] = modify_direct_columns_statement(tool['statement'])
            
            data['tools'][tool_name] = add_pdf_type_parameter(tool)
            modified_count += 1
    
    # Procesar herramientas con columnas proxy
    for tool_name in TOOLS_WITH_PROXY:
        if tool_name in data['tools']:
            print(f"🔧 Modificando {tool_name} (columnas proxy)...")
            tool = data['tools'][tool_name]
            
            if 'statement' in tool:
                tool['statement'] = modify_proxy_columns_statement(tool['statement'])
            
            data['tools'][tool_name] = add_pdf_type_parameter(tool)
            modified_count += 1
    
    # Guardar YAML modificado
    output_path = yaml_path.with_name('tools_updated_with_filter.yaml')
    with open(output_path, 'w', encoding='utf-8') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    
    print(f"\n✅ Modificaciones completadas:")
    print(f"   - Herramientas modificadas: {modified_count}")
    print(f"   - Archivo generado: {output_path}")
    print(f"   - Backup original: {backup_path}")
    
    return modified_count

def main():
    """
    Función principal
    """
    yaml_path = Path(__file__).parent / 'tools_updated.yaml'
    
    if not yaml_path.exists():
        print(f"❌ No se encontró el archivo: {yaml_path}")
        return
    
    print("=" * 70)
    print("🚀 Aplicando filtrado por tipo de PDF a herramientas MCP Toolbox")
    print("=" * 70)
    print()
    
    try:
        modified_count = process_yaml_file(yaml_path)
        
        print()
        print("=" * 70)
        print("✅ Proceso completado exitosamente")
        print("=" * 70)
        print()
        print("📋 Próximos pasos:")
        print("   1. Revisar tools_updated_with_filter.yaml")
        print("   2. Ejecutar tests de validación")
        print("   3. Reemplazar tools_updated.yaml si todo está correcto")
        print("   4. Commit y push a branch feature/pdf-type-filter")
        
    except Exception as e:
        print(f"\n❌ Error durante el procesamiento: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
