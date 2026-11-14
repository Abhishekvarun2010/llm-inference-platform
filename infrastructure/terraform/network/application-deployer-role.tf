data "aws_iam_policy_document" "application_deployer_assume_role" {
  statement {
    sid     = "TrustedProjectPrincipals"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.application_deployer_trusted_principal_arns
    }

    dynamic "condition" {
      for_each = length(var.application_deployer_trusted_principal_arns) == 0 ? [1] : []

      content {
        test     = "ArnLike"
        variable = "aws:PrincipalArn"
        values   = [local.managed_project_role_arn]
      }
    }
  }
}

resource "aws_iam_role" "application_deployer" {
  name                 = "${local.name}-application-deployer"
  path                 = "/deployment/"
  description          = "Deploys and updates project application infrastructure"
  assume_role_policy   = data.aws_iam_policy_document.application_deployer_assume_role.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "application_deployer_services" {
  statement {
    sid    = "ReadApplicationServiceInventory"
    effect = "Allow"
    actions = [
      "ecr:Describe*",
      "ecr:GetAuthorizationToken",
      "ecr:List*",
      "ec2:Describe*",
      "eks:Describe*",
      "eks:List*",
      "iam:Get*",
      "iam:List*",
      "logs:Describe*",
      "rds:Describe*",
      "ssm:DescribeParameters",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CreateTaggedEksCluster"
    effect = "Allow"
    actions = [
      "eks:CreateCluster"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ManageNamedEksResources"
    effect = "Allow"
    actions = [
      "eks:AssociateAccessPolicy",
      "eks:AssociateIdentityProviderConfig",
      "eks:CreateAccessEntry",
      "eks:CreateAddon",
      "eks:CreateNodegroup",
      "eks:CreatePodIdentityAssociation",
      "eks:DeleteAccessEntry",
      "eks:DeleteAddon",
      "eks:DeleteCluster",
      "eks:DeleteNodegroup",
      "eks:DeletePodIdentityAssociation",
      "eks:DisassociateAccessPolicy",
      "eks:DisassociateIdentityProviderConfig",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:UpdateAccessEntry",
      "eks:UpdateAddon",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
      "eks:UpdatePodIdentityAssociation"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.name}*",
      "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:nodegroup/${local.name}*/*/*",
      "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:addon/${local.name}*/*/*",
      "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:access-entry/${local.name}*/*/*/*/*",
      "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:podidentityassociation/${local.name}*/*",
      "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identityproviderconfig/${local.name}*/*/*/*"
    ]
  }

  statement {
    sid    = "ManageApplicationEcrRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchDeleteImage",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:CreateRepository",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetLifecyclePolicy",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:PutLifecyclePolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:UploadLayerPart"
    ]
    resources = [local.ecr_repository_arn]
  }

  statement {
    sid    = "ManageApplicationParameters"
    effect = "Allow"
    actions = [
      "ssm:AddTagsToResource",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:LabelParameterVersion",
      "ssm:PutParameter",
      "ssm:RemoveTagsFromResource",
      "ssm:UnlabelParameterVersion"
    ]
    resources = [local.application_parameter_arn]
  }

  statement {
    sid    = "CreateTaggedRdsResources"
    effect = "Allow"
    actions = [
      "rds:AddTagsToResource",
      "rds:CreateDBCluster",
      "rds:CreateDBClusterParameterGroup",
      "rds:CreateDBInstance",
      "rds:CreateDBParameterGroup",
      "rds:CreateDBSubnetGroup",
      "rds:CreateOptionGroup"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ModifyNamedRdsResources"
    effect = "Allow"
    actions = [
      "rds:AddTagsToResource",
      "rds:ApplyPendingMaintenanceAction",
      "rds:DeleteDBCluster",
      "rds:DeleteDBClusterParameterGroup",
      "rds:DeleteDBInstance",
      "rds:DeleteDBParameterGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:DeleteOptionGroup",
      "rds:ModifyDBCluster",
      "rds:ModifyDBClusterParameterGroup",
      "rds:ModifyDBInstance",
      "rds:ModifyDBParameterGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:ModifyOptionGroup",
      "rds:RebootDBCluster",
      "rds:RebootDBInstance",
      "rds:RemoveTagsFromResource",
      "rds:StartDBCluster",
      "rds:StartDBInstance",
      "rds:StopDBCluster",
      "rds:StopDBInstance"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:${local.name}-*",
      "arn:${data.aws_partition.current.partition}:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster:${local.name}-*",
      "arn:${data.aws_partition.current.partition}:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:pg:${local.name}-*",
      "arn:${data.aws_partition.current.partition}:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster-pg:${local.name}-*",
      "arn:${data.aws_partition.current.partition}:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:og:${local.name}-*",
      "arn:${data.aws_partition.current.partition}:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subgrp:${local.name}-*"
    ]
  }
}

resource "aws_iam_policy" "application_deployer_services" {
  name        = "${local.name}-application-services"
  path        = "/deployment/"
  description = "Scoped EKS, ECR, SSM and RDS deployment permissions"
  policy      = data.aws_iam_policy_document.application_deployer_services.json
}

data "aws_iam_policy_document" "application_deployer_supporting" {
  statement {
    sid    = "ManageApplicationIamRoles"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription"
    ]
    resources = [local.application_role_arn_pattern]
  }

  statement {
    sid    = "ManageApplicationIamPolicies"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]
    resources = [local.application_policy_arn_pattern]
  }

  statement {
    sid       = "PassOnlyApplicationRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [local.application_role_arn_pattern]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "ec2.amazonaws.com",
        "eks.amazonaws.com",
        "rds.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "CreateRequiredServiceLinkedRoles"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "rds.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "CreateTaggedEc2SupportResources"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ModifyTaggedEc2SupportResources"
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteTags",
      "ec2:ModifyLaunchTemplate",
      "ec2:ModifySecurityGroupRules",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "TagEksOwnedSecurityGroups"
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/aws:eks:cluster-name"
      values   = [local.name]
    }
  }

  statement {
    sid    = "ManageEksClusterLogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DeleteLogGroup",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${local.name}*/cluster:*"
    ]
  }
}

