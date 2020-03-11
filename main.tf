# -----------------------------------
# Getting Started
# -----------------------------------
# This is introduction script for terraform with basic commands.
# Account AWS required
# Configuration AWS CLI required
# AWS profile configuration required
# Instalation Terraform CLI required
# S3 for backend required
# $ terraform init / plan / apply / destroy


#-------------------------
# Provider
#--------------------------
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
# Your VPC comes with a default security group.
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
# Subnet 
#-------------------------
#  Subnet_1 251 IP 2a
#-------------------------
resource "aws_subnet" "akrawiec_subnet_1" {
  vpc_id     = aws_vpc.akrawiec_vpc.id
  cidr_block = "10.0.0.0/24"
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

  tags = {
    Name = "akrawiec_subnet_2"
     Owner = "akrawiec"
  }
}

#-------------------------
# EC2
#-------------------------	
# Create EC2 instance with AMI Image (public image)
# Amazon Machine Images (AMI) EC2
#-------------------------

resource "aws_instance" "example" {
  ami           = var.amis[var.region]
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.akrawiec_subnet_2.id
  tags = {
    Name = "akrawiec-EC2"
    Owner = "akrawiec"
  }
  
   provisioner "local-exec" {
    command = "echo ${aws_instance.example.public_ip} > ip_address.txt"
  }
}


# -------------- Variables -------------------
# to comunicate with module (including this root module)
# variables here or in variables.tf  ,
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
output "server_out" {
  value = "Module output: ${module.call_server.server_outputs}"
}





