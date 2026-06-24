locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = count.index == 0 ? "us-east-1a" : "us-east-1b"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-1${count.index == 0 ? "a" : "b"}"
  })
}

resource "aws_subnet" "frontend_private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1${count.index + 1}.0/24"
  availability_zone = count.index == 0 ? "us-east-1a" : "us-east-1b"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-frontend-1${count.index == 0 ? "a" : "b"}"
  })
}

resource "aws_subnet" "backend_private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2${count.index + 1}.0/24"
  availability_zone = count.index == 0 ? "us-east-1a" : "us-east-1b"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-backend-1${count.index == 0 ? "a" : "b"}"
  })
}

resource "aws_subnet" "database_private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3${count.index + 1}.0/24"
  availability_zone = count.index == 0 ? "us-east-1a" : "us-east-1b"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-1${count.index == 0 ? "a" : "b"}"
  })
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-gw"
  })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rt-private"
  })
}

resource "aws_route_table_association" "frontend_private" {
  count          = 2
  subnet_id      = aws_subnet.frontend_private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "backend_private" {
  count          = 2
  subnet_id      = aws_subnet.backend_private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rt-db"
  })
}

resource "aws_route_table_association" "database" {
  count          = 2
  subnet_id      = aws_subnet.database_private[count.index].id
  route_table_id = aws_route_table.database.id
}
