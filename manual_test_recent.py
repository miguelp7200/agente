#!/usr/bin/env python3
"""
Test manual para verificar la funcionalidad de facturas recientes
"""

import sys
import os

# Agregar el directorio de tests/runners al path donde está utils
script_dir = os.path.dirname(os.path.abspath(__file__))
tests_runners_dir = os.path.join(script_dir, "tests", "runners")
sys.path.append(tests_runners_dir)

from utils.adk_wrapper import ADKHTTPWrapper
import json

def test_recent_invoices():
    """Test manual para facturas recientes"""
    print("🧪 Testing facturas recientes manualmente...")
    
    # Configurar agente
    agent_dir = os.path.join(os.path.dirname(__file__), "my-agents", "gcp-invoice-agent-app")
    adk = ADKHTTPWrapper(
        base_url="http://localhost:8001",
        agent_dir=agent_dir
    )
    
    # Test diferentes consultas
    queries = [
        "Dame las 10 facturas más recientes",
        "Busca las últimas 10 facturas del sistema",
        "Muéstrame las facturas más recientes ordenadas por fecha",
        "Quiero ver las 10 facturas con fecha más nueva"
    ]
    
    for query in queries:
        print(f"\n{'='*60}")
        print(f"🔍 CONSULTA: {query}")
        print(f"{'='*60}")
        
        try:
            result = adk.run_query(
                user_id="test-user",
                query=query
            )
            
            print(f"✅ RESPUESTA:")
            print(f"Answer: {result.get('answer', 'No response')}")
            
            if 'tool_calls' in result:
                print(f"🔧 TOOL CALLS: {len(result['tool_calls'])}")
                for i, tool in enumerate(result['tool_calls']):
                    print(f"  [{i+1}] {tool.get('name', 'unknown')}({tool.get('args', {})})")
            
            if 'error' in result:
                print(f"❌ ERROR: {result['error']}")
                
        except Exception as e:
            print(f"❌ EXCEPTION: {e}")
            
        print("-" * 60)

if __name__ == "__main__":
    test_recent_invoices()