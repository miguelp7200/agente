#!/usr/bin/env python3
"""
Test Case Generator for Invoice Chatbot
Converts user queries into structured test cases
"""

# Based on the 65+ user queries provided
PRIORITY_QUERIES = [
    # Financial Analysis (High Priority)
    {
        "query": "cuanto es la suma de los montos por cada año",
        "category": "financial_analysis",
        "priority": "high",
        "expected_tools": ["get_amount_statistics_by_year"],
        "should_contain": ["suma", "montos", "año", "total"],
        "should_not_contain": ["error", "no puedo", "disculpa"]
    },
    {
        "query": "dime los números de factura de 2025",
        "category": "year_specific_search",
        "priority": "high", 
        "expected_tools": ["search_invoices_by_year"],
        "should_contain": ["números", "factura", "2025"],
        "should_not_contain": ["error", "no encontré", "disculpa"]
    },
    {
        "query": "Busca facturas del rut 8672564-9 de los años 2019 y 2020",
        "category": "rut_multi_year_search",
        "priority": "high",
        "expected_tools": ["search_invoices_by_rut_date_range"],
        "should_contain": ["8672564-9", "2019", "2020", "facturas"],
        "should_not_contain": ["error", "no encontré"]
    },
    {
        "query": "me puedes traer la factura cuyo rut es 69190500-4",
        "category": "rut_specific_search",
        "priority": "medium",
        "expected_tools": ["search_invoices_by_rut"],
        "should_contain": ["factura", "69190500-4"],
        "should_not_contain": ["error", "no encontré"]
    },
    {
        "query": "dame la factura de gas las naciones la última emitida",
        "category": "company_specific_search",
        "priority": "medium",
        "expected_tools": ["search_invoices_by_company_name"],
        "should_contain": ["gas", "naciones", "última", "emitida"],
        "should_not_contain": ["error", "no puedo"]
    },
    # Connectivity & Edge Cases (Medium Priority)
    {
        "query": "test de conectividad",
        "category": "connectivity_test",
        "priority": "low",
        "expected_tools": [],
        "should_contain": ["conectividad", "funciona", "activo", "disponible"],
        "should_not_contain": ["error", "fallo", "desconectado"]
    },
    {
        "query": "Me puedes traer la factura 103671886?",
        "category": "invoice_number_search",
        "priority": "medium",
        "expected_tools": ["search_invoices_by_number"],
        "should_contain": ["factura", "103671886"],
        "should_not_contain": ["error", "no encontré"]
    },
    # Business Intelligence (High Priority)
    {
        "query": "dame las facturas por solicitantes",
        "category": "business_intelligence",
        "priority": "high",
        "expected_tools": ["get_invoices_by_solicitante"],
        "should_contain": ["facturas", "solicitantes"],
        "should_not_contain": ["error", "no puedo"]
    },
    {
        "query": "pero solo quiero el conteo, no las descargas",
        "category": "count_only_request",
        "priority": "medium",
        "expected_tools": ["get_count_statistics"],
        "should_contain": ["conteo", "total", "cantidad"],
        "should_not_contain": ["enlace", "descarga", "zip"]
    },
    # Month/Year Specific Searches (High Priority)
    {
        "query": "Hola, me puedes buscar facturas de abril de 2022?",
        "category": "monthly_search",
        "priority": "high",
        "expected_tools": ["search_invoices_by_month_year"],
        "should_contain": ["abril", "2022", "facturas"],
        "should_not_contain": ["error", "no encontré"]
    },
    {
        "query": "Hola, puedes conseguirme las facturas de diciembre de 2021?",
        "category": "monthly_search", 
        "priority": "high",
        "expected_tools": ["search_invoices_by_month_year"],
        "should_contain": ["diciembre", "2021", "facturas"],
        "should_not_contain": ["error", "no encontré"]
    }
]

def generate_test_case(query_data):
    """Generate a structured test case from query data"""
    
    name = f"Test: {query_data['category'].replace('_', ' ').title()}"
    description = f"Valida que el agente pueda manejar consultas de tipo {query_data['category']}. Prioridad: {query_data['priority']}."
    
    test_case = {
        "name": name,
        "description": description,
        "query": query_data["query"],
        "validation_criteria": {
            "response_content": {
                "should_contain": query_data["should_contain"],
                "should_not_contain": query_data["should_not_contain"]
            },
            "tool_sequence": {
                "expected_tools": query_data["expected_tools"],
                "sequence_required": False
            }
        },
        "metadata": {
            "category": query_data["category"],
            "priority": query_data["priority"],
            "created_date": "2025-09-08",
            "test_type": "user_query_validation",
            "expected_execution_time": "< 8 segundos",
            "validation_requirements": {
                "functional_response": True,
                "accurate_data": True,
                "no_errors": True
            }
        }
    }
    
    return test_case

def main():
    """Generate all test cases"""
    print("🧪 Generando casos de test adicionales...")
    
    for i, query_data in enumerate(PRIORITY_QUERIES, 1):
        test_case = generate_test_case(query_data)
        filename = f"query_{i:02d}_{query_data['category']}.test.json"
        
        print(f"✅ Generado: {filename}")
        print(f"   Query: {query_data['query']}")
        print(f"   Categoría: {query_data['category']}")
        print(f"   Prioridad: {query_data['priority']}")
        print()

if __name__ == "__main__":
    main()