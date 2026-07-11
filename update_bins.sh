#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
ARCH="${1:-}"
VERSION="${2:-}"

[ -n "${ARCH}" ] || { echo "Usage: $0 <arm|aarch64|x86_64|mips> <version>" >&2; exit 2; }
[ -n "${VERSION}" ] || { echo "A pinned EasyTier version is required" >&2; exit 2; }
case "${VERSION}" in v*) TAG="${VERSION}" ;; *) TAG="v${VERSION}" ;; esac

ASSET="easytier-linux-${ARCH}-${TAG}.zip"
RELEASE_API="https://api.github.com/repos/EasyTier/EasyTier/releases/tags/${TAG}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT INT TERM

echo "Fetching EasyTier ${TAG} release metadata..."
curl -fsSL "${RELEASE_API}" -o "${TMPDIR}/release.json"
python3 "${DIR}/tools/release_asset.py" "${TMPDIR}/release.json" "${ASSET}" >"${TMPDIR}/asset"
URL="$(sed -n '1p' "${TMPDIR}/asset")"
DIGEST="$(sed -n '2p' "${TMPDIR}/asset")"
[ -n "${URL}" ] && [ -n "${DIGEST}" ] || { echo "Release asset metadata is incomplete" >&2; exit 1; }

echo "Downloading ${ASSET}..."
curl -fsSL "${URL}" -o "${TMPDIR}/${ASSET}"
printf '%s  %s\n' "${DIGEST#sha256:}" "${TMPDIR}/${ASSET}" | sha256sum -c -
unzip -q "${TMPDIR}/${ASSET}" -d "${TMPDIR}/unpack"
SOURCE_DIR="${TMPDIR}/unpack/easytier-linux-${ARCH}"
[ -x "${SOURCE_DIR}/easytier-core" ] && [ -x "${SOURCE_DIR}/easytier-cli" ] || { echo "Release archive is missing required binaries" >&2; exit 1; }

check_elf_arch() {
	binary_info="$(file "$1")"
	case "${ARCH}:${binary_info}" in
		aarch64:*ARM\ aarch64*|arm:*ARM*|x86_64:*x86-64*|mips:*MIPS*) return 0 ;;
	esac
	echo "Unexpected ELF architecture: ${binary_info}" >&2
	return 1
}

check_elf_arch "${SOURCE_DIR}/easytier-core"
check_elf_arch "${SOURCE_DIR}/easytier-cli"

mkdir -p "${DIR}/easytier/bin"
cp -f "${SOURCE_DIR}/easytier-core" "${DIR}/easytier/bin/easytier-core"
cp -f "${SOURCE_DIR}/easytier-cli" "${DIR}/easytier/bin/easytier-cli"
chmod 755 "${DIR}/easytier/bin/easytier-core" "${DIR}/easytier/bin/easytier-cli"

PLUGIN_VERSION="$(sed -n 's/^PLUGIN_VERSION=//p' "${DIR}/easytier/version" | head -n 1)"
cat >"${DIR}/easytier/version" <<EOF
PLUGIN_VERSION=${PLUGIN_VERSION:-2.0.0}
CORE_VERSION=${TAG#v}
ARCH=${ARCH}
UPSTREAM_SHA256=${DIGEST#sha256:}
CORE_RELEASE_URL=https://github.com/EasyTier/EasyTier/releases/tag/${TAG}
EOF

echo "Updated EasyTier core to ${TAG} (${ARCH})"
