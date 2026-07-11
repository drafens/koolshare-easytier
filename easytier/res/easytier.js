(function () {
  "use strict";

  var state = {
    serviceState: "stopped",
    dirty: false,
    loadedConfig: "",
    statusTimer: null
  };

  function el(id) { return document.getElementById(id); }

  function requestId() {
    return String(Math.floor(Math.random() * 90000000) + 10000000);
  }

  function encodeConfig(value) {
    return btoa(unescape(encodeURIComponent(value)));
  }

  function decodeConfig(value) {
    return decodeURIComponent(escape(atob(value)));
  }

  function parsePayload(payload) {
    var text = payload === undefined || payload === null ? "" : String(payload);
    if (text.indexOf("ETB64:") === 0) {
      try { text = decodeConfig(text.substring(6)); }
      catch (decodeError) { return { meta: {}, body: "", raw: "", decodeError: true }; }
    }
    var separator = text.indexOf("\n\n");
    var header = separator >= 0 ? text.substring(0, separator) : text;
    var body = separator >= 0 ? text.substring(separator + 2) : "";
    var meta = {};
    var lines = header.split(/\r?\n/);
    var i;
    for (i = 0; i < lines.length; i += 1) {
      var equals = lines[i].indexOf("=");
      if (equals > 0) meta[lines[i].substring(0, equals)] = lines[i].substring(equals + 1);
    }
    return { meta: meta, body: body, raw: text };
  }

  function request(method, params, fields, id, callback) {
    $.ajax({
      type: "POST",
      cache: false,
      timeout: 10000,
      url: "/_api/",
      dataType: "json",
      data: JSON.stringify({
        id: Number(id || requestId()),
        method: method,
        params: params,
        fields: fields || {}
      }),
      success: function (response) {
        if (!response || response.result === undefined) {
          callback(new Error("路由器接口返回格式无效"));
          return;
        }
        var parsed = parsePayload(response.result);
        if (parsed.decodeError) {
          callback(new Error("路由器接口响应解码失败"));
          return;
        }
        callback(null, parsed);
      },
      error: function (xhr, textStatus, errorThrown) {
        var detail = "路由器接口请求失败";
        if (xhr && xhr.status) detail += "（HTTP " + xhr.status + "）";
        if (textStatus === "timeout") detail = "路由器接口请求超时";
        else if (textStatus && textStatus !== "error") detail += "：" + textStatus;
        if (errorThrown) detail += " " + errorThrown;
        if (xhr && xhr.responseText) detail += "\n\n" + xhr.responseText.substring(0, 800);
        callback(new Error(detail));
      }
    });
  }

  function api(action, options, callback) {
    options = options || {};
    request(
      "easytier_config.sh",
      [action],
      options.fields,
      options.id,
      callback
    );
  }

  function setBusy(value) {
    var buttons = document.querySelectorAll("[data-easytier-action]");
    var i;
    for (i = 0; i < buttons.length; i += 1) buttons[i].disabled = value;
  }

  function setDirty(value) {
    state.dirty = value;
    el("easytier-dirty").className = "easytier-dirty" + (value ? " is-visible" : "");
  }

  function showDialog(title, content, closable) {
    el("easytier-dialog-title").textContent = title;
    el("easytier-dialog-content").value = content || "";
    el("easytier-dialog-close").style.visibility = closable === false ? "hidden" : "visible";
    el("easytier-modal").className = "easytier-modal is-visible";
  }

  function closeDialog() {
    el("easytier-modal").className = "easytier-modal";
  }

  function stateLabel(value) {
    if (value === "running") return "运行中";
    if (value === "failed") return "异常";
    return "已停止";
  }

  function coreReleaseUrl(value) {
    var fallback = "https://github.com/EasyTier/EasyTier/releases";
    return /^https:\/\/github\.com\/EasyTier\/EasyTier\/releases(?:\/|$)/.test(value || "") ? value : fallback;
  }

  function loadStatus() {
    request("easytier_status.sh", [], {}, null, function (error, result) {
      if (error) {
        el("easytier-state").textContent = "状态获取失败";
        el("easytier-state").className = "easytier-status-value easytier-state-failed";
        el("easytier-pid").textContent = "-";
      } else {
        var current = result.meta.STATE || "stopped";
        state.serviceState = current;
        el("easytier-state").textContent = stateLabel(current);
        el("easytier-state").className = "easytier-status-value easytier-state-" + current;
        el("easytier-pid").textContent = result.meta.PID || "-";
        el("easytier-core-version").textContent = result.meta.CORE_VERSION || "unknown";
        el("easytier-core-version").href = coreReleaseUrl(result.meta.CORE_RELEASE_URL);
        el("easytier-plugin-version").textContent = result.meta.PLUGIN_VERSION || "unknown";
        el("easytier-service-button").value = current === "stopped" ? "启动" : "关闭";
      }
      window.clearTimeout(state.statusTimer);
      state.statusTimer = window.setTimeout(loadStatus, 8000);
    });
  }

  function loadConfig() {
    api("get_config", {}, function (error, result) {
      if (error) {
        el("easytier-config-editor").value = "";
        el("easytier-config-editor").placeholder = "配置读取失败，请确认插件后端已正确安装后刷新页面";
        state.loadedConfig = "";
        setDirty(false);
        return;
      }
      var config = "";
      if (result.meta.CODE === "CONFIG_LOADED") {
        config = result.body;
      }
      el("easytier-config-editor").value = config;
      state.loadedConfig = config;
      setDirty(false);
    });
  }

  function applyConfig() {
    var config = el("easytier-config-editor").value.trim();
    if (!config) { showDialog("无法保存", "配置内容不能为空"); return; }
    var id = requestId();
    var fields = {};
    fields["easytier_payload_" + id] = encodeConfig(config);
    setBusy(true);
    showDialog("正在保存配置", "正在校验配置文件...", false);
    api("save_config", {
      id: id,
      fields: fields
    }, function (error, result) {
      setBusy(false);
      if (error || result.meta.RESULT !== "success") {
        showDialog("提交失败", error ? error.message : result.raw);
        return;
      }
      state.loadedConfig = el("easytier-config-editor").value;
      setDirty(false);
      showDialog("配置已保存", result.raw);
    });
  }

  function serviceAction() {
    var action = state.serviceState === "stopped" ? "start" : "stop";
    setBusy(true);
    api(action, {}, function (error, result) {
      setBusy(false);
      if (error || result.meta.RESULT !== "success") showDialog("操作失败", error ? error.message : result.raw);
      loadStatus();
    });
  }

  function loadOutput(action) {
    var target = action === "get_log" ? el("easytier-log-output") : el("easytier-network-output");
    target.value = "正在读取...";
    api(action, {}, function (error, result) {
      target.value = error ? error.message : (result.body || result.meta.MESSAGE || result.raw);
    });
  }

  function clearLog() {
    if (!window.confirm("确定清空 EasyTier 历史日志？")) return;
    setBusy(true);
    api("clear_log", {}, function (error, result) {
      setBusy(false);
      if (error || result.meta.RESULT !== "success") {
        showDialog("清空失败", error ? error.message : result.raw);
        return;
      }
      el("easytier-log-output").value = "";
    });
  }

  function switchView(name) {
    var views = document.querySelectorAll(".easytier-view");
    var tabs = document.querySelectorAll(".easytier-tab");
    var i;
    for (i = 0; i < views.length; i += 1) views[i].hidden = views[i].getAttribute("data-view") !== name;
    for (i = 0; i < tabs.length; i += 1) tabs[i].className = "easytier-tab" + (tabs[i].getAttribute("data-view-target") === name ? " is-active" : "");
    if (name === "network") loadOutput("get_node");
    if (name === "log") loadOutput("get_log");
  }

  window.easytierInitial = function () {
    show_menu(menu_hook);
    el("easytier-config-editor").oninput = function () { setDirty(this.value !== state.loadedConfig); };
    el("easytier-apply-button").onclick = applyConfig;
    el("easytier-service-button").onclick = serviceAction;
    el("easytier-clear-log").onclick = clearLog;
    el("easytier-dialog-close").onclick = closeDialog;

    $(".easytier-tab").click(function () { switchView(this.getAttribute("data-view-target")); });
    $("[data-cli-action]").click(function () { loadOutput(this.getAttribute("data-cli-action")); });
    window.onbeforeunload = function () { if (state.dirty) return "配置尚未保存"; };
    loadConfig();
    loadStatus();
  };
}());
