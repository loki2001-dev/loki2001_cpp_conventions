# Changelog

Breaking changes are marked with **Breaking**. The version must match the three plugin manifests.

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
