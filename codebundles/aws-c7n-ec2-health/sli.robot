*** Settings ***
Metadata          Author   saurabh3460
Metadata          Supports    AWS    EC2    CloudCustodian
Metadata          Display Name    AWS EC2 Health
Documentation     Count the number of EC2 instances that are stale or stopped
Force Tags    EC2    Compute    AWS    asg

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
Check for stale AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Check for stale EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/stale-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}        
    ...    tags=${AWS_EC2_TAGS}
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/stale-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/stale-ec2-instances/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    ${stale_ec2_instances_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_ALLOWED_STALE_INSTANCES}) else 0
    Set Global Variable    ${stale_ec2_instances_score}

Check for stopped AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Check for stopped EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/stopped-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}        
    ...    tags=${AWS_EC2_TAGS}
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/stopped-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/stopped-ec2-instances/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    ${stopped_ec2_instances_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_ALLOWED_STOPPED_INSTANCES}) else 0
    Set Global Variable    ${stopped_ec2_instances_score}

Check for invalid Auto Scaling Groups in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Check for invalid Auto Scaling Groups.
    [Tags]    asg    aws    compute
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/invalid-asg.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/invalid-asg/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    ${invalid_asg_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_ALLOWED_INVALID_ASG}) else 0
    Set Global Variable    ${invalid_asg_score}

Generate Health Score for EC2 Instances in AWS Region `$${AWS_REGION}` in AWS Account `$${AWS_ACCOUNT_ID}`
    ${health_score}=      Evaluate  (${stale_ec2_instances_score} + ${stopped_ec2_instances_score} + ${invalid_asg_score}) / 3
    ${health_score}=      Convert to Number    ${health_score}  2
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
    ${MAX_ALLOWED_STOPPED_INSTANCES}=    RW.Core.Import User Variable    MAX_ALLOWED_STOPPED_INSTANCES
    ...    type=string
    ...    description=The maxiumum number of stopped EC2 instances to allow.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_ALLOWED_STALE_INSTANCES}=    RW.Core.Import User Variable    MAX_ALLOWED_STALE_INSTANCES
    ...    type=string
    ...    description=The maxiumum number of stale EC2 instances to allow.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_ALLOWED_INVALID_ASG}=    RW.Core.Import User Variable    MAX_ALLOWED_INVALID_ASG
    ...    type=string
    ...    description=The maxiumum number of Invalid ASG to allow.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${AWS_EC2_AGE}=    RW.Core.Import User Variable    AWS_EC2_AGE
    ...    type=string
    ...    description=The age (in days) for EC2 instances to be considered stale.
    ...    pattern=^\d+$
    ...    example=60
    ...    default="60"
    ${AWS_EC2_TAGS}=    RW.Core.Import User Variable    AWS_EC2_TAGS
    ...    type=string
    ...    description=Comma separated list of tags to filter AWS EC2 instances.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=Name,Environment
    ...    default=""
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ec2-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_EC2_AGE}    ${AWS_EC2_AGE}
    Set Suite Variable    ${AWS_EC2_TAGS}    ${AWS_EC2_TAGS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${MAX_ALLOWED_STOPPED_INSTANCES}    ${MAX_ALLOWED_STOPPED_INSTANCES}
    Set Suite Variable    ${MAX_ALLOWED_STALE_INSTANCES}    ${MAX_ALLOWED_STALE_INSTANCES}
    Set Suite Variable    ${MAX_ALLOWED_INVALID_ASG}    ${MAX_ALLOWED_INVALID_ASG}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}