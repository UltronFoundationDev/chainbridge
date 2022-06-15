locals {
  ec2_instance_name = "${var.project_name}-${var.environment}-${var.module_name}-node"
  resource_prefix = format("%s-%s-%s",
    var.project_name,
    var.environment,
    var.module_name
  )

  path_prefix = format("%s/%s/%s",
    var.project_name,
    var.environment,
    var.aws_region
  )

  tags = {
    Environment = var.environment,
    Terraform   = "true",
  }
}

data "aws_caller_identity" "current" {
  # Use this data source to get the access to the effective Account ID, User ID, and ARN in which Terraform is
  # authorized.
}

# get current AWS provider region
data "aws_region" "current" {

}


data "aws_ssm_parameter" "chainbridge_parameters" {
  for_each = {
    for id, chainbridge_id in toset(var.chainbridge_ids) : id => chainbridge_id
    if var.chainbridge_ids != ""
  }
  name = "/${local.path_prefix}/${var.module_name}-node-${each.key}/parameters"
}

# -------------------------------------------------- AMI ----------------------------------------------------------
# Find an official Ubuntu AMI

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["099720109477"] # Canonical official
}

# ------------------------------------------
# EC2 SSH key to use with project instances
# ------------------------------------------

# ----------------------------------------------- VARIABLES definition -------------------------------------------------
variable "chainbridge_ssh_public_key" {
  description = "The public key material to create a SSH key pair resource."
  type        = string
  default     = ""
}
#=======================================================================================================================

# ----------------------------------------------- MAIN functionality ---------------------------------------------------
resource "tls_private_key" "chainbridge_ssh_key" {
  count = (var.enabled && length(var.chainbridge_ssh_public_key) == 0) ? 1 : 0
  # (Required) The name of the algorithm to use for the key. Currently-supported values are "RSA" and "ECDSA".
  algorithm = "RSA"
}

# ---------------------------------
# Make sure EC2 SSH key is created
# ---------------------------------
resource "aws_key_pair" "chainbridge_ssh_key" {
  count = var.enabled ? 1 : 0
  # (Optional) Creates a unique name beginning with the specified prefix. Conflicts with key_name.
  key_name_prefix = "chainbridge-node-ec2-ssh-key-"
  # (Required) The public key material.
  public_key = length(var.chainbridge_ssh_public_key) > 0 ? var.chainbridge_ssh_public_key : join("", tls_private_key.chainbridge_ssh_key.*.public_key_openssh)
}
#=======================================================================================================================

# -------------------------------------------------- EC2 Instances -----------------------------------------------------
resource "aws_instance" "chainbridge_node" {
  for_each = {
    for id, chainbridge_id in toset(var.chainbridge_ids) : id => chainbridge_id
    if var.chainbridge_ids != ""
  }
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.chainbridge_instance_type
  root_block_device {
    volume_type = var.chainbridge_volume_type
    volume_size = var.chainbridge_volume_size
  }
  iam_instance_profile = join("", aws_iam_instance_profile.chainbridge_profile.*.name)
  user_data = base64encode(templatefile("${path.module}/templates/node-userdata.tpl.sh",
    {
      aws_account_id                = var.aws_account_id
      project_name                  = var.project_name
      module_name                   = var.module_name
      aws_region                    = var.aws_region
      environment                   = var.environment
      aws_ec2_iam_role              = join("", aws_iam_role.chainbridge_role.*.name)
      ec2_instance_name             = "${local.ec2_instance_name}-${each.key}"
      chainbridge_configs_s3_bucket = var.chainbridge_configs_s3_bucket
      base64_file                   = jsondecode(data.aws_ssm_parameter.chainbridge_parameters[each.key].value)["base64_file"]
      base64_jsonconfig             = jsondecode(data.aws_ssm_parameter.chainbridge_parameters[each.key].value)["base64_jsonconfig"]
      chainbridge_id                = jsondecode(data.aws_ssm_parameter.chainbridge_parameters[each.key].value)["chainbridge_id"]
      chainbridge_pubkey            = jsondecode(data.aws_ssm_parameter.chainbridge_parameters[each.key].value)["chainbridge_pubkey"]
      address                       = jsondecode(data.aws_ssm_parameter.chainbridge_parameters[each.key].value)["address"]
      chainbridge_password          = jsondecode(data.aws_ssm_parameter.chainbridge_parameters[each.key].value)["chainbridge_password"]
    }
  ))
  key_name               = join("", aws_key_pair.chainbridge_ssh_key.*.key_name)
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [join("", aws_security_group.chainbridge.*.id)]
  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.module_name}-node-${each.key}"
    }
  )
}
