#!/bin/sh

DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
KSROOT="${KSROOT:-/koolshare}"
PID_FILE="${PID_FILE:-/var/run/easytier.pid}"
. "${KSROOT}/scripts/base.sh"
. "${DIR}/scripts/easytier_common.sh"
TITLE="EasyTier 异地组网"
DESCRIPTION="基于 EasyTier 的去中心化异地组网插件"

metadata_value() {
	sed -n "s/^$1=//p" "${DIR}/version" 2>/dev/null | head -n 1
}

fail() {
	echo_date "安装失败：$*"
	echo_date "请重新安装；若软件中心仍显示插件已安装，请先卸载后重新安装。"
	exit 1
}

preflight() {
	[ -d "${KSROOT}" ] || fail "未检测到 Softcenter"
	for required_file in \
		bin/easytier-core bin/easytier-cli \
		scripts/easytier_common.sh scripts/easytier_config.sh \
		scripts/easytier_event.sh scripts/easytier_service.sh \
		scripts/easytier_status.sh webs/Module_easytier.asp \
		res/easytier.js res/icon-easytier.png uninstall.sh version; do
		[ -f "${DIR}/${required_file}" ] || fail "安装包缺少 ${required_file}"
	done
	[ -x "${DIR}/bin/easytier-core" ] || fail "easytier-core 不可执行"
	[ -x "${DIR}/bin/easytier-cli" ] || fail "easytier-cli 不可执行"
	[ -n "$(metadata_value PLUGIN_VERSION)" ] || fail "插件版本元数据无效"
	[ -n "$(metadata_value CORE_VERSION)" ] || fail "核心版本元数据无效"
	[ -n "$(metadata_value CORE_RELEASE_URL)" ] || fail "核心发布地址元数据无效"
	binary_arch="$(metadata_value ARCH)"
	machine="$(uname -m)"
	case "${binary_arch}:${machine}" in
		aarch64:aarch64|aarch64:arm64|arm:arm*|x86_64:x86_64|mips:mips*) ;;
		*) fail "安装包架构 ${binary_arch} 与路由器架构 ${machine} 不匹配" ;;
	esac
}

install_files() {
	echo_date "安装插件文件..."
	mkdir -p "${KSROOT}/bin" "${KSROOT}/scripts" "${KSROOT}/webs" \
		"${KSROOT}/res" "${KSROOT}/configs" "${KSROOT}/init.d" || fail "无法创建目录"
	cp -f "${DIR}/bin/easytier-core" "${KSROOT}/bin/" || fail "无法安装 easytier-core"
	cp -f "${DIR}/bin/easytier-cli" "${KSROOT}/bin/" || fail "无法安装 easytier-cli"
	cp -f "${DIR}/scripts/"*.sh "${KSROOT}/scripts/" || fail "无法安装后端脚本"
	cp -f "${DIR}/webs/Module_easytier.asp" "${KSROOT}/webs/" || fail "无法安装管理页面"
	cp -f "${DIR}/res/"* "${KSROOT}/res/" || fail "无法安装页面资源"
	cp -f "${DIR}/uninstall.sh" "${KSROOT}/scripts/uninstall_easytier.sh" || fail "无法安装卸载脚本"

	chmod 755 "${KSROOT}/bin/easytier-core" "${KSROOT}/bin/easytier-cli" \
		"${KSROOT}/scripts/easytier_"*.sh "${KSROOT}/scripts/uninstall_easytier.sh" || fail "无法设置插件文件权限"
	chmod 600 "${KSROOT}/configs/easytier.toml" 2>/dev/null || true
	ln -sf "${KSROOT}/scripts/easytier_event.sh" "${KSROOT}/init.d/S99easytier.sh" || fail "无法创建开机启动链接"
}

write_metadata() {
	plugin_version="$(metadata_value PLUGIN_VERSION)"
	core_version="$(metadata_value CORE_VERSION)"
	core_version_compact="$(printf '%s' "${core_version}" | tr -d '.')"
	release_version="${plugin_version}.${core_version_compact}"
	sed -i "s/__EASYTIER_RELEASE_VERSION__/${release_version}/g" "${KSROOT}/webs/Module_easytier.asp" || fail "无法更新页面资源版本"
	dbus set easytier_core_version="${core_version}" || fail "无法写入核心版本"
	dbus set softcenter_module_easytier_version="${release_version}" || fail "无法写入软件中心版本"
	dbus set softcenter_module_easytier_install="1" || fail "无法写入软件中心安装状态"
	dbus set softcenter_module_easytier_name="easytier" || fail "无法写入软件中心名称"
	dbus set softcenter_module_easytier_title="${TITLE}" || fail "无法写入软件中心标题"
	dbus set softcenter_module_easytier_description="${DESCRIPTION}" || fail "无法写入软件中心描述"
	if [ -z "$(dbus get easytier_autostart 2>/dev/null)" ]; then
		dbus set easytier_autostart="0" || fail "无法初始化开机启动状态"
	fi

	for payload_key in $(dbus list easytier_payload_ 2>/dev/null | cut -d= -f1); do
		dbus remove "${payload_key}" >/dev/null 2>&1 || true
	done
}

preflight
if ! acquire_lock_wait "${LOCK_WAIT_SECONDS}"; then
	fail "插件操作未结束，请稍后重试"
fi
trap 'release_lock' EXIT
trap 'exit 1' HUP INT TERM
echo_date "停止现有 EasyTier 服务..."
force_stop_easytier || fail "无法停止现有 EasyTier 进程，已取消升级"
install_files
write_metadata
release_lock
trap - EXIT HUP INT TERM

echo_date "${TITLE} ${release_version} 安装完成"
exit 0
