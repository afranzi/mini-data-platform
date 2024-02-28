module "argocd" {
  source        = "../modules/k8s/argocd/server"
  argocd_domain = "argocd.data"
  depends_on    = [module.cluster]
}

provider "argocd" {
  server_addr = "${module.argocd.argocd_server}:443"
  username    = "admin"
  password    = module.argocd.argocd_token
  grpc_web    = true
  insecure    = true
}
