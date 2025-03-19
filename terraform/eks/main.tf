data "aws_iam_policy_document" "spoke_cluster_secrets" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgId"
      values = [
        data.aws_organizations_organization.current.id
      ]
    }
  }
}

resource "aws_iam_role" "spoke_cluster_secrets" {
  name               = "argocd-hub-spoke-access"
  assume_role_policy = data.aws_iam_policy_document.spoke_cluster_secrets.json
}

module "central_eks" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=c60b70fbc80606eb4ed8cf47063ac6ed0d8dd435"

  cluster_name    = var.central_eks_cluster.cluster_name
  cluster_version = var.central_eks_cluster.cluster_version

  cluster_endpoint_public_access       = var.central_eks_cluster.publicly_accessible_cluster
  cluster_endpoint_public_access_cidrs = var.central_eks_cluster.publicly_accessible_cluster ? var.central_eks_cluster.publicly_accessible_cluster_cidrs : null

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
    kube-proxy = {
      before_compute = true
      most_recent    = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        eniConfig = var.eks_vpc_cni_custom_networking ? {
          create  = true
          region  = data.aws_region.current.name
          subnets = { for az, subnet_id in local.cni_az_subnet_map : az => { securityGroups : [module.central_eks.node_security_group_id], id : subnet_id } }
        } : null
        env = {
          AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = var.eks_vpc_cni_custom_networking ? "true" : "false"
          ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
      } })
    }
  }

  vpc_id                   = data.aws_vpc.vpc.id
  subnet_ids               = local.private_subnet_ids
  control_plane_subnet_ids = local.public_subnet_ids
  cluster_ip_family        = var.cluster_ip_family

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = false

  eks_managed_node_groups = {
    nodegroup = {
      instance_types = ["t3.medium"]

      min_size     = 3
      max_size     = 3
      desired_size = 3

      subnet_ids = local.private_subnet_ids

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = var.restrict_instance_metadata ? 1 : 2
      }
    }
  }

  access_entries = {
    spokes = {
      kubernetes_groups = []
      principal_arn     = aws_iam_role.spoke_cluster_secrets.arn

      policy_associations = {
        argocd = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            namespaces = ["argocd"]
            type       = "namespace"
          }
        }
      }
    }
  }
  cluster_upgrade_policy = {
    support_type = var.central_eks_cluster.cluster_support_type
  }
}

resource "aws_acm_certificate" "argocd" {
  domain_name       = local.argocd_hostname
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = false
  }
}

data "aws_route53_zone" "argocd" {
  name         = var.argocd_domainname
  private_zone = false
}

resource "aws_route53_record" "argocd" {
  for_each = {
    for dvo in aws_acm_certificate.argocd.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.argocd.zone_id
}

resource "aws_acm_certificate_validation" "argocd" {
  certificate_arn         = aws_acm_certificate.argocd.arn
  validation_record_fqdns = [for record in aws_route53_record.argocd : record.fqdn]
}

module "argocd_pod_identity" {
  depends_on = [module.central_eks]
  source     = "git::https://github.com/terraform-aws-modules/terraform-aws-eks-pod-identity?ref=f39ff40fd4f45d61dda0b1a26cb82e1a005e2417"

  name            = "${var.name_prefix}ManagementRole"
  use_name_prefix = false

  trust_policy_conditions = [
    {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    },
    {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.central_eks.cluster_arn]
    }
  ]

  associations = {
    controller = {
      cluster_name    = module.central_eks.cluster_name
      namespace       = "argocd"
      service_account = "argocd-application-controller"
    }
    server = {
      cluster_name    = module.central_eks.cluster_name
      namespace       = "argocd"
      service_account = "argocd-server"
    }
  }
}

module "eks_blueprints_addons" {
  depends_on = [module.central_eks, module.argocd_pod_identity]
  source     = "git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons.git?ref=a9963f4a0e168f73adb033be594ac35868696a91"

  cluster_name      = module.central_eks.cluster_name
  cluster_endpoint  = module.central_eks.cluster_endpoint
  cluster_version   = module.central_eks.cluster_version
  oidc_provider_arn = module.central_eks.oidc_provider_arn

  enable_argocd                       = true
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [
      {
        name  = "vpcId"
        value = data.aws_vpc.vpc.id
      }
    ]
  }
  enable_metrics_server          = true
  enable_external_dns            = true
  external_dns_route53_zone_arns = [data.aws_route53_zone.argocd.arn]
  argocd = {
    chart_version = "7.4.5"
    values        = [file("${path.module}/helm-values/argocd.yaml")]
  }
}

resource "time_sleep" "wait_lb_controller_deployment" {
  depends_on      = [module.eks_blueprints_addons]
  create_duration = "60s"
}

resource "helm_release" "argocdingress" {
  depends_on = [aws_acm_certificate_validation.argocd, time_sleep.wait_lb_controller_deployment]
  name       = "argocdingress"
  chart      = "${path.module}/../../charts/argocdingress"
  namespace  = "argocd"
  version    = "0.10.0"

  set {
    name  = "argocdlb.hostname"
    value = local.argocd_hostname
  }

  set {
    name  = "argocdlb.certificatearn"
    value = aws_acm_certificate.argocd.arn
  }

  set {
    name  = "argocdlb.subnetlist"
    value = join("\\,", local.public_subnet_ids)
  }
}


resource "aws_ssm_parameter" "hub" {
  name = "hub"
  type = "String"
  tier = "Advanced"
  value = jsonencode(
    {
      "cluster_name" : module.central_eks.cluster_name,
      "cluster_endpoint" : module.central_eks.cluster_endpoint
      "cluster_certificate_authority_data" : module.central_eks.cluster_certificate_authority_data,
      "cluster_region" : data.aws_region.current.name,
      "argocd_iam_role_arn" : module.argocd_pod_identity.iam_role_arn,
      "spoke_cluster_secrets_arn" : aws_iam_role.spoke_cluster_secrets.arn,
    }
  )
}

resource "aws_ram_resource_share" "hub" {
  name                      = "hub"
  allow_external_principals = false
}

resource "aws_ram_principal_association" "hub" {
  principal          = data.aws_organizations_organization.current.arn
  resource_share_arn = aws_ram_resource_share.hub.arn
}

resource "aws_ram_resource_association" "hub" {
  resource_arn       = aws_ssm_parameter.hub.arn
  resource_share_arn = aws_ram_resource_share.hub.arn
}
