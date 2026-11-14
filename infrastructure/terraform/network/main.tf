data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = local.name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for index, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, index)]
  public_subnets  = [for index, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, index + 48)]
  database_subnets = [
    for index, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, index + 64)
  ]

  create_database_subnet_group = true
  database_subnet_group_name   = "${local.name}-database"

  # NAT Gateway creation is intentionally disabled for now to avoid its hourly
  # and public IPv4 charges. Re-enable these settings when private workloads
  # require outbound internet access.
  enable_nat_gateway = false
  # single_nat_gateway = var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    Tier                     = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    Tier                              = "private"
  }

  database_subnet_tags = {
    Tier = "database"
  }
}

# Temporary direct internet routing for the existing private-named application
# subnets. Their names and module classification stay unchanged, but a default
# route to the VPC internet gateway makes them public/routable. Workloads must
# still be launched with a public IPv4 address to use this route.
resource "aws_route" "private_subnet_internet_gateway" {
  count = length(local.azs)

  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.vpc.igw_id
}

resource "aws_security_group" "shared_services" {
  name        = "${local.name}-shared-services"
  description = "Shared security group for application infrastructure"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc_publisher && var.github_oidc_provider_arn == null ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_image_publisher_assume_role" {
  count = var.enable_github_oidc_publisher ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_image_publisher" {
  count = var.enable_github_oidc_publisher ? 1 : 0

  name               = "${local.name}-github-image-publisher"
  assume_role_policy = data.aws_iam_policy_document.github_image_publisher_assume_role[0].json
}

data "aws_iam_policy_document" "github_image_publisher" {
  count = var.enable_github_oidc_publisher ? 1 : 0

  statement {
    sid       = "GetEcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushApplicationImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [local.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "github_image_publisher" {
  count = var.enable_github_oidc_publisher ? 1 : 0

  name   = "ecr-push-${var.project_name}"
  role   = aws_iam_role.github_image_publisher[0].id
  policy = data.aws_iam_policy_document.github_image_publisher[0].json
}

