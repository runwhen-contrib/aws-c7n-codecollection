*** Settings ***
Metadata          Author   stewartshea
Metadata          Support    AWS    S3
Documentation     Generates a report on S3 buckets in an Account that are insecure or unhealthy. 
Force Tags    S3    Bucket    AWS    Storage    Secure

Library    RW.Core
Library    RW.CLI
Library    CloudCustodian.Core

Suite Setup    Suite Initialization

*** Tasks ***
List S3 Buckets With Public Access in AWS Account `${AWS_ACCOUNT_NAME}`
    [Documentation]  Fetch total number of S3 buckets with public access enabled and raises an issue if any exist.  
    [Tags]    s3    storage    aws    security
    ${c7n_output}=    RW.CLI.Run Cli
    ...    cmd=custodian run -r ${AWS_REGION} --output-dir ${OUTPUT_DIR}/aws-c7n-s3-health ${CURDIR}/s3-public-buckets.yaml
    ...    secret__aws_account_id=${AWS_ACCESS_KEY_ID}
    ...    secret__aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
    ${report_data}=    RW.CLI.Run Cli                                         # Note: This just an example of parsing with the RW.CLI.Run Cli keyword. 
    ...    cmd=cat ${OUTPUT_DIR}/aws-c7n-s3-health/s3-public-buckets/resources.json 
    RW.Core.Add Pre To Report    ${c7n_output.stdout}     # Note: This actual data needs to be parsed to be usable in the report. Json data in a report like this isn't super useful. 

    ${parsed_results}=    CloudCustodian.Core.Parse Custodian Results         # Note: This just an example of simple parsing with a custom keyword.
    ...    input_dir=${OUTPUT_DIR}/aws-c7n-s3-health
    RW.Core.Add Pre To Report    ${parsed_results}  

    # Convert custodian json output to a list. 
    TRY
        ${bucket_list}=    Evaluate    json.loads(r'''${report_data.stdout}''')    json
    EXCEPT
        Log    Failed to load JSON payload, defaulting to empty list.    WARN
        ${bucket_list}=    Create List
    END

    # Generate issues if any resources are in the list
    IF    len(@{bucket_list}) > 0
        FOR    ${item}    IN    @{bucket_list}
            RW.Core.Add Issue        # Note: This is fairly basic issue. Ideally the next steps and details would have more specific recommendations and details. 
            ...    severity=2
            ...    expected=AWS S3 Buckets in AWS Account `${AWS_ACCOUNT_NAME}` should not have public access enabled
            ...    actual=AWS S3 Buckets in AWS Account `${AWS_ACCOUNT_NAME}` have public access enabled
            ...    title=AWS S3 Buckets `${item["Name"]}` in AWS Account `${AWS_ACCOUNT_NAME}` have public access enabled
            ...    reproduce_hint=${c7n_output.cmd}
            ...    details=${item}        # Note: This should have some refined and specific details.
            ...    next_steps=Disable public access to AWS S3 bucket `${item["Name"]}`.   
        END    
    END



** Keywords ***
Suite Initialization
    ${AWS_REGION}=    RW.Core.Import User Variable    AWS_REGION
    ...    type=string
    ...    description=AWS Region
    ...    pattern=\w*
    ${AWS_ACCOUNT_ID}=    RW.Core.Import Secret   AWS_ACCOUNT_ID
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
    ${clean_workding_dir}=    RW.CLI.Run Cli    cmd=rm -rf ${OUTPUT_DIR}/aws-c7n-s3-health         # Note: Clean out the cloud custoding report dir to ensure accurate data
    Set Suite Variable    ${AWS_ACCOUNT_NAME}    ${aws_account_name_query.stdout}
    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
