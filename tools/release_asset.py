#!/usr/bin/env python3
"""Select one verified asset from a GitHub Release API response."""

import json
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: release_asset.py <release.json> <asset-name>", file=sys.stderr)
        return 2

    with open(sys.argv[1], encoding="utf-8") as release_file:
        release = json.load(release_file)

    asset_name = sys.argv[2]
    for asset in release.get("assets", []):
        if asset.get("name") != asset_name:
            continue
        url = asset.get("browser_download_url", "")
        digest = asset.get("digest", "")
        if not url or not digest.startswith("sha256:"):
            print(f"asset {asset_name} has no SHA-256 digest", file=sys.stderr)
            return 1
        print(url)
        print(digest)
        return 0

    print(f"asset not found: {asset_name}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
