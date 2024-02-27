global:
  domain: ${argocd_domain}
  image:
    tag: ${argocd_version}

server:
  service:
    type: NodePort
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    extraTls:
      - hosts:
        - ${argocd_domain}
        # Based on the ingress controller used secret might be optional
        secretName: wildcard-tls