"""
🔄 Callbacks de Retry para Gemini en ADK

Este módulo proporciona callbacks personalizados para el agente ADK que
implementan retry automático cuando se detectan errores 500 de Gemini.

Los callbacks se integran con el sistema de callbacks existente y añaden
capacidad de retry transparente sin modificar el flujo principal.
"""

import logging
import time
from typing import Any, Dict, Optional
from .retry_handler import (
    is_retryable_error,
    log_500_error_details,
    get_retry_stats,
)

logger = logging.getLogger(__name__)


class GeminiRetryCallbacks:
    """
    Clase que proporciona callbacks para manejar errores de Gemini con retry.

    Esta clase se puede usar junto con callbacks existentes para añadir
    capacidad de retry sin romper funcionalidad existente.
    """

    def __init__(self):
        self.error_count = 0
        self.retry_count = 0
        self.last_error_time = None
        self.session_errors = {}  # Track errors por sesión

    def on_error_callback(
        self,
        error: Exception,
        context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Callback invocado cuando ocurre un error en el agente.

        Args:
            error: Excepción que ocurrió
            context: Contexto adicional del error

        Returns:
            Dict con información del error procesado
        """
        self.error_count += 1
        self.last_error_time = time.time()

        # Extraer session_id si está disponible
        session_id = context.get("session_id", "unknown") if context else "unknown"

        # Track errores por sesión
        if session_id not in self.session_errors:
            self.session_errors[session_id] = []

        self.session_errors[session_id].append({
            "error_type": type(error).__name__,
            "error_message": str(error),
            "timestamp": self.last_error_time,
        })

        # Verificar si es un error reintentable
        is_retryable = is_retryable_error(error)

        if is_retryable:
            self.retry_count += 1
            logger.warning(
                f"⚠️ [GEMINI RETRY] Error 500 detectado en session {session_id} "
                f"(error #{self.error_count}, retry #{self.retry_count})"
            )

            # Log detallado para diagnóstico
            log_context = {
                "session_id": session_id,
                "error_number": self.error_count,
                "retry_number": self.retry_count,
                **(context or {}),
            }
            log_500_error_details(error, log_context)
        else:
            logger.error(
                f"❌ [GEMINI ERROR] Error no reintentable en session {session_id}: "
                f"{type(error).__name__}"
            )

        return {
            "error_handled": True,
            "is_retryable": is_retryable,
            "error_count": self.error_count,
            "retry_count": self.retry_count,
            "session_id": session_id,
        }

    def get_error_stats(self) -> Dict[str, Any]:
        """
        Obtiene estadísticas de errores procesados.

        Returns:
            Dict con estadísticas de errores
        """
        return {
            "total_errors": self.error_count,
            "total_retries": self.retry_count,
            "last_error_time": self.last_error_time,
            "sessions_with_errors": len(self.session_errors),
            "retry_stats": get_retry_stats(),
        }

    def get_session_errors(self, session_id: str) -> list:
        """
        Obtiene historial de errores para una sesión específica.

        Args:
            session_id: ID de la sesión

        Returns:
            Lista de errores para esa sesión
        """
        return self.session_errors.get(session_id, [])

    def reset_stats(self):
        """Resetea estadísticas (útil para testing)"""
        self.error_count = 0
        self.retry_count = 0
        self.last_error_time = None
        self.session_errors = {}


# Instancia global de callbacks
gemini_retry_callbacks = GeminiRetryCallbacks()


def create_enhanced_error_handler(existing_handler=None):
    """
    Crea un manejador de errores mejorado que combina retry con handler existente.

    Args:
        existing_handler: Handler de errores existente (opcional)

    Returns:
        Nueva función handler que incluye retry
    """
    def enhanced_handler(error: Exception, context: Optional[Dict[str, Any]] = None):
        # Primero ejecutar el retry callback
        retry_result = gemini_retry_callbacks.on_error_callback(error, context)

        # Luego ejecutar el handler existente si hay uno
        if existing_handler:
            try:
                existing_result = existing_handler(error, context)
                # Combinar resultados
                return {**retry_result, "existing_handler_result": existing_result}
            except Exception as handler_error:
                logger.error(
                    f"❌ [ERROR HANDLER] Error en handler existente: {handler_error}"
                )
                return retry_result

        return retry_result

    return enhanced_handler


def log_retry_metrics():
    """
    Función helper para logear métricas de retry en formato legible.
    Útil para monitoreo y debugging.
    """
    stats = gemini_retry_callbacks.get_error_stats()

    logger.info("=" * 80)
    logger.info("📊 MÉTRICAS DE RETRY - GEMINI ERRORS")
    logger.info("=" * 80)
    logger.info(f"Total de errores: {stats['total_errors']}")
    logger.info(f"Total de retries: {stats['total_retries']}")
    logger.info(f"Sesiones con errores: {stats['sessions_with_errors']}")

    retry_stats = stats.get('retry_stats', {})
    if retry_stats:
        logger.info(f"Retries exitosos: {retry_stats.get('successful_retries', 0)}")
        logger.info(f"Retries fallidos: {retry_stats.get('failed_retries', 0)}")
        logger.info(f"Tasa de éxito: {retry_stats.get('success_rate', 0):.1f}%")

    logger.info("=" * 80)