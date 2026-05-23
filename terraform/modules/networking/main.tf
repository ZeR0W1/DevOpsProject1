resource "aws_security_group" "frontend_http" {
  name        = "${var.name_prefix}-${var.environment}-http"
  description = "http"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "http access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-http"
    Environment = var.environment
    Role        = "frontend"
    ManagedBy   = "Terraform"
  })
}

resource "aws_security_group" "backend_api" {
  name        = "${var.name_prefix}-${var.environment}-backend-api"
  description = "Backend API access from frontend SG"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_http.id]
    description     = "frontend-to-backend"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-backend-api"
    Environment = var.environment
    Role        = "backend"
    ManagedBy   = "Terraform"
  })
}

resource "aws_security_group" "worker_app" {
  name        = "${var.name_prefix}-${var.environment}-worker-app"
  description = "Worker app access from backend SG"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_api.id]
    description     = "backend-to-worker"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-worker-app"
    Environment = var.environment
    Role        = "worker"
    ManagedBy   = "Terraform"
  })
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-${var.environment}-db"
  description = "Project database access group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_app.id]
    description     = "worker-app"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-db"
    Usage       = "DB"
    Environment = var.environment
    Role        = "database"
    ManagedBy   = "Terraform"
  })
}