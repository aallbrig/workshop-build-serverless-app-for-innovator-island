#!/usr/bin/env bash

function delete_stack() {
  stack_name="${1}"
  [ -z "${stack_name}" ] && { echo "Stack name must be provided"; exit 1; }

  aws cloudformation delete-stack --stack-name "${stack_name}"
}

function check_dependant_binaries() {
  if ! command -v aws &> /dev/null
  then
    echo "aws could not be found"
    exit 1
  fi
}

function main() {
  check_dependant_binaries
  stacks=(innovator-island-amplify-app theme-park-ride-times theme-park-backend realtime-ride-times-app)

  for stack in "${stacks[@]}"; do
    delete_stack "${stack}"
  done

  # hack: remove all resources from S3 bucket before deleting the cloudformation stack
  deploy_bucket=$(aws cloudformation describe-stacks \
    --stack-name theme-park-sam-deployment-bucket \
    --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
    --output text)
  aws s3 rm s3://"${deploy_bucket}" --recursive
  delete_stack theme-park-sam-deployment-bucket

  repo_root=$(git rev-parse --show-toplevel)
  if ! grep "initStateAPI: ''" "${repo_root}"/apps/webapp-frontend/src/config.js; then
    sed -i '' "s@initStateAPI: '[^']*'@initStateAPI: ''@g" "${repo_root}"/apps/webapp-frontend/src/config.js
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
