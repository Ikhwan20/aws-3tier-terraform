provider "aws" {
    region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "main-vpc"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "main-igw"
    }
}

# Public Subnet
resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "${var.aws_region}a"

    tags = {
        Name = "public-subnet"
    }
}

# Public Subnet
resource "aws_subnet" "public_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = true
    availability_zone = "${var.aws_region}b"

    tags = {
        Name = "public-subnet-2"
    }
}

# Private Subnet
resource "aws_subnet" "private" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "${var.aws_region}a"

    tags = {
        Name = "private-subnet"
    }
}

resource "aws_subnet" "private_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.4.0/24"
    availability_zone = "${var.aws_region}b"

    tags = {
        Name = "private-subnet-2"
    }
}

#Route Table (Public)
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "public-rt"
    }
}

#Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_assoc" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT
resource "aws_eip" "nat_eip" {

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway in public subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-rt"
  }
}

# Associate private subnet with private route table
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group for Web Server (private EC2)
resource "aws_security_group" "web_sg" {
    name = "web-server-sg"
    description = "Allow HTTP from ALB only"
    vpc_id = aws_vpc.main.id

    ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      security_groups = [aws_security_group.alb_sg.id]
    }

    # SSH from Bastion only
    ingress {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [aws_security_group.bastion_sg.id]
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "web-sg"
    }
}

# EC2 Instance (Private Subnet)
resource "aws_instance" "web_server" {
  ami = var.ami_id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private.id
  key_name = aws_key_pair.web.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y apache2 php php-mysql mysql-client unzip
              systemctl enable apache2
              systemctl start apache2

              # Remove default Apache index.html
              rm -f /var/www/html/index.html
              a2enmod php*

              # Simple PHP app to connect to RDS
              cat <<EOPHP > /var/www/html/index.php
              <?php
              \$host = "${aws_db_instance.mydb.address}";
              \$user = "admin";
              \$pass = "Password123!";
              \$dbname = "appdb";

              // Create connection
              \$conn = new mysqli(\$host, \$user, \$pass, \$dbname);

              // Check connection
              if (\$conn->connect_error) {
                  die("Connection failed: " . \$conn->connect_error);
              }
              echo "<h1>Connected successfully to RDS!</h1>";

              // Simple query
              \$sql = "SELECT NOW() as current_time";
              \$result = \$conn->query(\$sql);
              if (\$result->num_rows > 0) {
                  while(\$row = \$result->fetch_assoc()) {
                      echo "Server Time: " . \$row["current_time"];
                  }
              }

              \$conn->close();
              ?>
              EOPHP

              # Restart Apache
              systemctl restart apache2
              EOF

  tags = {
    Name = "web-server"
  }
}

# Security Group for ALB (Public)
resource "aws_security_group" "alb_sg" {
  name = "alb-sg"
  description = "Allow HTTP traffic from anywhere"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Target Group (Private EC2 backend)
resource "aws_lb_target_group" "web_tg" {
  name = "web-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id

  health_check {
    path = "/"
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

# Attach EC2 to Target Group
resource "aws_lb_target_group_attachment" "web_tg_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id = aws_instance.web_server.id
  port = 80
} 

# Application Load Balancer (Public Subnet)
resource "aws_lb" "app_lb" {
  name = "app-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = [aws_subnet.public.id, aws_subnet.public_2.id]

  tags = {
    Name = "app-alb"
  }
}

# Listener for ALB
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name = "rds-sg"
  description = "Allow MySQL access from Web Server SG"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.web_sg.id] #only from web server
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}


# RDS Subnet Group (for private subnets)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_2.id]

  tags = {
    Name = "rds-subnet-group"
  }
}

# RDS Instance
resource  "aws_db_instance" "mydb" {
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  db_name = "appdb"
  username = "admin"
  password = "Password123!"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot = true

  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible = false
}

# Security Group for Bastion
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from your IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["180.74.219.19/32"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Bastion Host (Public Subnet)
resource "aws_instance" "bastion" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.web.key_name
  security_groups = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "bastion-host"
  }
}

resource "aws_key_pair" "web" {
  key_name   = "web-key"
  public_key = file("C:/Users/user/.ssh/id_rsa.pub")
}

resource "aws_security_group_rule" "allow_http_from_bastion" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = aws_security_group.web_sg.id
}

