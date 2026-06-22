#!/usr/bin/env bash
# Offline test harness for core/ssm-to-env.sh.
#
# Puts `curl` and `sha256sum` stubs on PATH so the action never hits the network
# nor hashes a real binary, runs the action script in a throwaway cwd, and asserts
# on exit code, the generated .env, and the recorded stub invocations.
# No network, no real download.
#
# shellcheck disable=SC2015  # `cond && ok || bad` is intentional; ok() always returns 0
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../core/ssm-to-env.sh"
STUB_DIR="$HERE"   # contains the curl + sha256sum stubs

# Read the expected checksum straight from the script so the test never drifts if
# the pinned constant is bumped.
EXPECTED="$(grep -oE '[0-9a-f]{64}' "$SCRIPT" | head -1)"

pass=0
fail=0
note() { printf '  %s\n' "$*"; }
ok()   { pass=$((pass + 1)); printf 'ok   - %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL - %s\n' "$1"; [ -n "${2:-}" ] && note "$2"; }

# Run the action script in a fresh cwd with the stubs on PATH.
# Usage: run_action <SHA_STUB_OUT value> [extra env assignments...]
# Sets RUN_OUT/RUN_RC/RUN_DIR/RUN_CURLLOG/RUN_SHALOG/RUN_AWSENVLOG for the caller.
run_action() {
  local sha="$1"; shift
  RUN_DIR="$(mktemp -d)"
  RUN_CURLLOG="$(mktemp)"
  RUN_SHALOG="$(mktemp)"
  RUN_AWSENVLOG="$(mktemp)"
  : >"$RUN_CURLLOG"; : >"$RUN_SHALOG"; : >"$RUN_AWSENVLOG"
  RUN_OUT="$(
    cd "$RUN_DIR" &&
    env -u AWS_ENV_PATH \
        PATH="$STUB_DIR:$PATH" \
        CURL_LOG="$RUN_CURLLOG" \
        SHA_LOG="$RUN_SHALOG" \
        AWSENV_LOG="$RUN_AWSENVLOG" \
        SHA_STUB_OUT="$sha" \
        "$@" \
        bash "$SCRIPT" 2>&1
  )"
  RUN_RC=$?
}

cleanup_run() {
  rm -rf "$RUN_DIR" "$RUN_CURLLOG" "$RUN_SHALOG" "$RUN_AWSENVLOG"
}

# ---------------------------------------------------------------- tests

test_happy_path() {
  run_action "$EXPECTED" AWS_ENV_PATH=/some/path

  [ "$RUN_RC" -eq 0 ] && ok "happy: exit 0 (green)" || bad "happy: exit 0 (green)" "rc=$RUN_RC out=$RUN_OUT"
  [ -f "$RUN_DIR/.env" ] && ok "happy: .env written in cwd" || bad "happy: .env written in cwd"
  grep -q '^FOO=bar$' "$RUN_DIR/.env" 2>/dev/null && ok "happy: .env contains FOO=bar" || bad "happy: .env contains FOO=bar" "$(cat "$RUN_DIR/.env" 2>/dev/null)"
  grep -q '^BAZ=qux$' "$RUN_DIR/.env" 2>/dev/null && ok "happy: .env contains BAZ=qux" || bad "happy: .env contains BAZ=qux" "$(cat "$RUN_DIR/.env" 2>/dev/null)"
  grep -q -- 'aws-env --recursive --format=dotenv' "$RUN_AWSENVLOG" && ok "happy: aws-env run with --recursive --format=dotenv" || bad "happy: aws-env run with --recursive --format=dotenv" "$(cat "$RUN_AWSENVLOG")"

  cleanup_run
}

test_checksum_mismatch() {
  run_action "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" AWS_ENV_PATH=/some/path

  [ "$RUN_RC" -ne 0 ] && ok "mismatch: non-zero exit" || bad "mismatch: non-zero exit" "rc=$RUN_RC out=$RUN_OUT"
  grep -q 'checksum mismatch' <<<"$RUN_OUT" && ok "mismatch: stderr reports checksum mismatch" || bad "mismatch: stderr reports checksum mismatch" "$RUN_OUT"
  [ ! -s "$RUN_DIR/.env" ] && ok "mismatch: .env not written (or empty)" || bad "mismatch: .env not written (or empty)" "$(cat "$RUN_DIR/.env" 2>/dev/null)"
  [ ! -s "$RUN_AWSENVLOG" ] && ok "mismatch: aws-env payload NOT executed" || bad "mismatch: aws-env payload NOT executed" "$(cat "$RUN_AWSENVLOG")"

  cleanup_run
}

test_missing_aws_env_path() {
  run_action "$EXPECTED"

  [ "$RUN_RC" -ne 0 ] && ok "missing path: non-zero exit (:? guard)" || bad "missing path: non-zero exit (:? guard)" "rc=$RUN_RC out=$RUN_OUT"
  [ ! -s "$RUN_CURLLOG" ] && ok "missing path: curl NOT invoked" || bad "missing path: curl NOT invoked" "$(cat "$RUN_CURLLOG")"

  cleanup_run
}

# ---------------------------------------------------------------- run

test_happy_path
test_checksum_mismatch
test_missing_aws_env_path

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
