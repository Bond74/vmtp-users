variable "aws_account" {
  description = "AWS Account ID"
  type        = string
  default     = "779846810965"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Name of the service"
  type        = string
  default     = "vmtp-users"
}

variable "stage" {
  description = "Deployment stage"
  type        = string
  default     = "dev"
}
