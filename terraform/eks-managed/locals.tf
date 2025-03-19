locals {
  cni_az_subnet_map                  = { for availability_zone in var.availability_zones : availability_zone => data.aws_subnets.private[availability_zone].ids[1 % length(data.aws_subnets.private[availability_zone].ids)] }
  public_subnet_ids                  = [for availability_zone in var.availability_zones : data.aws_subnets.public[availability_zone].ids[0]]
  private_subnet_ids                 = [for availability_zone in var.availability_zones : data.aws_subnets.private[availability_zone].ids[0]]
  decoded_hub_values                 = jsondecode(data.aws_ssm_parameter.hub.value)
  argocd_role_arn                    = local.decoded_hub_values.argocd_iam_role_arn
  cluster_certificate_authority_data = local.decoded_hub_values.cluster_certificate_authority_data
  cluster_endpoint                   = local.decoded_hub_values.cluster_endpoint
  cluster_name                       = local.decoded_hub_values.cluster_name
  spoke_cluster_secrets_arn          = local.decoded_hub_values.spoke_cluster_secrets_arn
}
