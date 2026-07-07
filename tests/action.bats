#!/usr/bin/env bats
# bats tests for core/ssm-to-env.sh
#
# Uses npx and node stubs. Each test runs the script in a throwaway sandbox
# with a controlled PATH and asserts on exit codes, .env content, and stub logs.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../core/ssm-to-env.sh"
  STUB_DIR="$BATS_TEST_DIRNAME/__mocks__"
  BASH_BIN="$(command -v bash)"

  # Read the pinned env-ssm version from the script itself for assertions
  ENV_SSM_VERSION="$(grep -oE 'ENV_SSM_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$SCRIPT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  PINNED_SPEC="@heronlabs/env-ssm@${ENV_SSM_VERSION}"
}

# Run core/ssm-to-env.sh in a throwaway sandbox with a controlled PATH.
# Usage: run_script <path> <env_path>
# Sets EXIT_CODE and SANDBOX.
run_script() {
  local path="$1" env_path="$2"
  SANDBOX="$(mktemp -d)"
  local npx_log="${SANDBOX}/npx.log" node_log="${SANDBOX}/node.log"
  : > "${npx_log}"
  : > "${node_log}"

  set +e
  if [ "${env_path}" = "__unset__" ]; then
    ( cd "${SANDBOX}" \
      && PATH="${path}" NPX_LOG="${npx_log}" NODE_LOG="${node_log}" \
        "${BASH_BIN}" "${SCRIPT}" >"${SANDBOX}/stdout" 2>"${SANDBOX}/stderr" )
  else
    ( cd "${SANDBOX}" \
      && PATH="${path}" AWS_ENV_PATH="${env_path}" NPX_LOG="${npx_log}" NODE_LOG="${node_log}" \
        "${BASH_BIN}" "${SCRIPT}" >"${SANDBOX}/stdout" 2>"${SANDBOX}/stderr" )
  fi
  EXIT_CODE=$?
  set -e
}

# ---------------------------------------------------------------- tests

@test "happy path: writes .env, invokes npx with pinned spec and --format=dotenv" {
  run_script "${STUB_DIR}:${PATH}" "/some/path"

  [ "$EXIT_CODE" -eq 0 ]
  [ -f "${SANDBOX}/.env" ]
  grep -qxF "FOO='bar'" "${SANDBOX}/.env"
  grep -qxF "BAZ='qux'" "${SANDBOX}/.env"
  grep -qF -- "--format=dotenv" "${SANDBOX}/npx.log"
  grep -qF "${PINNED_SPEC}" "${SANDBOX}/npx.log"
}

@test "missing AWS_ENV_PATH: exits non-zero, npx not invoked, no .env" {
  run_script "${STUB_DIR}:${PATH}" "__unset__"

  [ "$EXIT_CODE" -ne 0 ]
  [ ! -s "${SANDBOX}/npx.log" ]
  [ ! -e "${SANDBOX}/.env" ]
}

@test "missing node: exits non-zero, stderr mentions node requirement" {
  local npx_only_dir; npx_only_dir="$(mktemp -d)"
  cp "${STUB_DIR}/npx" "${npx_only_dir}/npx"

  run_script "${npx_only_dir}" "/some/path"

  [ "$EXIT_CODE" -ne 0 ]
  grep -qF "node is required" "${SANDBOX}/stderr"
  [ ! -s "${SANDBOX}/npx.log" ]
  [ ! -e "${SANDBOX}/.env" ]
}
