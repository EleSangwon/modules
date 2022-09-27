terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 3.46"
      configuration_aliases = [aws.dev]
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.3"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.2"
    }
  }
}

locals {
  k8s_service_account_namespace = "kube-system"
}

data "aws_region" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
