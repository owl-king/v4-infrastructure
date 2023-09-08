# Module for ECS task and task execution roles
module "iam_ecs_task_roles" {
  source                        = "../modules/iam/ecs_task_roles"
  name                          = var.indexers[var.region].name
  environment                   = var.environment
  additional_task_role_policies = local.indexer_ecs_task_role_policies
}

# -----------------------------------------------------------------------------
# Lambda Services task roles: used by the lambda task itself.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_services_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM role to be used by lambda_services
resource "aws_iam_role" "lambda_services" {
  for_each = local.lambda_services

  name = "${var.environment}-${var.indexers[var.region].name}-${each.key}"

  assume_role_policy = data.aws_iam_policy_document.lambda_services_role_policy.json
}

# Attach the lambda service's deploy policy to lambda service's IAM role
resource "aws_iam_role_policy_attachment" "lambda_services_deploy_policy_attachment" {
  for_each = local.lambda_services

  role       = aws_iam_role.lambda_services[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Attach the lambda service's policy for upgrading indexer
resource "aws_iam_role_policy_attachment" "lambda_services_upgrade_indexer_attachment" {
  for_each = { for key, value in local.lambda_services : key => value if value.requires_upgrade_indexer_iam_policies }

  role       = aws_iam_role.lambda_services[each.key].name
  policy_arn = aws_iam_policy.lambda_upgrade_indexer_policy.arn
}

resource "aws_iam_policy" "lambda_upgrade_indexer_policy" {
  name        = "UpdateIndexerPolicy"
  description = "Policy that grants permission necessary to upgrade indexer"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:InvokeFunction",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "iam:PassRole",
          "ecr:DescribeImages"
        ],
        Effect = "Allow",
        // TODO(IND-262): Restrict these permissions
        Resource = "*"
      }
    ]
  })
}