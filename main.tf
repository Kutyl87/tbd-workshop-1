locals {
  main_subnet_address  = "10.10.10.0/24"
  notebook_vpc_name    = "main-vpc"
  notebook_subnet_name = "subnet-01"
  notebook_subnet_id   = "${var.region}/${local.notebook_subnet_name}"
}

module "vpc" {
  source         = "./modules/vpc"
  project_name   = var.project_name
  region         = var.region
  network_name   = local.notebook_vpc_name
  subnet_name    = local.notebook_subnet_name
  subnet_address = local.main_subnet_address
}


module "gcr" {
  source       = "./modules/gcr"
  project_name = var.project_name
}

## Jupyter Docker image no longer needed - using Jupyter on Dataproc cluster instead
#module "jupyter_docker_image" {
#  depends_on         = [module.gcr]
#  source             = "./modules/jupyter_docker_image"
#  registry_hostname  = module.gcr.registry_hostname
#  registry_repo_name = coalesce(var.project_name)
#  project_name       = var.project_name
#  spark_version      = local.spark_version
#  dbt_version        = local.dbt_version
#  dbt_spark_version  = local.dbt_spark_version
#}

## Vertex AI Workbench replaced with Jupyter on Dataproc cluster
## See Dataproc module configuration for Jupyter optional component
#module "vertex_ai_workbench" {
#  depends_on   = [module.vpc]
#  source       = "./modules/vertex-ai-workbench"
#  project_name = var.project_name
#  region       = var.region
#  network      = module.vpc.network.network_id
#  subnet       = module.vpc.subnets[local.notebook_subnet_id].id
#
#  ai_notebook_instance_owner = var.ai_notebook_instance_owner
#  ## To remove before workshop
#  # FIXME:remove
#  ai_notebook_image_repository = element(split(":", module.jupyter_docker_image.jupyter_image_name), 0)
#  ai_notebook_image_tag        = element(split(":", module.jupyter_docker_image.jupyter_image_name), 1)
#  ## To remove before workshop
#}

#
module "dataproc" {
  depends_on    = [module.vpc]
  source        = "./modules/dataproc"
  project_name  = var.project_name
  region        = var.region
  subnet        = module.vpc.subnets[local.notebook_subnet_id].id
  machine_type  = "e2-standard-4"
  image_version = "2.2.69-ubuntu22"
}

## Uncomment for Dataproc batches (serverless)
#module "metastore" {
#  source = "./modules/metastore"
#  project_name   = var.project_name
#  region         = var.region
#  network        = module.vpc.network.network_id
#}

# module "composer" {
#   depends_on     = [module.vpc]
#   source         = "./modules/composer"
#   project_name   = var.project_name
#   network        = module.vpc.network.network_name
#   subnet_address = local.composer_subnet_address
#   env_variables = {
#     "AIRFLOW_VAR_PROJECT_ID" : var.project_name,
#     "AIRFLOW_VAR_REGION_NAME" : var.region,
#     "AIRFLOW_VAR_BUCKET_NAME" : local.code_bucket_name,
#     "AIRFLOW_VAR_PHS_CLUSTER" : module.dataproc.dataproc_cluster_name,
#     "AIRFLOW_VAR_WRK_NAMESPACE" : local.composer_work_namespace,
#     "AIRFLOW_VAR_DBT_GIT_REPO" : local.dbt_git_repo,
#     "AIRFLOW_VAR_DBT_GIT_REPO_BRANCH" : local.dbt_git_repo_branch
#   }
# }

# module "dbt_docker_image" {
#   depends_on         = [module.composer, module.gcr]
#   source             = "./modules/dbt_docker_image"
#   registry_hostname  = module.gcr.registry_hostname
#   registry_repo_name = coalesce(var.project_name)
#   project_name       = var.project_name
#   spark_version      = local.spark_version
#   dbt_version        = local.dbt_version
#   dbt_spark_version  = local.dbt_spark_version
# }

# module "data-pipelines" {
#   source               = "./modules/data-pipeline"
#   project_name         = var.project_name
#   region               = var.region
#   bucket_name          = local.code_bucket_name
#   data_service_account = module.composer.data_service_account
#   dag_bucket_name      = module.composer.gcs_bucket
#   data_bucket_name     = local.data_bucket_name
# }




# resource "kubernetes_service" "dbt-task-service" {
#   metadata {
#     name      = "dbt-task-service"
#     namespace = local.composer_work_namespace
#     labels = {
#       app = "dbt-app"
#     }
#   }

#   spec {
#     type = "NodePort"
#     selector = {
#       app = "dbt-app"
#     }
#     port {
#       name        = "spark-driver"
#       protocol    = "TCP"
#       port        = local.spark_driver_port
#       target_port = local.spark_driver_port
#       node_port   = local.spark_driver_port

#     }
#     port {
#       name        = "spark-block-mgr"
#       protocol    = "TCP"
#       port        = local.spark_blockmgr_port
#       target_port = local.spark_blockmgr_port
#       node_port   = local.spark_blockmgr_port
#     }

#   }
# }

#checkov:skip=CKV_GCP_38: "Testowa VM do warsztatu, bez CSEK - nie jest to krytyczna maszyna"
resource "google_compute_instance" "cost-test" {
  name         = "cost-test"
  project      = var.project_name
  machine_type = "e2-standard-4"
  zone         = "europe-west1-b"

  # CKV_GCP_32: blokujemy globalne SSH keys
  metadata = {
    block-project-ssh-keys = "true"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
    # tu można by dodać CSEK/CMEK, ale dla warsztatu to overkill
  }

  # CKV_GCP_39: włączamy Shielded VM
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  network_interface {
    network = module.vpc.network.network_id

    # CKV_GCP_40: NIE dodajemy access_config => brak publicznego IP
    # access_config {}  # usuwamy tę linię
  }
}
