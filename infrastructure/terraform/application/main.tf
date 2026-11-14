data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket  = var.network_state_bucket
    key     = var.network_state_key
    region  = var.network_state_region
    profile = var.aws_profile
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  iam_role_name = "${local.name}-eks-cluster"
  iam_role_path = "/application/"

  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = false

  addons = {
    coredns                = {}
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = { before_compute = true }
    vpc-cni                = { before_compute = true }
  }

  vpc_id                        = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids                    = data.terraform_remote_state.network.outputs.private_subnet_ids
  additional_security_group_ids = [data.terraform_remote_state.network.outputs.shared_services_security_group_id]

  eks_managed_node_groups = {
    general = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      iam_role_name = "${local.name}-eks-node-general"
      iam_role_path = "/application/"

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      vpc_security_group_ids = [data.terraform_remote_state.network.outputs.shared_services_security_group_id]

      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }
}

resource "aws_ecr_repository" "application" {
  name                 = var.project_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.ecr_force_delete

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "application" {
  repository = aws_ecr_repository.application.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep the 100 most recent immutable release images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 100
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ssm_parameter" "application_config" {
  for_each = local.ssm_parameters

  name  = "/${var.project_name}/${var.environment}/inference/${replace(each.key, "_", "-")}"
  type  = "String"
  value = each.value
  tier  = "Standard"
}

