# ─── IAM role shared by all Lambda functions ─────────────────────────────────

resource "aws_iam_role" "lambda_exec" {
  name = "${local.name_prefix}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_start_execution" {
  name = "${local.name_prefix}-lambda-start-execution"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.notifications.arn
    }]
  })
}

resource "aws_iam_role_policy" "lambda_translate" {
  name = "${local.name_prefix}-lambda-translate"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "translate:TranslateText"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_comprehend" {
  name = "${local.name_prefix}-lambda-comprehend"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "comprehend:DetectSentiment"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_pinpoint" {
  name = "${local.name_prefix}-lambda-pinpoint"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "mobiletargeting:SendMessages"
      Resource = "${aws_pinpoint_app.notifications.arn}*"
    }]
  })
}

# ─── Lambda packages (one per function) ──────────────────────────────────────

resource "null_resource" "lambda_packages" {
  for_each = local.lambda_functions

  triggers = {
    handler_sha = filesha256("${path.module}/src/lambda/${each.key}/handler.py")
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/build_lambda_package.sh ${path.module} ${each.key}"
  }
}

data "archive_file" "lambda_zips" {
  for_each = local.lambda_functions

  type        = "zip"
  source_file = "${path.module}/src/lambda/${each.key}/handler.py"
  output_path = "${path.module}/.build/${each.key}.zip"

  depends_on = [null_resource.lambda_packages]
}

# ─── Lambda functions ─────────────────────────────────────────────────────────
# Split into two resources so the state machine (which references the workflow
# functions' ARNs) and "dispatch" (which needs the state machine's ARN back)
# don't form a dependency cycle.

resource "aws_lambda_function" "workflow" {
  for_each = local.workflow_functions

  function_name = "${local.name_prefix}-${each.key}"
  description   = each.value.description
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.lambda_zips[each.key].output_path
  source_code_hash = data.archive_file.lambda_zips[each.key].output_base64sha256

  environment {
    variables = {
      REGION               = var.aws_region
      SOURCE_LANGUAGE_CODE = var.source_language_code
      TARGET_LANGUAGE_CODE = var.target_language_code
      PINPOINT_APP_ID      = aws_pinpoint_app.notifications.application_id
    }
  }

  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-${each.key}"
    Function = each.key
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
  ]
}

resource "aws_lambda_function" "dispatch" {
  function_name = "${local.name_prefix}-dispatch"
  description   = local.lambda_functions["dispatch"].description
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.lambda_zips["dispatch"].output_path
  source_code_hash = data.archive_file.lambda_zips["dispatch"].output_base64sha256

  environment {
    variables = {
      REGION            = var.aws_region
      STATE_MACHINE_ARN = aws_sfn_state_machine.notifications.arn
    }
  }

  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-dispatch"
    Function = "dispatch"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
  ]
}

# ─── Amazon Pinpoint: app used to send SMS/Voice notifications ──────────────

resource "aws_pinpoint_app" "notifications" {
  name = "${local.name_prefix}-app"

  tags = local.common_tags
}

# ─── AWS Step Functions: translate + sentiment analysis in parallel, then send

resource "aws_iam_role" "state_machine" {
  name = "${local.name_prefix}-state-machine"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "state_machine_invoke_lambda" {
  name = "${local.name_prefix}-state-machine-invoke-lambda"
  role = aws_iam_role.state_machine.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = [for fn in aws_lambda_function.workflow : fn.arn]
    }]
  })
}

resource "aws_sfn_state_machine" "notifications" {
  name     = "${local.name_prefix}-workflow"
  role_arn = aws_iam_role.state_machine.arn

  definition = jsonencode({
    Comment = "Translate + analyze sentiment in parallel, then send the notification."
    StartAt = "Parallel"
    States = {
      Parallel = {
        Type       = "Parallel"
        ResultPath = "$.parallel_results"
        Branches = [
          {
            StartAt = "TranslateNotification"
            States = {
              TranslateNotification = {
                Type     = "Task"
                Resource = aws_lambda_function.workflow["translate_notification"].arn
                End      = true
              }
            }
          },
          {
            StartAt = "AnalyzeSentiment"
            States = {
              AnalyzeSentiment = {
                Type     = "Task"
                Resource = aws_lambda_function.workflow["analyze_sentiment"].arn
                End      = true
              }
            }
          }
        ]
        Next = "SendNotification"
      }
      SendNotification = {
        Type     = "Task"
        Resource = aws_lambda_function.workflow["send_notification"].arn
        End      = true
      }
    }
  })

  tags = local.common_tags
}

# ─── API Gateway HTTP API: entry point for the Support App ──────────────────

resource "aws_apigatewayv2_api" "notifications" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "dispatch" {
  api_id                 = aws_apigatewayv2_api.notifications.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.dispatch.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "notifications" {
  api_id    = aws_apigatewayv2_api.notifications.id
  route_key = "POST /notifications"
  target    = "integrations/${aws_apigatewayv2_integration.dispatch.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.notifications.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_gateway_invoke_dispatch" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatch.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.notifications.execution_arn}/*/*"
}
