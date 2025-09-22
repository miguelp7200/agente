"""
Servicio centralizado para manejo estable de URLs firmadas de Google Cloud Storage.

Esta clase encapsula toda la lógica de generación, validación y descarga de signed URLs
con las mejoras de estabilidad implementadas en los otros módulos.

Según el Byterover memory layer, esta implementación resuelve los errores intermitentes
SignatureDoesNotMatch mediante una aproximación integral y robusta.
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime, timezone
import json

from .gcs_time_sync import verify_time_sync, get_time_sync_info
from .gcs_stable_urls import (
    generate_stable_signed_url,
    generate_stable_signed_urls_batch,
    validate_signed_url_format,
)
from .gcs_retry_logic import RetryableSignedURLDownloader

logger = logging.getLogger(__name__)


class SignedURLService:
    """
    Servicio centralizado para manejo estable de URLs firmadas de GCS.

    Esta clase combina todos los módulos de estabilidad en una interfaz
    coherente y fácil de usar que resuelve los problemas de clock skew
    y errores SignatureDoesNotMatch.

    Example:
        >>> service = SignedURLService(service_account_path="path/to/key.json")
        >>> url = service.generate_download_url("mi-bucket", "archivo.pdf")
        >>> response = service.download_with_retry(url)
    """

    def __init__(
        self,
        service_account_path: Optional[str] = None,
        default_expiration_hours: int = 1,
        max_retries: int = 3,
        enable_monitoring: bool = True,
    ):
        """
        Inicializar servicio de signed URLs.

        Args:
            service_account_path: Ruta al archivo de service account (opcional)
            default_expiration_hours: Horas de expiración por defecto
            max_retries: Número máximo de reintentos para descargas
            enable_monitoring: Si habilitar logging estructurado
        """
        self.service_account_path = service_account_path
        self.default_expiration_hours = default_expiration_hours
        self.max_retries = max_retries
        self.enable_monitoring = enable_monitoring

        # Inicializar downloader con retry
        self.downloader = RetryableSignedURLDownloader(
            max_retries=max_retries,
            base_delay=90,  # Delay base más largo para signed URLs
            timeout=60,  # Timeout más largo para archivos grandes
        )

        # Estadísticas del servicio
        self.stats = {
            "urls_generated": 0,
            "downloads_successful": 0,
            "downloads_failed": 0,
            "clock_skew_detected": 0,
            "retries_triggered": 0,
        }

        logger.info(
            f"SignedURLService inicializado "
            f"(expiration={default_expiration_hours}h, retries={max_retries})"
        )

    def generate_download_url(
        self,
        bucket_name: str,
        blob_name: str,
        expiration_hours: Optional[int] = None,
        check_format: bool = True,
    ) -> str:
        """
        Generar URL de descarga estable para un archivo.

        Args:
            bucket_name: Nombre del bucket de GCS
            blob_name: Nombre del archivo/blob
            expiration_hours: Horas de expiración (usa default si None)
            check_format: Si validar formato de la URL generada

        Returns:
            URL firmada estable

        Raises:
            Exception: Si falla la generación o validación

        Example:
            >>> url = service.generate_download_url("bucket", "file.pdf")
        """
        start_time = datetime.now(timezone.utc)

        try:
            expiration = expiration_hours or self.default_expiration_hours

            # Generar URL con mejoras de estabilidad
            signed_url = generate_stable_signed_url(
                bucket_name=bucket_name,
                blob_name=blob_name,
                expiration_hours=expiration,
                service_account_path=self.service_account_path,
            )

            # Validar formato si se solicita
            if check_format and not validate_signed_url_format(signed_url):
                raise ValueError(
                    f"URL generada tiene formato inválido: {signed_url[:100]}..."
                )

            # Actualizar estadísticas
            self.stats["urls_generated"] += 1

            # Log de monitoreo
            if self.enable_monitoring:
                generation_time = (
                    datetime.now(timezone.utc) - start_time
                ).total_seconds()
                self._log_url_generation(bucket_name, blob_name, generation_time, True)

            return signed_url

        except Exception as e:
            if self.enable_monitoring:
                generation_time = (
                    datetime.now(timezone.utc) - start_time
                ).total_seconds()
                self._log_url_generation(
                    bucket_name, blob_name, generation_time, False, str(e)
                )
            raise

    def generate_batch_urls(
        self,
        bucket_name: str,
        blob_names: List[str],
        expiration_hours: Optional[int] = None,
    ) -> Dict[str, Optional[str]]:
        """
        Generar múltiples URLs de descarga de forma eficiente.

        Args:
            bucket_name: Nombre del bucket de GCS
            blob_names: Lista de nombres de archivos
            expiration_hours: Horas de expiración (usa default si None)

        Returns:
            Diccionario {blob_name: signed_url}, None si error

        Example:
            >>> urls = service.generate_batch_urls("bucket", ["f1.pdf", "f2.pdf"])
            >>> successful_urls = {k: v for k, v in urls.items() if v is not None}
        """
        start_time = datetime.now(timezone.utc)

        try:
            expiration = expiration_hours or self.default_expiration_hours

            # Generar URLs en batch
            urls = generate_stable_signed_urls_batch(
                bucket_name=bucket_name,
                blob_names=blob_names,
                expiration_hours=expiration,
                service_account_path=self.service_account_path,
            )

            # Actualizar estadísticas
            successful_count = sum(1 for url in urls.values() if url is not None)
            self.stats["urls_generated"] += successful_count

            # Log de monitoreo
            if self.enable_monitoring:
                batch_time = (datetime.now(timezone.utc) - start_time).total_seconds()
                self._log_batch_generation(
                    bucket_name, len(blob_names), successful_count, batch_time
                )

            return urls

        except Exception as e:
            logger.error(f"Error en generación batch para bucket {bucket_name}: {e}")
            return {blob_name: None for blob_name in blob_names}

    def download_with_retry(self, signed_url: str) -> bytes:
        """
        Descargar archivo con retry automático.

        Args:
            signed_url: URL firmada de GCS

        Returns:
            Contenido del archivo en bytes

        Raises:
            Exception: Si falla la descarga después de todos los reintentos

        Example:
            >>> content = service.download_with_retry(signed_url)
            >>> with open('archivo.pdf', 'wb') as f:
            ...     f.write(content)
        """
        start_time = datetime.now(timezone.utc)

        try:
            response = self.downloader.download(signed_url)
            content = response.content

            # Actualizar estadísticas
            self.stats["downloads_successful"] += 1

            # Log de monitoreo
            if self.enable_monitoring:
                download_time = (
                    datetime.now(timezone.utc) - start_time
                ).total_seconds()
                self._log_download(signed_url, len(content), download_time, True)

            return content

        except Exception as e:
            self.stats["downloads_failed"] += 1

            if self.enable_monitoring:
                download_time = (
                    datetime.now(timezone.utc) - start_time
                ).total_seconds()
                self._log_download(signed_url, 0, download_time, False, str(e))

            raise

    def download_to_file(self, signed_url: str, file_path: str) -> bool:
        """
        Descargar archivo directamente a disco.

        Args:
            signed_url: URL firmada de GCS
            file_path: Ruta donde guardar el archivo

        Returns:
            True si exitoso, False si falló

        Example:
            >>> success = service.download_to_file(signed_url, "factura.pdf")
        """
        return self.downloader.download_to_file(signed_url, file_path)

    def validate_and_download(self, signed_url: str) -> bytes:
        """
        Validar formato de URL y descargar con retry.

        Args:
            signed_url: URL firmada a validar y descargar

        Returns:
            Contenido del archivo

        Raises:
            ValueError: Si el formato de URL es inválido
            Exception: Si falla la descarga
        """
        if not validate_signed_url_format(signed_url):
            raise ValueError(f"Formato de signed URL inválido")

        return self.download_with_retry(signed_url)

    def get_time_sync_status(self) -> Dict[str, Any]:
        """
        Obtener estado actual de sincronización de tiempo.

        Returns:
            Diccionario con información de sincronización

        Example:
            >>> status = service.get_time_sync_status()
            >>> if not status['is_synced']:
            ...     print("Clock skew detectado!")
        """
        local_time, google_time, diff = get_time_sync_info()
        sync_status = verify_time_sync()

        return {
            "is_synced": sync_status,
            "local_time": local_time.isoformat() if local_time else None,
            "google_time": google_time.isoformat() if google_time else None,
            "time_difference_seconds": diff,
            "clock_skew_detected": sync_status is False,
            "check_timestamp": datetime.now(timezone.utc).isoformat(),
        }

    def get_service_stats(self) -> Dict[str, Any]:
        """
        Obtener estadísticas del servicio.

        Returns:
            Diccionario con estadísticas de uso
        """
        return {
            **self.stats,
            "success_rate": (
                self.stats["downloads_successful"]
                / max(
                    1,
                    self.stats["downloads_successful"] + self.stats["downloads_failed"],
                )
            )
            * 100,
            "service_uptime": datetime.now(timezone.utc).isoformat(),
        }

    def _log_url_generation(
        self,
        bucket: str,
        blob: str,
        duration: float,
        success: bool,
        error: Optional[str] = None,
    ):
        """Log estructurado para generación de URLs."""
        log_data = {
            "event": "url_generation",
            "bucket": bucket,
            "blob": blob,
            "duration_seconds": round(duration, 3),
            "success": success,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        if error:
            log_data["error"] = error

        if success:
            logger.info(f"URL generated: {json.dumps(log_data)}")
        else:
            logger.error(f"URL generation failed: {json.dumps(log_data)}")

    def _log_batch_generation(
        self, bucket: str, total_count: int, success_count: int, duration: float
    ):
        """Log estructurado para generación batch."""
        log_data = {
            "event": "batch_url_generation",
            "bucket": bucket,
            "total_urls": total_count,
            "successful_urls": success_count,
            "success_rate": (success_count / total_count) * 100,
            "duration_seconds": round(duration, 3),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        logger.info(f"Batch URLs generated: {json.dumps(log_data)}")

    def _log_download(
        self,
        url: str,
        size: int,
        duration: float,
        success: bool,
        error: Optional[str] = None,
    ):
        """Log estructurado para descargas."""
        # Truncar URL para logging
        url_truncated = url[:100] + "..." if len(url) > 100 else url

        log_data = {
            "event": "file_download",
            "url": url_truncated,
            "size_bytes": size,
            "duration_seconds": round(duration, 3),
            "success": success,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        if error:
            log_data["error"] = error

        if success:
            logger.info(f"Download completed: {json.dumps(log_data)}")
        else:
            logger.error(f"Download failed: {json.dumps(log_data)}")


if __name__ == "__main__":
    # Test del servicio
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    print("🎯 Testing SignedURLService...")

    # Crear instancia del servicio
    service = SignedURLService(
        default_expiration_hours=1, max_retries=2, enable_monitoring=True
    )

    # Test estado de sincronización
    sync_status = service.get_time_sync_status()
    print(f"Estado de sincronización: {sync_status}")

    # Test estadísticas
    stats = service.get_service_stats()
    print(f"Estadísticas del servicio: {stats}")

    print("✅ SignedURLService inicializado correctamente")
