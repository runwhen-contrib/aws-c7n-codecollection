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
List Unused ACM Certificates expiring in next `${CERT_EXPIRY_DAYS}` days in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
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
        ${len}    Get length    ${resource_list}    
        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "InUse", "NotAfter","Link", "Tags"], (.[] | [ (.CertificateArn | split("/") | .[1]), .DomainName, .InUse, (.NotAfter // "Unknown"), ("https://" + $region + ".console.aws.amazon.com/acm/home?region=" + $region + "#/certificates/" + (.CertificateArn | split("/") | .[1])), (.Tags | map(.Key + "=" + .Value) | join(","))]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/unused-certificate/resources.json | column -t | awk '\''{if (NR == 1) print "Certificate Summary:\\n=============================================\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        ${all_cert_details}=    Set Variable    ${EMPTY}
        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            ${all_cert_details}=    Catenate    SEPARATOR=\n\n    ${all_cert_details}    ${pretty_item}
        END

        RW.Core.Add Issue        
        ...    severity=4
        ...    expected=All ACM certificates should be in use in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    actual=Found ${len} unused ACM certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    title=Unused ACM certificates detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        ...    reproduce_hint=${c7n_output.cmd}
        ...    details=${all_cert_details}
        ...    next_steps=Remove unused ACM certificates in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
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
        ${len}    Get length    ${resource_list}    
        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "InUse", "NotAfter","Link", "Tags"], (.[] | [ (.CertificateArn | split("/") | .[1]), .DomainName, .InUse, (.NotAfter // "Unknown"),("https://" + $region + ".console.aws.amazon.com/acm/home?region=" + $region + "#/certificates/" + (.CertificateArn | split("/") | .[1])), (.Tags | map(.Key + "=" + .Value) | join(","))]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/soon-to-expire-certificates/resources.json | column -t | awk '\''{if (NR == 1) print "Certificate Summary:\\n=============================================\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        ${all_cert_details}=    Set Variable    ${EMPTY}
        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            ${all_cert_details}=    Catenate    SEPARATOR=\n\n    ${all_cert_details}    ${pretty_item}
        END

        RW.Core.Add Issue        
        ...    severity=3
        ...    expected=All ACM certificates should be renewed at least `${CERT_EXPIRY_DAYS}` days before expiration in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    actual=Found ${len} ACM certificates expiring within `${CERT_EXPIRY_DAYS}` days in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    title=ACM certificates nearing expiration detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        ...    reproduce_hint=${c7n_output.cmd}
        ...    details=${all_cert_details}
        ...    next_steps=Renew expiring ACM certificates in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
    ELSE
        RW.Core.Add Pre To Report    No ACM certificates nearing expiration found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    END

List Expired ACM Certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` within the Last ${CERT_EXPIRY_DAYS} Days
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
        ${len}    Get length    ${resource_list}    
        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "InUse", "NotAfter","Link" "Tags"], (.[] | [ (.CertificateArn | split("/") | .[1]), .DomainName, .InUse, (.NotAfter // "Unknown"), ("https://" + $region + ".console.aws.amazon.com/acm/home?region=" + $region + "#/certificates/" + (.CertificateArn | split("/") | .[1])), (.Tags | map(.Key + "=" + .Value) | join(","))]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/expired-certificate/resources.json | column -t | awk '\''{if (NR == 1) print "Certificate Summary:\\n=============================================\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        ${all_cert_details}=    Set Variable    ${EMPTY}
        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            ${all_cert_details}=    Catenate    SEPARATOR=\n\n    ${all_cert_details}    ${pretty_item}
        END

        RW.Core.Add Issue        
        ...    severity=3
        ...    expected=All ACM certificates should be renewed before expiration in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    actual=Found ${len} expired ACM certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    title=Expired ACM certificates detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        ...    reproduce_hint=${c7n_output.cmd}
        ...    details=${all_cert_details}
        ...    next_steps=Renew expired ACM certificates in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
    ELSE
        RW.Core.Add Pre To Report    No expired ACM certificates found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    END

List Certificates with Failed Status in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
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

    ${len}    Get length    ${resource_list}
    
    IF    ${len} > 0
        # Format and display results
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "Status", "FailureReason", "Link", "Tags"], (.[] | [ (.CertificateArn | split("/") | .[1]), .DomainName, .Status, .FailureReason, ("https://" + $region + ".console.aws.amazon.com/acm/home?region=" + $region + "#/certificates/" + (.CertificateArn | split("/") | .[1])), (.Tags | map(.Key + "=" + .Value) | join(",")) ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/failed-status-certificate/resources.json | column -t | awk '\''{if (NR == 1) print "Certificate Summary:\\n=============================================\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        ${all_cert_details}=    Set Variable    ${EMPTY}
        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            ${all_cert_details}=    Catenate    SEPARATOR=\n\n    ${all_cert_details}    ${pretty_item}
        END
        RW.Core.Add Issue        
        ...    severity=3
        ...    expected=All ACM certificates should be in a valid status in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    actual=Found ${len} ACM certificates in FAILED status in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    title=Failed ACM certificates detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        ...    reproduce_hint=${c7n_output.cmd}
        ...    details=${all_cert_details}
        ...    next_steps=Investigate and resolve the failure reasons for the ACM certificates in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`\nEscalate ACM Certificate Provisioning Issues to Service Owner
    ELSE
        RW.Core.Add Pre To Report    No ACM certificates in failed status found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    END

List Pending Validation ACM Certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find pending validation ACM certificates
    [Tags]    aws    acm    certificate    status
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/pending-validation-certificate.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/pending-validation-certificate/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    ${len}    Get length    ${resource_list}
    
    IF    ${len} > 0
        # Format and display results
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["CertificateArn", "DomainName", "Status", "Link", "Tags"], (.[] | [ (.CertificateArn | split("/") | .[1]), .DomainName, .Status, ("https://" + $region + ".console.aws.amazon.com/acm/home?region=" + $region + "#/certificates/" + (.CertificateArn | split("/") | .[1])), (.Tags | map(.Key + "=" + .Value) | join(",")) ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-acm-health/pending-validation-certificate/resources.json | column -t | awk '\''{if (NR == 1) print "Certificate Summary:\\n=============================================\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        ${all_cert_details}=    Set Variable    ${EMPTY}
        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            ${all_cert_details}=    Catenate    SEPARATOR=\n\n    ${all_cert_details}    ${pretty_item}
        END
        RW.Core.Add Issue        
        ...    severity=2
        ...    expected=All ACM certificates should be validated in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    actual=Found ${len} ACM certificates pending validation in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    title=Pending validation ACM certificates detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        ...    reproduce_hint=${c7n_output.cmd}
        ...    details=${all_cert_details}
        ...    next_steps=Complete the validation process for the pending ACM certificates in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
    ELSE
        RW.Core.Add Pre To Report    No ACM certificates pending validation found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
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
