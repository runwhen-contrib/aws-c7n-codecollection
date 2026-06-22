# AWS Cloud Custodian S3 Health

This codebundle starts out as an example of integrating the custodian (c7n) cli into RunWhen. 

## SLI
A simple SLI that counts S3 buckets that are public. Uses the custodian cli. 

This bundle now evaluates:
- S3 buckets with public access enabled
- S3 buckets missing default encryption

## TaskSet
Similar to the SLI, but produces a report on the specific resources and raises issues for each bucket that is public or unencrypted. 


## Required Configuration

```
export AWS_ACCESS_KEY_ID=[]
export AWS_SECRET_ACCESS_KEY=[]
export AWS_DEFAULT_REGION=[]
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
```


## Testing 
See the .test directory for infrastructure test code. 