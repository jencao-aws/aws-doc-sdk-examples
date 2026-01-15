from runner import writeme
from enum import Enum
from pathlib import Path



if __name__ == "__main__":

    # target_services = ["acm", 
    #                    "api-gateway", 
    #                    "auto-scaling", 
    #                    "aurora", 
    #                    "cloudfront", 
    #                    "cloudwatch-logs", 
    #                    "cloudwatch", 
    #                    "cognito-identity-provider", 
    #                    "comprehend", 
    #                    "config-service", 
    #                    "controltower", 
    #                    "ec2",
    #                    "ecr", 
    #                    "emr", 
    #                    "firehose", 
    #                    "glue", 
    #                    "healthlake", 
    #                    "iam",
    #                    "iotsitewise", 
    #                    "keyspaces", 
    #                    "kms", 
    #                    "medical-imaging", 
    #                    "organizations", 
    #                    "pinpoint-sms-voice", 
    #                    "pinpoint", 
    #                    "polly", 
    #                    "rds", 
    #                    "redshift", 
    #                    "rekognition", 
    #                    "route53-recovery-cluster", 
    #                    "s3",
    #                    "scheduler", 
    #                    "secrets-manager", 
    #                    "ses", 
    #                    "sesv2", 
    #                    "sfn", 
    #                    "sns", 
    #                    "sqs", 
    #                    "ssm", 
    #                    "transcribe"]

    target_services = ["bedrock-runtime"] #, "bedrock-agent-runtime", "comprehend", "cloudwatch", "dynamodb", "ec2", "kinesis", "lambda", "s3", "sagemaker", "sns", "sqs", "textract", "translate"]

    for service in target_services:
        writeme(languages=["SAP ABAP:1"], services=[service])

    print("Done!")
