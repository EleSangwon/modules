module "iam_role_external_dns" {
  providers = {
    aws = aws.dev
  }

  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "4.1.0"
  create_role                   = true
  role_name                     = "external-dns-${var.name}"
  provider_url                  = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
  role_policy_arns              = [aws_iam_policy.external_dns.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.k8s_service_account_namespace}:external-dns"]
}

resource "aws_iam_openid_connect_provider" "cross_account_dns" {
  provider        = aws.dev
  url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

data "aws_route53_zone" "external_dns" {
  provider = aws.dev
  count    = length(var.external_dns_zones)
  name     = var.external_dns_zones[count.index]
}

resource "aws_iam_policy" "external_dns" {
  provider    = aws.dev
  name_prefix = "external-dns"
  description = "EKS external-dns policy for cluster ${data.aws_eks_cluster.cluster.id}"
  policy      = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource": ${jsonencode(formatlist("arn:aws:route53:::hostedzone/%s", data.aws_route53_zone.external_dns[*].zone_id))}
      },
      {
        "Effect": "Allow",
        "Action": [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  }
  EOF
}

resource "local_file" "external_dns" {
  filename = "values/helm_external_dns.yml"
  content = yamlencode(merge({
    provider   = "aws"
    registry   = "txt"
    txtOwnerId = var.name
    aws = {
      region   = data.aws_region.current.name
      zoneType = "public"
    }
    domainFilters = var.external_dns_zones
    serviceAccount = {
      name = "external-dns"
      annotations = {
        "eks.amazonaws.com/role-arn" : module.iam_role_external_dns.iam_role_arn
      }
    }
    sources = [
      "service",
      "ingress",
    ]
  }, var.external_dns_values))
}

resource "helm_release" "external_dns" {
  name            = "external-dns"
  repository      = "https://charts.bitnami.com/bitnami"
  version         = var.external_dns_version
  chart           = "external-dns"
  namespace       = "kube-system"
  cleanup_on_fail = true
  atomic          = true
  reset_values    = true

  values = [local_file.external_dns.content]
}
