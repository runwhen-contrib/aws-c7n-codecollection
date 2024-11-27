# Check if the EBS volume exists (data source will fail if not found)
data "aws_ebs_volumes" "existing_volumes" {
  filter {
    name   = "tag:Name"
    values = [var.ebs_volume_name]
  }
}

# Create the EBS volume if it doesn't exist
resource "aws_ebs_volume" "ebs_volume" {
  count             = length(data.aws_ebs_volumes.existing_volumes.ids) == 0 ? 1 : 0
  availability_zone = var.availability_zone
  size              = var.ebs_volume_size

  tags = {
    Name = var.ebs_volume_name
  }
}

# Output
output "volume_id" {
  value = aws_ebs_volume.ebs_volume[0].id
}