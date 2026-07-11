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
export STARTUP_TIMEOUT_SECONDS=1
export STOP_WAIT_SECONDS=3
export DBUS_DIR="${TEST_ROOT}/dbus"
export PATH="${TEST_ROOT}/bin:${PATH}"
mkdir -p "${KSROOT}/bin" "${KSROOT}/scripts" "${CONFIG_DIR}" "${DBUS_DIR}" "${TEST_ROOT}/bin"
cp "${ROOT}/easytier/scripts/"*.sh "${KSROOT}/scripts/"
cc -O2 -o "${KSROOT}/bin/easytier-core" "${ROOT}/tests/fixtures/fake_easytier_core.c"

cat >"${KSROOT}/scripts/base.sh" <<'EOF'
#!/bin/sh
http_response() { printf '%s\n' "$1"; }
EOF
cat >"${TEST_ROOT}/bin/dbus" <<'EOF'
#!/bin/sh
command="$1"
shift
case "${command}" in
	get) [ -f "${DBUS_DIR}/$1" ] && cat "${DBUS_DIR}/$1" ;;
	set) key="${1%%=*}"; value="${1#*=}"; printf '%s' "${value}" >"${DBUS_DIR}/${key}" ;;
	remove) rm -f "${DBUS_DIR}/$1" ;;
	list) for file in "${DBUS_DIR}/$1"*; do [ -f "${file}" ] && printf '%s=%s\n' "${file##*/}" "$(cat "${file}")"; done ;;
esac
EOF
cat >"${KSROOT}/bin/easytier-cli" <<'EOF'
#!/bin/sh
case "$1" in
	--version) echo "easytier-cli 2.6.4" ;;
	node) exit 0 ;;
	*) exit 1 ;;
esac
EOF
chmod 755 "${TEST_ROOT}/bin/dbus" "${KSROOT}/bin/"* "${KSROOT}/scripts/"*.sh

decode_response() {
	printf '%s' "${1#ETB64:}" | base64 -d
}

printf 'valid=false\nold=true\n' >"${CONFIG_FILE}"
printf 'dmFsaWQ9dHJ1ZQo=' >"${DBUS_DIR}/easytier_payload_101"
response="$(${KSROOT}/scripts/easytier_config.sh 101 save_config)"
decode_response "${response}" | grep -q 'CODE=CONFIG_SAVED'
grep -q '^valid=true$' "${CONFIG_FILE}"
[ ! -e "${PID_FILE}" ] || { echo "FAIL: saving config started a service" >&2; exit 1; }

response="$(${KSROOT}/scripts/easytier_config.sh 0 start)"
decode_response "${response}" | grep -q 'CODE=SERVICE_RUNNING'
[ "$(cat "${DBUS_DIR}/easytier_autostart")" = "1" ] || { echo "FAIL: successful start did not enable auto-start" >&2; exit 1; }
running_pid="$(cat "${PID_FILE}")"
printf 'dmFsaWQ9dHJ1ZQpsaXZlX3VwZGF0ZT10cnVlCg==' >"${DBUS_DIR}/easytier_payload_104"
response="$(${KSROOT}/scripts/easytier_config.sh 104 save_config)"
decode_response "${response}" | grep -q 'CODE=CONFIG_SAVED'
[ "$(cat "${PID_FILE}")" = "${running_pid}" ] || { echo "FAIL: saving config restarted the service" >&2; exit 1; }
grep -q '^live_update=true$' "${CONFIG_FILE}" || { echo "FAIL: running-service save did not update config" >&2; exit 1; }
cat >"${KSROOT}/bin/easytier-cli" <<'EOF'
#!/bin/sh
sleep 2
exit 0
EOF
chmod 755 "${KSROOT}/bin/easytier-cli"
response="$(COMMAND_TIMEOUT_SECONDS=1 "${KSROOT}/scripts/easytier_config.sh" 0 get_node)"
decode_response "${response}" | grep -q 'CODE=CLI_TIMEOUT' || { echo "FAIL: CLI timeout was not reported" >&2; exit 1; }
response="$(${KSROOT}/scripts/easytier_config.sh 0 stop)"
decode_response "${response}" | grep -q 'CODE=SERVICE_STOPPED'
[ "$(cat "${DBUS_DIR}/easytier_autostart")" = "0" ] || { echo "FAIL: stop did not disable auto-start" >&2; exit 1; }

