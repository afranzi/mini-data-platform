from typing import Any, Iterable

from airflow.datasets import Dataset
from airflow.models import TaskInstance


def xcom_pod(task_instance: TaskInstance, task_id: str) -> Any:
    return task_instance.xcom_pull(task_ids=task_id, key="return_value")


def get_datasets(task_instance: TaskInstance, task_id: str) -> list[Dataset]:
    params = xcom_pod(task_instance, task_id)
    datasets: Iterable[str] = (x.get("airflow_trigger", {}).get("dataset_name") for x in params)
    datasets: list[str] = list(filter(None, datasets))
    datasets: list[Dataset] = [Dataset(f"s3://{x}") for x in datasets]
    return datasets
