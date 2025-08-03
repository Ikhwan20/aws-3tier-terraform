# AWS 3-Tier Architecture with Terraform
This project provisions a full 3-tier infrastructure on AWS using Terraform.

## Architecture Overview
- **Frontend**: AWS Application Load Balancer (ALB)
- **App Layer**: EC2 Auto Scaling Group (private subnet)
- **Database**: RDS MySQL (private subnet)

## Objectives
- Hands-on AWS infrastructure with best practices
- Secure networking using VPC, subnets and security groups
- Use of Terraform for reproducible infrastructure

## Coming Soon
- CI/CD deployment via Github Actions
- NGINX + sample Flask app auto-install on EC2
