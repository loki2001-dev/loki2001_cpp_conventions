# Changelog

Breaking changes are marked with **Breaking**. The version must match the three plugin manifests.

## Unreleased

- `verification` skill: `verify.sh` runs clang-format, CMake policy, commit message, convention, clang-tidy and P1, P2, P3, P5 checks and prints `file:line: [RULE] reason. fix: direction`
- Agents apply the verification skill and resolve every failure before reporting completion
- Fix: `.clang-format` used `BreakTemplateDeclarations`, which clang-format 18 (Ubuntu 24.04, the CI template) rejects. It now uses `AlwaysBreakTemplateDeclarations`
- Fix: the test helper example in `cpp` patterns was not clang-formatted

## 0.3.0

- Agent decision and clarification rules: ask instead of guessing safety, protocol and timing values
- Deadlock, crash, SIGSEGV and zombie prevention rules, sanitizer builds and zero-tolerance test criteria
- Convention enforcement: `scripts/check`, CI workflow template, `clang-analyzer-*` in `.clang-tidy`
- Fuzz testing for codecs and parsers with libFuzzer
- Timing and performance contract in the component spec and design record
- Principle exception tracking with `EX-P{n}-{nnn}` markers
- Security rules: TLS, command authentication, secrets, privileges
- Interface evolution and versioning rules, build info header
- Fix: `BlockingWorker::stop()` changed the wait predicate without the mutex and could hang `join()`
- **Breaking**: `.clang-tidy` now enforces method and function naming. Existing projects may need renames

## 0.2.0

- Skills: `cbd`, `architecture`, `cpp`, `testing`, `cmake`, `setup`
