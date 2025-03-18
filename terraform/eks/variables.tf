// General variables
variable "argocd_domainname" {
  type        = string
  description = "Domain used for ArgoCD"
  default     = "nbat2-dev.com"
}

variable "argocd_hostname_prefix" {
  type        = string
  description = "Prefix added to domain used for ArgoCD"
  default     = "argocd"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for resource names"
  default     = "nbat2-hub"
}

# variable "repository_branch" {
#   type        = string
#   description = "Repository branch used as target for ArgoCD Apps"
#   default     = "main"
# }

# variable "repository_url" {
#   type        = string
#   description = "Repository url where ArgoCD Apps are stored"
#   default     = ""
# }

variable "tags" {
  type        = map(string)
  description = "Default tags for all resources"
  default = {
    Environment = "prd"
  }
}

// Networking variables

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "cluster_ip_family" {
  description = "The IP family used to assign Kubernetes pod and service addresses. Valid values are `ipv4` (default) and `ipv6`. You can only specify an IP family when you create a cluster, changing this value will force a new cluster to be created"
  type        = string
  default     = "ipv4"
}

variable "eks_vpc_cni_custom_networking" {
  description = "Use custom networking configuration for AWS VPC CNI"
  type        = bool
  default     = true
}

// Cluster variables

variable "central_eks_cluster" {
  type = object({
    cluster_name                      = string
    cluster_version                   = string
    publicly_accessible_cluster       = bool
    publicly_accessible_cluster_cidrs = list(string)
    cluster_support_type              = string
  })
  description = "Details of Central EKS cluster"
  default = {
    cluster_name                      = "nbat2-hub"
    cluster_version                   = "1.30"
    publicly_accessible_cluster       = true
    publicly_accessible_cluster_cidrs = ["0.0.0.0/0"]
    cluster_support_type              = "STANDARD"
  }
}

variable "restrict_instance_metadata" {
  type        = bool
  description = "Restrict pods from accesssing node instance metadata endpoint"
  default     = true
}

variable "sso_cluster_admin_role_name" {
  type        = string
  description = "Name of AWS IAM Identity Center role added as cluster admin"
  default     = "AWSReservedSSO_AWSSSO-NBAT2_66cc46e0d7d94e79"
}