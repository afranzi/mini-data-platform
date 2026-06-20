from collections.abc import Iterable
from typing import Any

from airflow.models import TaskInstance
from airflow.sdk import Asset


def xcom_pod(task_instance: TaskInstance, task_id: str) -> Any:
    return task_instance.xcom_pull(task_ids=task_id, key="return_value")


def get_datasets(task_instance: TaskInstance, task_id: str) -> list[Asset]:
    params = xcom_pod(task_instance, task_id)
    datasets: Iterable[str] = (x.get("airflow_trigger", {}).get("dataset_name") for x in params)
    datasets: list[str] = list(filter(None, datasets))
    assets: list[Asset] = [Asset(f"s3://{x}") for x in datasets]
    return assets
