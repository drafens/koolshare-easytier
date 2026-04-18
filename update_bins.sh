#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${DIR}/easytier/bin"

# 参数: ./update_bins.sh <架构> [版本]
# 架构: arm, aarch64, x86_64 等
# 版本: 可选，不填则自动获取最新
ARCH="$1"
VERSION="$2"

if [ -z "${ARCH}" ]; then
	echo "用法: $0 <架构> [版本]"
	echo "示例: $0 arm v2.6.0"
	echo "      $0 aarch64"
	exit 1
fi

# 确定版本号
if [ -n "${VERSION}" ]; then
	case "${VERSION}" in
		v*) TAG="${VERSION}" ;;
		*) TAG="v${VERSION}" ;;
	esac
	echo "使用指定版本: ${TAG}"
else
	TAG="$(curl -fsSL https://api.github.com/repos/EasyTier/EasyTier/releases/latest | sed -n 's/.*\"tag_name\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p' | head -n 1)"
	if [ -z "${TAG}" ]; then
		echo "无法获取最新版本" >&2
		exit 1
	fi
	echo "最新版本: ${TAG}"
fi

# 下载并解压
PKG="easytier-linux-${ARCH}-${TAG}.zip"
URL="https://github.com/EasyTier/EasyTier/releases/download/${TAG}/${PKG}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "下载: ${URL}"
curl -fsSL -o "${TMPDIR}/${PKG}" "${URL}"
unzip -q "${TMPDIR}/${PKG}" -d "${TMPDIR}"

# 复制文件（统一命名，不保留架构后缀）
mkdir -p "${BIN_DIR}"

if [ ! -d "${TMPDIR}/easytier-linux-${ARCH}" ]; then
	echo "错误: 解压后的目录不存在: ${TMPDIR}/easytier-linux-${ARCH}" >&2
	exit 1
fi

if [ ! -f "${TMPDIR}/easytier-linux-${ARCH}/easytier-core" ]; then
	echo "错误: 找不到 easytier-core" >&2
	exit 1
fi

cp -f "${TMPDIR}/easytier-linux-${ARCH}/easytier-core" "${BIN_DIR}/easytier-core"
cp -f "${TMPDIR}/easytier-linux-${ARCH}/easytier-cli" "${BIN_DIR}/easytier-cli"
chmod 755 "${BIN_DIR}/easytier-core" "${BIN_DIR}/easytier-cli"

# 更新插件版本号（与 EasyTier 核心版本保持一致）
# version 文件包含：架构名 + 版本号
cat > "${DIR}/easytier/version" <<EOF
${ARCH}
${TAG#v}
EOF

echo "完成!"
echo "已生成:"
ls -lh "${BIN_DIR}/easytier-core" "${BIN_DIR}/easytier-cli"
echo "插件版本: $(cat "${DIR}/easytier/version")"
