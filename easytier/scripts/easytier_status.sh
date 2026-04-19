#!/bin/sh

export KSROOT=/koolshare
. $KSROOT/scripts/base.sh

easytier_version=`/koolshare/bin/easytier-cli --version 2>/dev/null || echo "unknown"`
easytier_pid=`pidof easytier-core`

if [ -n "$easytier_pid" ];then
	http_response "EasyTier ${easytier_version} 进程运行正常！PID：$easytier_pid"
else
	http_response "EasyTier ${easytier_version} 进程未运行！"
fi
