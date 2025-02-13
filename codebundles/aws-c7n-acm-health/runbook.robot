*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS ACM health
Documentation        List AWS ACM certificates that are unused, Expiring, or expired and failed status.
Force Tags    Tag    AWS    acm    certificate    security    expiration

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
List Unused ACM Certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unused ACM certificates
    [Tags]    aws    acm    certificate    security 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/unused-certificate.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/unused-certificate/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "InUse", "NotAfter", "Tags"], (.[] | [ .CertificateArn, .DomainName, .InUse, (.NotAfter // "Unknown"), (.Tags | map(.Key + "=" + .Value) | join(",")) ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/unused-certificate/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=ACM certificate `${item['CertificateArn']}` should be in use in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` 
            ...    actual=Unused ACM certificate `${item['CertificateArn']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` is not in use
            ...    title=Unused ACM certificates detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_item}
            ...    next_steps=Remove unused ACM certificates in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        END
    ELSE
        RW.Core.Add Pre To Report    No unused ACM certificates found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    END

List Expiring ACM Certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find Expiring ACM certificates
    [Tags]    aws    acm    certificate    expiration
    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/soon-to-expire-certificates.j2
    ...    days=${CERT_EXPIRY_DAYS}

    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/soon-to-expire-certificates.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/soon-to-expire-certificates/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "InUse", "NotAfter", "Tags"], (.[] | [ .CertificateArn, .DomainName, .InUse, (.NotAfter // "Unknown"), (.Tags | map(.Key + "=" + .Value) | join(",")) ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/soon-to-expire-certificates/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            RW.Core.Add Issue        
            ...    severity=3
            ...    expected=ACM certificate `${item['CertificateArn']}` should be renewed at least `${CERT_EXPIRY_DAYS}` days before it expires in in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    actual=ACM certificate `${item['CertificateArn']}` will expire in `${CERT_EXPIRY_DAYS}` days in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=ACM certificates are nearing expiration within `${CERT_EXPIRY_DAYS}` days in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_item}
            ...    next_steps=Renew Expiring ACM Certificates in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        END
    ELSE
            RW.Core.Add Pre To Report    No ACM certificates nearing expiration found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    END

List Expired ACM Certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find expired ACM certificates
    [Tags]    aws    acm    certificate    expiration
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/expired-certificate.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/expired-certificate/resources.json 
    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "InUse", "NotAfter", "Tags"], (.[] | [ .CertificateArn, .DomainName, .InUse, (.NotAfter // "Unknown"), (.Tags | map(.Key + "=" + .Value) | join(",")) ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/expired-certificate/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            RW.Core.Add Issue        
            ...    severity=3
            ...    expected=ACM certificate `${item['CertificateArn']}` should not be expired in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    actual=ACM certificate `${item['CertificateArn']}` is expired in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=Expired ACM certificates detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_item}
            ...    next_steps=Renew expired ACM certificate in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        END
    ELSE
        RW.Core.Add Pre To Report    No expired ACM certificates found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    END

List Failed Status ACM Certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find failed status ACM certificates
    [Tags]    aws    acm    certificate    status
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/failed-status-certificate.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/failed-status-certificate/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "Status", "FailureReason", "Tags"], (.[] | [ .CertificateArn, .DomainName, .Status, .FailureReason, (.Tags | map(.Key + "=" + .Value) | join(",")) ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/failed-status-certificate/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            RW.Core.Add Issue        
            ...    severity=3
            ...    expected=ACM certificate `${item['CertificateArn']}` should not be in a FAILED status in AWS Region `${AWS_REGION}` for AWS Account `${AWS_ACCOUNT_ID}`
            ...    actual=ACM certificate `${item['CertificateArn']}` is in a FAILED status due to: ${item['FailureReason']} in AWS Region `${AWS_REGION}` for AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=ACM Certificates are in a FAILED status detected in AWS Region `${AWS_REGION}` for AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_item}
            ...    next_steps=Investigate and resolve the failure reason for the ACM certificate in AWS Region `${AWS_REGION}` for AWS Account `${AWS_ACCOUNT_ID}`\nEscalate ACM Certificate Provisioning Issues to Service Owner
        END
    ELSE
        RW.Core.Add Pre To Report    No ACM certificates in failed status found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
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
    ${CERT_EXPIRY_DAYS}=    RW.Core.Import User Variable    CERT_EXPIRY_DAYS
    ...    type=string
    ...    description=Number of days before ACM certificate expiry to raise a issue
    ...    pattern=^\d+$
    ...    example=30
    ...    default=30
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-acm-health
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${CERT_EXPIRY_DAYS}    ${CERT_EXPIRY_DAYS}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}
