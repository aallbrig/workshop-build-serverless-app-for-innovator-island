#!/usr/bin/env bash

function main() {
  repo_root=$(git rev-parse --show-toplevel)
  pushd "${repo_root}"/apps/chromakey-processor
  sam build
  sam local invoke ChromakeyProcessor -e events/event.json
  popd
  pushd "${repo_root}"/apps/compositing-processor
  sam build
  sam local invoke CompositingProcessor -e events/testevent.json
  sam local invoke CompositingProcessor -e events/event.json
  popd
  pushd "${repo_root}"/apps/photos-post-processing-processor
  sam build
  sam local invoke PhotosPostProcessingProcessor -e events/testevent.json
  sam local invoke PhotosPostProcessingProcessor -e events/event.json --container-env-vars ./env/environmentvariables.json
  popd
}

main