#!/bin/sh

KSROOT="${KSROOT:-/koolshare}"
CORE_BIN="${CORE_BIN:-${KSROOT}/bin/easytier-core}"
CLI_BIN="${CLI_BIN:-${KSROOT}/bin/easytier-cli}"
CONFIG_DIR="${CONFIG_DIR:-${KSROOT}/configs}"
CONFIG_FILE="${CONFIG_FILE:-${CONFIG_DIR}/easytier.toml}"
RUNTIME_DIR="${RUNTIME_DIR:-/tmp/easytier}"
PID_FILE="${PID_FILE:-/var/run/easytier.pid}"
LOCK_DIR="${LOCK_DIR:-${RUNTIME_DIR}/service.lock}"
CORE_LOG="${CORE_LOG:-${RUNTIME_DIR}/easytier.log}"
SERVICE_LOG="${SERVICE_LOG:-${RUNTIME_DIR}/easytier-service.log}"
STATE_FILE="${STATE_FILE:-${RUNTIME_DIR}/service.state}"
MAX_CONFIG_BYTES="${MAX_CONFIG_BYTES:-262144}"
MAX_SERVICE_LOG_BYTES="${MAX_SERVICE_LOG_BYTES:-1048576}"
COMMAND_TIMEOUT_SECONDS="${COMMAND_TIMEOUT_SECONDS:-8}"
STARTUP_TIMEOUT_SECONDS="${STARTUP_TIMEOUT_SECONDS:-8}"
STOP_WAIT_SECONDS="${STOP_WAIT_SECONDS:-8}"
LOCK_WAIT_SECONDS="${LOCK_WAIT_SECONDS:-10}"

ensure_runtime_dirs() {
	mkdir -p "${CONFIG_DIR}" "${RUNTIME_DIR}" || return 1
	chmod 700 "${RUNTIME_DIR}" 2>/dev/null || true
}

log_line() {
	ensure_runtime_dirs || return 1
	trim_service_log || return 1
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"${SERVICE_LOG}"
}

trim_service_log() {
	[ -f "${SERVICE_LOG}" ] || return 0
	service_log_bytes="$(wc -c <"${SERVICE_LOG}" 2>/dev/null)" || return 1
	[ "${service_log_bytes}" -le "${MAX_SERVICE_LOG_BYTES}" ] && return 0
	cp -f "${SERVICE_LOG}" "${SERVICE_LOG}.1" || return 1
	: >"${SERVICE_LOG}"
}

acquire_lock() {
	ensure_runtime_dirs || return 1
	if mkdir "${LOCK_DIR}" 2>/dev/null; then
		printf '%s\n' "$$" >"${LOCK_DIR}/pid"
		return 0
	fi

	lock_pid="$(sed -n '1p' "${LOCK_DIR}/pid" 2>/dev/null)"
	case "${lock_pid}" in
		''|*[!0-9]*) ;;
		*) kill -0 "${lock_pid}" 2>/dev/null && return 1 ;;
	esac
	rm -rf "${LOCK_DIR}" 2>/dev/null || return 1
	mkdir "${LOCK_DIR}" 2>/dev/null || return 1
	printf '%s\n' "$$" >"${LOCK_DIR}/pid"
}

acquire_lock_wait() {
	wait_seconds="${1:-${LOCK_WAIT_SECONDS}}"
	wait_deadline=$(( $(date +%s) + wait_seconds ))
	while ! acquire_lock; do
		[ "$(date +%s)" -ge "${wait_deadline}" ] && return 1
		sleep 1
	done
}

release_lock() {
	lock_pid="$(sed -n '1p' "${LOCK_DIR}/pid" 2>/dev/null)"
	[ "${lock_pid}" = "$$" ] || return 0
	rm -rf "${LOCK_DIR}" 2>/dev/null
}

read_pid() {
	pid="$(sed -n '1p' "${PID_FILE}" 2>/dev/null)"
	case "${pid}" in
		''|*[!0-9]*) return 1 ;;
	esac
	printf '%s\n' "${pid}"
}

is_easytier_pid() {
	check_pid="$1"
	case "${check_pid}" in
		''|*[!0-9]*) return 1 ;;
	esac
	kill -0 "${check_pid}" 2>/dev/null || return 1
	check_exe="$(readlink "/proc/${check_pid}/exe" 2>/dev/null)"
	check_exe="${check_exe% (deleted)}"
	case "${check_exe##*/}" in
		easytier-core) return 0 ;;
	esac
	return 1
}

