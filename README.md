# mini-data-platform

## Setup

brew install docker
brew install hyperkit
brew install colima
brew install minikube
brew install --cask openlens
https://github.com/alebcay/openlens-node-pod-menu

## https://github.com/tfutils/tfenv

brew install tfenv
tfenv install latest
tfenv use latest

colima start
# Intel
minikube start --driver=hyperkit --download-only
# M1
minikube start --driver=qemu2  --download-only

Minikube with Ingress setup
https://github.com/scott-the-programmer/terraform-provider-minikube
https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/

Authenticate ArgoCD with Google
https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/google/

Literature
https://medium.com/@mehmetodabashi/installing-argocd-on-minikube-and-deploying-a-test-application-caa68ec55fbf

curl --resolve "argocd.data:80:$( minikube ip -p data )" -i http://argocd.data

# DNS Local Resolver

> /etc/resolver/minikube-data

```
domain data
nameserver 192.168.105.4
search_order 1
timeout 5
```

> /etc/hosts

```
192.168.105.4 argocd.data
192.168.105.4 airflow.data
```

> `nslookup argocd.data 192.168.64.2`

```
Server:		192.168.64.2
Address:	192.168.64.2#53

Non-authoritative answer:
Name:	argocd.data
Address: 192.168.64.2
```