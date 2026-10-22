#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/artifacts.sh"
source "$project_root/scripts/local-aws.sh"
output="$PROJECTGO_ARTIFACTS_DIR/lambda"
function_name=projectgo-demo-api
role_name=projectgo-demo-lambda
test -f "$output/function.zip"

if ! aws_local iam get-role --role-name "$role_name" > "$output/role.json" 2>/dev/null; then
  aws_local iam create-role --role-name "$role_name" \
    --assume-role-policy-document "file://$project_root/demos/lambda/trust-policy.json" \
    > "$output/role.json"
fi
role_arn="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["Role"]["Arn"])' "$output/role.json")"

if aws_local lambda get-function --function-name "$function_name" >/dev/null 2>&1; then
  aws_local lambda update-function-code --function-name "$function_name" \
    --zip-file "fileb://$output/function.zip" > "$output/function.json"
  aws_local lambda wait function-updated --function-name "$function_name"
else
  aws_local lambda create-function --function-name "$function_name" \
    --runtime provided.al2023 --handler bootstrap --architectures x86_64 \
    --timeout 15 --memory-size 128 --role "$role_arn" \
    --zip-file "fileb://$output/function.zip" > "$output/function.json"
fi
aws_local lambda wait function-active --function-name "$function_name"
aws_local lambda get-function --function-name "$function_name" \
  --query 'Configuration.{Name:FunctionName,Runtime:Runtime,State:State,Role:Role,CodeSize:CodeSize}'

aws_local --cli-read-timeout 180 lambda invoke --function-name "$function_name" \
  --log-type Tail --payload '{"name":"ProjectGo"}' "$output/response-named.json" \
  > "$output/invoke-named.json"
aws_local --cli-read-timeout 180 lambda invoke --function-name "$function_name" \
  --log-type Tail --payload '{}' "$output/response-default.json" \
  > "$output/invoke-default.json"

python3 - "$output" <<'PY'
import base64
import json
from pathlib import Path
import sys

output = Path(sys.argv[1])
for case, expected in [('named', 'hello, ProjectGo from floci'), ('default', 'hello, world from floci')]:
    metadata = json.loads((output / f'invoke-{case}.json').read_text())
    response = json.loads((output / f'response-{case}.json').read_text())
    assert metadata['StatusCode'] == 200, metadata
    assert not metadata.get('FunctionError'), metadata
    assert response == {'statusCode': 200, 'body': expected}, response
    if metadata.get('LogResult'):
        (output / f'logs-{case}.txt').write_bytes(base64.b64decode(metadata['LogResult']))
    print(f'{case}: PASS — {json.dumps(response)}')
PY
