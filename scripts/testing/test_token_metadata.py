"""
Script de prueba para validar si la API de Gemini/Vertex AI
devuelve metadata de tokens (entrada y salida) después de generate_content()

Objetivo: Confirmar qué información de tokens está disponible antes de
         implementar el guardado en BigQuery.

Uso:
    python test_token_metadata.py
"""

import sys
from pathlib import Path
import os

# Fix encoding para Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

# Agregar directorio raíz al path
sys.path.append(str(Path(__file__).parent))

# Configurar proyecto y región ANTES de importar vertexai
os.environ["GOOGLE_CLOUD_PROJECT"] = "agent-intelligence-gasco"
os.environ["GOOGLE_CLOUD_LOCATION"] = "us-central1"

import vertexai
vertexai.init(project="agent-intelligence-gasco", location="us-central1")

from vertexai.generative_models import GenerativeModel
from config import VERTEX_AI_MODEL
import json


def test_token_metadata():
    """
    Prueba si la API de Vertex AI devuelve metadata de tokens
    """
    print("=" * 80)
    print("TEST: Metadata de Tokens en Vertex AI Gemini")
    print("=" * 80)

    try:
        # Inicializar modelo
        print(f"\n[1] Inicializando modelo: {VERTEX_AI_MODEL}")
        model = GenerativeModel(VERTEX_AI_MODEL)
        print("✅ Modelo inicializado correctamente")

        # Texto de prueba simple
        test_prompt = "Explica en 2 líneas qué es una factura electrónica."
        print(f"\n[2] Enviando prompt de prueba:")
        print(f"    '{test_prompt}'")

        # Generar respuesta
        print("\n[3] Llamando a generate_content()...")
        response = model.generate_content(test_prompt)
        print("✅ Respuesta recibida")

        # Examinar estructura de la respuesta
        print("\n" + "=" * 80)
        print("ESTRUCTURA DE LA RESPUESTA")
        print("=" * 80)

        # Atributos principales
        print("\n[4] Atributos disponibles en response:")
        response_attrs = [attr for attr in dir(response) if not attr.startswith('_')]
        for attr in response_attrs:
            print(f"    - response.{attr}")

        # Verificar usage_metadata
        print("\n" + "=" * 80)
        print("METADATA DE TOKENS")
        print("=" * 80)

        if hasattr(response, 'usage_metadata'):
            print("\n✅ response.usage_metadata EXISTE")
            usage = response.usage_metadata

            # Mostrar todos los atributos de usage_metadata
            print("\n[5] Atributos de usage_metadata:")
            usage_attrs = [attr for attr in dir(usage) if not attr.startswith('_')]
            for attr in usage_attrs:
                try:
                    value = getattr(usage, attr)
                    if not callable(value):
                        print(f"    - usage_metadata.{attr} = {value}")
                except:
                    print(f"    - usage_metadata.{attr} = <no accesible>")

            # Campos específicos que esperamos
            print("\n[6] Campos de tokens esperados:")

            # Tokens de entrada (prompt)
            if hasattr(usage, 'prompt_token_count'):
                print(f"    ✅ prompt_token_count = {usage.prompt_token_count} tokens")
            else:
                print(f"    ❌ prompt_token_count NO EXISTE")

            # Tokens de salida (respuesta)
            if hasattr(usage, 'candidates_token_count'):
                print(f"    ✅ candidates_token_count = {usage.candidates_token_count} tokens")
            else:
                print(f"    ❌ candidates_token_count NO EXISTE")

            # Total de tokens
            if hasattr(usage, 'total_token_count'):
                print(f"    ✅ total_token_count = {usage.total_token_count} tokens")
            else:
                print(f"    ❌ total_token_count NO EXISTE")

            # Tokens cached (si existen)
            if hasattr(usage, 'cached_content_token_count'):
                print(f"    ℹ️  cached_content_token_count = {usage.cached_content_token_count} tokens")

            # Convertir a dict para ver todo
            print("\n[7] JSON completo de usage_metadata:")
            try:
                # Intentar serializar a JSON
                usage_dict = {
                    attr: getattr(usage, attr)
                    for attr in dir(usage)
                    if not attr.startswith('_') and not callable(getattr(usage, attr))
                }
                print(json.dumps(usage_dict, indent=2))
            except Exception as e:
                print(f"    ⚠️  No se pudo serializar: {e}")
                print(f"    Raw: {usage}")

        else:
            print("\n❌ response.usage_metadata NO EXISTE")
            print("⚠️  La API no devuelve metadata de tokens")

        # Mostrar respuesta del modelo
        print("\n" + "=" * 80)
        print("RESPUESTA DEL MODELO")
        print("=" * 80)
        print(response.text)

        # Verificar candidates
        print("\n" + "=" * 80)
        print("CANDIDATES METADATA")
        print("=" * 80)

        if hasattr(response, 'candidates'):
            print(f"\n✅ response.candidates EXISTE ({len(response.candidates)} candidatos)")
            for i, candidate in enumerate(response.candidates):
                print(f"\n[Candidato {i}]")
                candidate_attrs = [attr for attr in dir(candidate) if not attr.startswith('_')]
                for attr in candidate_attrs:
                    try:
                        value = getattr(candidate, attr)
                        if not callable(value) and attr != 'content':
                            print(f"    - {attr} = {value}")
                    except:
                        pass

        # Resumen final
        print("\n" + "=" * 80)
        print("RESUMEN")
        print("=" * 80)

        has_usage = hasattr(response, 'usage_metadata')
        has_prompt_tokens = has_usage and hasattr(response.usage_metadata, 'prompt_token_count')
        has_output_tokens = has_usage and hasattr(response.usage_metadata, 'candidates_token_count')
        has_total_tokens = has_usage and hasattr(response.usage_metadata, 'total_token_count')

        print("\n✅ = Disponible | ❌ = No disponible\n")
        print(f"{'✅' if has_usage else '❌'} response.usage_metadata")
        print(f"{'✅' if has_prompt_tokens else '❌'} response.usage_metadata.prompt_token_count (tokens de entrada)")
        print(f"{'✅' if has_output_tokens else '❌'} response.usage_metadata.candidates_token_count (tokens de salida)")
        print(f"{'✅' if has_total_tokens else '❌'} response.usage_metadata.total_token_count (total)")

        if has_usage and has_prompt_tokens and has_output_tokens:
            print("\n" + "🎉" * 40)
            print("CONCLUSIÓN: ✅ SÍ es posible capturar tokens de entrada y salida")
            print("🎉" * 40)
            print("\nPróximos pasos:")
            print("1. Modificar conversation_callbacks.py para capturar usage_metadata")
            print("2. Agregar campos al schema de BigQuery (input_tokens, output_tokens, total_tokens)")
            print("3. Actualizar _enrich_conversation_data() para persistir estos datos")
        else:
            print("\n" + "⚠️ " * 40)
            print("CONCLUSIÓN: ❌ NO es posible capturar todos los tokens necesarios")
            print("⚠️ " * 40)
            print("\nAlternativa:")
            print("- Usar solo count_tokens() para estimaciones")

    except Exception as e:
        print(f"\n❌ ERROR DURANTE LA PRUEBA: {e}")
        import traceback
        print("\nStack trace completo:")
        traceback.print_exc()


