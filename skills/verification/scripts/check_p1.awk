# P1: obvious breaks of loop-thread-only component code. P1 as a whole is not provable here

FNR == 1 {
    startFile()
}

{
    startLine()
    trackSubmit(codeLine)
    checkThread(codeLine)
    checkLock(codeLine)
    if (submitCapture != "") {
        checkWorkerCapture(submitCapture)
    }
    # the line that calls submit runs on the loop thread
    if (lineInWorker && codeLine !~ /submit[ \t]*\(/) {
        checkWorkerState(codeLine)
    }
    endLine()
}

END {
    finish()
}

function checkThread(text) {
    if (match(text, /std::(thread|jthread)([^:A-Za-z0-9_]|$)/) || match(text, /std::async[ \t]*[(<]/) || match(text, /(^|[^A-Za-z0-9_])(pthread_create|CreateThread|_beginthreadex)[ \t]*\(/)) {
        report("P1-THREAD", "loop-thread code creates its own thread", "submit blocking work to BlockingWorker in src/network and return the result with UvLoop::post")
    }
}

function checkLock(text) {
    if (match(text, /std::(mutex|recursive_mutex|timed_mutex|shared_mutex|lock_guard|unique_lock|scoped_lock|shared_lock|condition_variable)([^A-Za-z0-9_]|$)/)) {
        report("P1-LOCK", "lock in loop-thread code. component code runs on one thread and needs no lock", "remove the lock and cross threads only through UvLoop::post or StateStore")
    }
}

function checkWorkerCapture(capture,    n, parts, k, item) {
    n = split(capture, parts, ",")
    for (k = 1; k <= n; k++) {
        item = parts[k]
        gsub(/[ \t]/, "", item)
        if (item == "this" || item == "*this" || item == "&" || item == "=" || item ~ /^&[A-Za-z_][A-Za-z0-9_]*$/) {
            report("P1-WORKER-CAPTURE", "the blocking lambda passed to submit runs on the worker thread but captures " item, "capture copies or shared_ptr values (for example [client = _client, request, response]) and touch members only in the onDone lambda")
            return
        }
    }
}

function checkWorkerState(text) {
    if (match(text, /(^|[^A-Za-z0-9_.>])_[a-z][A-Za-z0-9_]*[ \t]*(=[^=]|\+=|-=|\+\+|--)/) || index(text, "this->") > 0) {
        report("P1-WORKER-STATE", "the worker thread changes component state", "return the result to the onDone lambda, which runs on the loop thread, and change state there")
    }
}
