# P3: external lengths, counts, indexes and offsets used as buffer bounds without a range check.
#
# a value is external when it is
#   - the output argument of a reader call:          reader.readU16Be(length)
#   - byte-order converted:                          count = ntohs(raw)
#   - read out of a raw external buffer:             offset = data[4], (data[1] << 8) | data[2]
#   - computed from another external value:          end = offset + length
# a value is checked once it appears in a comparison, in an if or while condition, or in
# std::min, std::clamp or .at(). loop bounds in a for header do not count as a check
#
# raw external buffers are parameters of type uint8_t*, unsigned char*, std::byte*, or char*
# named like data or buf, plus get_data() and libuv buf->base

FNR == 1 {
    startFile()
    resetFunction()
}

{
    startLine()
    text = stripTemplates(codeLine)
    if (isFunctionStart(text)) {
        resetFunction()
        collectBufferParams(text)
    }
    checkFixedOffset(text)
    checkSinks(text)
    collectChecks(text)
    collectExternal(text)
    endLine()
}

END {
    finish()
}

function resetFunction() {
    split("", external)
    split("", boundBy)
    split("", checked)
    split("", buffers)
    sizeChecked = 0
}

function isFunctionStart(text,    trimmed) {
    trimmed = text
    sub(/^[ \t]+/, "", trimmed)
    if (trimmed ~ /^(if|for|while|switch|return|else|do|catch|case|delete|new|throw|using|typedef)([^A-Za-z0-9_]|$)/) {
        return 0
    }
    if (index(trimmed, ";") > 0 || index(trimmed, "=") > 0 || index(trimmed, "[") > 0) {
        return 0
    }
    if (trimmed ~ /^[A-Za-z_][A-Za-z0-9_]*::~?[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/) {
        return 1
    }
    return trimmed ~ /^[A-Za-z_"][A-Za-z0-9_:<>,\*&~" \t]*[ \t\*&]~?[A-Za-z_][A-Za-z0-9_:~]*[ \t]*\(/
}

function collectBufferParams(text,    rest, name) {
    rest = text
    while (match(rest, /(uint8_t|unsigned[ \t]+char|std::byte|char)[ \t]*(const[ \t]*)?\*[ \t]*[A-Za-z_][A-Za-z0-9_]*/)) {
        name = substr(rest, RSTART, RLENGTH)
        sub(/.*[\* \t]/, "", name)
        if (name !~ /^[A-Za-z_]/) {
            rest = substr(rest, RSTART + RLENGTH)
            continue
        }
        if (substr(rest, RSTART, 4) != "char" || name ~ /^(data|buf|buffer|bytes|payload|frame|packet|raw|rx)/) {
            buffers[name] = 1
        }
        rest = substr(rest, RSTART + RLENGTH)
    }
}

function readsExternalBuffer(text,    name) {
    if (index(text, "get_data()[") > 0 || match(text, /->base[ \t]*\[/)) {
        return 1
    }
    for (name in buffers) {
        if (match(text, "(^|[^A-Za-z0-9_.>])" name "[ \t]*\\[")) {
            return 1
        }
    }
    return 0
}

# sizes compared anywhere before a fixed offset read
function collectChecks(text,    name, condition) {
    condition = (text ~ /(^|[^A-Za-z0-9_])(if|while)[ \t]*\(/ || index(text, "?") > 0)
    if (isComparison(text) && text ~ /(size|Size|length|Length|len|Len|remaining|Remaining|nread|count|Count)/) {
        sizeChecked = 1
    }
    for (name in external) {
        if (!hasWord(text, name)) {
            continue
        }
        if (text ~ /(^|[^A-Za-z0-9_])for[ \t]*\(/) {
            continue
        }
        if (condition || isComparison(text) || match(text, "(std::min|std::max|std::clamp|\\.at)[ \t]*\\([^;]*" name)) {
            checked[name] = 1
        }
    }
}

function collectExternal(text,    rest, name, lhs, rhs, eq, other) {
    rest = text
    while (match(rest, /(\.|->)read[A-Za-z0-9_]*[ \t]*\([ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\)/)) {
        name = substr(rest, RSTART, RLENGTH)
        sub(/^.*\([ \t]*/, "", name)
        sub(/[ \t]*\)$/, "", name)
        markExternal(name, FNR)
        rest = substr(rest, RSTART + RLENGTH)
    }
    if (text ~ /(^|[^A-Za-z0-9_])for[ \t]*\(/) {
        collectLoopBound(text)
        return
    }
    eq = assignmentAt(text)
    if (eq == 0) {
        return
    }
    lhs = substr(text, 1, eq - 1)
    rhs = substr(text, eq + 1)
    sub("[-+*/|&]$", "", lhs)
    sub(/[ \t]+$/, "", lhs)
    if (!match(lhs, /[A-Za-z_][A-Za-z0-9_]*$/)) {
        return
    }
    name = substr(lhs, RSTART, RLENGTH)
    if (substr(lhs, RSTART - 1, 1) ~ /[.>]/) {
        return
    }
    if (rhs ~ /std::(min|max|clamp)[ \t]*\(/) {
        checked[name] = 1
        return
    }
    if (rhs ~ /(ntohs|ntohl|be16toh|be32toh|be64toh|le16toh|le32toh|le64toh|bswap_16|bswap_32|bswap_64)[ \t]*\(/ || readsExternalBuffer(rhs)) {
        markExternal(name, FNR)
        return
    }
    for (other in external) {
        if (other != name && hasWord(rhs, other) && !(other in checked)) {
            markExternal(name, external[other])
            return
        }
    }
}

# position of the first plain or compound assignment, 0 when there is none
function assignmentAt(text,    i, n, c, before, after) {
    n = length(text)
    for (i = 2; i <= n; i++) {
        c = substr(text, i, 1)
        if (c != "=") {
            continue
        }
        before = substr(text, i - 1, 1)
        after = substr(text, i + 1, 1)
        if (after == "=" || before == "=" || before == "!" || before == "<" || before == ">") {
            i++
            continue
        }
        return i
    }
    return 0
}

function markExternal(name, line) {
    if (name in external) {
        return
    }
    external[name] = line
}

# for (size_t i = 0; i < count; ++i): i indexes as far as the unchecked count allows
function collectLoopBound(text,    name, loop) {
    for (name in external) {
        if (name in checked) {
            continue
        }
        if (match(text, "[A-Za-z_][A-Za-z0-9_]*[ \t]*<=?[ \t]*" name "([^A-Za-z0-9_]|$)")) {
            loop = substr(text, RSTART, RLENGTH)
            sub(/[ \t]*<.*$/, "", loop)
            markExternal(loop, external[name])
            boundBy[loop] = name
            return
        }
    }
}

function checkSinks(text,    name) {
    for (name in external) {
        if ((name in checked) || !hasWord(text, name)) {
            continue
        }
        # if (index < COUNT && table[index]) checks before it indexes
        if (isComparison(text)) {
            continue
        }
        if (!usedAsSubscript(text, name) && !usedAsBound(text, name)) {
            continue
        }
        if (name in boundBy) {
            report("P3-UNCHECKED", "loop index " name " runs up to external count " boundBy[name] " (read at line " external[name] ") and indexes a buffer without a range check", "compare " boundBy[name] " with the buffer capacity or a ceiling constant before the loop, or store only what was actually read")
        } else {
            report("P3-UNCHECKED", "external value " name " (read at line " external[name] ") is used as a buffer bound without a range check", "compare " name " with the remaining size or a ceiling constant and drop the frame when it is out of range, or read through FrameReader")
        }
        return
    }
}

function usedAsSubscript(text, name,    rest, inside, closeAt, base) {
    rest = text
    while (match(rest, /\[[^]]*\]/)) {
        inside = substr(rest, RSTART, RLENGTH)
        closeAt = RSTART + RLENGTH
        base = substr(rest, 1, RSTART - 1)
        base = match(base, /[A-Za-z_][A-Za-z0-9_]*[ \t]*$/) ? substr(base, RSTART, RLENGTH) : ""
        sub(/[ \t]+$/, "", base)
        # a lambda capture list or an attribute is not a subscript. map[key] does not overflow
        if (substr(rest, closeAt, 1) !~ /[({]/ && substr(inside, 1, 2) != "[[" && !isMap(base) && hasWord(inside, name)) {
            return 1
        }
        rest = substr(rest, closeAt)
    }
    return 0
}

# mapNames: names declared as std::map or std::unordered_map anywhere in the sources (check_p3.sh)
function isMap(base) {
    return base != "" && index(" " mapNames " ", " " base " ") > 0
}

function usedAsBound(text, name,    start) {
    if (match(text, /(memcpy|memmove|memset|strncpy|copy_n|\.resize|\.reserve)[ \t]*\(/) || match(text, /ByteView([ \t]+[A-Za-z_][A-Za-z0-9_]*)?[ \t]*[({]/)) {
        return hasWord(substr(text, RSTART), name)
    }
    if (match(text, /new[ \t]+[A-Za-z_][A-Za-z0-9_:]*[ \t]*\[/)) {
        start = RSTART
        return hasWord(substr(text, start), name)
    }
    return 0
}

function checkFixedOffset(text,    name) {
    if (sizeChecked) {
        return
    }
    if (match(text, /(get_data\(\)|->base)[ \t]*\[[ \t]*([0-9]+|[A-Z][A-Z0-9_]*)[ \t]*\]/)) {
        report("P3-FIXED-OFFSET", "fixed offset read from an external buffer before any length check", "read through FrameReader, or check the size before reading")
        return
    }
    for (name in buffers) {
        if (match(text, "(^|[^A-Za-z0-9_.>])" name "[ \t]*\\[[ \t]*([0-9]+|[A-Z][A-Z0-9_]*)[ \t]*\\]")) {
            report("P3-FIXED-OFFSET", "fixed offset read from external buffer " name " before any length check", "read through FrameReader, or check the size before reading")
            return
        }
    }
}