list_easytier_pids() {
	for proc_dir in /proc/[0-9]*; do
		proc_pid="${proc_dir##*/}"
		is_easytier_pid "${proc_pid}" && printf '%s\n' "${proc_pid}"
	done
}

get_easytier_pid() {
	running_pid="$(read_pid 2>/dev/null || true)"
	if [ -n "${running_pid}" ] && is_easytier_pid "${running_pid}"; then
		printf '%s\n' "${running_pid}"
		return 0
	fi
	for running_pid in $(list_easytier_pids); do
		printf '%s\n' "${running_pid}" >"${PID_FILE}"
		printf '%s\n' "${running_pid}"
		return 0
	done
	rm -f "${PID_FILE}" 2>/dev/null
	return 1
}

write_service_state() {
	ensure_runtime_dirs || return 1
	printf '%s\n' "$1" >"${STATE_FILE}"
}

run_with_timeout() {
	timeout_seconds="$1"
	output_file="$2"
	shift 2
	rm -f "${output_file}"
	"$@" >"${output_file}" 2>&1 &
	command_pid=$!
	command_deadline=$(( $(date +%s) + timeout_seconds ))
	command_timed_out=0
	while ! process_has_exited "${command_pid}"; do
		if [ "$(date +%s)" -ge "${command_deadline}" ]; then
			command_timed_out=1
			kill "${command_pid}" 2>/dev/null || true
			kill -9 "${command_pid}" 2>/dev/null || true
			break
		fi
		sleep 1
	done
	wait "${command_pid}" 2>/dev/null
	command_status=$?
	[ "${command_timed_out}" -eq 0 ] || return 124
	return "${command_status}"
}

process_has_exited() {
	check_pid="$1"
	kill -0 "${check_pid}" 2>/dev/null || return 0
	proc_state="$(sed -n 's/^.*) \([^ ]\).*/\1/p' "/proc/${check_pid}/stat" 2>/dev/null)"
	[ "${proc_state}" = "Z" ]
}

core_rpc_is_ready() {
	ensure_runtime_dirs || return 1
	probe_output="${RUNTIME_DIR}/rpc-probe.$$"
	run_with_timeout 1 "${probe_output}" "${CLI_BIN}" node
	probe_status=$?
	rm -f "${probe_output}"
	return "${probe_status}"
}

force_stop_easytier() {
	stop_seconds="${1:-${STOP_WAIT_SECONDS}}"
	et_running_pids="$(list_easytier_pids)"
	[ -n "${et_running_pids}" ] || { rm -f "${PID_FILE}"; return 0; }
	for et_running_pid in ${et_running_pids}; do
		kill "${et_running_pid}" 2>/dev/null || true
	done
	stop_deadline=$(( $(date +%s) + stop_seconds ))
	while [ -n "$(list_easytier_pids)" ] && [ "$(date +%s)" -lt "${stop_deadline}" ]; do
		sleep 1
	done
	for et_running_pid in $(list_easytier_pids); do
		kill -9 "${et_running_pid}" 2>/dev/null || true
	done
	[ -z "$(list_easytier_pids)" ] || sleep 1
	[ -z "$(list_easytier_pids)" ] || return 1
	rm -f "${PID_FILE}"
}

tail_core_log() {
	line_count="$1"
	{
		for log_file in "${CORE_LOG}".* "${CORE_LOG}"; do
			[ -f "${log_file}" ] && cat "${log_file}"
		done
		for log_file in "${SERVICE_LOG}.1" "${SERVICE_LOG}"; do
			[ -f "${log_file}" ] && cat "${log_file}"
		done
	} | tail -n "${line_count}"
}

clear_service_log() {
	rm -f "${SERVICE_LOG}.1" 2>/dev/null || return 1
	: >"${SERVICE_LOG}" || return 1
	chmod 600 "${SERVICE_LOG}" 2>/dev/null || true
}

clear_core_log() {
	ensure_runtime_dirs || return 1
	rm -f "${CORE_LOG}".* 2>/dev/null || return 1
	: >"${CORE_LOG}" || return 1
	chmod 600 "${CORE_LOG}" 2>/dev/null || true
	clear_service_log
}

write_result() {
	result="$1"
	code="$2"
	message="$3"
	printf 'RESULT=%s\nCODE=%s\nMESSAGE=%s\n' "${result}" "${code}" "${message}"
}

http_safe_payload() {
	encoded_payload="$(printf '%s' "$1" | base64 | tr -d '\r\n')" || return 1
	printf 'ETB64:%s\n' "${encoded_payload}"
}
