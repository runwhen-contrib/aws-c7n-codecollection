*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS ELB health
Documentation        Check AWS ELB health.
Force Tags    AWS    ELB

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
List unused ELBs in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unused Application Load Balancers (ALBs) and Network Load Balancers (NLBs) that do not have any associated targets
    [Tags]    aws    elb

    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-elb-health ${CURDIR}/unused-elb.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-elb-health/unused-alb-nlb/resources.json

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${parsed_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["Load-Balancer-Name", "DNS-Name", "Type", "State", "Region"], (.[] | [ .LoadBalancerName, .DNSName, .Type, .State.Code, $region ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-elb-health/unused-alb-nlb/resources.json | column -t
        ${formatted_results}=    Set Variable    Resource Summary:\n${parsed_results.stdout}
        RW.Core.Add Pre To Report    ${formatted_results}

        FOR    ${item}    IN    @{resource_list}
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=AWS ELB `${item['LoadBalancerName']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should have associated targets
            ...    actual=AWS ELB `${item['LoadBalancerName']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` does not have associated targets
            ...    title=Unused ELB detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Remove the unused ELB in AWS region \`${AWS_REGION}\` and AWS account \`${AWS_ACCOUNT_ID}\`

        END
    END

*** Keywords ***
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
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-elb-health         # Note: Clean out the cloud custodian report dir to ensure accurate data
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}
