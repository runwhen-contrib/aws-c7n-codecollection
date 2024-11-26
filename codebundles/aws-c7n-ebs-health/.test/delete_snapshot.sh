#!/bin/bash

# Exit on error
set -e

# Configuration
REGION="us-west-2"
EBS_VOLUME_NAME="ebs-snapshot-test"


# Main function
delete_snapshot() {

    echo "Checking for existing snapshot with name $EBS_VOLUME_NAME..."
    SNAPSHOT_ID=$(
        aws ec2 describe-snapshots \
        --filters Name=tag:Name,Values="$EBS_VOLUME_NAME" \
        --region="$REGION" \
        --query 'Snapshots[0].SnapshotId' \
        --output text \
        --no-cli-pager
    )

    if [[ "$SNAPSHOT_ID" == "None" ]]; then
        echo "No snapshot found with the name $EBS_VOLUME_NAME. Exiting."
        exit 0
    fi

    echo "Found snapshot: $SNAPSHOT_ID. Deleting..."
    aws ec2 delete-snapshot --snapshot-id "$SNAPSHOT_ID" --region "$REGION" --no-cli-pager
    echo "Snapshot $SNAPSHOT_ID deleted successfully."
}

# Execute the function
delete_snapshot
