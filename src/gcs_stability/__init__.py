"""
Google Cloud Storage Stability Improvements

Módulo para resolver problemas de estabilidad con signed URLs de GCS,
incluyendo detección de clock skew, retry logic y monitoreo.

Este módulo implementa mejoras de estabilidad basadas en el análisis de errores
SignatureDoesNotMatch que ocurren por clock skew entre el servidor local y
los servidores de Google Cloud.
"""

from .gcs_time_sync import verify_time_sync
from .gcs_stable_urls import generate_stable_signed_url
from .gcs_retry_logic import retry_on_signature_error
from .signed_url_service import SignedURLService
from .gcs_monitoring import setup_signed_url_monitoring
from .environment_config import configure_environment, get_environment_status

__version__ = "1.0.0"
__all__ = [
    "verify_time_sync",
    "generate_stable_signed_url",
    "retry_on_signature_error",
    "SignedURLService",
    "setup_signed_url_monitoring",
    "configure_environment",
    "get_environment_status",
]
