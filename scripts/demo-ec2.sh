#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/artifacts.sh"
source "$project_root/scripts/local-aws.sh"
output="$PROJECTGO_ARTIFACTS_DIR/ec2"
mkdir -p "$output"
chmod 700 "$output"

aws_local ec2 describe-images > "$output/images.json"
aws_local ec2 describe-images --image-ids ami-ubuntu2404-amd64 \
  --query 'Images[].[ImageId,Name,Architecture]' --output table

if ! aws_local ec2 describe-key-pairs --key-names projectgo-demo-key >/dev/null 2>&1; then
  (umask 077; aws_local ec2 create-key-pair --key-name projectgo-demo-key \
    --query KeyMaterial --output text > "$output/projectgo-demo-key.pem")
fi
aws_local ec2 describe-key-pairs --key-names projectgo-demo-key

aws_local ec2 describe-instances \
  --filters 'Name=tag:Name,Values=projectgo-demo-ec2' \
    'Name=instance-state-name,Values=pending,running,stopping,stopped' \
  --query 'Reservations[].Instances[]' > "$output/existing-instances.json"
instance_id="$(python3 - "$output/existing-instances.json" <<'PY'
import json
import sys
instances = json.load(open(sys.argv[1]))
if len(instances) > 1:
    raise SystemExit('Multiple projectgo-demo-ec2 instances found; review them before continuing.')
print(instances[0]['InstanceId'] if instances else '')
PY
)"
if [[ -z "$instance_id" ]]; then
  aws_local ec2 run-instances \
    --image-id ami-ubuntu2404-amd64 --instance-type t3.micro \
    --key-name projectgo-demo-key \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=projectgo-demo-ec2}]' \
    > "$output/run-instances.json"
  instance_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["Instances"][0]["InstanceId"])' "$output/run-instances.json")"
else
  echo "Reusing existing demo instance: $instance_id"
  state="$(aws_local ec2 describe-instances --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].State.Name' --output text)"
  if [[ "$state" == stopping ]]; then
    aws_local ec2 wait instance-stopped --instance-ids "$instance_id"
    state=stopped
  fi
  if [[ "$state" == stopped ]]; then
    aws_local ec2 start-instances --instance-ids "$instance_id" > "$output/start-instances.json"
  fi
fi
printf '%s\n' "$instance_id" > "$output/instance-id.txt"
aws_local ec2 wait instance-running --instance-ids "$instance_id"
aws_local ec2 describe-instances --instance-ids "$instance_id" > "$output/instance.json"
aws_local ec2 describe-instances --instance-ids "$instance_id" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,ImageId,InstanceType,PrivateIpAddress]' \
  --output table
