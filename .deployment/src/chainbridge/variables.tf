variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "module_name" {
  description = "The name of the module"
  type        = string
  default     = "graph-node"
}

variable "aws_region" {
  description = "The name of region."
  type        = string
}

variable "environment" {
  description = "The name of the project environment."
  type        = string
}

variable "create" {
  description = "Whether to create resources."
  type        = bool
  default     = true
}

variable "aws_account_id" {
  description = "AWS Account ID."
  type        = string
}

variable "ec2_instance_type" {
  description = "The type of the instance."
  type        = string
}

variable "volume_type" {
  description = "The type of root EBS volume."
  type        = string
}

variable "volume_size" {
  description = "The size of root EBS volume."
  type        = number
}

variable "ec2_instance_name" {
  description = "The type of the instance."
  type        = string
  default     = ""
}
