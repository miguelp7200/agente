"""
Sistema de retry con exponential backoff para errores de signed URLs.

Este módulo implementa lógica de reintento inteligente específicamente para
errores SignatureDoesNotMatch que, según el Byterover memory layer, se
resuelven después de un tiempo de espera.
"""

import time
import requests
import logging
from functools import wraps
from typing import Callable, Any, Optional, Union, Type
import inspect

logger = logging.getLogger(__name__)


def retry_on_signature_error(
    max_retries: int = 3,
    base_delay: int = 60,
    max_delay: int = 300,
    backoff_multiplier: float = 2.0,
    jitter: bool = True,
):
    """
    Decorator para retry automático en errores de signature mismatch.

    Este decorator detecta errores SignatureDoesNotMatch específicos de GCS
    y reintenta la operación con exponential backoff, dando tiempo para que
    el clock skew se resuelva naturalmente.

    Args:
        max_retries: Número máximo de reintentos (default: 3)
        base_delay: Delay base en segundos para primer retry (default: 60)
        max_delay: Delay máximo en segundos (default: 300 = 5min)
        backoff_multiplier: Multiplicador para exponential backoff (default: 2.0)
        jitter: Agregar jitter aleatorio para evitar thundering herd (default: True)

    Returns:
        Decorator que aplica lógica de retry

    Example:
        @retry_on_signature_error(max_retries=2, base_delay=90)
        def download_file(signed_url):
            response = requests.get(signed_url)
            response.raise_for_status()
            return response
    """

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            last_exception = None

            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)

                except Exception as e:
                    last_exception = e

                    # Verificar si es un error de signature que vale la pena reintentar
                    if _is_signature_error(e) and attempt < max_retries:
                        delay = _calculate_delay(
                            attempt, base_delay, backoff_multiplier, max_delay, jitter
                        )

                        logger.warning(
                            f"SignatureDoesNotMatch detectado en {func.__name__} "
                            f"(intento {attempt + 1}/{max_retries + 1}), "
                            f"reintentando en {delay}s"
                        )

                        time.sleep(delay)
                        continue

                    # Si no es error de signature o se agotaron reintentos
                    if attempt == max_retries:
                        logger.error(
                            f"Agotados reintentos para {func.__name__} después de "
                            f"{max_retries} intentos"
                        )
                        break

            # Re-lanzar la última excepción
            raise last_exception

        return wrapper

    return decorator


def _is_signature_error(exception: Exception) -> bool:
    """
    Detectar si una excepción es un error de signature mismatch de GCS.

    FASE 3: Mejorada detección con patrones adicionales de encoding,
    clock skew, y timeout específicos de GCS.

    Args:
        exception: Excepción a analizar

    Returns:
        True si es un error de signature que vale la pena reintentar
    """
    # Convertir excepción a string para análisis
    error_str = str(exception).lower()

    # Patrones de error que indican signature mismatch
    signature_error_patterns = [
        "signaturedoesnotmatch",
        "signature does not match",
        "the request signature we calculated does not match",
        "invalid signature",
        "expired signature",
        # FASE 3: Patrones adicionales de encoding y clock skew
        "access denied",
        "invalid unicode",
        "unicodeencodeerror",
        "clock skew",
        "request time too skewed",
        "requesttimetoskewed",
        # FASE 3: Timeouts que pueden indicar problemas de firma
        "connection timeout",
        "read timeout",
        "timed out",
    ]

    # Verificar patrones en el mensaje de error
    for pattern in signature_error_patterns:
        if pattern in error_str:
            logger.debug(f"Error de signature detectado: {pattern}")
            return True

    # Verificar en requests.exceptions específicos
    if isinstance(exception, requests.exceptions.HTTPError):
        if hasattr(exception, "response") and exception.response:
            response_text = exception.response.text.lower()
            for pattern in signature_error_patterns:
                if pattern in response_text:
                    logger.debug(f"Error de signature en respuesta HTTP: {pattern}")
                    return True

            # FASE 3: Verificar códigos de estado específicos
            # 403 (Forbidden) y 401 (Unauthorized) pueden ser por firma
            if hasattr(exception.response, "status_code"):
                if exception.response.status_code in [401, 403]:
                    logger.debug(
                        f"HTTP {exception.response.status_code} - posible error de signature"
                    )
                    return True

    # FASE 3: Detectar errores de timeout que pueden ser por clock skew
    if isinstance(exception, (requests.exceptions.Timeout, TimeoutError)):
        logger.debug("Timeout detectado - puede ser por clock skew")
        return True

    return False


