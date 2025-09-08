#!/usr/bin/env python3
"""
Script de diagnóstico para investigar URLs firmadas malformadas
"""

import sys
from pathlib import Path
import os

# Añadir el directorio del agente al path
sys.path.append(str(Path(__file__).parent / "my-agents" / "gcp-invoice-agent-app"))

from agent import generate_individual_download_links, _get_service_account_email
from google.cloud import storage
from datetime import datetime, timedelta
import google.auth
from google.auth import impersonated_credentials

def debug_malformed_url():
    """Diagnostica el problema de URL malformada para factura 0101552280"""
    
    print("=" * 80)
    print("🔍 DIAGNÓSTICO DE URL MALFORMADA")
    print("=" * 80)
    
    # URLs problemáticas reportadas
    problematic_urls = [
        "gs://miguel-test/descargas/0101552280/Copia_Tributaria_cf.pdf"
    ]
    
    # URLs normales para comparación
    normal_urls = [
        "gs://miguel-test/descargas/0101531734/Copia_Cedible_cf.pdf",
        "gs://miguel-test/descargas/0101552280/Copia_Cedible_cf.pdf"
    ]
    
    print(f"📋 URLs a probar:")
    for i, url in enumerate(problematic_urls + normal_urls, 1):
        print(f"   {i}. {url}")
    
    print("\n" + "=" * 80)
    print("🧪 PROBANDO GENERACIÓN DE URLs INDIVIDUALES")
    print("=" * 80)
    
    for i, test_url in enumerate(problematic_urls + normal_urls, 1):
        print(f"\n🔗 Prueba {i}: {test_url}")
        print("-" * 50)
        
        try:
            result = generate_individual_download_links(test_url)
            
            if result["success"]:
                urls = result["download_urls"]
                for j, url in enumerate(urls):
                    print(f"✅ URL generada #{j+1}:")
                    print(f"   Longitud total: {len(url)} caracteres")
                    
                    # Analizar componentes de la URL
                    if "X-Goog-Signature=" in url:
                        signature_part = url.split("X-Goog-Signature=")[1]
                        base_url_part = url.split("X-Goog-Signature=")[0]
                        
                        print(f"   Longitud base URL: {len(base_url_part)} caracteres")
                        print(f"   Longitud firma: {len(signature_part)} caracteres")
                        
                        # Verificar patrones repetitivos
                        if len(signature_part) > 600:  # URLs normales tienen ~512 chars
                            print(f"   ⚠️  FIRMA ANORMALMENTE LARGA!")
                            
                            # Buscar patrones repetitivos
                            repeated_patterns = []
                            for pattern_len in [32, 64, 128]:
                                for start in range(0, min(len(signature_part), 200), pattern_len):
                                    pattern = signature_part[start:start+pattern_len]
                                    if len(pattern) == pattern_len and signature_part.count(pattern) > 1:
                                        repeated_patterns.append((pattern, signature_part.count(pattern)))
                            
                            if repeated_patterns:
                                print(f"   🔍 Patrones repetitivos encontrados:")
                                for pattern, count in repeated_patterns[:3]:  # Solo los primeros 3
                                    print(f"      '{pattern[:20]}...' se repite {count} veces")
                            
                            # Mostrar muestra de la firma
                            print(f"   📝 Primeros 100 chars de firma: {signature_part[:100]}")
                            print(f"   📝 Últimos 100 chars de firma: {signature_part[-100:]}")
                        else:
                            print(f"   ✅ Firma de longitud normal")
                            print(f"   📝 Firma completa: {signature_part}")
                    else:
                        print(f"   ❌ No se encontró firma X-Goog-Signature en la URL")
            else:
                print(f"❌ Error generando URL: {result.get('error', 'Error desconocido')}")
                
        except Exception as e:
            print(f"❌ Excepción durante la generación: {e}")
    
    print("\n" + "=" * 80)
    print("🔧 PROBANDO MÉTODO DIRECTO DE GCS")
    print("=" * 80)
    
    # Probar generación directa con el cliente GCS
    try:
        print("🔄 Configurando credenciales...")
        credentials, project = google.auth.default()
        service_account_email = _get_service_account_email()
        print(f"📧 Service Account: {service_account_email}")
        
        target_scopes = ['https://www.googleapis.com/auth/cloud-platform']
        target_credentials = impersonated_credentials.Credentials(
            source_credentials=credentials,
            target_principal=service_account_email,
            target_scopes=target_scopes,
        )
        
        storage_client = storage.Client(credentials=target_credentials)
        bucket = storage_client.bucket("miguel-test")
        
        # Probar URL problemática directamente
        problem_blob_path = "descargas/0101552280/Copia_Tributaria_cf.pdf"
        blob = bucket.blob(problem_blob_path)
        
        print(f"🔍 Verificando existencia del blob: {problem_blob_path}")
        if blob.exists():
            print("✅ Blob existe")
            
            # Probar generación multiple de URLs para ver si es consistente
            print("🔄 Generando 3 URLs firmadas para el mismo blob...")
            for i in range(3):
                expiration = datetime.utcnow() + timedelta(hours=1)
                signed_url = blob.generate_signed_url(
                    version="v4",
                    expiration=expiration,
                    method="GET",
                    credentials=target_credentials
                )
                signature = signed_url.split("X-Goog-Signature=")[1] if "X-Goog-Signature=" in signed_url else "NO_SIGNATURE"
                print(f"   URL #{i+1}: {len(signed_url)} chars, firma: {len(signature)} chars")
                if len(signature) > 600:
                    print(f"      ⚠️  URL #{i+1} ANORMALMENTE LARGA!")
                    print(f"      📝 Primeros 50 chars: {signature[:50]}")
        else:
            print("❌ Blob no existe")
            
    except Exception as e:
        print(f"❌ Error en método directo: {e}")
    
    print("\n" + "=" * 80)
    print("🏁 DIAGNÓSTICO COMPLETADO")
    print("=" * 80)

if __name__ == "__main__":
    debug_malformed_url()