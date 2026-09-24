#!/usr/bin/env bash
# CMake policy (cmake skill): target-based commands, source lists, warnings, compile_commands,
# test registration and out-of-source builds
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

main() {
  local root
  local files=()
  local output
  local count=0
  local preset=0
  root=$(verify_root "${1:-.}")
  mapfile -t files < <(verify_list_files "$root" '*CMakeLists.txt' '*.cmake')
  if [ "${#files[@]}" -eq 0 ]; then
    verify_summary cmake 0 "no files"
    return 0
  fi
  if [ -e "$root/CMakeCache.txt" ] || [ -d "$root/CMakeFiles" ]; then
    echo "CMakeCache.txt:1: [CMAKE-IN-SOURCE] the project was configured in the source directory. fix: delete CMakeCache.txt and CMakeFiles/, then configure with cmake -S . -B build"
    count=1
  fi
  if grep -q '"CMAKE_EXPORT_COMPILE_COMMANDS"' "$root/CMakePresets.json" 2> /dev/null; then
    preset=1
  fi
  output=$(cd "$root" && awk -v presetExport="$preset" -f "$VERIFY_COMMON_AWK" -f "$VERIFY_SCRIPT_DIR/check_cmake.awk" "${files[@]}")
  count=$((count + $(awk '/^@@count / { total += $2 } END { print total + 0 }' <<< "$output")))
  grep -v '^@@count ' <<< "$output" || true
  verify_summary cmake "$count" "${#files[@]} files"
}

main "$@"
