#!/usr/bin/env bash

function main() {
  if ! command -v aws &> /dev/null
  then
      echo "aws could not be found"
      exit
  fi

  aws cloudformation delete-stack \
    --stack-name innovator-island-amplify-app
}

main
