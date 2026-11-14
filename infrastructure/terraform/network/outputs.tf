output "aws_region" {
  description = "Selected AWS Region."
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID consumed by the application stack."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs consumed by EKS."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs available for public load balancers."
  value       = module.vpc.public_subnets
}

output "database_subnet_ids" {
  description = "Isolated database subnet IDs available to RDS."
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "RDS DB subnet group spanning the selected Availability Zones."
  value       = module.vpc.database_subnet_group_name
}

output "shared_services_security_group_id" {
  description = "Shared security group available to application infrastructure."
  value       = aws_security_group.shared_services.id
}

output "github_actions_image_role_arn" {
  description = "Set this as the GitHub Actions secret AWS_GITHUB_ACTIONS_ROLE_ARN."
  value       = aws_iam_role.github_image_publisher.arn
}

output "application_deployer_role_arn" {
  description = "Role assumed by operators to deploy and update application infrastructure."
  value       = aws_iam_role.application_deployer.arn
}

output "assume_application_deployer_command" {
  description = "AWS CLI command that requests a one-hour application deployment session."
  value       = "aws sts assume-role --role-arn ${aws_iam_role.application_deployer.arn} --role-session-name application-deployment --duration-seconds 3600 --profile default"
}

