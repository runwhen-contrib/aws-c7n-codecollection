#!/bin/bash

# Configuration
REGION="us-west-2"
AZ="${REGION}b"
EBS_VOLUME_NAME="ebs-test"
EBS_VOLUME_SIZE="1"

# Check if the EBS volume exists
EBS_VOLUME_EXISTS=$(
    aws ec2 describe-volumes \
    --filters Name=tag:Name,Values=$EBS_VOLUME_NAME \
    --query 'Volumes[0].VolumeId' \
    --region=$REGION \
    --output text \
    --no-cli-pager
)

if [[ "$EBS_VOLUME_EXISTS" == "None" ]]; then
    echo "Creating EBS volume $EBS_VOLUME_NAME..."
    EBS_VOLUME_ID=$(
        aws ec2 create-volume \
        --region=$REGION \
        --availability-zone=$AZ \
        --size=$EBS_VOLUME_SIZE \
        --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$EBS_VOLUME_NAME}]" \
        --query 'VolumeId' \
        --output text \
        --no-encrypted \
        --no-cli-pager
    )
    echo "Created EBS volume: $EBS_VOLUME_ID"
else
    EBS_VOLUME_ID=$EBS_VOLUME_EXISTS
    echo "EBS volume $EBS_VOLUME_NAME already exists: $EBS_VOLUME_ID"
fi

# Create a snapshot from the EBS volume
SNAPSHOT_DESCRIPTION="Snapshot of volume $EBS_VOLUME_ID"
SNAPSHOT_ID=$(
    aws ec2 describe-snapshots \
    --filters Name=tag:Name,Values=$EBS_VOLUME_NAME \
    --region=$REGION \
    --query 'Snapshots[0].SnapshotId' \
    --output text \
    --no-cli-pager
)

if [[ "$SNAPSHOT_ID" != "None" ]]; then
    echo "$SNAPSHOT_ID snapshot already exists"
else
    echo "create Snapshot $EBS_VOLUME_NAME"
    aws ec2 create-snapshot \
    --region=$REGION \
    --volume-id=$EBS_VOLUME_ID \
    --description="$SNAPSHOT_DESCRIPTION" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$EBS_VOLUME_NAME}]" \
    --query 'SnapshotId' \
    --output text \
    --no-cli-pager
fi

if [[ "$EBS_VOLUME_ID" == "None" ]]; then
    echo "EBS volume with name $EBS_VOLUME_NAME does not exist."
else
    # Delete the volume
    echo "Deleting EBS volume: $EBS_VOLUME_ID..."
    aws ec2 delete-volume \
        --volume-id=$EBS_VOLUME_ID \
        --region=$REGION \
        --no-cli-pager
    echo "EBS volume $EBS_VOLUME_ID deleted successfully."
fi