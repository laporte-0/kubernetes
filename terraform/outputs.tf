# ╔══════════════════════════════════════════════════════════════╗
# ║  outputs.tf — Values exported after terraform apply        ║
# ║                                                            ║
# ║  WHAT ARE OUTPUTS?                                         ║
# ║  After Terraform creates resources, you need to know       ║
# ║  certain values (like the cluster endpoint or ECR URL).    ║
# ║  Outputs print them to the terminal and make them          ║
# ║  available to other Terraform modules or scripts.          ║
# ║                                                            ║
# ║  Usage: terraform output ecr_repository_url                ║
# ╚══════════════════════════════════════════════════════════════╝

# ──────────────────────────────────────────────
# AWS Account Info
# ──────────────────────────────────────────────
output "aws_account_id" {
  description = "The AWS account ID (used in ECR URLs)"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "The AWS region where resources were created"
  value       = data.aws_region.current.name
}

# ──────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────
output "vpc_id" {
  description = "The VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (where nodes run)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of public subnets (where ALB lives)"
  value       = aws_subnet.public[*].id
}

# ──────────────────────────────────────────────
# EKS Cluster
# ──────────────────────────────────────────────
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "The URL of the Kubernetes API server"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster (used by kubectl)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC provider (used for IRSA)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# ──────────────────────────────────────────────
# ECR
# ──────────────────────────────────────────────
output "ecr_repository_url" {
  description = <<-EOT
    The full ECR image URL. Use it to tag and push:
      docker tag myapp:v7 <this-url>:webdb-v7
      docker push <this-url>:webdb-v7
  EOT
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_registry_id" {
  description = "The AWS account ID that owns the ECR registry"
  value       = aws_ecr_repository.app.registry_id
}

# ──────────────────────────────────────────────
# IAM Roles (for Helm chart annotations)
# ──────────────────────────────────────────────
output "lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller ServiceAccount"
  value       = aws_iam_role.lb_controller.arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI driver ServiceAccount"
  value       = aws_iam_role.ebs_csi.arn
}

# ──────────────────────────────────────────────
# Quick-start commands (printed after apply)
# ──────────────────────────────────────────────
output "configure_kubectl" {
  description = "Run this command to configure kubectl for the new cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "ecr_login_command" {
  description = "Run this command to authenticate Docker to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}"
}
