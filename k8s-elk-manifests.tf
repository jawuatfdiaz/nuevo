provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)
}

provider "kubectl" {
  host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}

resource "helm_release" "elastic" {
  name             = "elastic-operator"
  repository       = "https://helm.elastic.co"
  chart            = "eck-operator"
  namespace        = "elastic-system"
  create_namespace = "true"
  depends_on       = [azurerm_kubernetes_cluster.main_aks]
}

resource "time_sleep" "wait_30_seconds" {
  depends_on      = [helm_release.elastic]
  create_duration = "30s"
}

## Create Elasticsearch manifest
resource "kubectl_manifest" "elastic_quickstart" {
  yaml_body = file("manifest/elastic.yaml")
  provisioner "local-exec" {
    command = "sleep 30"
  }

  depends_on = [time_sleep.wait_30_seconds]
}

# Create Logstash manifest
resource "kubectl_manifest" "logstash_quickstart" {
  yaml_body = file("manifest/logstash2.yml")
  provisioner "local-exec" {
    command = "sleep 30"
  }
  depends_on = [time_sleep.wait_30_seconds]
}

## Create Kibana manifest
resource "kubectl_manifest" "kibana_quickstart" {
  yaml_body = file("manifest/kibana.yaml")
  provisioner "local-exec" {
    command = "sleep 30"
  }
  depends_on = [kubectl_manifest.elastic_quickstart]
}

## Create Metricbeat manifest
resource "kubectl_manifest" "metricbeat_cluster_role" {
  yaml_body = file("manifest/cluster_role.yaml")
  provisioner "local-exec" {
    command = "sleep 8"
  }
  depends_on = [kubectl_manifest.kibana_quickstart]
}

## Create Metricbeat manifest
resource "kubectl_manifest" "metricbeat_sa" {
  yaml_body = file("manifest/metricbeat_sa.yaml")
  provisioner "local-exec" {
    command = "sleep 8"
  }
  depends_on = [kubectl_manifest.metricbeat_cluster_role]
}




## Create Metricbeat manifest
resource "kubectl_manifest" "metricbeat_cluster_role_binding" {
  yaml_body = file("manifest/metricbeat_cluster_role_binding.yaml")
  provisioner "local-exec" {
    command = "sleep 8"
  }
  depends_on = [kubectl_manifest.metricbeat_sa]
}

## Create Metricbeat manifest
resource "kubectl_manifest" "metricbeat" {
  yaml_body = file("manifest/metricbeat.yaml")
  provisioner "local-exec" {
    command = "sleep 30"
  }
  depends_on = [kubectl_manifest.metricbeat_cluster_role_binding]
}

data "kubernetes_service" "elb_kibana_svc" {
  metadata {
    name = "quickstart-kb-http"
  }
  depends_on = [kubectl_manifest.kibana_quickstart]
}

data "kubernetes_secret" "psswd_kibana_web" {
  metadata {
    name = "quickstart-es-elastic-user"
  }
  depends_on = [kubectl_manifest.kibana_quickstart]
}

output "elb_kibana_svc_ip" {
  value = "https://${data.kubernetes_service.elb_kibana_svc.status[0].load_balancer[0].ingress[0].ip}:5601"
}

output "psswd_kibana_web_str" {
  sensitive = true
  value     = data.kubernetes_secret.psswd_kibana_web.data["elastic"]
}

output "user_kibana_web_str" {
  value = "elastic"
}



resource "kubectl_manifest" "apply_manifest" {
  yaml_body = file("manifest/deploy.yaml")
}



#data "kubernetes_pod" "post_apply_command" {
#  metadata {
#    name = "resources"
#  }
#  depends_on = [kubectl_manifest.apply_manifest]
#}

resource "kubernetes_pod" "test" {
  metadata {
    name = "docker-log-generator"
    namespace= "ms"
  }

  spec {
    container {
      image = "coffeeapplied/dockerloggenerator:1.0.2"
      name  = "docker-log-generator"
    }
  }
  depends_on = [kubectl_manifest.apply_manifest]
}





#resource "kubectl_manifest" "micro" {
#  yaml_body = file("manifest/random.yaml")
#  provisioner "local-exec" {
#	command = "sleep 30"
#  }
#  depends_on = [time_sleep.wait_30_seconds]
#}

#resource "null_resource" "connect_aks" {
#    triggers = {
#        cluster_created = azurerm_kubernetes_cluster.main_aks.name
#    }  
#    provisioner "local-exec" {
#        command = "az aks get-credentials --resource-group RSGRMAIN-${var.name} --name aks-elk-${local.timestamp_full}-${random_string.name.result}"
#   }
#    provisioner "local-exec" {
#        command = "kubectl create namespace random"
#    }
#    provisioner "local-exec" {
#        command = "kubectl apply -f roles/terraform_aks_template/files/azure-aks-tf/ms/random.yaml"
#    }
#    provisioner "local-exec" {
#        command = "kubectl set image deployment.v1.apps/random random=chentex/random-logger:latest -n random"
#    }
#}
