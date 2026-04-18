#!/bin/sh

eval `dbus export easytier_`
. /koolshare/scripts/base.sh
mkdir -p /tmp/upload
mkdir -p /koolshare/configs

NAME=easytier
CORE_BIN=/koolshare/bin/easytier-core
CLI_BIN=/koolshare/bin/easytier-cli
TOML_FILE=/koolshare/configs/easytier.toml
PID_FILE=/var/run/easytier.pid
SUBMIT_LOG_FILE=/tmp/upload/easytier_submit_log.txt
STARTUP_LOG_FILE=/tmp/upload/easytier_startup.log

submit_log(){
	[ "${EASYTIER_SUBMIT}" = "1" ] && echo_date "$@"
}

fun_ntp_sync(){
	# 异步执行 NTP 同步，避免阻塞启动流程
	(
		ntp_server="$(nvram get ntp_server0)"
		start_time="$(date +%Y%m%d)"
		ntpclient -h "${ntp_server}" -i3 -l -s >/dev/null 2>&1
		if [ "${start_time}" = "$(date +%Y%m%d)" ]; then
			ntpclient -h ntp1.aliyun.com -i3 -l -s >/dev/null 2>&1
		fi
	) &
}

save_toml_config(){
	# 从 dbus 获取 base64 编码的配置并解码保存
	local config_b64="${easytier_toml_config_b64}"
	
	if [ -z "${config_b64}" ]; then
		submit_log "错误：TOML 配置为空！"
		return 1
	fi
	
	submit_log "保存 TOML 配置文件到 ${TOML_FILE}"
	if ! echo "${config_b64}" | base64 -d > "${TOML_FILE}" 2>/dev/null; then
		submit_log "错误：Base64 解码失败，配置格式不正确！"
		return 1
	fi
	
	if [ ! -s "${TOML_FILE}" ]; then
		submit_log "错误：配置文件保存失败！"
		return 1
	fi
	
	submit_log "TOML 配置文件保存成功！"
	return 0
}

# 检查配置（仅验证，不保存）
check_toml_config(){
	local config_b64="${easytier_toml_config_b64}"
	
	if [ -z "${config_b64}" ]; then
		submit_log "错误：TOML 配置为空！"
		return 1
	fi
	
	# 解码并验证语法
	local temp_file="/tmp/easytier_check.toml"
	if ! echo "${config_b64}" | base64 -d > "${temp_file}" 2>/dev/null; then
		submit_log "错误：Base64 解码失败，配置格式不正确！"
		rm -f "${temp_file}"
		return 1
	fi
	
	if [ ! -s "${temp_file}" ]; then
		submit_log "错误：配置内容为空！"
		rm -f "${temp_file}"
		return 1
	fi
	
	submit_log "TOML 配置语法检查通过！"
	rm -f "${temp_file}"
	return 0
}

fun_start_stop(){
	# 获取版本信息
	if [ -x "${CLI_BIN}" ]; then
		local version="$(${CLI_BIN} --version 2>/dev/null || echo "unknown")"
		dbus set easytier_core_version="${version}"
	fi
	
	if [ "${easytier_enable}" = "1" ]; then
		submit_log "启动 EasyTier 服务..."
		
		# 保存配置文件
		if ! save_toml_config; then
			submit_log "配置文件保存失败，请检查配置！"
			return 1
		fi
		
		submit_log "检查配置文件..."
		if [ ! -s "${TOML_FILE}" ]; then
			submit_log "配置文件检查失败！"
			return 1
		fi
		submit_log "配置文件检查通过，准备启动..."
		
		# 停止旧进程
		killall easytier-core >/dev/null 2>&1 || true
		sleep 1
		
		# 清空启动日志
		> "${STARTUP_LOG_FILE}"
		
		# 启动 easytier-core
		nohup ${CORE_BIN} -c "${TOML_FILE}" >> "${STARTUP_LOG_FILE}" 2>&1 &
		echo $! > "${PID_FILE}"
		
		submit_log "EasyTier 服务已启动"
	else
		submit_log "停止 EasyTier 服务..."
		killall easytier-core >/dev/null 2>&1 || true
		rm -f "${PID_FILE}"
		submit_log "EasyTier 服务已停止"
	fi
}

