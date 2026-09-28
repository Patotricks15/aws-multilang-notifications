import os

import boto3

comprehend = boto3.client("comprehend", region_name=os.environ.get("REGION", "us-east-1"))

SOURCE_LANGUAGE_CODE = os.environ["SOURCE_LANGUAGE_CODE"]


def lambda_handler(event, context):
    """Runs sentiment analysis on the original notification message."""
    result = comprehend.detect_sentiment(
        Text=event["message"],
        LanguageCode=SOURCE_LANGUAGE_CODE,
    )

    return {
        "sentiment": result["Sentiment"],
        "sentiment_score": result["SentimentScore"],
    }
