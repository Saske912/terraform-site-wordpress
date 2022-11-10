resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

data "vault_generic_secret" "secret" {
  path = var.vault-path
}

resource "kubernetes_config_map_v1" "database-user" {
  metadata {
    name = "database-user"
    namespace = kubernetes_namespace.namespace.metadata.0.name
  }
  data = {
    start =<<EOT
#!/bin/ash

apk add mariadb-client

mysql -u root \
-h ${var.database.host} \
< /tmp/create-database.sql
EOT
    my-conf=<<EOT
[client]
user=root
password=${var.database.root-password}
EOT
    create-database=<<EOT
create user '${data.vault_generic_secret.secret.data["username"]}'@'%'
identified by '${data.vault_generic_secret.secret.data["password"]}';
create database ${data.vault_generic_secret.secret.data["database"]};
grant all privileges on ${data.vault_generic_secret.secret.data["database"]}.* to
'${data.vault_generic_secret.secret.data["username"]}';
EOT
  }
}

resource "kubernetes_job_v1" "create-user" {
  metadata {
    name = "create-user"
    namespace = kubernetes_namespace.namespace.metadata.0.name
  }
  spec {
    template {
      metadata {
        name = "create-user"
        labels = {
          app = "site"
        }
      }
      spec {
        container {
          name = "alpine"
          image = "alpine"
          command = ["ash"]
          args = ["/tmp/start.sh"]
          volume_mount {
            mount_path = "/tmp/start.sh"
            name       = "start"
            sub_path = "start.sh"
          }
          volume_mount {
            mount_path = "/root/.my.cnf"
            name       = "my-conf"
            sub_path = ".my.cnf"
          }
          volume_mount {
            mount_path = "/tmp/create-database.sql"
            name       = "create-database"
            sub_path = "create-database.sql"
          }
        }
        volume {
          name = "start"
          config_map {
            name = kubernetes_config_map_v1.database-user.metadata.0.name
            items {
              key = "start"
              path = "start.sh"
            }
          }
        }
        volume {
          name = "my-conf"
          config_map {
            name = kubernetes_config_map_v1.database-user.metadata.0.name
            items {
              key = "my-conf"
              path = ".my.cnf"
            }
          }
        }
        volume {
          name = "create-database"
          config_map {
            name = kubernetes_config_map_v1.database-user.metadata.0.name
            items {
              key = "create-database"
              path = "create-database.sql"
            }
          }
        }
      }
    }
  }
}

resource "helm_release" "site" {
  depends_on = [kubernetes_job_v1.create-user, helm_release.mail]
  chart = "wordpress"
  name  = "site"
  namespace = kubernetes_namespace.namespace.metadata.0.name
  repository = "https://charts.bitnami.com/bitnami"
  set {
    name  = "mariadb.enabled"
    value = false
  }
  set {
    name  = "externalDatabase.host"
    value = var.database.host
  }
  set {
    name  = "externalDatabase.port"
    value = 3306
  }
  set {
    name  = "externalDatabase.user"
    value = data.vault_generic_secret.secret.data["username"]
  }
  set {
    name  = "externalDatabase.database"
    value = data.vault_generic_secret.secret.data["database"]
  }
  set {
    name  = "externalDatabase.password"
    value = data.vault_generic_secret.secret.data["password"]
  }
  set {
    name  = "clusterDomain"
    value = var.cluster.domain
  }
  set {
    name  = "smtpHost"
    value = "mail"
  }
  set {
    name  = "smtpPort"
    value = 587
  }
#  set {
#    name  = "smtpProtocol"
#    value = "tls"
#  }
  set {
    name  = "wordpressUsername"
    value = data.vault_generic_secret.secret.data["username"]
  }
  set {
    name  = "wordpressPassword"
    value = data.vault_generic_secret.secret.data["password"]
  }
  set {
    name  = "wordpressEmail"
    value = data.vault_generic_secret.secret.data["email"]
  }
  set {
    name  = "wordpressFirstName"
    value = var.name.first
  }
  set {
    name  = "wordpressLastName"
    value = var.name.last
  }
  set {
    name  = "wordpressBlogName"
    value = var.blog-name
  }
  set {
    name  = "allowEmptyPassword"
    value = "false"
  }
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.hostname"
    value = data.vault_generic_secret.secret.data["domain"]
  }
  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "nginx"
  }
  set {
    name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = var.cluster.issuer
  }
  set {
    name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/limit-rps"
    value = "10"
    type = "string"
  }
  set {
    name  = "ingress.tls"
    value = "true"
  }
}
