output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.mydb.address
}
