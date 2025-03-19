data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_vpc" "vpc" {
  tags = {
    "Name" = "${var.vpc_name}-vpc"
  }
}

data "aws_subnets" "private" {
  for_each = toset(var.availability_zones)
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${data.aws_vpc.vpc.tags.Name}-private-${each.key}"]
  }
}

data "aws_subnets" "public" {
  for_each = toset(var.availability_zones)
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${data.aws_vpc.vpc.tags.Name}-public-${each.key}"]
  }
}

provider "aws" {
  alias  = "hub"
  region = "us-east-1"
}

data "aws_ssm_parameter" "hub" {
  name     = var.hub_parameter_arn
  provider = aws.hub
}



