#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPECTED_MAKE=$'[INFO] Calculator started\n10 + 5 = 15\n10 - 5 = 5'
EXPECTED_CMAKE=$'10 + 5 = 15\n10 - 5 = 5'

pass=0
fail=0

ok() {
    printf '[PASS] %s\n' "$1"
    pass=$((pass + 1))
}

bad() {
    printf '[FAIL] %s\n' "$1"
    fail=$((fail + 1))
}

printf '=== Make & CMake Recruit Check ===\n\n'

printf 'Task 2: Makefile\n'
(
    cd "$ROOT_DIR/make-task" || exit 1
    rm -f calculator ./*.o
    if make >/tmp/make-cmake-recruit-make.log 2>&1; then
        output="$(./calculator 2>/dev/null || true)"
        if [[ "$output" == "$EXPECTED_MAKE" ]]; then
            exit 0
        fi
    fi
    exit 1
)
if [[ $? -eq 0 ]]; then
    ok 'Make task builds and runs correctly'
else
    bad 'Make task is not complete yet'
fi

printf '\nTask 3: CMakeLists.txt\n'
rm -rf "$ROOT_DIR/cmake-task/build"
if cmake -S "$ROOT_DIR/cmake-task" -B "$ROOT_DIR/cmake-task/build" >/tmp/make-cmake-recruit-cmake-config.log 2>&1 \
    && cmake --build "$ROOT_DIR/cmake-task/build" >/tmp/make-cmake-recruit-cmake-build.log 2>&1; then
    output="$("$ROOT_DIR/cmake-task/build/calculator" 2>/dev/null || true)"
    if [[ "$output" == "$EXPECTED_CMAKE" ]]; then
        ok 'CMake task configures, builds and runs correctly'
    else
        bad 'CMake target runs, but output is incorrect'
    fi
else
    bad 'CMake task is not complete yet'
fi

printf '\nSummary: %d passed, %d failed\n' "$pass" "$fail"

if [[ "$fail" -ne 0 ]]; then
    exit 1
fi
