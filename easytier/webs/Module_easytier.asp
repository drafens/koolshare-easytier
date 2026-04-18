<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<!-- plugin version: 1.0 -->
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache"/>
<meta HTTP-EQUIV="Expires" CONTENT="-1"/>
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
.frpc_btn {
    border: 1px solid #3c3c3c;
    background: linear-gradient(to bottom, #3c3c3c  0%, #2a2a2a 100%);
    font-size:10pt;
    color: #fff;
    padding: 5px 10px;
    border-radius: 5px;
    width:auto;
    cursor:pointer;
    text-decoration:none;
    display:inline-block;
}
.frpc_btn:hover {
    border: 1px solid #4a4a4a;
    background: linear-gradient(to bottom, #4a4a4a  0%, #3c3c3c 100%);
    color: #fff;
    text-decoration:none;
}
#easytier_toml_config {
	width:99%;
	font-family:'Lucida Console';
	font-size:11px;
	background:#475A5F;
	color:#FFFFFF;
	text-transform:none;
	margin-top:5px;
	overflow:auto;
	resize:vertical;
	white-space:pre;
	word-break:normal;
	border:1px solid #3c3c3c;
	padding:5px;
}
#easytier_peer_info {
	width:100%;
	font-family:'Lucida Console';
	font-size:10px;
	background:#475A5F;
	color:#FFFFFF;
	white-space:nowrap;
	overflow-x:auto;
	overflow-y:auto;
	border:1px solid #91071f;
	padding:5px;
	line-height:1.4;
}
input[type=button]:focus {
    outline: none;
}
</style>
<script>
var db_easytier = {};
var easytier_refresh_flag = 0;
var easytier_count_down = 0;
var easytier_log_poll_tries = 0;

// 常量定义
const LOG_END_MARKER = "XU6J03M16";
const RESULT_OK = "EASYTIER_RESULT=OK";

function initial() {
	show_menu(menu_hook);
	get_dbus_data();
	get_status();
}

function get_dbus_data() {
	$.ajax({
		type: "GET",
		url: "/_api/easytier",
		dataType: "json",
		async: false,
		success: function(data) {
			db_easytier = data.result[0];
			conf2obj();
			$("#easytier_version_show").html("插件版本：" + db_easytier["easytier_version"]);
		}
	});
}

function conf2obj() {
	// 启用开关
	if(db_easytier["easytier_enable"]){
		E("easytier_enable").checked = db_easytier["easytier_enable"] == 1 ? true : false;
		document.form.easytier_enable.value = db_easytier["easytier_enable"];
	}
	
	// TOML 配置（base64 编码存储）
	if(db_easytier["easytier_toml_config_b64"]){
		try {
			var tomlConfig = atob(db_easytier["easytier_toml_config_b64"]);
			E("easytier_toml_config").value = tomlConfig;
		} catch(e) {
			E("easytier_toml_config").value = db_easytier["easytier_toml_config_b64"];
		}
	}
}

function get_status() {
	var postData = {
		"id": parseInt(Math.random() * 100000000),
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
			setTimeout("get_status();", 10000);
		},
		error: function() {
			setTimeout("get_status();", 5000);
		}
	});
}

function easytier_submit() {
	var tomlContent = E("easytier_toml_config").value.trim();
	if (tomlContent == "") {
		alert("TOML 配置不能为空！");
		return false;
	}
	
	// 将 TOML 配置 base64 编码后保存
	var tomlBase64 = btoa(unescape(encodeURIComponent(tomlContent)));
	db_easytier["easytier_toml_config_b64"] = tomlBase64;
	db_easytier["easytier_enable"] = E("easytier_enable").checked ? '1' : '0';
	
	var uid = parseInt(Math.random() * 100000000);
	var postData = {"id": uid, "method": "easytier_config.sh", "params": [1], "fields": db_easytier };
	easytier_refresh_flag = 0;
	E("easytier_ok_button").style.visibility = "hidden";
	E("easytier_log_content").value = "";
	easytier_log_poll_tries = 0;
	showEasyTierLoadingBar();
	$.ajax({
		url: "/_api/",
		cache: false,
		type: "POST",
		dataType: "json",
		data: JSON.stringify(postData),
		success: function(response) {
			if (response.result == uid){
				get_easytier_submit_log();
			}
		},
		error: function() {
			E("easytier_loading_block_title").innerHTML = "提交失败 ...";
			E("easytier_log_content").value = "提交请求失败，请重试！";
			E("easytier_ok_button").style.visibility = "visible";
			easytier_refresh_flag = 0;
			easytier_count_down = -1;
		}
	});
}

