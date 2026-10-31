#!/bin/bash
# SPDX-License-Identifier: MIT
# OpenWRT-CI-X86 插件源码安装脚本
#
# 插件来源优先级：
#   1. 用户提供的仓库清单
#   2. lede / luci feed 自带（无需克隆，直接写 CONFIG 即可）
#   3. 用户清单缺失时自行检索补充
#
# 依赖说明：
#   - PassWall / PassWall2 依赖 openwrt-passwall-packages（已一并安装）
#   - iStore 商店依赖 luci-lib-taskd / taskd / luci-lib-xterm（istore 仓库自带）
#   - 易有云依赖 linkease 二进制 + luci-lib-linkeasefile（nas-packages 系列仓库）
set -e

PACKAGE_DIR="./package"
mkdir -p "$PACKAGE_DIR"

# 克隆完整仓库到 ./package/<name>，自动清理旧目录
clone_pkg() {
	local name="$1" repo="$2" branch="$3"
	echo "=================================================="
	echo ">> 安装插件源码: $name"
	echo ">> 仓库: https://github.com/$repo.git (分支: $branch)"
	rm -rf "$PACKAGE_DIR/$name"
	git clone -q --depth=1 --single-branch --branch "$branch" \
		"https://github.com/$repo.git" "$PACKAGE_DIR/$name" || {
		echo "!! 克隆失败: $name"
		exit 1
	}
}

# 从大仓库中提取指定子目录到 ./package/<name>
extract_dir() {
	local src="$1" dest="$2"
	if [ ! -d "$src" ]; then
		echo "!! 提取失败，源目录不存在: $src"
		exit 1
	fi
	rm -rf "$PACKAGE_DIR/$dest"
	cp -rf "$src" "$PACKAGE_DIR/$dest"
	echo ">> 提取: $src -> $PACKAGE_DIR/$dest"
}

# ---------- 科学上网：PassWall / PassWall2 / OpenClash ----------
# openwrt-passwall 仓库根无 Makefile（多包仓库），需提取子目录到 package/<包名>，
# 目录名与包名一致时才会覆盖 lede feed 自带旧版（lucky 已验证此机制）。
# 依赖包 monorepo：全部子目录提取，确保 passwall 全家桶均为 Openwrt-Passwall 官方最新。
clone_pkg openwrt-passwall-src Openwrt-Passwall/openwrt-passwall main
extract_dir "$PACKAGE_DIR/openwrt-passwall-src/luci-app-passwall" luci-app-passwall
rm -rf "$PACKAGE_DIR/openwrt-passwall-src"

clone_pkg openwrt-passwall2-src Openwrt-Passwall/openwrt-passwall2 main
extract_dir "$PACKAGE_DIR/openwrt-passwall2-src/luci-app-passwall2" luci-app-passwall2
rm -rf "$PACKAGE_DIR/openwrt-passwall2-src"

