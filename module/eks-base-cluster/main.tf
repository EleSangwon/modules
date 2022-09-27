terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.46"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.3"
    }
  }
}

locals {
  k8s_service_account_namespace = "kube-system"
}

data "aws_region" "current" {}

data "aws_ec2_instance_type_offerings" "spot_instance_types" {
  for_each = var.private_subnets_by_az

  filter {
    name   = "location"
    values = [each.key]
  }

  filter {
    name   = "instance-type"
    values = var.spot_instance_types
  }

  location_type = "availability-zone"
}

module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.1.0"

  cluster_name    = var.name
  cluster_version = var.eks_version
  subnets         = [for zone in var.private_subnets_by_az : zone[0]]
  vpc_id          = var.vpc_id
  enable_irsa     = true
  tags            = var.tags
  map_roles       = var.eks_map_roles
  map_users       = var.eks_map_users

  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]

  cluster_enabled_log_types = [
    "api",
    "authenticator",
    "audit",
    "controllerManager",
    "scheduler",
  ]

  node_groups_defaults = merge({
    max_capacity = 3
    # Required for kubelet_extra_args and other customizations
    create_launch_template = true
  }, var.node_group_defaults)

  node_groups = merge(
    # Create an ondemand node group for each AZ (to allow balancing)
    {
      for name, subnets in var.private_subnets_by_az : "${substr(name, -1, -1)}-default" => merge({
        instance_types = [var.default_instance_type]
        subnets        = subnets
      }, var.ondemand_node_group_configuration)
    },
    # Create a spot node group for each AZ (for now, only one set of instance types is supported)
    {
      for name, subnets in var.private_subnets_by_az : "${substr(name, -1, -1)}-spot" => merge({
        instance_types = toset(data.aws_ec2_instance_type_offerings.spot_instance_types[name].instance_types)
        subnets        = subnets
        capacity_type  = "SPOT"
        min_capacity   = 0
        taints = var.taint_spot_instances ? [
          {
            key    = "NodeCapacityType"
            value  = "SPOT"
            effect = "NO_SCHEDULE"
          }
        ] : []
      }, var.spot_node_group_configuration)
    },
    # Add extra node groups (optional)
    var.extra_node_groups
  )
}

resource "aws_kms_key" "eks" {
  description = "EKS Secret Encryption Key"
  tags        = var.tags
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_id
}