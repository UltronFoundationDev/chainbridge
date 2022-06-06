resource "aws_iam_policy" "graph_iam_policy" {
  count       = var.create ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-graph-policy-"
  path        = "/"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ],
          "Resource" : [
            "arn:aws:logs:*:*:*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : "ecr:GetAuthorizationToken",
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ecr:Get*",
            "ecr:Describe*",
            "ecr:List*",
            "ecr:BatchGet*"
          ],
          "Resource" : [
            "arn:aws:ecr:us-east-1:${var.aws_account_id}:repository/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ssm:*"
          ],
          "Resource" : [
            "*"
          ]
        }
      ]
    }

  )
}

resource "aws_iam_role" "graph_role" {
  count       = var.create ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-graph-role-"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-${var.environment}-graph-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "graph_policy_role" {
  count      = var.create ? 1 : 0
  role       = aws_iam_role.graph_role[count.index].name
  policy_arn = aws_iam_policy.graph_iam_policy[count.index].arn
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = var.create ? 1 : 0
  role       = aws_iam_role.graph_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "graph_profile" {
  count = var.create ? 1 : 0
  # (Optional, Forces new resource) Creates a unique name beginning with the specified prefix. Conflicts with name.
  name_prefix = "${var.project_name}-${var.environment}-graph-profile-"
  # (Optional) The role name to include in the profile.
  role = join("", aws_iam_role.graph_role.*.name)
}
