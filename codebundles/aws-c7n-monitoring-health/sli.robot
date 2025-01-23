*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian    CloudTrail    CloudWatch
Metadata            Display Name    AWS CloudWatch Logs health
Documentation       Check AWS Monitoring Configuration Health
Force Tags          AWS    cloudwatch    logs    cloudtrail

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
Check CloudWatch Log Groups Without Retention Period in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
    [Documentation]  Check CloudWatch Log Groups without retention period
    [Tags]    aws    cloudwatch    logs
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-monitoring-health ${CURDIR}/log-groups-no-retention.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-monitoring-health/log-groups-no-retention/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value';
    ${no_retention_score}=    Evaluate    1 if int(${count.stdout}) <= int(${MAX_LOG_GROUPS_ALLOWED}) else 0
    Set Global Variable    ${no_retention_score}

Check if CloudTrail exists and is configured for multi-region in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]    Check if CloudTrail exists and is configured for multi-region
    [Tags]    aws    cloudtrail    logs
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-monitoring-health ${CURDIR}/list-trail.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-monitoring-health/list-cloudtrail-trails/resources.json

    TRY
        ${total_trails}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${total_trails}=    Create List
    END

    # Check if any CloudTrail exists
    IF    len(@{total_trails}) == 0
        Set Global Variable    ${cloudtrail_score}    0
    ELSE
        # Check for multi-region trails
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-monitoring-health ${CURDIR}/trail-no-multi-region.yaml --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

        ${report_data}=     RW.CLI.Run Cli
        ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-monitoring-health/trail-no-multi-region/resources.json

        TRY
            ${single_region_trails}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
        EXCEPT
            Log    Failed to load JSON payload, defaulting to empty list.    WARN
            ${single_region_trails}=    Create List
        END

        ${has_multi_region}=    Evaluate    len(@{total_trails}) > len(@{single_region_trails})

        ${cloudtrail_score}=    Evaluate    1 if ${has_multi_region} else 0
        Set Global Variable    ${cloudtrail_score}
    END

Check CloudTrail Without CloudWatch Logs in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]    Check if CloudTrail exists and is configured for multi-region in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Tags]    aws    cloudtrail    cloudwatch    logs
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-monitoring-health ${CURDIR}/trail-without-cloudwatch-logs.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-monitoring-health/trail-without-cloudwatch-logs/resources.json

    TRY
        ${trails_without_cloudwatch}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${trails_without_cloudwatch}=    Create List
    END

    ${cloudtrail_trails_without_cloudwatch_score}=    Evaluate    1 if len(@{trails_without_cloudwatch}) <= int(${MAX_CLOUDTRAIL_TRAILS_WITHOUT_CLOUDWATCH_LOGS_ALLOWED}) else 0
    Set Global Variable    ${cloudtrail_trails_without_cloudwatch_score}

Generate Health Score
    ${health_score}=      Evaluate  (${no_retention_score} + ${cloudtrail_score} + ${cloudtrail_trails_without_cloudwatch_score}) / 3 
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
    ${MAX_LOG_GROUPS_ALLOWED}=    RW.Core.Import User Variable    MAX_LOG_GROUPS_ALLOWED
    ...    type=string
    ...    description=The maximum number of CloudWatch Log Groups without retention period to consider healthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_CLOUDTRAIL_TRAILS_ALLOWED}=    RW.Core.Import User Variable    MAX_CLOUDTRAIL_TRAILS_ALLOWED
    ...    type=string
    ...    description=The maximum number of CloudTrail Trails to consider healthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_CLOUDTRAIL_TRAILS_WITHOUT_CLOUDWATCH_LOGS_ALLOWED}=    RW.Core.Import User Variable    MAX_CLOUDTRAIL_TRAILS_WITHOUT_CLOUDWATCH_LOGS_ALLOWED
    ...    type=string
    ...    description=The maximum number of CloudTrail Trails without CloudWatch Logs to consider healthy
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-monitoring-health
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${MAX_LOG_GROUPS_ALLOWED}    ${MAX_LOG_GROUPS_ALLOWED}
    Set Suite Variable    ${MAX_CLOUDTRAIL_TRAILS_WITHOUT_CLOUDWATCH_LOGS_ALLOWED}    ${MAX_CLOUDTRAIL_TRAILS_WITHOUT_CLOUDWATCH_LOGS_ALLOWED}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY} 