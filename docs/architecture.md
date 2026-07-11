# EasyTier Softcenter Plugin Architecture

## 目标

插件是 Softcenter 与 EasyTier 之间的薄适配层，不复制 EasyTier 配置语义，不运行独立 Web 服务，不依赖路由器上不存在的完整 Linux 服务管理器。

设计目标按优先级排序：

1. 无效配置不能破坏最后一份有效配置。
2. 服务操作必须幂等、可观察且不影响其他进程。
3. 密钥只持久化在权限为 `600` 的 TOML 文件中。
4. 页面保持原生、轻量，不依赖外部 CDN 或前端框架。
5. 构建输入必须固定且可校验。

## 组件边界

| 组件 | 职责 |
| --- | --- |
| `easytier_config.sh` | `/_api/` 动作白名单、配置事务、CLI 查询 |
| `easytier_service.sh` | PID 生命周期、启动、停止、状态 |
| `easytier_event.sh` | Softcenter 启动事件适配 |
| `easytier_status.sh` | 页面低成本状态轮询 |
| `easytier_common.sh` | 路径、锁、PID 校验和响应协议 |
| `easytier.js` | 单一 API 客户端、响应解析和页面状态刷新 |

Shell 层不再继续拆分。函数只在职责所属脚本中定义，共享的基础设施函数放入 `easytier_common.sh`。

## 状态和数据

`/koolshare/configs/easytier.toml` 保存实际配置文件。dbus 仅保存开机自启意图、核心版本和软件中心元数据。

运行状态通过核心进程确定：

- `easytier_autostart` 表示系统启动事件是否应启动服务。
- 先读取 PID 文件，再扫描 `/proc` 恢复遗漏的 PID；进程的 `/proc/<pid>/exe` 文件名必须为 `easytier-core`。
- EasyTier核心日志，写入 `/tmp/easytier/easytier.log`；
- 插件Shell日志，写入 `/tmp/easytier/easytier-service.log`；
- 单文件约 1 MiB，并保留一个`.1` 的归档；可在日志页面手动清理；

## 配置事务

1. 页面以 Base64 临时字段提交 TOML，字段名包含请求 ID。
2. API 读取并删除临时 dbus 字段，获取全局服务锁并写入配置目录中的候选文件。
3. `easytier-core -c <candidate> --check-config` 仅加载并解析 TOML；若上游未输出错误文本，插件使用随机本地 RPC 端口执行一次受限诊断。
4. 校验成功时原子移动候选文件为正式配置；失败时删除候选文件，旧配置保持不变。
5. 保存不影响当前运行实例。页面提示用户通过服务按钮重启 EasyTier 后应用新配置。

EasyTier RPC portal 是核心提供给 `easytier-cli` 的本地管理接口，用于查询节点、Peer 和路由等运行状态。启动成功要求核心进程存在且默认 portal 可访问；已有进程但 RPC 不可用时，插件停止残留进程后重新启动。

配置检查、诊断、CLI、启动和停止操作的后端时限为 8 秒，页面请求时限为 10 秒。安装和卸载最多等待操作锁 10 秒；卸载等待超时或停止失败时会警告并继续清理。

## API 协议

业务响应头使用稳定的 ASCII 键值：

```text
RESULT=success|pending|failed
CODE=STABLE_MACHINE_CODE
MESSAGE=Human readable text

optional payload
```

页面只根据 `RESULT` 和 `CODE` 决定状态，不解析日志文本。核心输出中的空行不会破坏协议解析。

由于 Softcenter 的 `http_response` 不会对多行内容进行 JSON 转义，除纯数字请求确认外，HTTP 载荷统一使用 `ETB64:<base64>` 单行封装，页面解码后再解析上述协议。

## 安全边界

- 禁止对 Web 输入使用 `eval`。
- API 动作和 CLI 子命令全部使用白名单。
- TOML 最大 256 KiB，文件权限为 `600`。
- 配置保存、服务启停、日志清空和安装生命周期共享一个原子目录锁。
- PID 归属通过 `/proc/<pid>/exe` 精确校验。
- CLI 和日志输出只能进入 textarea/textContent，不进入 `innerHTML`。

## 发布

构建平台到 EasyTier ABI 的映射来自 `manifest/platforms.conf`。任何新平台都必须在代表设备上验证后才能加入。

上游版本必须固定。下载脚本从 GitHub Release API 获取 asset URL 和 SHA-256 digest，校验压缩包及 ELF 架构后才更新仓库内二进制。

## 验收标准

- 首次安装、启动、停止和开机启动工作正常。
- 重复启动不会生成第二个进程。
- 非法 TOML 展示 EasyTier 原始错误，正式配置保持不变。
- 运行时提交非法配置后原实例继续运行。
- 两个页面并发修改时最多一个请求进入临界区。
- 普通卸载保留配置，purge 删除配置。
- HND、MTK、QCA/IPQ 包的 ELF ABI 与目标平台一致。
- 页面在 ASUSWRT、ROG/TUF Softcenter 主题和窄屏中无重叠。
