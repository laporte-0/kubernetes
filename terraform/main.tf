# ╔══════════════════════════════════════════════════════════════╗
# ║  main.tf — Terraform configuration & provider setup        ║
# ║                                                            ║
# ║  WHAT IS A PROVIDER?                                       ║
# ║  A provider is a plugin that lets Terraform talk to an     ║
# ║  API. The "aws" provider knows how to create EC2, EKS,     ║
# ║  VPC, etc. We tell it which region to target.              ║
# ║                                                            ║
# ║  WHAT IS A BACKEND?                                        ║
# ║  Terraform tracks the real-world state of your infra in    ║
# ║  a "state file". The backend defines WHERE that file is    ║
# ║  stored. We start local, but in a team you'd use S3.      ║
# ╚══════════════════════════════════════════════════════════════╝

# ──────────────────────────────────────────────
# Required providers — which plugins Terraform needs
# ──────────────────────────────────────────────
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # The AWS provider — manages all AWS resources
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Any 5.x version (stable, widely used)
    }

    # The TLS provider — we'll use it to get the EKS OIDC thumbprint
    # (needed for IAM Roles for Service Accounts)
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # ── State backend ────────────────────────────
  # Local backend: state stored in terraform.tfstate on your machine.
  # For production, you'd switch this to S3 + DynamoDB for locking:
  #
  #   backend "s3" {
  #     bucket         = "net4255-terraform-state"
  #     key            = "eks/terraform.tfstate"
  #     region         = "us-east-1"
  #     dynamodb_table = "terraform-lock"
  #     encrypt        = true
  #   }
  #
  backend "local" {
    path = "terraform.tfstate"
  }
}

# ──────────────────────────────────────────────
# Provider configuration — connect to AWS
# ──────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  # Tags applied to EVERY resource Terraform creates.
  # Helps with cost tracking and identifying what belongs to this project.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ──────────────────────────────────────────────
# Data sources — read existing AWS info
# ──────────────────────────────────────────────

# Fetch the current AWS account ID and region
# (used later in ECR URLs and IAM policies)
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
