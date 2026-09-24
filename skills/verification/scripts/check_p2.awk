# P2: blocking calls in loop-thread code. the first lambda of submit() runs on a worker and is skipped

FNR == 1 {
    startFile()
    split("", futures)
}

{
    startLine()
    trackSubmit(codeLine)
    if (!lineInWorker) {
        checkBlocking(codeLine)
    }
    endLine()
}

END {
    finish()
}

function checkBlocking(text,    name) {
    if (match(text, /(std::)?future<[^;]*>[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        name = substr(text, RSTART, RLENGTH)
        sub(/.*[ \t]/, "", name)
        futures[name] = 1
    }
    if (match(text, /this_thread::sleep_(for|until)[ \t]*\(/) || match(text, /(^|[^A-Za-z0-9_.>])(sleep|usleep|nanosleep|Sleep)[ \t]*\(/)) {
        report("P2-SLEEP", "sleep blocks the loop thread", "schedule the next step with a UvTimer, or move the call into BlockingWorker::submit")
        return
    }
    if (match(text, /(\.|->)(wait|wait_for|wait_until)[ \t]*\(/)) {
        report("P2-WAIT", "blocking wait on the loop thread", "deliver the result with UvLoop::post or a callback instead of waiting")
        return
    }
    for (name in futures) {
        if (match(text, "(^|[^A-Za-z0-9_])" name "[ \t]*\\.[ \t]*get[ \t]*\\(")) {
            report("P2-WAIT", "future::get blocks the loop thread until the result is ready", "deliver the result with UvLoop::post or a callback instead of waiting")
            return
        }
    }
    if (match(text, /(^|[^A-Za-z0-9_])::(connect|accept|recv|recvfrom|recvmsg|read|write|send|sendto|select|poll|epoll_wait)[ \t]*\(/)) {
        report("P2-SOCKET", "synchronous socket or file descriptor call blocks the loop thread", "use the non-blocking libuv transport, or run the call on a dedicated thread in src/network")
        return
    }
    if (match(text, /(^|[^A-Za-z0-9_.>])(getaddrinfo|gethostbyname|gethostbyname_r)[ \t]*\(/)) {
        report("P2-DNS", "synchronous name resolution blocks the loop thread", "use uv_getaddrinfo with a callback, or resolve on a dedicated thread")
        return
    }
    if (match(text, /(^|[^A-Za-z0-9_.>])(system|popen|pclose)[ \t]*\(/) || (match(text, /(^|[^A-Za-z0-9_.>])waitpid[ \t]*\(/) && index(text, "WNOHANG") == 0)) {
        report("P2-PROCESS", "waiting for a child process blocks the loop thread", "use uv_spawn with an exit callback, or waitpid with WNOHANG")
        return
    }
    if (index(text, "std::cin") > 0) {
        report("P2-STDIN", "reading standard input blocks the loop thread", "read input on a dedicated thread and post it to the loop")
        return
    }
    if (match(text, /(^|[^A-Za-z0-9_])uv_run[ \t]*\(/)) {
        report("P2-LOOP-RUN", "running a libuv loop inside loop-thread code blocks the owning loop", "only UvLoop::run in the app layer runs the loop. use timers and callbacks here")
        return
    }
    if (match(text, /(^|[^A-Za-z0-9_])uv_fs_[a-z_]+[ \t]*\(.*(nullptr|NULL)[ \t]*\)/)) {
        report("P2-SYNC-FS", "libuv fs call without a callback runs synchronously", "pass a completion callback")
        return
    }
    if (match(text, /(^|[^A-Za-z0-9_])(MQTTClient_connect|MQTTClient_publish|MQTTClient_publishMessage|MQTTClient_waitForCompletion|MQTTClient_receive|curl_easy_perform|lws_service)[ \t]*\(/)) {
        report("P2-SYNC-API", "synchronous network library call on the loop thread", "run it on a dedicated thread in src/network and return the result with UvLoop::post")
    }
}
