#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

sh -n "${ROOT}/build.sh" "${ROOT}/update_bins.sh" \
	"${ROOT}/easytier/install.sh" "${ROOT}/easytier/uninstall.sh" \
	"${ROOT}/easytier/scripts/"*.sh
node --check "${ROOT}/easytier/res/easytier.js"

for test_file in "${ROOT}/tests/shell/"test_*.sh; do
	sh "${test_file}"
done

python3 "${ROOT}/tools/release_asset.py" "${ROOT}/tests/fixtures/release.json" \
	"easytier-linux-aarch64-v2.6.4.zip" | grep -q '^https://example.invalid/easytier.zip$'

echo "All tests passed"
