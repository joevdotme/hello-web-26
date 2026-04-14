terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "lambda_zip_path" {
  type    = string
  default = "../dist/lambda.zip"
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_exec" {
  name = "hello-web-26-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policies/service-role/AWSLambdaBasicExecutionRole"
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_lambda_function" "app" {
  function_name    = "hello-web-26"
  role             = aws_iam_role.lambda_exec.arn
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  handler          = "lambda_handler.handler"
  runtime          = "python3.12"

  environment {
    variables = {
      FLASK_ENV = "production"
    }
  }
}

# ── API Gateway (HTTP API) ────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "http" {
  name          = "hello-web-26"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.app.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "catch_all" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "function_name" {
  value = aws_lambda_function.app.function_name
}
