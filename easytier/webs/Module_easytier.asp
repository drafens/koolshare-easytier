<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<meta http-equiv="Pragma" content="no-cache"/>
<meta http-equiv="Expires" content="-1"/>
<title>软件中心 - EasyTier异地组网</title>
<link rel="stylesheet" type="text/css" href="index_style.css"/>
<link rel="stylesheet" type="text/css" href="form_style.css"/>
<link rel="stylesheet" type="text/css" href="usp_style.css"/>
<link rel="stylesheet" type="text/css" href="res/softcenter.css"/>
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/res/softcenter.js"></script>
<script type="text/javascript">
function menu_hook(title, tab) {
  tabtitle[tabtitle.length - 1] = new Array("", "EasyTier 异地组网");
  tablink[tablink.length - 1] = new Array("", "Module_easytier.asp");
}
</script>
<script type="text/javascript" src="/res/easytier.js?v=__EASYTIER_RELEASE_VERSION__"></script>
<style type="text/css">
#easytier-app { width:100%; }
.easytier-status-grid { display:table; table-layout:fixed; width:100%; margin:12px 0; border-top:1px solid #6b8fa3; border-bottom:1px solid #6b8fa3; }
.easytier-status-item { display:table-cell; width:25%; padding:10px 12px; border-right:1px solid #6b8fa3; vertical-align:top; box-sizing:border-box; }
.easytier-status-item:last-child { border-right:0; }
.easytier-status-label { display:block; margin-bottom:4px; color:#b8c4c8; font-size:11px; }
.easytier-status-value { display:block; font-size:13px; word-wrap:break-word; }
.easytier-version-link { color:#9fd7ff; text-decoration:underline; cursor:pointer; }
.easytier-version-link:hover, .easytier-version-link:focus { color:#d6f0ff; text-decoration:underline; }
.easytier-state-running { color:#7bd88f; }
.easytier-state-failed { color:#ff8a80; }
.easytier-state-stopped { color:#d3d9dc; }
.easytier-toolbar { width:100%; margin:10px 0; min-height:34px; overflow:hidden; }
.easytier-tabs { display:inline-block; border-bottom:1px solid #6b8fa3; vertical-align:bottom; }
.easytier-actions { float:right; white-space:nowrap; }
.easytier-actions .button_gen { margin-left:6px; }
.easytier-view-actions { min-height:32px; margin:0 0 8px; overflow:hidden; }
.easytier-links { margin:0 0 10px 5px; color:#b8c4c8; font-size:12px; }
.easytier-links a { color:#9fd7ff; text-decoration:underline; }
.easytier-links .separator { margin:0 8px; color:#7f9096; }
.easytier-tab { min-width:72px; padding:9px 14px 7px; border:0; border-bottom:3px solid transparent; background:transparent; color:#fff; cursor:pointer; }
.easytier-tab.is-active { border-bottom-color:#5fa7c4; font-weight:bold; }
.easytier-view[hidden] { display:none !important; }
#easytier-config-editor, .easytier-output { display:block; box-sizing:border-box; width:100%; border:1px solid #6b8fa3; background:#26363b; color:#f4f7f8; font-family:"Lucida Console",Monaco,monospace; font-size:12px; line-height:1.55; padding:10px; resize:vertical; white-space:pre; overflow:auto; }
#easytier-config-editor { height:390px; min-height:390px; }
.easytier-output { height:350px; min-height:350px; }
.easytier-dirty { float:left; padding-top:9px; color:#ffd180; font-size:12px; visibility:hidden; }
.easytier-dirty.is-visible { visibility:visible; }
.easytier-modal { position:fixed; top:0; left:0; z-index:9999; display:none; width:100%; height:100%; background:rgba(20,28,31,.88); }
.easytier-modal.is-visible { display:block; }
.easytier-dialog { position:absolute; top:8%; left:50%; box-sizing:border-box; width:720px; margin-left:-360px; max-height:84%; padding:16px; border:1px solid #6b8fa3; background:#26363b; color:#fff; }
.easytier-dialog-title { margin:0 0 12px; font-size:16px; }
.easytier-dialog .easytier-output { height:360px; min-height:260px; max-height:55vh; }
button[disabled], input[disabled] { cursor:not-allowed !important; opacity:.55; }
@media screen and (max-width:900px) {
  .easytier-dialog { left:5%; width:90%; margin-left:0; }
  .easytier-status-grid { display:block; }
  .easytier-status-item { display:inline-block; width:49%; border-bottom:1px solid #6b8fa3; }
}
</style>
</head>
<body onload="easytierInitial();">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>

<div id="easytier-modal" class="easytier-modal" role="dialog" aria-modal="true" aria-labelledby="easytier-dialog-title">
  <div class="easytier-dialog">
    <h2 id="easytier-dialog-title" class="easytier-dialog-title">EasyTier</h2>
    <textarea id="easytier-dialog-content" class="easytier-output" readonly="readonly" wrap="off"></textarea>
    <div class="apply_gen">
      <input id="easytier-dialog-close" class="button_gen" type="button" value="关闭"/>
    </div>
  </div>
</div>

<table class="content" align="center" cellpadding="0" cellspacing="0">
  <tr>
    <td width="17">&nbsp;</td>
    <td valign="top" width="202"><div id="mainMenu"></div><div id="subMenu"></div></td>
    <td valign="top">
      <div id="tabMenu" class="submenuBlock"></div>
      <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
        <tr><td align="left" valign="top">
          <table width="760px" border="0" cellpadding="5" cellspacing="0" class="FormTitle" id="FormTitle">
            <tr><td bgcolor="#4D595D" valign="top">
              <div>&nbsp;</div>
              <div class="formfonttitle">软件中心 - EasyTier异地组网</div>
              <div style="float:right;width:15px;height:25px;margin-top:-20px;">
                <img id="return_btn" alt="" onclick="reload_Soft_Center();" align="right" style="cursor:pointer;position:absolute;margin-left:-30px;margin-top:-25px;" title="返回软件中心" src="/images/backprev.png" onmouseover="this.src='/images/backprevclick.png'" onmouseout="this.src='/images/backprev.png'"/>
              </div>
              <div class="splitLine" style="margin:10px 0 10px 5px;"></div>
              <div class="easytier-links">
                <a href="https://easytier.cn/guide/network/configurations.html" target="_blank">EasyTier 配置文档</a><span class="separator">|</span><a href="https://github.com/koolshare/rogsoft" target="_blank">KoolShare 官方插件</a><span class="separator">|</span><a href="https://github.com/drafens/koolshare-easytier" target="_blank">本插件项目</a>
              </div>

              <div id="easytier-app">
                <div class="easytier-status-grid">
                  <div class="easytier-status-item"><span class="easytier-status-label">运行状态</span><span id="easytier-state" class="easytier-status-value">获取中</span></div>
                  <div class="easytier-status-item"><span class="easytier-status-label">进程 PID</span><span id="easytier-pid" class="easytier-status-value">-</span></div>
                  <div class="easytier-status-item"><span class="easytier-status-label">核心版本</span><a id="easytier-core-version" class="easytier-status-value easytier-version-link" href="https://github.com/EasyTier/EasyTier/releases" target="_blank">-</a></div>
                  <div class="easytier-status-item"><span class="easytier-status-label">插件版本</span><a id="easytier-plugin-version" class="easytier-status-value easytier-version-link" href="https://github.com/drafens/koolshare-easytier/releases" target="_blank">-</a></div>
                </div>

                <div class="easytier-toolbar">
                  <div class="easytier-tabs" role="tablist">
                    <button class="easytier-tab is-active" type="button" data-view-target="config">配置</button>
                    <button class="easytier-tab" type="button" data-view-target="network">网络</button>
                    <button class="easytier-tab" type="button" data-view-target="log">日志</button>
                  </div>
                  <div class="easytier-actions">
                    <input id="easytier-service-button" class="button_gen" data-easytier-action="service" type="button" value="启动"/>
                  </div>
                </div>

                <div class="easytier-view" data-view="config">
                  <div class="easytier-view-actions">
                    <span id="easytier-dirty" class="easytier-dirty">有未保存的修改</span>
                    <div class="easytier-actions">
                      <input id="easytier-apply-button" class="button_gen" data-easytier-action="apply" type="button" value="保存配置"/>
                    </div>
                  </div>
                  <textarea id="easytier-config-editor" spellcheck="false" wrap="off" placeholder="instance_name = 'my-router'
ipv4 = '10.144.144.1'

[network_identity]
network_name = 'my-network'
network_secret = 'change-me'"></textarea>
                </div>

                <div class="easytier-view" data-view="network" hidden="hidden">
                  <div class="easytier-view-actions">
                    <div class="easytier-actions">
                      <input class="button_gen" data-easytier-action="query" data-cli-action="get_node" type="button" value="本机"/>
                      <input class="button_gen" data-easytier-action="query" data-cli-action="get_peers" type="button" value="Peer"/>
                      <input class="button_gen" data-easytier-action="query" data-cli-action="get_routes" type="button" value="路由"/>
                    </div>
                  </div>
                  <textarea id="easytier-network-output" class="easytier-output" readonly="readonly" wrap="off"></textarea>
                </div>

                <div class="easytier-view" data-view="log" hidden="hidden">
                  <div class="easytier-view-actions">
                    <div class="easytier-actions">
                      <input id="easytier-clear-log" class="button_gen" data-easytier-action="query" type="button" value="清空"/>
                      <input class="button_gen" data-easytier-action="query" data-cli-action="get_log" type="button" value="刷新"/>
                    </div>
                  </div>
                  <textarea id="easytier-log-output" class="easytier-output" readonly="readonly" wrap="off"></textarea>
                </div>
              </div>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </td>
    <td width="10" valign="top"></td>
  </tr>
</table>
<div id="footer"></div>
</body>
</html>
