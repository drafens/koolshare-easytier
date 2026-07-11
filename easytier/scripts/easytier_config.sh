#!/bin/sh

export KSROOT="${KSROOT:-/koolshare}"
. "${KSROOT}/scripts/base.sh"
. "${KSROOT}/scripts/easytier_common.sh"

SERVICE_SCRIPT="${KSROOT}/scripts/easytier_service.sh"
REQUEST_ID="$1"
ACTION="$2"

respond() {
	http_response "$(http_safe_payload "$1")"
}

get_config() {
	if [ -f "${CONFIG_FILE}" ]; then
		respond "$(write_result success CONFIG_LOADED 'Configuration loaded')

$(cat "${CONFIG_FILE}")"
	else
		respond "$(write_result success CONFIG_EMPTY 'No configuration has been saved')"
	fi
}

save_config() {
	payload_key="easytier_payload_${REQUEST_ID}"
	if ! ensure_runtime_dirs; then
		respond "$(write_result failed RUNTIME_UNAVAILABLE 'Runtime directory is unavailable')"
		return
	fi
	payload_b64="$(dbus get "${payload_key}" 2>/dev/null)"
	dbus remove "${payload_key}" >/dev/null 2>&1 || true

	[ -n "${payload_b64}" ] || { respond "$(write_result failed CONFIG_EMPTY 'Configuration is empty')"; return; }
	if ! acquire_lock; then
		respond "$(write_result failed BUSY 'Another operation is in progress')"
		return
	fi
	trap 'release_lock' EXIT
	trap 'exit 1' HUP INT TERM
	candidate="${CONFIG_FILE}.new"
	rm -f "${candidate}"
	if ! printf '%s' "${payload_b64}" | base64 -d >"${candidate}" 2>/dev/null; then
		rm -f "${candidate}"
		respond "$(write_result failed CONFIG_DECODE_FAILED 'Configuration encoding is invalid')"
		return
	fi
	config_size="$(wc -c <"${candidate}" | tr -d ' ')"
	if [ ! -s "${candidate}" ] || [ "${config_size:-0}" -gt "${MAX_CONFIG_BYTES}" ]; then
		rm -f "${candidate}"
		respond "$(write_result failed CONFIG_SIZE_INVALID 'Configuration is empty or too large')"
		return
	fi
	if ! chmod 600 "${candidate}"; then
		rm -f "${candidate}"
		respond "$(write_result failed CONFIG_PERMISSION_FAILED 'Configuration permissions could not be set')"
		return
	fi
	check_deadline=$(( $(date +%s) + COMMAND_TIMEOUT_SECONDS ))
	check_output_file="${RUNTIME_DIR}/config-check.$$"
	run_with_timeout "${COMMAND_TIMEOUT_SECONDS}" "${check_output_file}" \
		"${CORE_BIN}" -c "${candidate}" --check-config
	check_status=$?
	check_output="$(cat "${check_output_file}" 2>/dev/null)"
	rm -f "${check_output_file}"
	if [ "${check_status}" -eq 124 ]; then
		rm -f "${candidate}"
		respond "$(write_result failed CONFIG_CHECK_TIMEOUT 'Configuration validation timed out')"
		return
	fi
	if [ "${check_status}" -ne 0 ]; then
		# EasyTier validates before its logger is initialized, so this
		# command can fail without writing the parser error to stderr. The normal
		# path initializes an error-only logger and uses an ephemeral local RPC port.
		if [ -z "${check_output}" ]; then
			remaining_seconds=$(( check_deadline - $(date +%s) ))
			if [ "${remaining_seconds}" -gt 0 ]; then
				diagnostic_output_file="${RUNTIME_DIR}/config-diagnostic.$$"
				run_with_timeout "${remaining_seconds}" "${diagnostic_output_file}" \
					"${CORE_BIN}" -c "${candidate}" --rpc-portal "127.0.0.1:0" \
					--console-log-level error
				diagnostic_status=$?
				check_output="$(cat "${diagnostic_output_file}" 2>/dev/null)"
				rm -f "${diagnostic_output_file}"
				[ "${diagnostic_status}" -ne 124 ] || check_output="Configuration diagnostics timed out."
			fi
		fi
		[ -n "${check_output}" ] || check_output="EasyTier did not provide a configuration error."
		rm -f "${candidate}"
		respond "$(write_result failed CONFIG_REJECTED 'EasyTier rejected the configuration')

${check_output}"
		return
	fi
	if ! mv -f "${candidate}" "${CONFIG_FILE}"; then
		rm -f "${candidate}"
		respond "$(write_result failed CONFIG_COMMIT_FAILED 'Configuration could not be committed; the previous configuration was preserved')"
		return
	fi
	respond "$(write_result success CONFIG_SAVED 'Configuration saved; restart EasyTier to apply it')"
}