// 检查配置（仅验证，不保存）
function easytier_check_config() {
	var tomlContent = E("easytier_toml_config").value.trim();
	if (tomlContent == "") {
		alert("TOML 配置不能为空！");
		return false;
	}
	
	// 将 TOML 配置 base64 编码后传递，但不保存到 dbus
	var tomlBase64 = btoa(unescape(encodeURIComponent(tomlContent)));
	var postData = {"id": parseInt(Math.random() * 100000000), "method": "easytier_config.sh", "params": [3], "fields": {"easytier_toml_config_b64": tomlBase64} };
	easytier_refresh_flag = 0;
	E("easytier_ok_button").style.visibility = "hidden";
	E("easytier_log_content").value = "";
	easytier_log_poll_tries = 0;
	showEasyTierLoadingBar();
	$.ajax({
		url: "/_api/",
		cache: false,
		type: "POST",
		dataType: "json",
		data: JSON.stringify(postData),
		success: function(response) {
			if (response.result == postData.id){
				get_easytier_submit_log();
			}
		},
		error: function() {
			E("easytier_loading_block_title").innerHTML = "提交失败 ...";
			E("easytier_log_content").value = "提交请求失败，请重试！";
			E("easytier_ok_button").style.visibility = "visible";
			easytier_refresh_flag = 0;
			easytier_count_down = -1;
		}
	});
}

// 保存配置
function easytier_save_config() {
	var tomlContent = E("easytier_toml_config").value.trim();
	if (tomlContent == "") {
		alert("TOML 配置不能为空！");
		return false;
	}
	
	// 将 TOML 配置 base64 编码后保存
	var tomlBase64 = btoa(unescape(encodeURIComponent(tomlContent)));
	db_easytier["easytier_toml_config_b64"] = tomlBase64;
	db_easytier["easytier_enable"] = E("easytier_enable").checked ? '1' : '0';
	
	var uid = parseInt(Math.random() * 100000000);
	var postData = {"id": uid, "method": "easytier_config.sh", "params": [4], "fields": db_easytier };
	easytier_refresh_flag = 0;
	E("easytier_ok_button").style.visibility = "hidden";
	E("easytier_log_content").value = "";
	easytier_log_poll_tries = 0;
	showEasyTierLoadingBar();
	$.ajax({
		url: "/_api/",
		cache: false,
		type: "POST",
		dataType: "json",
		data: JSON.stringify(postData),
		success: function(response) {
			if (response.result == uid){
				get_easytier_submit_log();
			}
		},
		error: function() {
			E("easytier_loading_block_title").innerHTML = "提交失败 ...";
			E("easytier_log_content").value = "提交请求失败，请重试！";
			E("easytier_ok_button").style.visibility = "visible";
			easytier_refresh_flag = 0;
			easytier_count_down = -1;
		}
	});
}

// 启动服务
function easytier_start_service() {
	var tomlContent = E("easytier_toml_config").value.trim();
	if (tomlContent == "") {
		alert("TOML 配置不能为空！");
		return false;
	}
	
	// 将 TOML 配置 base64 编码后保存
	var tomlBase64 = btoa(unescape(encodeURIComponent(tomlContent)));
	db_easytier["easytier_toml_config_b64"] = tomlBase64;
	db_easytier["easytier_enable"] = E("easytier_enable").checked ? '1' : '0';
	
	var uid = parseInt(Math.random() * 100000000);
	var postData = {"id": uid, "method": "easytier_config.sh", "params": [1], "fields": db_easytier };
	easytier_refresh_flag = 0;
	E("easytier_ok_button").style.visibility = "hidden";
	E("easytier_log_content").value = "";
	easytier_log_poll_tries = 0;
	showEasyTierLoadingBar();
	$.ajax({
		url: "/_api/",
		cache: false,
		type: "POST",
		dataType: "json",
		data: JSON.stringify(postData),
		success: function(response) {
			if (response.result == uid){
				get_easytier_submit_log();
			}
		},
		error: function() {
			E("easytier_loading_block_title").innerHTML = "提交失败 ...";
			E("easytier_log_content").value = "提交请求失败，请重试！";
			E("easytier_ok_button").style.visibility = "visible";
			easytier_refresh_flag = 0;
			easytier_count_down = -1;
		}
	});
}

