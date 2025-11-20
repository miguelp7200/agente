"""
Módulo de verificación de sincronización de tiempo con Google Cloud Storage.

Este módulo detecta diferencias de tiempo (clock skew) entre el servidor local
y los servidores de Google Cloud que pueden causar errores SignatureDoesNotMatch
en URLs firmadas.

Basándome en el Byterover memory layer, los errores de signature mismatch están
relacionados con desfases temporales que se resuelven después de 10-15 minutos.
"""

import time
import requests
import logging
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Optional, Tuple

from src.core.config import get_config

logger = logging.getLogger(__name__)


def verify_time_sync(timeout: Optional[int] = None) -> Optional[bool]:
    """
    Verificar sincronización de tiempo del servidor con Google Cloud.

    Compara el tiempo local con el tiempo reportado por Google Storage
    a través de headers HTTP para detectar clock skew que puede causar
    errores SignatureDoesNotMatch.

    Args:
        timeout: Timeout en segundos para la petición HTTP (None = usar config)

    Returns:
        True si el tiempo está sincronizado (< threshold diferencia)
        False si hay clock skew detectado (> threshold diferencia)
        None si no se pudo verificar (error de red)

    Example:
        >>> sync_status = verify_time_sync()
        >>> if sync_status is False:
        ...     print("Clock skew detectado - agregando buffer time")
    """
    if timeout is None:
        timeout = int(get_config().get("gcs.time_sync.check_timeout", 5))

    threshold = int(get_config().get("gcs.time_sync.threshold_seconds", 60))

    try:
        # Obtener tiempo de servidor de Google usando HEAD request
        response = requests.head("https://storage.googleapis.com", timeout=timeout)

        google_time_str = response.headers.get("date")
        if not google_time_str:
            logger.warning("No se encontró header 'date' en respuesta de Google")
            return None

        # Parsear tiempo de Google y obtener tiempo local
        google_dt = parsedate_to_datetime(google_time_str)
        local_dt = datetime.now(timezone.utc)

        # Calcular diferencia en segundos
        time_diff = abs((local_dt - google_dt).total_seconds())

        # Log de información de sincronización
        logger.info(
            f"Time sync check - Local: {local_dt.isoformat()}, "
            f"Google: {google_dt.isoformat()}, "
            f"Diff: {time_diff:.1f}s"
        )

        # Considerar sincronizado si diferencia < threshold
        if time_diff > threshold:
            logger.warning(
                f"Clock skew detectado: {time_diff:.1f} segundos de diferencia"
            )
            return False

        logger.info(f"Tiempo sincronizado correctamente ({time_diff:.1f}s diff)")
        return True

    except requests.exceptions.RequestException as e:
        logger.error(f"Error verificando sincronización de tiempo: {e}")
        return None
    except Exception as e:
        logger.error(f"Error inesperado en verificación de tiempo: {e}")
        return None


def get_time_sync_info(
    timeout: int = 5,
) -> Tuple[Optional[datetime], Optional[datetime], Optional[float]]:
    """
    Obtener información detallada de sincronización de tiempo.

    Args:
        timeout: Timeout en segundos para la petición HTTP

    Returns:
        Tupla con (tiempo_local, tiempo_google, diferencia_segundos)
        Valores pueden ser None si hay error

    Example:
        >>> local_time, google_time, diff = get_time_sync_info()
        >>> if diff and diff > 120:
        ...     print(f"Clock skew crítico: {diff} segundos")
    """
    try:
        response = requests.head("https://storage.googleapis.com", timeout=timeout)

        google_time_str = response.headers.get("date")
        if not google_time_str:
            return None, None, None

        google_dt = parsedate_to_datetime(google_time_str)
        local_dt = datetime.now(timezone.utc)
        time_diff = (
            local_dt - google_dt
        ).total_seconds()  # Positivo si local adelantado

        return local_dt, google_dt, time_diff

    except Exception as e:
        logger.error(f"Error obteniendo información de tiempo: {e}")
        return None, None, None


def calculate_buffer_time(sync_status: Optional[bool] = None) -> int:
    """
    Calcular tiempo de buffer recomendado basado en estado de sincronización.

    Args:
        sync_status: Resultado de verify_time_sync(), o None para verificar automáticamente

    Returns:
        Tiempo de buffer en minutos recomendado para signed URLs

    Example:
        >>> buffer_minutes = calculate_buffer_time()
        >>> expiration = datetime.utcnow() + timedelta(hours=1, minutes=buffer_minutes)
    """
    if sync_status is None:
        sync_status = verify_time_sync()

    # Get buffer times from config
    buffer_clock_skew = int(get_config().get("gcs.buffer_time.clock_skew_detected", 5))
    buffer_verification_failed = int(
        get_config().get("gcs.buffer_time.verification_failed", 3)
    )
    buffer_synchronized = int(get_config().get("gcs.buffer_time.synchronized", 1))

    if sync_status is False:
        # Clock skew detectado - usar buffer grande
        logger.info(
            f"Clock skew detectado - usando buffer de {buffer_clock_skew} minutos"
        )
        return buffer_clock_skew
    elif sync_status is None:
        # No se pudo verificar - usar buffer moderado por precaución
        logger.info(
            f"No se pudo verificar tiempo - usando buffer de {buffer_verification_failed} minutos"
        )
        return buffer_verification_failed
    else:
        # Tiempo sincronizado - usar buffer mínimo
        logger.info(
            f"Tiempo sincronizado - usando buffer de {buffer_synchronized} minuto"
        )
        return buffer_synchronized


if __name__ == "__main__":
    # Test del módulo
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    print("🕐 Testing verificación de tiempo...")

    # Test básico de sincronización
    sync_result = verify_time_sync()
    print(f"Resultado sincronización: {sync_result}")

    # Test información detallada
    local_time, google_time, diff = get_time_sync_info()
    if all(v is not None for v in [local_time, google_time, diff]):
        print(f"Tiempo local: {local_time}")
        print(f"Tiempo Google: {google_time}")
        print(f"Diferencia: {diff:.1f}s")

    # Test cálculo de buffer
    buffer = calculate_buffer_time(sync_result)
    print(f"Buffer recomendado: {buffer} minutos")
