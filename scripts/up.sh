#!/usr/bin/env bash
__required_binaries=(git aws node)
__required_environment_variables=(AMPLIFYAPPGITHUBACCESSTOKEN REPOSITORY_URL WEBAPPFRONTENDROOT)

set -e

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
    [ -z "${environment_variable}" ] && { echo "${environment_variable} must be defined"; exit 1; }
  done
}

function main() {
  check_dependant_binaries
  check_required_environment_variables
  repo_root=$(git rev-parse --show-toplevel)

  # TODO It'd be great to have the gh CLI interactions in order to create an appropriate GitHub access token for an aws amplify app (right now this is hidden knowledge for this script; see GitHubAccessToken value of AMPLIFYAPPGITHUBACCESSTOKEN environment variable)
  # Using `curl` or `gh api`
  # send a POST to create a new github fine-grained access token that is limited to
  # aallbrig/workshop-build-serverless-app-for-innovator-island
  # and has permission to (copied from github amplify app that you can manually trigger in aws)
  # - Write access to files located at amplify.yml
  # - Read access to code and metadata
  # - Read and write access to checks, pull requests, and repository hooks
  # ...Once this access token is create then use it instead of AMPLIFYAPPGITHUBACCESSTOKEN environment variable

  # Amplify web app for frontend
  aws cloudformation deploy \
    --template-file "${repo_root}"/cloudformation/amplify_app.yaml \
    --stack-name innovator-island-amplify-app \
    --parameter-overrides \
      Repository="${REPOSITORY_URL}" \
      WebAppFrontendRoot="${WEBAPPFRONTENDROOT}" \
      GitHubAccessToken="${AMPLIFYAPPGITHUBACCESSTOKEN}"

  # Bucket for SAM deployments
  account_id=$(aws sts get-caller-identity --query Account --output text)
  sam_deployment_bucket_name="theme-park-sam-deployment-${account_id}"
  aws cloudformation deploy \
    --template-file "${repo_root}"/cloudformation/sam_deployment_bucket.yaml \
    --stack-name theme-park-sam-deployment-bucket \
    --parameter-overrides \
      BucketName="${sam_deployment_bucket_name}"
  deploy_bucket=$( \
    aws cloudformation describe-stacks \
      --stack-name theme-park-sam-deployment-bucket \
      --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
      --output text \
  )

  # Deploy ride controller
  pushd "${repo_root}"/apps/ride-controller
  sam build
  sam package --output-template-file package.yaml --s3-bucket "${deploy_bucket}" --s3-prefix ride-controller
  sam deploy \
    --template-file package.yaml \
    --stack-name theme-park-ride-times \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  ride_updates_sns_topic=$(aws cloudformation describe-stacks --stack-name theme-park-ride-times --query "Stacks[0].Outputs[?OutputKey=='RideUpdatesSNSTopic'].OutputValue" --output text)
  popd

  # Deploy remaining SAM backend
  pushd "${repo_root}"/apps/sam-app
  sam build
  sam package --output-template-file package.yaml --s3-bucket "${deploy_bucket}" --s3-prefix sam-app
  sam deploy \
    --template-file package.yaml \
    --stack-name theme-park-backend \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  aws_region=$(aws configure get region)
  final_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id FinalBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  processing_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id ProcessingBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  upload_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id UploadBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  dynamo_table=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id DynamoDBTable --query "StackResourceDetail.PhysicalResourceId" --output text)
  theme_park_lambda_role=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='ThemeParkLambdaRole'].OutputValue" --output text)
  popd

  # Populate the DynamoDB Table
  pushd "${repo_root}"/apps/local-app
  npm install
  # This is probably not idempotent (todo: make it idempotent)
  node ./importData.js "${aws_region}" "${dynamo_table}"
  # aws dynamodb scan --table-name "${dynamo_table}"
  initStateAPI=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='InitStateApi'].OutputValue" --output text)
  popd

  # Create new realtime ride times app
  pushd "${repo_root}"/apps/realtime-ride-times-app
  # grab some info for lambda envvars
  iot_endpoint_address=$(aws iot describe-endpoint --endpoint-type iot:Data-ATS --query 'endpointAddress' --output text)
  dynamo_table_name=$(aws dynamodb list-tables --query "TableNames[?contains(@, 'backend')]" --output text)
  echo "iot_endpoint_address: ${iot_endpoint_address} dynamo_table_name: ${dynamo_table_name}"
  sam build
  sam package --output-template-file package.yaml --s3-bucket "${deploy_bucket}" --s3-prefix realtime-ride-times-app
  sam deploy \
    --template-file package.yaml \
    --stack-name realtime-ride-times-app \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
      LambdaRoleName="${theme_park_lambda_role}" \
      SNSTopicName="${ride_updates_sns_topic}" \
      IOTDataEndpoint="${iot_endpoint_address}" \
      DDBTableName="${dynamo_table_name}"
  popd

  # Update frontend
  if ! grep "${initStateAPI}" "${repo_root}"/apps/webapp-frontend/src/config.js; then
    sed -i '' "s@initStateAPI: '.*'@initStateAPI: '${initStateAPI}'@g" "${repo_root}"/apps/webapp-frontend/src/config.js
  fi
}

main
