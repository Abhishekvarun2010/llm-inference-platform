output "aws_region" {
  description = "Selected AWS Region."
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "ecr_repository_url" {
  description = "Application ECR repository URL."
  value       = aws_ecr_repository.application.repository_url
}

output "ssm_parameter_names" {
  description = "Application configuration keys stored in SSM Parameter Store."
  value       = { for key, parameter in aws_ssm_parameter.application_config : key => parameter.name }
}

output "configure_kubectl_command" {
  description = "Command that configures kubectl for the EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --profile default"
}

