#!/bin/bash

set -euo pipefail

: $ENVIRONMENT
: ${USERNAME:=admin}
: $CONCOURSE_TERRAFORM_STATE_FILE
: $CONCOURSE_CREDS_FILE

# Grab pre-requisite files from S3
aws s3 cp "s3://${ENVIRONMENT}-states/concourse/tfstate.json" "${CONCOURSE_TERRAFORM_STATE_FILE}"
aws s3 cp "s3://${ENVIRONMENT}-states/concourse/creds.yml" "${CONCOURSE_CREDS_FILE}"

FQDN=$(terraform output -state=${ENVIRONMENT}_concourse.tfstate.json concourse_fqdn)
PASSWORD=$(bosh int --path /admin_password ${ENVIRONMENT}_concourse.creds.yml)

fly login -t "$ENVIRONMENT" -u "$USERNAME" -p "$PASSWORD" -c "https://$FQDN"