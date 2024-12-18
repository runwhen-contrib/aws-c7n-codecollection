# Fetch the VPC
data "aws_vpc" "control_tower_vpc" {
  filter {
    name   = "tag:Name"
    values = ["aws-controltower-VPC"]
  }
}

resource "aws_security_group" "insecure_sg" {
  name        = "insecure-security-group"
  description = "Extremely permissive security group with wide-open ingress and egress"
  vpc_id      = data.aws_vpc.control_tower_vpc.id  # Replace with your VPC ID

  # Ingress rule allowing all traffic from anywhere
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]  # Allows access from any IP
  }

  # Egress rule allowing all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]  # Allows outbound to any destination
  }

  # Optional: Specific open ports for common services
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # SSH access from anywhere
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTP access from anywhere
  }

  tags = {
    Name = "Insecure Security Group"
    Risk = "High"
  }
}

# Optional: Output the security group ID
output "insecure_sg_id" {
  value = aws_security_group.insecure_sg.id
}