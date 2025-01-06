*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS RDS health
Documentation        Check AWS RDS instances that are unencrypted, publicly accessible, or have backups disabled.
Force Tags    Tag    AWS    rds    database    security    encryption    backups

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
Check for unencrypted RDS instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unencrypted RDS instances
    [Tags]    aws    rds    database    encryption 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-rds-health ${CURDIR}/unencrypted-rds.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-rds-health/unencrypted-rds/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${unencrypted_rds_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unencrypted_rds_score}

Check for publicly accessible RDS instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find publicly accessible RDS instances
    [Tags]    aws    rds    database    security 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-rds-health ${CURDIR}/publicly-accessible-rds.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-rds-health/publicly-accessible-rds/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${publicly_accessible_rds_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${publicly_accessible_rds_score}

Check for disabled backup RDS instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find RDS instances with backups disabled
    [Tags]    aws    rds    database    backups
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-rds-health ${CURDIR}/backup-disabled-rds.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-rds-health/backup-disabled-rds/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${backup_disabled_rds_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${backup_disabled_rds_score}


Generate Health Score
    ${health_score}=      Evaluate  (${unencrypted_rds_score} + ${publicly_accessible_rds_score} + ${backup_disabled_rds_score}) / 3
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
    ${EVENT_THRESHOLD}=    RW.Core.Import User Variable    EVENT_THRESHOLD
    ...    type=string
    ...    description=The minimum number of rds instances to consider unsecured and unhealthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-rds-health
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${EVENT_THRESHOLD}    ${EVENT_THRESHOLD}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}

