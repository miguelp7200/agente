"""
Script para probar el sistema de logging con debugging activado.
Ejecuta una consulta simple y captura los logs del callback_context.
Basado en debug/scripts/capture_monthly_breakdown.ps1
"""

import requests
import json
import time
import subprocess

# URL del backend
BACKEND_URL = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"  # Cloud Run correcto

def get_gcloud_token():
    """Obtiene token de autenticación de gcloud"""
    try:
        result = subprocess.run(
            ["gcloud", "auth", "print-identity-token"],
            capture_output=True,
            text=True,
            check=True
        )
        token = result.stdout.strip()
        print("Token de autenticacion obtenido")
        return token
    except subprocess.CalledProcessError as e:
        print(f"ERROR: No se pudo obtener token de gcloud: {e}")
        print("Ejecuta: gcloud auth login")
        return None

def create_session(backend_url, app_name, user_id, session_id, headers):
    """Crea una sesión antes de enviar la query"""
    session_url = f"{backend_url}/apps/{app_name}/users/{user_id}/sessions/{session_id}"

    try:
        print(f"Creando sesion: {session_id}")
        response = requests.post(
            session_url,
            headers=headers,
            json={},
            timeout=300
        )
        print(f"Sesion creada (status: {response.status_code})")
        return True
    except Exception as e:
        print(f"Advertencia: Error creando sesion: {e}")
        return False

def test_simple_query():
    """Ejecuta una consulta simple para activar los callbacks con debugging"""

    # 1. AUTENTICACIÓN
    print("=" * 80)
    print("PASO 1: AUTENTICACION")
    print("=" * 80)

    token = get_gcloud_token()
    if not token:
        return False

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    # 2. TEST DE CONECTIVIDAD
    print("\n" + "=" * 80)
    print("PASO 2: TEST DE CONECTIVIDAD")
    print("=" * 80)

    try:
        print(f"Probando: {BACKEND_URL}/list-apps")
        response = requests.get(
            f"{BACKEND_URL}/list-apps",
            headers=headers,
            timeout=300
        )
        print(f"Conectividad OK (status: {response.status_code})")
    except Exception as e:
        print(f"ERROR de conectividad: {e}")
        return False

    # 3. CREAR SESIÓN
    print("\n" + "=" * 80)
    print("PASO 3: CREAR SESION")
    print("=" * 80)

    timestamp = int(time.time())
    session_id = f"debug-session-{timestamp}"
    user_id = "debug-user"
    app_name = "gcp-invoice-agent-app"

    print(f"Session ID: {session_id}")
    print(f"User ID: {user_id}")
    print(f"App Name: {app_name}")

    create_session(BACKEND_URL, app_name, user_id, session_id, headers)

    # 4. EJECUTAR QUERY
    print("\n" + "=" * 80)
    print("PASO 4: EJECUTAR QUERY CON DEBUGGING")
    print("=" * 80)

    query = "Busca facturas de diciembre 2019"
    print(f"Query: {query}")

    payload = {
        "appName": app_name,
        "userId": user_id,
        "sessionId": session_id,
        "newMessage": {
            "parts": [{"text": query}],
            "role": "user"
        }
    }

    endpoint = f"{BACKEND_URL}/run"
    print(f"\nEndpoint: {endpoint}")
    print("\nBuscando logs con prefijo [DEBUG] en Cloud Run...\n")

    try:
        start_time = time.time()
        response = requests.post(
            endpoint,
            json=payload,
            headers=headers,
            timeout=300
        )
        duration = time.time() - start_time

        print(f"Status Code: {response.status_code}")
        print(f"Duration: {duration:.2f} segundos")

        if response.status_code == 200:
            result = response.json()
            print(f"\nResponse Structure:")
            print(f"  - Type: {type(result)}")
            print(f"  - Is list: {isinstance(result, list)}")

            if isinstance(result, list) and len(result) > 0:
                print(f"  - Events count: {len(result)}")

                # Buscar el evento final con role="model"
                final_text = None
                for event in result:
                    if event.get('content', {}).get('role') == 'model':
                        parts = event.get('content', {}).get('parts', [])
                        if parts and len(parts) > 0:
                            final_text = parts[0].get('text', '')

                if final_text:
                    print(f"\nFinal Response Text:")
                    print(f"  - Length: {len(final_text)} chars")
                    print(f"  - Preview: {final_text[:200]}...")
                else:
                    print(f"\nWARNING: No se encontro texto final en la respuesta")

            print(f"\n" + "=" * 80)
            print("SUCCESS: Consulta completada")
            print("=" * 80)
            print(f"\nNEXT STEPS:")
            print(f"  1. Revisa los logs de Cloud Run:")
            print(f"     gcloud logging read 'resource.type=cloud_run_revision' --limit 50 --format json")
            print(f"  2. Busca lineas con prefijo [DEBUG] en los logs")
            print(f"  3. Filtra por session_id: {session_id}")
            print(f"  4. Analiza la estructura de callback_context y agent_response")
            print(f"\n  O usa la consola web:")
            print(f"     https://console.cloud.google.com/logs/query")

            return True
        else:
            print(f"\nERROR: {response.status_code}")
            print(f"Response: {response.text[:500]}")
            return False

    except Exception as e:
        print(f"\nEXCEPTION: {e}")
        import traceback
        print(traceback.format_exc())
        return False

if __name__ == "__main__":
    print("\n" + "=" * 80)
    print("DEBUGGING CALLBACK_CONTEXT STRUCTURE")
    print("=" * 80)
    print("\nObjetivo: Identificar la estructura correcta de agent_response")
    print("Cambios: Se agregaron logs detallados en conversation_callbacks.py")
    print("\nIMPORTANTE: Asegurate de que el backend este corriendo:")
    print("   - Local: ./deployment/backend/start_backend.sh")
    print("   - Cloud Run: Ya esta desplegado")
    print("\n")

    success = test_simple_query()

    print("\n" + "=" * 80)
    if success:
        print("Test completado - Revisa los logs del servidor")
    else:
        print("Test fallo - Revisa la conexion al backend")
    print("=" * 80 + "\n")