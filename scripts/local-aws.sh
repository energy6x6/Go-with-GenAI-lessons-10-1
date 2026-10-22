#!/usr/bin/env bash
# Shared setup for demos that run only against the local Floci endpoint.
export PATH="${HOME}/.venvs/devops-aws/bin:${PATH}"
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=eu-central-1
export AWS_REGION=eu-central-1
export AWS_EC2_METADATA_DISABLED=true
export AWS_PAGER=""
unset AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE

aws_local() {
  command aws --endpoint-url http://127.0.0.1:4566 "$@"
}
