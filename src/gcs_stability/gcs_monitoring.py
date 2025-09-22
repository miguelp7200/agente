"""
Sistema de monitoreo y logging estructurado para signed URLs de GCS.

Este módulo implementa logging JSON estructurado con métricas específicas
para operaciones de signed URLs, facilitando el monitoreo y debugging
de problemas de estabilidad.

Basándome en el Byterover memory layer, esto ayudará a trackear patrones
de errores SignatureDoesNotMatch y métricas de rendimiento.
"""

import logging
import json
import time
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
from functools import wraps
from pathlib import Path
import threading
from collections import defaultdict, deque

logger = logging.getLogger(__name__)


class SignedURLFormatter(logging.Formatter):
    """
    Formateador personalizado para logs estructurados de signed URLs.

    Convierte logs en formato JSON con campos específicos para
    operaciones de GCS signed URLs.
    """

    def format(self, record: logging.LogRecord) -> str:
        """
        Formatear record de log en JSON estructurado.

        Args:
            record: Record de logging estándar

        Returns:
            String JSON con información estructurada
        """
        # Datos base del log
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }

        # Agregar datos específicos de signed URLs si están disponibles
        if hasattr(record, "signed_url_data"):
            log_entry["signed_url_data"] = record.signed_url_data

        # Agregar información de excepción si existe
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_entry, ensure_ascii=False)


