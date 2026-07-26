#!/usr/bin/env bash
#
# ShellCheck at -S warning with no blanket excludes. The few intentional
# patterns (dynamic `source` of VM configs, deliberate word splitting, globals
# read by sourcing scripts) carry inline `# shellcheck disable=` directives at
# the exact line, so a real problem elsewhere still fails the build.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

command -v shellcheck >/dev/null || { echo "shellcheck not installed"; exit 1; }

files=()
while IFS= read -r f; do files+=("$f"); done < <(./tests/ci/shell-files.sh)

echo "Checking ${#files[@]} scripts with $(shellcheck --version | awk '/version:/{print $2}')"
shellcheck -S warning "${files[@]}"
echo "ShellCheck: clean"
