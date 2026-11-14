variable "aws_region" {
  description = "AWS selected Region for all Regional resources."
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile used by the application Terraform stack."
  type        = string
  default     = "application-deployer"
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

variable "network_state_bucket" {
  description = "S3 bucket containing the network Terraform state."
  type        = string
}

variable "network_state_key" {
  description = "S3 key containing the network Terraform state."
  type        = string
  default     = "llm-inference-platform/dev/network/terraform.tfstate"
}

variable "network_state_region" {
  description = "Region containing the network Terraform state bucket."
  type        = string
  default     = "ap-southeast-2"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version. Verify support before applying."
  type        = string
  default     = "1.33"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to access the public EKS API endpoint. Do not use 0.0.0.0/0."
  type        = list(string)

  validation {
    condition = alltrue([
      for cidr in var.cluster_endpoint_public_access_cidrs : cidr != "0.0.0.0/0"
    ])
    error_message = "Restrict the EKS public endpoint to trusted CIDRs; 0.0.0.0/0 is not allowed."
  }
}

variable "node_instance_types" {
  description = "Allowed instance types for the general-purpose managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum managed node group size."
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired managed node group size."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum managed node group size."
  type        = number
  default     = 4
}

variable "ecr_force_delete" {
  description = "Permit Terraform to delete a non-empty ECR repository. Keep false for safety."
  type        = bool
  default     = false
}

variable "inference_base_url" {
  description = "Inference API URL stored in SSM Parameter Store."
  type        = string
  default     = "http://ollama.ollama.svc.cluster.local:11434/v1"
}

variable "inference_model" {
  description = "Inference model name stored in SSM Parameter Store."
  type        = string
  default     = "qwen3:0.6b"
}

variable "tags" {
  description = "Additional tags applied to AWS resources."
  type        = map(string)
  default     = {}
}

