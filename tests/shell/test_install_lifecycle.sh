#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT INT TERM

export KSROOT="${TEST_ROOT}/koolshare"
export PID_FILE="${TEST_ROOT}/easytier.pid"
export RUNTIME_DIR="${TEST_ROOT}/runtime"
export LOCK_DIR="${RUNTIME_DIR}/service.lock"
export CORE_LOG="${RUNTIME_DIR}/easytier.log"
export LOCK_WAIT_SECONDS=1
export DBUS_DIR="${TEST_ROOT}/dbus"
export PATH="${TEST_ROOT}/bin:${PATH}"
PACKAGE_DIR="${TEST_ROOT}/package"
mkdir -p "${KSROOT}/bin" "${KSROOT}/scripts" "${KSROOT}/configs" "${DBUS_DIR}" "${TEST_ROOT}/bin"
cp -R "${ROOT}/easytier" "${PACKAGE_DIR}"
cc -O2 -o "${PACKAGE_DIR}/bin/easytier-core" "${ROOT}/tests/fixtures/fake_easytier_core.c"
cat >"${PACKAGE_DIR}/bin/easytier-cli" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "${PACKAGE_DIR}/bin/easytier-cli"
cp "${PACKAGE_DIR}/bin/easytier-core" "${KSROOT}/bin/easytier-core"

cat >"${KSROOT}/scripts/base.sh" <<'EOF'
#!/bin/sh
echo_date() { :; }
EOF
cat >"${KSROOT}/scripts/easytier_service.sh" <<'EOF'
#!/bin/sh
exit 1
EOF
cat >"${TEST_ROOT}/bin/dbus" <<'EOF'
#!/bin/sh
command="$1"
shift
case "${command}" in
	get) [ -f "${DBUS_DIR}/$1" ] && cat "${DBUS_DIR}/$1" ;;
	set) key="${1%%=*}"; value="${1#*=}"; [ "${DBUS_FAIL_KEY:-}" != "${key}" ] || exit 1; printf '%s' "${value}" >"${DBUS_DIR}/${key}" ;;
	remove) rm -f "${DBUS_DIR}/$1" ;;
	list) for file in "${DBUS_DIR}/$1"*; do [ -f "${file}" ] && printf '%s=%s\n' "${file##*/}" "$(cat "${file}")"; done ;;
esac
EOF
cat >"${TEST_ROOT}/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' aarch64
EOF
chmod 755 "${KSROOT}/scripts/"* "${TEST_ROOT}/bin/"*

printf 'valid=true\n' >"${KSROOT}/configs/easytier.toml"
printf '1' >"${DBUS_DIR}/easytier_autostart"
"${KSROOT}/bin/easytier-core" -c "${KSROOT}/configs/easytier.toml" &
old_pid=$!
printf '%s\n' "${old_pid}" >"${PID_FILE}"
mkdir -p "${LOCK_DIR}"
sleep 5 &
lock_owner=$!
printf '%s\n' "${lock_owner}" >"${LOCK_DIR}/pid"
if "${PACKAGE_DIR}/install.sh"; then
	echo "FAIL: installer ignored a busy lifecycle lock" >&2
	exit 1
fi
kill -0 "${old_pid}" 2>/dev/null || { echo "FAIL: failed installer modified the running service" >&2; exit 1; }
kill "${lock_owner}" 2>/dev/null || true
wait "${lock_owner}" 2>/dev/null || true
rm -rf "${LOCK_DIR}"

if DBUS_FAIL_KEY=easytier_core_version "${PACKAGE_DIR}/install.sh"; then
	echo "FAIL: installer reported success after a metadata failure" >&2
	exit 1
fi
"${PACKAGE_DIR}/install.sh"
if kill -0 "${old_pid}" 2>/dev/null; then
	echo "FAIL: installer did not stop the residual EasyTier process" >&2
	exit 1
fi
[ -x "${KSROOT}/scripts/easytier_service.sh" ] || { echo "FAIL: installer did not install the service script" >&2; exit 1; }
plugin_version="$(sed -n 's/^PLUGIN_VERSION=//p' "${PACKAGE_DIR}/version")"
core_version="$(sed -n 's/^CORE_VERSION=//p' "${PACKAGE_DIR}/version" | tr -d '.')"
release_version="${plugin_version}.${core_version}"
grep -q "easytier.js?v=${release_version}" "${KSROOT}/webs/Module_easytier.asp" || { echo "FAIL: installer did not stamp the JS cache version" >&2; exit 1; }
[ "$(cat "${DBUS_DIR}/easytier_autostart")" = "1" ] || { echo "FAIL: installer did not preserve the boot preference" >&2; exit 1; }
[ ! -e "${PID_FILE}" ] || { echo "FAIL: installer unexpectedly restarted EasyTier" >&2; exit 1; }

"${KSROOT}/bin/easytier-core" -c "${KSROOT}/configs/easytier.toml" &
new_pid=$!
printf '%s\n' "${new_pid}" >"${PID_FILE}"
"${KSROOT}/scripts/uninstall_easytier.sh"
if kill -0 "${new_pid}" 2>/dev/null; then
	echo "FAIL: uninstaller did not stop the EasyTier process" >&2
	exit 1
fi
[ ! -e "${KSROOT}/bin/easytier-core" ] || { echo "FAIL: uninstaller kept the core binary" >&2; exit 1; }
[ ! -e "${KSROOT}/webs/Module_easytier.asp" ] || { echo "FAIL: uninstaller kept the management page" >&2; exit 1; }
[ ! -e "${DBUS_DIR}/easytier_autostart" ] || { echo "FAIL: uninstaller kept the boot preference" >&2; exit 1; }

"${PACKAGE_DIR}/install.sh"
printf '\nforce_stop_easytier() { return 1; }\n' >>"${KSROOT}/scripts/easytier_common.sh"
mkdir -p "${LOCK_DIR}"
sleep 5 &
lock_owner=$!
printf '%s\n' "${lock_owner}" >"${LOCK_DIR}/pid"
"${KSROOT}/scripts/uninstall_easytier.sh"
kill "${lock_owner}" 2>/dev/null || true
wait "${lock_owner}" 2>/dev/null || true
[ ! -e "${KSROOT}/bin/easytier-core" ] || { echo "FAIL: forced uninstaller kept the core binary" >&2; exit 1; }
[ ! -e "${KSROOT}/webs/Module_easytier.asp" ] || { echo "FAIL: forced uninstaller kept the management page" >&2; exit 1; }

echo "test_install_lifecycle.sh: PASS"
