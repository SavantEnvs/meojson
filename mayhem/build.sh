#!/usr/bin/env bash
#
# mayhem/build.sh — build the meojson fuzz harness (sanitized), its standalone reproducer, and the
# upstream test suite + known-answer probe (normal flags) that mayhem/test.sh runs.
# meojson is header-only, so the "project build" is compiling the headers into each translation unit
# with $SANITIZER_FLAGS / $DEBUG_FLAGS; nothing is fetched, so the script is offline and re-runnable.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
OUT_DIR=/mayhem
WORK="$SRC/build/mayhem"
mkdir -p "$WORK"

# 1) Sanitized fuzz harness + standalone reproducer. The library is header-only, so the harness TU
#    carries the instrumented project code; fuzzer-no-link keeps SanCov on even with no sanitizers.
CXXFLAGS_FUZZ="-std=c++17 -O1 -fsanitize=fuzzer-no-link $SANITIZER_FLAGS $DEBUG_FLAGS -I$SRC/include"

$CXX $CXXFLAGS_FUZZ -c "$SRC/mayhem/lsan_off.cc" -o "$WORK/lsan_off.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -x c -c "$STANDALONE_FUZZ_MAIN" -o "$WORK/standalone_main.o"

$CXX $CXXFLAGS_FUZZ $LIB_FUZZING_ENGINE "$SRC/mayhem/parse_fuzzer.cpp" "$WORK/lsan_off.o" \
    -o "$OUT_DIR/parse_fuzzer"
$CXX $CXXFLAGS_FUZZ "$SRC/mayhem/parse_fuzzer.cpp" "$WORK/standalone_main.o" "$WORK/lsan_off.o" \
    -o "$OUT_DIR/parse_fuzzer-standalone"

# 2) Upstream test suite + KAT probe with the project's normal flags (no sanitizers), separate outputs.
CXXFLAGS_TEST="-std=c++17 -O2 -msse4.1 -DMEOJSON_FS_PATH_EXTENSION -DMEOJSON_KEEP_FLOATING_PRECISION $COVERAGE_FLAGS -I$SRC/include"
$CXX $CXXFLAGS_TEST $SRC/test/*.cpp -o "$WORK/testing"
$CXX -std=c++17 -O2 $COVERAGE_FLAGS -I"$SRC/include" "$SRC/mayhem/kat.cpp" -o "$WORK/kat"
