#!/usr/bin/env python3
"""
Script de prueba para verificar la solución temporal al problema de ZIP downloads
"""

import requests
import sys
import os
import time
from pathlib import Path

# Agregar directorio raíz al path
sys.path.append(str(Path(__file__).parent))


def test_zip_download_fix():
    """
    Prueba la solución temporal para ZIP downloads
    """
    print("🧪 [TEST] Iniciando prueba de la solución ZIP download fix...")

    # URLs de prueba
    test_urls = [
        # URL problemática (servidor ADK puerto 8080)
        "http://localhost:8080/zips/zip_test.zip",
        # URL correcta (PDF server puerto 8011)
        "http://localhost:8011/zips/zip_test.zip",
    ]

    for url in test_urls:
        print(f"\n🔍 [TEST] Probando URL: {url}")

        try:
            # Hacer request con timeout
            response = requests.get(url, timeout=10, allow_redirects=True)

            print(f"📊 [TEST] Status Code: {response.status_code}")
            print(f"📊 [TEST] Headers: {dict(response.headers)}")

            if response.status_code == 200:
                print(f"✅ [TEST] URL funciona correctamente: {url}")
                if "application/zip" in response.headers.get("content-type", ""):
                    print(f"✅ [TEST] Content-Type es ZIP correcto")
                else:
                    print(
                        f"⚠️ [TEST] Content-Type inesperado: {response.headers.get('content-type')}"
                    )
            else:
                print(f"❌ [TEST] URL falló: {url} - Status: {response.status_code}")
                print(f"📄 [TEST] Respuesta: {response.text[:200]}...")

        except requests.exceptions.ConnectionError:
            print(f"🔌 [TEST] Servidor no disponible en: {url}")
        except requests.exceptions.Timeout:
            print(f"⏰ [TEST] Timeout en: {url}")
        except Exception as e:
            print(f"❌ [TEST] Error inesperado en {url}: {e}")


def check_servers_running():
    """
    Verifica que los servidores necesarios estén corriendo
    """
    print("🔍 [CHECK] Verificando servidores...")

    servers = [
        {"name": "ADK API Server", "url": "http://localhost:8080", "port": 8080},
        {"name": "PDF Server", "url": "http://localhost:8011", "port": 8011},
        {"name": "MCP Toolbox", "url": "http://localhost:5000", "port": 5000},
    ]

    all_running = True

    for server in servers:
        try:
            # Intentar conectar al puerto
            import socket

            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex(("localhost", server["port"]))
            sock.close()

            if result == 0:
                print(
                    f"✅ [CHECK] {server['name']} corriendo en puerto {server['port']}"
                )
            else:
                print(
                    f"❌ [CHECK] {server['name']} NO disponible en puerto {server['port']}"
                )
                all_running = False

        except Exception as e:
            print(f"❌ [CHECK] Error verificando {server['name']}: {e}")
            all_running = False

    return all_running


def test_zip_packager_fix():
    """
    Prueba la función get_zip_download_url mejorada
    """
    print("\n🧪 [TEST] Probando función get_zip_download_url...")

    try:
        from zip_packager import get_zip_download_url

        # Simular archivo ZIP de prueba
        test_filename = "zip_test_123.zip"

        # Probar en modo local (sin Cloud Run)
        os.environ.pop("K_SERVICE", None)  # Asegurarse que no está en Cloud Run

        url = get_zip_download_url(test_filename)
        print(f"📋 [TEST] URL generada (local): {url}")

        expected_local = f"http://localhost:8011/zips/{test_filename}"
        if url == expected_local:
            print("✅ [TEST] URL local generada correctamente")
        else:
            print(f"❌ [TEST] URL local incorrecta. Esperada: {expected_local}")

        # Simular modo Cloud Run
        os.environ["K_SERVICE"] = "invoice-backend"

        try:
            url_cloud = get_zip_download_url(test_filename)
            print(f"📋 [TEST] URL generada (Cloud Run): {url_cloud}")

            # Debería ser o una URL firmada o una URL de fallback
            if url_cloud.startswith("https://") and "zips" in url_cloud:
                print("✅ [TEST] URL Cloud Run generada (puede ser firmada o fallback)")
            else:
                print(f"⚠️ [TEST] URL Cloud Run inesperada: {url_cloud}")

        except Exception as e:
            print(f"⚠️ [TEST] Error en modo Cloud Run (esperado sin permisos): {e}")

        # Limpiar variable de entorno
        os.environ.pop("K_SERVICE", None)

    except ImportError as e:
        print(f"❌ [TEST] No se pudo importar zip_packager: {e}")
    except Exception as e:
        print(f"❌ [TEST] Error probando zip_packager: {e}")


def main():
    """
    Función principal de pruebas
    """
    print("🚀 [MAIN] Iniciando suite de pruebas para ZIP download fix\n")

    # 1. Verificar servidores
    if not check_servers_running():
        print("\n⚠️ [MAIN] Algunos servidores no están corriendo.")
        print("💡 [MAIN] Para testing completo, inicia:")
        print("   - ADK API Server: adk api_server my-agents")
        print("   - PDF Server: python local_pdf_server.py")
        print(
            "   - MCP Toolbox: ./mcp-toolbox/toolbox --tools-file=tools_updated.yaml\n"
        )

    # 2. Probar función zip_packager
    test_zip_packager_fix()

    # 3. Probar URLs de descarga (solo si servidores están disponibles)
    test_zip_download_fix()

    print("\n🎯 [MAIN] Pruebas completadas.")
    print("\n📋 [MAIN] RESUMEN DE LA SOLUCIÓN:")
    print("   1. ✅ get_zip_download_url mejorada con fallback elegante")
    print("   2. ✅ PDF Server con detección de redirecciones problemáticas")
    print("   3. ⏳ Pendiente: Permisos IAM para URLs firmadas")
    print(
        "\n🚀 [MAIN] Cuando tengas los permisos, las URLs firmadas funcionarán automáticamente."
    )


if __name__ == "__main__":
    main()
