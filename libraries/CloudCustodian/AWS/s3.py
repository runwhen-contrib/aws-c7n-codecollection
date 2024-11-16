from c7n.resources.aws import s3
from c7n.policy import Policy
from c7n.config import Config

# Explicitly load only the `s3` resource
s3.register_s3()

def count_s3_buckets(aws_region, account_id):
    """
    Count the number of S3 buckets in the specified AWS account.

    Args:
        aws_region (str): The AWS region to use.
        account_id (str): The AWS account ID.

    Returns:
        int: The number of S3 buckets in the account.
    """
    # Set up Cloud Custodian configuration
    config = Config.empty()
    config.region = aws_region
    config.account_id = account_id

    # Define a simple policy to target S3 buckets
    policy_data = {"name": "count-s3-buckets", "resource": "aws.s3"}

    # Initialize and run the policy
    policy = Policy(policy_data, options=config)
    resources = policy.run()

    # Return the count of S3 buckets
    return len(resources)
