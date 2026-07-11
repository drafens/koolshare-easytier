#!/bin/sh

KSROOT="${KSROOT:-/koolshare}"
PID_FILE="${PID_FILE:-/var/run/easytier.pid}"
. "${KSROOT}/scripts/base.sh"
. "${KSROOT}/scripts/easytier_common.sh"

# Remove service and Web entry points first so no new operation starts while
# the uninstaller waits for an in-flight request.
rm -f "${KSROOT}/init.d/S99easytier.sh" "${KSROOT}/init.d/N99easytier.sh"
rm -f "${KSROOT}/webs/Module_easytier.asp"
rm -f "${KSROOT}/scripts/easytier_config.sh" "${KSROOT}/scripts/easytier_status.sh"

dbus set easytier_autostart="0" >/dev/null 2>&1 || echo_date "警告：无法关闭 EasyTier 开机启动状态"
lock_acquired=0
if acquire_lock_wait "${LOCK_WAIT_SECONDS}"; then
	lock_acquired=1
else
	echo_date "警告：EasyTier 操作锁超时，将继续强制卸载"
fi
if ! force_stop_easytier; then
	echo_date "警告：无法停止全部 EasyTier 进程，将继续卸载插件文件，建议重启路由完成卸载"
fi
rm -f "${KSROOT}/res/icon-easytier.png" "${KSROOT}/res/easytier.js"
rm -f "${KSROOT}/bin/easytier-core" "${KSROOT}/bin/easytier-cli"
rm -f "${KSROOT}/scripts/easytier_config.sh" "${KSROOT}/scripts/easytier_service.sh"
rm -f "${KSROOT}/scripts/easytier_status.sh" "${KSROOT}/scripts/easytier_common.sh"
rm -f "${KSROOT}/scripts/easytier_event.sh"
rm -f "${KSROOT}/webs/Module_easytier.asp" "${KSROOT}/scripts/uninstall_easytier.sh"

dbus remove easytier_autostart >/dev/null 2>&1 || true
dbus remove easytier_core_version >/dev/null 2>&1 || true

for payload_key in $(dbus list easytier_payload_ 2>/dev/null | cut -d= -f1); do
	dbus remove "${payload_key}" >/dev/null 2>&1 || true
done

dbus remove softcenter_module_easytier_version >/dev/null 2>&1 || true
dbus remove softcenter_module_easytier_install >/dev/null 2>&1 || true
dbus remove softcenter_module_easytier_name >/dev/null 2>&1 || true
dbus remove softcenter_module_easytier_title >/dev/null 2>&1 || true
dbus remove softcenter_module_easytier_description >/dev/null 2>&1 || true

if [ "$1" = "purge" ]; then
	rm -f "${KSROOT}/configs/easytier.toml"
fi

[ "${lock_acquired}" -eq 0 ] || release_lock
rm -rf "${RUNTIME_DIR}"
