/**
 * # Mini Data Platform
 * This project aims to showcase the value and capabilities to deploy a local K8s cluster with the minimum
 * Data Platform stack we would start in any company. This means having K8s with ArgoCD & Airflow.
 *
 * !!! abstract "Terraform setup"
 *     This section has been generated with the [terraform-docs](https://terraform-docs.io/) pre-commit repo.
 *
 * ## Setup
 * For the mini-data-platform deployment we will require:
 *
 * <div class="grid cards" markdown>
 * - :simple-kubernetes: __[minikube](https://minikube.sigs.k8s.io/)__ to deploy the K8s cluster
 * - :simple-terraform: __[tfenv](https://github.com/tfutils/tfenv)__ to manage our Terraform version
 * - :simple-docker: __[colima](https://github.com/abiosoft/colima)__ for running docker
 * - :simple-docker: __[qemu driver](https://minikube.sigs.k8s.io/docs/drivers/qemu/)__ for K8S VM creation
 * - :simple-lens: __[OpenLens](https://github.com/MuhammedKalkan/OpenLens)__ to interact with K8s resources
 * </div>
 *
 * ``` shell title="setup.sh"
 * brew install docker
 * brew install colima
 * brew install minikube
 * # Configure Terraform
 * brew install tfenv
 * tfenv install latest
 * tfenv use latest
 * # extras
 * brew install --cask openlens
 * ```
 *
 * ### Qemu Networking
 * !!! info
 *     The QEMU driver has two networking options: socket_vmnet and builtin.
 *     socket_vmnet will give you full minikube networking functionality,
 *     such as the service and tunnel commands.
 *     *See: [**docs**](https://minikube.sigs.k8s.io/docs/drivers/qemu/#networking)*
 *
 * ```shell title="qemu_setup.sh"
 * minikube start --driver=qemu --download-only
 * brew install socket_vmnet
 * brew tap homebrew/services
 * HOMEBREW=$(which brew) && sudo ${HOMEBREW} services start socket_vmnet
 * ```
 *
 * ### Configure local network
 * Since we take advantage of the ingress add-on, we must configure our local hosts and resolvers
 * to enable us to browser our applications using our own local domain.
 *
 * !!! tip
 *     The default configuration exposes all the endpoints into the `*.data` domain.
 *     (i.e. argocd.data & airflow.data).
 *
 * Once the minikube cluster is deployed via terraform, we will obtain its ip with the following command:
 * ```shell hl_lines="2"
 * $ minikube ip -p data
 * 192.168.105.4
 * ```
 * Then, we will provide a new resolver plus add the domain into the hosts file.
 *
 * ``` title="/etc/resolver/minikube-data"
 * domain data
 * nameserver 192.168.105.4
 * search_order 1
 * timeout 5
 * ```
 *
 * ``` title="/etc/hosts"
 * 192.168.105.4 argocd.data
 * 192.168.105.4 airflow.data
 * ```
 *
 * ---
 *
 */
