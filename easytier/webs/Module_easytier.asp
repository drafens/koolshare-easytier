<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<!-- plugin version: 1.0 -->
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache"/>
<link rel="shortcut icon" href="images/favicon.png"/>
<link rel="icon" href="images/favicon.png"/>
<title>软件中心 - EasyTier异地组网</title>
<link rel="stylesheet" type="text/css" href="index_style.css" />
<link rel="stylesheet" type="text/css" href="form_style.css" />
<link rel="stylesheet" type="text/css" href="usp_style.css" />
<link rel="stylesheet" type="text/css" href="ParentalControl.css">
<link rel="stylesheet" type="text/css" href="css/icon.css">
<link rel="stylesheet" type="text/css" href="css/element.css">
<link rel="stylesheet" type="text/css" href="/res/layer/theme/default/layer.css">
<link rel="stylesheet" type="text/css" href="res/softcenter.css">
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/validator.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/res/softcenter.js"></script>
<style type="text/css">
/* TOML 配置编辑器 */
#easytier_toml_config {
	width: 99%;
	font-family: 'Lucida Console', monospace;
	font-size: 11px;
	background: #475A5F;
	color: #FFFFFF;
	text-transform: none;
	margin-top: 5px;
	resize: vertical;
	white-space: pre;
	word-break: normal;
	overflow: auto;
	border: 1px solid #3c3c3c;
	padding: 5px;
	outline: none;
}

/* Peer 信息显示 */
#easytier_peer_info {
	width: 100%;
	font-family: 'Lucida Console', monospace;
	font-size: 10px;
	background: #475A5F;
	color: #FFFFFF;
	white-space: nowrap;
	overflow-x: auto;
	overflow-y: auto;
	border: 1px solid #91071f;
	padding: 5px;
	line-height: 1.4;
	outline: none;
}

/* 按钮焦点样式 */
input[type=button]:focus {
	outline: none;
}
</style>
<script>
var db_easytier = {};                // dbus 数据
var loadingBarAutoCloseSeconds = 0;  // LoadingBar关闭倒计时，-1手动关闭
var easytier_log_poll_tries = 0;     // 日志轮询计数
var defaultTomlConfig = 
	'# EasyTier TOML Configuration\n' +
	'# 保存位置: /koolshare/configs/easytier.toml\n' +
	'\n' +
	'instance_name = \'my-network\'\n' +
	'ipv4 = \'10.144.144.1\'\n' +
	'dhcp = false\n' +
	'\n' +
	'[network_identity]\n' +
	"network_name = 'my-network'\n" +
	"network_secret = 'your-secret-password'\n" +
	'\n' +
	'[rpc]\n' +
	"rpc_portal = '127.0.0.1:15888'\n" +
	'\n' +
	'[flags]\n' +
	'no_tun = true\n' +
	'\n' +
	'# 添加peer节点\n' +
	'[[peer]]\n' +
	"uri = 'tcp://1.2.3.4:11010'";          // 默认TOML配置模板

// 常量定义
const LOG_END_MARKER = "XU6J03M16";
const RESULT_OK = "EASYTIER_RESULT=OK";
const LOG_POLL_INTERVAL = 200;                  // 日志轮询间隔
const LOG_POLL_MAX_RETRIES = 25;                // 日志轮询最大次数
const STATUS_POLL_INTERVAL = 10000;             // 运行状态轮询间隔

// ==================== 页面初始化 ====================

function initPage() {
	show_menu(setupMenu);
	setTimeout(function() {
		loadDbusData();
		startStatusPolling();
	}, 100);
}

// 设置菜单标题
function setupMenu() {
	tabtitle[tabtitle.length - 1] = new Array("", "EasyTier 异地组网");
	tablink[tablink.length - 1] = new Array("", "Module_easytier.asp");
}

// 设置菜单标题
function loadDbusData() {
	$.ajax({
		type: "GET",
		url: "/_api/easytier",
		dataType: "json",
		async: false,
		success: function(data) {
			db_easytier = data.result[0];
			applyConfigToUI();
			$("#easytier_version_show").html("插件版本：" + db_easytier["easytier_version"]);
		}
	});
}

