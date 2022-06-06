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

  # extract variables we need for easy access
  project_name       = try(local.environment_vars.locals.project_name)
  module_name        = try(local.environment_vars.locals.module_name)
  environment        = try(local.environment_vars.locals.environment_name, split("/", path_relative_to_include())[0])
  aws_account_id     = try(local.environment_vars.locals.aws_account_id, get_env("AWS_ACCOUNT_ID", get_aws_account_id()))
  aws_region         = try(local.environment_vars.locals.aws_region)
  ### ---

  # --------------------------------------------------------------------
  # local variables to fill remote state settings of the current module
  # --------------------------------------------------------------------
  backend_s3_bucket_name      = "tf-state-${local.aws_account_id}-${local.module_name}-${local.environment}-env"
  backend_dynamodb_table_name = "tf-lock-${local.aws_account_id}-${local.module_name}-${local.environment}"
}

# Overrides the default minimum supported version of terraform. Terragrunt only officially supports the latest version
# of terraform, however in some cases an old terraform is needed.
terraform_version_constraint = "= 1.1.6"
# If the running version of Terragrunt doesn’t match the constraints specified, Terragrunt will produce an error and
# exit without taking any further actions.
terragrunt_version_constraint = "= 0.36.3"


# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder.
terraform {
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()

    arguments = [
      # Force Terraform to keep trying to acquire a lock for up to XX minutes if someone else already has the lock.
      "-lock-timeout=1m"
    ]
  }

  # remove cache-directory to reduce disk space usage
  after_hook "clear_terragrunt_cache" {
    commands     = ["plan", "apply", "destroy"]
    execute      = ["rm", "-rf", "--", "${get_terragrunt_dir()}/.terragrunt-cache"]
    run_on_error = true
  }
}


remote_state {
  backend = "s3"

  config = {
    region         = "us-east-1"
    bucket         = local.backend_s3_bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    dynamodb_table = local.backend_dynamodb_table_name
    encrypt        = true

    # Further, the config options:
    #   * s3_bucket_tags,
    #   * dynamodb_table_tags,
    #   * skip_bucket_versioning,
    #   * skip_bucket_ssencryption,
    #   * skip_bucket_accesslogging,
    #   * enable_lock_table_ssencryption
    # are only valid for backend s3. They are used by terragrunt and are not passed on to terraform.

    # use only if the cost for the extra object space is undesirable or the object store does not support access
    # logging
    skip_bucket_accesslogging = true

    s3_bucket_tags = {
      Name = local.backend_s3_bucket_name
    }

    dynamodb_table_tags = {
      Name = local.backend_dynamodb_table_name
    }
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL PARAMETERS
# These variables apply to all configurations in this subfolder. These are automatically merged into the child
# `terragrunt.hcl` config via the include block.
# ---------------------------------------------------------------------------------------------------------------------

# Configure root level variables that all resources can inherit.
inputs = merge(
  local.global_vars.locals,
  local.environment_vars.locals,
  local.region_vars.locals
)
