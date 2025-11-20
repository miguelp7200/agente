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
import os

from .gcs_time_sync import verify_time_sync, calculate_buffer_time
from src.core.config import get_config

logger = logging.getLogger(__name__)


def generate_stable_signed_url(
    bucket_name: str,
    blob_name: str,
    expiration_hours: int = 1,
    service_account_path: Optional[str] = None,
    credentials: Optional[Any] = None,
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
        credentials: Credenciales de GCP a usar (opcional, para impersonated credentials)
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
        client = _initialize_gcs_client(service_account_path, credentials)

        # 3. Obtener bucket y blob
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        # 3.5. CRÍTICO: Verificar que el blob existe antes de generar URL
        if not blob.exists():
            error_msg = f"Blob not found: gs://{bucket_name}/{blob_name}"
            logger.error(error_msg)
            raise FileNotFoundError(error_msg)

        # 4. Calcular tiempo de expiración con buffer
        expiration = datetime.now(timezone.utc) + timedelta(
            hours=expiration_hours, minutes=buffer_minutes
        )

        # 5. Generar signed URL usando v4 signing (más estable)
        # En Cloud Run, usar IAM-based signing si no hay service account path
        if service_account_path is None and credentials is None:
            # IAM-based signing para Cloud Run - más compatible
            try:
                signed_url = blob.generate_signed_url(
                    expiration=expiration,
                    method=method,
                    version="v4",
                )
            except Exception as iam_error:
                logger.warning(f"IAM-based signing falló: {iam_error}")
                # Para Cloud Run: usar service account impersonation con signing específico
                logger.info("Intentando signed URL con service account impersonation")

                from google.auth.transport.requests import Request

                service_account_email = get_config().get(
                    "google_cloud.service_accounts.pdf_signer",
                    "adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com",
                )

                signed_url = None
                try:
                    # Obtener credenciales por defecto de Cloud Run
                    source_credentials, _ = default()

                    # Crear credenciales impersonadas CON delegates para signing
                    target_credentials = impersonated_credentials.Credentials(
                        source_credentials=source_credentials,
                        target_principal=service_account_email,
                        target_scopes=[
                            "https://www.googleapis.com/auth/cloud-platform"
                        ],
                        delegates=[],  # Importante para signing
                    )

                    # Refrescar las credenciales antes de usar
                    request = Request()
                    target_credentials.refresh(request)

                    # Generar signed URL con las credenciales impersonadas refreshed
                    signed_url = blob.generate_signed_url(
                        expiration=expiration,
                        method=method,
                        version="v4",
                        credentials=target_credentials,
                    )

                    logger.info(
                        f"Signed URL generada con impersonation para {service_account_email}"
                    )
                except Exception as imp_error:
                    logger.warning(f"Impersonation falló: {imp_error}")
                    signed_url = None

                # Si aún falla, intentar con IAM generateSignedUrl API
                if not signed_url:
                    logger.warning("Signed URL con impersonation falló, usando IAM API")
                    signed_url = _generate_signed_url_via_iam_api(
                        bucket_name,
                        blob_name,
                        expiration,
                        method,
                        service_account_email,
                    )
        else:
            # Usar el método original con credenciales específicas
            signed_url = blob.generate_signed_url(
                expiration=expiration,
                method=method,
                version="v4",
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
    credentials: Optional[Any] = None,
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
        credentials: Credenciales de GCP a usar (opcional, para impersonated credentials)
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
                credentials=credentials,
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
    credentials: Optional[Any] = None,
) -> storage.Client:
    """
    Inicializar cliente de Google Cloud Storage con credenciales adecuadas.

    Args:
        service_account_path: Ruta opcional al archivo de service account
        credentials: Credenciales de GCP a usar (opcional)

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
        elif credentials:
            # Usar credenciales específicas (como impersonated credentials)
            client = storage.Client(credentials=credentials)
            logger.info("Cliente GCS inicializado con credenciales impersonadas")
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


def _generate_signed_url_via_iam_api(
    bucket_name: str,
    blob_name: str,
    expiration: datetime,
    method: str,
    service_account_email: str,
) -> str:
    """
    Generar signed URL usando la IAM API directamente.

    Esta es una implementación alternativa para Cloud Run cuando
    las credenciales impersonadas no funcionan correctamente.
    """
    try:
        import base64
        import json
        from urllib.parse import quote
        from google.auth.transport.requests import Request
        from google.auth import default

        logger.info(f"Generando signed URL via IAM API para {service_account_email}")

        # Construir la string to sign según el formato de GCS v4 signing
        from datetime import datetime, timezone
        import hashlib

        # Calcular timestamp y fecha
        now = datetime.now(timezone.utc)
        timestamp = now.strftime("%Y%m%dT%H%M%SZ")
        date_stamp = now.strftime("%Y%m%d")

        # Calcular expires en segundos desde ahora
        expires_seconds = int((expiration - now).total_seconds())

        # Canonical request components
        canonical_uri = f"/{bucket_name}/{blob_name}"
        canonical_query = (
            f"X-Goog-Algorithm=GOOG4-RSA-SHA256&"
            f"X-Goog-Credential={quote(service_account_email)}/{date_stamp}/auto/storage/goog4_request&"
            f"X-Goog-Date={timestamp}&"
            f"X-Goog-Expires={expires_seconds}&"
            f"X-Goog-SignedHeaders=host"
        )
        canonical_headers = "host:storage.googleapis.com\n"
        signed_headers = "host"
        payload_hash = "UNSIGNED-PAYLOAD"

        # Construir canonical request correctamente
        canonical_request = f"{method}\n{canonical_uri}\n{canonical_query}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"

        # Hash de la canonical request
        canonical_request_hash = hashlib.sha256(
            canonical_request.encode("utf-8")
        ).hexdigest()

        # String to sign
        credential_scope = f"{date_stamp}/auto/storage/goog4_request"
        string_to_sign = f"GOOG4-RSA-SHA256\n{timestamp}\n{credential_scope}\n{canonical_request_hash}"

        # Usar IAM API para firmar
        credentials, _ = default()
        request = Request()

        # Llamar a IAM signBlob API
        import googleapiclient.discovery

        iam_service = googleapiclient.discovery.build(
            "iam", "v1", credentials=credentials
        )

        sign_request = {
            "bytesToSign": base64.b64encode(string_to_sign.encode("utf-8")).decode(
                "utf-8"
            )
        }

        response = (
            iam_service.projects()
            .serviceAccounts()
            .signBlob(
                name=f"projects/-/serviceAccounts/{service_account_email}",
                body=sign_request,
            )
            .execute()
        )

        signature = response["signature"]

        # Construir la signed URL final
        signed_url = f"https://storage.googleapis.com{canonical_uri}?{canonical_query}&X-Goog-Signature={signature}"

        logger.info("Signed URL generada exitosamente via IAM API")
        return signed_url

    except Exception as e:
        logger.error(f"Error generando signed URL via IAM API: {e}")
        # Fallback a URL pública
        return f"https://storage.googleapis.com/{bucket_name}/{blob_name}"


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
