# =====================================================================
# BLOCK 1: TERRAFORM ENGINE & REGION SELECTION
# =====================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Lock version range to prevent syntax changes
    }
  }
  required_version = ">= 1.5.0" # Prevents local team version corruption
}

provider "aws" {
  region = var.aws_region # Pulls "ap-south-1" straight from terraform.tfvars
}

# =====================================================================
# BLOCK 2: THE VPC NETWORK CONTAINER
# =====================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr # Pulls "10.0.0.0/16" from tfvars
  enable_dns_hostnames = true         # Gives instances public DNS names (e.g. ://amazonaws.com)
  enable_dns_support   = true         # Turns on the AWS internal DNS resolution server

  tags = {
    Name = "${var.tags_name}-vpc"
  }
}

# =====================================================================
# BLOCK 3: THE SUBNET SLICES (Public & Private)
# =====================================================================

# Subnet A: The Public Entry Point
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id          # Links this subnet to the VPC we created above
  cidr_block              = var.public_subnet_cidr   # Pulls "10.0.1.0/24" from tfvars
  availability_zone       = "${var.aws_region}a"     # Deploys into Mumbai Zone A (ap-south-1a)
  map_public_ip_on_launch = true                     # Automatically gives instances a public IP

  tags = {
    Name = "${var.tags_name}-public-subnet"
  }
}

# Subnet B: The Isolated Private Layer
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id          # Links this subnet to the exact same VPC
  cidr_block              = var.private_subnet_cidr  # Pulls "10.0.2.0/24" from tfvars
  availability_zone       = "${var.aws_region}a"     # Keeps it in the same Zone A to avoid cross-AZ latency
  map_public_ip_on_launch = false                    # Guarantees instances remain completely hidden

  tags = {
    Name = "${var.tags_name}-private-subnet"
  }
}
  
# =====================================================================
# BLOCK 4: THE EDGE GATEWAYS (Internet & NAT)
# =====================================================================

# 1. The Internet Gateway (The Front Door for the VPC)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id # Hooks the door directly onto your VPC container

  tags = {
    Name = "${var.tags_name}-igw"
  }
}

# 2. The Static Public IP (Elastic IP) for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain     = "vpc"             # Allocates this static public IP inside the VPC network layer
  depends_on = [aws_internet_gateway.igw] # Ensures the IGW is active before requesting an IP

  tags = {
    Name = "${var.tags_name}-nat-eip"
  }
}

# 3. The NAT Gateway (The One-Way Mirror)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id      # Binds the static Elastic IP to this gateway appliance
  subnet_id     = aws_subnet.public.id     # Places the appliance physically inside the Public Subnet
  depends_on    = [aws_internet_gateway.igw] # Prevents creation loops by waiting for internet pathways

  tags = {
    Name = "${var.tags_name}-nat"
  }
}
# =====================================================================
# BLOCK 5: ROUTE TABLES & ASSOCIATIONS (The Highway Maps)
# =====================================================================

# 1. Public Highway Map
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"               # Represents absolutely any address on the internet
    gateway_id = aws_internet_gateway.igw.id # Directs internet traffic straight to the front door
  }

  tags = {
    Name = "${var.tags_name}-public-rt"
  }
}

# Link Public Map to Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# 2. Private Highway Map
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"           # Represents absolutely any address on the internet
    nat_gateway_id = aws_nat_gateway.nat.id  # Directs internet traffic to your one-way NAT window
  }

  tags = {
    Name = "${var.tags_name}-private-rt"
  }
}

# Link Private Map to Private Subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

# =====================================================================
# BLOCK 6: SECURITY GROUPS (The Firewalls)
# =====================================================================

# 1. Front-Facing Public Firewall (Bastion SG)
resource "aws_security_group" "public_sg" {
  name        = "learning-public-sg"
  description = "Allows SSH access from the internet"
  vpc_id      = aws_vpc.main.id

  # Inbound Rule: Allow SSH from anywhere on Earth
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Outbound Rule: Allow this server to talk to anything outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # "-1" means all protocols (HTTP, HTTPS, SSH, etc.)
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tags_name}-public-sg"
  }
}

# 2. Hidden Private Firewall (App/DB SG)
resource "aws_security_group" "private_sg" {
  name        = "learning-private-sg"
  description = "Strictly limits inbound access to the public bastion host only"
  vpc_id      = aws_vpc.main.id

  # Inbound Rule: ONLY accept SSH if it comes from a server wearing the public_sg
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id] # Chaining firewalls together
  }

  # Outbound Rule: Allow this server to talk to the internet (via NAT Gateway)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tags_name}-private-sg"
  }
}

# =====================================================================
# BLOCK 7: AUTOMATED SSH KEY GENERATION
# =====================================================================
resource "tls_private_key" "generated_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "learning-bastion-key"
  public_key = tls_private_key.generated_key.public_key_openssh
}

# Automatically saves your private key to your local folder so you can log in
resource "local_file" "ssh_key_file" {
  content         = tls_private_key.generated_key.private_key_pem
  filename        = "${path.module}/learning-key.pem"
  file_permission = "0600" # Sets read-only permissions required by SSH client
}

# =====================================================================
# BLOCK 8: EC2 COMPUTE INSTANCES
# =====================================================================

# 1. Public Instance (Bastion Host / Jump Box)
resource "aws_instance" "public_bastion" {
  ami                    = var.ami_id        # Pulls "ami-0b1ed96948adabcd9" from tfvars
  instance_type          = var.instance_type # Pulls "t3.micro" from tfvars
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = aws_key_pair.deployer_key.key_name

  tags = {
    Name = "${var.tags_name}-public-ec2"
  }
}

# 2. Private Instance (App / Database Server)
resource "aws_instance" "private_app" {
  ami                    = var.ami_id        # Pulls same image ID from tfvars
  instance_type          = var.instance_type # Pulls "t3.micro" from tfvars
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.deployer_key.key_name

  tags = {
    Name = "${var.tags_name}-private-ec2"
  }
}

# =====================================================================
# BLOCK 9: TERMINAL OUTPUTS
# =====================================================================
output "bastion_public_ip" {
  value       = aws_instance.public_bastion.public_ip
  description = "The public IP of your gateway server"
}

output "private_instance_internal_ip" {
  value       = aws_instance.private_app.private_ip
  description = "The internal IP of your hidden server"
}
