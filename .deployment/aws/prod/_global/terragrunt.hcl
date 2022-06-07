# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that supports locking and enforces best
# practices: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # load project, environment and region wide variables
  global_vars      = read_terragrunt_config("global.hcl", read_terragrunt_config(find_in_parent_folders("global.hcl", "does-not-exist.fallback"), { locals = {} }))
  environment_vars = read_terragrunt_config("env.hcl", read_terragrunt_config(find_in_parent_folders("env.hcl", "does-not-exist.fallback"), { locals = {} }))
  region_vars      = read_terragrunt_config("region.hcl", read_terragrunt_config(find_in_parent_folders("region.hcl", "does-not-exist.fallback"), { locals = {} }))

  aws_account_id      = try(local.environment_vars.locals.aws_account_id, get_env("AWS_ACCOUNT_ID", get_aws_account_id()))
  aws_region          = local.region_vars.locals.aws_region
}

# This tells Terragrunt to automatically include all the settings from the 'root' `terragrunt.root.hcl` file
include {
  # `find_in_parent_folders` function returns the path to the first `terragrunt.root.hcl` file it finds in the parent
  # folders above the current `terragrunt.root.hcl` file.
  path = find_in_parent_folders()
}

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder.
terraform {
  # Note: the double slash (//) is intentional and required. It's part of Terraform's Git syntax for module sources.
  # See: https://www.terraform.io/docs/modules/sources.html
  # Terraform may display a "Terraform initialized in an empty directory" warning, but you can safely ignore it.)
  source = format("%s//_global", find_in_parent_folders("src"))
}

inputs = {
  # --------------------------
  # Common/General parameters
  # --------------------------
  # Whether to create the resources (`false` prevents the module from creating any resources).
  create      = true
  environment  = try(local.environment_vars.locals.environment_name, split("/", path_relative_to_include())[0])
  aws_region   = local.aws_region
  aws_account_id         = local.aws_account_id
}