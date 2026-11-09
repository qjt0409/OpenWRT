# OpenWRT-CI-X86

基于 **Lean 大的 lede 源码**（[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)，master 分支，x86 内核 6.18 / OpenWrt 25.12 主线）的 GitHub Actions 云编译项目，面向 **x86_64 软路由（J1900 / J1800 等通用设备）**。

> 说明：lede 没有「24.10.3」这个版本号（24.10.3 是 OpenWrt 官方版本号）。lede master 基于 OpenWrt 25.12 主线、x86 内核 6.18，功能与稳定性均优于旧版 lede 分支，因此本项目采用 lede master。

## 登录信息

| 项目 | 值 |
|---|---|
| 管理地址 | `http://10.0.1.1` |
| 用户名 | `root` |
| 密码 | `password`（首次登录直接可用，无需手动设置） |
| 主机名 | `OpenWRT` |
| 默认语言 | 中文（zh_cn，全量界面中文） |

## 固件特性（当前清单）

| 类别 | 内容 |
|---|---|
| 科学上网 | **PassWall**（26.9.16，含 Hysteria2）、**PassWall2**（26.9.16）、**OpenClash**（vernesong 官方 0.47.156+） |
| 消息推送 | 全能推送（PushBot）、微信推送（ServerChan，已更名 luci-app-wechatpush） |
| 网络工具 | DDNS-Go、Lucky（2.27.2 官方最新）、uhttpd、负载均衡（mwan3）、TTYD 终端、自定义命令、IP 限速（eqosplus）、**看门狗 Watchcat** |
| 文件存储 | 易有云（LinkEase）、**OpenList**（= Alist 社区分支，登录页显示 Alist 属正常）、网络共享（Samba4）、磁盘管理 |
| 容器 | **Docker**（dockerd + docker-compose 29.6.1），**独立顶级菜单**（Docker 管理，非"Docker CE"样式） |
| 行为管理 | OAF（OpenAppFilter 上游 v7）应用过滤 |
| 应用商店 | **iStore 商店**（中文界面，1Panel 等可在商店内一键安装） |
| 流量统计 | luci-app-statistics（collectd）、BandwidthD 按 IP 流量统计（守护包走 packages feed，界面包为作者 AlexZhuo 仓库；数据持久化于 /mnt/sdb2/tongji，重启不丢失，保留 13 个月自动清理） |
| 网络加速 | TurboACC（Flow Offload），**BBR 由内核直接启用并设为默认拥塞算法** |
| 主题 | Argon + Argon 主题设置（默认主题钉死 Argon；design/bootstrap 显式关闭，design 首启抢默认另在构建时摘除） |

**顶级菜单顺序**：状态 → 系统 → iStore → Docker → 服务 → 网络存储 → Control → 网络 → 统计 → 退出

## PassWall 能力（协议 / 内核 / 传输）

- **协议**：VLESS（+Vision/REALITY/XHTTP）、VMess、Shadowsocks（2022）、ShadowsocksR、Trojan（+XTLS）、WireGuard、Hysteria（v1/v2）、TUIC v5、NaiveProxy、Shadow-TLS、SSH、Socks4/5、HTTP/HTTPS，以及负载均衡/分流/自定义接口
- **内核（每次构建自动拉官方最新）**：Xray（26.9.9）、Sing-Box（1.14.2）、Shadowsocks-Rust、ShadowsocksR-Libev、Hysteria2，辅助组件 chinadns-ng / dns2socks / ipt2socks / microsocks / naiveproxy / shadow-tls / v2ray-geodata 等全部最新
- **传输**：TCP、WS、gRPC、HTTPupgrade、XHTTP（h2/h3）、mKCP、QUIC
- **注意**：Xray 26.9+ 已禁止裸 VLESS 连接公网地址（"vless without TLS ... is prohibited"）。若节点无加密（裸 VLESS），请在节点「内核」选 **Sing-Box**，或使用带 TLS/REALITY 的节点

## OpenClash 说明

- 来源：vernesong/OpenClash 官方 master（每次构建自动拉最新）
- 依赖已内置：dnsmasq-full（lede 自带，当前 2.93）、bash、curl、ca-bundle、ip-full、ruby、ruby-yaml、kmod-tun、unzip
- **clash / clash-meta 内核不在固件内**：首次使用进「OpenClash → 配置运行 → 内核下载」获取（若下载失败，可先配置好 PassWall 代理后再下载，或手动上传内核文件到 `/etc/openclash/core/`）

## 插件来源与版本策略

