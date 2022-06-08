variable "aws_region" {
  description = "The name of region."
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID."
  type        = string
}

variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = ""
}

variable "module_name" {
  description = "The name of the project."
  type        = string
  default     = ""
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

variable "ec2_instance_fqdn" {
  description = "Fully Qualified Domain Name for the EC2 instance."
  type        = string
  default     = null
}

variable "instance_class" {
  description = "The RDS instance class."
  type        = string
}

variable "engine_version" {
  description = "The postgres engine version."
  type        = string
}

variable "domain_name" {
  description = "Domain Name."
  type        = string
  default     = null
}

variable "enabled" {
  description = "Whether to create the resources when applying."
  type        = bool
  default     = true
}

variable "chainbridge_ids" {
  description = "Chainbridge node IDs"
  type        = list(string)
}

variable "chainbridge_instance_type" {
  description = "The type of ec2 instance."
  type        = string
}

variable "chainbridge_volume_type" {
  description = "The type of root EBS volume."
  type        = string
}

variable "chainbridge_volume_size" {
  description = "The size of root EBS volume."
  type        = number
}
