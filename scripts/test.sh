#!/usr/bin/env bash

function main() {
  repo_root=$(git rev-parse --show-toplevel)
  pushd "${repo_root}" # move to the root of the repo
  pushd ./apps/chromakey-processor
  sam build
  sam local invoke ChromakeyProcessor -e events/event.json
  popd
  pushd ./apps/compositing-processor
  sam build
  sam local invoke CompositingProcessor -e events/testevent.json
  sam local invoke CompositingProcessor -e events/event.json
  popd
  pushd ./apps/photos-post-processing-processor
  sam build
  sam local invoke PhotosPostProcessingProcessor -e events/testevent.json
  sam local invoke PhotosPostProcessingProcessor -e events/event.json --container-env-vars ./env/environmentvariables.json
  popd
  popd
}

main