function showEasyTierLoadingBar(){
	try {
		if (document.scrollingElement) document.scrollingElement.scrollTop = 0;
	} catch(e){}
	try {
		document.documentElement.scrollTop = 0;
		document.body.scrollTop = 0;
	} catch(e){}
	E("easytier_loading_block_title").innerHTML = "&nbsp;&nbsp;EasyTier 提交日志";
	try {
		var lb = E("easytier_LoadingBar");
		if (lb && lb.style && lb.style.setProperty) {
			lb.style.setProperty("display", "block", "important");
			lb.style.setProperty("visibility", "visible", "important");
		} else {
			lb.style.display = "block";
			lb.style.visibility = "visible";
		}
	} catch(e){}
	var page_h = window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;
	var page_w = window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth;
	var log_h = E("easytier_loadingBarBlock").clientHeight;
	var log_w = E("easytier_loadingBarBlock").clientWidth;
	var log_h_offset = (page_h - log_h) / 2;
	var log_w_offset = (page_w - log_w) / 2 + 90;
	$('#easytier_loadingBarBlock').offset({top: log_h_offset, left: log_w_offset});
}

function hideEasyTierLoadingBar(){
	try {
		var lb = E("easytier_LoadingBar");
		if (lb && lb.style && lb.style.setProperty) {
			lb.style.setProperty("visibility", "hidden", "important");
			lb.style.setProperty("display", "none", "important");
		} else {
			lb.style.visibility = "hidden";
			lb.style.display = "none";
		}
	} catch(e){}
	E("easytier_ok_button").style.visibility = "hidden";
	if (easytier_refresh_flag == 1){
		refreshpage();
	}
}

function easytier_count_down_close() {
	if (easytier_count_down == 0) {
		hideEasyTierLoadingBar();
	}
	if (easytier_count_down < 0) {
		E("easytier_ok_button1").value = "手动关闭"
		return;
	}
	E("easytier_ok_button1").value = easytier_count_down + " 秒后关闭"
	--easytier_count_down;
	setTimeout("easytier_count_down_close();", 1000);
}

function easytier_log_clean(s){
	if (!s) return "";
	return s
		.replace(/\\r/g, "")
		.replace(new RegExp("^.*" + RESULT_OK + ".*$", "gm"), "")
		.replace(new RegExp("^.*" + LOG_END_MARKER + ".*$", "gm"), "")
		.replace(/\n{3,}/g, "\n\n")
		.trim() + "\n";
}

function get_easytier_submit_log(){
	$.ajax({
		url: '/_temp/easytier_submit_log.txt',
		type: 'GET',
		cache:false,
		dataType: 'text',
		success: function(response) {
			var retArea = E("easytier_log_content");
			var done = (response.indexOf("XU6J03M16") != -1);
			var ok = (response.indexOf("EASYTIER_RESULT=OK") != -1);
			retArea.value = easytier_log_clean(response);
			retArea.scrollTop = retArea.scrollHeight;
			if (done) {
				E("easytier_ok_button").style.visibility = "visible";
				easytier_refresh_flag = 1;
				if (ok) {
					easytier_count_down = 6;
				} else {
					easytier_count_down = 4;
				}
				easytier_count_down_close();
				return;
			}
			setTimeout("get_easytier_submit_log();", 500);
		},
		error: function(xhr) {
			easytier_log_poll_tries++;
			if (easytier_log_poll_tries <= 20) {
				setTimeout("get_easytier_submit_log();", 500);
				return;
			}
			E("easytier_loading_block_title").innerHTML = "暂无日志信息 ...";
			E("easytier_log_content").value = "日志文件为空，请关闭本窗口！";
			E("easytier_ok_button").style.visibility = "visible";
			easytier_refresh_flag = 0;
			easytier_count_down = -1;
		}
	});
}

function view_easytier_peer_info(){
	var postData = {
		"id": parseInt(Math.random() * 100000000),
		"method": "easytier_config.sh",
		"params": [2],
		"fields": {}
	};
	$.ajax({
		type: "POST",
		cache: false,
		url: "/_api/",
		data: JSON.stringify(postData),
		dataType: "json",
		success: function(response) {
			showPeerInfo();
		}
	});
}

function showPeerInfo(){
	E("easytier_loading_block_title").innerHTML = "&nbsp;&nbsp;EasyTier Peer 信息";
	showEasyTierLoadingBar();
	$.ajax({
		url: '/_temp/easytier_peer_info.txt',
		type: 'GET',
		cache:false,
		dataType: 'text',
		success: function(response) {
			var retArea = E("easytier_log_content");
			retArea.value = response || "暂无 Peer 信息";
			retArea.cols = 100;  // 增加列数以适应宽表格
			retArea.scrollTop = 0;  // 滚动到顶部
			retArea.scrollLeft = 0;
			E("easytier_ok_button").style.visibility = "visible";
			E("easytier_ok_button1").value = "关闭";
		},
		error: function() {
			E("easytier_loading_block_title").innerHTML = "获取失败 ...";
			E("easytier_log_content").value = "无法获取 Peer 信息，请确认 EasyTier 正在运行。";
			E("easytier_ok_button").style.visibility = "visible";
			E("easytier_ok_button1").value = "关闭";
		}
	});
}

