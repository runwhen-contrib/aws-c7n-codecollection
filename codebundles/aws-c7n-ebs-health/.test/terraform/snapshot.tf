# Data Source: Check if the volume exists
data "aws_ebs_volumes" "existing_volume" {
  filter {
    name   = "tag:Name"
    values = [var.snapshot_volume_name]
  }
}

# Resource: Create EBS volume only if it doesn't exist
resource "aws_ebs_volume" "snapshot_volume" {
  count             = length(data.aws_ebs_volumes.existing_volume.ids) == 0 ? 1 : 0
  availability_zone = var.availability_zone
  size              = var.snapshot_volume_size

  tags = {
    Name = var.snapshot_volume_name
  }
}


# Resource: Create snapshot if it doesn't exist
resource "aws_ebs_snapshot" "new_snapshot" {

  volume_id = coalesce(
    try(data.aws_ebs_volumes.existing_volume.ids[0], null),
    try(aws_ebs_volume.snapshot_volume[0].id, null)
  )

  description = "Snapshot of volume"
  tags = {
    Name = var.snapshot_volume_name
  }
}

# Resource: Delete volume after snapshot creation
resource "null_resource" "delete_volume" {
  depends_on = [aws_ebs_snapshot.new_snapshot]
  provisioner "local-exec" {
    command = <<EOT
      aws ec2 delete-volume \
      --volume-id ${length(data.aws_ebs_volumes.existing_volume.ids) > 0 ? data.aws_ebs_volumes.existing_volume.ids[0] : aws_ebs_volume.snapshot_volume[0].id} \
      --region ${var.region} \
      --no-cli-pager
    EOT
  }
}

# Outputs
output "snapshot_id" {
  value = aws_ebs_snapshot.new_snapshot.id
}