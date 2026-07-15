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


resource "aws_vpc" "my_custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyProductionVPC"
  }
}


resource "aws_subnet" "my_public_subnet" {
  vpc_id                  = aws_vpc.my_custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "MyPublicSubnet"
  }
}




resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_custom_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}
































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

resource "aws_route_table_association" "my_public_rta" {
  subnet_id      = aws_subnet.my_public_subnet.id
  route_table_id = aws_route_table.my_public_rt.id
}




resource "aws_security_group" "my_web_sg" {
  name        = "allow_web_and_ssh"
  description = "Allow Web and SSH inbound traffic"
  vpc_id      = aws_vpc.my_custom_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
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
    Name = "MyWebSecurityGroup"
  }
}






















# 1. Find the latest Ubuntu Operating System
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # The official ID for Canonical (the makers of Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 2. Build the Server
resource "aws_instance" "my_web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.my_public_subnet.id
  vpc_security_group_ids = [aws_security_group.my_web_sg.id]

  # 3. Run this script when the server boots up
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

# 4. Print the IP address to the screen
output "website_url" {
  value = "http://${aws_instance.my_web_server.public_ip}"
}
