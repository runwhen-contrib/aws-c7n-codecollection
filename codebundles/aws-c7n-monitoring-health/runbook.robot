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
List CloudWatch Log Groups Without Retention Period in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  List CloudWatch Log Groups Without Retention Period
    [Tags]    aws    cloudwatch    logs
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-monitoring-health ${CURDIR}/log-groups-no-retention.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-monitoring-health/log-groups-no-retention/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["LogGroupName", "Region", "RetentionInDays", "StoredBytes", "CreationTime"], (.[] | [ .logGroupName, $region, .retentionInDays, .storedBytes, .creationTime ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-monitoring-health/log-groups-no-retention/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=CloudWatch Log Group `${item['logGroupName']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should have a retention period
            ...    actual=CloudWatch Log Group `${item['logGroupName']}` has no retention period in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=CloudWatch Log Group `${item['logGroupName']}` with no retention period detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_item}
            ...    next_steps=Configure retention period for CloudWatch Log Groups in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        END
    ELSE
        RW.Core.Add Pre To Report    "No CloudWatch Log Groups without retention period found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`"
    END

Check CloudTrail Configuration in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]    Check if CloudTrail exists and is configured for multi-region
    [Tags]    aws    cloudtrail
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
        RW.Core.Add Pre To Report    "No CloudTrail exists in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`"
        ${pretty_itemt}=    Evaluate    pprint.pformat(${total_trails})    modules=pprint
        RW.Core.Add Issue
        ...    severity=4
        ...    expected=At least one CloudTrail should exist in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    actual=No CloudTrail exists in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
        ...    title=No CloudTrail Found in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        ...    reproduce_hint=${c7n_output.cmd}
        ...    details=${pretty_itemt}
        ...    next_steps=Create a multi-region CloudTrail in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
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
        IF    not ${has_multi_region}
            ${formatted_results}=    RW.CLI.Run Cli
                ...    cmd=jq -r --arg region "${AWS_REGION}" '["Name", "S3BucketName", "IsMultiRegionTrail", "HomeRegion", "TrailARN"], (.[] | [ .Name, .S3BucketName, .IsMultiRegionTrail, .HomeRegion, .TrailARN ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-monitoring-health/trail-no-multi-region/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
                RW.Core.Add Pre To Report    ${formatted_results.stdout}
            FOR    ${trail}    IN    @{single_region_trails}
                ${pretty_trail}=    Evaluate    pprint.pformat(${trail})    modules=pprint
                RW.Core.Add Issue
                    ...    severity=4
                    ...    expected=At least one multi-region CloudTrail should exist in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
                    ...    actual=CloudTrail `${trail['Name']}` should be a multi-region CloudTrail in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
                    ...    title=CloudTrail `${trail['Name']}` is a single-region CloudTrail in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
                    ...    reproduce_hint=${c7n_output.cmd}
                    ...    details=${pretty_trail}
                    ...    next_steps=Create a multi-region CloudTrail in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            END
        END
    END

 Check for CloudTrail integration with CloudWatch Logs in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]    Check for CloudTrail integration with CloudWatch Logs
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

    IF    len(@{trails_without_cloudwatch}) > 0
        ${formatted_results}=    RW.CLI.Run Cli
            ...    cmd=jq -r --arg region "${AWS_REGION}" '["Name", "S3BucketName", "IsMultiRegionTrail", "HomeRegion", "TrailARN"], (.[] | [ .Name, .S3BucketName, .IsMultiRegionTrail, .HomeRegion, .TrailARN ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-monitoring-health/trail-without-cloudwatch-logs/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
            RW.Core.Add Pre To Report    ${formatted_results.stdout}
        FOR    ${trail}    IN    @{trails_without_cloudwatch}
            ${pretty_trail}=    Evaluate    pprint.pformat(${trail})    modules=pprint
            RW.Core.Add Issue
            ...    severity=4
            ...    expected=CloudTrail `${trail['Name']}` should be integrated with CloudWatch Logs in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    actual=CloudTrail `${trail['Name']}` is not integrated with CloudWatch Logs in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=CloudTrail `${trail['Name']}` Without CloudWatch Logs Integration Found in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_trail}
            ...    next_steps=Configure CloudTrail with CloudWatch Logs in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
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
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-monitoring-health
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY} 