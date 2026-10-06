resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "databricks-${var.environment}-vpc"
    Environment = var.environment
  }
}

# --- Private subnets (where Databricks clusters reside) ---

resource "aws_subnet" "private" {
  for_each = { for idx, az in var.availability_zones : az => var.private_subnet_cidrs[idx] }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name        = "databricks-${var.environment}-private-${each.key}"
    Environment = var.environment
  }
}

# --- Internet Gateway and public subnet (only exist with NAT enabled) ---

resource "aws_internet_gateway" "this" {
  count  = var.enable_nat ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "databricks-${var.environment}-igw"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count = var.enable_nat ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "databricks-${var.environment}-public"
    Environment = var.environment
  }
}

resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "databricks-${var.environment}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "databricks-${var.environment}-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.this]
}

# --- Route tables ---

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[0].id
    }
  }

  tags = {
    Name        = "databricks-${var.environment}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "public" {
  count  = var.enable_nat ? 1 : 0
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = {
    Name        = "databricks-${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count = var.enable_nat ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

# --- Security Group (standard required by Databricks) ---

resource "aws_security_group" "databricks" {
  name        = "databricks-${var.environment}-sg"
  description = "Security group for the Databricks workspace"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name        = "databricks-${var.environment}-sg"
    Environment = var.environment
  }
}

# Databricks requires all traffic between members of the security group to be allowed
resource "aws_vpc_security_group_ingress_rule" "self_all" {
  security_group_id            = aws_security_group.databricks.id
  referenced_security_group_id = aws_security_group.databricks.id
  ip_protocol                  = "-1"
  description                  = "Traffic between Databricks cluster nodes"
}

resource "aws_vpc_security_group_egress_rule" "self_all" {
  security_group_id            = aws_security_group.databricks.id
  referenced_security_group_id = aws_security_group.databricks.id
  ip_protocol                  = "-1"
  description                  = "Traffic between Databricks cluster nodes"
}

# HTTPS outbound to the Databricks control plane, S3, PyPI, etc.
resource "aws_vpc_security_group_egress_rule" "https_out" {
  security_group_id = aws_security_group.databricks.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "(HTTPS outbound to control plane, S3, PyPI)"
}

# Legacy Hive metastore
resource "aws_vpc_security_group_egress_rule" "hive_metastore_legacy" {
  security_group_id = aws_security_group.databricks.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
  description       = "Legacy Hive metastore"
}

# Internal calls to the control plane API (8443, 8445), Unity Catalog logging and lineage (8444),
# and ports reserved for future use (8446-8451)
resource "aws_vpc_security_group_egress_rule" "control_plane_internal" {
  security_group_id = aws_security_group.databricks.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8443
  to_port           = 8451
  description       = "Databricks control plane API, UC logging and lineage, reserved ports"
}