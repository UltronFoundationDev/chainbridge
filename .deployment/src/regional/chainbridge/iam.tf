resource "aws_iam_policy" "chainbridge_iam_policy" {
  count       = var.enabled ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-chainbridge-policy-"
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
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:ListBucket",
            "s3:GetObject"
          ],
          "Resource" : [
            "arn:aws:s3:::${var.chainbridge_configs_s3_bucket}",
            "arn:aws:s3:::${var.chainbridge_configs_s3_bucket}/*"
          ]

        }
      ]
    }

  )
}

resource "aws_iam_role" "chainbridge_role" {
  count       = var.enabled ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-chainbridge-role-"
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
      Name = "${var.project_name}-${var.environment}-chainbridge-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "chainbridge_policy_role" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.chainbridge_role[count.index].name
  policy_arn = aws_iam_policy.chainbridge_iam_policy[count.index].arn
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.chainbridge_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "chainbridge_profile" {
  count = var.enabled ? 1 : 0
  # (Optional, Forces new resource) Creates a unique name beginning with the specified prefix. Conflicts with name.
  name_prefix = "${var.project_name}-${var.environment}-chainbridge-profile-"
  # (Optional) The role name to include in the profile.
  role = join("", aws_iam_role.chainbridge_role.*.name)
}
