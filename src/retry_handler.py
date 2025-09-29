"""
🔄 Sistema de Retry Mejorado para Errores de Backend

Este módulo implementa un sistema robusto de reintentos para manejar errores
temporales de Gemini (especialmente errores 500 INTERNAL) con estrategias
de fallback inteligentes.

Características:
- Retry automático con backoff exponencial
- Detección específica de errores 500
- Logging detallado para diagnóstico
- Métricas de reintentos
- Fallback a nueva sesión si es necesario
"""

import time
import logging
from typing import Optional, Callable, Any, Dict
from functools import wraps
import traceback

# Configurar logging
logger = logging.getLogger(__name__)


class RetryConfig:
    """Configuración centralizada de reintentos"""

    # Configuración de reintentos
    MAX_RETRIES = 2  # Total de 3 intentos (1 original + 2 retries)
    INITIAL_BACKOFF_SECONDS = 2  # Primer retry espera 2s
    BACKOFF_MULTIPLIER = 2  # Backoff exponencial: 2s, 4s, 8s...
    MAX_BACKOFF_SECONDS = 10  # Máximo 10s de espera

    # Errores específicos a reintentar
    RETRYABLE_ERROR_CODES = [500]  # Solo errores 500 INTERNAL
    RETRYABLE_ERROR_KEYWORDS = [
        "INTERNAL",
        "Internal error encountered",
        "ServerError",
        "DeadlineExceeded",
        "ServiceUnavailable",
    ]


class RetryMetrics:
    """Métricas de reintentos para monitoreo"""

    def __init__(self):
        self.total_retries = 0
        self.successful_retries = 0
        self.failed_retries = 0
        self.retry_durations = []

    def record_retry(self, success: bool, duration: float):
        """Registra un intento de retry"""
        self.total_retries += 1
        if success:
            self.successful_retries += 1
        else:
            self.failed_retries += 1
        self.retry_durations.append(duration)

    def get_stats(self) -> Dict[str, Any]:
        """Obtiene estadísticas de reintentos"""
        avg_duration = (
            sum(self.retry_durations) / len(self.retry_durations)
            if self.retry_durations
            else 0
        )
        return {
            "total_retries": self.total_retries,
            "successful_retries": self.successful_retries,
            "failed_retries": self.failed_retries,
            "success_rate": (
                (self.successful_retries / self.total_retries * 100)
                if self.total_retries > 0
                else 0
            ),
            "avg_retry_duration_seconds": round(avg_duration, 2),
        }


# Instancia global de métricas
retry_metrics = RetryMetrics()


def is_retryable_error(error: Exception) -> bool:
    """
    Determina si un error debe ser reintentado.

    Args:
        error: Excepción a evaluar

    Returns:
        True si el error es reintentable (error 500)
    """
    error_str = str(error)
    error_type = type(error).__name__

    # Verificar código de error 500 en el mensaje
    if "500" in error_str:
        logger.info(f"🔍 [RETRY] Error 500 detectado: {error_type}")
        return True

    # Verificar keywords específicos de errores temporales
    for keyword in RetryConfig.RETRYABLE_ERROR_KEYWORDS:
        if keyword.lower() in error_str.lower() or keyword in error_type:
            logger.info(f"🔍 [RETRY] Error reintentable detectado: {keyword}")
            return True

    return False


def calculate_backoff(attempt: int) -> float:
    """
    Calcula el tiempo de espera con backoff exponencial.

    Args:
        attempt: Número de intento actual (0-indexed)

    Returns:
        Tiempo de espera en segundos
    """
    backoff = RetryConfig.INITIAL_BACKOFF_SECONDS * (
        RetryConfig.BACKOFF_MULTIPLIER**attempt
    )
    return min(backoff, RetryConfig.MAX_BACKOFF_SECONDS)


