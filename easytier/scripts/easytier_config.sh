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

tool_submit_log(){
	[ "${EASYTIER_SUBMIT}" = "1" ] && echo_date "$@"
}

# 轮询等待函数
# $1: 检查命令，返回0表示成功
# $2: 最大等待次数（默认50）
# $3: 每次间隔秒数（默认0.2）
tool_wait_for_condition() {
	local check_cmd="$1"
	local max_wait="${2:-50}"
	local interval="${3:-0.2}"
	local count=0
	
	while [ ${count} -lt ${max_wait} ]; do
		if eval "${check_cmd}" >/dev/null 2>&1; then
			return 0
		fi
		sleep ${interval}
		count=$((count + 1))
	done
	return 1
}

# 返回结果辅助函数
tool_print_success_marker() {
	echo "EASYTIER_RESULT=OK"
	tool_print_end_marker
}

tool_print_fail_marker() {
	echo "EASYTIER_RESULT=FAIL"
	tool_print_end_marker
}

tool_print_end_marker() {
	echo "XU6J03M16"
}

# Base64 解码函数
# $1: base64 编码的配置
# $2: 输出文件路径
# 返回: 0=成功, 1=失败
config_decode_toml() {
	local config_b64="$1"
	local output_file="$2"
	
	if [ -z "${config_b64}" ]; then
		tool_submit_log "TOML 配置为空"
		return 1
	fi
	
	if ! echo "${config_b64}" | base64 -d > "${output_file}" 2>/dev/null; then
		tool_submit_log "Base64 解码失败，配置格式不正确"
		return 1
	fi
	
	if [ ! -s "${output_file}" ]; then
		tool_submit_log "配置内容为空"
		return 1
	fi
	
	return 0
}

config_save_toml(){
	# 从 dbus 获取 base64 编码的配置并解码保存
	local config_b64="${toml_base64}"
	local temp_file="/tmp/easytier_save_temp.toml"
	
	if ! config_decode_toml "${config_b64}" "${temp_file}"; then
		rm -f "${temp_file}"
		return 1
	fi
	
	# 移动到最终位置
	tool_submit_log "保存 TOML 配置到 ${TOML_FILE}"
	mv "${temp_file}" "${TOML_FILE}"
	tool_submit_log "配置保存成功"
	return 0
}

# 检查配置（仅验证，不保存）
config_check_toml(){
	local config_b64="${toml_base64}"
	local temp_file="/tmp/easytier_check.toml"

	if ! config_decode_toml "${config_b64}" "${temp_file}"; then
		rm -f "${temp_file}"
		return 1
	fi
	
	tool_submit_log "配置语法检查通过"
	rm -f "${temp_file}"
	return 0
}

# 启动服务
# $1: 日志函数名（echo_date 或 tool_submit_log）
service_start() {
	local log_func="$1"
	
	# 保存配置文件
	if ! config_save_toml; then
		$log_func "配置文件保存失败，请检查配置！"
		return 1
	fi
	
	$log_func "检查配置文件..."
	if [ ! -s "${TOML_FILE}" ]; then
		$log_func "配置文件不存在或为空"
		return 1
	fi
	$log_func "配置文件验证通过"
	
	# 停止旧进程
	killall easytier-core >/dev/null 2>&1 || true
	sleep 1
	
	# 清空启动日志
	> "${STARTUP_LOG_FILE}"
	
	# 启动 easytier-core
	nohup ${CORE_BIN} -c "${TOML_FILE}" >> "${STARTUP_LOG_FILE}" 2>&1 &
	echo $! > "${PID_FILE}"
	
	$log_func "EasyTier 进程已启动"
	return 0
}

# 停止服务  
# $1: 日志函数名（echo_date 或 tool_submit_log）
service_stop() {
	local log_func="$1"
	
	killall easytier-core >/dev/null 2>&1 || true
	
	# 轮询检测进程是否停止，最多等待5秒
	if tool_wait_for_condition "! pidof easytier-core" 25 0.2; then
		$log_func "EasyTier 进程已停止"
		rm -f "${PID_FILE}"
		return 0
	else
		$log_func "EasyTier 进程停止超时"
		return 1
	fi
}

# NTP 同步
sys_ntp_sync(){
	(
		ntp_server="$(nvram get ntp_server0)"
		start_time="$(date +%Y%m%d)"
		ntpclient -h "${ntp_server}" -i3 -l -s >/dev/null 2>&1
		if [ "${start_time}" = "$(date +%Y%m%d)" ]; then
			ntpclient -h ntp1.aliyun.com -i3 -l -s >/dev/null 2>&1
		fi
	) &
}