function menu_hook(title, tab) {
	tabtitle[tabtitle.length - 1] = new Array("", "EasyTier 异地组网");
	tablink[tablink.length - 1] = new Array("", "Module_easytier.asp");
}

function openssHint(itemNum) {
	var statusmenu = "";
	var _caption = "";

	if (itemNum == 0) {
		_caption = "开启 EasyTier";
		statusmenu = "开启/关闭 EasyTier 服务。<br>若无法启用，请先在 <a href='Advanced_System_Content.asp'><u><font color='#00F'>系统管理 - 系统设置</font></u></a> 开启 Enable JFFS custom scripts and configs。";
	} else if (itemNum == 1) {
		_caption = "TOML 配置";
		statusmenu = "直接输入 EasyTier 的完整 TOML 配置文件。<br>支持所有 EasyTier 配置选项。<br>配置示例：<br>instance_name = 'my-network'<br>ipv4 = '10.144.144.1'<br><br>[[peer]]<br>uri = 'tcp://1.2.3.4:11010'<br><br>配置会保存到 /koolshare/configs/easytier.toml<br>并使用 base64 编码存储到 dbus 以便回显。";
	}

	return overlib(statusmenu, OFFSETX, -160, LEFT, WIDTH, 360, CAPTION, _caption);
}
</script>
</head>
<body onload="initial();">
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
					<input style="margin-left:10px" id="easytier_ok_button1" class="button_gen" type="button" onclick="hideEasyTierLoadingBar()" value="确定">
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
												<label><a class="hintstyle" href="javascript:void(0);" onmouseover="return openssHint(0);" onmouseout="nd();">开启EasyTier</a></label>
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
													<a type="button" class="frpc_btn" style="cursor:pointer" href="https://github.com/EasyTier/EasyTier/releases" target="_blank">查看更新</a>
													<a type="button" class="frpc_btn" style="cursor:pointer" href="javascript:void(0);" onclick="view_easytier_peer_info();">查看Peer</a>
												</div>
											</td>
										</tr>
										<tr id="easytier_status">
											<th width="20%">运行状态</th>
											<td><span id="status">获取中...</span>
											</td>
										</tr>

										<tr>
											<th width="20%" style="vertical-align:top;"><a class="hintstyle" href="javascript:void(0);" onmouseover="return openssHint(1);" onmouseout="nd();">TOML配置</a></th>
											<td>
												<textarea id="easytier_toml_config" name="easytier_toml_config" rows="20" spellcheck="false" placeholder="# EasyTier TOML Configuration
# 保存位置: /koolshare/configs/easytier.toml

instance_name = 'my-network'
ipv4 = '10.144.144.1'
dhcp = false

[network_identity]
network_name = 'my-network'
network_secret = 'your-secret-password'

[rpc]
rpc_portal = '127.0.0.1:15888'

[flags]
no_tun = true

# 添加节点（可选）
# [[peer]]
# uri = 'tcp://1.2.3.4:11010'"></textarea>
											</td>
										</tr>
									</table>
									</div>

									<div class="apply_gen">
										<input class="button_gen" style="margin-right:5px;" id="checkBtn" onclick="easytier_check_config()" type="button" value="检查"/>
										<input class="button_gen" style="margin-right:5px;" id="saveBtn" onclick="easytier_save_config()" type="button" value="保存"/>
										<input class="button_gen" style="margin-right:5px;" id="startBtn" onclick="easytier_start_service()" type="button" value="提交"/>
									</div>

									<div style="margin:30px 0 10px 5px;" class="splitLine"></div>
									<div class="formfontdesc" style="margin-left:10px;">
										<b>使用说明：</b><br>
										1. 在上方文本框中直接输入完整的 TOML 配置文件<br>
										2. 配置会保存到 <code>/koolshare/configs/easytier.toml</code><br>
										3. 配置示例请参考 <a href="https://github.com/EasyTier/EasyTier" target="_blank">EasyTier 官方文档</a><br>
										4. [重要]路由器可能不支持tun启动, 启动失败可能需要在flags中添加no_tun = true<br>
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
