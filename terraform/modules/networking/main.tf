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
  count = length(var.public_subnet_netnums)

  vpc_id                  = aws_vpc.project.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_newbits, var.public_subnet_netnums[count.index])
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name                     = "${var.name_prefix}-${var.environment}-public-${count.index + 1}"
    Environment              = var.environment
    Tier                     = "public"
    ManagedBy                = "Terraform"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_netnums)

  vpc_id                  = aws_vpc.project.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_newbits, var.private_subnet_netnums[count.index])
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name                              = "${var.name_prefix}-${var.environment}-private-${count.index + 1}"
    Environment                       = var.environment
    Tier                              = "private"
    ManagedBy                         = "Terraform"
    "kubernetes.io/role/internal-elb" = "1"
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

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-nat-eip"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_nat_gateway" "project" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-nat"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  depends_on = [aws_internet_gateway.project]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.project.id

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-private-rt"
    Environment = var.environment
    Tier        = "private"
    ManagedBy   = "Terraform"
  })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.project[0].id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-${var.environment}-db"
  description = "Project database access group"
  vpc_id      = aws_vpc.project.id

  ingress {
    # Admin-path DB access (e.g., pgAdmin) from approved CIDR only.
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
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