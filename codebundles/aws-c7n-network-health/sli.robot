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
    ${public_ip_access_score}=    Evaluate    1 if ${total_count} <= int(${EVENT_THRESHOLD}) else 0
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
    ${unattached_eip_score}=    Evaluate    1 if ${total_count} <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unattached_eip_score}

Check for unused ELBs in AWS account `${AWS_ACCOUNT_ID}`
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
    ${unused_elb_score}=    Evaluate    1 if ${total_count} <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unused_elb_score}

Check for VPCs with Flow Logs disabled in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find VPCs that do not have Flow Logs enabled
    [Tags]    aws    vpc    network 
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
    ${flow_log_disabled_vpc_score}=    Evaluate    1 if ${total_count} <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${flow_log_disabled_vpc_score}

Generate Health Score
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
    ${EVENT_THRESHOLD}=    RW.Core.Import User Variable    EVENT_THRESHOLD
    ...    type=string
    ...    description=The minimum number of network resources to consider unsecured
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-network-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    ${AWS_ENABLED_REGIONS}=    RW.CLI.Run Cli
    ...    cmd=aws ec2 describe-regions --region ${AWS_REGION} --query 'Regions[*].RegionName' --output json
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${AWS_ENABLED_REGIONS}=    Evaluate    json.loads(r'''${AWS_ENABLED_REGIONS.stdout}''')    json
    Set Suite Variable    ${AWS_ENABLED_REGIONS}    ${AWS_ENABLED_REGIONS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${EVENT_THRESHOLD}    ${EVENT_THRESHOLD}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}