sys_start_stop(){
	# 获取版本信息
	if [ -x "${CLI_BIN}" ]; then
		local version="$(${CLI_BIN} --version 2>/dev/null || echo "unknown")"
		dbus set easytier_core_version="${version}"
	fi
	
	if [ "${easytier_enable}" = "1" ]; then
		service_start tool_submit_log
	else
		service_stop tool_submit_log
	fi
}

sys_nat_start(){
	if [ "${easytier_enable}" = "1" ]; then
		[ ! -L "/koolshare/init.d/N99easytier.sh" ] && ln -sf /koolshare/scripts/easytier_config.sh /koolshare/init.d/N99easytier.sh
	else
		rm -rf /koolshare/init.d/N99easytier.sh >/dev/null 2>&1
	fi
}

# =============================================
# this part for start up by post-mount
case $ACTION in
start)
	sys_ntp_sync
	sys_start_stop
	sys_nat_start
	;;
start_nat)
	sys_ntp_sync
	sys_start_stop
	;;
esac

# for web submit
case $2 in
start)
	# 启动服务
	(
		EASYTIER_SUBMIT=1
		export EASYTIER_SUBMIT
		echo_date "========== 启动 EasyTier =========="
		sys_ntp_sync
		
		# 启动服务
		if service_start echo_date; then
			sys_nat_start
			
			# 轮询检测进程是否启动，最多等待5秒
			if tool_wait_for_condition "pidof easytier-core" 25 0.2; then
				pid="$(pidof easytier-core 2>/dev/null)"
				echo_date "EasyTier 启动成功，PID: ${pid}"
				echo_date "======================================"
				tool_print_success_marker
			else
				echo_date "--------------------------------------"
				echo_date "EasyTier 启动失败"
				echo_date "--------------------------------------"
				if [ -s "${STARTUP_LOG_FILE}" ]; then
					echo_date "[错误日志]"
					cat "${STARTUP_LOG_FILE}"
					echo_date "[/错误日志]"
				else
					echo_date "未捕获到错误日志，请检查配置"
				fi
				echo_date "======================================"
				tool_print_fail_marker
			fi
		else
			tool_print_fail_marker
		fi
	) >"${SUBMIT_LOG_FILE}" 2>&1 &
	http_response "$1"
	;;
stop)
	# 停止服务
	(
		EASYTIER_SUBMIT=1
		export EASYTIER_SUBMIT
		echo_date "========== 停止 EasyTier =========="
		
		# 使用核心停止函数
		if service_stop echo_date; then
			echo_date "======================================"
			tool_print_success_marker
		else
			echo_date "======================================"
			tool_print_fail_marker
		fi
	) >"${SUBMIT_LOG_FILE}" 2>&1 &
	http_response "$1"
	;;
peer)
	# 查询 peer 信息
	(
		# 先删除旧文件，确保生成的是最新数据
		rm -f /tmp/upload/easytier_peer_info.txt
		
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
		tool_print_end_marker
	) &
	http_response "$1"
	;;
check)
	# 检查配置（仅验证，不保存）
	(
		EASYTIER_SUBMIT=1
		export EASYTIER_SUBMIT
		echo_date "========== 检查配置 =========="
		if ! config_check_toml; then
			echo_date "配置检查失败"
			echo_date "======================================"
			tool_print_fail_marker
			http_response "$1"
			exit 0
		fi
		
		echo_date "配置语法正确"
		echo_date "请点击「保存」按钮保存配置"
		echo_date "======================================"
		tool_print_success_marker
	) >"${SUBMIT_LOG_FILE}" 2>&1 &
	http_response "$1"
	;;
save)
	# 保存配置（不启动）
	(
		EASYTIER_SUBMIT=1
		export EASYTIER_SUBMIT
		echo_date "========== 保存配置 =========="
		if ! config_save_toml; then
			echo_date "配置保存失败"
			echo_date "======================================"
			tool_print_fail_marker
			http_response "$1"
			exit 0
		fi
		echo_date "配置已保存到 ${TOML_FILE}"
		echo_date "请点击「启动」按钮运行服务"
		echo_date "======================================"
		tool_print_success_marker
	) >"${SUBMIT_LOG_FILE}" 2>&1 &
	http_response "$1"
	;;
esac
