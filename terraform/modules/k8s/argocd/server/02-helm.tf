resource "helm_release" "argocd" {
  name       = var.name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_helm_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    templatefile("${path.module}/helm_values/argocd.yaml.tpl", {
      # Image tag from https://github.com/argoproj/argo-cd/releases
      argocd_version = var.argocd_version
      argocd_domain  = var.argocd_domain
    })
  ]

  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}
