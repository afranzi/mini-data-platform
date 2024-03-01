from mini_dags.chester.utils import dates, udf

chester_macros = {
    "today": dates.today,
    "xcom_pod": udf.xcom_pod,
    "get_datasets": udf.get_datasets,
}
