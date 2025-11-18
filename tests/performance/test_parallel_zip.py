#!/usr/bin/env python3
"""
Script de prueba para validar la optimización de descarga paralela en ZIPs

Compara el rendimiento de la versión secuencial vs paralela
"""

import time
import logging
from pathlib import Path
from zip_packager import ZipPackager

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

def test_parallel_vs_sequential():
    """
    Prueba de rendimiento: descarga paralela vs secuencial
    """
    logger.info("=" * 80)
    logger.info("🧪 TEST DE RENDIMIENTO: Descarga Paralela vs Secuencial")
    logger.info("=" * 80)
    
    # Crear instancia del empaquetador
    packager = ZipPackager()
    
    # Obtener lista de PDFs disponibles
    available_pdfs = packager.list_available_pdfs()
    
    if len(available_pdfs) < 10:
        logger.warning(f"⚠️ Solo {len(available_pdfs)} PDFs disponibles")
        logger.warning("⚠️ Se recomienda tener al menos 10 PDFs para una prueba significativa")
        if len(available_pdfs) == 0:
            logger.error("❌ No hay PDFs disponibles para testing")
            return
    
    # Tomar los primeros 20 PDFs (o todos si hay menos)
    test_pdfs = [pdf['filename'] for pdf in available_pdfs[:min(20, len(available_pdfs))]]
    
    logger.info(f"\n📊 Configuración del test:")
    logger.info(f"   - PDFs a procesar: {len(test_pdfs)}")
    logger.info(f"   - Workers paralelos: {packager.max_workers}")
    logger.info(f"   - Tamaño total aprox: {sum(p['size_bytes'] for p in available_pdfs[:len(test_pdfs)]):,} bytes")
    
    # Test 1: Con paralelización (actual)
    logger.info(f"\n🚀 Test 1: Descarga PARALELA ({packager.max_workers} workers)")
    logger.info("-" * 80)
    
    start_parallel = time.time()
    result_parallel = packager.generate_zip(
        zip_id="test-parallel",
        pdf_filenames=test_pdfs
    )
    end_parallel = time.time()
    
    parallel_total_time = int((end_parallel - start_parallel) * 1000)
    
    logger.info(f"\n✅ Resultado Paralelo:")
    logger.info(f"   ⏱️  Tiempo total: {parallel_total_time}ms")
    logger.info(f"   🚀 Tiempo descarga paralela: {result_parallel.get('parallel_download_time_ms', 'N/A')}ms")
    logger.info(f"   📦 Archivos incluidos: {result_parallel['files_included']}/{result_parallel['files_requested']}")
    logger.info(f"   📏 Tamaño ZIP: {result_parallel['total_size_bytes']:,} bytes")
    logger.info(f"   🗜️  Ratio compresión: {result_parallel['compression_ratio']}")
    
    # Calcular métricas
    if result_parallel['files_included'] > 0:
        ms_per_file_parallel = parallel_total_time / result_parallel['files_included']
        logger.info(f"   📊 Tiempo por archivo: {ms_per_file_parallel:.2f}ms")
    
    # Test 2: Simulación secuencial (para comparación)
    # Para simular secuencial, usamos max_workers=1
    logger.info(f"\n🐌 Test 2: Descarga SECUENCIAL (1 worker)")
    logger.info("-" * 80)
    
    packager_sequential = ZipPackager(max_workers=1)
    
    start_sequential = time.time()
    result_sequential = packager_sequential.generate_zip(
        zip_id="test-sequential",
        pdf_filenames=test_pdfs
    )
    end_sequential = time.time()
    
    sequential_total_time = int((end_sequential - start_sequential) * 1000)
    
    logger.info(f"\n✅ Resultado Secuencial:")
    logger.info(f"   ⏱️  Tiempo total: {sequential_total_time}ms")
    logger.info(f"   📦 Archivos incluidos: {result_sequential['files_included']}/{result_sequential['files_requested']}")
    logger.info(f"   📏 Tamaño ZIP: {result_sequential['total_size_bytes']:,} bytes")
    
    if result_sequential['files_included'] > 0:
        ms_per_file_sequential = sequential_total_time / result_sequential['files_included']
        logger.info(f"   📊 Tiempo por archivo: {ms_per_file_sequential:.2f}ms")
    
    # Comparación final
    logger.info(f"\n" + "=" * 80)
    logger.info(f"📊 COMPARACIÓN DE RENDIMIENTO")
    logger.info("=" * 80)
    
    speedup = sequential_total_time / parallel_total_time if parallel_total_time > 0 else 0
    time_saved = sequential_total_time - parallel_total_time
    percentage_improvement = ((sequential_total_time - parallel_total_time) / sequential_total_time * 100) if sequential_total_time > 0 else 0
    
    logger.info(f"\n⏱️  Tiempos:")
    logger.info(f"   - Paralelo ({packager.max_workers} workers): {parallel_total_time}ms")
    logger.info(f"   - Secuencial (1 worker): {sequential_total_time}ms")
    logger.info(f"   - Tiempo ahorrado: {time_saved}ms")
    
    logger.info(f"\n🚀 Mejora de rendimiento:")
    logger.info(f"   - Speedup: {speedup:.2f}x más rápido")
    logger.info(f"   - Mejora: {percentage_improvement:.1f}%")
    
    if speedup > 1.5:
        logger.info(f"\n✅ ¡EXCELENTE! La paralelización mejora significativamente el rendimiento")
    elif speedup > 1.0:
        logger.info(f"\n✅ BUENO: La paralelización mejora el rendimiento")
    else:
        logger.info(f"\n⚠️  ADVERTENCIA: La paralelización no mejora el rendimiento")
        logger.info(f"   Esto puede deberse a pocos archivos o archivos muy pequeños")
    
    logger.info(f"\n" + "=" * 80)
    logger.info(f"🏁 Test completado exitosamente")
    logger.info("=" * 80)

if __name__ == "__main__":
    test_parallel_vs_sequential()
