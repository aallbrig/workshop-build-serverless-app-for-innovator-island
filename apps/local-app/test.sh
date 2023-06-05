#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

function main() {
  upload_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id UploadBucket --query "StackResourceDetail.PhysicalResourceId" --output text)
  processing_bucket=$(aws cloudformation describe-stack-resource --stack-name theme-park-backend --logical-resource-id ProcessingBucket --query "StackResourceDetail.PhysicalResourceId" --output text)

  pushd "${SCRIPT_DIR}"

  # aws s3api delete-object --bucket "${final_bucket}" --key green-screen-test.png
  aws s3api delete-object --bucket "${processing_bucket}" --key green-screen-test.png
  aws s3api delete-object --bucket "${upload_bucket}" --key green-screen-test.png
  aws s3 cp ./photos/green-screen-test.png s3://"${upload_bucket}"

  popd
}
main
