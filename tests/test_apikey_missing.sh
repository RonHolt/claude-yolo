#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir/.."

# Ensure API key is unset
unset ANTHROPIC_API_KEY

# Stub docker to bypass image check
stub_dir="$(mktemp -d)"
cat <<'STUB' > "$stub_dir/docker"
#!/bin/bash
if [[ "$1" == "image" && "$2" == "inspect" ]]; then
  exit 0
elif [[ "$1" == "run" ]]; then
  exit 0
else
  exit 0
fi
STUB
chmod +x "$stub_dir/docker"
PATH="$stub_dir:$PATH"

set +e
output="$("$repo_root/claude-yolo" --apikey 2>&1)"
status=$?
set -e

expected="❌ Error: ANTHROPIC_API_KEY environment variable is not set for --apikey mode."

if [ "$status" -eq 0 ]; then
  echo "Expected non-zero exit status" >&2
  exit 1
fi

if [[ "$output" != *"$expected"* ]]; then
  echo "Expected error message not found" >&2
  echo "Output was:" >&2
  echo "$output" >&2
  exit 1
fi

echo "PASS"
