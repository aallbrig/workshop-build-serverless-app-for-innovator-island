#!/usr/bin/env bash
__required_binaries=(git aws node)
__required_environment_variables=(GITHUBACCESSTOKEN REPOSITORY WEBAPPFRONTENDROOT)

function check_dependant_binaries() {
  for binary in "${__required_binaries[@]}"; do
    if ! command -v "${binary}" &> /dev/null; then
        echo "${binary} could not be found. Exiting program"
        exit 1
    fi
  done
}

function check_required_environment_variables() {
  for environment_variable in "${__required_environment_variables[@]}"; do
    if [ -z "${environment_variable}" ]; then
        echo "${environment_variable} must be defined"
        exit 1
    fi
  done
}

function main() {
  check_dependant_binaries
  check_required_environment_variables
  repo_root=$(git rev-parse --show-toplevel)

  aws cloudformation deploy \
    --template-file "${repo_root}"/cloudformation/amplify_app.yaml \
    --stack-name innovator-island-amplify-app \
    --parameter-overrides \
      Repository=$REPOSITORY \
      WebAppFrontendRoot=$WEBAPPFRONTENDROOT \
      GitHubAccessToken=$GITHUBACCESSTOKEN

  # Bucket for SAM deployments
  account_id=$(aws sts get-caller-identity --query Account --output text)
  sam_deployment_bucket_name="theme-park-sam-deployment-${account_id}"
  aws cloudformation deploy \
    --template-file "${repo_root}"/cloudformation/sam_deployment_bucket.yaml \
    --stack-name theme-park-sam-deployment-bucket \
    --parameter-overrides \
      BucketName="${sam_deployment_bucket_name}"
  deploy_bucket=$(aws cloudformation describe-stacks \
    --stack-name theme-park-sam-deployment-bucket \
    --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
    --output text)

  # Deploy ride controller
  pushd "${repo_root}"/apps/ride-controller
  sam package --output-template-file package.yaml --s3-bucket "${deploy_bucket}"
  sam deploy --template-file package.yaml --stack-name theme-park-ride-times --capabilities CAPABILITY_IAM
  popd

  # Deploy remaining SAM backend
  pushd "${repo_root}"/apps/sam-app
  sam build
  sam package --output-template-file package.yaml --s3-bucket "${deploy_bucket}"
  sam deploy --template-file packaged.yaml --stack-name theme-park-backend --capabilities CAPABILITY_IAM
  AWS_REGION=$(aws configure get region)
  FINAL_BUCKET=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id FinalBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  PROCESSING_BUCKET=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id ProcessingBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  UPLOAD_BUCKET=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id UploadBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  DDB_TABLE=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id DynamoDBTable --query "StackResourceDetail.PhysicalResourceId" --output text)
  echo $FINAL_BUCKET
  echo $PROCESSING_BUCKET
  echo $UPLOAD_BUCKET
  echo $DDB_TABLE
  popd

  # Populate the DynamoDB Table
  pushd "${repo_root}"/apps/local-app
  npm install
  node ./importData.js "${AWS_REGION}" "${DDB_TABLE}"
  aws dynamodb scan --table-name "${DDB_TABLE}"
  initStateAPI=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='InitStateApi'].OutputValue" --output text)
  popd

  # Update frontend
  if ! grep "${initStateAPI}" "${repo_root}"/apps/webapp-frontend/src/config.js; then
    sed -i '' "s@initStateAPI: ''@initStateAPI: '${initStateAPI}'@g" "${repo_root}"/apps/webapp-frontend/src/config.js
  fi
}

main
