# ╔══════════════════════════════════════════════════════════════╗
# ║  ecr.tf — Amazon Elastic Container Registry                ║
# ║                                                            ║
# ║  WHAT IS ECR?                                              ║
# ║  ECR is AWS's private Docker registry (like Docker Hub     ║
# ║  but private & integrated with AWS).                       ║
# ║                                                            ║
# ║  WHY ECR INSTEAD OF DOCKER HUB?                            ║
# ║  - Images stay in the same AWS region → faster pulls       ║
# ║  - IAM-based access (no docker login credentials)          ║
# ║  - EKS nodes can pull from ECR automatically               ║
# ║  - Built-in vulnerability scanning                         ║
# ║                                                            ║
# ║  The image URL will look like:                             ║
# ║  123456789.dkr.ecr.us-east-1.amazonaws.com/net4255:v7     ║
# ╚══════════════════════════════════════════════════════════════╝

# ──────────────────────────────────────────────
# ECR Repository — stores our Flask Docker images
# ──────────────────────────────────────────────
resource "aws_ecr_repository" "app" {
  name = var.project_name

  # MUTABLE means you can push the same tag again (e.g., "latest").
  # IMMUTABLE locks tags forever — safer for production.
  image_tag_mutability = var.ecr_image_tag_mutability

  # Scan images for known vulnerabilities on every push
  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  # Encrypt images at rest using AWS-managed keys
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# ──────────────────────────────────────────────
# Lifecycle Policy — auto-clean old images
# ──────────────────────────────────────────────
# Without this, your ECR repo fills up with old images.
# This rule keeps the last 20 tagged images and deletes
# untagged images after 1 day.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 20 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["webdb-", "webnodb-"]
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
