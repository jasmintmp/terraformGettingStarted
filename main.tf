# -----------------------------------
# Getting Started
# -----------------------------------
# This is introduction script for terraform with basic commands.
# Account AWS required
# Configuration AWS CLI required
# AWS profile configuration required
# Instalation Terraform CLI required
# S3 for backend required
# $ terraform init / plan / apply

#-------------------------
# Provider
#-------------------------
provider "aws" {
  profile = "default"
  region  = var.region
}

#-------------------------
# Backend Configuration
#-------------------------
# First S3 must be created from panel, 
# Configuration is moved to remote state [init];  destroy:  remove .terraform/ 
# The Terraform state is written to the key
# It's used to read state from one place - hence script can be run undependetly from different localizations.
#-------------------------
terraform {
  backend "s3" {
    bucket = "akrawiec-terraform-state"
    key    = "backend/key"
    region  = "us-west-2"
  }
}

# #-------------------------
#  S3 for test upload
# #-------------------------
# New resource for the S3 bucket our application will use.
# NOTE: S3 bucket names must be unique across _all_ AWS accounts  
# "my_bucket": local name can be refered from elsewhere in the same module.
# #------------------------- 
resource "aws_s3_bucket" "my_bucket" {  
  region  = var.region
  bucket = "akrawiec-terraform-upload"
  acl    = "private"
  force_destroy = true
  
}

#-------------------------
# Upload to S3
#-------------------------
#-- after my_bucket.id has created - referer to .id
#-------------------------
resource "aws_s3_bucket_object" "file_upload" {
  bucket = aws_s3_bucket.my_bucket.id
  key    = "upload_me.txt"
  source = "${path.module}/upload_me.txt"
  etag   = filemd5("${path.module}/upload_me.txt")
}

#-------------------------
# VPC
#-------------------------
# Your VPC comes with a default Security Group, NACL, Route Table unles it'll be provided.
# Creating a VPC with an Internet Gateway
#-------------------------
resource "aws_vpc" "akrawiec_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "akrawiec_vpc"
    Owner = "akrawiec"
  }
}

#------------------------- 
# Creating a Subnet 
#-------------------------
#  Subnet_1 251 IP 2a
#-------------------------
resource "aws_subnet" "akrawiec_subnet_1" {
  vpc_id     = aws_vpc.akrawiec_vpc.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2a"
  tags = {
    Name = "akrawiec_subnet_1"
     Owner = "akrawiec"
  }
}
#-------------------------
#  Subnet_2 251 IP 2c
#-------------------------
resource "aws_subnet" "akrawiec_subnet_2" {
  vpc_id     = aws_vpc.akrawiec_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2c"
 map_public_ip_on_launch = true
  tags = {
    Name = "akrawiec_subnet_2"
     Owner = "akrawiec"
  }
}

# Create the Internet Access 
# -------------- Gateway ----------------------
# Internet Gateway  
# 1 Creating and Attaching to VPC an Internet Gateway.
# -----------------------------------------
resource "aws_internet_gateway" "akrawiec_vpc_gw" {
  vpc_id = aws_vpc.akrawiec_vpc.id
  tags = {
    Name = "akrawiec_vpc_gw"
    Terraform = "true"
  }
}

# -------------- Route Table ----------------------
# 2 Creating a Custom Route Table 
# There is a route for all IPv4 traffic (0.0.0.0/0) that points to an internet gateway.
# By default, the main route table doesn't contain a route to an internet gateway
# Gateway route table
# -----------------------------------------
resource "aws_route_table" "akrawiec_VPC_route_table" {
  vpc_id = aws_vpc.akrawiec_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.akrawiec_vpc_gw.id
  }
}

#--------------- Subnet Association --------------- 
# 2.1 Add a route to your subnet's
#--------------------------------------------------
# Associate the Route Table with the Subnet1
resource "aws_route_table_association" "akrawiec_VPC_rt_with_sub1" {
  subnet_id      = aws_subnet.akrawiec_subnet_2.id
  route_table_id = aws_route_table.akrawiec_VPC_route_table.id
} 

