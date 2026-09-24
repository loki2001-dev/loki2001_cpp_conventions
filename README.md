# loki2001_cpp_conventions

---

- Personal C++ conventions for agentic development with Claude Code and Codex
- Distributed as a plugin (`cpp-conventions@loki2001`) for both Claude Code and Codex
- Designed for control software: components, threads, queues, device links, recovery and safety
- <span style="color:deepskyblue; font-weight:bold">`/cpp-conventions:setup` replaces the global agent instructions (backups are kept)</span>
- Scripts require bash, POSIX awk and git

---

## Features
- Component-based Development: <span style="color:deepskyblue; font-weight:bold">CBD process</span>, component rules and component spec template
- Design Principles: <span style="color:deepskyblue; font-weight:bold">P1–P5</span> principles, layers and design record template
- Threading Model: <span style="color:deepskyblue; font-weight:bold">Single loop threading</span> with bounded queues and no blocking calls on the loop
- Protocol Codecs: <span style="color:deepskyblue; font-weight:bold">Frame boundary checks</span> for parsing external device frames
- Failure Recovery: Reconnection, timeouts and <span style="color:deepskyblue; font-weight:bold">safe stop conditions</span> for external devices
- Source Code Policy: Naming, file structure, coding style, <span style="color:deepskyblue; font-weight:bold">smart pointers, callbacks, interfaces</span>
- Error Handling & Logging: <span style="color:deepskyblue; font-weight:bold">RAII</span>, error handling policy and a fixed logging format
- Code Formatting: Ready-to-use <span style="color:deepskyblue; font-weight:bold">`.clang-format` and `.clang-tidy`</span> configs
- Test Strategy: <span style="color:deepskyblue; font-weight:bold">Catch2</span> unit tests, virtual integration tests with fake devices, load and fault injection tests
- Build Convention: <span style="color:deepskyblue; font-weight:bold">Target-based CMake</span> with Ninja and MSVC/GCC warning policy
- Agent Decisions: Agents <span style="color:deepskyblue; font-weight:bold">ask instead of guessing</span> safety, protocol and timing values
- Robustness: <span style="color:deepskyblue; font-weight:bold">Zero deadlock, crash and zombie</span> rules with ASan, UBSan and TSan builds
- Enforcement: `clang-tidy` naming and `clang-analyzer-*`, <span style="color:deepskyblue; font-weight:bold">`scripts/check`</span> and a CI workflow template
- Fuzz Testing: <span style="color:deepskyblue; font-weight:bold">libFuzzer</span> targets for codecs, frame assemblers and parsers
- Timing Contract: Period, deadline, handler budget, jitter and throughput with <span style="color:deepskyblue; font-weight:bold">observed worst</span> values
- Principle Exceptions: <span style="color:deepskyblue; font-weight:bold">`EX-P{n}-{nnn}`</span> markers checked against the design record
- Security: <span style="color:deepskyblue; font-weight:bold">TLS</span>, command authentication, secrets and least privilege
- Versioning: Protocol version checks, compatible format changes and <span style="color:deepskyblue; font-weight:bold">build info</span> in the startup log
- Verification: <span style="color:deepskyblue; font-weight:bold">`verify.sh`</span> checks format, CMake policy, commit messages and P1, P2, P3, P5 with `file:line: [RULE] reason. fix: direction` output
- Global Instructions: Installs <span style="color:deepskyblue; font-weight:bold">`instructions/AGENTS.md`</span> as `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md`

---

## Skills

| Skill          | Scope                                                                 |
| -------------- | --------------------------------------------------------------------- |
| `cbd`          | Component-based development process, component rules, spec template   |
| `architecture` | Principles, exceptions, threading, timing, codecs, recovery, security |
| `cpp`          | Source code policy, patterns, clang configs, check script, CI         |
| `testing`      | Unit, fuzz, virtual integration, load and fault injection tests       |
| `cmake`        | Target-based CMake, warnings, sanitizers, fuzzing, build info         |
| `verification` | Automatic checks: format, CMake, commits, P1, P2, P3, P5              |
| `setup`        | Installs `instructions/AGENTS.md` globally                            |

