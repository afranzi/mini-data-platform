# Roadmap

!!! Tip
    This section aims to brainstorm the potential roadmap to keep the Mini Data Platform project evolving.

- [x] Define full project with :simple-terraform: [Terraform](../terraform/main).
- [x] Deploy :simple-apacheairflow: [Airflow](../helms/airflow) in K8s via :simple-argo: ArgoCD.
- [x] Provide a Postgres DB
- [x] Automate documentation
    * [x] Terraform docs
    * [x] Helms docs
    * [ ] Airflow docs
    * [ ] DBT docs
- [ ] Python DAG retrieving daily exchange rates data from https://fixer.io/ into the K8s postgres db.
    * Showcase how to execute a K8sPodOperator to execute Python code.

- [ ] DBT DAG processing the exchange rates
    * Showcase how to encapsulate and execute DBT Core as a K8sPodOperator

- [ ] DBT [Elementary](https://www.elementary-data.com/) Report Website
    * Showcase how to host and provide a static website inside K8s.

- [ ] K8s Certificates: Solve `Not Secure` issue with nginx without due fake certificates.
