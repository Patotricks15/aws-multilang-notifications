locals {
  name_prefix = var.project_name

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Demo      = "Multi-language notification system"
  }

  lambda_functions = {
    dispatch               = { description = "Receives notifications from the Support App and starts the state machine" }
    translate_notification = { description = "Translates the notification text with Amazon Translate" }
    analyze_sentiment      = { description = "Runs sentiment analysis on the notification text with Amazon Comprehend" }
    send_notification      = { description = "Merges translation + sentiment and sends SMS/Voice via Amazon Pinpoint" }
  }

  # Invoked directly by the Step Functions state machine (kept separate from
  # "dispatch" below to avoid a resource dependency cycle: the state machine
  # references these ARNs, and only "dispatch" needs the state machine's ARN back.
  workflow_functions = {
    for k, v in local.lambda_functions : k => v if k != "dispatch"
  }
}
