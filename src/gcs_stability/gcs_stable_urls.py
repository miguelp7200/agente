"""
Módulo de generación robusta de signed URLs para Google Cloud Storage.

Este módulo implementa generación de URLs firmadas con compensación automática
de clock skew y uso de v4 signing para mejor compatibilidad y estabilidad.

Basándome en el Byterover memory layer, los errores SignatureDoesNotMatch
se resuelven con buffer time adecuado y detección de desfases temporales.
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
from google.cloud import storage
from google.auth import default, impersonated_credentials
import google.auth.exceptions

from .gcs_time_sync import verify_time_sync, calculate_buffer_time

logger = logging.getLogger(__name__)


def generate_stable_signed_url(
    bucket_name: str,
    blob_name: str,
    expiration_hours: int = 1,
    service_account_path: Optional[str] = None,
    method: str = "GET",
    force_buffer_minutes: Optional[int] = None,
) -> str:
    """
    Generar signed URL estable con compensación automática de clock skew.

    Esta función mejora la estabilidad de signed URLs detectando clock skew
    y aplicando buffer time automático para evitar errores SignatureDoesNotMatch.

    Args:
        bucket_name: Nombre del bucket de GCS
        blob_name: Nombre del archivo/blob
        expiration_hours: Horas de validez de la URL (default: 1)
        service_account_path: Ruta al archivo de service account (opcional)
        method: Método HTTP ('GET', 'POST', etc.)
        force_buffer_minutes: Forzar buffer específico en minutos (opcional)

    Returns:
        URL firmada estable con compensación de clock skew

    Raises:
        Exception: Si falla la generación de la URL

    Example:
        >>> url = generate_stable_signed_url('mi-bucket', 'archivo.pdf')
        >>> # URL con buffer automático basado en sync de tiempo
    """
    try:
        # 1. Verificar sincronización de tiempo si no se fuerza buffer
        if force_buffer_minutes is None:
            sync_status = verify_time_sync()
            buffer_minutes = calculate_buffer_time(sync_status)

            if sync_status is False:
                logger.warning(
                    f"Clock skew detectado - agregando buffer de {buffer_minutes} minutos"
                )
            elif sync_status is None:
                logger.info(
                    f"No se pudo verificar tiempo - usando buffer de {buffer_minutes} minutos"
                )
        else:
            buffer_minutes = force_buffer_minutes
            logger.info(f"Usando buffer forzado de {buffer_minutes} minutos")

        # 2. Inicializar cliente GCS con credenciales adecuadas
        client = _initialize_gcs_client(service_account_path)

        # 3. Obtener bucket y blob
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        # 4. Calcular tiempo de expiración con buffer
        expiration = datetime.now(timezone.utc) + timedelta(
            hours=expiration_hours, minutes=buffer_minutes
        )

        # 5. Generar signed URL usando v4 signing (más estable)
        signed_url = blob.generate_signed_url(
            expiration=expiration,
            method=method,
            version="v4",  # v4 signing es más robusto
        )

        logger.info(
            f"Generated stable signed URL for {blob_name} "
            f"(expires: {expiration.isoformat()}, buffer: {buffer_minutes}m)"
        )

        return signed_url

    except Exception as e:
        logger.error(f"Error generando signed URL para {blob_name}: {e}")
        raise


def generate_stable_signed_urls_batch(
    bucket_name: str,
    blob_names: list[str],
    expiration_hours: int = 1,
    service_account_path: Optional[str] = None,
    method: str = "GET",
) -> Dict[str, Optional[str]]:
    """
    Generar múltiples signed URLs de forma eficiente.

    Optimiza la generación de múltiples URLs verificando el tiempo una sola vez
    y reutilizando el buffer calculado para todas las URLs.

    Args:
        bucket_name: Nombre del bucket de GCS
        blob_names: Lista de nombres de archivos/blobs
        expiration_hours: Horas de validez de las URLs
        service_account_path: Ruta al archivo de service account (opcional)
        method: Método HTTP para las URLs

    Returns:
        Diccionario {blob_name: signed_url} con URLs generadas
        None en el diccionario indica error para ese blob específico

    Example:
        >>> urls = generate_stable_signed_urls_batch(
        ...     'mi-bucket',
        ...     ['file1.pdf', 'file2.pdf']
        ... )
        >>> for blob, url in urls.items():
        ...     if url:
        ...         print(f"{blob}: {url}")
    """
    logger.info(
        f"Generando {len(blob_names)} signed URLs en batch para bucket {bucket_name}"
    )

    # Verificar tiempo una vez para toda la operación batch
    sync_status = verify_time_sync()
    buffer_minutes = calculate_buffer_time(sync_status)

    if sync_status is False:
        logger.warning(
            f"Clock skew detectado - usando buffer de {buffer_minutes}m para batch"
        )

    urls = {}
    successful = 0

    for blob_name in blob_names:
        try:
            url = generate_stable_signed_url(
                bucket_name=bucket_name,
                blob_name=blob_name,
                expiration_hours=expiration_hours,
                service_account_path=service_account_path,
                method=method,
                force_buffer_minutes=buffer_minutes,  # Reutilizar buffer calculado
            )
            urls[blob_name] = url
            successful += 1

        except Exception as e:
            logger.error(f"Error generando URL para {blob_name}: {e}")
            urls[blob_name] = None

    logger.info(
        f"Batch completado: {successful}/{len(blob_names)} URLs generadas exitosamente"
    )
    return urls


def _initialize_gcs_client(
    service_account_path: Optional[str] = None,
) -> storage.Client:
    """
    Inicializar cliente de Google Cloud Storage con credenciales adecuadas.

    Args:
        service_account_path: Ruta opcional al archivo de service account

    Returns:
        Cliente de GCS configurado

    Raises:
        Exception: Si falla la inicialización de credenciales
    """
    try:
        if service_account_path:
            # Usar service account específico
            client = storage.Client.from_service_account_json(service_account_path)
            logger.info(
                f"Cliente GCS inicializado con service account: {service_account_path}"
            )
        else:
            # Usar credenciales por defecto (ADC)
            client = storage.Client()
            logger.info("Cliente GCS inicializado con credenciales por defecto")

        return client

    except google.auth.exceptions.DefaultCredentialsError as e:
        logger.error(f"Error de credenciales por defecto: {e}")
        raise
    except Exception as e:
        logger.error(f"Error inicializando cliente GCS: {e}")
        raise


def validate_signed_url_format(signed_url: str) -> bool:
    """
    Validar formato básico de signed URL de GCS.

    Args:
        signed_url: URL firmada a validar

    Returns:
        True si el formato es válido, False si no

    Example:
        >>> is_valid = validate_signed_url_format(signed_url)
        >>> if not is_valid:
        ...     print("URL firmada tiene formato inválido")
    """
    if not signed_url or not isinstance(signed_url, str):
        return False

    # Verificar componentes básicos de signed URL de GCS
    required_components = [
        "storage.googleapis.com",
        "X-Goog-Algorithm=",
        "X-Goog-Credential=",
        "X-Goog-Date=",
        "X-Goog-Expires=",
        "X-Goog-Signature=",
    ]

    return all(component in signed_url for component in required_components)


if __name__ == "__main__":
    # Test del módulo
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    print("🔗 Testing generación de signed URLs estables...")

    # Ejemplo de uso (requiere configuración de GCS)
    try:
        # Test con un bucket y blob de ejemplo
        bucket_name = "ejemplo-bucket"
        blob_name = "ejemplo-archivo.pdf"

        print(f"Generando URL para {bucket_name}/{blob_name}...")

        # Nota: esto requiere credenciales y bucket real para funcionar
        # url = generate_stable_signed_url(bucket_name, blob_name)
        # print(f"URL generada: {url}")

        # Test de validación de formato
        test_url = "https://storage.googleapis.com/bucket/file?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=test&X-Goog-Date=test&X-Goog-Expires=3600&X-Goog-Signature=test"
        is_valid = validate_signed_url_format(test_url)
        print(f"Formato de URL de prueba válido: {is_valid}")

    except Exception as e:
        print(f"Error en test: {e}")
        print("Nota: Se requieren credenciales y bucket válido para test completo")