fun_nat_start(){
	if [ "${easytier_enable}"x = "1"x ];then
		[ ! -L "/koolshare/init.d/N99easytier.sh" ] && ln -sf /koolshare/scripts/easytier_config.sh /koolshare/init.d/N99easytier.sh
	else
		rm -rf /koolshare/init.d/N99easytier.sh >/dev/null 2>&1
	fi
}

# =============================================
# this part for start up by post-mount
case $ACTION in
start)
	fun_ntp_sync
	fun_start_stop
	fun_nat_start
	;;
start_nat)
	fun_ntp_sync
	fun_start_stop
	;;
esac

# for web submit
case $2 in
1)
	# 启动/停止服务
	(
		EASYTIER_SUBMIT=1
		export EASYTIER_SUBMIT
		echo_date "开始提交配置..."
		fun_ntp_sync
		if [ "${easytier_enable}" = "1" ]; then
			echo_date "启动 EasyTier 服务..."
		else
			echo_date "停止 EasyTier 服务..."
		fi
		fun_start_stop
		fun_nat_start
		if [ "${easytier_enable}" = "1" ]; then
			sleep 3
			pid="$(pidof easytier-core 2>/dev/null)"
			if [ -n "${pid}" ]; then
				echo_date "EasyTier 程序启动成功，PID: ${pid}"
				echo "EASYTIER_RESULT=OK"
			else
				echo_date "=========================================="
				echo_date "EasyTier 程序启动失败！"
				echo_date "=========================================="
				if [ -s "${STARTUP_LOG_FILE}" ]; then
					echo_date "=== 启动错误日志 ==="
					cat "${STARTUP_LOG_FILE}"
					echo_date "===================="
				else
					echo_date "未捕获到错误日志，请检查配置文件"
				fi
				# 启动失败时将开关关闭，使页面刷新后按钮状态同步
				dbus set easytier_enable="0"
				echo "EASYTIER_RESULT=FAIL"
			fi
		else
			sleep 1
			if pidof easytier-core >/dev/null 2>&1; then
				echo_date "EasyTier 程序停止失败，请稍后重试！"
				echo "EASYTIER_RESULT=FAIL"
			else
				echo_date "EasyTier 程序已停止"
				echo "EASYTIER_RESULT=OK"
			fi
		fi
		echo "XU6J03M16"
	) >"${SUBMIT_LOG_FILE}" 2>&1 &
	http_response "$1"
	;;
2)
	# 查询 peer 信息
	(
		if pidof easytier-core >/dev/null 2>&1; then
			peer_info="$(${CLI_BIN} peer 2>/dev/null)"
			if [ $? -eq 0 ] && [ -n "${peer_info}" ]; then
				echo "${peer_info}" > /tmp/upload/easytier_peer_info.txt
			else
				echo "无法获取 Peer 信息" > /tmp/upload/easytier_peer_info.txt
			fi
		else
			echo "EasyTier 未运行" > /tmp/upload/easytier_peer_info.txt
		fi
		echo "XU6J03M16"
	) &
	http_response "$1"
	;;
3)
	# 检查配置（仅验证，不保存）
	(
		EASYTIER_SUBMIT=1
		export EASYTIER_SUBMIT
		echo_date "开始检查配置..."
		if ! check_toml_config; then
			echo_date "配置检查失败！"
			echo "EASYTIER_RESULT=FAIL"
			echo "XU6J03M16"
			http_response "$1"
			exit 0
		fi
		
		echo_date "配置语法正确，请点击「保存」保存配置"
		echo "EASYTIER_RESULT=OK"
		echo "XU6J03M16"
	) >"${SUBMIT_LOG_FILE}" 2>&1 &
	http_response "$1"
	;;
4)
	# 保存配置（不启动）
	(
		EASYTIER_SUBMIT=1
		export EASYTIER_SUBMIT
		echo_date "开始保存配置..."
		if ! save_toml_config; then
			echo_date "配置保存失败！"
			echo "EASYTIER_RESULT=FAIL"
			echo "XU6J03M16"
			http_response "$1"
			exit 0
		fi
		echo_date "配置已保存到 ${TOML_FILE}"
		echo_date "请点击「启动」按钮开始运行"
		echo "EASYTIER_RESULT=OK"
		echo "XU6J03M16"
	) >"${SUBMIT_LOG_FILE}" 2>&1 &
	http_response "$1"
	;;
esac
