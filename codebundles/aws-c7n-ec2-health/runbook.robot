*** Settings ***
Metadata          Author   saurabh3460
Metadata          Support    AWS    EC2
Documentation     List old EC2 instances.
Force Tags    EC2    Compute    AWS    Instance

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
List old AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  List old EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/old-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}    
    ...    state=${AWS_EC2_STATE}    
    ...    tags=${AWS_EC2_TAGS}
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/old-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/old-ec2-instances/resources.json 
    RW.Core.Add Pre To Report    ${c7n_output.stdout}

    ${parsed_results}=    CloudCustodian.Core.Parse EBS Results
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-ec2-health
    RW.Core.Add Pre To Report    ${parsed_results} 

    ${clean_output_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ec2-health/old-ec2-instances
    
    
    TRY
        ${ec2_instances_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
        Log    ${report_data.stdout}
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ec2_instances_list}=    Create List
    END

    IF    len(@{ec2_instances_list}) > 0
        FOR    ${item}    IN    @{ec2_instances_list}
            RW.Core.Add Issue        
            ...    severity=2
            ...    expected=EC2 instance in AWS Account `${AWS_ACCOUNT_ID}` should not be older than ${AWS_EC2_AGE}
            ...    actual=Old EC2 instance `${item["InstanceId"]}` in AWS Account `${AWS_ACCOUNT_ID}` detected.
            ...    title=Old EC2 instance `${item["InstanceId"]}` detected in AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=Review the old ec2 instance details and usage in the AWS Management Console or CLI.
            ...    details=${item}        # Include complete details.
            ...    next_steps="Escalate to service owner to review of Old AWS EC2 instance `${item["InstanceId"]}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`. \n Delete Old AWS EC2 instance `${item["InstanceId"]}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`."
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
    ${AWS_EC2_STATE}=    RW.Core.Import User Variable    AWS_EC2_STATE
    ...    type=string
    ...    description=The state of AWS_EC2 instances to filter (e.g., running).
    ...    pattern=^\d+$
    ...    example=running
    ...    default=running
    ${AWS_EC2_AGE}=    RW.Core.Import User Variable    AWS_EC2_AGE
    ...    type=string
    ...    description=The age of AWS_EC2 instances in days to consider for filtering.
    ...    pattern=^\d+$
    ...    example=60
    ...    default=60
    ${AWS_EC2_TAGS}=    RW.Core.Import User Variable    AWS_EC2_TAGS
    ...    type=string
    ...    description=Comma-separated list of tags to filter AWS_EC2 instances.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=Name,Environment
    ...    default=
    ${aws_account_name_query}=       RW.CLI.Run Cli    
    ...    cmd=aws organizations describe-account --account-id $(aws sts get-caller-identity --query 'Account' --output text) --query "Account.Name" --output text | tr -d '\n'
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ec2-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_EC2_AGE}    ${AWS_EC2_AGE}
    Set Suite Variable    ${AWS_EC2_TAGS}    ${AWS_EC2_TAGS}
    Set Suite Variable    ${AWS_EC2_STATE}    ${AWS_EC2_STATE}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCOUNT_NAME}    ${aws_account_name_query.stdout}