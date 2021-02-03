terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "1.13.3"
    }

    helm = {
      source = "hashicorp/helm"
      version = "1.3.2"
    }

  }
}

provider "kubernetes" {
  config_context = "paulb-lab-k8s-admin"
}

provider "helm" {
}

resource "kubernetes_namespace" "ratingsapp_ns" {
  metadata {
    name = "ratingsapp"
  }
}

output "ratingsapp_namespace" {
    value = kubernetes_namespace.ratingsapp_ns.metadata[0].name
}

resource "helm_release" "mongodb_ratings" {
  name       = "ratings"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mongodb"
  namespace = kubernetes_namespace.ratingsapp_ns.metadata[0].name

  set {
    name  = "auth.username"
    value = var.mongodb_username
  }

  set_sensitive {
    name  = "auth.password"
    value = var.mongodb_password
  }

  set {
    name  = "auth.database"
    value = "ratingsdb"
  }
}

output "helm_mongodb_release_metadata" {
    value = helm_release.mongodb_ratings.metadata
}

resource "kubernetes_secret" "mongodb_secret" {
  metadata {
    name = "mongosecret"
    namespace = "ratingsapp"
  }

  data = {
    MONGOCONNECTION = "mongodb://${var.mongodb_username}:${var.mongodb_password}@ratings-mongodb.ratingsapp:27017/ratingsdb"
  }
}

# ratings-api deployment
resource "kubernetes_deployment" "ratings_api_deployment" {
  metadata {
    name = "ratings-api"
    namespace = "ratingsapp"
  }

  spec {
    #replicas = 1

    selector {
      match_labels = {
        app = "ratings-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "ratings-api"
        }
      }

      spec {
        container {
          image = "paulblabacr5qlpc.azurecr.io/ratings-api:v1"
          name  = "ratings-api"
          image_pull_policy = "Always"

          port {
            container_port = 3000
          }

          env {
            name = "MONGODB_URI"
            value_from {
                secret_key_ref {
                    key = "MONGOCONNECTION"
                    name = "mongosecret"
                }
            }
          }

          resources {
            limits {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests {
              cpu    = "250m"
              memory = "64Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 3000
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 3000
            }
          }

        }
      }
    }
  }
}

# output "ratings_api_deployment_output" {
#     value = kubernetes_deployment.ratings_api_deployment
# }

resource "kubernetes_service" "ratings_api_service" {
  metadata {
    name = "ratings-api"
    namespace = "ratingsapp"
  }
  spec {
    selector = {
      app = "ratings-api"
    }
    port {
      port        = 80
      target_port = 3000
      protocol = "TCP"
    }

    type = "ClusterIP"
  }
}

# ratings-web deployment
resource "kubernetes_deployment" "ratings_web_deployment" {
  metadata {
    name = "ratings-web"
    namespace = "ratingsapp"
  }

  spec {
    #replicas = 1

    selector {
      match_labels = {
        app = "ratings-web"
      }
    }

    template {
      metadata {
        labels = {
          app = "ratings-web"
        }
      }

      spec {
        container {
          image = "paulblabacr5qlpc.azurecr.io/ratings-web:v1"
          name  = "ratings-web"
          image_pull_policy = "Always"

          port {
            container_port = 8080
          }

          env {
            name = "API"
            value = "http://ratings-api.ratingsapp.svc.cluster.local"
          }

          resources {
            limits {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests {
              cpu    = "250m"
              memory = "64Mi"
            }
          }

        }
      }
    }
  }
}

resource "kubernetes_service" "ratings_web_service" {
  metadata {
    name = "ratings-web"
    namespace = "ratingsapp"
  }
  spec {
    selector = {
      app = kubernetes_deployment.ratings_web_deployment.metadata[0].name
    }
    port {
      port        = 80
      target_port = 8080
      protocol = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_namespace" "ingress_ns" {
  metadata {
    name = "ingress"
  }
}

resource "helm_release" "ingress_nginx_controller" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_ns.metadata[0].name

  set {
    name  = "controller.replicaCount"
    value = 2
  }

}

resource "kubernetes_ingress" "nginx_ingress" {
  metadata {
    name = "ratings-web-ingress"
    namespace = "ratingsapp"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/issue-temporary-certificate" = "true"
      "acme.cert-manager.io/http01-edit-in-place" = "true"
      "cert-manager.io/cluster-issuer" = "letsencrypt"
    }
  }

  spec {
    rule {
      host = "my.smoothie.az.pblivelab.com"
      http {
        path {
          backend {
            service_name = "ratings-web"
            service_port = 80
          }

          path = "/"
        }
      }
    }

    tls {
      hosts = [ "my.smoothie.az.pblivelab.com" ]
      secret_name = "my-smoothie-az-pblivelab-tls"
    }
  }

  depends_on = [ helm_release.ingress_nginx_controller ]
}

resource "kubernetes_namespace" "cert_manager_ns" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager_release" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager_ns.metadata[0].name
  version = "v1.1.0"

  set {
    name  = "installCRDs"
    value = true
  }

}
