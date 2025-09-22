"""
Configuración de entorno para estabilidad temporal de signed URLs.

Este módulo establece configuraciones críticas para evitar problemas de clock skew
y asegurar operaciones estables con Google Cloud Storage signed URLs.

Basándome en el Byterover memory layer, la configuración UTC y validación de
credenciales son fundamentales para resolver errores SignatureDoesNotMatch.
"""

import os
import time
import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional, Tuple
import subprocess
import sys

logger = logging.getLogger(__name__)


def configure_environment() -> Dict[str, Any]:
    """
    Configurar entorno completo para operaciones estables de signed URLs.

    Establece timezone UTC, valida credenciales de Google Cloud y configura
    variables de entorno necesarias para máxima estabilidad temporal.

    Returns:
        Diccionario con resultado de configuración y detalles

    Example:
        >>> config_result = configure_environment()
        >>> if config_result['success']:
        ...     print("Entorno configurado correctamente")
    """
    logger.info("Iniciando configuración de entorno para signed URLs...")

    config_result = {
        "success": False,
        "timezone_configured": False,
        "credentials_valid": False,
        "environment_variables_set": False,
        "issues": [],
        "recommendations": [],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    try:
        # 1. Configurar timezone UTC
        timezone_result = _configure_timezone_utc()
        config_result["timezone_configured"] = timezone_result["success"]
        if not timezone_result["success"]:
            config_result["issues"].append(f"Timezone: {timezone_result['error']}")

        # 2. Validar credenciales de Google Cloud
        credentials_result = _validate_google_cloud_credentials()
        config_result["credentials_valid"] = credentials_result["valid"]
        if not credentials_result["valid"]:
            config_result["issues"].append(
                f"Credenciales: {credentials_result['error']}"
            )
        else:
            config_result["credentials_info"] = credentials_result["info"]

        # 3. Configurar variables de entorno
        env_result = _set_environment_variables()
        config_result["environment_variables_set"] = env_result["success"]
        if not env_result["success"]:
            config_result["issues"].append(f"Variables: {env_result['error']}")
        else:
            config_result["environment_variables"] = env_result["variables"]

        # 4. Verificar configuración final
        verification_result = _verify_final_configuration()
        config_result["verification"] = verification_result

        # Determinar éxito general
        config_result["success"] = (
            config_result["timezone_configured"]
            and config_result["credentials_valid"]
            and config_result["environment_variables_set"]
        )

        # Generar recomendaciones si hay problemas
        if not config_result["success"]:
            config_result["recommendations"] = _generate_recommendations(config_result)

        # Log resultado
        if config_result["success"]:
            logger.info("✅ Entorno configurado exitosamente para signed URLs")
        else:
            logger.warning(
                f"⚠️ Configuración parcial: {len(config_result['issues'])} problemas detectados"
            )

        return config_result

    except Exception as e:
        logger.error(f"Error crítico en configuración de entorno: {e}")
        config_result["issues"].append(f"Error crítico: {str(e)}")
        return config_result


def _configure_timezone_utc() -> Dict[str, Any]:
    """
    Configurar timezone del sistema a UTC para consistencia temporal.

    Returns:
        Diccionario con resultado de configuración de timezone
    """
    try:
        # Intentar establecer TZ=UTC
        os.environ["TZ"] = "UTC"

        # En sistemas Unix, aplicar el cambio
        if hasattr(time, "tzset"):
            time.tzset()

        # Verificar que el cambio se aplicó
        current_tz = os.environ.get("TZ")
        current_time = datetime.now(timezone.utc)
        local_time = datetime.now()

        # En sistemas correctamente configurados, UTC y local deberían ser similares
        time_diff = abs(
            (current_time - local_time.replace(tzinfo=timezone.utc)).total_seconds()
        )

        logger.info(f"Timezone configurado: TZ={current_tz}")
        logger.info(f"Tiempo UTC: {current_time.isoformat()}")
        logger.info(f"Diferencia local-UTC: {time_diff:.1f}s")

        return {
            "success": True,
            "timezone": current_tz,
            "utc_time": current_time.isoformat(),
            "time_difference": time_diff,
            "properly_configured": time_diff < 60,  # Menos de 1 minuto de diferencia
        }

    except Exception as e:
        logger.error(f"Error configurando timezone: {e}")
        return {
            "success": False,
            "error": str(e),
            "current_tz": os.environ.get("TZ", "Not set"),
        }


def _validate_google_cloud_credentials() -> Dict[str, Any]:
    """
    Validar que las credenciales de Google Cloud están correctamente configuradas.

    Returns:
        Diccionario con información de validación de credenciales
    """
    try:
        # Verificar variable de entorno GOOGLE_APPLICATION_CREDENTIALS
        creds_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")

        credential_info = {"method": "unknown", "valid": False, "details": {}}

        if creds_path:
            # Validar archivo de service account
            if os.path.exists(creds_path):
                try:
                    import json

                    with open(creds_path, "r") as f:
                        creds_data = json.load(f)

                    credential_info.update(
                        {
                            "method": "service_account_file",
                            "valid": True,
                            "details": {
                                "file_path": creds_path,
                                "project_id": creds_data.get("project_id"),
                                "client_email": creds_data.get("client_email"),
                                "type": creds_data.get("type"),
                            },
                        }
                    )

                    logger.info(
                        f"✅ Service account válido: {creds_data.get('client_email')}"
                    )

                except Exception as e:
                    logger.error(f"Error leyendo service account: {e}")
                    return {
                        "valid": False,
                        "error": f"Archivo de credenciales inválido: {e}",
                    }
            else:
                logger.error(f"Archivo de credenciales no existe: {creds_path}")
                return {"valid": False, "error": f"Archivo no encontrado: {creds_path}"}
        else:
            # Intentar usar Application Default Credentials (ADC)
            try:
                # Esto requiere google-auth, pero podemos hacer verificación básica
                logger.info("Intentando usar Application Default Credentials...")

                # Verificar si gcloud está configurado
                result = subprocess.run(
                    ["gcloud", "auth", "list", "--format=value(account)"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )

                if result.returncode == 0 and result.stdout.strip():
                    accounts = result.stdout.strip().split("\n")
                    active_account = accounts[0] if accounts else None

                    credential_info.update(
                        {
                            "method": "application_default_credentials",
                            "valid": True,
                            "details": {
                                "active_account": active_account,
                                "available_accounts": accounts,
                            },
                        }
                    )

                    logger.info(f"✅ ADC válido: {active_account}")

                else:
                    logger.warning("No se encontraron credenciales ADC")
                    return {
                        "valid": False,
                        "error": "No hay credenciales ADC configuradas",
                    }

            except FileNotFoundError:
                logger.warning("gcloud CLI no está instalado")
                return {
                    "valid": False,
                    "error": "gcloud CLI no disponible y no hay service account configurado",
                }
            except Exception as e:
                logger.error(f"Error verificando ADC: {e}")
                return {"valid": False, "error": f"Error en validación ADC: {e}"}

        return {"valid": credential_info["valid"], "info": credential_info}

    except Exception as e:
        logger.error(f"Error validando credenciales: {e}")
        return {"valid": False, "error": str(e)}


def _set_environment_variables() -> Dict[str, Any]:
    """
    Configurar variables de entorno necesarias para signed URLs estables.

    Returns:
        Diccionario con resultado de configuración de variables
    """
    try:
        # Variables por defecto para signed URLs estables
        default_variables = {
            "TZ": "UTC",  # Ya configurada, pero asegurar
            "SIGNED_URL_EXPIRATION_HOURS": "1",
            "SIGNED_URL_BUFFER_MINUTES": "3",
            "MAX_SIGNATURE_RETRIES": "3",
            "SIGNED_URL_TIMEOUT_SECONDS": "60",
            "ENABLE_SIGNED_URL_MONITORING": "true",
        }

        set_variables = {}

        for var_name, default_value in default_variables.items():
            # Solo establecer si no existe ya
            if var_name not in os.environ:
                os.environ[var_name] = default_value
                set_variables[var_name] = default_value
                logger.info(f"Variable establecida: {var_name}={default_value}")
            else:
                current_value = os.environ[var_name]
                set_variables[var_name] = current_value
                logger.info(f"Variable existente: {var_name}={current_value}")

        return {
            "success": True,
            "variables": set_variables,
            "newly_set": [
                k for k, v in default_variables.items() if k not in os.environ
            ],
        }

    except Exception as e:
        logger.error(f"Error configurando variables de entorno: {e}")
        return {"success": False, "error": str(e)}


def _verify_final_configuration() -> Dict[str, Any]:
    """
    Verificar que toda la configuración esté correcta.

    Returns:
        Diccionario con verificación final
    """
    verification = {
        "timezone_utc": False,
        "required_variables_present": False,
        "credentials_accessible": False,
        "system_time_stable": False,
    }

    try:
        # Verificar timezone
        tz = os.environ.get("TZ")
        verification["timezone_utc"] = tz == "UTC"

        # Verificar variables requeridas
        required_vars = [
            "SIGNED_URL_EXPIRATION_HOURS",
            "SIGNED_URL_BUFFER_MINUTES",
            "MAX_SIGNATURE_RETRIES",
        ]
        verification["required_variables_present"] = all(
            var in os.environ for var in required_vars
        )

        # Verificar credenciales (básico)
        has_service_account = "GOOGLE_APPLICATION_CREDENTIALS" in os.environ
        verification["credentials_accessible"] = has_service_account

        # Verificar estabilidad de tiempo (diferencia mínima entre llamadas)
        time1 = datetime.now(timezone.utc)
        time.sleep(0.1)
        time2 = datetime.now(timezone.utc)
        time_stability = abs((time2 - time1).total_seconds() - 0.1)
        verification["system_time_stable"] = (
            time_stability < 0.05
        )  # Menos de 50ms de drift

        logger.info(f"Verificación final: {verification}")

    except Exception as e:
        logger.error(f"Error en verificación final: {e}")

    return verification


def _generate_recommendations(config_result: Dict[str, Any]) -> list[str]:
    """
    Generar recomendaciones basadas en problemas detectados.

    Args:
        config_result: Resultado de configuración con problemas

    Returns:
        Lista de recomendaciones
    """
    recommendations = []

    if not config_result.get("timezone_configured"):
        recommendations.append(
            "Configurar timezone UTC: export TZ=UTC (Linux/Mac) o setx TZ UTC (Windows)"
        )

    if not config_result.get("credentials_valid"):
        recommendations.extend(
            [
                "Configurar credenciales de Google Cloud:",
                "1. Service Account: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json",
                "2. O usar gcloud: gcloud auth application-default login",
            ]
        )

    if not config_result.get("environment_variables_set"):
        recommendations.append(
            "Configurar variables de entorno requeridas para signed URLs"
        )

    # Recomendaciones adicionales basadas en Byterover memory
    recommendations.extend(
        [
            "Para máxima estabilidad:",
            "- Usar service account específico en lugar de ADC",
            "- Configurar SIGNED_URL_BUFFER_MINUTES=5 si hay clock skew frecuente",
            "- Habilitar monitoreo: ENABLE_SIGNED_URL_MONITORING=true",
        ]
    )

    return recommendations


def get_environment_status() -> Dict[str, Any]:
    """
    Obtener estado actual del entorno sin modificar nada.

    Returns:
        Diccionario con estado actual completo

    Example:
        >>> status = get_environment_status()
        >>> print(f"Timezone: {status['timezone']}")
    """
    return {
        "timezone": os.environ.get("TZ", "Not set"),
        "current_utc_time": datetime.now(timezone.utc).isoformat(),
        "google_credentials_set": "GOOGLE_APPLICATION_CREDENTIALS" in os.environ,
        "credentials_path": os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"),
        "signed_url_variables": {
            var: os.environ.get(var, "Not set")
            for var in [
                "SIGNED_URL_EXPIRATION_HOURS",
                "SIGNED_URL_BUFFER_MINUTES",
                "MAX_SIGNATURE_RETRIES",
                "SIGNED_URL_TIMEOUT_SECONDS",
            ]
        },
        "monitoring_enabled": os.environ.get(
            "ENABLE_SIGNED_URL_MONITORING", "false"
        ).lower()
        == "true",
    }


if __name__ == "__main__":
    # Test del módulo de configuración
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    print("🔧 Testing configuración de entorno...")

    # Mostrar estado actual
    print("\n📊 Estado actual del entorno:")
    current_status = get_environment_status()
    import json

    print(json.dumps(current_status, indent=2, ensure_ascii=False))

    # Ejecutar configuración
    print("\n⚙️ Ejecutando configuración...")
    config_result = configure_environment()

    print(f"\n📋 Resultado de configuración:")
    print(json.dumps(config_result, indent=2, ensure_ascii=False))

    if config_result["success"]:
        print("\n✅ Entorno configurado correctamente para signed URLs estables")
    else:
        print(
            f"\n⚠️ Configuración incompleta ({len(config_result['issues'])} problemas)"
        )
        print("\n💡 Recomendaciones:")
        for rec in config_result.get("recommendations", []):
            print(f"  - {rec}")
