locals {
  chainbridge_configs_s3_bucket = format("%s-configstore-%s-%s-env",
    var.module_name,
    var.aws_account_id,
    var.environment
  )
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  create_bucket = true
  bucket        = local.chainbridge_configs_s3_bucket
  acl           = "private"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

}
