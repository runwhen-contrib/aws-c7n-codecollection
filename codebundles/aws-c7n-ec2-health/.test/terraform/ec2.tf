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

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "public-subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.new_vpc.id

  tags = {
    Name = "example-igw"
  }
}

# Add a Route to the Internet Gateway
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate the Route Table with Public Subnets
resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create a Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.new_vpc.id

  tags = {
    Name = "public-route-table"
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

resource "aws_launch_template" "example" {
  name          = "example-launch-template"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_ec2_key.key_name
  network_interfaces {
    subnet_id = aws_subnet.private_subnet.id
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "example-asg-instance"
    }
  }
}

# Create an Auto Scaling Group
resource "aws_autoscaling_group" "example" {
  name                = "example-asg"
  max_size            = 1
  min_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.private_subnet.id]
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "example-asg-instance"
    propagate_at_launch = true
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
