# loki2001_cpp_conventions

Personal C++ conventions for agentic development with Claude Code and Codex.

Built on two sources:

- Radar Verification Tool source code policy: naming, file structure, coding style, smart pointers,
  callbacks, interfaces, error handling, logging, RAII, threading, tests, comments
- MOLIT-15 integrated control software design: component-based development (CBD), design principles
  P1–P5, layers, single loop threading, bounded queues, frame boundary checks, failure recovery,
  safety design, configuration, logging format, test strategy

## Install

```bash
# claude
claude plugin marketplace add loki2001-dev/loki2001_cpp_conventions
claude plugin install cpp-conventions@loki2001

# codex
codex plugin marketplace add loki2001-dev/loki2001_cpp_conventions
codex plugin add cpp-conventions@loki2001

# setup (replaces global agent instructions, backups are kept)
/cpp-conventions:setup
```

## Skills

| Skill          | Scope                                                                 |
| -------------- | --------------------------------------------------------------------- |
| `cbd`          | Component-based development process, component rules, spec template   |
| `architecture` | Principles, layers, threading, queues, codecs, recovery, safety, logs |
| `cpp`          | Source code policy, patterns, clang-format and clang-tidy configs     |
| `testing`      | Unit tests, virtual integration tests, load and fault injection       |
| `cmake`        | Target-based CMake, MSVC and GCC warning policy                       |
| `setup`        | Installs `instructions/AGENTS.md` globally                            |

## Test

```bash
skills/setup/tests/test
```
