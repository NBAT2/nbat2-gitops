vpc_name = "nbat2-dev"

managed_eks_cluster = {
  cluster_name                      = "managed-cluster-dev"
  cluster_version                   = "1.30"
  publicly_accessible_cluster       = true
  publicly_accessible_cluster_cidrs = ["0.0.0.0/0"]
  cluster_support_type              = "STANDARD"
}
sso_cluster_admin_role_name = "AWSReservedSSO_AWSSSO-NBAT2_88a218ae83ba01e2"

create_baseapp = false

enable_aws_load_balancer_controller = true

enable_external_dns = false

tags = {
  Environment = "dev"
}

environment = "dev"

hub_parameter_arn = "arn:aws:ssm:us-east-1:038462767168:parameter/hub"