output "stage" {
  description = "Name of the deployment stage"
  value = var.stage
}

output "region" {
  description = "Name of the deployment AWS region"
  value = var.aws_region
}

output "deployment_bucket" {
  description = "Name of the deployment S3 bucket"
  value = aws_s3_bucket.deployment_bucket.id
}

output "users_api_invoke_url" {
  description = "Name of the deployment S3 bucket"
  value = aws_apigatewayv2_stage.apiGw_stage.invoke_url
}
