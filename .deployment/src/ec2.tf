module "chainbridge" {
  source            = ".//chainbridge"
  aws_account_id    = var.aws_account_id
  aws_region        = var.aws_region
  environment       = var.environment
  project_name      = var.project_name
  ec2_instance_type = var.ec2_instance_type
  volume_type       = var.volume_type
  volume_size       = var.volume_size
}
