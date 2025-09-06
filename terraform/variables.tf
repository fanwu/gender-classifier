# Variables for Gender Classification API Terraform Configuration

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "image_uri" {
  description = "ECR Image URI for the gender classifier container"
  type        = string
  # Will be set in terraform.tfvars
}

variable "model_bucket" {
  description = "S3 bucket name containing the trained model"
  type        = string
  # Will be set in terraform.tfvars
}

variable "model_prefix" {
  description = "S3 key prefix for the model files"
  type        = string
  default     = "models/gender-classification-final/"
}

variable "task_cpu" {
  description = "CPU units for the ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memory (MB) for the ECS task"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Number of instances of the task definition to run"
  type        = number
  default     = 1
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "gender-classifier"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}