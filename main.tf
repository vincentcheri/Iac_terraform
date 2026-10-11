
# ============================================================
# 1. TERRAFORM AND PROVIDER CONFIGURATION
# ============================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# ============================================================
# 2. AMI DATA SOURCE
# Find the latest matching Ubuntu 22.04 AMI from Canonical.
# ============================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================
# 3. NETWORKING SERVICES
# VPC, subnets, Internet Gateway, NAT Gateway and routing.
# ============================================================

# VPC
resource "aws_vpc" "test_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "test-vpc"
  }
}

# Public subnet
resource "aws_subnet" "test_pub_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "pub"
  }
}

# Private application subnet
resource "aws_subnet" "test_priv_subnet" {
  vpc_id     = aws_vpc.test_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "priv"
  }
}

# Database subnet
resource "aws_subnet" "test_db_subnet" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "db"
  }
}

# Second database subnet in a different AZ for RDS subnet group coverage.
resource "aws_subnet" "test_db_subnet_az2" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "db-az2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "int_gw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "intgateway"
  }
}

# Public route table: internet traffic goes through the IGW.
resource "aws_route_table" "rt_pub_subnet" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int_gw.id
  }

  tags = {
    Name = "Route Table for Public Subnet"
  }
}

# Private application route table.
# The NAT route is added below after the NAT Gateway resource.
resource "aws_route_table" "rt_priv_subnet" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "Route Table for Private Subnet"
  }
}

# Database route table: no default internet route.
resource "aws_route_table" "rt_db_subnet" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "Route Table for Database Subnet"
  }
}

# Associate the public subnet with its route table.
resource "aws_route_table_association" "rt_pubsub_association" {
  subnet_id      = aws_subnet.test_pub_subnet.id
  route_table_id = aws_route_table.rt_pub_subnet.id
}

# Associate the application subnet with its route table.
resource "aws_route_table_association" "rt_privsub_association" {
  subnet_id      = aws_subnet.test_priv_subnet.id
  route_table_id = aws_route_table.rt_priv_subnet.id
}

# Associate the database subnet with its route table.
resource "aws_route_table_association" "rt_dbsub_association" {
  subnet_id      = aws_subnet.test_db_subnet.id
  route_table_id = aws_route_table.rt_db_subnet.id
}

resource "aws_route_table_association" "rt_dbsub_az2_association" {
  subnet_id      = aws_subnet.test_db_subnet_az2.id
  route_table_id = aws_route_table.rt_db_subnet.id
}

# Elastic IP allocated for the public NAT Gateway.
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway: placed in the public subnet.
resource "aws_nat_gateway" "pub_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.test_pub_subnet.id

  tags = {
    Name = "gw NAT"
  }

  depends_on = [aws_internet_gateway.int_gw]
}

# Route private application-subnet internet traffic through NAT.
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.rt_priv_subnet.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.pub_nat_gw.id
}

# ============================================================
# 4. SECURITY GROUPS
# Create separate security groups for each application tier.
# ============================================================

# Frontend: accept HTTP from internet users.
resource "aws_security_group" "fe_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP access to the frontend"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-sg"
  }
}

# Backend: accept HTTPS traffic from the frontend security group.
resource "aws_security_group" "be_sg" {
  name        = "backend-sg"
  description = "Allow HTTPS traffic from the frontend tier"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    description     = "HTTPS from frontend instances"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.fe_sg.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}

# Database: accept MySQL traffic only from the backend tier.
resource "aws_security_group" "db_sg" {
  name        = "database-sg"
  description = "Allow MySQL traffic from the backend tier"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    description     = "MySQL from backend instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.be_sg.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database-sg"
  }
}

# ============================================================
# 5. COMPUTE SERVICES
# Create the frontend, backend, and database EC2 instances.
# ============================================================

# Frontend EC2 instance in the public subnet.
resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.test_pub_subnet.id
  vpc_security_group_ids      = [aws_security_group.fe_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "frontend-server"
  }
}

# Backend EC2 instance in the private application subnet.
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.test_priv_subnet.id
  vpc_security_group_ids = [aws_security_group.be_sg.id]

  tags = {
    Name = "backend-server"
  }
}

#=========================================#
# db subnet group                         #
#=========================================#

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "db_subnet"
  subnet_ids = [
    aws_subnet.test_db_subnet.id,
    aws_subnet.test_db_subnet_az2.id,
  ]

  tags = {
    Name = "My DB subnet group"
  }
}


resource "aws_db_instance" "database" {
  allocated_storage    = 10
  db_name              = "giwas_db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "giwa"
  password             = "gizogizo"
  parameter_group_name = "default.mysql8.0"
  availability_zone    = aws_subnet.test_db_subnet.availability_zone
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot  = true
}
