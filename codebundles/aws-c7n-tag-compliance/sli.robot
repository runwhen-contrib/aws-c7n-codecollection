*** Settings ***
Documentation     Count total AWS resources that do not follow tag policy
Metadata          Author    saurabh3460
Metadata        Supports    AWS    Tag    CloudCustodian
Force Tags        AWS    Tag    CloudCustodian
Library          RW.Core
Library          RW.CLI
Library          Collections
Library          CloudCustodian.Core
Library          String
Suite Setup      Suite Initialization

*** Tasks ***
Validate AWS Resource Tag Compliance in Account `${AWS_ACCOUNT_ID}`
    [Documentation]    Count total AWS resources that do not follow tag policy
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/tag-compliance.j2      
    ...    tags=${AWS_TAGS}
    ...    resource_providers=${AWS_RESOURCE_PROVIDERS}

    ${total_noncompliant}=    Set Variable    ${0}
    ${first_region}=    Set Variable    ${AWS_ENABLED_REGIONS}[0]

    # Split providers into global and regional
    ${providers_list}=    Split String    ${AWS_RESOURCE_PROVIDERS}    ,
    ${global_providers}=    Create List
    ${regional_providers}=    Create List
    FOR    ${provider}    IN    @{providers_list}
        # Extract just the resource type part before the '='
        ${resource_type}=    Set Variable    ${provider.split('=')[0]}
        ${is_global}=    Evaluate    "${resource_type}".startswith("iam-")
        IF    ${is_global}
            Append To List    ${global_providers}    ${resource_type}
        ELSE
            Append To List    ${regional_providers}    ${resource_type}
        END
    END

    # Run global resources only in first region if we have any
    IF    len(@{global_providers}) > 0
        ${global_types}=    Evaluate    " -t ".join(@{global_providers})
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${first_region} --output-dir ${OUTPUT_DIR}/aws-c7n-tag-compliance/${first_region} ${CURDIR}/tag-compliance.yaml -t ${global_types} --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

        # Process global resources from first region
        ${dirs}=    RW.CLI.Run Cli
        ...    cmd=find ${OUTPUT_DIR}/aws-c7n-tag-compliance/${first_region} -mindepth 1 -maxdepth 1 -type d | jq -R -s 'split("\n") | map(select(length > 0))';

        TRY
            ${dir_list}=    Evaluate    json.loads(r'''${dirs.stdout}''')    json
            FOR    ${dir}    IN    @{dir_list}
                ${report_data}=     RW.CLI.Run Cli
                ...    cmd=cat ${dir}/resources.json

                TRY
                    ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
                    ${resource_count}=    Get Length    ${resource_list}
                    ${total_noncompliant}=    Evaluate    ${total_noncompliant} + ${resource_count}
                EXCEPT
                    Log    Failed to load JSON payload, skipping directory.    WARN
                END
            END
        EXCEPT
            Log    Failed to load JSON payload, defaulting to empty list.    WARN
        END
        RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-tag-compliance/${first_region}
    END

    # Run regional resources in all regions if we have any
    IF    len(@{regional_providers}) > 0
        ${regional_types}=    Evaluate    " -t ".join(@{regional_providers})
        FOR    ${region}    IN    @{AWS_ENABLED_REGIONS}
            ${c7n_output}=    RW.CLI.Run Cli
            ...    cmd=custodian run -r ${region} --output-dir ${OUTPUT_DIR}/aws-c7n-tag-compliance/${region} ${CURDIR}/tag-compliance.yaml -t ${regional_types} --cache-period 0
            ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
            ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

            ${dirs}=    RW.CLI.Run Cli
            ...    cmd=find ${OUTPUT_DIR}/aws-c7n-tag-compliance/${region} -mindepth 1 -maxdepth 1 -type d | jq -R -s 'split("\n") | map(select(length > 0))';

            TRY
                ${dir_list}=    Evaluate    json.loads(r'''${dirs.stdout}''')    json
                FOR    ${dir}    IN    @{dir_list}
                    ${report_data}=     RW.CLI.Run Cli
                    ...    cmd=cat ${dir}/resources.json

                    TRY
                        ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
                        ${resource_count}=    Get Length    ${resource_list}
                        ${total_noncompliant}=    Evaluate    ${total_noncompliant} + ${resource_count}
                    EXCEPT
                        Log    Failed to load JSON payload, skipping directory.    WARN
                    END
                END
            EXCEPT
                Log    Failed to load JSON payload, defaulting to empty list.    WARN
            END
        END
    END

    RW.Core.Push Metric    ${total_noncompliant}

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
    ${AWS_RESOURCE_PROVIDERS}=    RW.Core.Import User Variable    AWS_RESOURCE_PROVIDERS
    ...    type=string
    ...    description=Comma-separated list of AWS Resource Providers
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=ec2,rds,vpc,iam-group,iam-policy,iam-user,security-group
    ...    default=ec2,rds,vpc,iam-group,iam-policy,iam-user,security-group
    ${AWS_TAGS}=    RW.Core.Import User Variable    AWS_TAGS
    ...    type=string
    ...    description=Comma-separated list of mandatory tags that AWS resources must have for compliance. These tags will be checked across all specified resource types.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=Name,Environment,Owner
    ...    default=Name,Environment,Owner
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-tag-compliance
    ${AWS_ENABLED_REGIONS}=    RW.CLI.Run Cli
    ...    cmd=aws ec2 describe-regions --region ${AWS_REGION} --query 'Regions[*].RegionName' --output json
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${AWS_ENABLED_REGIONS}=    Evaluate    json.loads(r'''${AWS_ENABLED_REGIONS.stdout}''') 
    # ${AWS_ENABLED_REGIONS}=    Evaluate    json.loads(r'''["us-west-2"]''')    json
    Set Suite Variable    ${AWS_ENABLED_REGIONS}    ${AWS_ENABLED_REGIONS}
    Set Suite Variable    ${AWS_TAGS}    ${AWS_TAGS}
    Set Suite Variable    ${AWS_RESOURCE_PROVIDERS}    ${AWS_RESOURCE_PROVIDERS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}