"""
🔄 Wrapper de Retry para Agente ADK

Este módulo proporciona un wrapper que intercepta las llamadas al agente
y aplica retry automático cuando se detectan errores 500 de Gemini.

El wrapper se integra de manera transparente con el sistema de callbacks
existente del agente.
"""

import logging
from typing import AsyncGenerator, Any, Dict, Optional
from google.adk.agents import Agent
from .retry_handler import (
    is_retryable_error,
    calculate_backoff,
    log_500_error_details,
    retry_metrics,
    RetryConfig,
)
import asyncio
import time

logger = logging.getLogger(__name__)


class AgentRetryWrapper:
    """
    Wrapper que añade capacidad de retry al agente ADK.

    Este wrapper intercepta las llamadas run_async del agente y reintenta
    automáticamente cuando detecta errores 500 temporales.
    """

    def __init__(self, agent: Agent):
        """
        Inicializa el wrapper con un agente ADK.

        Args:
            agent: Instancia del agente ADK a wrappear
        """
        self.agent = agent
        self.retry_stats = {
            "total_requests": 0,
            "retried_requests": 0,
            "successful_retries": 0,
        }

    async def run_async_with_retry(
        self,
        *args,
        session_id: Optional[str] = None,
        query: Optional[str] = None,
        **kwargs
    ) -> AsyncGenerator[Any, None]:
        """
        Ejecuta el agente con retry automático para errores 500.

        Args:
            *args: Argumentos posicionales para el agente
            session_id: ID de sesión para logging
            query: Query del usuario para logging
            **kwargs: Argumentos keyword para el agente

        Yields:
            Eventos del agente (misma interfaz que run_async)
        """
        self.retry_stats["total_requests"] += 1
        last_error = None

        for attempt in range(RetryConfig.MAX_RETRIES + 1):
            try:
                if attempt > 0:
                    self.retry_stats["retried_requests"] += 1
                    logger.info(
                        f"🔄 [AGENT RETRY] Intento {attempt + 1}/{RetryConfig.MAX_RETRIES + 1} "
                        f"para session_id={session_id}"
                    )

                start_time = time.time()

                # Ejecutar el agente
                async for event in self.agent.run_async(*args, **kwargs):
                    yield event

                # Si llegamos aquí, fue exitoso
                if attempt > 0:
                    duration = time.time() - start_time
                    self.retry_stats["successful_retries"] += 1
                    retry_metrics.record_retry(True, duration)
                    logger.info(
                        f"✅ [AGENT RETRY] Intento {attempt + 1} exitoso después de {duration:.2f}s"
                    )

                return  # Salir exitosamente

            except Exception as e:
                last_error = e
                duration = time.time() - start_time if attempt > 0 else 0

                # Log detallado del error con contexto
                context = {
                    "session_id": session_id or "unknown",
                    "query": query or "unknown",
                    "attempt": attempt + 1,
                    "max_attempts": RetryConfig.MAX_RETRIES + 1,
                }

                # Verificar si es un error reintentable
                if not is_retryable_error(e):
                    logger.info(
                        f"❌ [AGENT RETRY] Error no reintentable: {type(e).__name__}"
                    )
                    log_500_error_details(e, context)
                    raise

                # Si agotamos los reintentos, fallar
                if attempt >= RetryConfig.MAX_RETRIES:
                    retry_metrics.record_retry(False, duration)
                    logger.error(
                        f"❌ [AGENT RETRY] Todos los intentos fallaron para session_id={session_id}"
                    )
                    log_500_error_details(e, context)
                    raise

                # Calcular backoff y esperar
                backoff_time = calculate_backoff(attempt)
                logger.warning(
                    f"⚠️ [AGENT RETRY] Intento {attempt + 1} falló: {type(e).__name__}"
                )
                logger.warning(
                    f"⏳ [AGENT RETRY] Esperando {backoff_time}s antes de reintentar..."
                )

                # Esperar antes del retry
                await asyncio.sleep(backoff_time)

                # Continuar al siguiente intento
                continue

        # Fallback final
        if last_error:
            raise last_error

    def get_stats(self) -> Dict[str, Any]:
        """
        Obtiene estadísticas del wrapper.

        Returns:
            Dict con estadísticas de retry del wrapper
        """
        return {
            **self.retry_stats,
            "retry_success_rate": (
                (self.retry_stats["successful_retries"] / self.retry_stats["retried_requests"] * 100)
                if self.retry_stats["retried_requests"] > 0
                else 0
            ),
        }


def create_agent_with_retry(agent: Agent) -> AgentRetryWrapper:
    """
    Factory function para crear un agente con capacidad de retry.

    Args:
        agent: Agente ADK original

    Returns:
        AgentRetryWrapper configurado
    """
    wrapper = AgentRetryWrapper(agent)
    logger.info("✅ [AGENT RETRY] Wrapper de retry inicializado")
    return wrapper