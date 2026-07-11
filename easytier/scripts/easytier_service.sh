#!/bin/sh

KSROOT="${KSROOT:-/koolshare}"
. "${KSROOT}/scripts/easytier_common.sh"

start_service() {
	config_path="${1:-${CONFIG_FILE}}"
	startup_deadline=$(( $(date +%s) + STARTUP_TIMEOUT_SECONDS ))
	if get_easytier_pid >/dev/null 2>&1; then
		core_rpc_is_ready && return 0
		log_line "EasyTier process exists but its RPC portal is unavailable"
		remaining_seconds=$(( startup_deadline - $(date +%s) ))
		[ "${remaining_seconds}" -gt 0 ] || remaining_seconds=1
		force_stop_easytier "${remaining_seconds}" || { write_service_state failed; return 1; }
	fi
	[ -x "${CORE_BIN}" ] || { log_line "EasyTier core does not exist or is not executable"; write_service_state failed; return 1; }
	[ -s "${config_path}" ] || { log_line "EasyTier configuration is empty"; write_service_state failed; return 1; }

	ensure_runtime_dirs || return 1
	clear_core_log || return 1
	nohup "${CORE_BIN}" -c "${config_path}" \
		--console-log-level off \
		--file-log-level info \
		--file-log-dir "${RUNTIME_DIR}" \
		--file-log-size 1 \
		--file-log-count 1 >>"${SERVICE_LOG}" 2>&1 &
	new_pid=$!
	printf '%s\n' "${new_pid}" >"${PID_FILE}"

	while [ "$(date +%s)" -lt "${startup_deadline}" ]; do
		if ! is_easytier_pid "${new_pid}"; then
			rm -f "${PID_FILE}"
			write_service_state failed
			return 1
		fi
		if core_rpc_is_ready; then
			write_service_state running
			return 0
		fi
		sleep 1
	done
	if ! is_easytier_pid "${new_pid}"; then
		rm -f "${PID_FILE}"
		write_service_state failed
		return 1
	fi
	log_line "EasyTier default RPC portal did not become ready"
	force_stop_easytier 1 || log_line "Unable to stop EasyTier after RPC readiness failure"
	write_service_state failed
	return 1
}

stop_service() {
	if ! force_stop_easytier; then
		log_line "Unable to stop EasyTier process"
		return 1
	fi
	write_service_state stopped
}

with_lock() {
	command_name="$1"
	shift
	if ! acquire_lock; then
		log_line "Another EasyTier operation is in progress"
		return 2
	fi
	trap 'release_lock' EXIT
	trap 'exit 1' HUP INT TERM
	"${command_name}" "$@"
	ret=$?
	release_lock
	trap - EXIT INT TERM
	return "${ret}"
}

case "$1" in
	start) with_lock start_service "${2:-${CONFIG_FILE}}" ;;
	stop) with_lock stop_service ;;
	*) printf 'Usage: %s {start|stop}\n' "$0" >&2; exit 2 ;;
esac
