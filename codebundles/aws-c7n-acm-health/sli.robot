*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS ACM health
Documentation        Count AWS ACM certificates that are unused, Expiring, or expired and failed status.
Force Tags    Tag    AWS    acm    certificate    security    expiration

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
Check for unused ACM certificates in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unused ACM certificates
    [Tags]    aws    acm    certificate    security 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/unused-certificate.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/unused-certificate/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${unused_certificate_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_UNUSED_CERTIFICATES}) else 0
    Set Global Variable    ${unused_certificate_score}

Check for Expiring ACM certificates in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find Expiring ACM certificates
    [Tags]    aws    acm    certificate    expiration 
    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/soon-to-expire-certificates.j2
    ...    days=${CERT_EXPIRY_DAYS}
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/soon-to-expire-certificates.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/soon-to-expire-certificates/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${expiring_certificate_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_EXPIRING_CERTIFICATES}) else 0
    Set Global Variable    ${expiring_certificate_score}

Check for expired ACM certificates in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find expired ACM certificates
    [Tags]    aws    acm    certificate    expiration
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/expired-certificate.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/expired-certificate/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${expired_certificate_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_EXPIRED_CERTIFICATES}) else 0
    Set Global Variable    ${expired_certificate_score}

Check for Failed Status ACM Certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find failed status ACM certificates
    [Tags]    aws    acm    certificate    status
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/failed-status-certificate.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/failed-status-certificate/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${failed_certificate_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_FAILED_CERTIFICATES}) else 0
    Set Global Variable    ${failed_certificate_score}

Check for Pending Validation ACM Certificates in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find pending validation ACM certificates
    [Tags]    aws    acm    certificate    validation
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-acm-health ${CURDIR}/pending-validation-certificate.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-acm-health/pending-validation-certificate/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${pending_validation_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_PENDING_VALIDATION_CERTIFICATES}) else 0
    Set Global Variable    ${pending_validation_score}

Generate Health Score
    ${health_score}=      Evaluate  (${unused_certificate_score} + ${expiring_certificate_score} + ${expired_certificate_score} + ${failed_certificate_score} + ${pending_validation_score}) / 5
    ${health_score}=      Convert to Number    ${health_score}  2
    RW.Core.Push Metric    ${health_score}

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
    ${MAX_UNUSED_CERTIFICATES}=    RW.Core.Import User Variable    MAX_UNUSED_CERTIFICATES
    ...    type=string
    ...    description=The maximum number of unused ACM certificates to consider healthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_FAILED_CERTIFICATES}=    RW.Core.Import User Variable    MAX_FAILED_CERTIFICATES
    ...    type=string
    ...    description=The maximum number of failed ACM certificates to consider healthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_EXPIRING_CERTIFICATES}=    RW.Core.Import User Variable    MAX_EXPIRING_CERTIFICATES
    ...    type=string
    ...    description=The maximum number of Expiring ACM certificates to consider healthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_EXPIRED_CERTIFICATES}=    RW.Core.Import User Variable    MAX_EXPIRED_CERTIFICATES
    ...    type=string
    ...    description=The maximum number of expired ACM certificates to consider healthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_PENDING_VALIDATION_CERTIFICATES}=    RW.Core.Import User Variable    MAX_PENDING_VALIDATION_CERTIFICATES
    ...    type=string
    ...    description=The maximum number of pending validation ACM certificates to consider healthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${CERT_EXPIRY_DAYS}=    RW.Core.Import User Variable    CERT_EXPIRY_DAYS
    ...    type=string
    ...    description=Number of days before ACM certificate expiry to raise a issue
    ...    pattern=^\d+$
    ...    example=30
    ...    default=30
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-acm-health
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${CERT_EXPIRY_DAYS}    ${CERT_EXPIRY_DAYS}
    Set Suite Variable    ${MAX_UNUSED_CERTIFICATES}    ${MAX_UNUSED_CERTIFICATES}
    Set Suite Variable    ${MAX_FAILED_CERTIFICATES}    ${MAX_FAILED_CERTIFICATES}
    Set Suite Variable    ${MAX_EXPIRING_CERTIFICATES}    ${MAX_EXPIRING_CERTIFICATES}
    Set Suite Variable    ${MAX_EXPIRED_CERTIFICATES}    ${MAX_EXPIRED_CERTIFICATES}
    Set Suite Variable    ${MAX_PENDING_VALIDATION_CERTIFICATES}    ${MAX_PENDING_VALIDATION_CERTIFICATES}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}