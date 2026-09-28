import json
import os

import boto3

sfn = boto3.client("stepfunctions", region_name=os.environ.get("REGION", "us-east-1"))

STATE_MACHINE_ARN = os.environ["STATE_MACHINE_ARN"]


def lambda_handler(event, context):
    """Receives a notification request from the Support App and starts the workflow."""
    body = json.loads(event.get("body") or "{}")

    execution_input = {
        "message": body["message"],
        "recipient_phone_number": body["recipient_phone_number"],
        "recipient_user_id": body.get("recipient_user_id", "unknown"),
    }

    response = sfn.start_execution(
        stateMachineArn=STATE_MACHINE_ARN,
        input=json.dumps(execution_input),
    )

    return {
        "statusCode": 202,
        "body": json.dumps({"executionArn": response["executionArn"]}),
    }
