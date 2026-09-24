#!/usr/bin/env bash
# runs every verification check on a project and prints file:line: [RULE] reason. fix: direction
#
# usage: verify.sh [--only a,b] [--skip a,b] [--range RANGE | --all-commits] [project-root]
# checks: format cmake commit conventions tidy p1 p2 p3 p5
# exit: 0 all checks passed or were skipped, 1 a check failed, 2 usage or tool error
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
PLUGIN_DIR="$(cd "$VERIFY_SCRIPT_DIR/../../.." && pwd)"
ALL_CHECKS="format cmake commit conventions tidy p1 p2 p3 p5"
CLANG_TIDY=${CLANG_TIDY:-clang-tidy}

usage() {
  echo "usage: $0 [--only a,b] [--skip a,b] [--range RANGE | --all-commits] [project-root]" >&2
  echo "checks: $ALL_CHECKS" >&2
  exit 2
}

run_conventions() {
  local root=$1
  local output
  if output=$("$PLUGIN_DIR/skills/cpp/scripts/check" "$root" 2>&1); then
    verify_summary conventions 0 "cpp skill check"
    return 0
  fi
  sed 's/$/. fix: see the cpp skill (include order, NOLINT reason) or the architecture skill (exception table)/' <<< "$(grep -v '^check passed$' <<< "$output")"
  verify_summary conventions "$(grep -c . <<< "$output")" "cpp skill check"
}

run_tidy() {
  local root=$1
  local build=
  local dir
  local files
  local output
  local count
  for dir in "${VERIFY_BUILD_DIR:-}" build .; do
    if [ -n "$dir" ] && [ -f "$root/$dir/compile_commands.json" ]; then
      build=$dir
      break
    fi
  done
  if [ -z "$build" ]; then
    echo "tidy: skipped (no compile_commands.json in build/. configure with cmake -S . -B build first)"
    return 3
  fi
  if ! command -v "$CLANG_TIDY" > /dev/null 2>&1; then
    echo "tidy: skipped ($CLANG_TIDY not found. install clang-tidy or set CLANG_TIDY)"
    return 3
  fi
  files=$(verify_cpp_files "$root" | grep -E '\.(cpp|cc)$' || true)
  if [ -z "$files" ]; then
    verify_summary tidy 0 "no files"
    return 0
  fi
  output=$(cd "$root" && xargs "$CLANG_TIDY" -p "$build" --quiet <<< "$files" 2>&1 || true)
  grep -E ': (error|warning): ' <<< "$output" | sed 's/$/. fix: see the cpp skill naming and prohibited items/' || true
  count=$(grep -c -E ': (error|warning): ' <<< "$output" || true)
  verify_summary tidy "$count" "$(grep -c . <<< "$files") files"
}

run_check() {
  local name=$1
  local root=$2
  shift 2
  case "$name" in
    format) "$VERIFY_SCRIPT_DIR/check_format.sh" "$root" ;;
    cmake) "$VERIFY_SCRIPT_DIR/check_cmake.sh" "$root" ;;
    commit) "$VERIFY_SCRIPT_DIR/check_commit.sh" "$@" "$root" ;;
    conventions) run_conventions "$root" ;;
    tidy) run_tidy "$root" ;;
    p1 | p2 | p3 | p5) "$VERIFY_SCRIPT_DIR/check_$name.sh" "$root" ;;
    *) usage ;;
  esac
}

main() {
  local only=$ALL_CHECKS
  local skip=
  local commit_args=()
  local root=.
  local name
  local status
  local failed=()
  local skipped=()
  local errors=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --only)
        only=${2:-}
        only=${only//,/ }
        shift 2
        ;;
      --skip)
        skip=${2:-}
        skip=${skip//,/ }
        shift 2
        ;;
      --range)
        commit_args=(--range "${2:-}")
        shift 2
        ;;
      --all-commits)
        commit_args=(--all)
        shift
        ;;
      -*)
        usage
        ;;
      *)
        root=$1
        shift
        ;;
    esac
  done
  root=$(verify_root "$root")
  for name in $only; do
    grep -q -w "$name" <<< "$ALL_CHECKS" || usage
  done
  for name in $ALL_CHECKS; do
    grep -q -w "$name" <<< "$only" || continue
    ! grep -q -w "$name" <<< "$skip" || continue
    echo "== $name"
    status=0
    run_check "$name" "$root" "${commit_args[@]}" || status=$?
    case "$status" in
      0) ;;
      1) failed+=("$name") ;;
      3) skipped+=("$name") ;;
      *) errors+=("$name") ;;
    esac
  done
  echo "=="
  [ "${#skipped[@]}" -eq 0 ] || echo "verify: skipped ${skipped[*]}. report these as not verified"
  if [ "${#errors[@]}" -gt 0 ]; then
    echo "verify: error in ${errors[*]}"
    return 2
  fi
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "verify: fail (${failed[*]}). fix every finding above and run verify.sh again"
    return 1
  fi
  echo "verify: pass"
}

main "$@"
