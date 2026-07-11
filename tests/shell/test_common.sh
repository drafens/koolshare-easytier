#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT INT TERM

export KSROOT="${TEST_ROOT}/koolshare"
export CONFIG_DIR="${KSROOT}/configs"
export RUNTIME_DIR="${TEST_ROOT}/runtime"
export PID_FILE="${TEST_ROOT}/easytier.pid"
export LOCK_DIR="${RUNTIME_DIR}/service.lock"
export CORE_LOG="${RUNTIME_DIR}/core.log"
export SERVICE_LOG="${RUNTIME_DIR}/service.log"
export MAX_SERVICE_LOG_BYTES=32
mkdir -p "${KSROOT}/bin" "${KSROOT}/configs" "${KSROOT}/scripts"
cp "${ROOT}/easytier/scripts/easytier_common.sh" "${KSROOT}/scripts/"

. "${KSROOT}/scripts/easytier_common.sh"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_eq() {
	[ "$1" = "$2" ] || fail "expected '$2', got '$1'"
}

ensure_runtime_dirs
[ -d "${RUNTIME_DIR}" ] || fail "runtime directory was not created"

printf '%040d\n' 0 >"${SERVICE_LOG}"
log_line "bounded diagnostic"
[ "$(wc -c <"${SERVICE_LOG}")" -lt 80 ] || fail "diagnostic log was not trimmed"
grep -q 'bounded diagnostic' "${SERVICE_LOG}" || fail "diagnostic message was not written"
grep -q '0000000000' "${SERVICE_LOG}.1" || fail "previous diagnostic log was not retained"
[ "$(tail_core_log 2 | wc -l)" -eq 2 ] || fail "current and previous diagnostic logs were not readable"
[ ! -s "${CORE_LOG}" ] || fail "shell diagnostic was written to the core log"

acquire_lock || fail "first lock acquisition failed"
if acquire_lock; then
	fail "second lock acquisition unexpectedly succeeded"
fi
release_lock
acquire_lock || fail "lock could not be reacquired"
release_lock

assert_eq "$(write_result success OK done)" "RESULT=success
CODE=OK
MESSAGE=done"

safe_payload="$(http_safe_payload 'line 1
line "2"')"
case "${safe_payload}" in ETB64:*) ;; *) fail "HTTP payload was not encoded" ;; esac
decoded_payload="$(printf '%s' "${safe_payload#ETB64:}" | base64 -d)"
assert_eq "${decoded_payload}" "line 1
line \"2\""

echo "test_common.sh: PASS"
