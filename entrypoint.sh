#!/bin/bash
set -e

############## Definitions part
deploy_lambda_dependencies () {

    echo "Installing dependencies..."
    mkdir -p python/lib/python3.8/site-packages
    pip install -t ./python/lib/python3.8/site-packages -r "${INPUT_REQUIREMENTS_TXT}"
    echo "OK"

    echo "Zipping dependencies..."
    zip -r python.zip ./python
    rm -rf python
    echo "OK"

    echo "Publishing dependencies layer..."
    response=$(aws lambda publish-layer-version --compatible-runtimes python3.8 --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://python.zip)
    VERSION=$(echo $response | jq '.Version')
    rm python.zip
    echo "OK"

    echo "Updating lambda layer version..."
    aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${VERSION}"
    echo "OK\n"
    echo "Depencencies was deployed successfully"
}

############## Git config
git remote set-url origin "https://${INPUT_TOKEN}@github.com/${GITHUB_REPOSITORY}"
CHANGED_FILES=()

############## Main part
echo "AWS configuration..."
aws configure set default.region "${INPUT_LAMBDA_REGION}"
echo "OK"

echo "Deploying lambda main code..."
if [[ -z "${INPUT_LAMBDA_PAYLOAD_DIR}" ]]; then
  echo "No payload directory set. Using root of repository."
else
  echo "Switching directory to ${INPUT_LAMBDA_PAYLOAD_DIR}"
  cd ${INPUT_LAMBDA_PAYLOAD_DIR}
fi
zip -r lambda.zip . -x \*.git\*
aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://lambda.zip
echo "OK"

### Deploy dependencies if INPUT_LAMBDA_LAYER_ARN was defined in action call
[ ! -z "${INPUT_LAMBDA_LAYER_ARN}" ] && deploy_lambda_dependencies || echo "Dependencies wasn't deployed."

echo "${INPUT_LAMBDA_FUNCTION_NAME} function was deployed successfully."