- **包装仓库按最新拉取**：lede 源码、所有外部插件包装仓库均按 main/master 最新拉取（每次构建全新 clone），lucky / passwall 全家桶 / OpenClash / iStore / argon 等全部官方源。注意：包装仓库最新 ≠ 应用本体最新，本体版本由包装仓库 Makefile 的 `PKG_VERSION` 写死（见下条）。
- **构建时自动追新（本仓库处理）**：`Scripts/packages.sh` 文末的追新函数组在构建时查询上游 GitHub 最新 Release 自动升级版本（hash 置 skip，查询失败自动回退原版本、绝不因此让构建失败），覆盖：lucky、ddns-go、xray-core、sing-box、hysteria、chinadns-ng、shadowsocks-rust、shadow-tls、geoview、v2ray-plugin、xray-plugin、microsocks、ipt2socks、v2ray-geodata（geoip/geosite 数据）、naiveproxy、smartdns、linkease 本体、OpenList（含前端版本同步）。**Docker 全家桶联动升级**（dockerd/docker/containerd/runc/tini 整组升）自 2026-11-01 起停用：containerd 2.4.2 在本构建环境编译失败（go:embed 资源文件缺失），Docker 暂随 feed 版本 29.6.1；联动函数保留在脚本中，待适配后重新启用（删除调用行前的注释即可）。
- **已核实无需追新**：dns2socks、shadowsocksr-libev（源码内嵌包装仓库、上游已停更，现版即最终版）、tcping、simple-obfs（git 包，所钉 commit 经核对就是上游 master HEAD，上游已归档）。
- **feed 插件的版本边界**：luci feed 固定 `openwrt-25.12` 分支是 lede 官方搭配（coolsnowwolf/luci 的 master 为陈旧遗留分支，25.12 已是其最新分支），不能单改；Samba4、TTYD、mwan3、statistics、TurboACC、watchcat 等的上游就是 OpenWrt/lede 本身，只能随 lede 更新，单独升版会与系统库冲突，不做。磁盘管理 Diskman 已改为 lisaac 官方源直拉（与 feed 版脱钩）。
- **官方源替换 feed 旧版**：`Scripts/packages.sh` 按「包名目录」提取多包仓库子目录（lucky、passwall、passwall-packages、OpenClash、ddns-go），并在 `core.yml` 与 `packages.sh` 移除 lede feed 同名旧版（passwall / lucky / OpenClash / dockerman / ddns-go / wechatpush / argon 等），避免同名冲突与版本回退。
- **已移除**：Alist（luci-app-alist）、lede 自带 Docker CE 界面（改用 Dockerman 顶级菜单）、helloworld feed（与 passwall-packages 同名冲突）

## 使用方法

1. **Fork / 上传本项目**到你的 GitHub 仓库（保持目录结构）。
2. 进入仓库 **Actions** 页面，首次使用会提示启用 Workflows，点击启用。
3. 手动编译：Actions → **OpenWrt-Build** → **Run workflow**。
   - `config`：选择 `X86`
   - `extra_packages`（可选）：额外追加 `CONFIG_PACKAGE_xxx=y` 行
   - `test`：勾选后**只生成 .config 不编译固件**，用于快速验证配置
4. 编译完成后，固件发布在仓库 **Releases** 页面，含：
   - `openwrt-x86-64-generic-squashfs-combined.img.gz`（BIOS 引导，J1900/J1800 刷这个）
   - `openwrt-x86-64-generic-squashfs-combined-efi.img.gz`（UEFI 引导）
   - `...-ext4-*.img.gz`（ext4 文件系统版本）
   - `...-vmdk-image*.gz`（VMware/虚拟机用）
   - `sha256sums`（校验文件）与完整 `.config`

## 常用操作

- **每日自动编译**：每天北京时间 **04:26** 自动执行（清理任务完成后自动触发）。
- **清理**：Actions → **OpenWrt-Cleanup** → Run workflow，清理历史 Releases 与构建缓存（每周一自动执行）。
- **加快二次编译**：构建缓存（ccache + 工具链）自动保存/恢复，同源码提交的二次编译显著加快；缓存超限时自动轮换清理。
- **1Panel 安装**：刷机后进入「iStore 应用商店」→ 搜索 1Panel → 一键安装（固件已内置 Docker）。
- **升级固件**：在「系统 → 备份/升级」上传 `squashfs-combined.img.gz` 并勾选保留配置；lucky 配置存于 `/etc/config/lucky`（已列为 conffiles，升级保留）。

## 自定义

- **增删插件**：编辑 `Config/X86.txt`，按需增删 `CONFIG_PACKAGE_xxx=y` 行；修改后先跑一次 `test` 模式验证。
- **插件源码**：`Scripts/packages.sh` 管理所有外部插件克隆与提取（多包仓库自动按子目录落地）。
- **默认参数**：`Scripts/patches.sh`（BBR、dnsmasq 版本守护、顶级菜单重排）、`Scripts/settings.sh`（配置合并 + 中文语言符号）。
- **更换源码**：修改 `build.yml` 中 `repo` / `branch` / `source` 三个参数。

## 注意事项

- OAF（OpenAppFilter）为内核模块，若未来 lede 升级内核后编译报错，可在 `Config/X86.txt` 中临时移除 OAF 相关行，等待上游适配。
- 首次编译约 2~4 小时（需编译 Go 类组件如 xray-core、sing-box 等），属正常现象。
- 管理地址为 `10.0.1.1`，刷机后电脑需与路由器在同一网段（10.0.1.x）才能访问后台。
- OpenList 登录页显示 "Alist for OpenWRT" 属正常（OpenList 为 Alist 社区分支）。

## 目录结构

```
OpenWRT-CI-X86/
├── .github/workflows/
│   ├── build.yml        # 编译入口（手动/定时/清理后触发，hostname=OpenWRT）
│   ├── core.yml         # 可复用编译核心（克隆→移除冲突源→插件→补丁→编译→发布）
│   └── cleanup.yml      # 定期清理 Releases 与缓存
├── Config/
│   └── X86.txt          # x86_64 目标配置片段（全部插件开关）
├── Scripts/
│   ├── packages.sh      # 插件源码安装（官方源提取 + 移除 feed 同名旧版）
│   ├── patches.sh       # 源码级补丁（BBR/dnsmasq 版本守护/菜单重排）
│   └── settings.sh      # 编译配置生成
├── Files/etc/uci-defaults/
│   ├── 99-zh-lang       # 首次启动设置中文
│   └── 99-root-password # 首次启动设置 root 密码 password
└── README.md
```
