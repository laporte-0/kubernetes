# ╔══════════════════════════════════════════════════════════════╗
# ║  vpc.tf — Virtual Private Cloud (your isolated network)    ║
# ║                                                            ║
# ║  ARCHITECTURE:                                             ║
# ║  - 1 VPC with a /16 CIDR (65k IPs)                        ║
# ║  - 2 Public subnets  (for ALB + NAT Gateway)              ║
# ║  - 2 Private subnets (for EKS worker nodes)               ║
# ║  - Internet Gateway  (public internet access)             ║
# ║  - NAT Gateway       (outbound-only for private subnets)  ║
# ║                                                            ║
# ║  WHY PUBLIC + PRIVATE?                                     ║
# ║  Worker nodes don't need a public IP. They sit in private  ║
# ║  subnets and reach the internet through the NAT Gateway    ║
# ║  (e.g., to pull Docker images). The load balancer sits     ║
# ║  in public subnets because it needs to receive traffic.    ║
# ╚══════════════════════════════════════════════════════════════╝

# ──────────────────────────────────────────────
# VPC — The top-level network container
# ──────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # DNS support is required for EKS to work properly.
  # It lets pods resolve service names (e.g., "mongodb" → IP).
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ──────────────────────────────────────────────
# Internet Gateway — connects the VPC to the internet
# ──────────────────────────────────────────────
# Without this, nothing in the VPC can reach the outside world.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ──────────────────────────────────────────────
# Public Subnets — one per AZ
# ──────────────────────────────────────────────
# Public = instances here CAN get a public IP.
# The ALB and NAT Gateway live here.
#
# The special tags tell AWS:
# - "kubernetes.io/role/elb" = "put ALB here"
# - "kubernetes.io/cluster/<name>" = "this subnet belongs to my cluster"
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Instances launched here automatically get a public IP
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    # These tags are REQUIRED for the AWS Load Balancer Controller
    # to auto-discover which subnets to place the ALB in.
    "kubernetes.io/role/elb"                              = "1"
    "kubernetes.io/cluster/${var.project_name}-cluster"   = "shared"
  }
}

# ──────────────────────────────────────────────
# Private Subnets — one per AZ
# ──────────────────────────────────────────────
# Private = no public IP, no direct internet access.
# EKS worker nodes run here for security.
#
# "kubernetes.io/role/internal-elb" tells AWS:
# "if I create an internal load balancer, put it here"
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"                     = "1"
    "kubernetes.io/cluster/${var.project_name}-cluster"   = "shared"
  }
}

# ──────────────────────────────────────────────
# Elastic IP — a static public IP for the NAT Gateway
# ──────────────────────────────────────────────
# NAT Gateways need a fixed IP so outbound traffic from
# private subnets always comes from the same address.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# ──────────────────────────────────────────────
# NAT Gateway — outbound internet for private subnets
# ──────────────────────────────────────────────
# Placed in a PUBLIC subnet. Private subnets route outbound
# traffic through this. Workers can pull images, but nobody
# on the internet can reach them directly.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Lives in the first public subnet

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# ──────────────────────────────────────────────
# Route Tables — traffic rules
# ──────────────────────────────────────────────

# PUBLIC route table: "send internet traffic to the Internet Gateway"
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"          # All internet traffic
    gateway_id = aws_internet_gateway.main.id  # → goes to IGW
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# PRIVATE route table: "send internet traffic to the NAT Gateway"
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"          # All internet traffic
    nat_gateway_id = aws_nat_gateway.main.id   # → goes to NAT GW
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# ──────────────────────────────────────────────
# Route Table Associations — link subnets to their route tables
# ──────────────────────────────────────────────
# "This subnet uses THIS set of routing rules"

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