def _calculate_delay(
    attempt: int, base_delay: int, multiplier: float, max_delay: int, jitter: bool
) -> float:
    """
    Calcular delay para exponential backoff con jitter opcional.

    Args:
        attempt: Número de intento (0-based)
        base_delay: Delay base en segundos
        multiplier: Multiplicador exponencial
        max_delay: Delay máximo permitido
        jitter: Si agregar jitter aleatorio

    Returns:
        Delay en segundos a esperar
    """
    import random

    # Calcular delay exponencial
    delay = base_delay * (multiplier**attempt)

    # Aplicar límite máximo
    delay = min(delay, max_delay)

    # Agregar jitter aleatorio (±25% del delay)
    if jitter:
        jitter_range = delay * 0.25
        delay += random.uniform(-jitter_range, jitter_range)
        delay = max(1, delay)  # Mínimo 1 segundo

    return delay


class RetryableSignedURLDownloader:
    """
    Clase para descargas con retry automático de signed URLs.

    Encapsula la lógica de descarga con manejo inteligente de errores
    de signature y retry exponencial automático.
    """

    def __init__(
        self,
        max_retries: int = 3,
        base_delay: int = 60,
        timeout: int = 30,
        max_delay: int = 300,
    ):
        """
        Inicializar downloader con configuración de retry.

        Args:
            max_retries: Máximo número de reintentos
            base_delay: Delay base para exponential backoff
            timeout: Timeout para requests HTTP
            max_delay: Delay máximo entre reintentos
        """
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.timeout = timeout
        self.max_delay = max_delay

        logger.info(
            f"RetryableSignedURLDownloader inicializado "
            f"(max_retries={max_retries}, base_delay={base_delay}s)"
        )

    @retry_on_signature_error(max_retries=3, base_delay=90)
    def download(self, signed_url: str) -> requests.Response:
        """
        Descargar archivo desde signed URL con retry automático.

        Args:
            signed_url: URL firmada de GCS

        Returns:
            requests.Response con el contenido descargado

        Raises:
            requests.exceptions.RequestException: Si falla la descarga

        Example:
            >>> downloader = RetryableSignedURLDownloader()
            >>> response = downloader.download(signed_url)
            >>> with open('archivo.pdf', 'wb') as f:
            ...     f.write(response.content)
        """
        logger.info(f"Descargando desde signed URL (timeout={self.timeout}s)")

        response = requests.get(signed_url, timeout=self.timeout)
        response.raise_for_status()

        logger.info(f"Descarga exitosa ({len(response.content)} bytes)")
        return response

    def download_to_file(self, signed_url: str, file_path: str) -> bool:
        """
        Descargar archivo directamente a disco.

        Args:
            signed_url: URL firmada de GCS
            file_path: Ruta donde guardar el archivo

        Returns:
            True si la descarga fue exitosa, False si no

        Example:
            >>> downloader = RetryableSignedURLDownloader()
            >>> success = downloader.download_to_file(signed_url, 'factura.pdf')
        """
        try:
            response = self.download(signed_url)

            with open(file_path, "wb") as f:
                f.write(response.content)

            logger.info(f"Archivo guardado exitosamente en {file_path}")
            return True

        except Exception as e:
            logger.error(f"Error descargando a {file_path}: {e}")
            return False


# Funciones de conveniencia
@retry_on_signature_error(max_retries=2, base_delay=90)
def download_from_signed_url(signed_url: str, timeout: int = 30) -> requests.Response:
    """
    Función de conveniencia para descarga simple con retry automático.

    Args:
        signed_url: URL firmada de GCS
        timeout: Timeout para la request

    Returns:
        requests.Response con el contenido

    Example:
        >>> response = download_from_signed_url(signed_url)
        >>> print(f"Descargado {len(response.content)} bytes")
    """
    response = requests.get(signed_url, timeout=timeout)
    response.raise_for_status()
    return response


if __name__ == "__main__":
    # Test del módulo
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    print("🔄 Testing sistema de retry para signed URLs...")

    # Test detector de errores de signature
    test_errors = [
        Exception(
            "SignatureDoesNotMatch: The request signature we calculated does not match"
        ),
        requests.exceptions.HTTPError("403 Forbidden"),
        Exception("Network timeout"),
    ]

    for i, error in enumerate(test_errors):
        is_signature = _is_signature_error(error)
        print(f"Error {i+1}: {error} -> Signature error: {is_signature}")

    # Test cálculo de delays
    for attempt in range(4):
        delay = _calculate_delay(attempt, 60, 2.0, 300, False)
        print(f"Intento {attempt}: delay = {delay:.1f}s")

    print("✅ Tests básicos completados")
