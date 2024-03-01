from datetime import datetime, timedelta

from mini_dags.chester.filters import chester_filters
from mini_dags.chester.macros import chester_macros

from airflow import DAG
from airflow.configuration import conf as airflow_conf
from airflow.models.dag import ScheduleArg


class ChesterDag(DAG):
    def __init__(
        self,
        dag_id: str,
        description: str,
        start_date: datetime,
        schedule: ScheduleArg,
        tags: list[str],
        catchup: bool = False,
        retries: int = 1,
        is_paused_upon_creation: bool | None = None,
        params: dict | None = None,
        retry_delay: timedelta = timedelta(minutes=1),
        max_active_runs: int = airflow_conf.getint("core", "max_active_runs_per_dag"),
        max_active_tasks: int = airflow_conf.getint("core", "max_active_tasks_per_dag"),
    ):
        DAG.__init__(
            self,
            dag_id=dag_id,
            description=description,
            default_args={
                "depends_on_past": False,
                "email_on_failure": False,
                "email_on_retry": False,
                "retries": retries,
                "retry_delay": retry_delay,
            },
            start_date=start_date,
            schedule=schedule,
            template_searchpath=[],
            catchup=catchup,
            tags=tags,
            user_defined_filters=chester_filters,
            user_defined_macros=chester_macros,
            is_paused_upon_creation=is_paused_upon_creation,
            params=params,
            max_active_runs=max_active_runs,
            max_active_tasks=max_active_tasks,
        )

    def __exit__(self, _type, _value, _tb) -> None:  # type: ignore
        DAG.__exit__(self, _type, _value, _tb)
