# shared helpers for the verification scripts. source this file, do not execute it
VERIFY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_COMMON_AWK="$VERIFY_SCRIPT_DIR/common.awk"
VERIFY_LOOP_DIRS=${VERIFY_LOOP_DIRS:-"src/component src/control src/codec"}

verify_usage() {
  echo "usage: $0 [project-root]" >&2
  exit 2
}

verify_root() {
  local root=${1:-.}
  [ -d "$root" ] || verify_usage
  (cd "$root" && pwd)
}

# lists project files matching the patterns, skipping third party code, build output and test
# fixtures (inputs that break the rules on purpose)
verify_list_files() {
  local root=$1
  local path
  shift
  if git -C "$root" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    git -C "$root" ls-files --cached --others --exclude-standard -- "$@"
  else
    local pattern
    for pattern in "$@"; do
      (cd "$root" && find . -type f -name "$pattern" -not -path './.git/*' | sed 's|^\./||')
    done
  fi | { grep -v -E '(^|/)(3rdparty|third_party|build[^/]*|fixtures)/' || true; } | sort -u | while read -r path; do
    if [ -f "$root/$path" ]; then
      echo "$path"
    fi
  done
}

verify_cpp_files() {
  verify_list_files "$1" '*.h' '*.hpp' '*.cpp' '*.cc'
}

# product code only. tests may sleep, index fixtures and build unbounded buffers
verify_source_files() {
  verify_cpp_files "$1" | grep -v -E '(^|/)(tests?|simulation)/' || true
}

# code that runs on the loop thread (architecture skill layers)
verify_loop_files() {
  local root=$1
  local dir
  local pattern=
  for dir in $VERIFY_LOOP_DIRS; do
    pattern="${pattern:+$pattern|}^${dir%/}/"
  done
  verify_source_files "$root" | grep -E "$pattern" || true
}

verify_summary() {
  local name=$1
  local count=$2
  local scanned=$3
  if [ "$count" -eq 0 ]; then
    echo "$name: pass ($scanned)"
    return 0
  fi
  echo "$name: $count violation(s) ($scanned)"
  return 1
}

# runs an awk check over the files and prints its findings. each awk run ends with "@@count N".
# VERIFY_AWK_VARS="name=value" passes one variable to the check
verify_run_awk() {
  local name=$1
  local check=$2
  local root=$3
  local files=$4
  local output
  local count
  local total
  local variables=(-v "unused=")
  total=$(grep -c . <<< "$files" || true)
  if [ "$total" -eq 0 ]; then
    verify_summary "$name" 0 "no files"
    return 0
  fi
  [ -z "${VERIFY_AWK_VARS:-}" ] || variables=(-v "$VERIFY_AWK_VARS")
  output=$(cd "$root" && xargs awk "${variables[@]}" -f "$VERIFY_COMMON_AWK" -f "$check" <<< "$files")
  count=$(awk '/^@@count / { total += $2 } END { print total + 0 }' <<< "$output")
  grep -v '^@@count ' <<< "$output" || true
  verify_summary "$name" "$count" "$total files"
}
