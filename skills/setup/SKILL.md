---
name: setup
description: C++ 개발 규약을 Codex 및 Claude Code 환경의 사용자 전체 지침으로 설치한다. 사용자가 전역 지침 설치나 규약 설정을 요청할 때 사용한다.
---

# 전역 지침 설치

이 스킬은 Codex 및 Claude Code 환경의 사용자 전체 지침을 이 플러그인의 공용 지침으로 완전히 교체한다.

## 실행 전 확인

- 기존 `~/.codex/AGENTS.md`와 `~/.claude/CLAUDE.md`의 전체 내용이 교체된다고 알린다.
- 대상 파일이 있으면 동일한 디렉터리에 UTC 타임스탬프가 붙은 백업 파일을 만든다고 알린다.
- 사용자가 명시적으로 승인한 경우에만 설치를 실행한다.

## 실행 방법

현재 작업 공간이 아니라, 이 `SKILL.md`와 같은 디렉터리에 포함된 `scripts/setup`을 실행한다.

```bash
scripts/setup --force
```

## 설치 결과 확인

- 표준 출력에 두 설치 경로가 표시되는지 확인한다.
- 기존 파일이 있었다면 백업 경로가 표시되는지 확인한다.
- Codex 환경은 새 세션에서 `~/.codex/AGENTS.md`를 읽고, Claude Code 환경은 새 세션에서 `~/.claude/CLAUDE.md`를 읽는다.
