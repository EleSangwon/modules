variable "eks_version" {
  type = string
}

variable "name" {
  type = string
}

variable "tags" {
  default = {}
}

variable "vpc_id" {
  type = string
}

variable "private_subnets_by_az" {
  type = map(list(string))
}

variable "default_instance_type" {
  default = "t3.medium"
}

variable "spot_instance_types" {
  default = ["t3.large", "t3.small"]
}

variable "arm_instance_type" {
  default = "t3.small"
}

variable "taint_spot_instances" {
  default = true
}

variable "node_group_defaults" {
  default = {}
}

variable "ondemand_node_group_configuration" {
  default = {}
}

variable "spot_node_group_configuration" {
  default = {}
}

variable "extra_node_groups" {
  default = {}
}

variable "eks_map_roles" {
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
}

variable "eks_map_users" {
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
}