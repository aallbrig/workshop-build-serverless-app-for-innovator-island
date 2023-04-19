#!/usr/bin/env bash

function main() {
  if ! command -v aws &> /dev/null
  then
      echo "aws could not be found"
      exit
  fi

  if [ -z "$GITHUBACCESSTOKEN" ] || [ -z "$REPOSITORY" ] || [ -z "$WEBAPPFRONTENDROOT" ]
  then
      echo "GITHUBACCESSTOKEN, REPOSITORY, and WEBAPPFRONTENDROOT must be defined"
      exit
  fi

  aws cloudformation deploy \
    --template-file ./cloudformation/amplify_app.yaml \
    --stack-name innovator-island-amplify-app \
    --parameter-overrides \
      Repository=$REPOSITORY \
      WebAppFrontendRoot=$WEBAPPFRONTENDROOT \
      GitHubAccessToken=$GITHUBACCESSTOKEN
}

main
