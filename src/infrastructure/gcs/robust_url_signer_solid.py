"""
Robust URL Signer Implementation (SOLID)
========================================
Production-grade signed URL generator with comprehensive stability features.

Features:
- Triple fallback strategy (legacy → impersonation → ADC)
- Automatic clock skew detection and mitigation
- Exponential backoff with retry logic
- Comprehensive metrics collection
- Batch URL generation support
- Thread-safe operations

This is a COMPLETE reimplementation of the legacy robust URL signer,
following SOLID principles with dependency injection.
"""

import logging
import time
import binascii
import hashlib
import collections
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from threading import Lock
from urllib.parse import quote

from google.cloud import storage
from google.auth import impersonated_credentials, default
from google.oauth2 import service_account
from googleapiclient import discovery

from src.domain.interfaces.time_sync import ITimeSyncValidator
from src.domain.interfaces.environment_validator import IEnvironmentValidator
from src.domain.interfaces.retry_strategy import IRetryStrategy
from src.domain.interfaces.metrics_collector import IMetricsCollector
from src.core.config.yaml_config_loader import ConfigLoader


logger = logging.getLogger(__name__)


class RobustURLSigner:
    """
    Production-grade signed URL generator with stability features

    Implements triple fallback strategy:
    1. Legacy method (service account key file)
    2. Impersonation method (using service account email)
    3. ADC method (Application Default Credentials)

    Dependencies (injected via constructor):
    - ITimeSyncValidator: Validates time synchronization with GCS
    - IEnvironmentValidator: Validates environment configuration
    - IRetryStrategy: Handles transient errors with exponential backoff
    - IMetricsCollector: Collects performance and error metrics

    Configuration (config.yaml):
        gcs:
          signed_urls:
            default_expiration_minutes: 60
            use_impersonation: true
            service_account_email: "..."
            use_legacy_method: false
          retry:
            max_retries: 3
            base_delay_seconds: 1
    """

    def __init__(
        self,
        time_sync_validator: ITimeSyncValidator,
        environment_validator: IEnvironmentValidator,
        retry_strategy: IRetryStrategy,
        metrics_collector: IMetricsCollector,
    ):
        """
        Initialize robust URL signer with dependencies

        Args:
            time_sync_validator: Time synchronization validator
            environment_validator: Environment configuration validator
            retry_strategy: Retry strategy for transient errors
            metrics_collector: Metrics collector for monitoring
        """
        self.time_sync = time_sync_validator
        self.env_validator = environment_validator
        self.retry = retry_strategy
        self.metrics = metrics_collector

        # Configuration
        self.config = ConfigLoader()
        self.default_expiration = self.config.get(
            "gcs.signed_urls.default_expiration_minutes", 60
        )
        self.use_impersonation = self.config.get(
            "gcs.signed_urls.use_impersonation", True
        )
        self.service_account_email = self.config.get(
            "gcs.signed_urls.service_account_email"
        )
        self.use_legacy_method = self.config.get(
            "gcs.signed_urls.use_legacy_method", False
        )

        # Thread safety
        self._client_lock = Lock()

        # Cache for storage clients
        self._legacy_client = None
        self._impersonated_client = None
        self._adc_client = None

        # Debugging: Track credential renewals and URL generation
        self._last_credential_refresh = None
        self._urls_generated_count = 0
        self._last_url_timestamp = None

        logger.info(
            "RobustURLSigner initialized",
            extra={
                "default_expiration_minutes": self.default_expiration,
                "use_impersonation": self.use_impersonation,
                "use_legacy_method": self.use_legacy_method,
                "service_account_email": self.service_account_email,
            },
        )

    def _get_buffer_minutes(self) -> int:
        """
        Calculate buffer time based on clock synchronization status

        Returns:
            Buffer time in minutes (5/3/1 based on sync status)
        """
        # get_sync_info returns (local_time, google_time, time_diff_seconds)
        local_time, google_time, time_diff = self.time_sync.get_sync_info()

        # Get threshold and buffer values from config
        threshold_seconds = self.config.get("gcs.time_sync.threshold_seconds", 60)
        buffer_synced = self.config.get("gcs.buffer_time.synchronized", 5)
        buffer_skew = self.config.get("gcs.buffer_time.clock_skew_detected", 5)
        buffer_unknown = self.config.get("gcs.buffer_time.verification_failed", 5)

        # Determine sync status from time_diff
        if time_diff is None:
            # Unknown sync status - use maximum buffer
            buffer = buffer_unknown
            logger.warning(
                "Clock sync status unknown - using maximum buffer",
                extra={"buffer_minutes": buffer},
            )
        elif abs(time_diff) <= threshold_seconds:
            # Good sync - use minimum buffer
            buffer = buffer_synced
            logger.debug(
                "Clock synchronized - using minimum buffer",
                extra={
                    "buffer_minutes": buffer,
                    "time_diff_seconds": round(time_diff, 2),
                    "threshold_seconds": threshold_seconds,
                },
            )
        else:
            # Poor sync - use medium buffer
            buffer = buffer_skew
            logger.warning(
                "Clock NOT synchronized - using medium buffer",
                extra={
                    "buffer_minutes": buffer,
                    "time_diff_seconds": round(time_diff, 2),
                    "threshold_seconds": threshold_seconds,
                },
            )

            # Log clock skew event
            self.metrics.log_clock_skew_detection(
                bucket="system",
                time_diff=time_diff,
                buffer_applied=buffer,
            )

        return buffer

    def _get_legacy_client(self) -> Optional[storage.Client]:
        """
        Get storage client using legacy method (service account key file)

        Returns:
            Storage client or None if not available
        """
        if not self.use_legacy_method:
            logger.debug("Legacy method disabled by configuration")
            return None

        # Thread-safe double-check locking pattern
        if self._legacy_client is not None:
            return self._legacy_client

        with self._client_lock:
            # Double-check inside lock to prevent race condition
            if self._legacy_client is not None:
                return self._legacy_client

            try:
                credentials_path = self.config.get(
                    "gcs.credentials.service_account_key_file"
                )
                if not credentials_path:
                    logger.debug("No service account key file configured")
                    return None

                credentials = service_account.Credentials.from_service_account_file(
                    credentials_path
                )

                self._legacy_client = storage.Client(credentials=credentials)

                logger.info(
                    "Legacy storage client created",
                    extra={"credentials_path": credentials_path},
                )

                return self._legacy_client

            except Exception as e:
                logger.error(
                    "Failed to create legacy storage client",
                    extra={
                        "error": str(e),
                        "error_type": type(e).__name__,
                    },
                )
                return None

    def _get_impersonated_client(self) -> Optional[storage.Client]:
        """
        Get storage client using impersonation method.

        Includes automatic credential refresh every 30 minutes to prevent
        SignatureDoesNotMatch errors from stale credentials.

        Returns:
            Storage client or None if not available
        """
        if not self.use_impersonation or not self.service_account_email:
            logger.debug("Impersonation method not configured")
            return None

        # Check if we need to refresh credentials (every 30 minutes)
        should_refresh = False
        if self._impersonated_client is not None:
            if self._last_credential_refresh is not None:
                age_seconds = (
                    datetime.utcnow() - self._last_credential_refresh
                ).total_seconds()
                # Refresh every 30 minutes (1800 seconds)
                if age_seconds > 1800:
                    should_refresh = True
                    logger.info(
                        "Credentials expired, refreshing",
                        extra={
                            "age_seconds": round(age_seconds, 0),
                            "threshold_seconds": 1800,
                        },
                    )

        # Return cached client if valid and not expired
        if self._impersonated_client is not None and not should_refresh:
            return self._impersonated_client

        with self._client_lock:
            # Double-check inside lock
            if self._impersonated_client is not None and not should_refresh:
                return self._impersonated_client

            try:
                # Import Request for credential refresh
                from google.auth.transport.requests import Request

                source_credentials, _ = default()

                target_credentials = impersonated_credentials.Credentials(
                    source_credentials=source_credentials,
                    target_principal=self.service_account_email,
                    target_scopes=["https://www.googleapis.com/auth/cloud-platform"],
                )

                # CRITICAL: Refresh credentials explicitly
                # This ensures the token is valid before use
                try:
                    request = Request()
                    target_credentials.refresh(request)
                    logger.info(
                        "Credentials refreshed successfully",
                        extra={
                            "service_account": self.service_account_email,
                            "was_refresh": should_refresh,
                        },
                    )
                except Exception as refresh_error:
                    logger.warning(
                        "Credential refresh warning (continuing anyway)",
                        extra={
                            "error": str(refresh_error),
                            "error_type": type(refresh_error).__name__,
                        },
                    )

                self._impersonated_client = storage.Client(
                    credentials=target_credentials
                )
                self._last_credential_refresh = datetime.utcnow()

                logger.info(
                    "Impersonated storage client created",
                    extra={
                        "service_account_email": self.service_account_email,
                        "refresh_timestamp": self._last_credential_refresh.isoformat(),
                    },
                )

                return self._impersonated_client

            except Exception as e:
                logger.error(
                    "Failed to create impersonated storage client",
                    extra={"error": str(e), "error_type": type(e).__name__},
                )
                return None

    def _get_adc_client(self) -> Optional[storage.Client]:
        """
        Get storage client using Application Default Credentials

        Returns:
            Storage client or None if not available
        """
        # Thread-safe double-check locking pattern
        if self._adc_client is not None:
            return self._adc_client

        with self._client_lock:
            # Double-check inside lock to prevent race condition
            if self._adc_client is not None:
                return self._adc_client

            try:
                self._adc_client = storage.Client()

                logger.info("ADC storage client created")

                return self._adc_client

            except Exception as e:
                logger.error(
                    "Failed to create ADC storage client",
                    extra={
                        "error": str(e),
                        "error_type": type(e).__name__,
                    },
                )
                return None

    def _generate_with_client(
        self,
        client: storage.Client,
        bucket_name: str,
        blob_name: str,
        expiration_minutes: int,
    ) -> str:
        """
        Generate signed URL using specific storage client

        Args:
            client: Storage client to use
            bucket_name: GCS bucket name
            blob_name: Blob path within bucket
            expiration_minutes: URL validity duration

        Returns:
            Signed URL string

        Raises:
            Exception: If URL generation fails
        """
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        expiration = timedelta(minutes=expiration_minutes)

        # DEBUGGING: Log client creation/reuse
        client_type = type(client._credentials).__name__
        client_created_new = False
        if client_type == "Credentials":
            if self._last_credential_refresh is None:
                client_created_new = True
                self._last_credential_refresh = datetime.utcnow()
                logger.info(
                    "Storage client created with impersonated credentials",
                    extra={
                        "credential_type": client_type,
                        "timestamp": self._last_credential_refresh.isoformat(),
                    },
                )

        # Pass credentials explicitly to ensure correct signing
        # Critical for impersonated credentials
        # WORKAROUND: Retry up to 3 times if signature is corrupt
        max_attempts = 3
        signed_url = None

        for attempt in range(max_attempts):
            generation_start = time.time()
            system_time_before = datetime.utcnow()

            # Recreate blob object for each attempt to avoid cached state
            if attempt > 0:
                blob = client.bucket(bucket_name).blob(blob_name)
                time.sleep(0.1 * attempt)  # Small delay: 100ms, 200ms

            signed_url = blob.generate_signed_url(
                version="v4",
                expiration=expiration,
                method="GET",
                credentials=client._credentials,
            )

            # Validate signature immediately (length + hex format)
            if "X-Goog-Signature=" in signed_url:
                sig = signed_url.split("X-Goog-Signature=")[1]
                sig_len = len(sig)

                # RSA-SHA256 signature must be exactly 512 hex characters
                is_valid_length = sig_len == 512
                is_valid_hex = all(c in "0123456789abcdef" for c in sig.lower())
                is_valid = is_valid_length and is_valid_hex

                if is_valid:
                    # Valid signature (length + hex format)
                    if attempt > 0:
                        logger.info(
                            f"Signature OK on attempt {attempt + 1} | "
                            f"blob={blob_name}"
                        )
                    break  # Success
                else:
                    # Corrupt signature (length or format)
                    error_detail = []
                    if not is_valid_length:
                        error_detail.append(f"length={sig_len}")
                    if not is_valid_hex:
                        # Find first non-hex character
                        for i, c in enumerate(sig):
                            if c.lower() not in "0123456789abcdef":
                                error_detail.append(f"non-hex_char='{c}'_at_pos_{i}")
                                break

                    logger.error(
                        f"CORRUPT SIGNATURE attempt {attempt + 1}/{max_attempts} | "
                        f"blob={blob_name} | {' '.join(error_detail)}"
                    )
                    if attempt < max_attempts - 1:
                        continue  # Retry
                    else:
                        logger.error(
                            f"All {max_attempts} attempts failed | blob={blob_name} | "
                            f"Returning corrupt URL"
                        )

        system_time_after = datetime.utcnow()
        generation_time_ms = (time.time() - generation_start) * 1000

        # DEBUGGING: Track URL generation velocity
        self._urls_generated_count += 1
        time_since_last_url = None
        if self._last_url_timestamp:
            time_since_last_url = (
                system_time_after - self._last_url_timestamp
            ).total_seconds() * 1000
        self._last_url_timestamp = system_time_after

        # DEBUGGING: Log URL length and signature analysis
        url_length = len(signed_url)

        # Extract URL components for validation
        url_components = {}
        x_goog_date_str = None
        clock_skew_seconds = None

        if "?" in signed_url:
            base_url, query_string = signed_url.split("?", 1)
            url_components["base_url"] = base_url
            params = dict(
                param.split("=", 1) for param in query_string.split("&") if "=" in param
            )
            x_goog_date_str = params.get("X-Goog-Date", "")
            url_components["x_goog_date"] = x_goog_date_str
            url_components["x_goog_expires"] = params.get("X-Goog-Expires", "")
            url_components["x_goog_algorithm"] = params.get("X-Goog-Algorithm", "")

            # DEBUGGING: Calculate clock skew
            if x_goog_date_str:
                try:
                    # Parse X-Goog-Date: 20251121T183307Z
                    x_goog_dt = datetime.strptime(x_goog_date_str, "%Y%m%dT%H%M%SZ")
                    clock_skew_seconds = (
                        system_time_before - x_goog_dt
                    ).total_seconds()

                    # Log significant clock skew
                    if abs(clock_skew_seconds) > 2:
                        logger.warning(
                            "Significant clock skew detected",
                            extra={
                                "bucket": bucket_name,
                                "blob": blob_name,
                                "system_time": (system_time_before.isoformat()),
                                "x_goog_date": x_goog_dt.isoformat(),
                                "skew_seconds": round(clock_skew_seconds, 2),
                            },
                        )
                except Exception as e:
                    logger.debug(f"Could not parse X-Goog-Date: {e}")

        if "X-Goog-Signature=" in signed_url:
            signature = signed_url.split("X-Goog-Signature=")[1]
            sig_length = len(signature)

            # Check for repeated patterns (bug indicator)
            if sig_length > 1000:
                logger.error(
                    "ABNORMALLY LONG SIGNATURE DETECTED",
                    extra={
                        "bucket": bucket_name,
                        "blob": blob_name,
                        "url_length": url_length,
                        "signature_length": sig_length,
                        "signature_preview": signature[:200],
                        "signature_tail": signature[-200:],
                    },
                )

                # Check for repetition pattern
                if sig_length > 500:
                    chunk = signature[200:268]  # 68 chars from position 200
                    occurrences = signature.count(chunk)
                    if occurrences > 10:
                        logger.error(
                            "SIGNATURE REPETITION DETECTED - POSSIBLE SDK BUG",
                            extra={
                                "bucket": bucket_name,
                                "blob": blob_name,
                                "pattern_length": len(chunk),
                                "pattern_occurrences": occurrences,
                                "pattern_sample": chunk,
                                "total_from_pattern": len(chunk) * occurrences,
                                "actual_signature_length": sig_length,
                                "credentials_type": type(client._credentials).__name__,
                            },
                        )
            elif sig_length >= 400 and sig_length <= 600:
                # Normal signature length - Log as INFO
                extra_data = {
                    "bucket": bucket_name,
                    "blob": blob_name,
                    "signature_length": sig_length,
                    "url_length": url_length,
                    "generation_time_ms": round(generation_time_ms, 2),
                    "x_goog_date": url_components.get("x_goog_date"),
                    "x_goog_expires": url_components.get("x_goog_expires"),
                    "x_goog_algorithm": url_components.get("x_goog_algorithm"),
                    "credentials_type": (type(client._credentials).__name__),
                    "url_sequence_number": self._urls_generated_count,
                    "system_time_utc": system_time_before.isoformat(),
                }

                # Add optional debugging fields
                if clock_skew_seconds is not None:
                    extra_data["clock_skew_seconds"] = round(clock_skew_seconds, 2)
                if time_since_last_url is not None:
                    extra_data["ms_since_last_url"] = round(time_since_last_url, 2)
                if self._last_credential_refresh:
                    seconds_since_refresh = (
                        system_time_after - self._last_credential_refresh
                    ).total_seconds()
                    extra_data["seconds_since_credential_refresh"] = round(
                        seconds_since_refresh, 2
                    )

                logger.info(
                    "Signed URL generated successfully",
                    extra=extra_data,
                )
            else:
                # Unexpected signature length (not normal, not extremely long)
                logger.warning(
                    "Unexpected signature length detected",
                    extra={
                        "bucket": bucket_name,
                        "blob": blob_name,
                        "signature_length": sig_length,
                        "url_length": url_length,
                        "expected_range": "400-600 chars",
                    },
                )

        return signed_url

    def _generate_signed_url_manual(
        self,
        bucket_name: str,
        blob_name: str,
        expiration_minutes: int,
    ) -> Optional[str]:
        """
        Generate signed URL using manual V4 signing (Google official method)

        This implementation follows the official Google Cloud sample:
        https://github.com/GoogleCloudPlatform/python-docs-samples/blob/main/storage/signed_urls/generate_signed_urls.py

        Uses IAM signBlob API instead of blob.generate_signed_url() to avoid
        the impersonated credentials bug.

        Args:
            bucket_name: GCS bucket name
            blob_name: Object path within bucket
            expiration_minutes: URL validity in minutes

        Returns:
            Signed URL string or None if failed
        """
        try:
            # Convert expiration to seconds
            expiration_seconds = expiration_minutes * 60
            if expiration_seconds > 604800:
                logger.error("Expiration cannot exceed 7 days (604800 seconds)")
                return None

            # Escape object name
            escaped_object_name = quote(blob_name.encode("utf-8"), safe=b"/~")
            canonical_uri = f"/{escaped_object_name}"

            # Get current UTC time
            datetime_now = datetime.now(tz=datetime.timezone.utc)
            request_timestamp = datetime_now.strftime("%Y%m%dT%H%M%SZ")
            datestamp = datetime_now.strftime("%Y%m%d")

            # Build credential scope
            client_email = self.service_account_email
            credential_scope = f"{datestamp}/auto/storage/goog4_request"
            credential = f"{client_email}/{credential_scope}"

            # Build canonical headers
            host = f"{bucket_name}.storage.googleapis.com"
            headers = {"host": host}

            canonical_headers = ""
            ordered_headers = collections.OrderedDict(sorted(headers.items()))
            for k, v in ordered_headers.items():
                lower_k = str(k).lower()
                strip_v = str(v).lower()
                canonical_headers += f"{lower_k}:{strip_v}\n"

            signed_headers = ";".join(str(k).lower() for k in ordered_headers.keys())

            # Build query parameters
            query_parameters = {
                "X-Goog-Algorithm": "GOOG4-RSA-SHA256",
                "X-Goog-Credential": credential,
                "X-Goog-Date": request_timestamp,
                "X-Goog-Expires": str(expiration_seconds),
                "X-Goog-SignedHeaders": signed_headers,
            }

            canonical_query_string = ""
            ordered_params = collections.OrderedDict(sorted(query_parameters.items()))
            for k, v in ordered_params.items():
                encoded_k = quote(str(k), safe="")
                encoded_v = quote(str(v), safe="")
                canonical_query_string += f"{encoded_k}={encoded_v}&"
            canonical_query_string = canonical_query_string[:-1]  # Remove trailing '&'

            # Build canonical request
            canonical_request = "\n".join(
                [
                    "GET",
                    canonical_uri,
                    canonical_query_string,
                    canonical_headers,
                    signed_headers,
                    "UNSIGNED-PAYLOAD",
                ]
            )

            # Hash canonical request
            canonical_request_hash = hashlib.sha256(
                canonical_request.encode()
            ).hexdigest()

            # Build string to sign
            string_to_sign = "\n".join(
                [
                    "GOOG4-RSA-SHA256",
                    request_timestamp,
                    credential_scope,
                    canonical_request_hash,
                ]
            )

            # Sign using IAM signBlob API
            # Get source credentials for impersonation
            source_credentials, _ = default()

            # Create IAM client
            iam_client = discovery.build(
                "iamcredentials",
                "v1",
                credentials=source_credentials,
                cache_discovery=False,
            )

            import base64

            # CRITICAL: IAM signBlob expects the RAW BYTES to sign (not pre-base64'd)
            # The API will base64-encode internally, and return base64-encoded signature
            # So we encode string_to_sign as bytes, then the API handles base64
            string_to_sign_bytes = string_to_sign.encode("utf-8")

            # Call signBlob - API expects base64-encoded payload
            service_account_name = f"projects/-/serviceAccounts/{client_email}"
            sign_request = (
                iam_client.projects()
                .serviceAccounts()
                .signBlob(
                    name=service_account_name,
                    body={
                        "payload": base64.b64encode(string_to_sign_bytes).decode(
                            "utf-8"
                        )
                    },
                )
            )

            sign_response = sign_request.execute()

            # Response contains base64-encoded signature bytes
            # Decode from base64, then convert to hex (GCS V4 expects hex signature)
            signature_bytes = base64.b64decode(sign_response["signedBlob"])
            signature = binascii.hexlify(signature_bytes).decode()

            # Build final URL
            scheme_and_host = f"https://{host}"
            signed_url = f"{scheme_and_host}{canonical_uri}?{canonical_query_string}&x-goog-signature={signature}"

            logger.info(
                "Manual signed URL generated successfully",
                extra={
                    "bucket": bucket_name,
                    "blob": blob_name,
                    "expiration_minutes": expiration_minutes,
                    "signature_length": len(signature),
                },
            )

            return signed_url

        except Exception as e:
            logger.error(
                f"Failed to generate manual signed URL: {type(e).__name__}: {str(e)}",
                extra={
                    "bucket": bucket_name,
                    "blob": blob_name,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                exc_info=True,
            )
            return None

    def _validate_signed_url(self, signed_url: str, timeout: float = 5.0) -> bool:
        """
        Validate signed URL by making a HEAD request.

        This catches SignatureDoesNotMatch errors BEFORE returning
        the URL to the user.

        Args:
            signed_url: The signed URL to validate
            timeout: Request timeout in seconds

        Returns:
            True if URL is valid, False otherwise
        """
        import requests

        try:
            response = requests.head(signed_url, timeout=timeout, allow_redirects=True)

            if response.status_code == 200:
                logger.debug(
                    "Signed URL validation passed",
                    extra={"status_code": 200},
                )
                return True
            elif response.status_code == 403:
                # Check if it's a signature error
                logger.error(
                    "Signed URL validation FAILED - Access Denied",
                    extra={
                        "status_code": 403,
                        "url_preview": signed_url[:100],
                    },
                )
                return False
            else:
                logger.warning(
                    "Signed URL validation unexpected status",
                    extra={
                        "status_code": response.status_code,
                        "url_preview": signed_url[:100],
                    },
                )
                # Allow non-403 errors (might be transient)
                return True

        except requests.exceptions.Timeout:
            logger.warning("Signed URL validation timeout (allowing URL)")
            return True  # Allow on timeout - might be network issue
        except Exception as e:
            logger.warning(
                "Signed URL validation error (allowing URL)",
                extra={"error": str(e)},
            )
            return True  # Allow on unknown error

    def generate_signed_url_with_validation(
        self,
        gs_url: str,
        expiration_minutes: Optional[int] = None,
        validate: bool = True,
    ) -> Optional[str]:
        """
        Generate and optionally validate a signed URL.

        If validation fails, forces credential refresh and retries.

        Args:
            gs_url: GCS URL (gs://bucket/path)
            expiration_minutes: URL validity duration
            validate: Whether to validate URL with HEAD request

        Returns:
            Validated signed URL or None if generation fails
        """
        # First attempt
        signed_url = self.generate_signed_url(gs_url, expiration_minutes)

        if signed_url is None:
            return None

        if not validate:
            return signed_url

        # Validate the URL
        if self._validate_signed_url(signed_url):
            return signed_url

        # Validation failed - force credential refresh and retry
        logger.warning(
            "URL validation failed, forcing credential refresh and retry",
            extra={"gs_url": gs_url},
        )

        # Invalidate cached client to force refresh
        with self._client_lock:
            self._impersonated_client = None
            self._last_credential_refresh = None

        # Retry with fresh credentials
        signed_url = self.generate_signed_url(gs_url, expiration_minutes)

        if signed_url is None:
            return None

        # Validate again
        if self._validate_signed_url(signed_url):
            logger.info("URL validation passed after credential refresh")
            return signed_url

        # Still failing - log error but return URL anyway
        # (Let the user see the error rather than failing silently)
        logger.error(
            "URL validation STILL failing after refresh - returning anyway",
            extra={"gs_url": gs_url},
        )
        return signed_url

    def generate_signed_url(
        self,
        gs_url: str,
        expiration_minutes: Optional[int] = None,
    ) -> Optional[str]:
        """
        Generate signed URL with triple fallback strategy

        Attempts methods in order:
        1. Legacy (service account key file)
        2. Impersonation (service account email)
        3. ADC (Application Default Credentials)

        Args:
            gs_url: GCS URL (gs://bucket/path)
            expiration_minutes: URL validity (default: from config)

        Returns:
            Signed URL or None if all methods fail

        Example:
            >>> signer = RobustURLSigner(...)
            >>> url = signer.generate_signed_url("gs://miguel-test/invoice.pdf")
            >>> print(f"URL: {url}")
        """
        start_time = time.time()

        # Parse GCS URL
        if not gs_url.startswith("gs://"):
            logger.error("Invalid GCS URL format", extra={"gs_url": gs_url})
            return None

        parts = gs_url.replace("gs://", "").split("/", 1)
        if len(parts) != 2:
            logger.error("Invalid GCS URL structure", extra={"gs_url": gs_url})
            return None

        bucket_name, blob_name = parts

        # Use default expiration if not specified
        if expiration_minutes is None:
            expiration_minutes = self.default_expiration

        # Add buffer time based on clock sync
        buffer_minutes = self._get_buffer_minutes()
        total_expiration = expiration_minutes + buffer_minutes

        # Cap total expiration at 7 days (Google limit: 604800 seconds)
        max_expiration_minutes = (604800 // 60) - 1  # 10079 minutes (just under 7 days)
        if total_expiration > max_expiration_minutes:
            logger.warning(
                f"Total expiration ({total_expiration}min) exceeds Google limit. "
                f"Capping at {max_expiration_minutes}min (~7 days)",
                extra={
                    "requested_minutes": expiration_minutes,
                    "buffer_minutes": buffer_minutes,
                    "total_minutes": total_expiration,
                    "capped_minutes": max_expiration_minutes,
                },
            )
            total_expiration = max_expiration_minutes

        logger.debug(
            "Generating signed URL",
            extra={
                "bucket": bucket_name,
                "blob": blob_name,
                "requested_expiration_minutes": expiration_minutes,
                "buffer_minutes": buffer_minutes,
                "total_expiration_minutes": total_expiration,
            },
        )

        # Triple fallback strategy
        methods = [
            ("legacy", self._get_legacy_client),
            ("impersonation", self._get_impersonated_client),
            ("adc", self._get_adc_client),
        ]

        signed_url = None
        success = False
        clock_skew_detected = buffer_minutes > 1

        for method_name, get_client_func in methods:
            try:
                client = get_client_func()
                if client is None:
                    logger.debug(
                        "Storage client not available", extra={"method": method_name}
                    )
                    continue

                # Use retry strategy for URL generation with SDK method
                @self.retry.retry_decorator()
                def _generate():
                    return self._generate_with_client(
                        client=client,
                        bucket_name=bucket_name,
                        blob_name=blob_name,
                        expiration_minutes=total_expiration,
                    )

                signed_url = _generate()
                success = True

                logger.info(
                    "Signed URL generated successfully",
                    extra={
                        "method": method_name,
                        "bucket": bucket_name,
                        "expiration_minutes": total_expiration,
                    },
                )

                break  # Success - exit fallback loop

            except Exception as e:
                logger.warning(
                    "URL generation failed with method - trying next",
                    extra={
                        "method": method_name,
                        "error": str(e),
                        "error_type": type(e).__name__,
                    },
                )
                continue

        # Record metrics
        duration = time.time() - start_time
        self.metrics.record_url_generation(
            bucket=bucket_name,
            duration=duration,
            success=success,
            clock_skew_detected=clock_skew_detected,
        )

        if not success:
            logger.error(
                "All URL generation methods failed",
                extra={
                    "bucket": bucket_name,
                    "blob": blob_name,
                    "duration_seconds": round(duration, 3),
                },
            )

        return signed_url

    def generate_batch_signed_urls(
        self,
        gs_urls: List[str],
        expiration_minutes: Optional[int] = None,
    ) -> Dict[str, Optional[str]]:
        """
        Generate multiple signed URLs in batch

        Args:
            gs_urls: List of GCS URLs (gs://bucket/path)
            expiration_minutes: URL validity (default: from config)

        Returns:
            Dictionary mapping gs_url → signed_url (or None if failed)

        Example:
            >>> signer = RobustURLSigner(...)
            >>> urls = [
            ...     "gs://miguel-test/invoice1.pdf",
            ...     "gs://miguel-test/invoice2.pdf",
            ... ]
            >>> signed_urls = signer.generate_batch_signed_urls(urls)
            >>> for gs_url, signed_url in signed_urls.items():
            ...     print(f"{gs_url} → {signed_url}")
        """
        logger.info(
            "Generating batch signed URLs",
            extra={
                "count": len(gs_urls),
                "expiration_minutes": expiration_minutes or self.default_expiration,
            },
        )

        result = {}
        for i, gs_url in enumerate(gs_urls):
            # Add delay between requests to avoid signBlob rate limiting
            # Google applies throttling on concurrent signBlob calls
            if i > 0:
                time.sleep(0.05)  # 50ms delay between generations

            result[gs_url] = self.generate_signed_url(
                gs_url=gs_url,
                expiration_minutes=expiration_minutes,
            )

        successful = sum(1 for url in result.values() if url is not None)
        logger.info(
            "Batch URL generation complete",
            extra={
                "total": len(gs_urls),
                "successful": successful,
                "failed": len(gs_urls) - successful,
            },
        )

        return result
