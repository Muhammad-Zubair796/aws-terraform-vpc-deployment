# ==============================================================================
# AWS INFRASTRUCTURE AS CODE - PORTFOLIO PROJECT
# Description: Provisions a custom VPC, public subnet, security group,
#              and an Nginx web server on an Ubuntu EC2 instance.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. TERRAFORM & PROVIDER CONFIGURATION
# ------------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ------------------------------------------------------------------------------
# 2. NETWORKING (VPC, Subnet, Gateway, Routing)
# ------------------------------------------------------------------------------
# Create a custom Virtual Private Cloud (VPC)
resource "aws_vpc" "my_custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyProductionVPC"
  }
}

# Create a Public Subnet within the VPC
resource "aws_subnet" "my_public_subnet" {
  vpc_id                  = aws_vpc.my_custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "MyPublicSubnet"
  }
}

# Create an Internet Gateway to allow public internet access
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_custom_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}

# Create a Route Table to direct traffic to the Internet Gateway
resource "aws_route_table" "my_public_rt" {
  vpc_id = aws_vpc.my_custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "MyPublicRouteTable"
  }
}

# Associate the Route Table with the Public Subnet
resource "aws_route_table_association" "my_public_rta" {
  subnet_id      = aws_subnet.my_public_subnet.id
  route_table_id = aws_route_table.my_public_rt.id
}

# ------------------------------------------------------------------------------
# 3. SECURITY
# ------------------------------------------------------------------------------
# Create a Security Group (Firewall) for the Web Server
resource "aws_security_group" "my_web_sg" {
  name        = "allow_web_and_ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = aws_vpc.my_custom_vpc.id

  # Allow inbound SSH (Port 22)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound HTTP (Port 80)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic to the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MyWebSecurityGroup"
  }
}

# ------------------------------------------------------------------------------
# 4. COMPUTE (EC2 Instance & Web Server Setup)
# ------------------------------------------------------------------------------
# Fetch the latest Ubuntu 22.04 AMI (Amazon Machine Image)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Official Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Provision the EC2 Instance
resource "aws_instance" "my_web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.my_public_subnet.id
  vpc_security_group_ids = [aws_security_group.my_web_sg.id]

  # Bash script to install and configure Nginx on boot
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Hello from my custom Terraform VPC!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "MyWebServer"
  }
}

# ------------------------------------------------------------------------------
# 5. OUTPUTS
# ------------------------------------------------------------------------------
# Display the public URL of the web server after deployment
output "website_url" {
  description = "The public HTTP URL of the newly created web server"
  value       = "http://${aws_instance.my_web_server.public_ip}"
}