# Associate the Route Table with the Subnet2
resource "aws_route_table_association" "akrawiec_VPC_rt_with_sub2" {
  subnet_id      = aws_subnet.akrawiec_subnet_1.id
  route_table_id = aws_route_table.akrawiec_VPC_route_table.id
}

# ---------------- Routes -------------------------
# 2.2 Add a Route to Route Table
# Direct internet traffic from VPC to Internet Gateway 
# Route table by default is NOT associated with subnets
# 0.0.0.0/0 => igw..
# --------------------------------------------
resource "aws_route" "akrawiec_VPC_internet_access" {
  route_table_id         = aws_route_table.akrawiec_VPC_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.akrawiec_vpc_gw.id
  depends_on                = [aws_route_table.akrawiec_VPC_route_table]
} 

# SECURITY
# -----------------------------------------
# NACL can be default - all traffic - and associated with subnets by default.
# -----------------------------------------

# -------------- Security Group-------------
# 3 Crate Security Group - subnet's firewall 
# -----------------------------------------
resource "aws_security_group" "akrawiec_sg_pub"{
  name = "akrawiec_sg_pub"
  description = "Allow SSH"
  vpc_id = aws_vpc.akrawiec_vpc.id

  # allow ingress of port 22
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow ingress of port 80
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CREATE SERVER INSTANCE 
# ---------- Key Pair ----------
# Set up in AWS your public key to allow putty access 
# ------------------------------
resource "aws_key_pair" "akrawiec_public_key" {
  key_name   = "AWS_EC2_public"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAmaKu47XByOz8jyRyCv0ags/XGMu5YDacJah0kf3TZniSQ+AzFJ4MtBDYPaxKNgE29dbZNu2skP66H33VfLwLQZtoWb3Wo7Y24orrrk1k4PrE3JL6p5jinYCXBHJscWscnoTiYzEEV0LzxfsfBsn2VTXPcI2aJSj1PHvph7TQNwhmQ8VhG30Ml0mx1kU21ti/Iazuc93l3jlyQUlt+VQGKYZ0ItEeiS6IMwNewCCKdZlSgBVa3LjRvN6tRZJ+6DziRACoKuVnd8C4gGtXzr2/hurqpCJI3NAeSUI9vrC1aD9VxsdsDEtqzey2Y4HdOMuW7HtgDyHjmttY+ydOivz7hQ== rsa-key-20200318"
}

#-------------------------
# EC2
#-------------------------	
# Create EC2 instance with AMI Image (public image)
# Amazon Machine Images (AMI) EC2
#-------------------------
resource "aws_instance" "EC2_instance_1" {
  ami           = var.amis[var.region]
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.akrawiec_subnet_2.id
  vpc_security_group_ids = [aws_security_group.akrawiec_sg_pub.id]
  key_name = aws_key_pair.akrawiec_public_key.key_name
  tags = {
    Name = "akrawiec_EC2_1"
    Owner = "akrawiec"
  }

  #---------- Script fired on launching EC2--- not working
    user_data = "${file("install_apache.sh")}"  
  }


# -------------- Variables -------------------
# to comunicate with module (including this root module)
# good practice to move variables from here to variables.tf  ,
# map : is a dictionary
# using  terraform.tfvars - variables can be automatically filled out.
# ex. region = "us-west-2"
#---------------------------------------------
variable "region" {
  default = "us-west-2"
}

variable "amis" {
  type = map
  default = {
    "us-east-1" = "ami-b374d5a5"
    "us-west-2" = "ami-06d51e91cea0dac8d"
  }
}

#--------- DataSource ------------------------
#  Data from:  provider, HTTP url, ...  , filters
#---------------------------------------------
data "aws_vpcs" "vpc_list" {
}

output "vpc_list" {
  value = "${data.aws_vpcs.vpc_list.ids}"
}

#---------- Modules -----------
# Uses all .tf files from terraformGettingStarted\modules\servers path 
# - as one component, with inputs (variables) and outputs; 
# After changes required $terraform init
#-------------------------------
module "call_server" {
  source = "./modules/servers"  
  server_name = "Jerzy"
  server_created = 1999
}

#---------- OutPut parameters from module 
#-- good practice to move it to output.tf
output "server_out" {
  value = "Module output: ${module.call_server.server_outputs}"
}