// 将 dbus 配置应用到 UI 表单
function applyConfigToUI() {
	if(db_easytier["easytier_enable"]){
		E("easytier_enable").checked = db_easytier["easytier_enable"] == 1 ? true : false;
		document.form.easytier_enable.value = db_easytier["easytier_enable"];
	}
	
	// TOML 配置（base64 编码存储）
	if(db_easytier["toml_base64"]){
		try {
			var tomlConfig = atob(db_easytier["toml_base64"]);
			E("easytier_toml_config").value = tomlConfig;
		} catch(e) {
			console.warn('TOML 配置解码失败，使用空配置');
			E("easytier_toml_config").value = '';
		}
	} else {
		// 如果没有配置，使用默认模板
		E("easytier_toml_config").value = defaultTomlConfig;
	}
}

// 轮询获取运行状态
function startStatusPolling() {
	var postData = {
		"id": generateRequestId(),
		"method": "easytier_status.sh",
		"params": [],
		"fields": ""
	};
	$.ajax({
		type: "POST",
		cache: false,
		url: "/_api/",
		data: JSON.stringify(postData),
		dataType: "json",
		success: function(response) {
			E("status").innerHTML = response.result;
			setTimeout(startStatusPolling, STATUS_POLL_INTERVAL);
		},
		error: function() {
			setTimeout(startStatusPolling, STATUS_POLL_INTERVAL / 2);
		}
	});
}

// ==================== 日志轮询 ====================

// 格式化日志文本
function formatLogText(s){
	if (!s) return "";
	return s
		.replace(/\r/g, "")
		.replace(new RegExp("^.*" + RESULT_OK + ".*$", "gm"), "")
		.replace(new RegExp("^.*" + LOG_END_MARKER + ".*$", "gm"), "")
		.replace(/\n{3,}/g, "\n\n")
		.trim() + "\n";
}

// 显示轮询进度提示
function showPollProgress(current, max, message) {
	E("easytier_loading_block_title").innerHTML = `${message} (${current}/${max})`;
}

// 处理轮询错误
function handlePollError(message) {
	E("easytier_loading_block_title").innerHTML = message;
	E("easytier_ok_button").style.visibility = "visible";
	loadingBarAutoCloseSeconds = -1;
}

// 轮询获取提交日志
function pollSubmitLog(){
	$.ajax({
		url: '/_temp/easytier_submit_log.txt',
		type: 'GET',
		cache: false,
		dataType: 'text',
		success: function(response) {
			var retArea = E("easytier_log_content");
			var done = (response.indexOf(LOG_END_MARKER) != -1);
			var ok = (response.indexOf(RESULT_OK) != -1);
			retArea.value = formatLogText(response);
			retArea.scrollTop = retArea.scrollHeight;
			
			if (done) {
				E("easytier_ok_button").style.visibility = "visible";
				loadingBarAutoCloseSeconds = 5;
				updateLoadingBarCountdown();
				return;
			}
			setTimeout(pollSubmitLog, LOG_POLL_INTERVAL);
		},
		error: function(xhr) {
			easytier_log_poll_tries++;
			showPollProgress(easytier_log_poll_tries, LOG_POLL_MAX_RETRIES, "正在获取提交日志");
			if (easytier_log_poll_tries <= LOG_POLL_MAX_RETRIES) {
				setTimeout(pollSubmitLog, LOG_POLL_INTERVAL);
				return;
			}
			handlePollError("暂无日志信息 ...");
			E("easytier_log_content").value = "日志文件为空，请关闭本窗口！";
			E("easytier_ok_button").style.visibility = "visible";
			loadingBarAutoCloseSeconds = -1;
		}
	});
}

// ==================== UI 操作函数 ====================

// 设置元素样式
function setElementStyle(element, display, visibility) {
	if (element && element.style && element.style.setProperty) {
		element.style.setProperty("display", display, "important");
		element.style.setProperty("visibility", visibility, "important");
	} else if (element && element.style) {
		element.style.display = display;
		element.style.visibility = visibility;
	}
}

