#!/bin/bash

# Configuration
REGION="us-west-2"
EBS_VOLUME_NAME="ebs-test"

# Check if the EBS volume exists
EBS_VOLUME_ID=$(
    aws ec2 describe-volumes \
    --filters Name=tag:Name,Values=$EBS_VOLUME_NAME \
    --query 'Volumes[0].VolumeId' \
    --region=$REGION \
    --output text \
    --no-cli-pager
)

if [[ "$EBS_VOLUME_ID" == "None" ]]; then
    echo "EBS volume with name $EBS_VOLUME_NAME does not exist."
else
    # Check for associated snapshots
    SNAPSHOT_ID=$(
        aws ec2 describe-snapshots \
        --filters Name=volume-id,Values=$EBS_VOLUME_ID \
        --query 'Snapshots[0].SnapshotId' \
        --region=$REGION \
        --output text \
        --no-cli-pager
    )

    # Delete the snapshot if it exists
    if [[ "$SNAPSHOT_ID" != "None" ]]; then
        echo "Deleting snapshot: $SNAPSHOT_ID..."
        aws ec2 delete-snapshot \
            --snapshot-id=$SNAPSHOT_ID \
            --region=$REGION \
            --no-cli-pager
        echo "Snapshot $SNAPSHOT_ID deleted successfully."
    else
        echo "No snapshot associated with volume $EBS_VOLUME_ID."
    fi

    # Delete the volume
    echo "Deleting EBS volume: $EBS_VOLUME_ID..."
    aws ec2 delete-volume \
        --volume-id=$EBS_VOLUME_ID \
        --region=$REGION \
        --no-cli-pager
    echo "EBS volume $EBS_VOLUME_ID deleted successfully."
fi
