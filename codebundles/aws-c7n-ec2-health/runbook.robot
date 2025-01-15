*** Settings ***
Metadata          Author   saurabh3460
Metadata          Supports    AWS    EC2    CloudCustodian
Metadata          Display Name    AWS EC2 Health
Documentation     Check for EC2 instances that are stale or stopped
Force Tags    EC2    Compute    AWS    asg

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization


*** Tasks ***
List stale AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  List stale EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute    stale    

    # Generate the Cloud Custodian policy
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/stale-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}  
    ...    tags=${AWS_EC2_TAGS}

    # Run the Cloud Custodian policy
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/stale-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    # Read the generated report data
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/stale-ec2-instances/resources.json
    ${parsed_results}=    CloudCustodian.Core.Parse Custodian Results
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-ec2-health/stale-ec2-instances
    RW.Core.Add Pre To Report    ${parsed_results} 

    TRY
        ${ec2_instances_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ec2_instances_list}=    Create List
    END

    ${ec2_instances_list_length}=    Evaluate    len(@{ec2_instances_list})
    IF    ${ec2_instances_list_length} > int(${MAX_ALLOWED_STALE_INSTANCES})
        # Generate and format report 
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["InstanceId", "InstanceType", "ImageId", "REGION", "Tags"], (.[] | [ .InstanceId, .InstanceType, .ImageId, $region, (.Tags | map(.Key + "=" + .Value) | join(","))]) | @tsv' ${OUTPUT_DIR}/aws-c7n-ec2-health/stale-ec2-instances/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        # Loop through each EC2 instance in the list
        FOR    ${item}    IN    @{ec2_instances_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            RW.Core.Add Issue        
            ...    severity=3
            ...    actual=EC2 instance in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should not be stale for more than `${AWS_EC2_AGE}` days
            ...    expected=EC2 instance `${item["InstanceId"]}` has been stale for more than `${AWS_EC2_AGE}` days in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=Stale EC2 instance `${item["InstanceId"]}` found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_item}
            ...    next_steps=Patch and restart EC2 instances in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`\nDelete stale AWS EC2 instance in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`
        END
    ELSE
        RW.Core.Add Pre To Report     ${ec2_instances_list_length} stale instances found, below threshold of ${MAX_ALLOWED_STALE_INSTANCES}\n${report_data.stdout}
    END

