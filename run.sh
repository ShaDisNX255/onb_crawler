#!/usr/bin/env bash

set -u

cd "$(dirname "$0")"
LOG_FILE="$PWD/log.txt"

exec >> "$LOG_FILE" 2>&1

echo
echo "============================================================"
echo "ONB crawler starting: $(date)"
echo "============================================================"

READY_FILE="runtime/dungeon_pool/READY"

rm -f "$READY_FILE"

node tools/dungeon-generator/generator_server.js &
GENERATOR_PID=$!

cleanup() {
    echo
    echo "Stopping dungeon generator..."

    kill "$GENERATOR_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM


echo "Waiting for dungeon generator..."


while [ ! -f "$READY_FILE" ]; do
    if ! kill -0 "$GENERATOR_PID" 2>/dev/null; then
        echo "Dungeon generator exited before becoming ready."
        exit 1
    fi

    sleep 0.25
done


echo "Dungeon generator ready."
echo "Starting ONB server..."


./net_battle_server "$@"
