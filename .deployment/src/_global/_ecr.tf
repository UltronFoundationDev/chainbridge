locals {
  tags = {
    Environment = var.environment,
    Terraform   = "true",
  }
}

resource "aws_ecr_repository" "graph_node" {
  name                 = "${var.module_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
  tags = merge(
    local.tags,
    {
      Name = "${var.module_name}-${var.environment}"
    }
  )
}
