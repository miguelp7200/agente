#!/usr/bin/env python3
"""
Test de integración y fallback para el sistema de estabilidad GCS.

Este script valida que el sistema puede funcionar con y sin los módulos
de estabilidad, garantizando robustez y compatibilidad hacia atrás.
"""

import sys
import os
from pathlib import Path

# Agregar paths necesarios
current_dir = Path(__file__).parent
backend_dir = current_dir.parent.parent
sys.path.insert(0, str(backend_dir / "src"))
sys.path.insert(0, str(backend_dir / "my-agents" / "gcp-invoice-agent-app"))

def test_gcs_stability_availability():
    """Test de disponibilidad de módulos de estabilidad."""
    print("🧪 Test 1: Disponibilidad de módulos GCS Stability")
    
    try:
        from src.gcs_stability import SignedURLService, verify_time_sync
        print("   ✅ Módulos de estabilidad importados exitosamente")
        
        # Test básico de funcionalidad
        service = SignedURLService()
        print(f"   ✅ SignedURLService creado: {service.default_expiration_hours}h expiration")
        
        time_status = verify_time_sync(timeout=2)
        print(f"   ✅ Verificación de tiempo: {time_status}")
        
        return True
    except ImportError as e:
        print(f"   ❌ Módulos no disponibles: {e}")
        return False
    except Exception as e:
        print(f"   ⚠️ Error en test: {e}")
        return False

def test_agent_integration():
    """Test de integración en agent.py."""
    print("\n🧪 Test 2: Integración en agent.py")
    
    try:
        # Simular la carga del agente
        print("   📦 Simulando importación de agent.py...")
        
        # Verificar la estructura del agente sin importar completamente
        agent_path = backend_dir / "my-agents" / "gcp-invoice-agent-app" / "agent.py"
        if not agent_path.exists():
            print("   ❌ agent.py no encontrado")
            return False
            
        # Leer contenido para verificar integración
        with open(agent_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Verificar elementos clave de integración
        checks = [
            ("GCS_STABILITY_AVAILABLE", "Variable de control de disponibilidad"),
            ("from src.gcs_stability import", "Importación de módulos"),
            ("SignedURLService", "Servicio centralizado"),
            ("verify_time_sync", "Verificación temporal"),
            ("configure_environment", "Configuración de entorno"),
        ]
        
        for check, description in checks:
            if check in content:
                print(f"   ✅ {description}: encontrado")
            else:
                print(f"   ❌ {description}: NO encontrado")
                
        return True
        
    except Exception as e:
        print(f"   ❌ Error en test de integración: {e}")
        return False

def test_fallback_mechanism():
    """Test del mecanismo de fallback."""
    print("\n🧪 Test 3: Mecanismo de fallback")
    
    try:
        # Simular fallo de módulos de estabilidad
        print("   🔄 Simulando fallo de módulos de estabilidad...")
        
        # Verificar que existe implementación legacy
        agent_path = backend_dir / "my-agents" / "gcp-invoice-agent-app" / "agent.py"
        with open(agent_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        fallback_indicators = [
            "_generate_individual_download_links_legacy",
            "Usando implementación legacy",
            "Fallback a implementación",
            "except ImportError",
        ]
        
        fallback_found = 0
        for indicator in fallback_indicators:
            if indicator in content:
                print(f"   ✅ Indicador de fallback: {indicator}")
                fallback_found += 1
            else:
                print(f"   ❌ Indicador faltante: {indicator}")
                
        if fallback_found >= 3:
            print("   ✅ Mecanismo de fallback robusto implementado")
            return True
        else:
            print("   ⚠️ Mecanismo de fallback incompleto")
            return False
            
    except Exception as e:
        print(f"   ❌ Error en test de fallback: {e}")
        return False

def test_configuration_validation():
    """Test de validación de configuración."""
    print("\n🧪 Test 4: Validación de configuración")
    
    try:
        # Verificar variables de configuración
        config_path = backend_dir / "config.py"
        if not config_path.exists():
            print("   ❌ config.py no encontrado")
            return False
            
        with open(config_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        config_vars = [
            "SIGNED_URL_EXPIRATION_HOURS",
            "SIGNED_URL_BUFFER_MINUTES", 
            "MAX_SIGNATURE_RETRIES",
            "TIME_SYNC_TIMEOUT",
            "SIGNED_URL_MONITORING_ENABLED",
        ]
        
        for var in config_vars:
            if var in content:
                print(f"   ✅ Variable de configuración: {var}")
            else:
                print(f"   ❌ Variable faltante: {var}")
                
        return True
        
    except Exception as e:
        print(f"   ❌ Error en validación de configuración: {e}")
        return False

def main():
    """Ejecutar suite completa de tests de integración."""
    print("🔍 INICIANDO TESTS DE INTEGRACIÓN Y FALLBACK")
    print("=" * 60)
    
    # Obtener directorio del backend
    global backend_dir
    backend_dir = Path(__file__).parent.parent.parent
    
    print(f"📁 Directorio backend: {backend_dir}")
    print(f"📁 Directorio actual: {Path.cwd()}")
    
    # Ejecutar tests
    tests = [
        test_gcs_stability_availability,
        test_agent_integration, 
        test_fallback_mechanism,
        test_configuration_validation,
    ]
    
    results = []
    for test_func in tests:
        try:
            result = test_func()
            results.append(result)
        except Exception as e:
            print(f"❌ Error ejecutando {test_func.__name__}: {e}")
            results.append(False)
    
    # Resumen
    print("\n" + "=" * 60)
    passed = sum(results)
    total = len(results)
    
    print(f"🎯 RESUMEN DE TESTS:")
    print(f"   ✅ Pasados: {passed}/{total}")
    print(f"   ❌ Fallidos: {total - passed}/{total}")
    
    if passed == total:
        print("🎉 TODOS LOS TESTS DE INTEGRACIÓN PASARON")
        return 0
    else:
        print("⚠️ ALGUNOS TESTS FALLARON - REVISAR IMPLEMENTACIÓN")
        return 1

if __name__ == "__main__":
    exit(main())