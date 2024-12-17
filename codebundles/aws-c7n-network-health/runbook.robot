*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS network health
Documentation        Check AWS network health.
Force Tags    Tag    AWS    security-group    network

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
List security group that allow public IP ingress in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Find security group that contains a rule that allow public ingress
    [Tags]    tag    aws    security-group    network 
 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-network-health ${CURDIR}/sg-insecure-ingress.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    # ${parsed_results}=    CloudCustodian.Core.Parse EBS Results
    # ...    input_dir=${OUTPUT_DIR}/aws-c7n-network-health

    ${dirs}=    RW.CLI.Run Cli
    ...    cmd=find ${OUTPUT_DIR}/aws-c7n-network-health -mindepth 1 -maxdepth 1 -type d | jq -R -s 'split("\n") | map(select(length > 0))';

    TRY
        ${dir_list}=    Evaluate    json.loads(r'''${dirs.stdout}''')    json
        Log    ${dirs.stdout}
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
    END


    IF    len(@{dir_list}) > 0
        FOR    ${dir}    IN    @{dir_list}

            ${resource_data}=     RW.CLI.Run Cli
            ...    cmd=cat ${dir}/resources.json
            ${metadata}=     RW.CLI.Run Cli
            ...    cmd=cat ${dir}/metadata.json

            ${parsed_results}=    RW.CLI.Run Cli
            ...    cmd=jq -r '["Security-Group-Id", "Security-Group-Name", "Open-Ports", "VPC-ID"], (.[] | [ .GroupId, .GroupName, (.IpPermissions[0].FromPort | tostring) + "-" + (.IpPermissions[0].ToPort | tostring) + "/" + .IpPermissions[0].IpProtocol, .VpcId ]) | @tsv' ${dir}/resources.json | column -t

            RW.Core.Add Pre To Report    ${parsed_results} 

            TRY
                ${resource_list}=    Evaluate    json.loads(r'''${resource_data.stdout}''')    json
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
                FOR    ${item}    IN    @{resource_list}
                    RW.Core.Add Issue        
                    ...    severity=3
                    ...    expected=AWS Security-Group `${item['GroupId']}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` should not have rule to allow public IP ingress
                    ...    actual=AWS Security-Group `${item['GroupId']}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` allow public ip ingress
                    ...    title=Public IP address rule found in AWS Security-Group `${item['GroupId']} in AWS Account `${AWS_ACCOUNT_ID}`
                    ...    reproduce_hint=${c7n_output.cmd}
                    ...    details=${item}
                    ...    next_steps=
                    
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
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-network-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_TAGS}    ${AWS_TAGS}
    Set Suite Variable    ${AWS_RESOURCE_PROVIDERS}    ${AWS_RESOURCE_PROVIDERS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}