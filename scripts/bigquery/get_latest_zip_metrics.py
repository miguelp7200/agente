#!/usr/bin/env python3
"""
Script para obtener las últimas métricas de performance de ZIPs desde BigQuery
"""
from google.cloud import bigquery
from datetime import datetime, timedelta


def get_latest_zip_metrics():
    """Consultar las últimas métricas de ZIPs generados"""

    client = bigquery.Client(project="agent-intelligence-gasco")

    query = """
    SELECT
        FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', timestamp) as timestamp,
        SUBSTR(conversation_id, 1, 8) as conv_id,
        SUBSTR(user_question, 1, 50) as question,
        zip_generation_time_ms,
        zip_parallel_download_time_ms,
        zip_max_workers_used,
        zip_files_included,
        zip_files_missing,
        ROUND(zip_total_size_bytes / 1024 / 1024, 2) AS size_mb,
        ROUND(zip_generation_time_ms / NULLIF(zip_files_included, 0), 2) AS ms_per_file,
        CASE 
            WHEN zip_max_workers_used > 1 THEN 'PARALELO'
            WHEN zip_max_workers_used = 1 THEN 'SECUENCIAL'
            ELSE 'DESCONOCIDO'
        END AS mode
    FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
    WHERE 
        zip_generated = TRUE
        AND zip_generation_time_ms IS NOT NULL
        AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 HOUR)
    ORDER BY timestamp DESC
    LIMIT 10
    """

    print("\n" + "=" * 100)
    print("METRICAS DE PERFORMANCE - GENERACION DE ZIPs (Ultimas 3 horas)")
    print("=" * 100 + "\n")

    results = client.query(query).result()

    found = False
    for row in results:
        found = True
        print(f"🕐 Timestamp: {row.timestamp}")
        print(f"📝 Pregunta: {row.question}...")
        print(f"🆔 Conv ID: {row.conv_id}")
        print(f"⚙️  Modo: {row.mode} (workers: {row.zip_max_workers_used})")
        print(
            f"⏱️  Tiempo total: {row.zip_generation_time_ms} ms ({row.zip_generation_time_ms/1000:.2f}s)"
        )

        if row.zip_parallel_download_time_ms:
            print(
                f"🚀 Descarga paralela: {row.zip_parallel_download_time_ms} ms ({row.zip_parallel_download_time_ms/1000:.2f}s)"
            )
            percentage = (
                row.zip_parallel_download_time_ms / row.zip_generation_time_ms
            ) * 100
            print(f"   └─ {percentage:.1f}% del tiempo total en descarga paralela")

        print(f"📦 Archivos: {row.zip_files_included} incluidos", end="")
        if row.zip_files_missing and row.zip_files_missing > 0:
            print(f", {row.zip_files_missing} faltantes", end="")
        print()

        if row.size_mb:
            print(f"💾 Tamaño: {row.size_mb} MB")

        if row.ms_per_file:
            print(f"📊 Performance: {row.ms_per_file} ms/archivo")

        print("-" * 100 + "\n")

    if not found:
        print("⚠️  No se encontraron ZIPs generados en las últimas 3 horas")
        print(
            "💡 Ejecuta el test: .\\tests\\cloudrun\\test_search_invoices_by_date_TEST_ENV.ps1\n"
        )
        return

    # Estadísticas agregadas
    stats_query = """
    SELECT
        CASE 
            WHEN zip_max_workers_used > 1 THEN 'PARALELO'
            WHEN zip_max_workers_used = 1 THEN 'SECUENCIAL'
            ELSE 'DESCONOCIDO'
        END AS mode,
        COUNT(*) as total_zips,
        ROUND(AVG(zip_generation_time_ms), 2) as avg_generation_ms,
        ROUND(MIN(zip_generation_time_ms), 2) as min_generation_ms,
        ROUND(MAX(zip_generation_time_ms), 2) as max_generation_ms,
        ROUND(AVG(zip_parallel_download_time_ms), 2) as avg_download_ms,
        ROUND(AVG(zip_files_included), 2) as avg_files,
        ROUND(AVG(zip_generation_time_ms / NULLIF(zip_files_included, 0)), 2) as avg_ms_per_file
    FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
    WHERE 
        zip_generated = TRUE
        AND zip_generation_time_ms IS NOT NULL
        AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
    GROUP BY mode
    ORDER BY mode
    """

    print("=" * 100)
    print("📈 ESTADÍSTICAS AGREGADAS (Últimas 24 horas)")
    print("=" * 100 + "\n")

    stats = client.query(stats_query).result()

    for row in stats:
        print(f"Modo: {row.mode}")
        print(f"   Total ZIPs: {row.total_zips}")
        print(
            f"   Tiempo promedio: {row.avg_generation_ms:.0f} ms ({row.avg_generation_ms/1000:.2f}s)"
        )
        print(f"   Rango: {row.min_generation_ms:.0f} - {row.max_generation_ms:.0f} ms")
        if row.avg_download_ms:
            print(
                f"   Descarga promedio: {row.avg_download_ms:.0f} ms ({row.avg_download_ms/1000:.2f}s)"
            )
        print(f"   Archivos promedio: {row.avg_files:.1f}")
        if row.avg_ms_per_file:
            print(f"   Performance: {row.avg_ms_per_file:.0f} ms/archivo")
        print()


if __name__ == "__main__":
    try:
        get_latest_zip_metrics()
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback

        traceback.print_exc()
