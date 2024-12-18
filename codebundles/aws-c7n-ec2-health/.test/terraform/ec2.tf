# Provider Configuration
provider "aws" {
  region = "us-west-2"
}

# Local SSH Key Generation
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# EC2 Key Pair
resource "aws_key_pair" "my_ec2_key" {
  key_name   = "my-ec2-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Create a new VPC
resource "aws_vpc" "new_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags = {
    Name = "private-vpc"
  }
}

# Create Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "private-subnet"
  }
}

# Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group
resource "aws_security_group" "instance_sg" {
  name        = "test-instance-sg"
  description = "Security group for test EC2 instance"
  vpc_id      = aws_vpc.new_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test-instance-sg"
  }
}

# EC2 Instance
resource "aws_instance" "test_instance" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  # Use the private subnet
  subnet_id = aws_subnet.private_subnet.id

  # Associate the security group
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # Use the generated key pair
  key_name = aws_key_pair.my_ec2_key.key_name

  tags = {
    Name = "TestInstance"
  }
}

# Outputs
output "instance_id" {
  value = aws_instance.test_instance.id
}

output "instance_private_ip" {
  value = aws_instance.test_instance.private_ip
}

output "vpc_id" {
  value = aws_vpc.new_vpc.id
}

output "subnet_id" {
  value = aws_subnet.private_subnet.id
}

output "private_key" {
  value     = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}

output "public_key" {
  value = tls_private_key.ssh_key.public_key_openssh
}
