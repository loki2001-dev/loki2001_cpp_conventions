#!/usr/bin/env bash
# clang-format --dry-run --Werror with the project .clang-format (cpp skill assets)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CLANG_FORMAT=${CLANG_FORMAT:-clang-format}
MAX_LINES_PER_FILE=5

main() {
  local root
  local files
  local path
  local output
  local lines
  local count=0
  local total
  root=$(verify_root "${1:-.}")
  files=$(verify_cpp_files "$root")
  total=$(grep -c . <<< "$files" || true)
  if [ "$total" -eq 0 ]; then
    verify_summary format 0 "no files"
    return 0
  fi
  if [ ! -f "$root/.clang-format" ]; then
    echo ".clang-format:1: [FORMAT-CONFIG] the project has no .clang-format. fix: copy skills/cpp/assets/.clang-format to the project root"
    verify_summary format 1 "$total files"
    return 1
  fi
  if ! command -v "$CLANG_FORMAT" > /dev/null 2>&1; then
    echo "format: error: $CLANG_FORMAT not found. install clang-format or set CLANG_FORMAT" >&2
    return 2
  fi
  while read -r path; do
    output=$(cd "$root" && "$CLANG_FORMAT" --dry-run --Werror --style=file "$path" 2>&1) && continue
    lines=$(awk -v path="$path" 'index($0, path ":") == 1 {
      split(substr($0, length(path) + 2), parts, ":")
      if (parts[1] ~ /^[0-9]+$/) {
        print path ":" parts[1]
      }
    }' <<< "$output" | sort -u -t: -k2,2n)
    if [ -z "$lines" ]; then
      echo "$path:1: [FORMAT] clang-format failed: $(head -n 1 <<< "$output"). fix: run clang-format on the file and read its error"
      count=$((count + 1))
      continue
    fi
    head -n "$MAX_LINES_PER_FILE" <<< "$lines" | while read -r line; do
      echo "$line: [FORMAT] code is not clang-formatted. fix: run $CLANG_FORMAT -i $path"
    done
    if [ "$(grep -c . <<< "$lines")" -gt "$MAX_LINES_PER_FILE" ]; then
      echo "$path: [FORMAT] $(($(grep -c . <<< "$lines") - MAX_LINES_PER_FILE)) more unformatted lines"
    fi
    count=$((count + 1))
  done <<< "$files"
  verify_summary format "$count" "$total files"
}

main "$@"
