#!/bin/sh
set -eu

MODULE="easytier"
DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
PLATFORM="${1:-}"
MATRIX="${DIR}/manifest/platforms.conf"

usage() {
	printf 'Usage: %s <platform>\n' "$0"
	printf 'Supported platforms: '
	awk '!/^#/ && NF >= 2 { printf "%s ", $1 } END { print "" }' "${MATRIX}"
}

[ -n "${PLATFORM}" ] || { usage; exit 2; }
[ -f "${MATRIX}" ] || { echo "Missing platform matrix" >&2; exit 1; }

ARCH="$(awk -v platform="${PLATFORM}" '$1 == platform { print $2; exit }' "${MATRIX}")"
[ -n "${ARCH}" ] || { echo "Unsupported platform: ${PLATFORM}" >&2; usage; exit 2; }

metadata_value() {
	sed -n "s/^$1=//p" "${DIR}/${MODULE}/version" | head -n 1
}

PLUGIN_VERSION="$(metadata_value PLUGIN_VERSION)"
CORE_VERSION="$(metadata_value CORE_VERSION)"
CORE_RELEASE_URL="$(metadata_value CORE_RELEASE_URL)"
BINARY_ARCH="$(metadata_value ARCH)"
[ -n "${PLUGIN_VERSION}" ] && [ -n "${CORE_VERSION}" ] && [ -n "${CORE_RELEASE_URL}" ] || { echo "Invalid version metadata" >&2; exit 1; }
CORE_VERSION_COMPACT="$(printf '%s' "${CORE_VERSION}" | tr -d '.')"
[ -n "${CORE_VERSION_COMPACT}" ] || { echo "Invalid core version metadata" >&2; exit 1; }
RELEASE_VERSION="${PLUGIN_VERSION}.${CORE_VERSION_COMPACT}"
[ "${ARCH}" = "${BINARY_ARCH}" ] || { echo "Binary architecture ${BINARY_ARCH} does not match ${PLATFORM} (${ARCH})" >&2; exit 1; }
[ -x "${DIR}/${MODULE}/bin/easytier-core" ] && [ -x "${DIR}/${MODULE}/bin/easytier-cli" ] || { echo "Run update_bins.sh first" >&2; exit 1; }

check_elf_arch() {
	binary_info="$(file "$1")"
	case "${ARCH}:${binary_info}" in
		aarch64:*ARM\ aarch64*|arm:*ARM*|x86_64:*x86-64*|mips:*MIPS*) return 0 ;;
	esac
	echo "Unexpected ELF architecture for $1: ${binary_info}" >&2
	return 1
}

check_elf_arch "${DIR}/${MODULE}/bin/easytier-core"
check_elf_arch "${DIR}/${MODULE}/bin/easytier-cli"

BUILD_DIR="${DIR}/build"
OUTPUT_DIR="${DIR}/output"
OUTPUT_FILE="${MODULE}_${PLATFORM}_${ARCH}_v${RELEASE_VERSION}.tar.gz"
trap 'rm -rf "${BUILD_DIR}"' EXIT INT TERM
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"
cp -R "${DIR}/${MODULE}" "${BUILD_DIR}/${MODULE}"
printf '%s\n' "${PLATFORM}" >"${BUILD_DIR}/${MODULE}/.valid"
chmod 755 "${BUILD_DIR}/${MODULE}/install.sh" "${BUILD_DIR}/${MODULE}/uninstall.sh" \
	"${BUILD_DIR}/${MODULE}/bin/"* "${BUILD_DIR}/${MODULE}/scripts/"*.sh

(cd "${BUILD_DIR}" && tar -zcf "${OUTPUT_FILE}" "${MODULE}")
mv "${BUILD_DIR}/${OUTPUT_FILE}" "${OUTPUT_DIR}/${OUTPUT_FILE}"
MD5="$(md5sum "${OUTPUT_DIR}/${OUTPUT_FILE}" | awk '{print $1}')"
SHA256="$(sha256sum "${OUTPUT_DIR}/${OUTPUT_FILE}" | awk '{print $1}')"
BUILD_DATE="$(date '+%Y-%m-%d_%H:%M:%S')"

printf '%s\n%s\n' "${RELEASE_VERSION}" "${MD5}" >"${DIR}/version"
cat >"${DIR}/config.json.js" <<EOF
{
  "version":"${RELEASE_VERSION}",
  "md5":"${MD5}",
  "sha256":"${SHA256}",
  "home_url":"Module_easytier.asp",
  "title":"EasyTier异地组网",
  "description":"基于EasyTier的去中心化异地组网插件",
  "tags":"网络 组网 VPN",
  "author":"drafens",
  "link":"https://github.com/drafens/koolshare-easytier",
  "changelog":"",
  "build_date":"${BUILD_DATE}",
  "platform":"${PLATFORM}",
  "arch":"${ARCH}",
  "plugin_version":"${PLUGIN_VERSION}",
  "core_version":"${CORE_VERSION}",
  "core_release_url":"${CORE_RELEASE_URL}"
}
EOF

printf 'Built %s\nMD5: %s\nSHA256: %s\n' "${OUTPUT_DIR}/${OUTPUT_FILE}" "${MD5}" "${SHA256}"
