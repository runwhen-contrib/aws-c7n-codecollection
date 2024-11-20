#!/bin/bash

# GIT_TLD=`git rev-parse --show-toplevel`
REGION="us-west-2"
AZ="${REGION}b"
EBS_VOLUME_NAME="ebs-test"
EBS_VOLUME_SIZE="1"


EBS_VOLUME_EXISTS=$(
    aws ec2 describe-volumes \
    --filters Name=tag:Name,Values=$EBS_VOLUME_NAME \
    --query 'Volumes[0].VolumeId' \
    --region=$REGION \
    --output text \
    --no-cli-pager
)


if [[ "$EBS_VOLUME_EXISTS" == "None" ]]; then
    aws ec2 create-volume --region=$REGION \
    --availability-zone=$AZ --size=$EBS_VOLUME_SIZE \
    --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$EBS_VOLUME_NAME}]" \
    --output text --no-encrypted --no-cli-pager
else 
    echo "$EBS_VOLUME_EXISTS ebs already exists"
fi