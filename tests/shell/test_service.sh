#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT INT TERM

export KSROOT="${TEST_ROOT}/koolshare"
export CONFIG_DIR="${KSROOT}/configs"
export CONFIG_FILE="${CONFIG_DIR}/easytier.toml"
export RUNTIME_DIR="${TEST_ROOT}/runtime"
export PID_FILE="${TEST_ROOT}/easytier.pid"
export LOCK_DIR="${RUNTIME_DIR}/service.lock"
export CORE_LOG="${RUNTIME_DIR}/core.log"
export SERVICE_LOG="${RUNTIME_DIR}/service.log"
export STATE_FILE="${RUNTIME_DIR}/service.state"
export STARTUP_TIMEOUT_SECONDS=5
export STOP_WAIT_SECONDS=3
REAL_KSROOT="${TEST_ROOT}/softcenter"
mkdir -p "${REAL_KSROOT}"
ln -s "${REAL_KSROOT}" "${KSROOT}"
mkdir -p "${KSROOT}/bin" "${KSROOT}/scripts" "${CONFIG_DIR}"
cp "${ROOT}/easytier/scripts/easytier_common.sh" "${KSROOT}/scripts/"
cp "${ROOT}/easytier/scripts/easytier_service.sh" "${KSROOT}/scripts/"
cc -O2 -o "${KSROOT}/bin/easytier-core" "${ROOT}/tests/fixtures/fake_easytier_core.c"
cat >"${KSROOT}/bin/easytier-cli" <<'EOF'
#!/bin/sh
case "$1" in
	--version) echo "easytier-cli 2.6.4" ;;
	node) exit 0 ;;
	*) exit 1 ;;
esac
EOF
chmod 755 "${KSROOT}/bin/"* "${KSROOT}/scripts/"*.sh
. "${KSROOT}/scripts/easytier_common.sh"
printf 'valid=true\n' >"${CONFIG_FILE}"

start_time="$(date +%s)"
"${KSROOT}/scripts/easytier_service.sh" start
elapsed="$(( $(date +%s) - start_time ))"
[ "${elapsed}" -lt "${STARTUP_TIMEOUT_SECONDS}" ] || { echo "FAIL: readiness probe did not finish startup early" >&2; exit 1; }
pid="$(sed -n '1p' "${PID_FILE}")"
kill -0 "${pid}" 2>/dev/null || { echo "FAIL: service did not start" >&2; exit 1; }
is_easytier_pid "${pid}" || { echo "FAIL: exact core executable was not recognized" >&2; exit 1; }
cmdline="$(tr '\000' ' ' <"/proc/${pid}/cmdline")"
case "${cmdline}" in
	*"--file-log-level info"*"--file-log-size 1"*"--file-log-count 1"*) ;;
	*) echo "FAIL: EasyTier built-in log rotation arguments are missing" >&2; exit 1 ;;
esac
cp "${KSROOT}/bin/easytier-core" "${KSROOT}/bin/other-easytier-core"
"${KSROOT}/bin/other-easytier-core" -c "${CONFIG_FILE}" &
other_pid=$!
sleep 1
if is_easytier_pid "${other_pid}"; then
	echo "FAIL: a different executable was accepted as EasyTier" >&2
	exit 1
fi
kill "${other_pid}" 2>/dev/null || true
mkdir -p "${TEST_ROOT}/alternate-bin"
cp "${KSROOT}/bin/easytier-core" "${TEST_ROOT}/alternate-bin/easytier-core"
"${TEST_ROOT}/alternate-bin/easytier-core" -c "${CONFIG_FILE}" &
alternate_pid=$!
sleep 1
is_easytier_pid "${alternate_pid}" || { echo "FAIL: EasyTier from another path was not recognized" >&2; exit 1; }
"${KSROOT}/scripts/easytier_service.sh" start
[ "$(sed -n '1p' "${PID_FILE}")" = "${pid}" ] || { echo "FAIL: start was not idempotent" >&2; exit 1; }
"${KSROOT}/scripts/easytier_service.sh" stop
kill -0 "${pid}" 2>/dev/null && { echo "FAIL: service did not stop" >&2; exit 1; }
kill -0 "${alternate_pid}" 2>/dev/null && { echo "FAIL: EasyTier from another path was not stopped" >&2; exit 1; }
[ "$(cat "${STATE_FILE}")" = "stopped" ] || { echo "FAIL: stopped state was not recorded" >&2; exit 1; }

"${KSROOT}/bin/easytier-core" -c "${CONFIG_FILE}" &
orphan_pid=$!
sleep 1
rm -f "${PID_FILE}"
[ "$(get_easytier_pid)" = "${orphan_pid}" ] || { echo "FAIL: untracked EasyTier process was not discovered" >&2; exit 1; }
"${KSROOT}/scripts/easytier_service.sh" stop
kill -0 "${orphan_pid}" 2>/dev/null && { echo "FAIL: untracked EasyTier process was not stopped" >&2; exit 1; }

cat >"${KSROOT}/bin/easytier-cli" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "${KSROOT}/bin/easytier-cli"
start_time="$(date +%s)"
if STARTUP_TIMEOUT_SECONDS=2 "${KSROOT}/scripts/easytier_service.sh" start; then
	echo "FAIL: unavailable default RPC portal was accepted" >&2
	exit 1
fi
elapsed="$(( $(date +%s) - start_time ))"
[ "${elapsed}" -ge 2 ] || { echo "FAIL: RPC readiness timeout returned too early" >&2; exit 1; }
[ ! -e "${PID_FILE}" ] || { echo "FAIL: failed RPC startup kept its PID file" >&2; exit 1; }

"${KSROOT}/bin/easytier-core" -c "${CONFIG_FILE}" &
stale_pid=$!
sleep 1
if STARTUP_TIMEOUT_SECONDS=3 "${KSROOT}/scripts/easytier_service.sh" start; then
	echo "FAIL: an existing process without RPC readiness was accepted" >&2
	exit 1
fi
kill -0 "${stale_pid}" 2>/dev/null && { echo "FAIL: stale EasyTier process was not stopped" >&2; exit 1; }

printf 'valid=true\ndelayed_failure=true\n' >"${CONFIG_FILE}"
if STARTUP_TIMEOUT_SECONDS=4 "${KSROOT}/scripts/easytier_service.sh" start; then
	echo "FAIL: delayed startup failure was accepted" >&2
	exit 1
fi
grep -q 'delayed startup failure' "${SERVICE_LOG}" || { echo "FAIL: delayed startup error was not captured" >&2; exit 1; }

printf 'valid=false\n' >"${CONFIG_FILE}"
if "${KSROOT}/scripts/easytier_service.sh" start; then
	echo "FAIL: invalid config unexpectedly started" >&2
	exit 1
fi
grep -q 'invalid test config' "${SERVICE_LOG}" || { echo "FAIL: core error was not captured" >&2; exit 1; }
[ "$(cat "${STATE_FILE}")" = "failed" ] || { echo "FAIL: failed state was not recorded" >&2; exit 1; }

echo "test_service.sh: PASS"
