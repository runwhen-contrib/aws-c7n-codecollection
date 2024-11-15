from c7n.policy import Policy
from c7n.config import Config

class S3:
    ROBOT_LIBRARY_SCOPE = "GLOBAL"

    def __init__(self):
        """
        Initializes the S3 class. Region and account ID can be passed as arguments
        to each method for flexibility with Robot Framework.
        """
        self.config = None

    def _create_config(self, region, account_id):
        """
        Helper method to create a Cloud Custodian config for the given region and account ID.
        """
        config = Config.empty()
        config.region = region
        config.account_id = account_id
        self.config = config

    def count_buckets_with_public_access(self, AWS_REGION, AWS_ACCOUNT_ID):
        """
        Counts the number of S3 buckets with public access.

        Args:
            AWS_REGION (str): AWS region to target.
            AWS_ACCOUNT_ID (str): AWS account ID.

        Returns:
            int: Count of S3 buckets with public access.
        """
        self._create_config(AWS_REGION, AWS_ACCOUNT_ID)
        
        policy_data = {
            "name": "s3-count-public-access",
            "resource": "s3",
            "filters": [
                {
                    "type": "public",
                    "value": "true"
                }
            ]
        }
        policy = Policy(policy_data, config=self.config)
        resources = policy.run()
        
        return len(resources)

    def list_buckets_with_public_access(self, AWS_REGION, AWS_ACCOUNT_ID):
        """
        Lists the names of S3 buckets with public access.

        Args:
            AWS_REGION (str): AWS region to target.
            AWS_ACCOUNT_ID (str): AWS account ID.

        Returns:
            list: List of S3 bucket names with public access.
        """
        self._create_config(AWS_REGION, AWS_ACCOUNT_ID)
        
        policy_data = {
            "name": "s3-list-public-access",
            "resource": "s3",
            "filters": [
                {
                    "type": "public",
                    "value": "true"
                }
            ]
        }
        policy = Policy(policy_data, config=self.config)
        resources = policy.run()
        
        return [resource['Name'] for resource in resources]

    def remove_public_access(self, AWS_REGION, AWS_ACCOUNT_ID):
        """
        Removes public access from S3 buckets with public access permissions.

        Args:
            AWS_REGION (str): AWS region to target.
            AWS_ACCOUNT_ID (str): AWS account ID.

        Returns:
            list: List of S3 bucket names that had public access removed.
        """
        self._create_config(AWS_REGION, AWS_ACCOUNT_ID)
        
        policy_data = {
            "name": "s3-remove-public-access",
            "resource": "s3",
            "filters": [
                {
                    "type": "public",
                    "value": "true"
                }
            ],
            "actions": [
                {
                    "type": "delete-global-grants",
                    "grants": ["READ", "WRITE", "READ_ACP", "WRITE_ACP", "FULL_CONTROL"]
                }
            ]
        }
        policy = Policy(policy_data, config=self.config)
        resources = policy.run()
        
        return [resource['Name'] for resource in resources]
