# ╔══════════════════════════════════════════════════════════════╗
# ║  variables.tf — Configurable inputs for the AWS platform   ║
# ║                                                            ║
# ║  Every resource references these variables so you can      ║
# ║  change region, cluster size, instance types, etc.         ║
# ║  without editing resource definitions directly.            ║
# ╚══════════════════════════════════════════════════════════════╝

# ──────────────────────────────────────────────
# General
# ──────────────────────────────────────────────
variable "project_name" {
  description = "Name prefix for all AWS resources (keeps everything identifiable)"
  type        = string
  default     = "net4255"
}

variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment label (dev, staging, prod) — used in tags and naming"
  type        = string
  default     = "dev"
}

# ──────────────────────────────────────────────
# Networking (VPC)
# ──────────────────────────────────────────────
variable "vpc_cidr" {
  description = <<-EOT
    The IP address range for the entire VPC.
    /16 gives us 65,536 IPs — plenty of room to carve subnets.
  EOT
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = <<-EOT
    List of AZs to spread subnets across.
    EKS requires at least 2 AZs for high availability.
  EOT
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = <<-EOT
    CIDR blocks for public subnets (one per AZ).
    Public subnets host the NAT Gateway and load balancers.
  EOT
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = <<-EOT
    CIDR blocks for private subnets (one per AZ).
    Worker nodes and pods run here — no direct internet access.
    Outbound traffic goes through the NAT Gateway.
  EOT
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# ──────────────────────────────────────────────
# EKS Cluster
# ──────────────────────────────────────────────
variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_types" {
  description = <<-EOT
    EC2 instance type(s) for the EKS managed node group.
    t3.medium = 2 vCPU, 4 GiB RAM — good for dev workloads.
  EOT
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min" {
  description = "Minimum number of worker nodes (autoscaling lower bound)"
  type        = number
  default     = 1
}

variable "eks_node_max" {
  description = "Maximum number of worker nodes (autoscaling upper bound)"
  type        = number
  default     = 4
}

variable "eks_node_disk_size" {
  description = "Disk size in GiB for each worker node"
  type        = number
  default     = 20
}

# ──────────────────────────────────────────────
# ECR (Container Registry)
# ──────────────────────────────────────────────
variable "ecr_image_tag_mutability" {
  description = <<-EOT
    MUTABLE  = you can overwrite tags (e.g., push "latest" again).
    IMMUTABLE = once a tag is pushed, it's locked (safer for prod).
  EOT
  type        = string
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  description = "Enable automatic vulnerability scanning when images are pushed"
  type        = bool
  default     = true
}
