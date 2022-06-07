module "chainbridge" {
  source                    = ".//chainbridge"
  aws_account_id            = var.aws_account_id
  aws_region                = var.aws_region
  environment               = var.environment
  project_name              = var.project_name
  chainbridge_ids           = var.chainbridge_ids
  chainbridge_instance_type = var.chainbridge_instance_type
  volume_type               = var.chainbridge_volume_type
  volume_size               = var.chainbridge_volume_size
}
