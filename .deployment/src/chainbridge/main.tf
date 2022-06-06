locals {
  ec2_instance_name = "${var.project_name}-${var.environment}-${var.module_name}"
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
variable "graph_ssh_public_key" {
  description = "The public key material to create a SSH key pair resource."
  type        = string
  default     = ""
}
#=======================================================================================================================

# ----------------------------------------------- MAIN functionality ---------------------------------------------------
resource "tls_private_key" "graph_node_ssh_key" {
  count = var.create ? 1 : 0
  # (Required) The name of the algorithm to use for the key. Currently-supported values are "RSA" and "ECDSA".
  algorithm = "RSA"
}

# ---------------------------------
# Make sure EC2 SSH key is created
# ---------------------------------
resource "aws_key_pair" "graph_node_ssh_key" {
  count = var.create ? 1 : 0
  # (Optional) Creates a unique name beginning with the specified prefix. Conflicts with key_name.
  key_name_prefix = "graph-node-ec2-ssh-key-"
  # (Required) The public key material.
  public_key = length(var.graph_ssh_public_key) > 0 ? var.graph_ssh_public_key : join("", tls_private_key.graph_node_ssh_key.*.public_key_openssh)
}
#=======================================================================================================================

# -------------------------------------------------- EC2 Instances -----------------------------------------------------
resource "aws_instance" "graph_node" {
  count         = var.create ? 1 : 0
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  # root_block_device {
  #   volume_type = var.volume_type
  #   volume_size = var.volume_size
  # }
  iam_instance_profile = join("", aws_iam_instance_profile.graph_profile.*.name)
  user_data = base64encode(templatefile("${path.module}/templates/node-userdata.tpl.sh",
    {
      aws_account_id    = var.aws_account_id
      project_name      = var.project_name
      module_name       = var.module_name
      aws_region        = var.aws_region
      environment       = var.environment
      aws_ec2_iam_role  = join("", aws_iam_role.graph_role.*.name)
      ec2_instance_name = "${var.project_name}-${var.module_name}-node-${count.index}"
    }
  ))
  key_name               = join("", aws_key_pair.graph_node_ssh_key.*.key_name)
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [join("", aws_security_group.graph_node.*.id)]
  tags = merge(
    local.tags,
    {
      Name = "ultron-${var.module_name}-node-${count.index + 1}"
    }
  )
}