// 滚动到页面顶部
function scrollToTop() {
	try {
		if (document.scrollingElement) {
			document.scrollingElement.scrollTop = 0;
		}
	} catch(e) {}
	
	try {
		document.documentElement.scrollTop = 0;
		document.body.scrollTop = 0;
	} catch(e) {}
}

// 显示 LoadingBar 弹窗
function showLoadingBar(title) {
	scrollToTop();
	
	var lb = E("easytier_LoadingBar");
	setElementStyle(lb, "block", "visible");
	
	// 设置标题
	if (title) {
		E("easytier_loading_block_title").innerHTML = title;
	}
	
	// 计算居中位置
	var page_h = window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;
	var page_w = window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth;
	var log_h = E("easytier_loadingBarBlock").clientHeight;
	var log_w = E("easytier_loadingBarBlock").clientWidth;
	var log_h_offset = (page_h - log_h) / 2;
	var log_w_offset = (page_w - log_w) / 2 + 90;  // +90 补偿左侧菜单宽度
	$('#easytier_loadingBarBlock').offset({top: log_h_offset, left: log_w_offset});
}

// 隐藏 LoadingBar 弹窗
function hideLoadingBar(){
	var lb = E("easytier_LoadingBar");
	setElementStyle(lb, "none", "hidden");
	
	E("easytier_ok_button").style.visibility = "hidden";
	refreshpage();
}

// LoadingBar 倒计时关闭
function updateLoadingBarCountdown() {
	if (loadingBarAutoCloseSeconds == 0) {
		hideLoadingBar();
	}
	if (loadingBarAutoCloseSeconds < 0) {
		E("easytier_ok_button1").value = "手动关闭";
		return;
	}
	E("easytier_ok_button1").value = loadingBarAutoCloseSeconds + " 秒后关闭";
	--loadingBarAutoCloseSeconds;
	setTimeout(updateLoadingBarCountdown, 1000);
}

// ==================== 配置管理函数 ====================

// Base64 编码
function toBase64(str) {
	return btoa(unescape(encodeURIComponent(str)));
}

// 生成随机请求 ID
function generateRequestId() {
	const REQUEST_ID_MAX = 100000000;
	return parseInt(Math.random() * REQUEST_ID_MAX);
}

// 获取并验证 TOML 配置
function getTomlConfig() {
	var tomlContent = E("easytier_toml_config").value.trim();
	if (tomlContent == "") {
		alert("TOML 配置不能为空！");
		return null;
	}
	return tomlContent;
}

// ==================== 后端通信函数 ====================

// 调用后端 API
function callBackend(postData) {
	E("easytier_ok_button").style.visibility = "hidden";
	E("easytier_log_content").value = "";
	easytier_log_poll_tries = 0;
	
	$.ajax({
		url: "/_api/",
		cache: false,
		type: "POST",
		dataType: "json",
		data: JSON.stringify(postData),
		success: function(response) {
			if (response.result == postData.id){
				pollSubmitLog();
			}
		},
		error: function() {
			E("easytier_loading_block_title").innerHTML = "提交失败 ...";
			E("easytier_log_content").value = "提交请求失败，请重试！";
			E("easytier_ok_button").style.visibility = "visible";
			loadingBarAutoCloseSeconds = -1;
		}
	});
}

// ==================== 业务操作函数 ====================

// 检查配置
function checkConfig() {
	var tomlContent = getTomlConfig();
	if (!tomlContent) return;

	var postData = {
		"id": generateRequestId(),
		"method": "easytier_config.sh",
		"params": ["check"],
		"fields": {toml_base64: toBase64(tomlContent)}
	};
	
	showLoadingBar("&nbsp;&nbsp;EasyTier 配置检查");
	E("easytier_log_content").value = "正在检查配置格式...";
	callBackend(postData);
}

