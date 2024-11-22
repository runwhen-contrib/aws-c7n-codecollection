*** Settings ***
Metadata          Author   runwhen
Metadata          Support    AWS    EBS
Documentation     Counts the number of EBS resources by identifying unattached volumes, unused and aged snapshots, and unencrypted volumes.
Force Tags    EBS    Volume    AWS    Storage    Secure

Library    RW.Core
Library    RW.CLI

Suite Setup    Suite Initialization



*** Tasks ***
Check Unattached EBS Volumes in `${AWS_REGION}`
    [Documentation]  Check for unattached EBS volumes in the specified region. 
    [Tags]    ebs    storage    aws    volume
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ebs-health ${CURDIR}/unattached-ebs-volumes.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ebs-health/unattached-ebs-volumes/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    ${unattached_ebs_event_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unattached_ebs_event_score}

Check Unencrypted EBS Volumes in `${AWS_REGION}`
    [Documentation]  Check for unencrypted EBS volumes and report any found that do not meet encryption requirements.
    [Tags]    ebs    storage    aws    security    volume
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ebs-health ${CURDIR}/unencrypted-ebs-volumes.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ebs-health/unencrypted-ebs-volumes/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    ${unencrypted_ebs_event_score}=    Evaluate    1 if int(${count.stdout}) <= int(${SECURITY_EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unencrypted_ebs_event_score}


Check Unused EBS Snapshots in `${AWS_REGION}`
    [Documentation]  Check for unused EBS snapshots. 
    [Tags]    ebs    storage    aws    snapshots    volume
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-ebs-health ${CURDIR}/unused-ebs-snapshots.yaml --cache-period 0
    ...    secret__aws_access_key_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${count}=     RW.CLI.Run Cli
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-ebs-health/unused-ebs-snapshots/metadata.json | jq '.metrics[] | select(.MetricName == "ResourceCount") | .Value'
    ${unsued_ebs_snapshot_event_score}=    Evaluate    1 if int(${count.stdout}) <= int(${EVENT_THRESHOLD}) else 0
    Set Global Variable    ${unsued_ebs_snapshot_event_score}


Generate EBS Score
    ${ebs_health_score}=      Evaluate  (${unattached_ebs_event_score} + ${unencrypted_ebs_event_score} + ${unsued_ebs_snapshot_event_score}) / 3
    ${health_score}=      Convert to Number    ${ebs_health_score}  2
    RW.Core.Push Metric    ${health_score}

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
    ${EVENT_THRESHOLD}=    RW.Core.Import User Variable    EVENT_THRESHOLD
    ...    type=string
    ...    description=The minimum number of EBS volumes | snapshots to consider unhealthy.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=1
    ${SECURITY_EVENT_THRESHOLD}=    RW.Core.Import User Variable    SECURITY_EVENT_THRESHOLD
    ...    type=string
    ...    description=The minimum number of security-related EBS volumes to consider unhealthy.
    ...    pattern=^\d+$
    ...    example=2
    ...    default=1
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-ebs-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
    Set Suite Variable    ${EVENT_THRESHOLD}    ${EVENT_THRESHOLD}
    Set Suite Variable    ${SECURITY_EVENT_THRESHOLD}    ${SECURITY_EVENT_THRESHOLD}