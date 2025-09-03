#!/usr/bin/env python3
"""
Script para actualizar URLs en tools_updated.yaml según el entorno
- En desarrollo local: http://localhost:8011
- En Cloud Run: https://invoice-backend-819133916464.us-central1.run.app
"""

import os
import re
from pathlib import Path

def update_yaml_urls():
    """Actualiza las URLs en tools_updated.yaml según el entorno"""
    
    # Detectar entorno
    is_cloud_run = os.getenv("K_SERVICE") is not None
    
    if is_cloud_run:
        new_base_url = os.getenv("CLOUD_RUN_SERVICE_URL", "https://invoice-backend-819133916464.us-central1.run.app")
        print(f"[CLOUD RUN] Actualizando URLs a: {new_base_url}")
    else:
        new_base_url = "http://localhost:8011"
        print(f"[LOCAL] Manteniendo URLs locales: {new_base_url}")
    
    # Ruta del archivo YAML
    yaml_file = Path(__file__).parent / "mcp-toolbox" / "tools_updated.yaml"
    
    if not yaml_file.exists():
        print(f"❌ Error: Archivo no encontrado: {yaml_file}")
        return False
    
    try:
        # Leer contenido del archivo
        with open(yaml_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Patrón para encontrar URLs localhost
        pattern = r'http://localhost:\d+'
        
        # Contar ocurrencias antes del reemplazo
        matches = re.findall(pattern, content)
        count_before = len(matches)
        
        # Reemplazar todas las URLs
        updated_content = re.sub(pattern, new_base_url, content)
        
        # Contar ocurrencias después del reemplazo
        matches_after = re.findall(pattern, updated_content)
        count_after = len(matches_after)
        
        # Escribir archivo actualizado
        with open(yaml_file, 'w', encoding='utf-8') as f:
            f.write(updated_content)
        
        print(f"✅ URLs actualizadas exitosamente:")
        print(f"   📄 Archivo: {yaml_file}")
        print(f"   🔄 Reemplazos: {count_before - count_after}")
        print(f"   🌐 URL base: {new_base_url}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error actualizando archivo YAML: {e}")
        return False

if __name__ == "__main__":
    update_yaml_urls()
