*** Settings ***
Metadata          Author   saurabh3460
Metadata          Supports    AWS    EC2    CloudCustodian
Metadata          Display Name    AWS EC2 Health
Documentation     Check for EC2 instances that are unpatched or unused
Force Tags    EC2    Compute    AWS

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
List unpatched AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  List unpatched EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute    unpatched    

    # Generate the Cloud Custodian policy
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/unpatched-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}  
    ...    tags=${AWS_EC2_TAGS}

    # Run the Cloud Custodian policy
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/unpatched-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    # Read the generated report data
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/unpatched-ec2-instances/resources.json 

    ${clean_output_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ec2-health/old-ec2-instances
    TRY
        ${ec2_instances_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ec2_instances_list}=    Create List
    END

    IF    len(@{ec2_instances_list}) > 0
        # Generate and format report 
        ${parsed_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["InstanceId", "InstanceType", "ImageId","REGION", "Tags"], (.[] | [ .InstanceId, .InstanceType, .ImageId, $region, (.Tags | map(.Key + "=" + .Value) | join(","))]) | @tsv' ${OUTPUT_DIR}/aws-c7n-ec2-health/unpatched-ec2-instances/resources.json | column -t
        ${formatted_results}=    Set Variable    Resource Summary:\n${parsed_results.stdout}
        RW.Core.Add Pre To Report    ${formatted_results}

        # Loop through each EC2 instance in the list
        FOR    ${item}    IN    @{ec2_instances_list}
            RW.Core.Add Issue        
            ...    severity=3
            ...    actual=EC2 instance in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should not be unpatched for more than `${AWS_EC2_AGE}` days
            ...    expected=EC2 instance `${item["InstanceId"]}` has been unpatched for more than `${AWS_EC2_AGE}` days in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=Unpatched EC2 instance `${item["InstanceId"]}` found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Patch unpatched EC2 Instances in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`\nDelete unpatched AWS EC2 instance in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`
        END
    END

List unused AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  List unused EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute

    # Generate the Cloud Custodian policy
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/unused-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}  
    ...    tags=${AWS_EC2_TAGS}

    # Run the Cloud Custodian policy
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/unused-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    # Read the generated report data
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/unused-ec2-instances/resources.json 

    ${clean_output_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ec2-health/old-ec2-instances
    TRY
        ${ec2_instances_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ec2_instances_list}=    Create List
    END

    IF    len(@{ec2_instances_list}) > 0
        # Generate and format report 
        ${parsed_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["InstanceId", "InstanceType", "ImageId","REGION", "Tags"], (.[] | [ .InstanceId, .InstanceType, .ImageId, $region, (.Tags | map(.Key + "=" + .Value) | join(","))]) | @tsv' ${OUTPUT_DIR}/aws-c7n-ec2-health/unused-ec2-instances/resources.json | column -t
        ${formatted_results}=    Set Variable    Resource Summary:\n${parsed_results.stdout}
        RW.Core.Add Pre To Report    ${formatted_results}

        # Loop through each EC2 instance in the list
        FOR    ${item}    IN    @{ec2_instances_list}
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=EC2 instance in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should not be unused for more than `${AWS_EC2_AGE}` days
            ...    actual=EC2 instance `${item["InstanceId"]}` has been unused for more than `${AWS_EC2_AGE}` days in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=Unused EC2 instance `${item["InstanceId"]}` found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Delete unused AWS EC2 instance in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`
        END
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
    ${AWS_EC2_AGE}=    RW.Core.Import User Variable    AWS_EC2_AGE
    ...    type=string
    ...    description=The age of AWS EC2 instances in days to consider for filtering.
    ...    pattern=^\d+$
    ...    example=60
    ...    default=60
    ${AWS_EC2_TAGS}=    RW.Core.Import User Variable    AWS_EC2_TAGS
    ...    type=string
    ...    description=Comma-separated list of tags to filter AWS EC2 instances.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=Name,Environment
    ...    default=
    ${aws_account_name_query}=       RW.CLI.Run Cli    
    ...    cmd=aws organizations describe-account --account-id $(aws sts get-caller-identity --query 'Account' --output text) --query "Account.Name" --output text | tr -d '\n'
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ec2-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_EC2_AGE}    ${AWS_EC2_AGE}
    Set Suite Variable    ${AWS_EC2_TAGS}    ${AWS_EC2_TAGS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCOUNT_NAME}    ${aws_account_name_query.stdout}