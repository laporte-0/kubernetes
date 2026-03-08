# ╔══════════════════════════════════════════════════════════════╗
# ║  eks.tf — Amazon EKS cluster and managed node group        ║
# ║                                                            ║
# ║  WHAT IS EKS?                                              ║
# ║  EKS = Elastic Kubernetes Service. AWS manages the         ║
# ║  control plane (API server, etcd, scheduler) for you.      ║
# ║  You only manage the worker nodes that run your pods.      ║
# ║                                                            ║
# ║  WHAT IS A MANAGED NODE GROUP?                             ║
# ║  AWS manages the EC2 instances lifecycle (launch, update,  ║
# ║  terminate). You define the instance type, count, and      ║
# ║  disk size — AWS handles the rest.                         ║
# ╚══════════════════════════════════════════════════════════════╝

# ──────────────────────────────────────────────
# EKS Cluster (Control Plane)
# ──────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  version  = var.eks_cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  # The control plane needs access to subnets to place
  # the ENIs (Elastic Network Interfaces) that the API server
  # uses to communicate with worker nodes.
  vpc_config {
    # Give EKS both public and private subnets.
    # Control plane ENIs go in private subnets.
    # Public subnets are listed so the API endpoint is reachable.
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id
    )

    # Allow access to the Kubernetes API from the internet.
    # In production, you might restrict this to your office IP.
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # Enable control plane logging to CloudWatch.
  # Useful for debugging cluster issues.
  enabled_cluster_log_types = [
    "api",           # API server requests
    "audit",         # Who did what
    "authenticator", # IAM authentication
  ]

  # Ensure IAM roles exist before creating the cluster
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# ──────────────────────────────────────────────
# Managed Node Group (Worker Nodes)
# ──────────────────────────────────────────────
# These are the EC2 instances that actually run your pods.
# "Managed" means AWS handles:
#   - Launching instances with the right AMI
#   - Registering them with the EKS cluster
#   - Draining & replacing nodes during updates
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn

  # Worker nodes go in PRIVATE subnets (no public IP)
  subnet_ids = aws_subnet.private[*].id

  instance_types = var.eks_node_instance_types
  disk_size      = var.eks_node_disk_size

  # Autoscaling configuration
  scaling_config {
    desired_size = var.eks_node_desired
    min_size     = var.eks_node_min
    max_size     = var.eks_node_max
  }

  # How nodes are replaced during updates:
  # max_unavailable = 1 means "update one node at a time"
  update_config {
    max_unavailable = 1
  }

  # Ensure all node IAM policies are attached before creating nodes
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy,
  ]

  tags = {
    Name = "${var.project_name}-nodes"
  }
}

# ──────────────────────────────────────────────
# EKS Add-ons
# ──────────────────────────────────────────────
# EKS add-ons are Kubernetes components managed by AWS.
# They're automatically updated with the cluster.

# CoreDNS — cluster-internal DNS (resolves service names)
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  # PRESERVE = don't overwrite custom config during updates
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.main]
}

# kube-proxy — handles Service → Pod routing on each node
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.main]
}

# VPC CNI — assigns VPC IPs directly to pods (AWS networking magic)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.main]
}

# EBS CSI Driver — lets Kubernetes create EBS volumes for PVCs
# This is what MongoDB will use for persistent storage.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.ebs_csi,
  ]
}