---

## Getting Started

### Prerequisites
- [Claude Code](https://claude.com/claude-code) or [Codex](https://github.com/openai/codex) CLI
- bash, POSIX awk and git (for the scripts and their tests)
- clang-format and clang-tidy (optional, for the `format` and `tidy` verification checks)

---

## Install Instructions

### Claude Code
```bash
# Add the marketplace
claude plugin marketplace add loki2001-dev/loki2001_cpp_conventions

# Install the plugin
claude plugin install cpp-conventions@loki2001
```

### Codex
```bash
# Add the marketplace
codex plugin marketplace add loki2001-dev/loki2001_cpp_conventions

# Install the plugin
codex plugin add cpp-conventions@loki2001
```

### Global Instructions
```bash
# Replace global agent instructions (backups are kept)
/cpp-conventions:setup
```

### Test
```bash
# Verify the setup script
skills/setup/tests/test

# Verify the convention check script
skills/cpp/tests/test

# Verify the verification skill
skills/verification/tests/test
```

---

## Using in a Project
Copy these files from the plugin into a C++ project that has none yet.

| Plugin file                       | Project path                  |
| --------------------------------- | ----------------------------- |
| `skills/cpp/assets/.clang-format` | `.clang-format`               |
| `skills/cpp/assets/.clang-tidy`   | `.clang-tidy`                 |
| `skills/cpp/scripts/check`        | `tools/check-conventions`     |
| `skills/cpp/assets/ci.yml`        | `.github/workflows/ci.yml`    |

```bash
# Run the checks locally
clang-format --dry-run --Werror $(git ls-files '*.cpp' '*.h')
cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
clang-tidy -p build $(git ls-files '*.cpp')
tools/check-conventions .
cmake --build build
ctest --test-dir build --output-on-failure --timeout 300
```

Agents run the verification skill after every implementation. It can also be run by hand from the plugin directory.

```bash
# Every check: format, cmake, commit, conventions, tidy, p1, p2, p3, p5
skills/verification/scripts/verify.sh /path/to/project

# Selected checks, or the commits of a pull request
skills/verification/scripts/verify.sh --only p2,p3 /path/to/project
skills/verification/scripts/verify.sh --range origin/main..HEAD /path/to/project
```

---

## Project Structure
```
loki2001_cpp_conventions/
├── .github/workflows/
│   └── test.yml                            # Script tests and version consistency
│
├── .claude-plugin/                         # Claude Code plugin metadata
│   ├── marketplace.json                    # Marketplace definition
│   └── plugin.json                         # Plugin manifest
│
├── .codex-plugin/                          # Codex plugin metadata
│   └── plugin.json                         # Plugin manifest
│
├── instructions/
│   └── AGENTS.md                           # Global agent instructions
│
├── skills/
│   ├── cbd/                                # Component-based development
│   │   ├── SKILL.md                        # CBD process and component rules
│   │   └── references/
│   │       ├── component-spec-template.md  # Component spec template
│   │       └── example.md                  # CBD example
│   │
│   ├── architecture/                       # Architecture rules
│   │   ├── SKILL.md                        # Principles, threading, timing, security
│   │   └── references/
│   │       ├── design-record.md            # Design record template
│   │       └── patterns.md                 # Architecture patterns
│   │
│   ├── cpp/                                # Source code policy
│   │   ├── SKILL.md                        # Naming, style, pointers, errors, logs
│   │   ├── assets/
│   │   │   ├── .clang-format               # clang-format config
│   │   │   ├── .clang-tidy                 # clang-tidy config
│   │   │   └── ci.yml                      # CI workflow template
│   │   ├── references/
│   │   │   └── patterns.md                 # C++ patterns
│   │   ├── scripts/
│   │   │   └── check                       # Checks what clang-tidy cannot
│   │   └── tests/
│   │       └── test                        # Check script test
│   │
│   ├── testing/                            # Test strategy
│   │   └── SKILL.md                        # Unit, fuzz, integration, load, faults
│   │
│   ├── cmake/                              # Build convention
│   │   └── SKILL.md                        # Targets, sanitizers, fuzzing, version
│   │
│   ├── verification/                       # Automatic convention checks
│   │   ├── SKILL.md                        # Rules, detection, exceptions, fixes
│   │   ├── scripts/
│   │   │   ├── verify.sh                   # Runs every check
│   │   │   ├── check_*.sh, check_*.awk     # format, cmake, commit, p1, p2, p3, p5
│   │   │   ├── common.awk                  # Shared awk functions
│   │   │   └── lib.sh                      # Shared shell functions
│   │   └── tests/
│   │       ├── test                        # Fixture and example tests
│   │       ├── extract-examples            # Writes skill code blocks to a project
│   │       ├── expected/                   # Expected output for the violations
│   │       └── fixtures/                   # violations/ and clean/ projects
│   │
│   └── setup/                              # Global instructions installer
│       ├── SKILL.md                        # Setup skill
│       ├── scripts/
│       │   └── setup                       # Installs AGENTS.md with backups
│       └── tests/
│           └── test                        # Setup script test
│
├── CHANGELOG.md
├── LICENSE
└── README.md
```

---

### Skill Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Agent (Claude Code / Codex)                         │
│                                                                             │
│   ┌──────────────────────┐                                                  │
│   │  Global Instructions │  ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md         │
│   │  (ask before         │  installed by /cpp-conventions:setup             │
│   │   guessing values)   │                                                  │
│   └──────────┬───────────┘                                                  │
│              │                                                              │
│              ▼                                                              │
│   ┌──────────────────────┐    ┌──────────────────────┐                      │
│   │  cbd                 │───▶│  architecture        │                      │
│   │  (Components, specs, │    │  (Threads, timing,   │                      │
│   │   timing contract)   │    │   security, recovery)│                      │
│   └──────────────────────┘    └──────────┬───────────┘                      │
│                                          │                                  │
│                    ┌─────────────────────┼─────────────────────┐            │
│                    ▼                     ▼                     ▼            │
│         ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│         │  cpp             │  │  cmake           │  │  testing         │    │
│         │  (Source code    │  │  (Sanitizers,    │  │  (Catch2, fuzz,  │    │
│         │   policy, check) │  │   fuzz, version) │  │   fake devices)  │    │
│         └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘    │
│                  └─────────────────────┼─────────────────────┘              │
│                                        ▼                                    │
│         ┌────────────────────────────────────────────────────────────┐      │
│         │  verification (scripts/verify.sh)                          │      │
│         │  format, cmake, commit, check, tidy, P1, P2, P3, P5        │      │
│         │  fix every finding before reporting the work as done       │      │
│         └─────────────────────────────┬──────────────────────────────┘      │
│                                       ▼                                     │
│         ┌────────────────────────────────────────────────────────────┐      │
│         │  CI gate (assets/ci.yml)                                   │      │
│         │  format, clang-tidy, check, Release, ASan, TSan, fuzz      │      │
│         └────────────────────────────────────────────────────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Order of Application:
1. AGENTS.md: Ask before guessing safety, protocol and timing values
2. cbd: Specify components, interfaces and timing contracts before writing code
3. architecture: Apply principles, threading, timing, security and recovery rules
4. cpp / cmake: Write sources and build scripts by the convention
5. testing: Verify with unit, fuzz, virtual integration, load and fault injection tests
6. verification: Run verify.sh and fix every finding before reporting the work as done
7. CI gate: Merge only when format, static analysis, check, sanitizer and fuzz jobs pass
```

---

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
