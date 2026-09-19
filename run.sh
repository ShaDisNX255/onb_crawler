#!/usr/bin/env bash

set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

SERVER="${SERVER:-$DIR/net_battle_server}"
PORT="${PORT:-7777}"

LOG="$DIR/log.txt"
SERVER_PIDFILE="$DIR/server.pid"
GENERATOR_PIDFILE="$DIR/generator.pid"

GENERATOR="$DIR/tools/dungeon-generator/generator_server.js"
READY_FILE="$DIR/runtime/dungeon_pool/READY"

have_pid() {
    local pid="${1:-}"
    [[ -n "$pid" ]] &&
        kill -0 "$pid" 2>/dev/null
}

stop_process_group() {
    local pid="$1"

    if ! have_pid "$pid"; then
        return 0
    fi

    kill -TERM -"${pid}" 2>/dev/null || true
    pkill -TERM -P "${pid}" 2>/dev/null || true
    kill -TERM "${pid}" 2>/dev/null || true

    for _ in {1..10}; do
        have_pid "$pid" || break
        sleep 0.3
    done

    if have_pid "$pid"; then
        kill -KILL -"${pid}" 2>/dev/null || true
        pkill -KILL -P "${pid}" 2>/dev/null || true
        kill -KILL "${pid}" 2>/dev/null || true
    fi
}

start_generator() {
    local pid=""

    if [[ -f "$GENERATOR_PIDFILE" ]]; then
        pid="$(
            cat "$GENERATOR_PIDFILE" \
                2>/dev/null || true
        )"

        if ! have_pid "$pid"; then
            rm -f "$GENERATOR_PIDFILE"
            pid=""
        fi
    fi

    if [[ -z "$pid" ]]; then
        rm -f "$READY_FILE"

        if command -v setsid >/dev/null 2>&1; then
            nohup setsid \
                node "$GENERATOR" \
                >> "$LOG" 2>&1 &
        else
            nohup node "$GENERATOR" \
                >> "$LOG" 2>&1 &
        fi

        pid=$!
        echo "$pid" > "$GENERATOR_PIDFILE"

        echo "Dungeon generator started (pid $pid)."
    else
        echo "Dungeon generator already running (pid $pid)."
    fi

    echo "Waiting for dungeon generator..."

    while [[ ! -f "$READY_FILE" ]]; do
        if ! have_pid "$pid"; then
            echo "Dungeon generator exited before becoming ready."
            rm -f "$GENERATOR_PIDFILE"
            return 1
        fi

        sleep 0.25
    done

    echo "Dungeon generator ready."
}

stop_generator() {
    if [[ -f "$GENERATOR_PIDFILE" ]]; then
        local pid

        pid="$(
            cat "$GENERATOR_PIDFILE" \
                2>/dev/null || true
        )"

        if have_pid "$pid"; then
            echo "Stopping dungeon generator..."
            stop_process_group "$pid"
        fi
    fi

    rm -f "$GENERATOR_PIDFILE"
    rm -f "$READY_FILE"
}

start_server() {
    if [[ -f "$SERVER_PIDFILE" ]]; then
        local existing_pid

        existing_pid="$(
            cat "$SERVER_PIDFILE" \
                2>/dev/null || true
        )"

        if have_pid "$existing_pid"; then
            echo "Server already running (pid $existing_pid)."
            start_generator
            return 0
        fi

        rm -f "$SERVER_PIDFILE"
    fi

    : > "$LOG"

    {
        echo
        echo "============================================================"
        echo "ONB crawler starting: $(date)"
        echo "============================================================"
    } >> "$LOG"

    start_generator

    local cmd

    if command -v stdbuf >/dev/null 2>&1; then
        cmd=(
            stdbuf
            -oL
            -eL
            "$SERVER"
            -p
            "$PORT"
        )
    else
        cmd=(
            "$SERVER"
            -p
            "$PORT"
        )
    fi

    if command -v setsid >/dev/null 2>&1; then
        nohup setsid "${cmd[@]}" \
            > >(
                sed -u \
                    's/\x1b\[[0-9;]*m//g' \
                    >> "$LOG"
            ) 2>&1 &
    else
        nohup "${cmd[@]}" \
            > >(
                sed -u \
                    's/\x1b\[[0-9;]*m//g' \
                    >> "$LOG"
            ) 2>&1 &
    fi

    local pid=$!
    echo "$pid" > "$SERVER_PIDFILE"

    sleep 0.25

    if ! have_pid "$pid"; then
        echo "Server exited during startup."
        rm -f "$SERVER_PIDFILE"
        stop_generator
        return 1
    fi

    echo "Server started (pid $pid)."
}

stop_server() {
    if [[ -f "$SERVER_PIDFILE" ]]; then
        local pid

        pid="$(
            cat "$SERVER_PIDFILE" \
                2>/dev/null || true
        )"

        if have_pid "$pid"; then
            echo "Stopping server..."
            stop_process_group "$pid"
        fi

        rm -f "$SERVER_PIDFILE"
    else
        echo "Server PID file not found."
    fi

    stop_generator

    echo "Server stopped."
}

status_server() {
    if [[ -f "$SERVER_PIDFILE" ]]; then
        local pid

        pid="$(
            cat "$SERVER_PIDFILE" \
                2>/dev/null || true
        )"

        if have_pid "$pid"; then
            echo "Server: running (pid $pid)"
        else
            echo "Server: stopped (stale pidfile: $pid)"
        fi
    else
        echo "Server: stopped"
    fi

    if [[ -f "$GENERATOR_PIDFILE" ]]; then
        local generator_pid

        generator_pid="$(
            cat "$GENERATOR_PIDFILE" \
                2>/dev/null || true
        )"

        if have_pid "$generator_pid"; then
            echo "Generator: running (pid $generator_pid)"
        else
            echo "Generator: stopped (stale pidfile: $generator_pid)"
        fi
    else
        echo "Generator: stopped"
    fi
}


case "${1:-}" in
    start|--daemon)
        start_server
        ;;

    stop)
        stop_server
        ;;

    restart)
        stop_server
        start_server
        ;;

    status)
        status_server
        ;;

    *)
        nohup bash "$0" start \
            >/dev/null 2>&1 &

        echo "Starting server in background."
        echo "Logs -> $LOG"
        ;;
esac
