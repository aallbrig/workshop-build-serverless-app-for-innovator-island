#!/usr/bin/env bash
__required_binaries=(git aws node)
__required_environment_variables=(AMPLIFYAPPGITHUBACCESSTOKEN REPOSITORY_URL WEBAPPFRONTENDROOT)
ARCH=$(uname -m)

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
  aws_region=$(aws configure get region)
  pushd "${repo_root}"

  # TODO It'd be great to have the gh CLI interactions in order to create an appropriate GitHub access token for an aws amplify app (right now this is hidden knowledge for this script; see GitHubAccessToken value of AMPLIFYAPPGITHUBACCESSTOKEN environment variable)
  # Using `curl` or `gh api`
  # send a POST to create a new github fine-grained access token that is limited to
  # aallbrig/workshop-build-serverless-app-for-innovator-island
  # and has permission to (copied from github amplify app that you can manually trigger in aws)
  # - Write access to files located at amplify.yml
  # - Read access to code and metadata
  # - Read and write access to checks, pull requests, and repository hooks
  # ...Once this access token is create then use it instead of AMPLIFYAPPGITHUBACCESSTOKEN environment variable

  if [ ! -f ./apps/local-app/translate/translations.json ]; then
    pushd ./apps/local-app/translate
    node ./translate.js "${aws_region}"
    popd
  fi

  if [ ! -f ./apps/webapp-frontend/src/languages/translations.json ] \
    || ! diff -q ./apps/local-app/translate/translations.json ./apps/webapp-frontend/src/languages/translations.json; then
    mv ./apps/local-app/translate/translations.json ./apps/webapp-frontend/src/languages/translations.json
  fi

  # region: amplify app
  # Amplify web app for frontend
  aws cloudformation deploy \
    --template-file ./cloudformation/amplify_app.yaml \
    --stack-name innovator-island-amplify-app \
    --parameter-overrides \
      Repository="${REPOSITORY_URL}" \
      WebAppFrontendRoot="${WEBAPPFRONTENDROOT}" \
      GitHubAccessToken="${AMPLIFYAPPGITHUBACCESSTOKEN}"
  # endregion

  # region sam deployment bucket
  # Bucket for SAM deployments
  account_id=$(aws sts get-caller-identity --query Account --output text)
  sam_deployment_bucket_name="theme-park-sam-deployments-${account_id}"
  aws cloudformation deploy \
    --template-file ./cloudformation/sam_deployment_bucket.yaml \
    --stack-name theme-park-sam-deployment-bucket \
    --parameter-overrides \
      BucketName="${sam_deployment_bucket_name}"
  deploy_bucket=$( \
    aws cloudformation describe-stacks \
      --stack-name theme-park-sam-deployment-bucket \
      --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
      --output text \
  )
  # endregion

  # region ride-controller (./apps/ride-controller)
  # Deploy ride controller
  pushd ./apps/ride-controller
  sam build
  sam package --output-template-file package.yaml --s3-bucket "${deploy_bucket}" --s3-prefix ride-controller
  sam deploy \
    --template-file package.yaml \
    --stack-name theme-park-ride-times \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  ride_updates_sns_topic=$(aws cloudformation describe-stacks --stack-name theme-park-ride-times --query "Stacks[0].Outputs[?OutputKey=='RideUpdatesSNSTopic'].OutputValue" --output text)
  popd
  # endregion

  # region theme-park-backend (./apps/sam-app)
  # Deploy remaining SAM backend
  pushd ./apps/sam-app
  sam build
  sam package --output-template-file package.yaml --s3-bucket "${deploy_bucket}" --s3-prefix sam-app
  sam deploy \
    --template-file package.yaml \
    --stack-name theme-park-backend \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  upload_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id UploadBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  upload_bucket_object_created_topic=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='UploadBucketObjectCreatedTopic'].OutputValue" --output text)
  processing_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id ProcessingBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  processing_bucket_object_created_topic=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='ProcessingBucketObjectCreatedTopic'].OutputValue" --output text)
  final_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id FinalBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  final_bucket_object_created_topic=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='FinalBucketObjectCreatedTopic'].OutputValue" --output text)
  dynamo_table=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id DynamoDBTable --query "StackResourceDetail.PhysicalResourceId" --output text)
  theme_park_lambda_role=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='ThemeParkLambdaRole'].OutputValue" --output text)
  initStateAPI=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='InitStateApi'].OutputValue" --output text)
  uploadAPI=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='UploadApi'].OutputValue" --output text)
  identityPoolId=$(aws cloudformation describe-stacks --stack-name theme-park-backend --output text --query "Stacks[0].Outputs[?OutputKey=='IdentityPoolId'].OutputValue" --output text)
  webapp_domain=$(aws cloudformation describe-stacks --stack-name theme-park-backend --query "Stacks[0].Outputs[?OutputKey=='WebAppDomain'].OutputValue" --output text)
  popd
  # endregion

  # region local operations (./apps/local-app)
  # Populate the DynamoDB Table
  pushd ./apps/local-app
  npm install
  # This is probably not idempotent (todo: make it idempotent)
  node ./importData.js "${aws_region}" "${dynamo_table}"
  # aws dynamodb scan --table-name "${dynamo_table}"
  popd
  # endregion

  # region: (module 2) realtime ride times app (./apps/realtime-ride-times-app)
  # Create new realtime ride times app
  pushd ./apps/realtime-ride-times-app
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
      DDBTableName="${dynamo_table_name}" \
    --no-fail-on-empty-changeset
  popd
  # endregion

  # region (module 3a) chromakey processor lambda app (./apps/chromakey-processor)
  pushd ./apps/chromakey-processor

  # Apparently opencv needs to be compiled for amazon linux 2, which is handled by a lambda layer.
  # Signal: if the file doesn't exist locally, wget it, upload it to the sam deployment bucket, and then create a lambda layer out of it
  if [ ! -f ./lambda-layer/cv2-python39.zip ]; then
    mkdir -p ./lambda-layer
    pushd ./lambda-layer

    # New instructions
    # instructions copied from this source repo: https://github.com/awslabs/lambda-opencv
    # 1. clone repo and cwd == repo root
    if [ ! -d lambda-opencv ]; then
      git clone https://github.com/aallbrig/lambda-opencv
    fi
    pushd lambda-opencv
    git checkout python39-only
    # (hack) remove .git folder so files show up in my editor without issue
    rm -rf .git

    # 2. build docker image
    if [[ "$ARCH" == "arm64" ]]; then
      # e.g. apple silicon M1, M2
      docker buildx build --platform linux/arm64 --tag=lambda-layer-factory:39 .
    else
      docker build --tag=lambda-layer-factory:39 .
    fi
    popd

    # 3. run docker image and extract relevant zip file
    docker run --rm -it -v $(pwd):/data lambda-layer-factory:39 cp /packages/cv2-python39.zip /data
    popd
  fi

  sam build
  sam package \
    --output-template-file package.yaml \
    --s3-bucket "${deploy_bucket}" \
    --s3-prefix chromakey-processor
  sam deploy \
    --template-file package.yaml \
    --stack-name chromakey-processor \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
      LambdaRoleName="${theme_park_lambda_role}" \
      ProcessingS3BucketName="${processing_bucket}" \
      UploadBucketObjectCreatedTopic="${upload_bucket_object_created_topic}" \
    --no-fail-on-empty-changeset
  popd
  # endregion

  # region (module 3b) compositing processor lambda app (./apps/compositing-processor)
  pushd ./apps/compositing-processor

  sam build
  sam package \
    --output-template-file package.yaml \
    --s3-bucket "${deploy_bucket}" \
    --s3-prefix compositing-processor
  sam deploy \
    --template-file package.yaml \
    --stack-name compositing-processor \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
      LambdaRoleName="${theme_park_lambda_role}" \
      FinalS3BucketName="${final_bucket}" \
      ProcessingBucketObjectCreatedTopic="${processing_bucket_object_created_topic}" \
    --no-fail-on-empty-changeset

  popd
  # endregion

  # region (module 3c) photos-post-processing processor lambda app (./apps/photos-post-processing-processor)
  pushd ./apps/photos-post-processing-processor

  sam build
  sam package \
    --output-template-file package.yaml \
    --s3-bucket "${deploy_bucket}" \
    --s3-prefix photos-post-processing-processor
  sam deploy \
    --template-file package.yaml \
    --stack-name photos-post-processing-processor \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
      LambdaRoleName="${theme_park_lambda_role}" \
      FinalBucketObjectCreatedTopic="${final_bucket_object_created_topic}" \
      IotDataEndpoint="${iot_endpoint_address}" \
      DDBTableName="${dynamo_table_name}" \
      WebAppDomain="${webapp_domain}" \
    --no-fail-on-empty-changeset

  popd
  # endregion

  # region theme park business analytics
  aws cloudformation deploy \
      --template-file ./cloudformation/business_analytics.yaml \
      --stack-name theme-park-business-analytics \
      --capabilities CAPABILITY_IAM
  #

  # region webapp-frontend (./apps/webapp-frontend)
  # Update frontend
  if ! grep "initStateAPI: '${initStateAPI}'" ./apps/webapp-frontend/src/config.js; then
    sed -i '' "s@initStateAPI: '[^']*'@initStateAPI: '${initStateAPI}'@g" ./apps/webapp-frontend/src/config.js
  fi
  if ! grep "photoUploadURL: '${uploadAPI}'" ./apps/webapp-frontend/src/config.js; then
    sed -i '' "s@photoUploadURL: '[^']*'@photoUploadURL: '${uploadAPI}'@g" ./apps/webapp-frontend/src/config.js
  fi
  if ! grep "poolId: '${identityPoolId}'" ./apps/webapp-frontend/src/config.js; then
    sed -i '' "s@poolId: '[^']*'@poolId: '${identityPoolId}'@" ./apps/webapp-frontend/src/config.js
  fi
  if ! grep "host: '${iot_endpoint_address}'" ./apps/webapp-frontend/src/config.js; then
    sed -i '' "s@host: '[^']*'@host: '${iot_endpoint_address}'@" ./apps/webapp-frontend/src/config.js
  fi
  if ! grep "region: '${aws_region}'" ./apps/webapp-frontend/src/config.js; then
    sed -i '' "s@region: '[^']*'@region: '${aws_region}'@" ./apps/webapp-frontend/src/config.js
  fi
  # endregion
  pushd
}

main
