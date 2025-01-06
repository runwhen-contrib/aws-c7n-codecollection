*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS network health
Documentation        List publicly accessible security groups, unused EIPs, and ELBs.
Force Tags    Tag    AWS    security-group    network    elb    eip

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
List Publicly Accessible Security Groups in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Find security group that contains a rule that allow public access
    [Tags]    tag    aws    security-group    network 
 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-network-health ${CURDIR}/insecure-sg-ingress.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-network-health/insecure-sg-ingress/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["Security-Group-Id", "Security-Group-Name", "Open-Ports", "VPC-ID", "IP-Address", "Region"], (.[] | [ .GroupId, .GroupName, (.IpPermissions[0].FromPort | tostring) + "-" + (.IpPermissions[0].ToPort | tostring) + "/" + .IpPermissions[0].IpProtocol, .VpcId, (.IpPermissions[0].IpRanges[0].CidrIp // "N/A"), $region ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-network-health/insecure-sg-ingress/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            RW.Core.Add Issue        
            ...    severity=3
            ...    expected=AWS Security Group `${item['GroupId']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should not allow public IP access
            ...    actual=AWS Security Group `${item['GroupId']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` allows public IP access
            ...    title=Public IP access rule detected in AWS Security Group `${item['GroupId']}` in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Disable public IP access from AWS Security Group in AWS region \`${AWS_REGION}\` and AWS account \`${AWS_ACCOUNT_ID}\`

        END
    END

List unused Elastic IPs in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unused Elastic IPs that are not associated with any instance or network interface
    [Tags]    aws    eip    network 

    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-network-health ${CURDIR}/unused-eip.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-network-health/unused-eip/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["Elastic-IP", "Allocation-Id", "Public-IP", "Region"], (.[] | [ .PublicIp, .AllocationId, .PublicIp, $region ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-network-health/unused-eip/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=Elastic IP `${item['PublicIp']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should be associated with an instance or network interface
            ...    actual=Elastic IP `${item['PublicIp']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` is not associated with any instance or network interface
            ...    title=Unused Elastic IP `${item['PublicIp']}` detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Release the unused Elastic IP in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`

        END
    END

List unused ELBs in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unused Application Load Balancers (ALBs) and Network Load Balancers (NLBs) that do not have any associated targets
    [Tags]    aws    elb    network

    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-elb-health ${CURDIR}/unused-elb.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-elb-health/unused-elb/resources.json

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["Load-Balancer-Name", "DNS-Name", "Type", "State", "Region"], (.[] | [ .LoadBalancerName, .DNSName, .Type, .State.Code, $region ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-elb-health/unused-elb/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=AWS ELB `${item['LoadBalancerName']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should have associated targets
            ...    actual=AWS ELB `${item['LoadBalancerName']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` does not have associated targets
            ...    title=Unused ELB detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Delete the unused ELB in AWS region \`${AWS_REGION}\` and AWS account \`${AWS_ACCOUNT_ID}\`

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
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-network-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}