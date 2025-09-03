"""
Servicio de BigQuery
Utilidades complementarias para BigQuery que no están cubiertas por MCP Toolbox
"""

import os
import logging
from typing import Optional, Dict, Any, List
from google.cloud import bigquery

logger = logging.getLogger(__name__)


class BigQueryService:
    """Servicio de utilidades BigQuery complementarias"""

    def __init__(self):
        """Inicializa el servicio de BigQuery"""
        # Configuración
        try:
            from config import PROJECT_ID, BIGQUERY_DATASET, LOCATION

            self.project_id = PROJECT_ID
            self.dataset_id = BIGQUERY_DATASET
            self.location = LOCATION
        except ImportError:
            # Fallback a variables de entorno
            self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "poc-genai-398414")
            self.dataset_id = os.getenv("BIGQUERY_DATASET", "invoice_processing")
            self.location = os.getenv("LOCATION", "us-central1")

        # Cliente BigQuery (lazy initialization)
        self._client = None

        logger.info(f"💾 BigQuery Service inicializado:")
        logger.info(f"   🏷️ Proyecto: {self.project_id}")
        logger.info(f"   📊 Dataset: {self.dataset_id}")
        logger.info(f"   🌍 Ubicación: {self.location}")

    @property
    def client(self) -> bigquery.Client:
        """Obtiene cliente BigQuery (lazy initialization)"""
        if self._client is None:
            try:
                self._client = bigquery.Client(
                    project=self.project_id, location=self.location
                )
                logger.info("✅ Cliente BigQuery inicializado")
            except Exception as e:
                logger.error(f"❌ Error inicializando cliente BigQuery: {e}")
                raise
        return self._client

    def test_connection(self) -> Dict[str, Any]:
        """
        Prueba la conexión a BigQuery

        Returns:
            Dict con información de la conexión
        """
        try:
            # Simple query para probar la conexión
            query = "SELECT 1 as test"

            job = self.client.query(query)
            results = list(job.result())

            return {
                "success": True,
                "project_id": self.project_id,
                "location": self.location,
                "dataset_id": self.dataset_id,
                "test_result": results[0].test if results else None,
            }

        except Exception as e:
            logger.error(f"❌ Error probando conexión BigQuery: {e}")
            return {
                "success": False,
                "error": str(e),
                "project_id": self.project_id,
                "location": self.location,
                "dataset_id": self.dataset_id,
            }

    def get_table_info(self, table_name: str) -> Optional[Dict[str, Any]]:
        """
        Obtiene información sobre una tabla

        Args:
            table_name: Nombre de la tabla

        Returns:
            Información de la tabla o None si no existe
        """
        try:
            table_ref = self.client.dataset(self.dataset_id).table(table_name)
            table = self.client.get_table(table_ref)

            return {
                "table_id": table.table_id,
                "dataset_id": table.dataset_id,
                "project_id": table.project,
                "num_rows": table.num_rows,
                "num_bytes": table.num_bytes,
                "created": table.created,
                "modified": table.modified,
                "schema_fields": len(table.schema),
                "description": table.description,
                "exists": True,
            }

        except Exception as e:
            logger.warning(f"⚠️ No se pudo obtener info de tabla {table_name}: {e}")
            return None

    def list_tables(self) -> List[Dict[str, Any]]:
        """
        Lista todas las tablas en el dataset

        Returns:
            Lista de información de tablas
        """
        try:
            dataset_ref = self.client.dataset(self.dataset_id)
            tables = self.client.list_tables(dataset_ref)

            table_list = []
            for table in tables:
                table_info = self.get_table_info(table.table_id)
                if table_info:
                    table_list.append(table_info)

            logger.info(f"📋 Tablas encontradas: {len(table_list)}")
            return table_list

        except Exception as e:
            logger.error(f"❌ Error listando tablas: {e}")
            return []

    def execute_query(
        self, query: str, job_config: Optional[bigquery.QueryJobConfig] = None
    ) -> Dict[str, Any]:
        """
        Ejecuta una consulta BigQuery

        Args:
            query: Query SQL a ejecutar
            job_config: Configuración del job (opcional)

        Returns:
            Resultado de la consulta
        """
        try:
            logger.info(f"🔍 Ejecutando consulta BigQuery...")

            job = self.client.query(query, job_config=job_config)
            results = list(job.result())

            # Convertir resultados a formato serializable
            rows = []
            if results:
                # Obtener nombres de columnas del primer resultado
                column_names = list(results[0].keys()) if results else []

                for row in results:
                    row_dict = {}
                    for column in column_names:
                        value = row.get(column)
                        # Convertir tipos no serializables
                        if hasattr(value, "isoformat"):  # datetime objects
                            value = value.isoformat()
                        row_dict[column] = value
                    rows.append(row_dict)

            return {
                "success": True,
                "rows": rows,
                "row_count": len(rows),
                "bytes_processed": job.total_bytes_processed,
                "job_id": job.job_id,
                "query": query,
            }

        except Exception as e:
            logger.error(f"❌ Error ejecutando consulta: {e}")
            return {
                "success": False,
                "error": str(e),
                "rows": [],
                "row_count": 0,
                "query": query,
            }

    def get_dataset_info(self) -> Dict[str, Any]:
        """
        Obtiene información del dataset

        Returns:
            Información del dataset
        """
        try:
            dataset_ref = self.client.dataset(self.dataset_id)
            dataset = self.client.get_dataset(dataset_ref)

            # Contar tablas
            tables = list(self.client.list_tables(dataset_ref))

            return {
                "dataset_id": dataset.dataset_id,
                "project_id": dataset.project,
                "location": dataset.location,
                "created": dataset.created.isoformat() if dataset.created else None,
                "modified": dataset.modified.isoformat() if dataset.modified else None,
                "description": dataset.description,
                "table_count": len(tables),
                "exists": True,
            }

        except Exception as e:
            logger.error(f"❌ Error obteniendo info del dataset: {e}")
            return {
                "exists": False,
                "error": str(e),
                "dataset_id": self.dataset_id,
                "project_id": self.project_id,
            }

    def validate_dataset_access(self) -> Dict[str, Any]:
        """
        Valida que se tenga acceso al dataset y tablas principales

        Returns:
            Estado de validación
        """
        validation = {
            "dataset_accessible": False,
            "tables_found": [],
            "tables_missing": [],
            "connection_ok": False,
            "errors": [],
        }

        try:
            # Probar conexión básica
            connection_test = self.test_connection()
            validation["connection_ok"] = connection_test["success"]

            if not connection_test["success"]:
                validation["errors"].append(
                    f"Conexión falló: {connection_test.get('error')}"
                )
                return validation

            # Verificar dataset
            dataset_info = self.get_dataset_info()
            validation["dataset_accessible"] = dataset_info["exists"]

            if not dataset_info["exists"]:
                validation["errors"].append(
                    f"Dataset no accesible: {dataset_info.get('error')}"
                )
                return validation

            # Verificar tablas principales
            expected_tables = [
                "facturas",
                "zip_packages",
            ]  # Tablas que esperamos encontrar

            for table_name in expected_tables:
                table_info = self.get_table_info(table_name)
                if table_info and table_info["exists"]:
                    validation["tables_found"].append(table_name)
                else:
                    validation["tables_missing"].append(table_name)

            logger.info("✅ Validación BigQuery completada")

        except Exception as e:
            logger.error(f"❌ Error en validación BigQuery: {e}")
            validation["errors"].append(str(e))

        return validation
