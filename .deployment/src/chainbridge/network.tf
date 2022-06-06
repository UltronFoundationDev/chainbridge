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

  database_subnets = [
    "172.64.0.0/22",
    "172.64.4.0/22",
    "172.64.8.0/22"
  ]

  create_database_subnet_group          = true
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

resource "aws_security_group" "graph_node" {
  count = var.create ? 1 : 0

  name_prefix = "${local.ec2_instance_name}-sg-"
  description = "Security Group for the [${local.ec2_instance_name}] EC2 instance."
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_all_egress" {
  count = var.create ? 1 : 0

  type              = "egress"
  description       = "Allow ALL Egress traffic."
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = join("", aws_security_group.graph_node.*.id)
}

# resource "aws_security_group_rule" "allow_ingress_ssh" {
#   count = var.create ? 1 : 0

#   type              = "ingress"
#   description       = "Allow ingress SSH."
#   from_port         = 22
#   to_port           = 22
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = join("", aws_security_group.graph_node.*.id)
# }

# resource "aws_security_group_rule" "allow_ingress_api" {
#   count = var.create ? 1 : 0

#   type              = "ingress"
#   description       = "Allow ingress traffic to the API via default port."
#   from_port         = 16761
#   to_port           = 16761
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = join("", aws_security_group.graph_node.*.id)
# }

resource "aws_security_group_rule" "allow_ingress_http" {
  count = var.create ? 1 : 0

  type              = "ingress"
  description       = "Allow ingress traffic via HTTP."
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = join("", aws_security_group.graph_node.*.id)
}

resource "aws_security_group_rule" "allow_ingress_https" {
  count = var.create ? 1 : 0

  type              = "ingress"
  description       = "Allow ingress traffic via HTTPS."
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = join("", aws_security_group.graph_node.*.id)
}

resource "aws_security_group_rule" "allow_ingress_within_vpc" {
  count = var.create ? 1 : 0

  type              = "ingress"
  description       = "Allow ALL ingress traffic from the VPC CIDR block."
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = join("", aws_security_group.graph_node.*.id)
}
