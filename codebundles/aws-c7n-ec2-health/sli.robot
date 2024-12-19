*** Settings ***
Metadata          Author   saurabh3460
Metadata          Supports    AWS    EC2    CloudCustodian
Metadata          Display Name    AWS EC2 Health
Documentation     Count the number of EC2 instances that are unpatched or unused
Force Tags    EC2    Compute    AWS

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
Check for unpatched AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Check for unpatched EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/unpatched-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}        
    ...    tags=${AWS_EC2_TAGS}
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/unpatched-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/unpatched-ec2-instances/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    Log    ${count}
    ${unpatched_ec2_instances_event_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unpatched_ec2_instances_event_score}

Check for unused AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Check for unused EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/unused-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}        
    ...    tags=${AWS_EC2_TAGS}
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/unused-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/unused-ec2-instances/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    Log    ${count}
    ${unused_ec2_instances_event_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unused_ec2_instances_event_score}


Generate EBS Score
    ${ebs_health_score}=      Evaluate  (${unpatched_ec2_instances_event_score} + ${unused_ec2_instances_event_score}) / 2
    ${health_score}=      Convert to Number    ${ebs_health_score}  2
    RW.Core.Push Metric    ${health_score}

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
    ${EVENT_THRESHOLD}=    RW.Core.Import User Variable    EVENT_THRESHOLD
    ...    type=string
    ...    description=The minimum number of EC2 instance to consider.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
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
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ec2-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_EC2_AGE}    ${AWS_EC2_AGE}
    Set Suite Variable    ${AWS_EC2_TAGS}    ${AWS_EC2_TAGS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${EVENT_THRESHOLD}    ${EVENT_THRESHOLD}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}