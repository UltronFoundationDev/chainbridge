terraform {
  required_providers {
    aws = {
      version = "~> 4.14.0"
      source  = "hashicorp/aws"
    }
  }
}

data "aws_caller_identity" "current" {
  # Use this data source to get the access to the effective Account ID, User ID, and ARN in which Terraform is
  # authorized.
}

# get current AWS provider region
data "aws_region" "current" {

}

locals {
  aws_account_id  = data.aws_caller_identity.current.account_id
  resource_prefix = "${var.project_name}-${var.environment}-${var.aws_region}"
  tags = {
    Terraform   = "true"
    Project     = var.project_name
    Environment = var.environment
  }
}
