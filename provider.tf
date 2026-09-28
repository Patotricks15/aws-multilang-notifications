provider "aws" {
  region = var.aws_region

  # Temporary override to run this scaffold against the local Floci AWS emulator (http://localhost:4566).
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    apigatewayv2 = "http://localhost:4566"
    lambda       = "http://localhost:4566"
    sfn          = "http://localhost:4566"
    comprehend   = "http://localhost:4566"
    pinpoint     = "http://localhost:4566"
    iam          = "http://localhost:4566"
    sts          = "http://localhost:4566"
    logs         = "http://localhost:4566"
  }
}
