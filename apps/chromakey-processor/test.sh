#!/usr/bin/env bash

function main() {
  upload_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id UploadBucket --query "StackResourceDetail.PhysicalResourceId" --output text)

  aws s3 cp ./photos/green-screen-test.png s3://"${upload_bucket}"
}
main