def retry_on_error(func: Callable) -> Callable:
    """
    Decorador para reintentar funciones que fallan con errores temporales.

    Uso:
        @retry_on_error
        def llamada_backend():
            ...
    """

    @wraps(func)
    def wrapper(*args, **kwargs):
        last_error = None

        for attempt in range(RetryConfig.MAX_RETRIES + 1):
            try:
                if attempt > 0:
                    logger.info(
                        f"🔄 [RETRY] Intento {attempt + 1} de {RetryConfig.MAX_RETRIES + 1}"
                    )

                # Ejecutar función
                start_time = time.time()
                result = func(*args, **kwargs)

                # Si llegamos aquí, fue exitoso
                if attempt > 0:
                    duration = time.time() - start_time
                    retry_metrics.record_retry(True, duration)
                    logger.info(
                        f"✅ [RETRY] Intento {attempt + 1} exitoso después de {duration:.2f}s"
                    )

                return result

            except Exception as e:
                last_error = e
                duration = time.time() - start_time if attempt > 0 else 0

                # Verificar si debemos reintentar
                if not is_retryable_error(e):
                    logger.info(
                        f"❌ [RETRY] Error no reintentable: {type(e).__name__}"
                    )
                    raise

                # Si ya agotamos los reintentos, fallar
                if attempt >= RetryConfig.MAX_RETRIES:
                    retry_metrics.record_retry(False, duration)
                    logger.error(
                        f"❌ [RETRY] Todos los intentos fallaron después de {attempt + 1} intentos"
                    )
                    logger.error(f"❌ [RETRY] Último error: {str(e)}")
                    raise

                # Calcular backoff y esperar
                backoff_time = calculate_backoff(attempt)
                logger.warning(
                    f"⚠️ [RETRY] Intento {attempt + 1} falló: {type(e).__name__}"
                )
                logger.warning(f"⏳ [RETRY] Esperando {backoff_time}s antes de reintentar...")
                time.sleep(backoff_time)

        # Fallback final (no debería llegar aquí)
        raise last_error

    return wrapper


async def retry_on_error_async(func: Callable) -> Callable:
    """
    Decorador asíncrono para reintentar funciones async que fallan.

    Uso:
        @retry_on_error_async
        async def llamada_backend_async():
            ...
    """

    @wraps(func)
    async def wrapper(*args, **kwargs):
        import asyncio

        last_error = None

        for attempt in range(RetryConfig.MAX_RETRIES + 1):
            try:
                if attempt > 0:
                    logger.info(
                        f"🔄 [RETRY ASYNC] Intento {attempt + 1} de {RetryConfig.MAX_RETRIES + 1}"
                    )

                # Ejecutar función
                start_time = time.time()
                result = await func(*args, **kwargs)

                # Si llegamos aquí, fue exitoso
                if attempt > 0:
                    duration = time.time() - start_time
                    retry_metrics.record_retry(True, duration)
                    logger.info(
                        f"✅ [RETRY ASYNC] Intento {attempt + 1} exitoso después de {duration:.2f}s"
                    )

                return result

            except Exception as e:
                last_error = e
                duration = time.time() - start_time if attempt > 0 else 0

                # Verificar si debemos reintentar
                if not is_retryable_error(e):
                    logger.info(
                        f"❌ [RETRY ASYNC] Error no reintentable: {type(e).__name__}"
                    )
                    raise

                # Si ya agotamos los reintentos, fallar
                if attempt >= RetryConfig.MAX_RETRIES:
                    retry_metrics.record_retry(False, duration)
                    logger.error(
                        f"❌ [RETRY ASYNC] Todos los intentos fallaron después de {attempt + 1} intentos"
                    )
                    logger.error(f"❌ [RETRY ASYNC] Último error: {str(e)}")
                    raise

                # Calcular backoff y esperar
                backoff_time = calculate_backoff(attempt)
                logger.warning(
                    f"⚠️ [RETRY ASYNC] Intento {attempt + 1} falló: {type(e).__name__}"
                )
                logger.warning(
                    f"⏳ [RETRY ASYNC] Esperando {backoff_time}s antes de reintentar..."
                )
                await asyncio.sleep(backoff_time)

        # Fallback final (no debería llegar aquí)
        raise last_error

    return wrapper


def get_retry_stats() -> Dict[str, Any]:
    """
    Obtiene estadísticas globales de reintentos.

    Returns:
        Dict con métricas de reintentos
    """
    return retry_metrics.get_stats()


def reset_retry_stats():
    """Resetea las estadísticas de reintentos (útil para testing)"""
    global retry_metrics
    retry_metrics = RetryMetrics()


# Logging helper para estructurar logs de errores 500
def log_500_error_details(error: Exception, context: Dict[str, Any] = None):
    """
    Registra detalles completos de un error 500 para diagnóstico.

    Args:
        error: Excepción ocurrida
        context: Contexto adicional (session_id, query, etc.)
    """
    logger.error("=" * 80)
    logger.error("🚨 ERROR 500 INTERNAL DETECTADO")
    logger.error("=" * 80)
    logger.error(f"Tipo de error: {type(error).__name__}")
    logger.error(f"Mensaje: {str(error)}")

    if context:
        logger.error("Contexto:")
        for key, value in context.items():
            logger.error(f"  - {key}: {value}")

    logger.error("Stack trace completo:")
    logger.error(traceback.format_exc())
    logger.error("=" * 80)