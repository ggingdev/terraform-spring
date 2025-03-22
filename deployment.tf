resource "kubernetes_deployment" "springboot_app" {
  metadata {
    name = "springboot"
    labels = {
      app = "springboot-app"
    }
  }

  spec {
    replicas = 4

    selector {
      match_labels = {
        app = "springboot-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "springboot-app"
        }
      }

      spec {
        container {
          name  = "springboot"
          image = "ggingdev/springboot:latest"
          port {
            container_port = 8080
            host_port      = 8080
          }
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "subnet-type"
                  operator = "In"
                  values   = ["private"]
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_service" "springboot_service" {
  metadata {
    name = "springboot-service"
  }

  spec {
    selector = {
      app = "springboot-app"
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.springboot_app]
}
