*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS Security Hub
Documentation        Check for aws security hub findings
Force Tags    Tag    AWS    security-hub     

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
Check for security hub findings in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Check for security hub findings
    [Tags]    aws    security-hub
    CloudCustodian.Core.Generate Policy
    ...    ${CURDIR}/security-hub.j2 
    ...    resource_providers=${AWS_RESOURCE_PROVIDERS} 
    ${total_count}=    Set Variable    0
    FOR    ${region}    IN    @{AWS_ENABLED_REGIONS}
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${region} --output-dir ${OUTPUT_DIR}/aws-c7n-security-hub/${region} ${CURDIR}/security-hub.yaml --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
        ...    timeout_seconds=120
        ${dirs}=    RW.CLI.Run Cli
        ...    cmd=find ${OUTPUT_DIR}/aws-c7n-security-hub/${region} -mindepth 1 -maxdepth 1 -type d | jq -R -s 'split("\n") | map(select(length > 0))';
        TRY
            ${dir_list}=    Evaluate    json.loads(r'''${dirs.stdout}''')    json
        EXCEPT
            Log    Failed to load JSON payload, defaulting to empty list.    WARN
        END

        IF    len(@{dir_list}) > 0
            FOR    ${dir}    IN    @{dir_list}
                ${count}=     RW.CLI.Run Cli
                ...    cmd=cat ${dir}/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
                ${total_count}=    Evaluate    ${total_count} + int(${count.stdout.strip()})
            END
        ELSE 
            Log    No directories found to process.    WARN
        END
    END
    RW.Core.Push Metric    ${total_count}


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
    ${AWS_ACCESS_KEY_ID}=    RW.Core.Import Secret   AWS_ACCESS_KEY_ID
    ...    type=string
    ...    description=AWS Access Key ID
    ...    pattern=\w*
    ${AWS_SECRET_ACCESS_KEY}=    RW.Core.Import Secret   AWS_SECRET_ACCESS_KEY
    ...    type=string
    ...    description=AWS Access Key Secret
    ...    pattern=\w*
    ${AWS_RESOURCE_PROVIDERS}=    RW.Core.Import User Variable    AWS_RESOURCE_PROVIDERS
    ...    type=string
    ...    description=Comma separated list of AWS Resource Providers.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example="ec2,s3,rds,vpc"
    ...    default="ec2,s3,rds,vpc,ebs,iam-group,iam-policy,iam-role,iam-user"
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-security-hub
    ${AWS_ENABLED_REGIONS}=    RW.CLI.Run Cli
    ...    cmd=aws ec2 describe-regions --region ${AWS_REGION} --query 'Regions[*].RegionName' --output json
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${AWS_ENABLED_REGIONS}=    Evaluate    json.loads(r'''${AWS_ENABLED_REGIONS.stdout}''')    json
    Set Suite Variable    ${AWS_ENABLED_REGIONS}    ${AWS_ENABLED_REGIONS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}
    Set Suite Variable    ${AWS_RESOURCE_PROVIDERS}    ${AWS_RESOURCE_PROVIDERS}