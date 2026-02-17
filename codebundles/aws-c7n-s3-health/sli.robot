*** Settings ***
Metadata          Author   stewartshea
Metadata          Display Name    AWS S3 Health
Metadata          Supports    AWS    S3    CloudCustodian
Documentation     Counts the number of S3 buckets in an Account that are insecure or unhealthy. 
Force Tags    S3    Bucket    AWS    Storage    Secure

Library    RW.Core
Library    RW.CLI

Suite Setup    Suite Initialization

*** Tasks ***
Count S3 Buckets With Public Access in AWS Account `${AWS_ACCOUNT_NAME}`
    [Documentation]  Fetch total number of S3 buckets with public access enabled.    
    [Tags]    s3    storage    aws    security    data:config
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-s3-health ${CURDIR}/s3-public-buckets.yaml
    ...    env=${env}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-s3-health/s3-public-buckets/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    RW.Core.Push Metric    ${count.stdout}




** Keywords ***
Suite Initialization
    ${AWS_REGION}=    RW.Core.Import User Variable    AWS_REGION
    ...    type=string
    ...    description=AWS Region
    ...    pattern=\w*
    ${AWS_ACCOUNT_ID}=    RW.Core.Import User Variable   AWS_ACCOUNT_ID
    ...    type=string
    ...    description=AWS Account ID
    ...    pattern=\w*
    ${aws_credentials}=    RW.Core.Import Secret    aws_credentials
    ...    type=string
    ...    description=AWS credentials from the workspace (from aws-auth block; e.g. aws:access_key@cli, aws:irsa@cli).
    ...    pattern=\w*
    # This may not work without certain permissions. We might just drop this, but unfortuinately a numberd account ID is less human friendly to include in task titles. 
    ${aws_account_name_query}=       RW.CLI.Run Cli    
    ...    cmd=aws organizations describe-account --account-id $(aws sts get-caller-identity --query 'Account' --output text) --query "Account.Name" --output text | tr -d '\n'
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-s3-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_ACCOUNT_NAME}    ${aws_account_name_query.stdout}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${aws_credentials}    ${aws_credentials}
    # AWS credentials are provided by the platform from the aws-auth block (runwhen-local);
    # the runtime uses aws_utils to set up the auth environment (IRSA, access key, assume role, etc.).
    Set Suite Variable
    ...    &{env}
    ...    AWS_REGION=${AWS_REGION}
