provider "aws" {
    profile = "default"
    region = var.aws_region
}

# *******************************************
# Deployment S3 bucket & source code package
# *******************************************
resource "aws_s3_bucket" "deployment_bucket" {
  bucket = "${var.service_name}-deplyment-bucket-${var.stage}-${var.aws_region}"

  tags = {
    Environment = var.stage
  }
}

resource "aws_s3_bucket_ownership_controls" "deployment_bucket" {
  bucket = aws_s3_bucket.deployment_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "deployment_bucket" {
  bucket = aws_s3_bucket.deployment_bucket.id

  rule {
    id = "rule-1"
    expiration {
      days = 90
    }

    filter {}

    status = "Enabled"
  }
}

data "archive_file" "vmpt_users_code_package" {
  type = "zip"

  source_dir  = "./dist"
  output_path = "./.terraform/deploy/dist.zip"
}

resource "aws_s3_object" "vmpt_users_code_package" {
  bucket = aws_s3_bucket.deployment_bucket.id

  key    = "dist.zip"
  source = data.archive_file.vmpt_users_code_package.output_path

  etag = filemd5(data.archive_file.vmpt_users_code_package.output_path)
}

# ********************************
# IAM roles & policies
# ********************************
resource "aws_iam_role" "lambda_role" {
  name = "${var.service_name}-${var.stage}-${var.aws_region}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }]
    })
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "lambda_exec_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
          Action = [
              "logs:CreateLogStream",
              "logs:CreateLogGroup",
              "logs:TagResource"
          ]
          Resource = [
              "arn:aws:logs:${var.aws_region}:${var.aws_account}:log-group:/aws/lambda/${var.service_name}-${var.stage}*:*"
          ]
          Effect = "Allow"
      },
      {
          Action = [
              "logs:PutLogEvents"
          ]
          Resource = [
              "arn:aws:logs:${var.aws_region}:${var.aws_account}:log-group:/aws/lambda/${var.service_name}-${var.stage}*:*"
          ]
          "Effect": "Allow"
      },      
      {
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${var.aws_account}:table/${var.service_name}-${var.stage}-users"
        ]
      }]
  })
}

# ********************************
# DynamoDb tables
# ********************************

resource "aws_dynamodb_table" "users" {
  name           = "${var.service_name}-${var.stage}-users"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "id"
  range_key      = "email"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  tags = {
    Environment = "${var.stage}"
  }
}

# ********************************
# Lambda Functions
# ********************************

resource "aws_lambda_function" "list" {
  function_name = "${var.service_name}-${var.stage}-list"

  s3_bucket = aws_s3_bucket.deployment_bucket.id
  s3_key    = aws_s3_object.vmpt_users_code_package.key

  runtime = "nodejs20.x"
  handler = "src/handlers.listUsers"

  source_code_hash = data.archive_file.vmpt_users_code_package.output_base64sha256

  role = aws_iam_role.lambda_role.arn
  
  environment {
    variables = {
      USERS_TABLE = "${aws_dynamodb_table.users.id}"
      REGION = "${var.aws_region}"
    }
  }  
}

resource "aws_cloudwatch_log_group" "list" {
  name = "/aws/lambda/${aws_lambda_function.list.function_name}"

  retention_in_days = 30
}

resource "aws_lambda_function" "getUser" {
  function_name = "${var.service_name}-${var.stage}-getUser"

  s3_bucket = aws_s3_bucket.deployment_bucket.id
  s3_key    = aws_s3_object.vmpt_users_code_package.key

  runtime = "nodejs20.x"
  handler = "src/handlers.getUser"

  source_code_hash = data.archive_file.vmpt_users_code_package.output_base64sha256

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      USERS_TABLE = "${aws_dynamodb_table.users.id}"
      REGION = "${var.aws_region}"
    }
  }  
}

resource "aws_cloudwatch_log_group" "getUser" {
  name = "/aws/lambda/${aws_lambda_function.getUser.function_name}"

  retention_in_days = 30
}


# ********************************
# API Gateway
# ********************************
resource "aws_apigatewayv2_api" "apiGw" {
  name          = "${var.service_name}-${var.stage}-users"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "apiGw_stage" {
  api_id = aws_apigatewayv2_api.apiGw.id

  name        = "${var.stage}"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apiGw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

# Method "list"

resource "aws_apigatewayv2_integration" "list" {
  api_id = aws_apigatewayv2_api.apiGw.id

  integration_uri    = aws_lambda_function.list.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "list" {
  api_id = aws_apigatewayv2_api.apiGw.id

  route_key = "GET /users/list"
  target    = "integrations/${aws_apigatewayv2_integration.list.id}"
}

resource "aws_cloudwatch_log_group" "apiGw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.apiGw.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "apiGw_list" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.apiGw.execution_arn}/*/*"
}

# Method "getUser"

resource "aws_apigatewayv2_integration" "getUser" {
  api_id = aws_apigatewayv2_api.apiGw.id

  integration_uri    = aws_lambda_function.getUser.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "getUser" {
  api_id = aws_apigatewayv2_api.apiGw.id

  route_key = "GET /users/getUser"
  target    = "integrations/${aws_apigatewayv2_integration.getUser.id}"
}

resource "aws_lambda_permission" "apiGw_getUser" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.getUser.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.apiGw.execution_arn}/*/*"
}