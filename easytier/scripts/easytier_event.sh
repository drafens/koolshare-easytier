#!/bin/sh

export KSROOT="${KSROOT:-/koolshare}"
. "${KSROOT}/scripts/base.sh"

case "${1:-${ACTION:-}}" in
	start)
		if [ "$(dbus get easytier_autostart 2>/dev/null)" = "1" ]; then
			"${KSROOT}/scripts/easytier_service.sh" start
		fi
		;;
	stop)
		"${KSROOT}/scripts/easytier_service.sh" stop
		;;
esac
