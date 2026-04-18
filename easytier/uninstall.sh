#!/bin/sh
export KSROOT=/koolshare
. $KSROOT/scripts/base.sh

killall easytier-core >/dev/null 2>&1
find /koolshare/init.d/ -name "*easytier*" -exec rm -rf {} \; >/dev/null 2>&1
rm -rf /koolshare/res/icon-easytier.png
rm -rf /koolshare/bin/easytier-core
rm -rf /koolshare/bin/easytier-cli
rm -rf /koolshare/scripts/easytier*.sh
rm -rf /koolshare/webs/Module_easytier.asp
rm -rf /koolshare/scripts/uninstall_easytier.sh
rm -rf /koolshare/configs/easytier.toml
