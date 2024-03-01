from typing import Callable

from airflow.utils.context import Context


def chain_alerts(alert_fns: list[Callable]) -> Callable[[Context], None]:
    def execute(context: Context) -> None:
        for alert_fn in alert_fns:
            alert_fn(context)

    return execute
