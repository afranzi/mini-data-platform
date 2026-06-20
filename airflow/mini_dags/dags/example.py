import datetime

from mini_dags.chester.dag import ChesterDag

from airflow.providers.standard.operators.empty import EmptyOperator
from airflow.sdk import DAG  # noqa

with ChesterDag(
    dag_id="my_dag_name",
    description="Dummy DAG",
    start_date=datetime.datetime(2024, 2, 27),
    schedule="@daily",
    tags=["example", "dummy"],
) as dag:
    EmptyOperator(task_id="task")
