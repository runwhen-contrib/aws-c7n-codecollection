# Create a Private VPC
resource "aws_vpc" "private_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags = {
    Name = "private-vpc"
  }
}

# Create a Security Group in the Private VPC
resource "aws_security_group" "insecure_sg" {
  name        = "insecure-security-group"
  description = "Extremely permissive security group with wide-open ingress and egress"
  vpc_id      = aws_vpc.private_vpc.id # Use the created VPC ID

  # Ingress rule allowing all traffic from anywhere
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allows access from any IP
  }

  # Egress rule allowing all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allows outbound to any destination
  }

  # Optional: Specific open ports for common services
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH access from anywhere
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # HTTP access from anywhere
  }

  tags = {
    Name = "Insecure Security Group"
    Risk = "High"
  }
}

resource "aws_eip" "unused_eip" {
  tags = {
    Name = "unused-eip"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.private_vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.private_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# Create a route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.private_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

# Create an unused Network Load Balancer (NLB)
resource "aws_lb" "unused_nlb" {
  name               = "unused-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_subnet.id]

  tags = {
    Name = "unused-nlb"
  }
}

# Optional: Output the VPC ID and Security Group ID
output "private_vpc_id" {
  value = aws_vpc.private_vpc.id
}

output "insecure_sg_id" {
  value = aws_security_group.insecure_sg.id
}

output "unused_nlb_arn" {
  value = aws_lb.unused_nlb.arn
}