# Shell portability

## Supported shells and platforms
Support macOS and Ubuntu with bash 3.2. Avoid `mapfile`, `readarray`, `local -n`, `${v,,}`, `sed -i` without a suffix, `readlink -f`, `stat -c`, `grep -P`, `date -d` and `find -printf`. Use `compute_md5` and `compute_sha256`.

## Probe exit status
Capture probe output before grepping: pipefail can invert a negated pipeline. `die()` inside command substitution exits the subshell only; check the returned status.
