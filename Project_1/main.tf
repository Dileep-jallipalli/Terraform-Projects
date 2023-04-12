provider "aws" {
  region     = "us-east-1"
  access_key = "<<paste your access key>>"
  secret_key = "<<paste your secret key>>"
}

#create VPC

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

#create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

#create AWS Route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

variable "subnet_prefix" {
  description = "cidr block for a subnet"
  type        = string
}
#create a Subnet

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = var.subnet_prefix
  availability_zone = "us-east-1a"

  tags = {
    Name = "Prod-subnet"
  }
}

# Associate Subnet with Route Table 

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create a security group to allow port 22, 80 and 443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Create a Network Interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-mic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign an Elastic IP to the Network Interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-mic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw, aws_instance.web-server-instance]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# Create Ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami               = "ami-007855ac798b5175e"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "Terraform"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-mic.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemtcl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-servers"
  }
}
