# P5: member queues need a capacity and an overflow policy, and drops are logged.
#
# run as: awk -f common.awk -f check_p5.awk pass=1 FILES pass=2 FILES
# pass 1 collects per header and source pair (same path without the extension):
#   - std::queue, std::deque, std::priority_queue members (_name, cpp naming rules)
#   - members whose size() is compared with something (a capacity check)
#   - BoundedQueue members and the overflow_policy they are constructed with
# pass 2 checks every BoundedQueue push. END reports unbounded members.
# locals and function parameters are temporary containers and are never checked

FNR == 1 {
    if (pass == 2 && pendingLog) {
        reportDropNotLogged()
    }
    startFile()
    pairKey = FILENAME
    sub(/\.[^.\/]*$/, "", pairKey)
    pushTracking = 0
}

pass == 1 {
    startLine()
    collect(codeLine)
    endLine()
    next
}

pass == 2 {
    startLine()
    checkPush(codeLine)
    endLine()
}

END {
    if (pendingLog) {
        reportDropNotLogged()
    }
    reportUnbounded()
    finish()
}

function collect(text,    rest, name, key, type) {
    if (match(text, /std::(queue|deque|priority_queue)[ \t]*</) && match(text, /_[A-Za-z0-9_]*[ \t]*(\{[^;]*\}|=[^;]*)?;[ \t]*$/)) {
        type = text
        sub(/^[ \t]*/, "", type)
        sub(/<.*$/, "", type)
        name = substr(text, RSTART, RLENGTH)
        sub(/[^A-Za-z0-9_].*$/, "", name)
        key = pairKey SUBSEP name
        queueAt[key] = FILENAME ":" FNR
        queueType[key] = type
        if (suppressed("P5-UNBOUNDED")) {
            queueAllowed[key] = 1
        }
    }
    if (match(text, /BoundedQueue[ \t]*<.*>[ \t]*_[A-Za-z0-9_]*[ \t]*;/)) {
        name = substr(text, RSTART, RLENGTH)
        sub(/[ \t]*;$/, "", name)
        sub(/.*[^A-Za-z0-9_]/, "", name)
        bounded[pairKey SUBSEP name] = 1
    }
    if (match(text, /_[A-Za-z0-9_]*[ \t]*[({][^;]*overflow_policy::(drop_oldest|reject)/)) {
        rest = substr(text, RSTART, RLENGTH)
        name = rest
        sub(/[^A-Za-z0-9_].*$/, "", name)
        sub(/.*overflow_policy::/, "", rest)
        policy[pairKey SUBSEP name] = rest
    }
    if (isComparison(stripTemplates(text))) {
        rest = text
        while (match(rest, /_[A-Za-z0-9_]*[ \t]*\.[ \t]*size[ \t]*\([ \t]*\)/)) {
            name = substr(rest, RSTART, RLENGTH)
            sub(/[^A-Za-z0-9_].*$/, "", name)
            sized[pairKey SUBSEP name] = 1
            rest = substr(rest, RSTART + RLENGTH)
        }
    }
}

function checkPush(text,    key, name, found, at) {
    if (pendingLog && match(text, /LOG_(WARN|ERROR)[ \t]*\(/)) {
        pendingLog = 0
    }
    if (pendingLog && FNR > pendingUntil) {
        reportDropNotLogged()
    }
    if (pushTracking) {
        trackPushStatement(text, 1)
        return
    }
    for (key in bounded) {
        split(key, found, SUBSEP)
        if (found[1] != pairKey) {
            continue
        }
        name = found[2]
        if (!match(text, "(^|[^A-Za-z0-9_])" name "[ \\t]*\\.[ \\t]*push[ \\t]*\\(")) {
            continue
        }
        at = RSTART + RLENGTH - 1
        if (text ~ ("^[ \\t]*(\\(void\\)[ \\t]*)?" name "[ \\t]*\\.[ \\t]*push[ \\t]*\\(")) {
            report("P5-PUSH-IGNORED", "push result of bounded queue " name " is ignored, so overflow is silent", "check the push_result: log dropped_total for drop_oldest, or return the rejection to the caller")
            return
        }
        if (policy[pairKey SUBSEP name] == "drop_oldest" && text !~ /(^|[^A-Za-z0-9_])return([^A-Za-z0-9_]|$)/ && !suppressed("P5-DROP-NOT-LOGGED")) {
            pushTracking = 1
            pushParen = 0
            pushName = name
            pushLine = FNR
            trackPushStatement(substr(text, at), 0)
        }
        return
    }
}

# waits until the push statement closes, then expects a LOG_WARN or LOG_ERROR within five lines
function trackPushStatement(text, continued,    i, n, c) {
    n = length(text)
    for (i = 1; i <= n; i++) {
        c = substr(text, i, 1)
        if (c == "(") {
            pushParen++
        } else if (c == ")") {
            pushParen--
            if (pushParen == 0) {
                pushTracking = 0
                pendingLog = 1
                pendingUntil = FNR + 5
                pendingFile = FILENAME
                pendingLine = pushLine
                pendingName = pushName
                if (match(substr(text, i), /LOG_(WARN|ERROR)[ \t]*\(/)) {
                    pendingLog = 0
                }
                return
            }
        }
    }
}

function reportDropNotLogged() {
    pendingLog = 0
    reportAt(pendingFile, pendingLine, "P5-DROP-NOT-LOGGED", "drop_oldest queue " pendingName " drops without a log", "when push does not return push_result::accepted, LOG_WARN the running dropped_total")
}

function reportUnbounded(    key, found, at) {
    for (key in queueAt) {
        if ((key in sized) || (key in queueAllowed)) {
            continue
        }
        split(key, found, SUBSEP)
        split(queueAt[key], at, ":")
        reportAt(at[1], at[2], "P5-UNBOUNDED", "member queue " found[2] " (" queueType[key] ") has no capacity check", "use BoundedQueue<T>(capacity, overflow_policy::drop_oldest or reject), or compare " found[2] ".size() with a capacity before pushing and count the drops")
    }
}
