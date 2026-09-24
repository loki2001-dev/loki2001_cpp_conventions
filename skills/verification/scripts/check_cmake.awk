# CMake policy (cmake skill). commands spanning lines are joined before they are checked.
# per command: source globs, global commands, global flag variables, 3rdparty includes without SYSTEM.
# project level (root CMakeLists.txt): minimum version, compile_commands.json, warning flags,
# test registration

FNR == 1 {
    depth = 0
    command = ""
    prevRawLine = ""
    isRoot = (FILENAME == "CMakeLists.txt")
    isToolchain = (FILENAME ~ /toolchain/)
    if (isRoot) {
        rootSeen = 1
    }
}

{
    rawLine = $0
    text = stripCmake($0)
    if (depth == 0 && match(text, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) {
        commandName = substr(text, RSTART, RLENGTH)
        gsub(/[ \t(]/, "", commandName)
        commandName = tolower(commandName)
        command = ""
        commandLine = FNR
        commandRaw = rawLine
        commandPrev = prevRawLine
        text = substr(text, RSTART + RLENGTH - 1)
        depth = 0
    }
    if (commandName != "") {
        collectCommand(text)
    }
    prevRawLine = (text ~ /^[ \t]*$/) ? rawLine : ""
}

END {
    if (rootSeen) {
        checkProject()
    }
    finish()
}

function stripCmake(line,    out, i, n, c, quoted) {
    out = ""
    n = length(line)
    quoted = 0
    for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (c == "\"" && substr(line, i - 1, 1) != "\\") {
            quoted = !quoted
        } else if (c == "#" && !quoted) {
            break
        }
        out = out c
    }
    return out
}

function collectCommand(text,    i, n, c, quoted) {
    n = length(text)
    quoted = 0
    for (i = 1; i <= n; i++) {
        c = substr(text, i, 1)
        if (c == "\"") {
            quoted = !quoted
        } else if (!quoted && c == "(") {
            depth++
            if (depth == 1) {
                continue
            }
        } else if (!quoted && c == ")") {
            depth--
            if (depth == 0) {
                checkCommand(commandName, command)
                commandName = ""
                return
            }
        }
        command = command c
    }
    command = command " "
}

function creport(rule, message, fix) {
    if (markerAllows(commandRaw, rule) || markerAllows(commandPrev, rule)) {
        return
    }
    reportAt(FILENAME, commandLine, rule, message, fix)
}

function firstWord(args, index_,    parts) {
    split(args, parts, /[ \t]+/)
    if (parts[1] == "") {
        return parts[index_ + 1]
    }
    return parts[index_]
}

function checkCommand(name, args,    variable, target) {
    allArgs = allArgs " " args
    if (index(args, "MSVC") > 0) {
        msvcSeen = 1
    }
    if (name == "file" && args ~ /^[ \t]*GLOB(_RECURSE)?[ \t]/ && (args ~ /\.(c|cc|cpp|cxx|h|hh|hpp|hxx)([^A-Za-z]|$)/ || args ~ /(^|[ \t"\/])(src|tests?)\//)) {
        creport("CMAKE-GLOB", "source files are collected with file(" firstWord(args, 1) ")", "list every source file explicitly in add_library or add_executable")
    }
    if (name ~ /^(include_directories|link_libraries|link_directories|add_definitions|add_compile_definitions|add_compile_options|add_link_options)$/ && !isToolchain) {
        creport("CMAKE-GLOBAL-COMMAND", name "() changes every target in the directory", "use the target form: target_include_directories, target_link_libraries, target_compile_definitions, target_compile_options or target_link_options")
    }
    if (name == "set") {
        variable = firstWord(args, 1)
    } else if (name == "string" || name == "list") {
        variable = firstWord(args, 2)
    } else {
        variable = ""
    }
    if (variable ~ /^CMAKE_(C|CXX)_FLAGS(_[A-Z]+)?$/ || variable ~ /^CMAKE_(EXE|SHARED|MODULE)_LINKER_FLAGS(_[A-Z]+)?$/) {
        if (!isToolchain) {
            creport("CMAKE-GLOBAL-FLAGS", variable " sets flags for every target", "put the flags in a list variable and apply it with target_compile_options or target_link_options")
        }
    }
    if (name == "set" && variable == "CMAKE_EXPORT_COMPILE_COMMANDS" && toupper(firstWord(args, 2)) ~ /^(ON|TRUE|1)$/) {
        exportSeen = 1
    }
    if (name == "target_include_directories" && index(args, "3rdparty") > 0 && args !~ /(^|[ \t])SYSTEM([ \t]|$)/) {
        creport("CMAKE-3RDPARTY-SYSTEM", "third party headers are included without SYSTEM, so the warning policy applies to them", "add SYSTEM: target_include_directories(" firstWord(args, 1) " SYSTEM PUBLIC ...)")
    }
    if (name == "cmake_minimum_required" && isRoot) {
        minimumSeen = 1
        minimumVersion = args
        sub(/^.*VERSION[ \t]+/, "", minimumVersion)
        sub(/[^0-9.].*$/, "", minimumVersion)
        minimumLine = commandLine
    }
    if (name == "add_executable") {
        target = firstWord(args, 1)
        if (target !~ /^\$/ && args !~ /(^|[ \t])(IMPORTED|ALIAS)([ \t]|$)/ && target ~ /(^|[_-])tests?([_-]|$)/) {
            testTargets[target] = FILENAME ":" commandLine
            if (markerAllows(commandRaw, "CMAKE-TEST-REGISTER") || markerAllows(commandPrev, "CMAKE-TEST-REGISTER")) {
                testAllowed[target] = 1
            }
        }
    }
    if (name == "add_test") {
        addTestSeen = 1
        addTestArgs = addTestArgs " " args
    }
    if (name == "enable_testing" || (name == "include" && firstWord(args, 1) == "CTest")) {
        testingEnabled = 1
    }
}

function versionBelow(version, major, minor,    parts) {
    split(version, parts, ".")
    return (parts[1] + 0 < major) || (parts[1] + 0 == major && parts[2] + 0 < minor)
}

function checkProject(    missing, flags, n, k, target, at) {
    if (!minimumSeen) {
        reportAt("CMakeLists.txt", 1, "CMAKE-MIN-VERSION", "cmake_minimum_required is missing", "start the root CMakeLists.txt with cmake_minimum_required(VERSION 3.16)")
    } else if (versionBelow(minimumVersion, 3, 16)) {
        reportAt("CMakeLists.txt", minimumLine, "CMAKE-MIN-VERSION", "cmake_minimum_required(VERSION " minimumVersion ") is below 3.16", "use cmake_minimum_required(VERSION 3.16)")
    }
    if (!exportSeen && !presetExport) {
        reportAt("CMakeLists.txt", 1, "CMAKE-COMPILE-COMMANDS", "compile_commands.json is not generated, so clang-tidy cannot run", "add set(CMAKE_EXPORT_COMPILE_COMMANDS ON)")
    }
    missing = ""
    n = split("-Wall -Wextra -Wpedantic -Werror", flags, " ")
    for (k = 1; k <= n; k++) {
        if (!hasFlag(flags[k])) {
            missing = missing " " flags[k]
        }
    }
    if (msvcSeen) {
        n = split("/W4 /WX /utf-8", flags, " ")
        for (k = 1; k <= n; k++) {
            if (!hasFlag(flags[k])) {
                missing = missing " " flags[k]
            }
        }
    }
    if (missing != "") {
        reportAt("CMakeLists.txt", 1, "CMAKE-WARNINGS", "warning flags missing:" missing, "define PROJECT_WARNINGS as in the cmake skill and apply it with target_compile_options to every target")
    }
    for (target in testTargets) {
        if ((target in testAllowed) || hasWord(addTestArgs, target)) {
            continue
        }
        split(testTargets[target], at, ":")
        reportAt(at[1], at[2], "CMAKE-TEST-REGISTER", "test executable " target " is not registered with add_test", "add add_test(NAME " target " COMMAND " target ") so that ctest --timeout runs it")
    }
    if (addTestSeen && !testingEnabled) {
        reportAt("CMakeLists.txt", 1, "CMAKE-ENABLE-TESTING", "add_test is used but enable_testing() is missing, so ctest finds no tests", "call enable_testing() in the root CMakeLists.txt")
    }
}

# flags usually sit in generator expressions: $<$<CXX_COMPILER_ID:GNU>:-Wall -Werror>
function hasFlag(flag) {
    return match(allArgs, "(^|[ \t\"';:,>])" flag "([ \t\"';,>]|$)")
}
