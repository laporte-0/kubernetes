#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/aws/build_and_push.sh webdb webdb-v7
#   scripts/aws/build_and_push.sh webnodb webnodb-v2

APP_VARIANT="${1:-webdb}"
IMAGE_TAG="${2:-latest}"
REGION="${AWS_REGION:-${3:-us-east-1}}"
REPOSITORY="${ECR_REPOSITORY:-net4255}"

if [[ "${APP_VARIANT}" != "webdb" && "${APP_VARIANT}" != "webnodb" ]]; then
  echo "Error: app variant must be one of: webdb, webnodb"
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI is not installed or not in PATH"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH"
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${REGISTRY}/${REPOSITORY}:${IMAGE_TAG}"

# Ensure repository exists (safe no-op if already created)
aws ecr describe-repositories --repository-names "${REPOSITORY}" --region "${REGION}" >/dev/null 2>&1 \
  || aws ecr create-repository --repository-name "${REPOSITORY}" --region "${REGION}" >/dev/null

echo "Logging in to ECR (${REGISTRY})..."
aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

echo "Building image ${IMAGE_URI} for ${APP_VARIANT}..."
docker build \
  --build-arg APP_MODULE="$( [[ "${APP_VARIANT}" == "webdb" ]] && echo "app" || echo "app_nodb" )" \
  -t "${IMAGE_URI}" \
  .

echo "Pushing image ${IMAGE_URI}..."
docker push "${IMAGE_URI}"

echo "Done. Image available at: ${IMAGE_URI}"
