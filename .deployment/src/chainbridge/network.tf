module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  create_vpc         = true
  manage_default_vpc = false

  name = "${var.project_name}-${var.environment}-${var.module_name}"
  cidr = "172.32.0.0/16"

  azs = [
    "${data.aws_region.current.name}a",
    "${data.aws_region.current.name}b",
    "${data.aws_region.current.name}c"
  ]
  public_subnets = [
    "172.32.0.0/22",
    "172.32.4.0/22",
    "172.32.8.0/22"
  ]
  private_subnets = [
    "172.32.252.0/22",
    "172.32.248.0/22",
    "172.32.244.0/22"
  ]

  create_database_subnet_group          = false
  create_database_subnet_route_table    = false
  create_elasticache_subnet_group       = false
  create_elasticache_subnet_route_table = false
  create_redshift_subnet_group          = false
  create_redshift_subnet_route_table    = false

  create_igw             = true
  create_egress_only_igw = false
  enable_nat_gateway     = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    subnet_type = "public"
  }

  private_subnet_tags = {
    subnet_type = "private"
  }

  tags = local.tags
}

resource "aws_security_group" "chainbridge" {
  count = var.enabled ? 1 : 0

  name_prefix = "${local.ec2_instance_name}-sg-"
  description = "Security Group for the [${local.ec2_instance_name}] EC2 instance."
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_all_egress" {
  count = var.enabled ? 1 : 0

  type              = "egress"
  description       = "Allow ALL Egress traffic."
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = join("", aws_security_group.chainbridge.*.id)
}

resource "aws_security_group_rule" "allow_ingress_within_vpc" {
  count = var.enabled ? 1 : 0

  type              = "ingress"
  description       = "Allow ALL ingress traffic from the VPC CIDR block."
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = join("", aws_security_group.chainbridge.*.id)
}
