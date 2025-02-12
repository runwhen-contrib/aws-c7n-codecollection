*** Settings ***
Metadata            Author   saurabh3460
Metadata            Supports    AWS    Tag    CloudCustodian
Metadata            Display Name    AWS tag policy
Documentation        List the number of AWS resources that do not follow tag policy.
Force Tags    Tag    AWS    compliance
Library    String
Library    Collections
Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core
Library    Util.py
Suite Setup    Suite Initialization


*** Tasks ***
Validate AWS Resource Tag Compliance in Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Identify cloud resources (${AWS_RESOURCE_PROVIDERS}) that are missing required tags as per the organization's tagging policy.
    [Tags]    tag    aws    compliance
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/tag-compliance.j2      
    ...    tags=${AWS_TAGS}
    ...    resource_providers=${AWS_RESOURCE_PROVIDERS}    

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

    ${first_region}=    Set Variable    ${AWS_ENABLED_REGIONS}[0]

    # Run global resources only in first region if we have any
    IF    len(@{global_providers}) > 0
        ${global_types}=    Evaluate    " -t ".join(@{global_providers})
        ${c7n_output}=    RW.CLI.Run Cli
        ...    cmd=custodian run -r ${first_region} --output-dir ${OUTPUT_DIR}/aws-c7n-tag-compliance/${first_region} ${CURDIR}/tag-compliance.yaml -t ${global_types} --cache-period 0
        ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
        ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
        ...    timeout_seconds=200
        Process Resources    ${first_region}    ${c7n_output}
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
            ...    timeout_seconds=200
            Process Resources    ${region}    ${c7n_output}
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
    ...    description=Comma-separated list of AWS Resource Providers. On adding a new resource provider, please update the resource_id_mappings.json file with the new resource type and the corresponding ID field name.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=ec2,rds,vpc,iam-group,iam-policy,iam-user,security-group
    ...    default=ec2,rds,vpc,iam-group,iam-policy,iam-user,security-group
    ${AWS_TAGS}=    RW.Core.Import User Variable    AWS_TAGS
    ...    type=string
    ...    description=Comma-separated list of mandatory tags that AWS resources must have for compliance. These tags will be checked across all specified resource types.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=Name,Environment,Owner
    ...    default=Name,Environment,Owner
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-tag-compliance         # Note: Clean out the cloud custoding report dir to ensure accurate data
    ${AWS_ENABLED_REGIONS}=    RW.CLI.Run Cli
    ...    cmd=aws ec2 describe-regions --region ${AWS_REGION} --query 'Regions[*].RegionName' --output json
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${AWS_ENABLED_REGIONS}=    Evaluate    json.loads(r'''${AWS_ENABLED_REGIONS.stdout}''')    json
    Set Suite Variable    ${AWS_ENABLED_REGIONS}    ${AWS_ENABLED_REGIONS}
    Set Suite Variable    ${AWS_TAGS}    ${AWS_TAGS}
    Set Suite Variable    ${AWS_RESOURCE_PROVIDERS}    ${AWS_RESOURCE_PROVIDERS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}

Process Resources
    [Arguments]    ${region}    ${c7n_output}
    ${dirs}=    RW.CLI.Run Cli
    ...    cmd=find ${OUTPUT_DIR}/aws-c7n-tag-compliance/${region} -mindepth 1 -maxdepth 1 -type d | jq -R -s 'split("\n") | map(select(length > 0))';
 
    TRY
        ${dir_list}=    Evaluate    json.loads(r'''${dirs.stdout}''')    json
        Log    ${dirs.stdout}
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        RETURN
    END

    # Initialize region-specific issue tracking
    ${region_issues}=    Create Dictionary
    ${region_resources}=    Create List

    IF    len(@{dir_list}) > 0
        FOR    ${dir}    IN    @{dir_list}
            ${report_data}=     RW.CLI.Run Cli
            ...    cmd=cat ${dir}/resources.json
            ${metadata}=     RW.CLI.Run Cli
            ...    cmd=cat ${dir}/metadata.json

            TRY
                ${resource_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
                ${meta_list}=    Evaluate    json.loads(r'''${metadata.stdout}''')    json
            EXCEPT
                Log    Failed to load JSON payload, defaulting to empty list.    WARN
                Continue For Loop
            END

            IF    len(@{resource_list}) > 0
                ${resource_type}=    Set Variable    ${meta_list["policy"]["resource"]}
                ${resource_type_title}=    Set Variable    ${resource_type.title()}
                
                # Load resource ID mappings
                TRY
                    ${resource_id_mappings_json}=    RW.CLI.Run Cli    cmd=cat ${CURDIR}/resource_id_mappings.json
                    ${resource_id_mapping}=    Evaluate    json.loads(r'''${resource_id_mappings_json.stdout}''')    json
                EXCEPT
                    Log    Failed to load resource_id_mappings.json, using default mapping    WARN
                    ${resource_id_mapping}=    Create Dictionary
                END
                
                # Collect all resources with missing tags
                FOR    ${item}    IN    @{resource_list}
                    ${matched_filters}=    Set Variable    ${item["c7n:MatchedFilters"]}
                    ${cleaned_tags}=    Create List
                    FOR    ${tag}    IN    @{matched_filters}
                        ${cleaned_tag}=    Replace String    ${tag}    tag:    ${EMPTY}
                        Append To List    ${cleaned_tags}    ${cleaned_tag}
                    END
                    ${missing_tags}=    Evaluate    ", ".join($cleaned_tags)
                    ${resource_id}=    Set Variable    ${resource_id_mapping.get('${resource_type}')}
                    # Find ARN if available
                    ${arn}=    Set Variable    ${EMPTY}
                    FOR    ${key}    IN    @{item.keys()}
                        IF    'arn' in '${key}'.lower()
                            ${arn}=    Set Variable    ${item['${key}']}
                            BREAK
                        END
                    END
                    # Add resource to region-specific list
                    ${resource_details}=    Create Dictionary
                    ...    type=${resource_type_title}
                    ...    id=${item['${resource_id}'] if len("${resource_id}") > 0 else "N/A"}
                    ...    missing_tags=${missing_tags}
                    ...    arn=${arn}
                    Append To List    ${region_resources}    ${resource_details}
                END
            END
        END
        
        # If we found resources with issues in this region
        IF    len(@{region_resources}) > 0
            # Create markdown table of resources
            ${report}=    GENERATE REGION REPORT    ${region}    ${region_resources}            
            # Add table to report
            RW.Core.Add Pre To Report    ${report}
            # Get the count of resources with issues
            ${resource_count}=    Get Length    ${region_resources}
            ${pretty_item}=    Evaluate    pprint.pformat(${region_resources})    modules=pprint
            # Create single issue per region
            RW.Core.Add Issue
            ...    severity=4
            ...    expected=All resources in AWS Region `${region}` should have the following Tags `${AWS_TAGS}`.
            ...    actual=Found ${resource_count} resources in AWS Region `${region}` missing required tags.
            ...    title=Missing tags `${AWS_TAGS}` detected in AWS Region `${region}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_item}
            ...    next_steps=Apply missing tags `${AWS_TAGS}` to resources in AWS region `${region}` and AWS account `${AWS_ACCOUNT_ID}`.
        END
    ELSE 
        Log    No resources found in region ${region}.    INFO
        RW.Core.Add Pre To Report    No resources found in region ${region}.
    END