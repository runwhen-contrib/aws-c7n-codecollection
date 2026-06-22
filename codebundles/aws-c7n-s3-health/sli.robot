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
    ${public_bucket_count}=    Evaluate    int(${count.stdout})
    Set Global Variable    ${public_bucket_count}

Count S3 Buckets Without Default Encryption in AWS Account `${AWS_ACCOUNT_NAME}`
    [Documentation]  Fetch total number of S3 buckets without default encryption enabled.
    [Tags]    s3    storage    aws    security    encryption    data:config
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-s3-health ${CURDIR}/s3-unencrypted-buckets.yaml
    ...    env=${env}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-s3-health/s3-unencrypted-buckets/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    ${unencrypted_bucket_count}=    Evaluate    int(${count.stdout})
    Set Global Variable    ${unencrypted_bucket_count}

Generate S3 Health Metric
    [Documentation]  Combine insecure bucket findings into a single metric.
    ${s3_unhealthy_bucket_count}=    Evaluate    int(${public_bucket_count}) + int(${unencrypted_bucket_count})
    RW.Core.Push Metric    ${s3_unhealthy_bucket_count}




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
    ${AWS_ACCOUNT_NAME}=    RW.Core.Import User Variable   AWS_ACCOUNT_NAME
    ...    type=string
    ...    description=AWS Account Name
    ...    pattern=\w*
    ${aws_credentials}=    RW.Core.Import Secret    aws_credentials
    ...    type=string
    ...    description=AWS credentials from the workspace (from aws-auth block; e.g. aws:access_key@cli, aws:irsa@cli).
    ...    pattern=\w*
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-s3-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_ACCOUNT_NAME}    ${AWS_ACCOUNT_NAME}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${aws_credentials}    ${aws_credentials}
    # AWS credentials are provided by the platform from the aws-auth block (runwhen-local);
    # the runtime uses aws_utils to set up the auth environment (IRSA, access key, assume role, etc.).
    Set Suite Variable
    ...    &{env}
    ...    AWS_REGION=${AWS_REGION}
