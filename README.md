# sys-terra

This project uses Terraform as infrastructure as code (IaC) to provision cloud resources from AWS. Instead of manually creating servers, networks, and databases in the AWS console, Terraform defines the required infrastructure(components) in code and then applies it consistently to the target cloud environment.

## Overview

The goal of this project is to demonstrate how Terraform can be used as a tool to pull AWS provider components and building blocks together to create a working cloud architecture. In this setup, AWS acts as the provider and supplies the core infrastructure services, while Terraform manages the configuration and deployment.

The infrastructure includes:
- A Virtual Private Cloud (VPC)
- Public and private subnets
- Internet Gateway and NAT Gateway
- Route tables and subnet associations
- Security groups for frontend, backend, and database layers
- EC2 instances for application tiers
- An RDS MySQL database

## Why Terraform and AWS?

Terraform is a declarative infrastructure tool that lets you describe the desired state of your infrastructure in configuration files. AWS is the cloud provider that offers the actual compute, networking, and database resources.

With Terraform:
- The environment can be created repeatedly and predictably
- Configuration is stored as code and versioned
- Changes can be reviewed before deployment
- Infrastructure can be updated or destroyed in a controlled way
- AWS resources are provisioned using the official AWS provider

## Current Architecture

This project provisions a small 3-tier AWS environment:

- Public tier: frontend EC2 instance exposed to the internet
- Application tier: backend EC2 instance in a private subnet
- Data tier: MySQL database hosted through Amazon RDS

The configuration is defined in Terraform files and uses the HashiCorp AWS provider, which gives access to AWS services such as VPCs, subnets, NAT gateways, EC2 instances, and RDS.

## Provider Configuration

The project configures the AWS provider with the region set to eu-north-1 and declares the required provider version.

Example configuration:

```hcl
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
```

This tells Terraform to use the AWS provider and deploy resources in the selected AWS region.

## Included AWS Resources

The infrastructure defined in this project includes:

- aws_vpc: creates the main virtual network
- aws_subnet: creates public, private, and database subnets
- aws_internet_gateway: allows public internet access
- aws_nat_gateway: enables outbound internet access for private resources
- aws_route_table and aws_route: manage network routing
- aws_security_group: restricts access by service and layer
- aws_instance: deploys frontend and backend compute instances
- aws_db_subnet_group and aws_db_instance: creates the database layer

The RDS subnet group uses database subnets in two available Availability Zones,
as required by Amazon RDS.

## Prerequisites

Before running this project, make sure you have:

- Terraform installed locally
- An AWS account
- AWS CLI configured with valid credentials
- Appropriate permissions to create VPC, EC2, security groups, and RDS resources

## Getting Started

Initialize the Terraform working directory:

```bash
terraform init
```

Review the resources that Terraform will create:

```bash
terraform plan
```

Apply the infrastructure:

```bash
terraform apply
```

To remove the infrastructure:

```bash
terraform destroy
```

## Recommended Workflow

1. Define infrastructure in Terraform configuration files
2. Validate the configuration with Terraform commands
3. Review the execution plan before applying changes
4. Deploy resources to AWS
5. Monitor and update the environment as needed

## Notes

This project is a practical example of using Terraform with the AWS provider to assemble cloud infrastructure components. It helps show how core building blocks from a cloud provider can be composed into a structured environment using code.

## Summary

Terraform is being used here as the orchestration layer, and AWS is the provider delivering the infrastructure services. Together, they allow for the creation of scalable and repeatable cloud infrastructure in an organized, code-driven way.
# Iac_terraform
