import os

import boto3

pinpoint = boto3.client("pinpoint", region_name=os.environ.get("REGION", "us-east-1"))

PINPOINT_APP_ID = os.environ["PINPOINT_APP_ID"]

# Sentiment values that should escalate delivery from SMS to a Voice call.
URGENT_SENTIMENTS = {"NEGATIVE"}


def lambda_handler(event, context):
    """Merges the translated text + sentiment, then sends the notification via Pinpoint."""
    translate_result, sentiment_result = event["parallel_results"]
    translated_message = translate_result["translated_message"]
    sentiment = sentiment_result["sentiment"]

    recipient_phone_number = event["recipient_phone_number"]
    channel_type = "VOICE" if sentiment in URGENT_SENTIMENTS else "SMS"

    pinpoint.send_messages(
        ApplicationId=PINPOINT_APP_ID,
        MessageRequest={
            "Addresses": {
                recipient_phone_number: {"ChannelType": channel_type},
            },
            "MessageConfiguration": {
                channel_type.title() + "Message": {"Body": translated_message},
            },
        },
    )

    return {
        "translated_message": translated_message,
        "sentiment": sentiment,
        "channel_type": channel_type,
    }
