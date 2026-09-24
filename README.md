# loki2001_cpp_conventions

---

- Personal C++ conventions for agentic development with Claude Code and Codex
- Distributed as a plugin (`cpp-conventions@loki2001`) for both Claude Code and Codex
- Built on the Radar Verification Tool source code policy and the MOLIT-15 integrated control software design
- Designed for control software: components, threads, queues, device links, recovery and safety
- <span style="color:deepskyblue; font-weight:bold">`/cpp-conventions:setup` replaces the global agent instructions (backups are kept)</span>
- Setup script and tests require bash

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
- Global Instructions: Installs <span style="color:deepskyblue; font-weight:bold">`instructions/AGENTS.md`</span> as `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md`

---

## Skills

| Skill          | Scope                                                                 |
| -------------- | --------------------------------------------------------------------- |
| `cbd`          | Component-based development process, component rules, spec template   |
| `architecture` | Principles, layers, threading, queues, codecs, recovery, safety, logs |
| `cpp`          | Source code policy, patterns, clang-format and clang-tidy configs     |
| `testing`      | Unit tests, virtual integration tests, load and fault injection       |
| `cmake`        | Target-based CMake, MSVC and GCC warning policy                       |
| `setup`        | Installs `instructions/AGENTS.md` globally                            |

---

## Getting Started

### Prerequisites
- [Claude Code](https://claude.com/claude-code) or [Codex](https://github.com/openai/codex) CLI
- bash (for the `setup` skill and its test)

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
```

---

## Project Structure
```
loki2001_cpp_conventions/
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
│   │   ├── SKILL.md                        # Principles, threading, queues, recovery
│   │   └── references/
│   │       ├── design-record.md            # Design record template
│   │       └── patterns.md                 # Architecture patterns
│   │
│   ├── cpp/                                # Source code policy
│   │   ├── SKILL.md                        # Naming, style, pointers, errors, logs
│   │   ├── assets/
│   │   │   ├── .clang-format               # clang-format config
│   │   │   └── .clang-tidy                 # clang-tidy config
│   │   └── references/
│   │       └── patterns.md                 # C++ patterns
│   │
│   ├── testing/                            # Test strategy
│   │   └── SKILL.md                        # Unit, integration, load, fault injection
│   │
│   ├── cmake/                              # Build convention
│   │   └── SKILL.md                        # Target-based CMake, warning policy
│   │
│   └── setup/                              # Global instructions installer
│       ├── SKILL.md                        # Setup skill
│       ├── scripts/
│       │   └── setup                       # Installs AGENTS.md with backups
│       └── tests/
│           └── test                        # Setup script test
│
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
│   │  (instructions/      │  installed by /cpp-conventions:setup             │
│   │   AGENTS.md)         │                                                  │
│   └──────────┬───────────┘                                                  │
│              │                                                              │
│              ▼                                                              │
│   ┌──────────────────────┐    ┌──────────────────────┐                      │
│   │  cbd                 │───▶│  architecture        │                      │
│   │  (Components, specs, │    │  (Threads, queues,   │                      │
│   │   assembly order)    │    │   codecs, recovery)  │                      │
│   └──────────────────────┘    └──────────┬───────────┘                      │
│                                          │                                  │
│                    ┌─────────────────────┼─────────────────────┐            │
│                    ▼                     ▼                     ▼            │
│         ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│         │  cpp             │  │  cmake           │  │  testing         │    │
│         │  (Source code    │  │  (Targets,       │  │  (Catch2, fake   │    │
│         │   policy)        │  │   warnings)      │  │   devices, load) │    │
│         └──────────────────┘  └──────────────────┘  └──────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Order of Application:
1. cbd: Specify components and interfaces before writing code
2. architecture: Apply design principles, threading, queues and recovery rules
3. cpp / cmake: Write sources and build scripts by the convention
4. testing: Verify with unit, virtual integration, load and fault injection tests
```

---

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