List stopped AWS EC2 instances in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` 
    [Documentation]  List stopped EC2 instances in AWS Region. 
    [Tags]    ec2    instance    aws    compute

    # Generate the Cloud Custodian policy
    ${result}=    CloudCustodian.Core.Generate Policy   
    ...    ${CURDIR}/stopped-ec2-instances.j2    
    ...    days=${AWS_EC2_AGE}  
    ...    tags=${AWS_EC2_TAGS}

    # Run the Cloud Custodian policy
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/stopped-ec2-instances.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    ${parsed_results}=    CloudCustodian.Core.Parse Custodian Results
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-ec2-health/stopped-ec2-instances
    RW.Core.Add Pre To Report    ${parsed_results} 

    # Read the generated report data
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/stopped-ec2-instances/resources.json 

    TRY
        ${ec2_instances_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ec2_instances_list}=    Create List
    END

    ${ec2_instances_list_length}=    Evaluate    len(@{ec2_instances_list})
    IF    ${ec2_instances_list_length} > int(${MAX_ALLOWED_STOPPED_INSTANCES})
        # Generate and format report 
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["InstanceId", "InstanceType", "ImageId","REGION", "Tags"], (.[] | [ .InstanceId, .InstanceType, .ImageId, $region, (.Tags | map(.Key + "=" + .Value) | join(","))]) | @tsv' ${OUTPUT_DIR}/aws-c7n-ec2-health/stopped-ec2-instances/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        # Loop through each EC2 instance in the list
        FOR    ${item}    IN    @{ec2_instances_list}
            ${pretty_item}=    Evaluate    pprint.pformat(${item})    modules=pprint
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=EC2 instance in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` should not be stopped for more than `${AWS_EC2_AGE}` days
            ...    actual=EC2 instance `${item["InstanceId"]}` has been stopped for more than `${AWS_EC2_AGE}` days in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    title=Stopped EC2 instance `${item["InstanceId"]}` found in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${pretty_item}
            ...    next_steps=Delete stopped AWS EC2 instance in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`
        END
    ELSE
        RW.Core.Add Pre To Report    ${ec2_instances_list_length} stopped instances found, below threshold of ${MAX_ALLOWED_STOPPED_INSTANCES}\n${report_data.stdout}
    END

List invalid AWS Auto Scaling Groups in AWS Region ${AWS_REGION} in AWS account ${AWS_ACCOUNT_ID}
    [Documentation]  List invalid Auto Scaling Groups
    [Tags]    asg    aws    compute    asg

    # Run the Cloud Custodian policy
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ec2-health ${CURDIR}/invalid-asg.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}

    # Read the generated report data
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ec2-health/invalid-asg/resources.json 

    ${parsed_results}=    CloudCustodian.Core.Parse Custodian Results
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-ec2-health/invalid-asg
    RW.Core.Add Pre To Report    ${parsed_results} 

    TRY
        ${asg_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${asg_list}=    Create List
    END

    ${asg_list_length}=    Evaluate    len(@{asg_list})
    IF    ${asg_list_length} > int(${MAX_ALLOWED_INVALID_ASG})
        # Generate and format report 
        ${formatted_results}=    RW.CLI.Run Cli
        ...    cmd=jq -r --arg region "${AWS_REGION}" '["AutoScalingGroupName", "LaunchConfigurationName", "MinSize", "MaxSize", "DesiredCapacity", "REGION", "Tags"], (.[] | [ .AutoScalingGroupName, .LaunchConfigurationName, .MinSize, .MaxSize, .DesiredCapacity, $region, (.Tags | map(.Key + "=" + .Value) | join(","))]) | @tsv' ${OUTPUT_DIR}/aws-c7n-ec2-health/invalid-asg/resources.json | column -t | awk '\''{if (NR == 1) print "Resource Summary:\\n" $0; else print $0}'\''
        RW.Core.Add Pre To Report    ${formatted_results.stdout}

        # Check for invalid ASGs and process each invalid attribute
        FOR    ${asg}    IN    @{asg_list}
            ${asg_name}=    Set Variable    ${asg["AutoScalingGroupName"]}
            ${invalid_items}=    Evaluate    ${asg}.get("Invalid", [])
            IF    ${invalid_items} == True
                RW.Core.Add Issue
                ...    severity=2
                ...    actual=Auto Scaling Group ${asg_name} in AWS Region ${AWS_REGION} in AWS Account ${AWS_ACCOUNT_ID} is invalid
                ...    expected=Auto Scaling Group ${asg_name} should be valid in AWS Region ${AWS_REGION} in AWS Account ${AWS_ACCOUNT_ID}
                ...    title=Invalid Auto Scaling Group configuration for \`${asg_name}\` in AWS Region \`${AWS_REGION}\` in AWS Account \`${AWS_ACCOUNT_ID}\`
                ...    reproduce_hint=${c7n_output.cmd}
                ...    details=Auto Scaling Group: ${asg_name}
                ...    next_steps=Escalate invalid Auto Scaling Group \`${asg_name}\` configuration in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\` to service owner
            ELSE
                ${invalid_items_length}=    Evaluate    len(@{invalid_items})
                IF    ${invalid_items_length} > 0
                    FOR    ${invalid_entry}    IN    @{invalid_items}
                        ${invalid_key}=    Set Variable    ${invalid_entry[0]}
                        ${human_friendly_key}=    Evaluate    '${invalid_key}'.replace("-", " ")
                        ${invalid_value}=    Set Variable    ${invalid_entry[1]}
                        RW.Core.Add Issue
                        ...    severity=2
                        ...    actual=Auto Scaling Group ${asg_name} in AWS Region ${AWS_REGION} in AWS Account ${AWS_ACCOUNT_ID} has ${human_friendly_key}
                        ...    expected=Auto Scaling Group ${asg_name} should not have ${human_friendly_key} in AWS Region ${AWS_REGION} in AWS Account ${AWS_ACCOUNT_ID}
                        ...    title=Found ${human_friendly_key} in Auto Scaling Group \`${asg_name}\` in AWS Region \`${AWS_REGION}\` in AWS Account \`${AWS_ACCOUNT_ID}\`
                        ...    reproduce_hint=${c7n_output.cmd}
                        ...    details=Auto Scaling Group: ${asg_name}\n- ${human_friendly_key}: ${invalid_value}
                        ...    next_steps=Fix ${human_friendly_key} Auto Scaling Group \`${asg_name}\` configuration in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\` to service owner
                    END
                ELSE
                    RW.Core.Add Pre To Report    No invalid configurations found for ${asg_name}.
                END
            END
        END
    ELSE
        RW.Core.Add Pre To Report    ${asg_list_length} invalid Auto Scaling Groups found, below threshold of ${MAX_ALLOWED_INVALID_ASG}\n${report_data.stdout}
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
    ${MAX_ALLOWED_STOPPED_INSTANCES}=    RW.Core.Import User Variable    MAX_ALLOWED_STOPPED_INSTANCES
    ...    type=string
    ...    description=The maxiumum number of stopped EC2 instances to allow.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_ALLOWED_STALE_INSTANCES}=    RW.Core.Import User Variable    MAX_ALLOWED_STALE_INSTANCES
    ...    type=string
    ...    description=The maxiumum number of stale EC2 instances to allow.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${MAX_ALLOWED_INVALID_ASG}=    RW.Core.Import User Variable    MAX_ALLOWED_INVALID_ASG
    ...    type=string
    ...    description=The maxiumum number of invalid ASGs to allow.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=0
    ${AWS_EC2_AGE}=    RW.Core.Import User Variable    AWS_EC2_AGE
    ...    type=string
    ...    description=The age (in days) for EC2 instances to be considered stale.
    ...    pattern=^\d+$
    ...    example=60
    ...    default="60"
    ${AWS_EC2_TAGS}=    RW.Core.Import User Variable    AWS_EC2_TAGS
    ...    type=string
    ...    description=Comma separated list of tags to filter AWS EC2 instances.
    ...    pattern=^[a-zA-Z0-9,]+$
    ...    example=Name,Environment
    ...    default=""
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ec2-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_EC2_AGE}    ${AWS_EC2_AGE}
    Set Suite Variable    ${AWS_EC2_TAGS}    ${AWS_EC2_TAGS}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${MAX_ALLOWED_STOPPED_INSTANCES}    ${MAX_ALLOWED_STOPPED_INSTANCES}
    Set Suite Variable    ${MAX_ALLOWED_STALE_INSTANCES}    ${MAX_ALLOWED_STALE_INSTANCES}
    Set Suite Variable    ${MAX_ALLOWED_INVALID_ASG}    ${MAX_ALLOWED_INVALID_ASG}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}