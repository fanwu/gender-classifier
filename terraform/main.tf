# Gender Classification API Infrastructure - Terraform
# Equivalent to cloudformation.yaml

# Data sources for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "gender-classifier-vpc"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "gender-classifier-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "gender-classifier-public-subnet-2"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gender-classifier-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "gender-classifier-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "main" {
  name_prefix = "gender-classifier-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Gender Classifier API"

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "gender-classifier-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "gender-classifier-cluster"

  tags = {
    Name = "gender-classifier-cluster"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/gender-classifier"
  retention_in_days = 7

  tags = {
    Name = "gender-classifier-logs"
  }
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "gender-classifier-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "gender-classifier-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "gender-classifier-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "gender-classifier-task-role"
  }
}

resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "s3-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.model_bucket}",
          "arn:aws:s3:::${var.model_bucket}/*"
        ]
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "gender-classifier"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "gender-classifier"
      image = var.image_uri
      
      portMappings = [
        {
          containerPort = 8000
        }
      ]

      environment = [
        {
          name  = "MODEL_BUCKET"
          value = var.model_bucket
        },
        {
          name  = "MODEL_PREFIX"
          value = var.model_prefix
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "gender-classifier-task"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "gender-classifier-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.main.id]
  subnets           = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "gender-classifier-alb"
  }
}

resource "aws_lb_target_group" "main" {
  name        = "gender-classifier-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "gender-classifier-tg"
  }
}

# Self-signed ACM certificate for ALB HTTPS
resource "aws_acm_certificate" "main" {
  private_key      = file("${path.module}/ssl/private-key.pem")
  certificate_body = file("${path.module}/ssl/certificate.pem")

  tags = {
    Name = "gender-classifier-certificate"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "gender-classifier-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.main.id]
    subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "gender-classifier"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.main]

  tags = {
    Name = "gender-classifier-service"
  }
}

# =============================================================================
# UI HOSTING INFRASTRUCTURE
# =============================================================================

# S3 Bucket for UI hosting (existing bucket in us-west-2)
data "aws_s3_bucket" "ui_bucket" {
  provider = aws.bucket_region
  bucket   = var.ui_bucket_name
}

# S3 Bucket Public Access Block (in us-west-2) - Allow public access for website
resource "aws_s3_bucket_public_access_block" "ui_bucket" {
  provider = aws.bucket_region
  bucket   = data.aws_s3_bucket.ui_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket Website Configuration (in us-west-2)
resource "aws_s3_bucket_website_configuration" "ui_bucket" {
  provider = aws.bucket_region
  bucket   = data.aws_s3_bucket.ui_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"  # SPA routing
  }
}

# S3 Bucket Policy for CloudFront and public website access (in us-west-2)
resource "aws_s3_bucket_policy" "ui_bucket" {
  provider = aws.bucket_region
  bucket   = data.aws_s3_bucket.ui_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.ui_oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${data.aws_s3_bucket.ui_bucket.arn}/*"
      },
      {
        Sid       = "AllowPublicWebsiteAccess"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${data.aws_s3_bucket.ui_bucket.arn}/ui/*"
      }
    ]
  })
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "ui_oai" {
  comment = "OAI for ${var.project_name} UI"
}

# CloudFront Distribution for UI
resource "aws_cloudfront_distribution" "ui_distribution" {
  origin {
    domain_name = data.aws_s3_bucket.ui_bucket.bucket_regional_domain_name
    origin_id   = "S3-${data.aws_s3_bucket.ui_bucket.id}"
    origin_path = "/ui"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.ui_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.project_name} UI Distribution"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${data.aws_s3_bucket.ui_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600    # 1 hour
    max_ttl                = 86400   # 24 hours
    compress              = true
  }

  # Cache behavior for static assets (CSS, JS, images)
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${data.aws_s3_bucket.ui_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 31536000  # 1 year
    max_ttl                = 31536000  # 1 year
    compress              = true
  }

  # Custom error response for SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  price_class = var.cloudfront_price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-ui-distribution"
  }
}