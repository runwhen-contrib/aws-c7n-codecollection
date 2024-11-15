*** Settings ***
Metadata          Author   stewartshea
Metadata          Support    AWS,S3
Documentation     This is a basic Cloud Custodian AWS SLI
Force Tags    Message    Hello    World    Test
Library    RW.Core
Library    CloudCustodian.AWS

Suite Setup    Suite Initialization

*** Tasks ***
Count Buckets With Public Access
    ${count}=    CloudCustodian.AWS.Count S3 Buckets
    ...    AWS_REGION=${AWS_REGION}
    ...    AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}  
    RW.Core.Push Metric    ${count}




** Keywords ***
Suite Initialization
    ${AWS_REGION}=    RW.Core.Import User Variable    AWS_REGION
    ...    type=string
    ...    description=AWS Region
    ...    pattern=\w*
    ${AWS_ACCOUNT_ID}=    RW.Core.Import Secret   AWS_ACCOUNT_ID
    ...    type=string
    ...    description=AWS Access Key ID
    ...    pattern=\w*

    Set Suite Variable    ${AWS_REGION}    ${AWS_REGION}
    Set Suite Variable    ${AWS_ACCOUNT_ID}    ${AWS_ACCOUNT_ID}
