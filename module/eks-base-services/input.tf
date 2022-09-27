variable "name" {
  type = string
}

variable "external_dns_zones" {
  type = list(string)
}

variable "tags" {
  default = {}
}

variable "eks_cluster_id" {
  type = string
}

variable "external_dns_values" {
  default = {}
}

variable "external_dns_version" {
  default = "6.9.0"
}