resource "aws_iam_policy" "application_deployer_supporting" {
  name        = "${local.name}-application-supporting"
  path        = "/deployment/"
  description = "Supporting IAM, EC2 and logging permissions for application infrastructure"
  policy      = data.aws_iam_policy_document.application_deployer_supporting.json
}

data "aws_iam_policy_document" "application_deployer_state" {
  statement {
    sid       = "ListTerraformStatePrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.terraform_state_bucket_name}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        local.application_state_key,
        "${local.application_state_key}.tflock",
        local.network_state_key
      ]
    }
  }

  statement {
    sid    = "ReadNetworkAndApplicationState"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.terraform_state_bucket_name}/${local.network_state_key}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.terraform_state_bucket_name}/${local.application_state_key}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.terraform_state_bucket_name}/${local.application_state_key}.tflock"
    ]
  }

  statement {
    sid    = "WriteApplicationStateAndLock"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.terraform_state_bucket_name}/${local.application_state_key}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.terraform_state_bucket_name}/${local.application_state_key}.tflock"
    ]
  }
}

resource "aws_iam_policy" "application_deployer_state" {
  name        = "${local.name}-application-state"
  path        = "/deployment/"
  description = "Read network state and manage application Terraform state"
  policy      = data.aws_iam_policy_document.application_deployer_state.json
}

resource "aws_iam_role_policy_attachment" "application_deployer" {
  for_each = {
    services   = aws_iam_policy.application_deployer_services.arn
    state      = aws_iam_policy.application_deployer_state.arn
    supporting = aws_iam_policy.application_deployer_supporting.arn
  }

  role       = aws_iam_role.application_deployer.name
  policy_arn = each.value
}

