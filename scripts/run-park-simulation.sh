#!/usr/bin/env bash

function main() {
  echo "Running park simulation..."
  simulator_fn_name="$(aws cloudformation describe-stacks --stack-name park-simulator  --query "Stacks[0].Outputs[?OutputKey=='SimulatorFunctionName'].OutputValue" --output text)"
  aws lambda invoke --function-name "${simulator_fn_name}" --invocation-type Event --payload '{}' /dev/stdout
}

main