# shared functions for the verification checks. POSIX awk only (mawk, busybox, gawk)
#
# every check calls startFile() on FNR == 1, startLine() first and endLine() last on every
# record, and finish() at the end. startLine() sets:
#   rawLine   the line as written
#   codeLine  the line without comments and string literal contents
# markers that allow a finding: "// exception: EX-P2-001 reason" (an approved exception in the
# design record) or "// NOVERIFY(P2-SLEEP) reason" (a false positive), on the same line or on a
# comment line right above

function startFile() {
    inBlockComment = 0
    prevRawLine = ""
    submitActive = 0
    lineInWorker = 0
}

function startLine() {
    rawLine = $0
    codeLine = stripCode($0)
}

# a marker on the previous line counts only when that line holds no code
function endLine() {
    prevRawLine = (codeLine ~ /^[ \t]*$/) ? rawLine : ""
}

function finish() {
    printf "@@count %d\n", violations
}

# removes comments and the contents of string and character literals
function stripCode(line,    out, i, n, c, pair, quote) {
    out = ""
    n = length(line)
    i = 1
    while (i <= n) {
        c = substr(line, i, 1)
        pair = substr(line, i, 2)
        if (inBlockComment) {
            if (pair == "*/") {
                inBlockComment = 0
                i += 2
            } else {
                i++
            }
            continue
        }
        if (pair == "/*") {
            inBlockComment = 1
            i += 2
            continue
        }
        if (pair == "//") {
            break
        }
        if (c == "\"" || c == "'") {
            quote = c
            out = out quote quote
            i++
            while (i <= n) {
                c = substr(line, i, 1)
                if (c == "\\") {
                    i += 2
                    continue
                }
                i++
                if (c == quote) {
                    break
                }
            }
            continue
        }
        out = out c
        i++
    }
    return out
}

# removes template argument lists so that "<" and ">" only remain as comparisons
function stripTemplates(text) {
    while (match(text, /<[A-Za-z0-9_:, \t\*&]*>/)) {
        text = substr(text, 1, RSTART - 1) " " substr(text, RSTART + RLENGTH)
    }
    return text
}

# true when text still has a relational operator after shifts and member arrows are removed.
# call stripTemplates first
function isComparison(text) {
    gsub(/<<|>>|->/, " ", text)
    return text ~ /[<>]/
}

# true when name occurs in text as a whole identifier
function hasWord(text, name) {
    return match(text, "(^|[^A-Za-z0-9_])" name "([^A-Za-z0-9_]|$)")
}

# "P2-SLEEP" -> "P2", "CMAKE-GLOB" -> "CMAKE"
function principleOf(rule,    principle) {
    principle = rule
    sub(/-.*$/, "", principle)
    return principle
}

# an approved exception marker (architecture skill) or a NOVERIFY marker with a reason
function markerAllows(text, rule,    principle, list, n, parts, k) {
    principle = principleOf(rule)
    if (match(text, /exception:[ \t]*EX-P[1-5]-[0-9][0-9][0-9][ \t]+[^ \t]/)) {
        if (index(substr(text, RSTART, RLENGTH), "EX-" principle "-") > 0) {
            return 1
        }
    }
    if (match(text, /NOVERIFY\([A-Z0-9, -]+\)[ \t]+[^ \t]/)) {
        list = substr(text, RSTART + 9, RLENGTH - 9)
        sub(/\).*$/, "", list)
        n = split(list, parts, /[ ,]+/)
        for (k = 1; k <= n; k++) {
            if (parts[k] == rule || parts[k] == principle) {
                return 1
            }
        }
    }
    return 0
}

function suppressed(rule) {
    return markerAllows(rawLine, rule) || markerAllows(prevRawLine, rule)
}

function reportAt(file, line, rule, message, fix) {
    printf "%s:%d: [%s] %s. fix: %s\n", file, line, rule, message, fix
    violations++
}

# reports on the current line unless a marker on this or the previous line allows it
function report(rule, message, fix) {
    if (suppressed(rule)) {
        return
    }
    reportAt(FILENAME, FNR, rule, message, fix)
}

# follows BlockingWorker::submit(blockingCall, onDone) calls across lines.
# lineInWorker is 1 when part of the line is inside the first lambda body, which runs on the
# worker thread. submitCapture holds the first lambda capture list on the line it closes
function trackSubmit(text,    i, n, c, start) {
    lineInWorker = (submitActive && submitLambda == 1)
    submitCapture = ""
    start = 1
    if (!submitActive && match(text, /(\.|->)submit[ \t]*\(/)) {
        submitActive = 1
        submitParen = 0
        submitLambda = 0
        submitBrace = 0
        submitCaptureOpen = 0
        submitCaptureText = ""
        start = RSTART + RLENGTH - 1
    }
    if (!submitActive) {
        return
    }
    n = length(text)
    for (i = start; i <= n; i++) {
        c = substr(text, i, 1)
        if (submitCaptureOpen) {
            if (c == "]") {
                submitCaptureOpen = 0
                submitCapture = submitCaptureText
            } else {
                submitCaptureText = submitCaptureText c
            }
            continue
        }
        if (c == "[" && submitLambda == 0 && submitCapture == "" && submitCaptureText == "") {
            submitCaptureOpen = 1
        } else if (c == "(") {
            submitParen++
        } else if (c == ")") {
            submitParen--
            if (submitParen == 0) {
                submitActive = 0
                return
            }
        } else if (c == "{") {
            if (submitLambda == 0) {
                submitLambda = 1
                submitBrace = 1
                lineInWorker = 1
            } else if (submitLambda == 1) {
                submitBrace++
            }
        } else if (c == "}" && submitLambda == 1) {
            submitBrace--
            if (submitBrace == 0) {
                submitLambda = 2
            }
        }
    }
}
