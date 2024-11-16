## Test

### Requirements

#### Building Infrastructure
For the infrastructure tasks, the Taskfile sources `/terraform/.tf.secret` with the following contents: 

```
export AWS_ACCESS_KEY_ID=[]
export AWS_SECRET_ACCESS_KEY=[]
export AWS_DEFAULT_REGION=[]
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
```

You also need to run those commands in your own session, along with the following command to allow an S3 bucket to be created with public access: 
```
aws s3control put-public-access-block \
  --account-id $AWS_ACCOUNT_ID \
  --public-access-block-configuration BlockPublicAcls=false,BlockPublicPolicy=false

```

Once thats complete: 
```
task build-infra
```


