#!/bin/sh
set -e

# build script for easytier project

MODULE="easytier"
DIR="$(cd "$(dirname "$0")" && pwd)"

# 从 easytier/version 文件读取架构和版本号
if [ -f "${DIR}/${MODULE}/version" ]; then
	ARCH="$(sed -n '1p' "${DIR}/${MODULE}/version" 2>/dev/null || echo "unknown")"
	VERSION="$(sed -n '2p' "${DIR}/${MODULE}/version" 2>/dev/null || echo "1.0")"
else
	ARCH="unknown"
	VERSION="1.0"
fi
TITLE="EasyTier异地组网"
DESCRIPTION="去中心化异地组网软件，支持WireGuard加密传输"
HOME_URL="Module_easytier.asp"
TAGS="网络 组网 VPN"
AUTHOR="drafens"
LINK="https://github.com/EasyTier/EasyTier"
CHANGELOG=""

PLATFORM="$1"
if [ -z "${PLATFORM}" ]; then
	echo "用法: sh build.sh <平台>"
	echo "示例: sh build.sh hnd"
	echo "      sh build.sh mtk"
	echo "      sh build.sh qca"
	echo "      sh build.sh ipq32"
	echo "      sh build.sh ipq64"
	exit 1
fi

# 输出文件名包含架构和版本信息
OUTPUT_FILE="${MODULE}_${ARCH}_v${VERSION}.tar.gz"
OUTPUT_DIR="${DIR}/output"

do_build() {
	# 创建输出目录
	mkdir -p "${OUTPUT_DIR}"
	rm -rf "${DIR}/build" && mkdir -p "${DIR}/build"

	# prepare build tree
	cp -rf "${DIR}/${MODULE}" "${DIR}/build/"
	echo "${PLATFORM}" >"${DIR}/build/${MODULE}/.valid"
	echo "${VERSION}" >"${DIR}/build/${MODULE}/version"

	# shrink package: keep only binaries
	rm -f "${DIR}/build/${MODULE}/bin/"*
	cp -f "${DIR}/${MODULE}/bin/easytier-core" "${DIR}/build/${MODULE}/bin/easytier-core"
	cp -f "${DIR}/${MODULE}/bin/easytier-cli" "${DIR}/build/${MODULE}/bin/easytier-cli"
	chmod 755 "${DIR}/build/${MODULE}/bin/easytier-core"
	chmod 755 "${DIR}/build/${MODULE}/bin/easytier-cli"

	# pack
	( cd "${DIR}/build" && tar -zcf "${OUTPUT_FILE}" "${MODULE}" )
	mv -f "${DIR}/build/${OUTPUT_FILE}" "${OUTPUT_DIR}/"
	rm -rf "${DIR}/build"

	md5value=$(md5sum "${OUTPUT_DIR}/${OUTPUT_FILE}" | tr " " "\n" | sed -n 1p)

	cat >"${DIR}/version" <<-EOF
	${VERSION}
	${md5value}
	EOF

	DATE=$(date +%Y-%m-%d_%H:%M:%S)
	cat >"${DIR}/config.json.js" <<-EOF
	{
	"version":"${VERSION}",
	"md5":"${md5value}",
	"home_url":"${HOME_URL}",
	"title":"${TITLE}",
	"description":"${DESCRIPTION}",
	"tags":"${TAGS}",
	"author":"${AUTHOR}",
	"link":"${LINK}",
	"changelog":"${CHANGELOG}",
	"build_date":"${DATE}"
	}
	EOF

	echo "=========================================="
	echo "构建完成!"
	echo "输出文件: ${OUTPUT_DIR}/${OUTPUT_FILE}"
	echo "文件大小: $(ls -lh "${OUTPUT_DIR}/${OUTPUT_FILE}" | awk '{print $5}')"
	echo "MD5: ${md5value}"
	echo "=========================================="

	# update app.json.js
	python3 "${DIR}/../softcenter/gen_install.py" stage2 2>/dev/null || true
}

do_build
