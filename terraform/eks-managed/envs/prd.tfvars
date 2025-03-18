vpc_name = "nbat2-prd"

managed_eks_cluster = {
  cluster_name                      = "managed-cluster-prd"
  cluster_version                   = "1.30"
  publicly_accessible_cluster       = true
  publicly_accessible_cluster_cidrs = ["0.0.0.0/0"]
  cluster_support_type              = "STANDARD"
}

app_repository_url = "https://github.com/codefresh-contrib/gitops-cert-level-2-examples"

app_repository_branch = "main"

app_repository_path = "custom-diff/02-external-app"

create_baseapp = false

enable_aws_load_balancer_controller = true

enable_external_dns = false