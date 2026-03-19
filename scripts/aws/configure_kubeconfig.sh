#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${EKS_CLUSTER_NAME:-${1:-net4255-cluster}}"
REGION="${AWS_REGION:-${2:-us-east-1}}"

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI is not installed or not in PATH"
  exit 1
fi

echo "Configuring kubeconfig for cluster '${CLUSTER_NAME}' in region '${REGION}'..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo "kubeconfig updated successfully"
