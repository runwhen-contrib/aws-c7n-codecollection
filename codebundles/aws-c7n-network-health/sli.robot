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
Check for public IP access in security group in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find security groups that allow public ingress
    [Tags]    aws    security-group    network 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-network-health ${CURDIR}/sg-insecure-ingress.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-network-health/sg-insecure-ingress/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${public_ip_access_event_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${public_ip_access_event_score}


Check for unused Elastic IPs in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unused Elastic IPs that are not associated with any instance or network interface
    [Tags]    aws    elastic-ip    network 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-network-health ${CURDIR}/unused-eip.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-network-health/unused-eip/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${unattached_eip_event_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unattached_eip_event_score}


Generate Health Score
    ${ebs_health_score}=      Evaluate  (${public_ip_access_event_score} + ${unattached_eip_event_score}) / 2
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
    ...    description=The minimum number of network resources to consider unsecured and unhealthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-network-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${EVENT_THRESHOLD}    ${EVENT_THRESHOLD}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}