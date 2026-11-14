variable "aws_region" {
  description = "AWS selected Region for all Regional resources."
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "llm-inference-platform"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway to reduce dev cost. Set false for one NAT gateway per AZ."
  type        = bool
  default     = true
}

variable "github_owner" {
  description = "GitHub organization or user that owns the application repository."
  type        = string
  default     = "Abhishekvarun2010"
}

variable "github_repository" {
  description = "GitHub repository allowed to publish application images."
  type        = string
  default     = "llm-inference-platform"
}

variable "github_branch" {
  description = "Git branch allowed to assume the image-publisher role."
  type        = string
  default     = "main"
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN. Leave null to create it."
  type        = string
  default     = null
  nullable    = true
}

variable "application_deployer_trusted_principal_arns" {
  description = "IAM principals allowed to assume the application deployment role. Defaults to the new-experience AccountFullAccessRole."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.application_deployer_trusted_principal_arns : arn != "*"])
    error_message = "Trusted principals must be explicit IAM ARNs; wildcard trust is not allowed."
  }
}

variable "terraform_state_bucket_name" {
  description = "S3 bucket containing network and application Terraform state."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to AWS resources."
  type        = map(string)
  default     = {}
}

