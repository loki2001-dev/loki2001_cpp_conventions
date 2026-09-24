#!/usr/bin/env bash
# P5: member queues without a capacity, ignored push results, drops without a log
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

main() {
  local root
  local files=()
  local output
  local count
  root=$(verify_root "${1:-.}")
  mapfile -t files < <(verify_source_files "$root")
  if [ "${#files[@]}" -eq 0 ]; then
    verify_summary p5 0 "no files"
    return 0
  fi
  output=$(cd "$root" && awk -f "$VERIFY_COMMON_AWK" -f "$VERIFY_SCRIPT_DIR/check_p5.awk" pass=1 "${files[@]}" pass=2 "${files[@]}")
  count=$(awk '/^@@count / { total += $2 } END { print total + 0 }' <<< "$output")
  grep -v '^@@count ' <<< "$output" | sort -t: -k1,1 -k2,2n || true
  verify_summary p5 "$count" "${#files[@]} files"
}

main "$@"
