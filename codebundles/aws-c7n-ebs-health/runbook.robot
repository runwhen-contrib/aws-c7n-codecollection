*** Settings ***
Metadata          Author    saurabh3460
Metadata          Supports    AWS    EBS    CloudCustodian
Metadata          Display Name    AWS EBS Health
Documentation     Check for AWS EBS resources by identifying unattached volumes, unused snapshots, and unencrypted volumes.
Force Tags    EBS    Volume    AWS    Storage    Encryption

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization



*** Tasks ***
List Unattached EBS Volumes in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` 
    [Documentation]  Check for unattached EBS volumes in the specified region. 
    [Tags]    ebs    storage    aws    volume    unattached
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
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ebs_volume_list}=    Create List
    END

    IF    len(@{ebs_volume_list}) > 0
        FOR    ${item}    IN    @{ebs_volume_list}
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=EBS volumes in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` should be attached
            ...    actual=EBS volume `${item["VolumeId"]}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` is unattached
            ...    title=Unattached EBS volume `${item["VolumeId"]}` detected in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Escalate to service owner for review of unattached AWS EBS volumes in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`\nDelete unattached AWS EBS volumes in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`
        END
    END


List Unencrypted EBS Volumes in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}`
    [Documentation]  Check for Unencrypted EBS Volumes in the specified region. 
    [Tags]    ebs    storage    aws    volume    encryption
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
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ebs_volume_list}=    Create List
    END

    IF    len(@{ebs_volume_list}) > 0
        FOR    ${item}    IN    @{ebs_volume_list}
            RW.Core.Add Issue        
            ...    severity=3
            ...    expected=EBS volumes in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` should be encrypted
            ...    actual=EBS volume `${item["VolumeId"]}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` is unencrypted
            ...    title=Unencrypted EBS volume `${item["VolumeId"]}` detected in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Escalate to service owner for review of unencrypted AWS EBS volumes found in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`\nEnable encryption of AWS EBS volumes in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`\nDelete unencrypted AWS EBS volumes in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`
        END
    END


List Unused EBS Snapshots in AWS Region `${AWS_REGION}` in AWS Account `${AWS_ACCOUNT_ID}` based on last access date
    [Documentation]  Check for Unused EBS Snapshots in the specified region. 
    [Tags]    ebs    storage    aws    volume    unused
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
        ${ebs_snapshot_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${ebs_snapshot_list}=    Create List
    END

    IF    len(@{ebs_snapshot_list}) > 0
        FOR    ${item}    IN    @{ebs_snapshot_list}
            RW.Core.Add Issue        
            ...    severity=4
            ...    expected=EBS snapshots in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` should be in use
            ...    actual=EBS Snapshots `${item["SnapshotId"]}` in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}` is unused
            ...    title=Unused EBS Snapshot `${item["SnapshotId"]}` detected in AWS Region `${AWS_REGION}` in AWS account `${AWS_ACCOUNT_ID}`
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}
            ...    next_steps=Escalate to service owner for review of unused EBS snapshots in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`\nDelete unused EBS snapshots in AWS Region \`${AWS_REGION}\` in AWS account \`${AWS_ACCOUNT_ID}\`
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