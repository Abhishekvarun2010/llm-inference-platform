locals {
  name = "${var.project_name}-${var.environment}"

  ssm_parameters = {
    inference_base_url = var.inference_base_url
    inference_model    = var.inference_model
  }

  tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Stack       = "application"
    },
    var.tags
  )
}