// 保存配置
function saveConfig() {
	var tomlContent = getTomlConfig();
	if (!tomlContent) return;
	
	var postData = {
		"id": generateRequestId(), 
		"method": "easytier_config.sh", 
		"params": ["save"], 
		"fields": {toml_base64: toBase64(tomlContent)} 
	};
	
	showLoadingBar("&nbsp;&nbsp;EasyTier 保存配置");
	E("easytier_log_content").value = "正在保存配置...";
	callBackend(postData);
}

// 启动服务
function startService() {
	var tomlContent = getTomlConfig();
	if (!tomlContent) return;
	
	var postData = {
		"id": generateRequestId(), 
		"method": "easytier_config.sh", 
		"params": ["start"], 
		"fields": {toml_base64: toBase64(tomlContent)}
	};
	
	showLoadingBar("&nbsp;&nbsp;EasyTier 启动服务");
	E("easytier_log_content").value = "正在启动服务...";
	callBackend(postData);
}

// 停止服务
function stopService() {
	var postData = {
		"id": generateRequestId(), 
		"method": "easytier_config.sh", 
		"params": ["stop"], 
		"fields": {}
	};
	
	showLoadingBar("&nbsp;&nbsp;EasyTier 停止服务");
	E("easytier_log_content").value = "正在停止服务...";
	callBackend(postData);
}

// 提交服务（根据开关状态决定启动或停止）
function submitService() {
	if (E("easytier_enable").checked) {
		startService();
	} else {
		stopService();
	}
}

// 显示 Peer 信息
function showPeerInfo(){
	var postData = {
		"id": generateRequestId(),
		"method": "easytier_config.sh",
		"params": ["peer"],
		"fields": {}
	};
	
	showLoadingBar("&nbsp;&nbsp;EasyTier Peer 信息");
	E("easytier_log_content").value = "正在获取最新 Peer 信息...";
	easytier_log_poll_tries = 0;
	
	$.ajax({
		type: "POST",
		cache: false,
		url: "/_api/",
		data: JSON.stringify(postData),
		dataType: "json",
		success: function(response) {
			pollPeerInfo();
		},
		error: function() {
			E("easytier_log_content").value = "获取 Peer 信息失败，请确认 EasyTier 正在运行。";
			E("easytier_ok_button").style.visibility = "visible";
			E("easytier_ok_button1").value = "关闭";
		}
	});
}

// 轮询获取 Peer 信息
function pollPeerInfo() {
	easytier_log_poll_tries++;
	showPollProgress(easytier_log_poll_tries, LOG_POLL_MAX_RETRIES, "正在获取 Peer 信息");
	
	$.ajax({
		url: '/_temp/easytier_peer_info.txt',
		type: 'GET',
		cache: false,
		dataType: 'text',
		data: { '_': Date.now() },
		success: function(response) {
			var retArea = E("easytier_log_content");
			
			// 检查是否有有效内容
			if (response && response.trim().length > 0 && response.indexOf("暂无") == -1) {
				retArea.value = response;
				retArea.cols = 100;
				retArea.scrollTop = 0;
				retArea.scrollLeft = 0;
				E("easytier_ok_button").style.visibility = "visible";
				E("easytier_ok_button1").value = "关闭";
			} else {
				// 继续轮询
				if (easytier_log_poll_tries < LOG_POLL_MAX_RETRIES) {
					setTimeout(pollPeerInfo, LOG_POLL_INTERVAL);
				} else {
					retArea.value = "获取 Peer 信息超时，请稍后重试。";
					E("easytier_ok_button").style.visibility = "visible";
					E("easytier_ok_button1").value = "关闭";
				}
			}
		},
		error: function() {
			if (easytier_log_poll_tries < LOG_POLL_MAX_RETRIES) {
				setTimeout(pollPeerInfo, LOG_POLL_INTERVAL);
			} else {
				var retArea = E("easytier_log_content");
				retArea.value = "获取 Peer 信息失败，请确认 EasyTier 正在运行。";
				E("easytier_ok_button").style.visibility = "visible";
				E("easytier_ok_button1").value = "关闭";
			}
		}
	});
}

