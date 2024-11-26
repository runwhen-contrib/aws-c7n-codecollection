#!/bin/bash

# Exit on error
set -e

# Configuration
REGION="us-west-2"
AZ="${REGION}b"
EBS_VOLUME_NAME="ebs-snapshot-test"
EBS_VOLUME_SIZE="1"
MAX_WAIT_TIME=300  # 5 minutes timeout


# Function to check volume status
wait_for_volume_state() {
    local volume_id=$1
    local desired_state=$2
    local start_time=$(date +%s)
    
    while true; do
        local current_state=$(aws ec2 describe-volumes \
            --volume-ids "$volume_id" \
            --region="$REGION" \
            --query 'Volumes[0].State' \
            --output text \
            --no-cli-pager)
        
        if [[ "$current_state" == "$desired_state" ]]; then
            echo "Volume $volume_id is now $desired_state"
            return 0
        fi
        
        if [[ "$current_state" == "error" ]]; then
            echo "Error: Volume $volume_id is in error state"
            return 1
        fi
        
        if (( $(date +%s) - start_time >= MAX_WAIT_TIME )); then
            echo "Timeout waiting for volume $volume_id to become $desired_state"
            return 1
        fi
        
        echo "Waiting for volume $volume_id (current state: $current_state)..."
        sleep 5
    done
}

# Function to wait for snapshot completion
wait_for_snapshot_completion() {
    local snapshot_id=$1
    local start_time=$(date +%s)
    
    while true; do
        local status=$(aws ec2 describe-snapshots \
            --snapshot-ids "$snapshot_id" \
            --region="$REGION" \
            --query 'Snapshots[0].State' \
            --output text \
            --no-cli-pager)
        
        if [[ "$status" == "completed" ]]; then
            echo "Snapshot $snapshot_id completed successfully"
            return 0
        fi
        
        if [[ "$status" == "error" ]]; then
            echo "Error: Snapshot $snapshot_id failed"
            return 1
        fi
        
        if (( $(date +%s) - start_time >= MAX_WAIT_TIME )); then
            echo "Timeout waiting for snapshot $snapshot_id to complete"
            return 1
        fi
        
        echo "Waiting for snapshot $snapshot_id (current state: $status)..."
        sleep 10
    done
}

# Main execution
main() {

    # Check if the EBS volume exists
    echo "Checking for existing volume with name $EBS_VOLUME_NAME..."
    EBS_VOLUME_EXISTS=$(
        aws ec2 describe-volumes \
        --filters Name=tag:Name,Values="$EBS_VOLUME_NAME" \
        --region="$REGION" \
        --query 'Volumes[0].VolumeId' \
        --output text \
        --no-cli-pager
    )

    if [[ "$EBS_VOLUME_EXISTS" == "None" ]]; then
        echo "Creating new EBS volume $EBS_VOLUME_NAME..."
        EBS_VOLUME_ID=$(
            aws ec2 create-volume \
            --region="$REGION" \
            --availability-zone="$AZ" \
            --size="$EBS_VOLUME_SIZE" \
            --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$EBS_VOLUME_NAME}]" \
            --query 'VolumeId' \
            --output text \
            --no-cli-pager
        )
        echo "Created EBS volume: $EBS_VOLUME_ID"
        
        # Wait for volume to become available
        wait_for_volume_state "$EBS_VOLUME_ID" "available" || exit 1
    else
        EBS_VOLUME_ID=$EBS_VOLUME_EXISTS
        echo "Using existing EBS volume: $EBS_VOLUME_ID"
    fi

    # Check for existing snapshot
    echo "Checking for existing snapshot..."
    SNAPSHOT_ID=$(
        aws ec2 describe-snapshots \
        --filters Name=tag:Name,Values="$EBS_VOLUME_NAME" \
        --region="$REGION" \
        --query 'Snapshots[0].SnapshotId' \
        --output text \
        --no-cli-pager
    )

    if [[ "$SNAPSHOT_ID" != "None" ]]; then
        echo "Snapshot $SNAPSHOT_ID already exists"
    else
        echo "Creating new snapshot from volume $EBS_VOLUME_ID..."
        SNAPSHOT_ID=$(
            aws ec2 create-snapshot \
            --region="$REGION" \
            --volume-id="$EBS_VOLUME_ID" \
            --description="Snapshot of volume $EBS_VOLUME_ID" \
            --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$EBS_VOLUME_NAME}]" \
            --query 'SnapshotId' \
            --output text \
            --no-cli-pager
        )
        
        # Wait for snapshot completion
        wait_for_snapshot_completion "$SNAPSHOT_ID" || exit 1
    fi

    # Delete the volume if it exists
    if [[ -n "$EBS_VOLUME_ID" && "$EBS_VOLUME_ID" != "None" ]]; then
        echo "Deleting EBS volume: $EBS_VOLUME_ID..."
        aws ec2 delete-volume \
            --volume-id="$EBS_VOLUME_ID" \
            --region="$REGION" \
            --no-cli-pager
        
        # Wait for volume deletion
        while aws ec2 describe-volumes --volume-ids "$EBS_VOLUME_ID" --region="$REGION" --no-cli-pager &>/dev/null; do
            echo "Waiting for volume deletion..."
            sleep 5
        done
        echo "EBS volume $EBS_VOLUME_ID deleted successfully"
    fi

    echo "Script completed successfully"
    echo "Snapshot ID: $SNAPSHOT_ID"
}

# Execute main function with error handling
main || {
    echo "Script failed with error code $?"
    exit 1
}