class SignedURLMetrics:
    """
    Colector de métricas para operaciones de signed URLs.

    Mantiene estadísticas en tiempo real de operaciones, errores,
    tiempos de respuesta y patrones de clock skew.
    """

    def __init__(self, max_history: int = 1000):
        """
        Inicializar colector de métricas.

        Args:
            max_history: Máximo número de eventos a mantener en historial
        """
        self.max_history = max_history
        self.lock = threading.Lock()

        # Contadores básicos
        self.counters = defaultdict(int)

        # Historiales con límite de tamaño
        self.response_times = deque(maxlen=max_history)
        self.error_history = deque(maxlen=max_history)
        self.clock_skew_history = deque(maxlen=max_history)

        # Métricas por bucket
        self.bucket_stats = defaultdict(lambda: defaultdict(int))

        # Timestamp de inicio
        self.start_time = datetime.now(timezone.utc)

        logger.info(f"SignedURLMetrics inicializado (max_history={max_history})")

    def record_url_generation(
        self,
        bucket: str,
        duration: float,
        success: bool,
        clock_skew_detected: bool = False,
    ):
        """
        Registrar evento de generación de URL.

        Args:
            bucket: Nombre del bucket
            duration: Tiempo de generación en segundos
            success: Si la generación fue exitosa
            clock_skew_detected: Si se detectó clock skew
        """
        with self.lock:
            # Contadores globales
            self.counters["url_generations_total"] += 1
            if success:
                self.counters["url_generations_successful"] += 1
            else:
                self.counters["url_generations_failed"] += 1

            if clock_skew_detected:
                self.counters["clock_skew_detected"] += 1
                self.clock_skew_history.append(
                    {
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "bucket": bucket,
                        "duration": duration,
                    }
                )

            # Estadísticas por bucket
            self.bucket_stats[bucket]["generations"] += 1
            if success:
                self.bucket_stats[bucket]["generations_successful"] += 1

            # Historial de tiempos de respuesta
            self.response_times.append(
                {
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "duration": duration,
                    "operation": "url_generation",
                    "bucket": bucket,
                    "success": success,
                }
            )

    def record_download(
        self,
        size_bytes: int,
        duration: float,
        success: bool,
        retries: int = 0,
        signature_error: bool = False,
    ):
        """
        Registrar evento de descarga.

        Args:
            size_bytes: Tamaño del archivo descargado
            duration: Tiempo de descarga en segundos
            success: Si la descarga fue exitosa
            retries: Número de reintentos realizados
            signature_error: Si hubo error de signature
        """
        with self.lock:
            # Contadores globales
            self.counters["downloads_total"] += 1
            if success:
                self.counters["downloads_successful"] += 1
                self.counters["total_bytes_downloaded"] += size_bytes
            else:
                self.counters["downloads_failed"] += 1

            if retries > 0:
                self.counters["downloads_with_retries"] += 1
                self.counters["total_retries"] += retries

            if signature_error:
                self.counters["signature_errors"] += 1
                self.error_history.append(
                    {
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "error_type": "signature_mismatch",
                        "retries": retries,
                        "duration": duration,
                    }
                )

            # Historial de tiempos de respuesta
            self.response_times.append(
                {
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "duration": duration,
                    "operation": "download",
                    "size_bytes": size_bytes,
                    "success": success,
                    "retries": retries,
                }
            )

    def get_summary(self) -> Dict[str, Any]:
        """
        Obtener resumen de métricas.

        Returns:
            Diccionario con resumen de estadísticas
        """
        with self.lock:
            # Calcular estadísticas derivadas
            total_downloads = max(1, self.counters["downloads_total"])
            total_generations = max(1, self.counters["url_generations_total"])

            # Estadísticas de tiempo de respuesta
            recent_times = [
                entry["duration"] for entry in list(self.response_times)[-100:]
            ]
            avg_response_time = (
                sum(recent_times) / len(recent_times) if recent_times else 0
            )

            uptime = (datetime.now(timezone.utc) - self.start_time).total_seconds()

            return {
                "uptime_seconds": uptime,
                "counters": dict(self.counters),
                "rates": {
                    "url_generation_success_rate": (
                        self.counters["url_generations_successful"] / total_generations
                    )
                    * 100,
                    "download_success_rate": (
                        self.counters["downloads_successful"] / total_downloads
                    )
                    * 100,
                    "retry_rate": (
                        self.counters["downloads_with_retries"] / total_downloads
                    )
                    * 100,
                    "clock_skew_rate": (
                        self.counters["clock_skew_detected"] / total_generations
                    )
                    * 100,
                },
                "performance": {
                    "avg_response_time_seconds": round(avg_response_time, 3),
                    "total_mb_downloaded": round(
                        self.counters["total_bytes_downloaded"] / (1024 * 1024), 2
                    ),
                    "avg_retries_per_download": (
                        self.counters["total_retries"]
                        / max(1, self.counters["downloads_with_retries"])
                    ),
                },
                "bucket_stats": dict(self.bucket_stats),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }

    def get_recent_errors(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Obtener errores recientes.

        Args:
            limit: Número máximo de errores a retornar

        Returns:
            Lista de errores recientes
        """
        with self.lock:
            return list(self.error_history)[-limit:]

    def get_clock_skew_events(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Obtener eventos recientes de clock skew.

        Args:
            limit: Número máximo de eventos a retornar

        Returns:
            Lista de eventos de clock skew
        """
        with self.lock:
            return list(self.clock_skew_history)[-limit:]


# Instancia global de métricas
_global_metrics = SignedURLMetrics()


def setup_signed_url_monitoring(
    log_level: int = logging.INFO,
    log_file: Optional[str] = None,
    enable_console: bool = True,
    enable_metrics: bool = True,
) -> logging.Logger:
    """
    Configurar sistema de monitoreo para signed URLs.

    Configura logging estructurado JSON y métricas para operaciones
    de signed URLs de Google Cloud Storage.

    Args:
        log_level: Nivel de logging (default: INFO)
        log_file: Archivo de log opcional
        enable_console: Si habilitar logging a consola
        enable_metrics: Si habilitar colección de métricas

    Returns:
        Logger configurado para signed URLs

    Example:
        >>> logger = setup_signed_url_monitoring(
        ...     log_file='signed_urls.log',
        ...     enable_metrics=True
        ... )
        >>> logger.info("Sistema de monitoreo iniciado")
    """
    # Crear logger específico para signed URLs
    logger = logging.getLogger("signed_url_service")
    logger.setLevel(log_level)

    # Limpiar handlers existentes
    logger.handlers.clear()

    # Configurar formateador personalizado
    formatter = SignedURLFormatter()

    # Handler para consola si está habilitado
    if enable_console:
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

    # Handler para archivo si se especifica
    if log_file:
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

    # Evitar propagación a root logger
    logger.propagate = False

    logger.info(
        "Sistema de monitoreo de signed URLs iniciado",
        extra={
            "signed_url_data": {
                "log_level": logging.getLevelName(log_level),
                "log_file": log_file,
                "console_enabled": enable_console,
                "metrics_enabled": enable_metrics,
            }
        },
    )

    return logger


def monitor_signed_url_operation(operation_type: str):
    """
    Decorator para monitorear operaciones de signed URLs.

    Args:
        operation_type: Tipo de operación ('generation', 'download', etc.)

    Returns:
        Decorator que agrega monitoreo automático

    Example:
        @monitor_signed_url_operation('generation')
        def generate_url(bucket, blob):
            # Lógica de generación
            return signed_url
    """

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            start_time = time.time()
            success = False
            error = None

            try:
                result = func(*args, **kwargs)
                success = True
                return result

            except Exception as e:
                error = str(e)
                raise

            finally:
                duration = time.time() - start_time

                # Log del evento
                logger = logging.getLogger("signed_url_service")
                log_data = {
                    "operation": operation_type,
                    "function": func.__name__,
                    "duration": round(duration, 3),
                    "success": success,
                }

                if error:
                    log_data["error"] = error

                logger.info(
                    f"Operation {operation_type} completed",
                    extra={"signed_url_data": log_data},
                )

        return wrapper

    return decorator


def get_global_metrics() -> SignedURLMetrics:
    """
    Obtener instancia global de métricas.

    Returns:
        Instancia global de SignedURLMetrics
    """
    return _global_metrics


def log_clock_skew_detection(bucket: str, time_diff: float, buffer_applied: int):
    """
    Log específico para detección de clock skew.

    Args:
        bucket: Bucket donde se detectó el skew
        time_diff: Diferencia de tiempo en segundos
        buffer_applied: Buffer aplicado en minutos
    """
    logger = logging.getLogger("signed_url_service")

    logger.warning(
        "Clock skew detectado",
        extra={
            "signed_url_data": {
                "event": "clock_skew_detection",
                "bucket": bucket,
                "time_difference_seconds": time_diff,
                "buffer_applied_minutes": buffer_applied,
                "severity": "high" if time_diff > 300 else "medium",
            }
        },
    )

    # Registrar en métricas globales
    _global_metrics.record_url_generation(
        bucket=bucket,
        duration=0,  # No aplica para detección de skew
        success=True,
        clock_skew_detected=True,
    )


if __name__ == "__main__":
    # Test del sistema de monitoreo
    print("📊 Testing sistema de monitoreo de signed URLs...")

    # Configurar monitoreo
    logger = setup_signed_url_monitoring(
        log_level=logging.INFO, enable_console=True, enable_metrics=True
    )

    # Test de métricas
    metrics = get_global_metrics()

    # Simular algunas operaciones
    metrics.record_url_generation("test-bucket", 0.5, True, False)
    metrics.record_url_generation("test-bucket", 1.2, True, True)  # Con clock skew
    metrics.record_download(1024000, 2.3, True, 0, False)
    metrics.record_download(512000, 1.8, False, 2, True)  # Con error de signature

    # Obtener resumen
    summary = metrics.get_summary()
    print(f"Resumen de métricas:")
    print(json.dumps(summary, indent=2, ensure_ascii=False))

    # Test logging estructurado
    logger.info(
        "Test de logging estructurado",
        extra={
            "signed_url_data": {
                "test": True,
                "bucket": "test-bucket",
                "operation": "test",
            }
        },
    )

    print("✅ Sistema de monitoreo funcionando correctamente")
