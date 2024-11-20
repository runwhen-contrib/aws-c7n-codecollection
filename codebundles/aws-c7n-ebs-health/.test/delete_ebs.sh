#!/bin/bash

# GIT_TLD=`git rev-parse --show-toplevel`

REGION="us-west-2"
EBS_VOLUME_NAME="ebs-test"

EBS_VOLUME_EXISTS=$(
    aws ec2 describe-volumes \
    --filters Name=tag:Name,Values=$EBS_VOLUME_NAME \
    --query 'Volumes[0].VolumeId' \
    --region=$REGION \
    --output text \
    --no-cli-pager
)

if [[ "$EBS_VOLUME_EXISTS" != "None" ]]; then
    echo "Deleting EBS volume $EBS_VOLUME_EXISTS..."
    aws ec2 delete-volume --volume-id "$EBS_VOLUME_EXISTS" --region=$REGION --no-cli-pager
else 
    echo "No EBS volume with tag Name=ebs-test exists."
fi
