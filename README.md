# koolshare-easytier

KoolShare EasyTier 异地组网插件
适用梅林(merlin)固件/官改(asuswrt)固件

## 简介

EasyTier 是一个简单、安全、去中心化的异地组网方案，支持 WireGuard 加密传输。
本插件为 KoolShare 商店定制，适合梅林(merlin)固件/官改(asuswrt)固件，支持 HND/MTK/QCA/IPQ 等多种路由器架构。

## 功能特性

- 去中心化 P2P 组网，无需中心服务器
- WireGuard 加密传输，安全可靠
- 支持多架构路由器（HND/MTK/QCA/IPQ）
- Web 界面配置，操作简单
- 支持配置检查、保存、一键启动

## 快速开始

### 1. 更新二进制文件

示例（aarch64 架构 v2.6.1）：
```bash
./update_bins.sh <架构> <版本>
# 示例:
./update_bins.sh aarch64 v2.6.1
```

支持的架构：`aarch64`, `arm`, `x86_64`, `mips` 等（根据 EasyTier 官方发布）
使用toml配置启动，理论兼容所有版本

该脚本会自动：
- 从 GitHub 下载指定版本的压缩包, 具体路径为https://github.com/EasyTier/EasyTier/releases/download/<版本>/easytier-linux-<架构>-<版本>.zip
- 解压并提取 `easytier-core` 和 `easytier-cli` 到 `easytier/bin/` 目录
- 更新插件版本号

### 2. 构建插件

```bash
# HND 架构（RT-BE88U, RT-AX86U 等）
sh build.sh hnd

# MTK 架构
sh build.sh mtk

# QCA 架构
sh build.sh qca
```

### 3. 安装插件

将生成的 `output/easytier_xx_xx.tar.gz` 上传到路由器软件中心安装。

## 配置说明

配置采用 TOML 格式，保存到 `/koolshare/configs/easytier.toml`。

### 基础配置示例

```toml
instance_name = 'my-network'
hostname = 'my-router'
dhcp = false
ipv4 = '10.144.144.1'
# dhcp = true

[network_identity]
network_name = 'my-network'
network_secret = 'your-secret-password'

[flags]
no_tun = true

# 添加对等节点（可选）
# [[peer]]
# uri = 'tcp://1.2.3.4:11010'
```

### 重要说明

1. **无 TUN 模式**：路由器可能不支持 TUN 设备，启动失败请在 flags 中添加 `no_tun = true`

## 相关链接

- [EasyTier 官方文档](https://github.com/EasyTier/EasyTier)
- [KoolShare 论坛](https://www.koolshare.cn)

## 许可证

本项目采用 [LGPL-3.0](LICENSE) 开源许可证。

本项目基于 [EasyTier](https://github.com/EasyTier/EasyTier) 开源项目开发，遵循相关开源协议。