*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS tag policy
Documentation        List the number of AWS resources that do not follow tag policy.
Force Tags    Tag    AWS    Ec2     S3      RDS      VPC      iam-group        iam-policy     iam-role        iam-user

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
List Missing AWS Resource Tags in AWS Region in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Identify cloud resources (${AWS_RESOURCE_PROVIDERS}) that are missing required tags as per the organization's tagging policy.
    [Tags]    tag    aws    ec2     s3      rds      vpc      iam-group        iam-policy     iam-role        iam-user
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/tag-policy.j2      
    ...    tags=${AWS_TAGS}
    ...    resource_providers=${AWS_RESOURCE_PROVIDERS}    
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-tag-policy ${CURDIR}/tag-policy.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${parsed_results}=    CloudCustodian.Core.Parse EBS Results
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-tag-policy

    RW.Core.Add Pre To Report    ${parsed_results} 

    ${dirs}=    RW.CLI.Run Cli
    ...    cmd=find ${OUTPUT_DIR}/aws-c7n-tag-policy -mindepth 1 -maxdepth 1 -type d | jq -R -s 'split("\n") | map(select(length > 0))';

    TRY
        ${dir_list}=    Evaluate    json.loads(r'''${dirs.stdout}''')    json
        Log    ${dirs.stdout}
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
    END


    IF    len(@{dir_list}) > 0
        FOR    ${dir}    IN    @{dir_list}

            ${report_data}=     RW.CLI.Run Cli
            ...    cmd=cat ${dir}/resources.json
            ${metadata}=     RW.CLI.Run Cli
            ...    cmd=cat ${dir}/metadata.json

            TRY
                ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
            EXCEPT
                Log    Failed to load JSON payload, defaulting to empty list.    WARN
                ${resource_list}=    Create List
            END

            TRY
                ${meta_list}=    Evaluate    json.loads(r'''${metadata.stdout}''')    json
            EXCEPT
                Log    Failed to load JSON payload, defaulting to empty list.    WARN
                ${meta_list}=    Create List
            END

            IF    len(@{resource_list}) > 0
                ${resource_type}=    Set Variable    ${meta_list["policy"]["resource"]}
                ${resource_id}=    Set Variable    ${EMPTY}
                FOR    ${item}    IN    @{resource_list}
                    FOR    ${key}    IN    @{item.keys()}
                        ${lower_key}=    Evaluate    "${key}".lower()
                        IF    "id" in "${lower_key}"
                            ${resource_id}=    Set Variable    ${key}
                            Log    Found key containing ${resource_id}
                            Exit For Loop
                        END
                    END
                    IF    len("${resource_id}") > 0
                        RW.Core.Add Issue        
                        ...    severity=4
                        ...    expected=AWS `${resource_type}` `${item['${resource_id}']}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` should have the following Tags `${AWS_TAGS}`.
                        ...    actual=AWS `${resource_type}` `${item['${resource_id}']}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` missing tags `${AWS_TAGS}`
                        ...    title=Missing tags `${AWS_TAGS}` on `${resource_type}` `${item['${resource_id}']} detected in AWS Account `${AWS_ACCOUNT_ID}`
                        ...    reproduce_hint=${c7n_output.cmd}
                        ...    details=${item}
                        ...    next_steps=Escalate to the service owner to review AWS ${RESOURCE_TYPE} in AWS region `${AWS_REGION}` and AWS account `${AWS_ACCOUNT_ID}` for missing tags: `${AWS_TAGS}`.\nAdd missing tags `${AWS_TAGS}` to AWS `${RESOURCE_TYPE}` in AWS region `${AWS_REGION}` and AWS account `${AWS_ACCOUNT_ID}`.
                    ELSE
                        RW.Core.Add Issue        
                        ...    severity=4
                        ...    expected=AWS `${resource_type}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` should have the following Tags `${AWS_TAGS}`.
                        ...    actual=AWS `${resource_type}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` missing tags `${AWS_TAGS}`
                        ...    title=Missing tags `${AWS_TAGS}` on `${resource_type}` detected in AWS Account `${AWS_ACCOUNT_ID}`
                        ...    reproduce_hint=${c7n_output.cmd}
                        ...    details=${item}
                        ...    next_steps=Escalate to the service owner to review AWS ${RESOURCE_TYPE} in AWS region `${AWS_REGION}` and AWS account `${AWS_ACCOUNT_ID}` for missing tags: `${AWS_TAGS}`.\nAdd missing tags `${AWS_TAGS}` to AWS `${RESOURCE_TYPE}` in AWS region `${AWS_REGION}` and AWS account `${AWS_ACCOUNT_ID}`.
                    END
                END
            END
        END
    ELSE 
        Log    No directories found to process.    WARN
    END


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
    ...    description=Comma-separated list of AWS Resource Providers.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=ec2,s3,rds,vpc
    ...    default=ec2,rds,vpc,iam-group,iam-policy,iam-user
    ${AWS_TAGS}=    RW.Core.Import User Variable    AWS_TAGS
    ...    type=string
    ...    description=Comma-separated list of tags to filter AWS_EC2 instances.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=Name,Environment
    ...    default=Name,Environment,Owner
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-tag-policy         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_TAGS}    ${AWS_TAGS}
    Set Suite Variable    ${AWS_RESOURCE_PROVIDERS}    ${AWS_RESOURCE_PROVIDERS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}