#!/usr/bin/env bash
# ==============================================================================
# Prolog Language Toolkit - Dynamic Timed Test Runner
#
# Records test execution times as pure Prolog terms in .test_timings.pl and
# dynamically computes safe execution timeouts:
#   - First run (unseen target): Timeout = TMIN + TBUFFER
#   - Subsequent runs: Timeout = (LastElapsed * 1.20) + 5s (with TMIN + TBUFFER floor)
#
# Both TMIN and test execution times are stored and read by the build system.
# ==============================================================================

set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <target_name> <command...>" >&2
    exit 1
fi
shift

TIMINGS_FILE="${TIMINGS_FILE:-.test_timings.pl}"
TBUFFER="${TBUFFER:-90}"
PROLOG="${PROLOG:-nice scryer-safe -f}"
PROLOG_MEMORY_MAX="${PROLOG_MEMORY_MAX:-2G}"

# Ensure timings file exists with header
if [ ! -f "$TIMINGS_FILE" ]; then
    cat << 'EOF' > "$TIMINGS_FILE"
% Prolog Test Timings Database
% Generated automatically by the build system. Do not edit manually.
EOF
fi

# Function to get TMIN from timings file
get_tmin() {
    awk -F '[,()[:space:]]+' '
        $1 == "test_timing" && $2 == "tmin" { val = $3 }
        END { if (val != "") print val; else print "none" }
    ' "$TIMINGS_FILE" 2>/dev/null || echo "none"
}

# Function to get last elapsed time for target
get_last_elapsed() {
    local target="$1"
    awk -F '[,()[:space:]]+' -v tgt="$target" '
        $1 == "test_timing" && $2 == tgt { val = $3 }
        END { if (val != "") print val; else print "none" }
    ' "$TIMINGS_FILE" 2>/dev/null || echo "none"
}

# 1. Ensure TMIN is recorded
TMIN="$(get_tmin)"
if [ "$TMIN" = "none" ] || [ "$TARGET" = "tmin" ]; then
    echo "[timed_runner] Estimating baseline minimal test time (TMIN)..."
    TMIN_START="$(date +%s.%N)"
    $PROLOG -g "halt" > /dev/null 2>&1 || true
    TMIN_END="$(date +%s.%N)"
    TMIN="$(awk -v s="$TMIN_START" -v e="$TMIN_END" 'BEGIN { printf "%.3f", (e - s) }')"
    NOW="$(date +%s)"
    # Filter out previous tmin
    awk -F '[,()[:space:]]+' '$1 == "test_timing" && $2 == "tmin" { next } { print }' "$TIMINGS_FILE" > "${TIMINGS_FILE}.tmp" 2>/dev/null || true
    mv "${TIMINGS_FILE}.tmp" "$TIMINGS_FILE"
    echo "test_timing(tmin, $TMIN, $NOW)." >> "$TIMINGS_FILE"
    echo "[timed_runner] TMIN measured: ${TMIN}s"
    
    if [ "$TARGET" = "tmin" ]; then
        exit 0
    fi
fi

# 2. Compute dynamic timeout for TARGET
LAST_ELAPSED="$(get_last_elapsed "$TARGET")"

TIMEOUT_SEC=$(awk -v last="$LAST_ELAPSED" -v tmin="$TMIN" -v tbuf="$TBUFFER" '
BEGIN {
    if (last == "none" || last == "") {
        est = (tmin + 0) + (tbuf + 0);
    } else {
        timeout_calc = (last + 0) * 1.20 + 5.0;
        floor_val = (tmin + 0) + (tbuf + 0);
        est = (timeout_calc > floor_val) ? timeout_calc : floor_val;
    }
    res = (est == int(est)) ? int(est) : int(est) + 1;
    if (res < 5) res = 5;
    print res;
}')

export PROLOG_TIMEOUT="${TIMEOUT_SEC}s"
export PROLOG_MEMORY_MAX

echo "[timed_runner] Target: ${TARGET} | Dynamic Timeout: ${TIMEOUT_SEC}s (Last: ${LAST_ELAPSED}s, TMin: ${TMIN}s, TBuffer: ${TBUFFER}s)"

# 3. Execute target test command with timing
START_TIME="$(date +%s.%N)"
set +e
"$@"
EXIT_CODE=$?
set -e
END_TIME="$(date +%s.%N)"

ELAPSED="$(awk -v s="$START_TIME" -v e="$END_TIME" 'BEGIN { printf "%.3f", (e - s) }')"
NOW="$(date +%s)"

if [ $EXIT_CODE -eq 0 ]; then
    # Record success timing cleanly
    awk -F '[,()[:space:]]+' -v tgt="$TARGET" '$1 == "test_timing" && $2 == tgt { next } { print }' "$TIMINGS_FILE" > "${TIMINGS_FILE}.tmp" 2>/dev/null || true
    mv "${TIMINGS_FILE}.tmp" "$TIMINGS_FILE"
    echo "test_timing(${TARGET}, ${ELAPSED}, ${NOW})." >> "$TIMINGS_FILE"
    echo "[timed_runner] Target '${TARGET}' passed in ${ELAPSED}s (recorded in ${TIMINGS_FILE})"
else
    echo "[timed_runner] Target '${TARGET}' FAILED with code ${EXIT_CODE} after ${ELAPSED}s" >&2
fi

exit $EXIT_CODE
