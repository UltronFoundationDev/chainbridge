variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "module_name" {
  description = "The name of the module"
  type        = string
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
