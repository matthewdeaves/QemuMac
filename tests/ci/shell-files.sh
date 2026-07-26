#!/usr/bin/env bash
#
# Echo every shell script in the project, one per line, from
# tests/shell-files.txt. Sourced or run by the checks that need the list.
#
set -euo pipefail
_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
grep -vE '^[[:space:]]*(#|$)' "${_root}/tests/shell-files.txt"
