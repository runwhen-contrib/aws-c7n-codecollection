# Create the EBS volume if it doesn't exist
resource "aws_ebs_volume" "ebs_volume" {
  availability_zone = var.availability_zone
  size              = var.ebs_volume_size
  encrypted = false
  tags = {
    Name = var.ebs_volume_name
  }
}

# Output
output "volume_id" {
  value = aws_ebs_volume.ebs_volume.id
}