def test_count_tokens_comparison():
    """
    Comparar count_tokens() vs usage_metadata para ver diferencias
    """
    print("\n\n" + "=" * 80)
    print("TEST ADICIONAL: Comparación count_tokens() vs usage_metadata")
    print("=" * 80)

    try:
        model = GenerativeModel(VERTEX_AI_MODEL)
        test_text = "¿Cuánto es 2+2? Responde solo con el número."

        # Método 1: count_tokens (estimación PRE-llamada)
        print("\n[Método 1] count_tokens() - Estimación ANTES de llamar:")
        count_result = model.count_tokens(test_text)
        estimated_tokens = count_result.total_tokens
        print(f"    Tokens estimados: {estimated_tokens}")

        # Método 2: generate_content + usage_metadata (real POST-llamada)
        print("\n[Método 2] generate_content() + usage_metadata - Tokens REALES:")
        response = model.generate_content(test_text)

        if hasattr(response, 'usage_metadata'):
            real_input = response.usage_metadata.prompt_token_count
            real_output = response.usage_metadata.candidates_token_count
            real_total = response.usage_metadata.total_token_count

            print(f"    Input tokens (real):  {real_input}")
            print(f"    Output tokens (real): {real_output}")
            print(f"    Total tokens (real):  {real_total}")

            print(f"\n[Comparación]")
            print(f"    Estimación count_tokens: {estimated_tokens}")
            print(f"    Real usage_metadata:     {real_input} (solo input)")
            print(f"    Diferencia:              {abs(estimated_tokens - real_input)} tokens")

            if estimated_tokens == real_input:
                print(f"    ✅ count_tokens() es preciso para el input")
            else:
                print(f"    ⚠️  count_tokens() tiene diferencia con el input real")
        else:
            print("    ❌ No hay usage_metadata disponible")

    except Exception as e:
        print(f"\n❌ ERROR en comparación: {e}")


if __name__ == "__main__":
    test_token_metadata()
    test_count_tokens_comparison()

    print("\n\n" + "=" * 80)
    print("FIN DEL TEST")
    print("=" * 80)
