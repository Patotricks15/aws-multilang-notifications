import os

import boto3

translate = boto3.client("translate", region_name=os.environ.get("REGION", "us-east-1"))

SOURCE_LANGUAGE_CODE = os.environ["SOURCE_LANGUAGE_CODE"]
TARGET_LANGUAGE_CODE = os.environ["TARGET_LANGUAGE_CODE"]


def lambda_handler(event, context):
    """Translates the notification message into the recipient's language."""
    result = translate.translate_text(
        Text=event["message"],
        SourceLanguageCode=SOURCE_LANGUAGE_CODE,
        TargetLanguageCode=TARGET_LANGUAGE_CODE,
    )

    return {"translated_message": result["TranslatedText"]}