printf 'dmFsaWQ9ZmFsc2UK' >"${DBUS_DIR}/easytier_payload_102"
response="$(${KSROOT}/scripts/easytier_config.sh 102 save_config)"
decode_response "${response}" | grep -q 'CODE=CONFIG_REJECTED'
decode_response "${response}" | grep -q 'invalid test config'
grep -q '^valid=true$' "${CONFIG_FILE}" || { echo "FAIL: invalid config replaced the saved config" >&2; exit 1; }

printf 'dmFsaWQ9ZmFsc2UKc2lsZW50X2NoZWNrX2ZhaWx1cmU9dHJ1ZQo=' >"${DBUS_DIR}/easytier_payload_105"
response="$(${KSROOT}/scripts/easytier_config.sh 105 save_config)"
decode_response "${response}" | grep -q 'CODE=CONFIG_REJECTED'
decode_response "${response}" | grep -q 'invalid test config' || { echo "FAIL: silent validation failure had no diagnostic" >&2; exit 1; }

printf 'dmFsaWQ9dHJ1ZQpjaGVja19kZWxheT10cnVlCg==' >"${DBUS_DIR}/easytier_payload_106"
response="$(COMMAND_TIMEOUT_SECONDS=1 "${KSROOT}/scripts/easytier_config.sh" 106 save_config)"
decode_response "${response}" | grep -q 'CODE=CONFIG_CHECK_TIMEOUT' || { echo "FAIL: configuration check timeout was not reported" >&2; exit 1; }

printf 'dmFsaWQ9dHJ1ZQpjaGVja19kZWxheT10cnVlCg==' >"${DBUS_DIR}/easytier_payload_201"
printf 'dmFsaWQ9dHJ1ZQo=' >"${DBUS_DIR}/easytier_payload_202"
"${KSROOT}/scripts/easytier_config.sh" 201 save_config >"${TEST_ROOT}/save-201.response" &
save_pid=$!
sleep 1
response="$(${KSROOT}/scripts/easytier_config.sh 202 save_config)"
decode_response "${response}" | grep -q 'CODE=BUSY' || { echo "FAIL: concurrent save was not rejected" >&2; exit 1; }
wait "${save_pid}"
decode_response "$(cat "${TEST_ROOT}/save-201.response")" | grep -q 'CODE=CONFIG_SAVED'

mkdir -p "${TEST_ROOT}/fail-bin"
cat >"${TEST_ROOT}/fail-bin/mv" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "${TEST_ROOT}/fail-bin/mv"
printf 'dmFsaWQ9dHJ1ZQo=' >"${DBUS_DIR}/easytier_payload_203"
response="$(PATH="${TEST_ROOT}/fail-bin:${PATH}" "${KSROOT}/scripts/easytier_config.sh" 203 save_config)"
decode_response "${response}" | grep -q 'CODE=CONFIG_COMMIT_FAILED'
grep -q '^valid=true$' "${CONFIG_FILE}" || { echo "FAIL: commit failure replaced saved config" >&2; exit 1; }

printf 'historical log\n' >"${CORE_LOG}"
printf 'historical diagnostic\n' >"${SERVICE_LOG}"
printf 'older diagnostic\n' >"${SERVICE_LOG}.1"
clear_response="$(${KSROOT}/scripts/easytier_config.sh 103 clear_log)"
printf '%s' "${clear_response#ETB64:}" | base64 -d | grep -q 'CODE=LOG_CLEARED'
[ ! -s "${CORE_LOG}" ] || { echo "FAIL: core log was not cleared" >&2; exit 1; }
[ ! -s "${SERVICE_LOG}" ] || { echo "FAIL: service log was not cleared" >&2; exit 1; }
[ ! -e "${SERVICE_LOG}.1" ] || { echo "FAIL: archived service log was not cleared" >&2; exit 1; }

cat >"${KSROOT}/scripts/easytier_service.sh" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "${KSROOT}/scripts/easytier_service.sh"
printf '1' >"${DBUS_DIR}/easytier_autostart"
response="$(${KSROOT}/scripts/easytier_config.sh 0 stop)"
decode_response "${response}" | grep -q 'CODE=STOP_FAILED'
[ "$(cat "${DBUS_DIR}/easytier_autostart")" = "0" ] || { echo "FAIL: failed stop did not disable auto-start" >&2; exit 1; }
response="$(${KSROOT}/scripts/easytier_config.sh 0 start)"
decode_response "${response}" | grep -q 'CODE=START_FAILED'
[ "$(cat "${DBUS_DIR}/easytier_autostart")" = "0" ] || { echo "FAIL: failed start enabled auto-start" >&2; exit 1; }

echo "test_config_transaction.sh: PASS"
