#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$ROOT_DIR/benchmark"
DATA_DIR="$BENCH_DIR/data"
CODE_DIR="$BENCH_DIR/code"
VERSION="${1:-$(git describe --tags --always 2>/dev/null || echo "dev")}"
DATE="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

mkdir -p "$DATA_DIR/raw"
CSV_FILE="$DATA_DIR/results.csv"

if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,version,target,requests_per_sec,latency_avg_ms" > "$CSV_FILE"
fi

echo "==> Building asmhttp library..."
as -o "$BENCH_DIR/asmhttp.o" "$ROOT_DIR/asmhttp.s"
ar rcs "$BENCH_DIR/libasmhttp.a" "$BENCH_DIR/asmhttp.o"

run_bench() {
    local target="$1"
    local bin="$BENCH_DIR/bin_$target"
    local raw_out="$DATA_DIR/raw/${VERSION}_${target}.txt"

    echo "==> Benchmarking: $target"
    $bin &
    local s_pid=$!
    sleep 1

    # Run load generator (wrk: 4 threads, 100 connections, 10 seconds)
    wrk -t4 -c100 -d10s http://127.0.0.1:80/ > "$raw_out" 2>&1 || true
    kill -9 "$s_pid" 2>/dev/null || true
    wait "$s_pid" 2>/dev/null || true

    # Extract metrics
    local rps=$(grep "Requests/sec:" "$raw_out" | awk '{print $2}')
    local lat=$(grep "Latency" "$raw_out" | head -n1 | awk '{print $2}')

    echo "$DATE,$VERSION,$target,$rps,$lat" >> "$CSV_FILE"
}

# Helper: check command availability
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure load generator exists before starting
if ! has_cmd wrk; then
    echo "[-] Error: 'wrk' benchmark tool not found in PATH. Aborting."
    exit 1
fi

# ==============================================================================
# 1. ASM Target (requires: as, ld)
# ==============================================================================
if has_cmd as && has_cmd ld; then
    echo "==> [ASM] Compiling and running..."
    as -o "$BENCH_DIR/app_asm.o" "$CODE_DIR/main.s"
    ld -s -n --no-warn-rwx-segments -o "$BENCH_DIR/bin_asm" "$BENCH_DIR/app_asm.o" "$BENCH_DIR/libasmhttp.a"
    run_bench "asm"
else
    echo "[!] Skipping ASM: 'as' or 'ld' not found in PATH."
fi

# ==============================================================================
# 2. C Target (requires: gcc or clang)
# ==============================================================================
if has_cmd gcc; then
    echo "==> [C] Compiling with gcc and running..."
    gcc -O3 -nostdlib -o "$BENCH_DIR/bin_c" "$CODE_DIR/main.c" "$BENCH_DIR/libasmhttp.a"
    run_bench "c"
elif has_cmd clang; then
    echo "==> [C] Compiling with clang and running..."
    clang -O3 -nostdlib -o "$BENCH_DIR/bin_c" "$CODE_DIR/main.c" "$BENCH_DIR/libasmhttp.a"
    run_bench "c"
else
    echo "[!] Skipping C: neither 'gcc' nor 'clang' found in PATH."
fi

# ==============================================================================
# 3. Zig Target (requires: zig)
# ==============================================================================
if has_cmd zig; then
    echo "==> [Zig] Compiling and running..."
    zig build-exe -O ReleaseFast "$CODE_DIR/main.zig" -femit-bin="$BENCH_DIR/bin_zig" "$BENCH_DIR/libasmhttp.a" --libc
    run_bench "zig"
else
    echo "[!] Skipping Zig: 'zig' not found in PATH."
fi

# Only patch README if results were recorded
if [ -s "$CSV_FILE" ]; then
    echo "==> Updating README.md benchmark table..."
    TEMP_TABLE=$(mktemp)
    echo "<!-- BENCHMARK_START -->" >> "$TEMP_TABLE"
    echo "| Date | Version | Target | Req/Sec | Latency |" >> "$TEMP_TABLE"
    echo "|---|---|---|---|---|" >> "$TEMP_TABLE"
    tail -n 12 "$CSV_FILE" | while IFS=',' read -r d v t r l; do
        [ "$d" == "timestamp" ] && continue
        echo "| $d | $v | $t | $r | $l |" >> "$TEMP_TABLE"
    done
    echo "<!-- BENCHMARK_END -->" >> "$TEMP_TABLE"

    sed -i -e "/<!-- BENCHMARK_START -->/,/<!-- BENCHMARK_END -->/{ r $TEMP_TABLE" -e "d }" "$ROOT_DIR/README.md"
    rm -f "$TEMP_TABLE"
fi

echo "==> Benchmarks complete and recorded in data/results.csv and README.md"