start_action() {
	if "${SERVICE_SCRIPT}" start; then
		if dbus set easytier_autostart="1"; then
			respond "$(write_result success SERVICE_RUNNING 'EasyTier started')"
		else
			respond "$(write_result failed AUTOSTART_SAVE_FAILED 'EasyTier started, but its auto-start state could not be saved')"
		fi
	else
		message="$(tail_core_log 20 2>/dev/null)"
		respond "$(write_result failed START_FAILED 'EasyTier failed to start')

${message}"
	fi
}

stop_action() {
	autostart_saved=1
	dbus set easytier_autostart="0" || autostart_saved=0
	if "${SERVICE_SCRIPT}" stop; then
		if [ "${autostart_saved}" -eq 1 ]; then
			respond "$(write_result success SERVICE_STOPPED 'EasyTier stopped')"
		else
			respond "$(write_result failed AUTOSTART_SAVE_FAILED 'EasyTier stopped, but its auto-start state could not be saved')"
		fi
	else
		respond "$(write_result failed STOP_FAILED 'EasyTier failed to stop')"
	fi
}

cli_action() {
	cli_command="$1"
	if ! get_easytier_pid >/dev/null 2>&1; then
		respond "$(write_result failed SERVICE_STOPPED 'EasyTier is not running')"
		return
	fi
	ensure_runtime_dirs || { respond "$(write_result failed RUNTIME_UNAVAILABLE 'Runtime directory is unavailable')"; return; }
	cli_output_file="${RUNTIME_DIR}/cli-${cli_command}.$$"
	run_with_timeout "${COMMAND_TIMEOUT_SECONDS}" "${cli_output_file}" "${CLI_BIN}" "${cli_command}"
	ret=$?
	output="$(cat "${cli_output_file}" 2>/dev/null)"
	rm -f "${cli_output_file}"
	if [ "${ret}" -eq 124 ]; then
		respond "$(write_result failed CLI_TIMEOUT 'EasyTier CLI command timed out')"
		return
	fi
	if [ "${ret}" -eq 0 ]; then
		respond "$(write_result success CLI_OK 'Command completed')

${output}"
	else
		respond "$(write_result failed CLI_FAILED 'EasyTier CLI command failed')

${output}"
	fi
}

clear_log() {
	if ! acquire_lock; then
		respond "$(write_result failed BUSY 'Another operation is in progress')"
		return
	fi
	trap 'release_lock' EXIT
	trap 'exit 1' HUP INT TERM
	clear_core_log || { respond "$(write_result failed LOG_CLEAR_FAILED 'Log could not be cleared')"; return; }
	respond "$(write_result success LOG_CLEARED 'Log cleared')"
}

case "${ACTION}" in
	get_config) get_config ;;
	save_config) save_config ;;
	start) start_action ;;
	stop) stop_action ;;
	get_node) cli_action node ;;
	get_peers) cli_action peer ;;
	get_routes) cli_action route ;;
	clear_log) clear_log ;;
	get_log)
		respond "$(write_result success LOG_LOADED 'Log loaded')

$(tail_core_log 200 2>/dev/null)"
		;;
	*) respond "$(write_result failed UNKNOWN_ACTION 'Unknown action')" ;;
esac
