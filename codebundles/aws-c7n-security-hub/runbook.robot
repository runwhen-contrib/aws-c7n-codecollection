*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS Security Hub
Documentation        List aws security hub findings
Force Tags    Tag    AWS    security-hub        

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
List aws security hub findings in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Check for security hub findings
    [Tags]    aws    security-hub
    CloudCustodian.Core.Generate Policy
    ...    ${CURDIR}/security-hub.j2 
    ...    resource_providers=${AWS_RESOURCE_PROVIDERS} 
    ${total_count}=    Set Variable    0
    FOR    ${region}    IN    @{AWS_ENABLED_REGIONS}
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${region} --output-dir ${OUTPUT_DIR}/aws-c7n-security-findings/${region} ${CURDIR}/security-hub.yaml --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
        ...    timeout_seconds=120
        ${dirs}=    RW.CLI.Run Cli
        ...    cmd=find ${OUTPUT_DIR}/aws-c7n-security-findings/${region} -mindepth 1 -maxdepth 1 -type d | jq -R -s 'split("\n") | map(select(length > 0))';
        TRY
            ${dir_list}=    Evaluate    json.loads(r'''${dirs.stdout}''')    json
        EXCEPT
            Log    Failed to load JSON payload, defaulting to empty list.    WARN
        END

        IF    len(@{dir_list}) > 0
            FOR    ${dir}    IN    @{dir_list}
                ${report_data}=     RW.CLI.Run Cli
                ...    cmd=cat ${dir}/resources.json 

                TRY
                    ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
                EXCEPT
                    Log    Failed to load JSON payload, defaulting to empty list.    WARN
                    ${resource_list}=    Create List
                END

                ${report}=    RW.CLI.Run Cli
                ...    cmd=jq '.[] | { Findings: ( .["c7n:finding-filter"][] | { Title: .Title, ProductName: .ProductName, Description: .Description, Resources: ( .Resources[] | { Type: .Type, Id: .Id, Region: .Region } ) })}' ${dir}/resources.json
                RW.Core.Add Pre To Report    ${report.stdout}

                IF    len(@{resource_list}) > 0
                    # Generate and format report
                    FOR    ${item}    IN    @{resource_list}
                        FOR    ${finding}    IN    @{item['c7n:finding-filter']}
                            ${pretty_finding}=    Evaluate    pprint.pformat(${finding})    modules=pprint
                            ${severity_label}=    Set Variable    ${finding['Severity']['Label']}
                            ${severity}=    Evaluate    1 if '${severity_label}' == 'CRITICAL' else 2 if '${severity_label}' == 'HIGH' else 3 if '${severity_label}' == 'MEDIUM' else 4
                            FOR    ${resource}    IN    @{finding['Resources']}
                                RW.Core.Add Issue
                                ...    severity=${severity}
                                ...    expected=${resource['Type']} ${resource['Id']} in AWS Region `${region}` in AWS Account `${AWS_ACCOUNT_ID}` should follow `${finding['Title']}`
                                ...    actual=AWS Security Hub detected an issue with the rule `${finding['Title']}` for `${resource['Type']}` `${resource['Id']}` in AWS Region `${region}` and AWS Account `${AWS_ACCOUNT_ID}`
                                ...    title=Security issue detected: Rule `${finding['Title']}` violated by `${resource['Type']}` `${resource['Id']}` in AWS Region `${region}` and AWS Account `${AWS_ACCOUNT_ID}`
                                ...    reproduce_hint=${c7n_output.cmd}
                                ...    details=${pretty_finding}
                                ...    next_steps=Review security hub findings in report related to rule `${finding['Title']}` on resource `${resource['Type']}` `${resource['Id']}` in AWS Region `${region}` and AWS Account `${AWS_ACCOUNT_ID}`
                            END
                        END
                    END
                ELSE
                    RW.Core.Add Pre To Report    "No Security Hub Findings in AWS region ${region}"
                END
            END
        ELSE 
            RW.Core.Add Pre To Report    "No directories found to process"
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
    ${AWS_RESOURCE_PROVIDERS}=    RW.Core.Import User Variable    AWS_RESOURCE_PROVIDERS
    ...    type=string
    ...    description=Comma separated list of AWS Resource Providers.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example="ec2,s3,rds,vpc"
    ...    default="ec2,s3,rds,vpc,ebs,iam-group,iam-policy,iam-role,iam-user"
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-security-findings
    ${AWS_ENABLED_REGIONS}=    RW.CLI.Run Cli
    ...    cmd=aws ec2 describe-regions --region ${AWS_REGION} --query 'Regions[*].RegionName' --output json
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${AWS_ENABLED_REGIONS}=    Evaluate    json.loads(r'''${AWS_ENABLED_REGIONS.stdout}''')    json
    Set Suite Variable    ${AWS_ENABLED_REGIONS}    ${AWS_ENABLED_REGIONS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}
    Set Suite Variable    ${AWS_RESOURCE_PROVIDERS}    ${AWS_RESOURCE_PROVIDERS}