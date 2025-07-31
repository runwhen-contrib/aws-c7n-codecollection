### How to test this codebundle? 

#### IAM User Configuration

We create two distinct AWS IAM users with carefully scoped access:

**CloudCustodian IAM User**

Purpose: Service Level Indicator (SLI) monitoring and runbook automation and configured with least privilege access principles

with the following policy:

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "VisualEditor0",
			"Effect": "Allow",
			"Action": [
				"tag:GetResources",
				"ec2:DescribeRegions",
				"ec2:DescribeSecurityGroups",
				"servicequotas:ListServices",
				"servicequotas:ListAWSDefaultServiceQuotas",
				"servicequotas:ListServiceQuotas",
				"cloudwatch:GetMetricStatistics"
			],
			"Resource": "*"
		}
	]
}
```

**Infrastructure Deployment User**

Purpose: Cloud infrastructure provisioning and management using Terraform

#### Credential Setup

Navigate to the `.test/terraform` directory and configure two secret files for authentication:

`cb.secret` - CloudCustodian and RunWhen Credentials

Create this file with the following environment variables:

	```sh
	export RW_PAT=""
	export RW_WORKSPACE=""
	export RW_API_URL="papi.beta.runwhen.com"

	export AWS_DEFAULT_REGION="us-west-2"
	export AWS_ACCESS_KEY_ID=""
	export AWS_SECRET_ACCESS_KEY=""
	export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
	```


`tf.secret` - Terraform Deployment Credentials

Create this file with the following environment variables:

	```sh
	export AWS_DEFAULT_REGION=""
	export AWS_ACCESS_KEY_ID=""
	export AWS_SECRET_ACCESS_KEY=""
	export AWS_SESSION_TOKEN="" # Optional: Include if using temporary credentials
	```

####  Testing Workflow

1. Build test infra:
	**Note** WIP

2. Generate RunWhen Configurations
	```sh
		tasks
	```

3. Upload generated SLx to RunWhen Platform

	```sh
		task upload-slxs
	```

4. At last, after testing, clean up the test infrastructure.

```sh
	task clean
```

