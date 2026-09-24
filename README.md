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

| Tool | Needed for | Linux | Windows |
| ---- | ---------- | ----- | ------- |
| [Claude Code](https://docs.claude.com/en/docs/claude-code/setup) or [Codex](https://github.com/openai/codex) CLI | Running the plugin | Required | Required |
| git | Plugin install, `commit` check | Required | Git for Windows (includes Git Bash) |
| bash, POSIX awk | `setup` and `verification` scripts | Preinstalled on most distributions | Git Bash (bundled with Git for Windows) |
| Node.js 18 or later | Installing Codex with npm | Codex only | Codex only |
| clang-format, clang-tidy | `format` and `tidy` checks | Optional | Optional (LLVM) |

On Windows, run the plugin scripts in **Git Bash**, not in PowerShell or cmd. The repository keeps LF line endings (`.gitattributes`), so the scripts run as checked out.

---

## Install Instructions

The steps are the same for Claude Code and Codex except where noted. Install either CLI, or both.

### Linux

The commands are for Ubuntu 22.04 and 24.04. Use the equivalent package names on other distributions. awk is preinstalled (mawk on Ubuntu) and is enough for the scripts.

**1. Install the tools**
```bash
sudo apt-get update
sudo apt-get install -y git curl

# Optional: clang-format and clang-tidy for the format and tidy checks
sudo apt-get install -y clang-format clang-tidy

# Codex only: Node.js 18 or later (skip if node --version already prints v18 or later)
# Ubuntu 24.04 packages Node.js 18. Ubuntu 22.04 packages an older one, so install it from https://nodejs.org instead
sudo apt-get install -y nodejs npm
```

**2. Install the agent CLI**
```bash
# Claude Code (native installer)
curl -fsSL https://claude.ai/install.sh | bash
claude --version

# Codex
npm install -g @openai/codex
codex --version
```
Sign in once by running `claude` or `codex` and following the prompt.

**3. Add the marketplace and install the plugin**
```bash
# Claude Code
claude plugin marketplace add loki2001-dev/loki2001_cpp_conventions
claude plugin install cpp-conventions@loki2001

# Codex
codex plugin marketplace add loki2001-dev/loki2001_cpp_conventions
codex plugin add cpp-conventions@loki2001
```

**4. Install the global instructions**

Start a new session (`claude` or `codex`) and run:
```text
/cpp-conventions:setup
```
The agent explains that the global instructions will be replaced and asks for approval. After approval it writes:

| Agent | File |
| ----- | ---- |
| Codex | `~/.codex/AGENTS.md` (or `$CODEX_HOME/AGENTS.md`) |
| Claude Code | `~/.claude/CLAUDE.md` (or `$CLAUDE_CONFIG_DIR/CLAUDE.md`) |

An existing file is kept next to it as `AGENTS.md.conventions-backup.<UTC time>` or `CLAUDE.md.conventions-backup.<UTC time>`.

**5. Check the installation**
```bash
ls -l ~/.claude/CLAUDE.md ~/.codex/AGENTS.md
```
Open a new session. The instructions are read when a session starts. In Claude Code, `/plugin` lists the installed plugin and its skills.

**6. Optional: clone the repository to run the tests or `verify.sh` by hand**
```bash
git clone https://github.com/loki2001-dev/loki2001_cpp_conventions.git
cd loki2001_cpp_conventions
skills/verification/scripts/verify.sh /path/to/your/project
```

### Windows

Choose where the agent runs and follow that path only.

- **Native Windows** (PowerShell terminal): follow the steps below. Git Bash runs the scripts, and files go to `C:\Users\<name>\.claude` and `C:\Users\<name>\.codex`.
- **WSL**: open the WSL terminal and follow the [Linux](#linux) steps. Files go to the WSL home directory, which native Windows agents do not read.

**1. Install the tools** (PowerShell)
```powershell
winget install --id Git.Git -e

# Optional: clang-format and clang-tidy for the format and tidy checks
winget install --id LLVM.LLVM -e

# Codex only: Node.js LTS
winget install --id OpenJS.NodeJS.LTS -e
```
Close and reopen PowerShell so that the new `PATH` applies. Check with `git --version`.

**2. Install the agent CLI** (PowerShell)
```powershell
# Claude Code (native installer). It uses Git Bash from Git for Windows
irm https://claude.ai/install.ps1 | iex
claude --version

# Codex
npm install -g @openai/codex
codex --version
```
Sign in once by running `claude` or `codex`. See the [Claude Code](https://docs.claude.com/en/docs/claude-code/setup) and [Codex](https://github.com/openai/codex) documentation for the current Windows support and requirements.

**3. Add the marketplace and install the plugin** (PowerShell)
```powershell
# Claude Code
claude plugin marketplace add loki2001-dev/loki2001_cpp_conventions
claude plugin install cpp-conventions@loki2001

# Codex
codex plugin marketplace add loki2001-dev/loki2001_cpp_conventions
codex plugin add cpp-conventions@loki2001
```

**4. Install the global instructions**

Start a new session and run `/cpp-conventions:setup`, as on Linux. Claude Code runs the script through Git Bash.

If the agent cannot run bash scripts, run the setup yourself in **Git Bash**:
```bash
git clone https://github.com/loki2001-dev/loki2001_cpp_conventions.git
cd loki2001_cpp_conventions
skills/setup/scripts/setup --force
```

| Agent | File |
| ----- | ---- |
| Codex | `%USERPROFILE%\.codex\AGENTS.md` (or `%CODEX_HOME%\AGENTS.md`) |
| Claude Code | `%USERPROFILE%\.claude\CLAUDE.md` (or `%CLAUDE_CONFIG_DIR%\CLAUDE.md`) |

**5. Check the installation** (PowerShell)
```powershell
Test-Path "$env:USERPROFILE\.claude\CLAUDE.md"
Test-Path "$env:USERPROFILE\.codex\AGENTS.md"
```
Both print `True` for the agents you set up. Open a new session so that the instructions are read.

**6. Optional: run `verify.sh` by hand** (Git Bash)
```bash
cd /c/path/to/loki2001_cpp_conventions
skills/verification/scripts/verify.sh /c/path/to/your/project
```
Git Bash writes Windows drives as `/c/...`. `format` and `tidy` run only when LLVM is on `PATH`, otherwise they report `skipped`.

### Restore the previous global instructions

The setup replaces the whole file. To go back, copy the backup over it (Linux or Git Bash):
```bash
ls ~/.claude/CLAUDE.md.conventions-backup.*
cp ~/.claude/CLAUDE.md.conventions-backup.<UTC time> ~/.claude/CLAUDE.md
```
The same applies to `~/.codex/AGENTS.md`.

### Troubleshooting

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `$'\r': command not found` or `bad interpreter` | The scripts have CRLF endings (a copy made before `.gitattributes` was added, or an editor converted them) | Clone the repository again, or reinstall the plugin |
| `claude` or `codex` not found after install | `PATH` is not refreshed | Open a new terminal. On Windows, reopen PowerShell |
| `awk: command not found` on Windows | The script runs in PowerShell or cmd | Run it in Git Bash |
| `format: error: clang-format not found` | LLVM is not installed or not on `PATH` | Install clang-format, or set `CLANG_FORMAT` to its full path |
| Rules are not applied in a session | The session started before the setup | Start a new session |

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
