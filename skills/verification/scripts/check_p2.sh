#!/usr/bin/env bash
# P2: blocking calls in loop-thread code (VERIFY_LOOP_DIRS)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

main() {
  local root
  root=$(verify_root "${1:-.}")
  verify_run_awk p2 "$VERIFY_SCRIPT_DIR/check_p2.awk" "$root" "$(verify_loop_files "$root")"
}

main "$@"
