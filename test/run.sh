#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/core/ssm-to-env.sh"
STUB_DIR="${REPO_ROOT}/test"

# Absolute path so the harness can launch bash even under a stripped-down PATH
# that intentionally hides node/npx from the script under test.
BASH_BIN="$(command -v bash)"

# The script interpolates the version into the package spec, so the literal
# "@heronlabs/env-ssm@<ver>" never appears in source. Read the pinned version
# from its assignment and reconstruct the spec npx actually receives at runtime,
# keeping the assertion in lockstep with the script (no drift).
ENV_SSM_VERSION="$(grep -oE 'ENV_SSM_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "${SCRIPT}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
PINNED_SPEC="@heronlabs/env-ssm@${ENV_SSM_VERSION}"

passed=0
failed=0

pass() {
  passed=$((passed + 1))
  printf 'ok   - %s\n' "$1"
}

fail() {
  failed=$((failed + 1))
  printf 'FAIL - %s\n' "$1"
}

assert_nonzero_exit() {
  if [ "$2" -ne 0 ]; then
    pass "$1"
  else
    fail "$1 (got exit 0)"
  fi
}

assert_file_exists() {
  if [ -f "$2" ]; then
    pass "$1"
  else
    fail "$1 (missing $2)"
  fi
}

assert_file_absent() {
  if [ ! -e "$2" ]; then
    pass "$1"
  else
    fail "$1 (unexpected $2)"
  fi
}

assert_file_has_line() {
  if grep -qxF "$3" "$2" 2>/dev/null; then
    pass "$1"
  else
    fail "$1 (no line '$3' in $2)"
  fi
}

assert_file_empty() {
  if [ ! -s "$2" ]; then
    pass "$1"
  else
    fail "$1 ($2 not empty)"
  fi
}

assert_contains() {
  case "$2" in
    *"$3"*) pass "$1" ;;
    *) fail "$1 (expected to contain '$3', got '$2')" ;;
  esac
}

# Runs core/ssm-to-env.sh in a throwaway cwd with a controlled PATH, capturing
# exit code, stdout, stderr, and the stub logs. Sets EXIT_CODE and SANDBOX.
run_script() {
  local sandbox path env_path
  path="$1"
  env_path="$2"
  sandbox="$(mktemp -d)"

  local npx_log="${sandbox}/npx.log"
  local node_log="${sandbox}/node.log"
  : > "${npx_log}"
  : > "${node_log}"

  set +e
  if [ "${env_path}" = "__unset__" ]; then
    ( cd "${sandbox}" \
      && PATH="${path}" NPX_LOG="${npx_log}" NODE_LOG="${node_log}" \
        "${BASH_BIN}" "${SCRIPT}" >"${sandbox}/stdout" 2>"${sandbox}/stderr" )
  else
    ( cd "${sandbox}" \
      && PATH="${path}" AWS_ENV_PATH="${env_path}" NPX_LOG="${npx_log}" NODE_LOG="${node_log}" \
        "${BASH_BIN}" "${SCRIPT}" >"${sandbox}/stdout" 2>"${sandbox}/stderr" )
  fi
  EXIT_CODE=$?
  set -e

  SANDBOX="${sandbox}"
}

test_happy_path() {
  run_script "${STUB_DIR}:${PATH}" "/some/path"

  if [ "${EXIT_CODE}" -eq 0 ]; then
    pass "happy path: exits 0"
  else
    fail "happy path: exits 0 (got ${EXIT_CODE})"
  fi
  assert_file_exists "happy path: writes .env in cwd" "${SANDBOX}/.env"
  assert_file_has_line "happy path: .env has FOO='bar'" "${SANDBOX}/.env" "FOO='bar'"
  assert_file_has_line "happy path: .env has BAZ='qux'" "${SANDBOX}/.env" "BAZ='qux'"
  assert_contains "happy path: npx ran with --format=dotenv" "$(cat "${SANDBOX}/npx.log")" "--format=dotenv"
  assert_contains "happy path: npx ran with pinned spec ${PINNED_SPEC}" "$(cat "${SANDBOX}/npx.log")" "${PINNED_SPEC}"
}

test_missing_aws_env_path() {
  run_script "${STUB_DIR}:${PATH}" "__unset__"

  assert_nonzero_exit "missing AWS_ENV_PATH: exits non-zero" "${EXIT_CODE}"
  assert_file_empty "missing AWS_ENV_PATH: npx not invoked" "${SANDBOX}/npx.log"
  assert_file_absent "missing AWS_ENV_PATH: no .env written" "${SANDBOX}/.env"
}

test_missing_node() {
  local npx_only_dir
  npx_only_dir="$(mktemp -d)"
  cp "${STUB_DIR}/npx" "${npx_only_dir}/npx"

  run_script "${npx_only_dir}" "/some/path"

  assert_nonzero_exit "missing node: exits non-zero" "${EXIT_CODE}"
  assert_contains "missing node: stderr mentions node requirement" "$(cat "${SANDBOX}/stderr")" "node is required"
  assert_file_empty "missing node: npx not invoked" "${SANDBOX}/npx.log"
  assert_file_absent "missing node: no .env written" "${SANDBOX}/.env"
}

test_happy_path
test_missing_aws_env_path
test_missing_node

printf '\n%d passed, %d failed\n' "${passed}" "${failed}"
[ "${failed}" -eq 0 ]
