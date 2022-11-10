resource "helm_release" "mail" {
  chart = "mail"
  name  = "mail"
  repository = "https://bokysan.github.io/docker-postfix/"
  namespace = kubernetes_namespace.namespace.metadata.0.name
  set {
    name  = "config.general.ALLOWED_SENDER_DOMAINS"
    value = data.vault_generic_secret.secret.data["domain"]
  }
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  set {
    name  = "config.general.RELAYHOST"
    value = var.smtp.host
  }
  set {
    name  = "config.general.RELAYHOST_USERNAME"
    value = var.smtp.login
  }
  set {
    name  = "config.general.RELAYHOST_PASSWORD"
    value = var.smtp.password
  }
  set {
    name  = "config.postfix.smtp_tls_wrappermode"
    value = "yes"
  }
  set {
    name  = "config.postfix.smtp_tls_security_level"
    value = "encrypt"
  }
}
