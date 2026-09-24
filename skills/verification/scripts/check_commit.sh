#!/usr/bin/env bash
# commit subjects: add:, fix:, refactor:, docs:, test: (with ! for breaking changes), lowercase english.
# whether a commit is one logical unit is not checked
#
# usage: check_commit.sh [--range RANGE | --all | --message-file FILE] [project-root]
#   default range: commits not pushed yet (@{upstream}..HEAD), or all commits without an upstream
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
PREFIX_PATTERN='^(add|fix|refactor|docs|test)!?: [^ ]'
FIX_PREFIX="reword the subject as \"<add|fix|refactor|docs|test>: <lowercase english>\" with git commit --amend (latest commit) or git rebase -i (older unpushed commits). do not rewrite pushed commits, report them instead"

# prints a violation and returns 1 when the subject breaks the convention
check_subject() {
  local location=$1
  local subject=$2
  local root_commit=${3:-0}
  case "$subject" in
    'Merge '* | 'Revert "'*)
      return 0
      ;;
  esac
  if [ "$root_commit" -eq 1 ] && [ "$subject" = "Initial commit" ]; then
    return 0
  fi
  subject=${subject#fixup! }
  subject=${subject#squash! }
  if ! grep -q -E "$PREFIX_PATTERN" <<< "$subject"; then
    echo "$location: [COMMIT-PREFIX] subject \"$subject\" does not start with add:, fix:, refactor:, docs: or test:. fix: $FIX_PREFIX"
    return 1
  fi
  if LC_ALL=C grep -q '[A-Z]' <<< "$subject" || LC_ALL=C grep -q '[^ -~]' <<< "$subject"; then
    echo "$location: [COMMIT-CASE] subject \"$subject\" is not lowercase english. fix: $FIX_PREFIX"
    return 1
  fi
  return 0
}

check_message_file() {
  local file=$1
  local subject
  subject=$(grep -v '^#' "$file" | head -n 1 || true)
  if check_subject "$file:1" "$subject"; then
    verify_summary commit 0 "1 message"
    return 0
  fi
  verify_summary commit 1 "1 message"
}

check_range() {
  local root=$1
  local range=$2
  local sha
  local subject
  local parents
  local count=0
  local total=0
  if [ -z "$range" ]; then
    verify_summary commit 0 "no commits to check"
    return 0
  fi
  while IFS=$'\x1f' read -r sha parents subject; do
    [ -n "$sha" ] || continue
    total=$((total + 1))
    check_subject "commit ${sha:0:7}" "$subject" "$([ -z "$parents" ] && echo 1 || echo 0)" || count=$((count + 1))
  done < <(git -C "$root" log --no-merges --format='%H%x1f%P%x1f%s' "$range")
  verify_summary commit "$count" "$total commits in $range"
}

main() {
  local mode=default
  local range=
  local file=
  local root=.
  while [ $# -gt 0 ]; do
    case "$1" in
      --range)
        mode=range
        range=${2:-}
        shift 2
        ;;
      --all)
        mode=all
        shift
        ;;
      --message-file)
        mode=file
        file=${2:-}
        shift 2
        ;;
      -*)
        verify_usage
        ;;
      *)
        root=$1
        shift
        ;;
    esac
  done
  if [ "$mode" = file ]; then
    [ -f "$file" ] || verify_usage
    check_message_file "$file"
    return
  fi
  root=$(verify_root "$root")
  if ! git -C "$root" rev-parse --verify HEAD > /dev/null 2>&1; then
    verify_summary commit 0 "not a git repository or no commits"
    return 0
  fi
  if [ "$mode" = all ]; then
    range=HEAD
  elif [ "$mode" = default ]; then
    if git -C "$root" rev-parse --verify '@{upstream}' > /dev/null 2>&1; then
      range='@{upstream}..HEAD'
      [ -n "$(git -C "$root" rev-list '@{upstream}..HEAD')" ] || range=
    else
      range=HEAD
    fi
  fi
  check_range "$root" "$range"
}

main "$@"