// 显示帮助提示
function showHelpHint(itemNum) {
	var caption = "";
	var content = "";
	
	const HINT_ID_ENABLE = 0;   // 开关提示
	const HINT_ID_TOML = 1;     // TOML 配置提示
	switch(itemNum) {
		case HINT_ID_ENABLE:
			caption = "开启 EasyTier";
			content = 
				"开启/关闭 EasyTier 服务。<br>" +
				"若无法启用，请先在 " +
				"<a href='Advanced_System_Content.asp'>" +
				"<u><font color='#00F'>系统管理 - 系统设置</font></u></a> " +
				"开启 Enable JFFS custom scripts and configs。";
			break;
			
		case HINT_ID_TOML:
			caption = "TOML 配置";
			content = 
				"直接输入 EasyTier 的完整 TOML 配置文件。<br>" +
				"支持所有 EasyTier 配置选项。<br><br>" +
				"配置示例：<br>" +
				"instance_name = 'my-network'<br>" +
				"ipv4 = '10.144.144.1'<br><br>" +
				"[[peer]]<br>" +
				"uri = 'tcp://1.2.3.4:11010'<br><br>" +
				"配置会保存到 /koolshare/configs/easytier.toml<br>" +
				"并使用 base64 编码存储到 dbus 以便回显。";
			break;
			
		default:
			caption = "未知选项";
			content = "无效的帮助请求。";
	}
	
	return overlib(content, OFFSETX, -160, LEFT, WIDTH, 360, CAPTION, caption);
}
</script>
</head>
<body onload="initPage();">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<div id="easytier_LoadingBar" class="popup_bar_bg_ks" style="position:fixed;margin:auto;top:0;left:0;width:100%;height:100%;z-index:9999;display:none;visibility:hidden;overflow:hidden;background:rgba(68,79,83,0.94) none repeat scroll 0 0;opacity:.94;" >
	<table cellpadding="5" cellspacing="0" id="easytier_loadingBarBlock" class="loadingBarBlock" style="width:740px;" align="center">
		<tr>
			<td height="100">
				<div id="easytier_loading_block_title" style="margin:10px auto;width:100%; font-size:12pt;text-align:center;"></div>
				<div style="margin-left:15px;margin-top:5px"><i>此处显示 EasyTier 提交日志或 Peer 信息</i></div>
				<div style="margin-left:15px;margin-right:15px;margin-top:10px;outline: 1px solid #3c3c3c;">
					<textarea cols="80" rows="25" wrap="off" readonly="readonly" id="easytier_log_content" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false" style="border:1px solid #000;width:100%; font-family:'Lucida Console'; font-size:11px;background:transparent;color:#FFFFFF;outline: none;padding-left:5px;padding-right:5px;overflow:auto;white-space:pre;overflow-wrap:normal;word-break:normal;resize:none;"></textarea>
				</div>
				<div id="easytier_ok_button" class="apply_gen" style="background:#000;visibility:hidden;">
					<input style="margin-left:10px" id="easytier_ok_button1" class="button_gen" type="button" onclick="hideLoadingBar()" value="确定">
				</div>
			</td>
		</tr>
	</table>
