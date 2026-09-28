output "notifications_api_endpoint" {
  description = "Invoke URL of the HTTP API the Support App posts notifications to."
  value       = aws_apigatewayv2_api.notifications.api_endpoint
}

output "state_machine_arn" {
  description = "ARN of the Step Functions workflow orchestrating translation + sentiment analysis + sending."
  value       = aws_sfn_state_machine.notifications.arn
}

output "pinpoint_application_id" {
  description = "Amazon Pinpoint application ID used to send SMS/Voice notifications."
  value       = aws_pinpoint_app.notifications.application_id
}

output "lambda_function_names" {
  description = "Names of the Lambda functions used across the notification workflow."
  value = merge(
    { for k, fn in aws_lambda_function.workflow : k => fn.function_name },
    { dispatch = aws_lambda_function.dispatch.function_name },
  )
}
