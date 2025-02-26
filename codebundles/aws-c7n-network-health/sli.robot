*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS network health
Documentation        Count publicly accessible security groups, unused EIPs, unused ELBs, and VPCs with flow logs disabled
Force Tags    Tag    AWS    security-group    elb    eip    network    vpc        

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
Check for publicly accessible security groups in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find publicly accessible security groups (e.g., "0.0.0.0/0" or "::/0")
    [Tags]    aws    security-group    network
    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/insecure-sg-ingress.j2    
    ...    tags=${AWS_SECURITY_GROUP_TAGS}
    ${total_count}=    Set Variable    0
    FOR    ${region}    IN    @{AWS_ENABLED_REGIONS}
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${region} --output-dir ${OUTPUT_DIR}/${region}/aws-c7n-network-health ${CURDIR}/insecure-sg-ingress.yaml --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
        ${count}=     RW.CLI.Run Cli
        ...    cmd=cat ${OUTPUT_DIR}/${region}/aws-c7n-network-health/insecure-sg-ingress/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
        ${total_count}=    Evaluate    ${total_count} + int(${count.stdout})
    END
    ${public_ip_access_score}=    Evaluate    1 if ${total_count} <= int(${UNSECURED_SG_THRESHOLD}) else 0
    Set Global Variable    ${public_ip_access_score}


Check for unused Elastic IPs in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unused Elastic IPs that are not associated with any instance or network interface
    [Tags]    aws    eip    network 
    ${total_count}=    Set Variable    0
    FOR    ${region}    IN    @{AWS_ENABLED_REGIONS}
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${region} --output-dir ${OUTPUT_DIR}/${region}/aws-c7n-network-health ${CURDIR}/unused-eip.yaml --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
        ${count}=     RW.CLI.Run Cli
        ...    cmd=cat ${OUTPUT_DIR}/${region}/aws-c7n-network-health/unused-eip/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
        ${total_count}=    Evaluate    ${total_count} + int(${count.stdout})
    END
    ${unattached_eip_score}=    Evaluate    1 if ${total_count} <= int(${MAX_ALLOWED_UNUSED_RESOURCES}) else 0
    Set Global Variable    ${unattached_eip_score}

Check for unused ALBs and NLBs in AWS account `${AWS_ACCOUNT_ID}` without associated targets
    [Documentation]  Find unused Application Load Balancers (ALBs) and Network Load Balancers (NLBs) that do not have any associated targets
    [Tags]    aws    elb    network 
    ${total_count}=    Set Variable    0
    FOR    ${region}    IN    @{AWS_ENABLED_REGIONS}
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${region} --output-dir ${OUTPUT_DIR}/${region}/aws-c7n-network-health ${CURDIR}/unused-elb.yaml --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
        ${count}=     RW.CLI.Run Cli
        ...    cmd=cat ${OUTPUT_DIR}/${region}/aws-c7n-network-health/unused-elb/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
        ${total_count}=    Evaluate    ${total_count} + int(${count.stdout})
    END
    ${unused_elb_score}=    Evaluate    1 if ${total_count} <= int(${MAX_ALLOWED_UNUSED_RESOURCES}) else 0
    Set Global Variable    ${unused_elb_score}

Check for VPCs with disabled Flow Logs in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find VPCs that do not have Flow Logs enabled
    [Tags]    aws    vpc    network 
    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/flow-log-disabled-vpc.j2    
    ...    tags=${AWS_VPC_TAGS}
    ${total_count}=    Set Variable    0
    FOR    ${region}    IN    @{AWS_ENABLED_REGIONS}
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${region} --output-dir ${OUTPUT_DIR}/${region}/aws-c7n-network-health ${CURDIR}/flow-log-disabled-vpc.yaml --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
        ${count}=     RW.CLI.Run Cli
        ...    cmd=cat ${OUTPUT_DIR}/${region}/aws-c7n-network-health/flow-log-disabled-vpc/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
        ${total_count}=    Evaluate    ${total_count} + int(${count.stdout})
    END
    ${flow_log_disabled_vpc_score}=    Evaluate    1 if ${total_count} <= int(${DISABLED_FLOW_LOG_THRESHOLD}) else 0
    Set Global Variable    ${flow_log_disabled_vpc_score}

Generate Health Score for EC2 Instances in AWS Region `$${AWS_REGION}`
    ${health_score}=      Evaluate  (${public_ip_access_score} + ${unattached_eip_score} + ${unused_elb_score} + ${flow_log_disabled_vpc_score}) / 4
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
    ${UNSECURED_SG_THRESHOLD}=    RW.Core.Import User Variable    UNSECURED_SG_THRESHOLD
    ...    type=string
    ...    description=The number of publicly accessible security groups allowed
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_ALLOWED_UNUSED_RESOURCES}=    RW.Core.Import User Variable    MAX_ALLOWED_UNUSED_RESOURCES
    ...    type=string
    ...    description=The maximum number of unused network resources allowed
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${DISABLED_FLOW_LOG_THRESHOLD}=    RW.Core.Import User Variable    DISABLED_FLOW_LOG_THRESHOLD
    ...    type=string
    ...    description=The number of VPCs to consider as having flow logs disabled
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${AWS_SECURITY_GROUP_TAGS}=    RW.Core.Import User Variable  AWS_SECURITY_GROUP_TAGS
    ...    type=string
    ...    description=Comma separated list of tags (with only Key or both Key=Value) to exclude security groups from filtering. 
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example="Name,Environment=prod"
    ...    default=""
    ${AWS_VPC_TAGS}=    RW.Core.Import User Variable  AWS_VPC_TAGS
    ...    type=string
    ...    description=Comma separated list of tags (with only Key or both Key=Value) to include VPCs. Only VPCs with these tags will be filtered.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example="Name,Environment=prod"
    ...    default="Name"
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-network-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    ${AWS_ENABLED_REGIONS}=    RW.CLI.Run Cli
    ...    cmd=aws ec2 describe-regions --region ${AWS_REGION} --query 'Regions[*].RegionName' --output json
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${AWS_ENABLED_REGIONS}=    Evaluate    json.loads(r'''${AWS_ENABLED_REGIONS.stdout}''')    json
    Set Suite Variable    ${AWS_ENABLED_REGIONS}    ${AWS_ENABLED_REGIONS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_SECURITY_GROUP_TAGS}    ${AWS_SECURITY_GROUP_TAGS}
    Set Suite Variable    ${AWS_VPC_TAGS}    ${AWS_VPC_TAGS}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${UNSECURED_SG_THRESHOLD}    ${UNSECURED_SG_THRESHOLD}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}
    Set Suite Variable    ${DISABLED_FLOW_LOG_THRESHOLD}    ${DISABLED_FLOW_LOG_THRESHOLD}
    Set Suite Variable    ${MAX_ALLOWED_UNUSED_RESOURCES}    ${MAX_ALLOWED_UNUSED_RESOURCES}