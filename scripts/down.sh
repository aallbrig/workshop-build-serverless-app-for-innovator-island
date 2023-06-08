#!/usr/bin/env bash

function check_dependant_binaries() {
  if ! command -v aws &> /dev/null
  then
    echo "aws could not be found"
    exit 1
  fi
}

function main() {
  check_dependant_binaries

  stacks=( \
    innovator-island-amplify-app \
    theme-park-ride-times \
    theme-park-backend \
    realtime-ride-times-app \
    chromakey-processor \
    compositing-processor \
    photos-post-processing-processor \
    theme-park-sam-deployment-bucket \
  )

  # hack: remove all resources from S3 bucket before deleting the cloudformation stack
  deploy_bucket=$(aws cloudformation describe-stacks \
    --stack-name theme-park-sam-deployment-bucket \
    --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
    --output text)
  upload_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id UploadBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  processing_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id ProcessingBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  final_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id FinalBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  buckets=( \
    "${deploy_bucket}" \
    "${upload_bucket}" \
    "${processing_bucket}" \
    "${final_bucket}" \
  )

  # Clear S3 buckets before deleting stacks
  for bucket in "${buckets[@]}"; do
    aws s3 rm s3://"${bucket}" --recursive
  done

  for stack in "${stacks[@]}"; do
    aws cloudformation delete-stack --stack-name "${stack}"
  done

  repo_root=$(git rev-parse --show-toplevel)
  if ! grep "initStateAPI: ''" "${repo_root}"/apps/webapp-frontend/src/config.js; then
    sed -i '' "s@initStateAPI: '[^']*'@initStateAPI: ''@g" "${repo_root}"/apps/webapp-frontend/src/config.js
  fi
  if ! grep "photoUploadURL: ''" "${repo_root}"/apps/webapp-frontend/src/config.js; then
    sed -i '' "s@photoUploadURL: '[^']*'@photoUploadURL: ''@g" "${repo_root}"/apps/webapp-frontend/src/config.js
  fi
  if ! grep "poolId: ''" "${repo_root}"/apps/webapp-frontend/src/config.js; then
    sed -i '' "s@poolId: '[^']*'@poolId: ''@g" "${repo_root}"/apps/webapp-frontend/src/config.js
  fi
  if ! grep "host: ''" "${repo_root}"/apps/webapp-frontend/src/config.js; then
    sed -i '' "s@host: '[^']*'@host: ''@g" "${repo_root}"/apps/webapp-frontend/src/config.js
  fi
  if ! grep "region: ''" "${repo_root}"/apps/webapp-frontend/src/config.js; then
    sed -i '' "s@region: '[^']*'@region: ''@g" "${repo_root}"/apps/webapp-frontend/src/config.js
  fi
}

main
