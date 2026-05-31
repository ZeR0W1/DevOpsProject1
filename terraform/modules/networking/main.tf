resource "aws_vpc" "project" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.project.id
  # public subnet split from VPC CIDR to keep envs reproducible.
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_newbits, var.app_subnet_netnum)
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-public-subnet"
    Environment = var.environment
    Tier        = "public"
    ManagedBy   = "Terraform"
  })
}

resource "aws_subnet" "db" {
  vpc_id                  = aws_vpc.project.id
  # Separate DB subnet carved from same VPC with different subnet index.
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_newbits, var.db_subnet_netnum)
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-private-subnet"
    Environment = var.environment
    Tier        = "private"
    ManagedBy   = "Terraform"
  })
}

resource "aws_internet_gateway" "project" {
  vpc_id = aws_vpc.project.id

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project.id
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-public-rt"
    Environment = var.environment
    Tier        = "public"
    ManagedBy   = "Terraform"
  })
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.project.id

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-private-rt"
    Environment = var.environment
    Tier        = "private"
    ManagedBy   = "Terraform"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.db.id
}

resource "aws_security_group" "frontend_http" {
  name        = "${var.name_prefix}-${var.environment}-http"
  description = "http"
  vpc_id      = aws_vpc.project.id

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

resource "aws_security_group" "ssh_admin" {
  # Optional admin SSH SG so ingress can be disabled entirely when not needed.
  count       = var.enable_ssh_ingress ? 1 : 0
  name        = "${var.name_prefix}-${var.environment}-ssh-admin"
  description = "SSH admin access"
  vpc_id      = aws_vpc.project.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
    description = "ssh admin access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-ssh-admin"
    Environment = var.environment
    Role        = "ssh"
    ManagedBy   = "Terraform"
  })
}

resource "aws_security_group" "backend_api" {
  name        = "${var.name_prefix}-${var.environment}-backend-api"
  description = "Backend API access from frontend SG"
  vpc_id      = aws_vpc.project.id

  ingress {
    # Restrict backend API access to frontend SG only.
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
  vpc_id      = aws_vpc.project.id

  ingress {
    # Restrict worker API access to backend SG only.
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
  vpc_id      = aws_vpc.project.id

  ingress {
    # App-path DB access: worker service to PostgreSQL.
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_app.id]
    description     = "worker-app"
  }

  ingress {
    # Admin-path DB access (e.g., pgAdmin) from approved CIDR only.
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