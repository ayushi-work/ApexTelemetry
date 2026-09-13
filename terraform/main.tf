terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-b"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2" {
  name   = "${var.project_name}-ec2"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from ALB"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    security_groups = [
      aws_security_group.alb.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_instance" "a" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_a.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl enable docker
              systemctl start docker

              docker run -d \
                --name apex-backend \
                -p 8000:8000 \
                -e INSTANCE_ID=EC2-A \
                -e REDIS_HOST=${aws_elasticache_cluster.redis.cache_nodes[0].address} \
                apex-telemetry-backend
              EOF

  tags = {
    Name     = "${var.project_name}-EC2-A"
    Instance = "A"
  }
}

resource "aws_instance" "b" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_b.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl enable docker
              systemctl start docker

              docker run -d \
                --name apex-backend \
                -p 8000:8000 \
                -e INSTANCE_ID=EC2-B \
                -e REDIS_HOST=${aws_elasticache_cluster.redis.cache_nodes[0].address} \
                apex-telemetry-backend
              EOF

  tags = {
    Name     = "${var.project_name}-EC2-B"
    Instance = "B"
  }
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    port                = "8000"
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-target-group"
  }
}

resource "aws_lb_target_group_attachment" "a" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.a.id
  port             = 8000
}

resource "aws_lb_target_group_attachment" "b" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.b.id
  port             = 8000
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name = "${var.project_name}-redis"

  subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id      = "${var.project_name}-redis"
  engine          = "redis"
  node_type       = "cache.t4g.micro"
  num_cache_nodes = 1
  port            = 6379

  subnet_group_name = aws_elasticache_subnet_group.redis.name

  security_group_ids = [
    aws_security_group.ec2.id
  ]
}