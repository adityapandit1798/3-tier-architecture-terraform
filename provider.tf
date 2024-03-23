terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
}
# Configure the AWS Provider
variable "aws_region" { default = "us-west-1" }
provider "aws" {
  region = var.aws_region
}


# Create a VPC
variable "VPC_cidr" { default = "10.0.0.0/16" }
resource "aws_vpc" "VPC_1" {
  cidr_block = var.VPC_cidr
  tags       = { Name = "VPC_1" }
}

#IGW
resource "aws_internet_gateway" "JIOFiber" {
  vpc_id = aws_vpc.VPC_1.id
  tags   = { Name = "JIOFiber" }
}

#create subnet
locals { availability_zones = ["us-west-1c", "us-west-1b"] }
resource "aws_subnet" "public" {
  count             = length(local.availability_zones)
  vpc_id            = aws_vpc.VPC_1.id
  cidr_block        = cidrsubnet(aws_vpc.VPC_1.cidr_block, 8, count.index)
  availability_zone = element(local.availability_zones, count.index)
  tags              = { Name = format("Public-Subnet-%d", count.index + 1) }
}

resource "aws_route_table" "MRT" {
  vpc_id = aws_vpc.VPC_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.JIOFiber.id
  }
  tags = { Name = "MRT" }
}

resource "aws_route_table_association" "route_table_association" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.MRT.id
}


#ec2 server public
locals {
  ami_id        = "ami-0d5ae304a0b933620"
  instance_type = "t2.micro"
}
resource "aws_instance" "web_server" {
  count                  = length(local.availability_zones)
  availability_zone      = element(local.availability_zones, count.index)
  ami                    = local.ami_id
  instance_type          = local.instance_type
  key_name               = "Key_terraform"
  vpc_security_group_ids = [aws_security_group.Ec2_seq_grp.id]
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
    ]
    connection {
      type        = "ssh"
      user        = "root"
      port        = 22
      private_key = file("./Key_terraform.pem")
      host        = aws_instance.web_server[count.index].public_ip
    }
  }

  provisioner "file" {
    source      = "./script.sh"
    destination = "/usr/share/nginx/html/script.sh"
  }

provisioner "remote-exec" {
  inline = [ 
    "chmod +x /usr/share/nginx/html/script.sh" ,
    "/usr/share/nginx/html/script.sh"
   ]
}


  tags = { Name = format("Web-Server-%d", count.index + 1) }
}


