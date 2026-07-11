#!/bin/sh

export KSROOT="${KSROOT:-/koolshare}"
. "${KSROOT}/scripts/base.sh"
. "${KSROOT}/scripts/easytier_common.sh"

pid="$(get_easytier_pid 2>/dev/null || true)"
if [ -n "${pid}" ]; then
	state="running"
else
	last_state="$(sed -n '1p' "${STATE_FILE}" 2>/dev/null)"
	case "${last_state}" in
		failed|running) state="failed" ;;
		*) state="stopped" ;;
	esac
fi
core_version="$(dbus get easytier_core_version 2>/dev/null)"
plugin_version="$(dbus get softcenter_module_easytier_version 2>/dev/null)"
if [ -n "${core_version}" ]; then
	core_release_url="https://github.com/EasyTier/EasyTier/releases/tag/v${core_version}"
else
	core_release_url="https://github.com/EasyTier/EasyTier/releases"
fi

response_payload="STATE=${state}
PID=${pid}
CORE_VERSION=${core_version:-unknown}
CORE_RELEASE_URL=${core_release_url}
PLUGIN_VERSION=${plugin_version:-unknown}"

http_response "$(http_safe_payload "${response_payload}")"
