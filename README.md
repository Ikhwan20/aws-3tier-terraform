# AWS 3-Tier Architecture with Terraform

This project provisions a **3-tier AWS infrastructure** using Terraform:
- **Application Load Balancer (ALB)** in public subnets
- **EC2 Web Server** in private subnet (Ubuntu + PHP + Apache)
- **RDS MySQL Database** in private subnet
- NAT Gateway for private internet access

## 🖼 Architecture
![Architecture Diagram](aws-3tier-infra.png)

## 🚀 Deployment
### Prerequisites
- AWS account
- Terraform installed
- AWS CLI configured (`aws configure`)

### Steps
```bash
git clone https://github.com/<your-username>/aws-3tier-terraform.git
cd aws-3tier-terraform
terraform init
terraform plan
terraform apply

