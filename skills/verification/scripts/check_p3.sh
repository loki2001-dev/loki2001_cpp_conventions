#!/usr/bin/env bash
# P3: external lengths, counts, indexes and offsets used as buffer bounds without a range check
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# names declared as maps. map[key] with an external key does not overflow a buffer
map_names() {
  local root=$1
  local files=$2
  [ -n "$files" ] || return 0
  (cd "$root" && xargs cat <<< "$files") | awk '
    match($0, /map[ \t]*<.*>[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*(;|=|\{)/) {
      name = substr($0, RSTART, RLENGTH)
      sub(/[ \t]*(;|=|\{)$/, "", name)
      sub(/.*[^A-Za-z0-9_]/, "", name)
      names[name] = 1
    }
    END {
      for (name in names) {
        printf "%s ", name
      }
    }'
}

main() {
  local root
  local files
  root=$(verify_root "${1:-.}")
  files=$(verify_source_files "$root")
  VERIFY_AWK_VARS="mapNames=$(map_names "$root" "$files")" \
    verify_run_awk p3 "$VERIFY_SCRIPT_DIR/check_p3.awk" "$root" "$files"
}

main "$@"
