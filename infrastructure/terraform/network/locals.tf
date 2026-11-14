locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  ecr_repository_arn = "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}"

  github_oidc_provider_arn = var.enable_github_oidc_publisher ? coalesce(
    var.github_oidc_provider_arn,
    try(aws_iam_openid_connect_provider.github[0].arn, null)
  ) : null

  application_deployer_trusted_principal_arns = length(var.application_deployer_trusted_principal_arns) > 0 ? var.application_deployer_trusted_principal_arns : [
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  ]

  managed_project_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/AccountFullAccessRole"

  application_role_arn_pattern   = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/application/${local.name}-*"
  application_policy_arn_pattern = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/application/${local.name}-*"
  application_parameter_arn      = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
  application_state_key          = "${var.project_name}/${var.environment}/application/terraform.tfstate"
  network_state_key              = "${var.project_name}/${var.environment}/network/terraform.tfstate"

  tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Stack       = "network"
    },
    var.tags
  )
}

