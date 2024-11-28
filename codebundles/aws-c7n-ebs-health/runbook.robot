*** Settings ***
Metadata          Author   runwhen
Metadata          Support    AWS    EBS
Documentation     Audit EBS resources by identifying unattached volumes, unused and aged snapshots, and unencrypted volumes.
Force Tags    EBS    Volume    AWS    Storage    Secure

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization



*** Tasks ***
List Unattached EBS Volumes in `${AWS_REGION}`
    [Documentation]  Check for unattached EBS volumes in the specified region. 
    [Tags]    ebs    storage    aws    volume
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ebs-health ${CURDIR}/unattached-ebs-volumes.yaml --cache-period 0
    ...    secret__aws_account_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ebs-health/unattached-ebs-volumes/resources.json 
    RW.Core.Add Pre To Report    ${c7n_output.stdout}     # Data needs to be parsed to be usable in the report.

    ${parsed_results}=    CloudCustodian.Core.Parse EBS Results
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-ebs-health
    RW.Core.Add Pre To Report    ${parsed_results} 

    ${clean_output_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ebs-health/unattached-ebs-volumes

    # Convert custodian json output to a list.
    TRY
        ${ebs_volume_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
        Log ${report_data.stdout}
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ebs_volume_list}=    Create List
    END

    # Generate issues if any unused EBS volumes are in the list
    IF    len(@{ebs_volume_list}) > 0
        FOR    ${item}    IN    @{ebs_volume_list}
            RW.Core.Add Issue        
            ...    severity=2
            ...    expected=EBS volumes in AWS Account `${AWS_ACCOUNT_NAME}` should be attached or in use
            ...    actual=EBS volume `${item["VolumeId"]}` in AWS Account `${AWS_ACCOUNT_NAME}` is unused
            ...    title=Unused EBS volume `${item["VolumeId"]}` detected in AWS Account `${AWS_ACCOUNT_NAME}`
            ...    reproduce_hint=Review the volume details and usage in the AWS Management Console or CLI.
            ...    details=${item}        # Include details such as volume ID, size, and region.
            ...    next_steps=Escalate to service owner for review of unattached volume `${item["VolumeId"]}` in ${AWS_ACCOUNT_NAME} AWS account in AWS Region ${AWS_REGION}".
        END
    END


List Unencrypted EBS Volumes in `${AWS_REGION}`
    [Documentation]  Check for unattached EBS volumes in the specified region. 
    [Tags]    ebs    storage    aws    volume
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ebs-health ${CURDIR}/unencrypted-ebs-volumes.yaml --cache-period 0
    ...    secret__aws_account_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ebs-health/unencrypted-ebs-volumes/resources.json 
    RW.Core.Add Pre To Report    ${c7n_output.stdout} 

    ${parsed_results}=    CloudCustodian.Core.Parse EBS Results
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-ebs-health
    RW.Core.Add Pre To Report    ${parsed_results}  

    ${clean_output_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ebs-health/unencrypted-ebs-volumes
   
    TRY
        ${ebs_volume_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
        Log ${report_data.stdout}
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ebs_volume_list}=    Create List
    END

    IF    len(@{ebs_volume_list}) > 0
        FOR    ${item}    IN    @{ebs_volume_list}
            RW.Core.Add Issue        
            ...    severity=2
            ...    expected=EBS volumes in AWS Account `${AWS_ACCOUNT_NAME}` should be unencrypted or in use
            ...    actual=EBS volume `${item["VolumeId"]}` in AWS Account `${AWS_ACCOUNT_NAME}` is unencrypted
            ...    title=Unencrypted EBS volume `${item["VolumeId"]}` detected in AWS Account `${AWS_ACCOUNT_NAME}`
            ...    reproduce_hint=Review the volume details and usage in the AWS Management Console or CLI.
            ...    details=${item}
            ...    next_steps=Escalate to service owner to review Unencrypted AWS EBS volume `${item["VolumeId"]}` found in ${AWS_ACCOUNT_NAME} AWS account in AWS Region ${AWS_REGION}".
        END
    END


List Unused EBS Snapshots in`${AWS_REGION}`
    [Documentation]  Check for unattached EBS volumes in the specified region. 
    [Tags]    ebs    storage    aws    volume
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ebs-health ${CURDIR}/unused-ebs-snapshots.yaml --cache-period 0
    ...    secret__aws_account_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${report_data}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ebs-health/unused-ebs-snapshots/resources.json 
    RW.Core.Add Pre To Report    ${c7n_output.stdout}  

    ${parsed_results}=    CloudCustodian.Core.Parse EBS Results
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-ebs-health
    RW.Core.Add Pre To Report    ${parsed_results}  
    ${clean_output_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ebs-health/unused-ebs-snapshots
    TRY
        ${ebs_volume_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
        Log ${report_data.stdout}
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ebs_volume_list}=    Create List
    END

    IF    len(@{ebs_volume_list}) > 0
        FOR    ${item}    IN    @{ebs_volume_list}
            RW.Core.Add Issue        
            ...    severity=2
            ...    expected=EBS snapshots in AWS Account `${AWS_ACCOUNT_NAME}` should be attached or in use
            ...    actual=EBS Snapshots `${item["SnapshotId"]}` in AWS Account `${AWS_ACCOUNT_NAME}` is unused
            ...    title=Unused EBS Snapshot `${item["SnapshotId"]}` detected in AWS Account `${AWS_ACCOUNT_NAME}`
            ...    reproduce_hint=Review the Snapshots details and usage in the AWS Management Console or CLI.
            ...    details=${item}        # Include details such as volume ID, size, and region.
            ...    next_steps=Escalate to service owner for review of unused EBS Snapshot `${item["SnapshotId"]}` in ${AWS_ACCOUNT_NAME} AWS account in AWS Region ${AWS_REGION}".
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
    ${aws_account_name_query}=       RW.CLI.Run Cli    
    ...    cmd=aws organizations describe-account --account-id $(aws sts get-caller-identity --query 'Account' --output text) --query "Account.Name" --output text | tr -d '\n'
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ebs-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_ACCOUNT_NAME}    ${aws_account_name_query.stdout}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${AWS_ACCESS_KEY_ID}    ${AWS_ACCESS_KEY_ID}
    Set Suite Variable    ${AWS_SECRET_ACCESS_KEY}    ${AWS_SECRET_ACCESS_KEY}