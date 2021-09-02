terraform {
  backend "local" {

  }
  required_version = ">=1.0.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}

provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "plex-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.prefix}-vpc"
  }
}

resource "aws_subnet" "plex-subnet-1" {
  vpc_id            = aws_vpc.plex-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name = "${var.prefix}-subnet-1"
  }
}

resource "aws_route_table" "plex-route-table" {
  vpc_id = aws_vpc.plex-vpc.id

  route = [
    {
      cidr_block                 = "10.0.1.0/24"
      gateway_id                 = aws_internet_gateway.plex-igw.id
      carrier_gateway_id         = ""
      egress_only_gateway_id     = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      nat_gateway_id             = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_peering_connection_id  = ""
      destination_prefix_list_id = ""
      local_gateway_id           = ""
      vpc_endpoint_id            = ""

    }
  ]

  tags = {
    Name = "${var.prefix}-route"
  }

}

resource "aws_internet_gateway" "plex-igw" {
  vpc_id = aws_vpc.plex-vpc.id

  tags = {
    Name = "${var.prefix}-igw"
  }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.plex-subnet-1.id
  route_table_id = aws_route_table.plex-route-table.id
}

resource "aws_security_group" "plex-sg" {
  name        = "plex-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.plex-vpc.id

  ingress = [
    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "ssh"
      cidr_blocks      = [var.my_ip]
      ipv6_cidr_blocks = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    },
    {
      description      = "http"
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      cidr_blocks      = [var.my_ip]
      ipv6_cidr_blocks = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    }
  ]

  egress = [
    {
      description      = "open to all"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    }
  ]

  tags = {
    Name = "${var.prefix}-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

output "aws_ami_id" {
  value = data.aws_ami.ubuntu.id
}

resource "aws_key_pair" "dev-key" {
  key_name   = "dev-key"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "plex-server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.plex-subnet-1.id
  vpc_security_group_ids      = [aws_security_group.plex-sg.id]
  availability_zone           = var.avail_zone
  associate_public_ip_address = true
  key_name                    = aws_key_pair.dev-key.key_name

  user_data = file("script.sh")

  tags = {
    Name = "${var.prefix}-server"
  }
}

output "ec2_public_ip" {
  value = aws_instance.plex-server.public_ip
}