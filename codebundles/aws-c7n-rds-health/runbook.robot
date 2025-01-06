*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS RDS health
Documentation        List AWS RDS instances that are unencrypted, publicly accessible, or have backups disabled.
Force Tags    Tag    AWS    rds    database    security    encryption    backups

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
List Unencrypted RDS Instances in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find unencrypted RDS instances
    [Tags]    aws    rds    database    encryption 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-rds-health ${CURDIR}/unencrypted-rds.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-rds-health/unencrypted-rds/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["DBInstanceIdentifier", "DBInstanceClass", "Engine", "Region", "Tags", "PubliclyAccessible", "StorageEncrypted"], (.[] | [ .DBInstanceIdentifier, .DBInstanceClass, .Engine, $region, (.Tags | map(.Key + "=" + .Value) | join(",")), .PubliclyAccessible, .StorageEncrypted ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-rds-health/unencrypted-rds/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            RW.Core.Add Issue        
            ...    severity=3
            ...    expected=RDS instance `${item['DBInstanceIdentifier']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should be encrypted
            ...    actual=RDS instance `${item['DBInstanceIdentifier']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` is not encrypted
            ...    title=Unencrypted RDS instance `${item['DBInstanceIdentifier']}` detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Enable encryption for the RDS instance in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        END
    END


List Publicly Accessible RDS Instances in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Find publicly accessible RDS instances
    [Tags]    aws    rds    database    security 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-rds-health ${CURDIR}/publicly-accessible-rds.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-rds-health/publicly-accessible-rds/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["DBInstanceIdentifier", "DBInstanceClass", "Engine", "Region", "Tags", "PubliclyAccessible", "StorageEncrypted"], (.[] | [ .DBInstanceIdentifier, .DBInstanceClass, .Engine, $region, (.Tags | map(.Key + "=" + .Value) | join(",")), .PubliclyAccessible, .StorageEncrypted ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-rds-health/publicly-accessible-rds/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            RW.Core.Add Issue        
            ...    severity=3
            ...    expected=RDS instance `${item['DBInstanceIdentifier']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should not be publicly accessible
            ...    actual=RDS instance `${item['DBInstanceIdentifier']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` is publicly accessible
            ...    title=Publicly accessible RDS instance `${item['DBInstanceIdentifier']}` detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Disable public access for the RDS instance in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
        END
    END

List RDS Instances with Backups Disabled in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Identify RDS instances with backups disabled
    [Tags]    aws    rds    database    backups 
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-rds-health ${CURDIR}/backup-disabled-rds.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-rds-health/backup-disabled-rds/resources.json 

    TRY
        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${resource_list}=    Create List
    END

    IF    len(@{resource_list}) > 0

        # Generate and format report
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["DBInstanceIdentifier", "DBInstanceClass", "Engine", "BackupRetentionPeriod", "Region", "Tags", "PubliclyAccessible", "StorageEncrypted"], (.[] | [ .DBInstanceIdentifier, .DBInstanceClass, .Engine, .BackupRetentionPeriod, $region, (.Tags | map(.Key + "=" + .Value) | join(",")), .PubliclyAccessible, .StorageEncrypted ]) | @tsv' ${OUTPUT_DIR}/aws-c7n-rds-health/backup-disabled-rds/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        FOR    ${item}    IN    @{resource_list}
            RW.Core.Add Issue        
            ...    severity=3
            ...    expected=RDS instance `${item['DBInstanceIdentifier']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should have backups enabled
            ...    actual=RDS instance `${item['DBInstanceIdentifier']}` in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` has backups disabled
            ...    title=RDS instance with backups disabled `${item['DBInstanceIdentifier']}` detected in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Enable backups for the RDS instance in AWS Region `${AWS_REGION}` and AWS Account `${AWS_ACCOUNT_ID}`
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
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-rds-health
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}