clone_pkg openwrt-passwall-packages-src Openwrt-Passwall/openwrt-passwall-packages main
for sub in "$PACKAGE_DIR/openwrt-passwall-packages-src"/*/; do
	name=$(basename "$sub")
	[ -f "$sub/Makefile" ] || continue
	extract_dir "${sub%/}" "$name"
done
rm -rf "$PACKAGE_DIR/openwrt-passwall-packages-src"

# 移除 lede feed 自带旧版 passwall 全家桶（界面 + 依赖），
# 避免同名包覆盖官方最新版（xray-core 26.6.1 -> 26.9.9 等）
rm -rf ./package/feeds/luci/applications/luci-app-passwall \
	./feeds/luci/applications/luci-app-passwall \
	./package/feeds/packages/net/xray-core ./feeds/packages/net/xray-core \
	./package/feeds/packages/net/sing-box ./feeds/packages/net/sing-box \
	./package/feeds/packages/net/hysteria ./feeds/packages/net/hysteria \
	./package/feeds/packages/net/chinadns-ng ./feeds/packages/net/chinadns-ng \
	./package/feeds/packages/net/dns2socks ./feeds/packages/net/dns2socks \
	./package/feeds/packages/net/geoview ./feeds/packages/net/geoview \
	./package/feeds/packages/net/ipt2socks ./feeds/packages/net/ipt2socks \
	./package/feeds/packages/net/microsocks ./feeds/packages/net/microsocks \
	./package/feeds/packages/net/naiveproxy ./feeds/packages/net/naiveproxy \
	./package/feeds/packages/net/shadow-tls ./feeds/packages/net/shadow-tls \
	./package/feeds/packages/net/shadowsocks-rust ./feeds/packages/net/shadowsocks-rust \
	./package/feeds/packages/net/shadowsocksr-libev ./feeds/packages/net/shadowsocksr-libev \
	./package/feeds/packages/net/simple-obfs ./feeds/packages/net/simple-obfs \
	./package/feeds/packages/net/tcping ./feeds/packages/net/tcping \
	./package/feeds/packages/net/v2ray-geodata ./feeds/packages/net/v2ray-geodata \
	./package/feeds/packages/net/v2ray-plugin ./feeds/packages/net/v2ray-plugin \
	./package/feeds/packages/net/xray-plugin ./feeds/packages/net/xray-plugin \
	2>/dev/null || true
echo ">> 已用 Openwrt-Passwall 官方最新全家桶，并移除 lede feed 同名旧版"

# ---------- OpenClash（vernesong 官方源） ----------
# 仓库根无 Makefile，提取 luci-app-openclash 子目录到 package/<包名>，
# 并移除 lede feed 自带旧版，保证用官方 master 最新（0.47.156+）。
# 注：clash / clash-meta 内核不在固件内，首次运行在 OpenClash 界面「内核下载」获取
# （可先用 PassWall 代理保证能下载）。
clone_pkg openclash-src vernesong/OpenClash master
extract_dir "$PACKAGE_DIR/openclash-src/luci-app-openclash" luci-app-openclash
rm -rf "$PACKAGE_DIR/openclash-src"
rm -rf ./package/feeds/luci/applications/luci-app-openclash \
	./feeds/luci/applications/luci-app-openclash \
	2>/dev/null || true
echo ">> 已用 OpenClash 官方最新版，并移除 lede feed 自带旧版"

# ---------- Argon 主题与主题设置 ----------
clone_pkg luci-theme-argon jerrykuku/luci-theme-argon master
clone_pkg luci-app-argon-config jerrykuku/luci-app-argon-config master
# 移除 lede feed 同名旧版，避免同名包重复定义（与 lucky/passwall 同一处理原则；
# feed 中不存在对应目录时 rm -rf 无副作用）
rm -rf ./package/feeds/luci/themes/luci-theme-argon ./feeds/luci/themes/luci-theme-argon
rm -rf ./package/feeds/luci/applications/luci-app-argon-config ./feeds/luci/applications/luci-app-argon-config

# ---------- 消息推送 ----------
# 全能推送
clone_pkg luci-app-pushbot zzsj0928/luci-app-pushbot master
rm -rf ./package/feeds/luci/applications/luci-app-pushbot ./feeds/luci/applications/luci-app-pushbot
# 微信推送（原 ServerChan，仓库已更名）
clone_pkg luci-app-wechatpush tty228/luci-app-wechatpush master
# lede luci feed 自带旧版 luci-app-wechatpush（及旧名 luci-app-serverchan），
# 不移除会与 tty228 官方版同名重复定义，此前未清理，导致可能仍用 feed 旧版。
rm -rf ./package/feeds/luci/applications/luci-app-wechatpush ./feeds/luci/applications/luci-app-wechatpush
rm -rf ./package/feeds/luci/applications/luci-app-serverchan ./feeds/luci/applications/luci-app-serverchan
echo ">> 已用 tty228 官方版 wechatpush，并移除 lede feed 同名旧版"

# ---------- 网络工具 ----------
# ddns-go：sirpdboy 仓库根无 Makefile（根目录下是 ddns-go/ 与 luci-app-ddns-go/ 两个子包），
# 此前整仓克隆到 package/luci-app-ddns-go 且未提取子目录、未移除 feed 同名版，
# 实际生效的是 lede feed 版。改为与 passwall/lucky 相同的 extract_dir 方式落地，
# 并移除 feed 的 luci 界面包与 packages 的 ddns-go 核心包，保证用克隆版。
clone_pkg luci-app-ddns-go-src sirpdboy/luci-app-ddns-go main
extract_dir "$PACKAGE_DIR/luci-app-ddns-go-src/ddns-go" ddns-go
extract_dir "$PACKAGE_DIR/luci-app-ddns-go-src/luci-app-ddns-go" luci-app-ddns-go
rm -rf "$PACKAGE_DIR/luci-app-ddns-go-src"
rm -rf ./package/feeds/luci/applications/luci-app-ddns-go ./feeds/luci/applications/luci-app-ddns-go
rm -rf ./package/feeds/packages/net/ddns-go ./feeds/packages/net/ddns-go
echo ">> 已用 sirpdboy 官方版 ddns-go（子目录提取），并移除 lede feed 同名旧版"
# lucky：官方 gdy666 仓库（程序 + 界面两个子包，均取 main 最新；
# 程序本体版本构建时由文末 bump_latest 按 gdy666/lucky 最新 Release 自动追新）
# 程序包 lucky/（装 /etc/init.d/lucky）
# 界面包 luci-app-lucky/（仅装 luckyarch，不装 init.d，避免文件冲突）
clone_pkg luci-app-lucky-src gdy666/luci-app-lucky main
extract_dir "$PACKAGE_DIR/luci-app-lucky-src/lucky" lucky
extract_dir "$PACKAGE_DIR/luci-app-lucky-src/luci-app-lucky" luci-app-lucky
rm -rf "$PACKAGE_DIR/luci-app-lucky-src"
# 移除 lede feed 同名源，避免与 gdy666 最新版冲突：
#   feeds/packages/net/lucky  （旧版 2.17.8，同名包覆盖导致用不上最新版）
#   feeds/luci/applications/luci-app-lucky  （界面包也安装 /etc/init.d/lucky，
#     与 lucky 程序包重复安装同一文件 -> opkg check_data_file_clashes 冲突）
rm -rf ./package/feeds/packages/net/lucky ./feeds/packages/net/lucky
rm -rf ./package/feeds/luci/applications/luci-app-lucky ./feeds/luci/applications/luci-app-lucky
echo ">> 已用 gdy666 官方版 lucky（版本构建时自动追新），并移除 lede feed 同名旧源"
# IP 限速（x86 专用）
clone_pkg luci-app-eqosplus sirpdboy/luci-app-eqosplus main
rm -rf ./package/feeds/luci/applications/luci-app-eqosplus ./feeds/luci/applications/luci-app-eqosplus

# ---------- 文件列表：Alist（已按用户要求移除，不编译） ----------

# ---------- iStore 应用商店（大仓库按需提取） ----------
clone_pkg istore-src linkease/istore main
for d in luci-app-store luci-lib-taskd luci-lib-xterm taskd; do
	extract_dir "$PACKAGE_DIR/istore-src/luci/$d" "$d"
done
# iStore 前端语言由 i18n.translate("istore_vue_lang") 决定，
# 未翻译时默认 en。注入 po 翻译让前端使用中文。
mkdir -p "$PACKAGE_DIR/luci-app-store/po/zh-cn"
cat > "$PACKAGE_DIR/luci-app-store/po/zh-cn/app.po" <<'PO'
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\n"
"Language: zh-cn\n"

msgid "istore_vue_lang"
msgstr "zh-cn"
PO
rm -rf "$PACKAGE_DIR/istore-src"

# ---------- 容器：Dockerman 中文前端 + Docker Engine API 库（参照 qjt0409/openwrt 方案） ----------
# - luci-app-dockerman：lisaac/luci-app-dockerman（dockerman 原作者维护，中文界面；
#   仓库根无 Makefile，需提取 applications/luci-app-dockerman 子目录；
#   Makefile 已自动依赖 luci-lib-docker / docker / dockerd / luci-compat / luci-lib-ip / ttyd；
#   controller 原生注册顶级 admin/docker 菜单 order 40）
# - luci-lib-docker：lisaac/luci-lib-docker（Docker Engine API 库，dockerman 运行必需；
#   仓库结构 collections/luci-lib-docker，需提取）
# 先移除 lede feed 自带同名旧版（luci-app-dockerman / luci-lib-docker），避免同名包重复定义。
rm -rf ./package/feeds/luci/applications/luci-app-dockerman ./feeds/luci/applications/luci-app-dockerman
rm -rf ./package/feeds/luci/applications/luci-lib-docker ./feeds/luci/applications/luci-lib-docker
clone_pkg luci-app-dockerman-src lisaac/luci-app-dockerman master
extract_dir "$PACKAGE_DIR/luci-app-dockerman-src/applications/luci-app-dockerman" luci-app-dockerman
rm -rf "$PACKAGE_DIR/luci-app-dockerman-src"
clone_pkg luci-lib-docker-src lisaac/luci-lib-docker master
extract_dir "$PACKAGE_DIR/luci-lib-docker-src/collections/luci-lib-docker" luci-lib-docker
rm -rf "$PACKAGE_DIR/luci-lib-docker-src"

# ---------- 易有云 LinkEase（大仓库按需提取） ----------
clone_pkg nas-packages linkease/nas-packages master
for d in linkease linkease-common-bin; do
	extract_dir "$PACKAGE_DIR/nas-packages/network/services/$d" "$d"
done
rm -rf "$PACKAGE_DIR/nas-packages"

clone_pkg nas-packages-luci linkease/nas-packages-luci main
for d in luci-app-linkease luci-lib-linkeasefile; do
	extract_dir "$PACKAGE_DIR/nas-packages-luci/luci/$d" "$d"
done
rm -rf "$PACKAGE_DIR/nas-packages-luci"

# ---------- OAF 行为管理（appfilter 用户态 + oaf 内核模块 + luci 界面） ----------
clone_pkg OpenAppFilter destan19/OpenAppFilter master

# 安全校验：lede 自带 OAF 残留会导致 kconfig 重复符号（递归依赖错误）
CONFLICT=$(find ./feeds ./package/feeds -maxdepth 4 -type d \( -name "open-app-filter" -o -name "luci-app-appfilter" \) 2>/dev/null)
if [ -n "$CONFLICT" ]; then
	echo "!! 检测到 lede 自带 OAF 残留，请确认 core.yml 已移除 feeds/packages/net/open-app-filter 与 feeds/luci/applications/luci-app-appfilter"
	echo "!! 残留目录: $CONFLICT"
	exit 1
fi

# ---------- 构建时自动追新（解决“包装仓库 PKG_VERSION 写死”问题） ----------
# 背景：clone_pkg 拉的只是“包装仓库”的最新代码，应用本体版本由各包装仓库
# Makefile 里的 PKG_VERSION 写死，并按该版本下载 tarball（如 lucky / ddns-go /
# xray-core / sing-box）。上游发新版后，包装维护者不改 PKG_VERSION 就不会变新。
# 处理：对结构简单、安全可升的包（源码 URL 形如 .../v$(PKG_VERSION)，单行
# PKG_VERSION + 单个 PKG_HASH），在构建时查询上游 GitHub 最新 Release，
# 自动把 PKG_VERSION 升到最新并将 PKG_HASH 置为 skip（lucky 本就是 skip）。
# 原则：查询失败 / 限流 / tag 格式异常时保留包装仓库原版本、继续构建，
# 追新失败绝不让整个构建失败（本脚本 set -e，故函数内全程防退出）。
# 未纳入：hysteria（tag 为 app/v* 特殊格式）、chinadns-ng / shadowsocks-rust
# （多架构多 hash）、v2ray-geodata（日期版 + 独立 Download 规则）、dockerd
# （与 docker/containerd/runc 版本联动校验，单升会编译报错）——这些仍以
# 包装仓库 / lede feed 维护者更新的版本为准。
bump_latest() {
	local mk="$1" upstream="$2"
	local tag="" ver="" old=""
	if [ ! -f "$mk" ]; then
		echo ">> 追新跳过（Makefile 不存在）: $mk"
		return 0
	fi
	old=$(grep -m1 -oP '^PKG_VERSION:=\K.+' "$mk" 2>/dev/null || true)
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		tag=$(curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/$upstream/releases/latest" 2>/dev/null \
			| sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)
	else
		tag=$(curl -fsSL -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/$upstream/releases/latest" 2>/dev/null \
			| sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)
	fi
	ver="${tag#v}"
	if [ -z "$ver" ] || ! printf '%s' "$ver" | grep -qE '^[0-9][0-9A-Za-z._-]*$'; then
		echo ">> 追新跳过（未取到有效最新版，保留 $old）: $upstream"
		return 0
	fi
	if [ "$ver" = "$old" ]; then
		echo ">> 已是最新: $upstream $old"
		return 0
	fi
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$ver/" "$mk"
	# 版本已变，原 tarball 的固定 hash 必然不匹配，置 skip（与 lucky 上游做法一致）
	if grep -q '^PKG_HASH:=' "$mk"; then
		sed -i 's/^PKG_HASH:=.*/PKG_HASH:=skip/' "$mk"
	fi
	echo ">> 已追新: $upstream $old -> $ver"
	return 0
}

bump_latest "$PACKAGE_DIR/lucky/Makefile" gdy666/lucky
bump_latest "$PACKAGE_DIR/ddns-go/Makefile" jeessy2/ddns-go
bump_latest "$PACKAGE_DIR/xray-core/Makefile" XTLS/Xray-core
bump_latest "$PACKAGE_DIR/sing-box/Makefile" SagerNet/sing-box
# OpenList 本体走 lede packages feed（feed 写死 4.2.7，上游已更新），直接对 feed 的 Makefile 追新
bump_latest "./feeds/packages/net/openlist/Makefile" OpenListTeam/OpenList

echo "=================================================="
echo ">> 全部插件源码安装完成"
