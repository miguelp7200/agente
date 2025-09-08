#!/usr/bin/env python3
"""
Script de prueba simple para verificar el wrapper ADK
"""
import sys
import os
import asyncio
from pathlib import Path

# Añadir el directorio de tests al path
sys.path.append("tests")


def main():
    try:
        print("🧪 Iniciando test simple del wrapper ADK...")

        # Importar wrapper
        from adk_wrapper import ADKHTTPWrapper

        print("✅ Import del wrapper exitoso")

        # Configurar wrapper
        agent_path = Path("my-agents/gcp-invoice-agent-app")
        wrapper = ADKHTTPWrapper(agent_path, port=8001)
        print(f"✅ Wrapper configurado para {agent_path}")

        # Probar una consulta simple
        async def test_query():
            result = await wrapper.process_query(
                "¿Cuántas facturas hay del emisor con RIF 0012148561?"
            )
            return result

        result = asyncio.run(test_query())

        print(f"📊 Resultado del test:")
        print(f"   Success: {result['success']}")
        print(f"   Answer: {result['answer'][:100]}...")

        if result["success"]:
            print("🎉 ¡Test EXITOSO!")
            return 0
        else:
            print(f"❌ Test FALLÓ: {result.get('error', 'Unknown error')}")
            return 1

    except Exception as e:
        print(f"💥 Error en test: {e}")
        import traceback

        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