</div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
<form method="POST" name="form" action="/applydb.cgi?p=easytier" target="hidden_frame">
<input type="hidden" name="current_page" value="Module_easytier.asp"/>
<input type="hidden" name="next_page" value="Module_easytier.asp"/>
<input type="hidden" name="group_id" value=""/>
<input type="hidden" name="modified" value="0"/>
<input type="hidden" name="action_mode" value=""/>
<input type="hidden" name="action_script" value=""/>
<input type="hidden" name="action_wait" value="5"/>
<input type="hidden" name="first_time" value=""/>
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>"/>
<input type="hidden" name="SystemCmd" onkeydown="onSubmitCtrl(this, ' Refresh ')" value="config-easytier.sh"/>
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>"/>
<table class="content" align="center" cellpadding="0" cellspacing="0">
	<tr>
		<td width="17">&nbsp;</td>
		<td valign="top" width="202">
			<div id="mainMenu"></div>
			<div id="subMenu"></div>
		</td>
		<td valign="top">
			<div id="tabMenu" class="submenuBlock"></div>
			<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
				<tr>
					<td align="left" valign="top">
						<table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3"  class="FormTitle" id="FormTitle">
							<tr>
								<td bgcolor="#4D595D" colspan="3" valign="top">
									<div>&nbsp;</div>
									<div style="float:left;" class="formfonttitle">软件中心 - EasyTier异地组网</div>
									<div style="float:right; width:15px; height:25px;margin-top:10px"><img id="return_btn" onclick="reload_Soft_Center();" align="right" style="cursor:pointer;position:absolute;margin-left:-30px;margin-top:-25px;" title="返回软件中心" src="/images/backprev.png" onMouseOver="this.src='/images/backprevclick.png'" onMouseOut="this.src='/images/backprev.png'"></img></div>
									<div style="margin:30px 0 10px 5px;" class="splitLine"></div>
									<div class="formfontdesc" style="margin-left:10px;">
										<i>EasyTier 是一个简单、安全、去中心化的异地组网方案。</i>
									</div>
									<div id="easytier_switch_show">
									<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
										<tr id="switch_tr">
											<th>
												<label><a class="hintstyle" href="javascript:void(0);" onmouseover="return showHelpHint(0);" onmouseout="nd();">开启EasyTier</a></label>
											</th>
											<td colspan="2">
												<div class="switch_field" style="display:table-cell;float: left;">
													<label for="easytier_enable">
														<input id="easytier_enable" class="switch" type="checkbox" style="display: none;">
														<div class="switch_container" >
															<div class="switch_bar"></div>
															<div class="switch_circle transition_style">
																<div></div>
															</div>
														</div>
													</label>
												</div>
												<div id="easytier_version_show" style="padding-top:5px;margin-left:30px;margin-top:0px;float: left;"></div>
												<div id="easytier_changelog_show" style="padding-top:5px;margin-right:10px;margin-top:0px;float: right;">
													<input class="button_gen" style="margin-right:5px;" type="button" value="查看更新" onclick="window.open('https://github.com/EasyTier/EasyTier/releases', '_blank');"/>
													<input class="button_gen" type="button" value="查看Peer" onclick="showPeerInfo();"/>
												</div>
											</td>
										</tr>
										<tr id="easytier_status">
											<th width="20%">运行状态</th>
											<td><span id="status">获取中...</span>
											</td>
										</tr>

										<tr>
											<th width="20%" style="vertical-align:top;"><a class="hintstyle" href="javascript:void(0);" onmouseover="return showHelpHint(1);" onmouseout="nd();">TOML配置</a></th>
											<td>
												<textarea id="easytier_toml_config" name="easytier_toml_config" rows="20" spellcheck="false"></textarea>
											</td>
										</tr>
									</table>
									</div>

									<div class="apply_gen">
										<input class="button_gen" style="margin-right:5px;" id="checkBtn" onclick="checkConfig()" type="button" value="检查"/>
										<input class="button_gen" style="margin-right:5px;" id="saveBtn" onclick="saveConfig()" type="button" value="保存"/>
										<input class="button_gen" style="margin-right:5px;" id="startBtn" onclick="submitService()" type="button" value="提交"/>
									</div>

									<div style="margin:30px 0 10px 5px;" class="splitLine"></div>
									<div class="formfontdesc" style="margin-left:10px;">
										<b>使用说明：</b><br>
										1. 在上方文本框中直接输入完整的 TOML 配置文件<br>
										2. 配置会保存到 <code>/koolshare/configs/easytier.toml</code><br>
										3. 配置示例请参考 <a href="https://github.com/EasyTier/EasyTier" target="_blank">EasyTier 官方文档</a><br>
										4. [重要]路由器可能不支持<code>tun</code>启动, 启动失败可能需要在<code>flags</code>中添加<code>no_tun = true</code><br>
										5. 启动后可通过「查看Peer」按钮查看已连接的节点信息
									</div>
								</td>
							</tr>
						</table>
					</td>
				</tr>
			</table>
		</td>
		<td width="10" align="center" valign="top"></td>
	</tr>
</table>
</form>
<div id="footer"></div>
</body>
</html>
