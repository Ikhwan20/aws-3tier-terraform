variable "aws_region" {
    default = "ap-southeast-1"
    description = "AWS region to deploy"
}

variable "ami_id" {
    default = "ami-08e7e250e7e3deb9b"
}

variable "db_username" {
  default     = "admin"
  description = "RDS admin username"
}

variable "db_password" {
  description = "RDS admin password"
  sensitive   = true
}