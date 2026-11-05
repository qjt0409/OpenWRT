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

# ---------- 清除构建缓存恢复出的 host ruby ----------
# 缓存（staging_dir/host*）会把上一轮装进 hostpkg 的 ruby 一并恢复。本轮 ruby [host]
# 在全新 build_dir 里 configure 时会把这份缓存 ruby 选作 BASERUBY；若其状态异常
# （如仓库改名后跨路径恢复），它加载不了自带标准库 optparse，构建必死在
# .revision.time 步（2026-11-02 两轮构建同签名失败：
# tool/file2lastrev.rb: cannot load such file -- optparse (LoadError)）。
# 本地已验证：无现成 ruby 时 configure 回退 miniruby 自举、构建正常。
# 故在编译前删掉缓存中的 ruby 本体与库，强制本轮重编一份干净的；
# 本步在缓存恢复之后、编译开始之前运行，时机正好。
rm -f ./staging_dir/hostpkg/bin/ruby ./staging_dir/hostpkg/bin/rake \
      ./staging_dir/hostpkg/bin/gem ./staging_dir/hostpkg/bin/irb \
      ./staging_dir/hostpkg/bin/erb ./staging_dir/hostpkg/bin/rdoc \
      ./staging_dir/hostpkg/bin/ri ./staging_dir/hostpkg/bin/bundle \
      ./staging_dir/hostpkg/bin/bundler ./staging_dir/hostpkg/bin/racc \
      ./staging_dir/hostpkg/bin/rbs ./staging_dir/hostpkg/bin/rdbg
rm -rf ./staging_dir/hostpkg/lib/ruby ./staging_dir/hostpkg/lib/libruby* \
       ./staging_dir/hostpkg/include/ruby-* ./staging_dir/hostpkg/share/ri
rm -f ./staging_dir/hostpkg/lib/pkgconfig/ruby*.pc
echo ">> 已清除缓存中的 host ruby（避免 BASERUBY 加载 optparse 失败）"

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
# 注意：这两个包【不要】删 lede feed 同名版（经 2026-10-15 发布固件的 rootfs 实测）：
# jerrykuku 的 luci-app-argon-config 仓库没有 po 目录，其简体中文目录
# argon-config.zh-cn.lmo 来自 feed 版定义的 luci-i18n-argon-config-zh-cn 包；
# 应用本体由构建系统的 OVERRIDE 机制自动用克隆版覆盖 feed 版（发布 .config 的
# CONFIG_OVERRIDE_PKGS 已含 luci-app-argon-config / luci-theme-argon）。
# 此前一版曾加过删除 feed 的两行，会导致主题设置页失去中文，已撤销。

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
# sirpdboy 核心包两处上游瑕疵，就地修正：
# 1) 其 Makefile 把版本注入写成 GO_PKG_LDFLAGS_X:=main.Version（大写 V），而
#    ddns-go 源码里变量是小写 main.version（默认 "DEV"），-X 注入落空，
#    二进制版本恒为 DEV：界面显示 vDEV、检查更新也无从比对。feed 版为小写，改回。
# 2) 自带默认配置 enabled '0'，但界面表单默认显示已启用，首次开机不点
#    「保存并应用」服务永不启动（界面恒显示未运行）。默认改为启用；
#    已保存过配置者升级时 conffiles 保留其配置，不受影响。
sed -i 's/GO_PKG_LDFLAGS_X:=main\.Version=/GO_PKG_LDFLAGS_X:=main.version=/' "$PACKAGE_DIR/ddns-go/Makefile"
# 3) 同一 Makefile 还多了一行 GO_PKG_LDFLAGS:=$(GO_PKG_LDFLAGS_X)（feed 版没有）：
#    golang-package.mk 拼的是「$(GO_PKG_LDFLAGS) + patsubst(-X, GO_PKG_LDFLAGS_X)」，
#    结果变成 -ldflags "main.version=6.17.7 -X main.version=6.17.7"，带头的裸 token
#    让链接器停在那里、后面的 -X 被丢弃——这就是只改大小写仍恒 DEV 的原因
#    （26.11.02 / 26.11.03 固件二进制均实证无版本号）。整行删掉，与 feed 版一致；
#    本地已按 golang-package.mk 公式模拟：删后 -ldflags 为干净的 "-X main.version=…"。
sed -i '/^GO_PKG_LDFLAGS:=$(GO_PKG_LDFLAGS_X)$/d' "$PACKAGE_DIR/ddns-go/Makefile"
# 4) 界面包「重置账户密码」按钮第一步要以 LuCI 会话执行 /usr/bin/ddns-go
#    -resetPassword，但其 rpcd ACL 只给了 init.d 等几个路径的 exec、漏了本体，
#    点了必报「没有权限」（2026-11-03 用户实机复现）。给 ACL 补上本体 exec；
#    本地已验证补后 JSON 合法。
sed -i 's#"/etc/init.d/ddns-go": \[ "exec" \],#&\n\t\t\t\t"/usr/bin/ddns-go": [ "exec" ],#' "$PACKAGE_DIR/luci-app-ddns-go/root/usr/share/rpcd/acl.d/luci-app-ddns-go.json"
sed -i "s/option enabled '0'/option enabled '1'/" "$PACKAGE_DIR/ddns-go/files/ddns-go.conf"
echo ">> 已修正 ddns-go 版本注入（main.version）与默认启用"
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
# 修复 iStore 本体中文目录缺失（实测发布固件里只有 iStore.zh-tw.lmo、无 zh-cn）：
# luci-app-store 的正式翻译在 src/po/zh-cn/iStore.po，但其 src/Makefile 的
# 安装循环直接用语言代码当目录名（zh_Hans），不走 luci.mk 的 zh-cn 别名映射，
# 导致简体目录永远生成不了。把该 po 复制一份到根 po/zh-cn/，让标准
# luci-i18n-store-zh-cn 包按 luci.mk 规则生成正确的 iStore.zh-cn.lmo。
if [ -f "$PACKAGE_DIR/luci-app-store/src/po/zh-cn/iStore.po" ]; then
	cp "$PACKAGE_DIR/luci-app-store/src/po/zh-cn/iStore.po" \
		"$PACKAGE_DIR/luci-app-store/po/zh-cn/iStore.po"
	echo ">> 已补入 iStore.po 到根 po/zh-cn（生成 iStore.zh-cn.lmo）"
fi
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

# ---------- 磁盘管理 Diskman（lisaac 官方源，原走 lede luci feed 旧版） ----------
# 与 dockerman 同为 lisaac 仓库群：根无 Makefile，提取 applications/luci-app-diskman；
# 依赖 parted/e2fsprogs/smartmontools/blkid 均由 lede packages feed 提供，无需额外处理。
rm -rf ./package/feeds/luci/applications/luci-app-diskman ./feeds/luci/applications/luci-app-diskman
clone_pkg luci-app-diskman-src lisaac/luci-app-diskman master
extract_dir "$PACKAGE_DIR/luci-app-diskman-src/applications/luci-app-diskman" luci-app-diskman
rm -rf "$PACKAGE_DIR/luci-app-diskman-src"
echo ">> 已用 lisaac 官方版 luci-app-diskman，并移除 lede feed 同名旧版"

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
# Makefile 里的 PKG_VERSION 写死，并按该版本下载 tarball / 预编译二进制。
# 上游发新版后，包装维护者不改版本就不会变新（lede feed 的包同理）。
# 处理：构建时查询上游 GitHub 最新 Release，自动升版本并把 hash 置 skip
# （lucky 上游本来就用 skip；hash 校验让位于版本自动跟随）。
# 原则：查询失败 / 限流 / tag 格式异常 / 联动数据缺失时，一律保留原版本
# 继续构建——追新失败绝不让构建失败（本脚本 set -e，函数全程防退出）。
# 已核实无需追新的包（2026-11-01 逐个查过 Makefile 与上游）：
#   dns2socks / shadowsocksr-libev：源码直接内嵌在包装仓库 src/ 里，构建不
#     下载，且上游已停发新版（2.1 / 2.5.6 即最终版）；
#   tcping / simple-obfs：git 包，其 PKG_SOURCE_VERSION 经 ls-remote 核对
#     就是上游 master 的 HEAD，上游已归档，本就是最新；
#   dockerd 之外的 feed 系统包（samba4/ttyd/mwan3 等）：上游就是 OpenWrt
#     本身，只能随 lede 更新，单独升版与系统库必然冲突，不做。

# 取某仓库最新 Release 的 tag；失败输出空
latest_tag() {
	local repo="$1" tag=""
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		tag=$(curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
			| sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)
	else
		tag=$(curl -fsSL -H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
			| sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)
	fi
	printf '%s' "$tag"
}

# 把文件里所有 64 位十六进制 hash（PKG_HASH / HASH / PKG_MIRROR_HASH）置 skip
skip_hashes() {
	sed -i -E 's/^([[:space:]]*(PKG_HASH|HASH|PKG_MIRROR_HASH):=)[0-9a-f]{64}/\1skip/' "$1"
}

# 通用追新：bump_latest <Makefile> <上游仓库> [tag 前缀，默认 v]
# 覆盖单 PKG_VERSION 型包（含多 hash 的 chinadns-ng、hysteria 的 app/v 前缀）。
# 若 Makefile 带 FRONTEND_VERSION（OpenList），同步升到同一版本。
bump_latest() {
	local mk="$1" upstream="$2" prefix="${3:-v}"
	local tag="" ver="" old=""
	if [ ! -f "$mk" ]; then
		echo ">> 追新跳过（Makefile 不存在）: $mk"
		return 0
	fi
	old=$(grep -m1 -oP '^PKG_VERSION:=\K.+' "$mk" 2>/dev/null || true)
	tag=$(latest_tag "$upstream")
	ver="$tag"
	if [ -n "$prefix" ] && [ "${ver#$prefix}" != "$ver" ]; then
		ver="${ver#$prefix}"
	elif [ "${ver#v}" != "$ver" ]; then
		ver="${ver#v}"
	fi
	if [ -z "$ver" ] || ! printf '%s' "$ver" | grep -qE '^[0-9][0-9A-Za-z._-]*$'; then
		echo ">> 追新跳过（未取到有效最新版，保留 $old）: $upstream"
		return 0
	fi
	if [ "$ver" = "$old" ]; then
		echo ">> 已是最新: $upstream $old"
		return 0
	fi
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$ver/" "$mk"
	skip_hashes "$mk"
	if grep -q '^FRONTEND_VERSION:=' "$mk"; then
		sed -i "s/^FRONTEND_VERSION:=.*/FRONTEND_VERSION:=$ver/" "$mk"
	fi
	echo ">> 已追新: $upstream $old -> $ver"
	return 0
}

# v2ray-geodata：GEOIP_VER / GEOSITE_VER 本身就是上游 release 的时间戳 tag
bump_geodata() {
	local mk="$PACKAGE_DIR/v2ray-geodata/Makefile" pair="" var="" repo="" tag="" old="" changed=0
	[ -f "$mk" ] || { echo ">> 追新跳过（geodata Makefile 不存在）"; return 0; }
	for pair in "GEOIP_VER Loyalsoldier/geoip" "GEOSITE_VER Loyalsoldier/v2ray-rules-dat"; do
		var="${pair%% *}"
		repo="${pair##* }"
		tag=$(latest_tag "$repo")
		old=$(grep -m1 -oP "^${var}:=\\K.+" "$mk" 2>/dev/null || true)
		if [ -z "$tag" ] || ! printf '%s' "$tag" | grep -qE '^[0-9]{12}$'; then
			echo ">> 追新跳过（未取到有效最新版，保留 $old）: $repo"
			continue
		fi
		if [ "$tag" = "$old" ]; then
			echo ">> 已是最新: $repo $old"
			continue
		fi
		sed -i "s/^${var}:=.*/${var}:=$tag/" "$mk"
		changed=1
		echo ">> 已追新: $repo $old -> $tag"
	done
	if [ "$changed" = "1" ]; then
		skip_hashes "$mk"
	fi
	return 0
}

# v2ray-geodata 预下载：geoip.dat / geosite.dat 只在该包 Build/Prepare 里经
# download.pl 现场下载（两个 Download 定义写在 Prepare 内部、未在顶层注册，
# make download 步根本不取这两个文件），而 dl/ 不在工作流缓存内、每轮全新。
# 一旦编译期 runner 到 GitHub Release 的连接假死，download.pl 的 curl 没有
# 速度下限会无限等——2026-11-05 定时构建就这样无声卡满 6 小时、被 GitHub
# 作业上限取消（run 41945159713）。故在源码安装阶段先按 Makefile 里的
# 版本/哈希把两个文件下进 dl/（连接超时 + 速度下限 + 单次总时长上限 +
# 重试）：prepare 时 download.pl 见文件在位且哈希对得上即跳过网络。
# 与其余追新函数不同，本函数在彻底失败时是刻意 exit 1 的——让故障在
# 开跑几分钟内显形，而不是无声吃满 6 小时；网络恢复后重跑即可。
predownload_geodata() {
	local mk="$PACKAGE_DIR/v2ray-geodata/Makefile" dl="./dl"
	local spec="" var="" repo="" blk="" ver="" urlfile="" hash="" file="" tmp="" attempt="" ok=""
	[ -f "$mk" ] || { echo ">> 预下载跳过（geodata Makefile 不存在）"; return 0; }
	mkdir -p "$dl"
	for spec in "GEOIP_VER Loyalsoldier/geoip geoip" "GEOSITE_VER Loyalsoldier/v2ray-rules-dat geosite"; do
		var="${spec%% *}"
		repo="$(printf '%s' "$spec" | cut -d' ' -f2)"
		blk="${spec##* }"
		ver=$(grep -m1 -oP "^${var}:=\K.+" "$mk" 2>/dev/null || true)
		urlfile=$(sed -n "/^define Download\/${blk}\$/,/^endef/p" "$mk" | grep -m1 -oP 'URL_FILE:=\K[^ \t]+' 2>/dev/null || true)
		hash=$(sed -n "/^define Download\/${blk}\$/,/^endef/p" "$mk" | grep -m1 -oP 'HASH:=\K[^ \t]+' 2>/dev/null || true)
		if [ -z "$ver" ] || [ -z "$urlfile" ]; then
			echo ">> 预下载跳过（${blk} 参数解析失败，保留编译期下载的原行为）"
			continue
		fi
		file="${urlfile}.${ver}"
		if [ -f "$dl/$file" ] && { [ -z "$hash" ] || [ "$hash" = "skip" ] || [ "$(sha256sum "$dl/$file" 2>/dev/null | cut -d' ' -f1)" = "$hash" ]; }; then
			echo ">> 已预下载（dl 在位）: $file"
			continue
		fi
		tmp="$dl/.${file}.tmp"
		ok=""
		for attempt in 1 2 3; do
			rm -f "$tmp"
			if curl -fL --connect-timeout 20 --speed-limit 10240 --speed-time 60 --max-time 240 \
				-o "$tmp" "https://github.com/${repo}/releases/download/${ver}/${urlfile}"; then
				if [ -z "$hash" ] || [ "$hash" = "skip" ] || [ "$(sha256sum "$tmp" 2>/dev/null | cut -d' ' -f1)" = "$hash" ]; then
					mv "$tmp" "$dl/$file"
					ok=1
					break
				fi
				echo ">> 预下载哈希不符（第 ${attempt} 次）: $file"
			else
				echo ">> 预下载失败（第 ${attempt} 次）: $file"
			fi
			sleep 5
		done
		rm -f "$tmp"
		if [ -z "$ok" ]; then
			echo ">> 预下载最终失败: $file（https://github.com/${repo}/releases/download/${ver}/${urlfile}）"
			echo ">> 立即终止构建，避免编译期 download.pl 无声卡满 6 小时；网络恢复后重跑即可。"
			exit 1
		fi
		echo ">> 已预下载: $file"
	done
	return 0
}

# naiveproxy：tag 形如 v154.0.8037.49-5，版本与 PKG_RELEASE 联动
bump_naiveproxy() {
	local mk="$PACKAGE_DIR/naiveproxy/Makefile" tag="" body="" rel="" old=""
	[ -f "$mk" ] || { echo ">> 追新跳过（naiveproxy Makefile 不存在）"; return 0; }
	old=$(grep -m1 -oP '^PKG_VERSION:=\K.+' "$mk" 2>/dev/null || true)
	tag=$(latest_tag klzgrad/naiveproxy)
	if ! printf '%s' "$tag" | grep -qE '^v[0-9.]+-[0-9]+$'; then
		echo ">> 追新跳过（未取到有效最新版，保留 $old）: klzgrad/naiveproxy"
		return 0
	fi
	body="${tag#v}"
	rel="${body##*-}"
	body="${body%-*}"
	if [ "$body" = "$old" ]; then
		echo ">> 已是最新: klzgrad/naiveproxy $old"
		return 0
	fi
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$body/" "$mk"
	sed -i "s/^PKG_RELEASE:=.*/PKG_RELEASE:=$rel/" "$mk"
	skip_hashes "$mk"
	echo ">> 已追新: klzgrad/naiveproxy $old -> $body-$rel"
	return 0
}

# smartdns：源码按 commit 打包，tag 形如 Release48.4，需把 tag 解析成 commit sha
bump_smartdns() {
	local mk="$PACKAGE_DIR/smartdns/Makefile" tag="" ver="" sha="" old=""
	[ -f "$mk" ] || { echo ">> 追新跳过（smartdns Makefile 不存在）"; return 0; }
	old=$(grep -m1 -oP '^PKG_VERSION:=\K.+' "$mk" 2>/dev/null || true)
	tag=$(latest_tag pymumu/smartdns)
	ver="${tag#Release}"
	if [ -z "$ver" ] || ! printf '%s' "$ver" | grep -qE '^[0-9][0-9.]*$'; then
		echo ">> 追新跳过（未取到有效最新版，保留 $old）: pymumu/smartdns"
		return 0
	fi
	if [ "$ver" = "$old" ]; then
		echo ">> 已是最新: pymumu/smartdns $old"
		return 0
	fi
	sha=$(git ls-remote https://github.com/pymumu/smartdns.git "refs/tags/$tag" "refs/tags/$tag^{}" 2>/dev/null | tail -1 | cut -f1 || true)
	if ! printf '%s' "$sha" | grep -qE '^[0-9a-f]{40}$'; then
		echo ">> 追新跳过（未取到 tag 对应 commit，保留 $old）: pymumu/smartdns"
		return 0
	fi
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$ver/" "$mk"
	sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$sha/" "$mk"
	skip_hashes "$mk"
	echo ">> 已追新: pymumu/smartdns $old -> $ver"
	return 0
}

# linkease / linkease-common-bin：版本写在 PKG_SOURCE_DATE，源码包来自
# istoreos/istoreos-app-hub 的 linkease-runtime-v<版本> 系列 tag（该仓库混发
# 多个应用，不能用 releases/latest，改用 ls-remote 按前缀取最大版本）
bump_linkease() {
	local ver="" f="" old=""
	ver=$(git ls-remote --tags --refs https://github.com/istoreos/istoreos-app-hub.git 2>/dev/null \
		| sed -n 's|.*refs/tags/linkease-runtime-v\([0-9][0-9.]*\)$|\1|p' | sort -Vu | tail -1 || true)
	if [ -z "$ver" ]; then
		echo ">> 追新跳过（未取到 linkease-runtime 最新版）"
		return 0
	fi
	for f in "$PACKAGE_DIR/linkease/Makefile" "$PACKAGE_DIR/linkease-common-bin/Makefile"; do
		[ -f "$f" ] || continue
		old=$(grep -m1 -oP '^PKG_SOURCE_DATE:=\K.+' "$f" 2>/dev/null || true)
		if [ "$ver" = "$old" ]; then
			echo ">> 已是最新: linkease-runtime $old"
			continue
		fi
		sed -i "s/^PKG_SOURCE_DATE:=.*/PKG_SOURCE_DATE:=$ver/" "$f"
		skip_hashes "$f"
		echo ">> 已追新: linkease-runtime $old -> $ver（${f##*/}）"
	done
	return 0
}

# Docker 全家桶联动追新（lede packages feed）：
# dockerd 构建时会自检——docker(CLI) 版本必须与 dockerd 相同、containerd /
# runc / tini 版本必须等于 moby 源码 Dockerfile 里 vendored 的版本、且两个
# 包的 PKG_GIT_SHORT_COMMIT 必须等于对应 tag 的短 commit。任一项单独升都会
# 被自检拦下报错，故整组一起升：先集齐全部数据并校验，缺任何一项整组不动。
bump_docker_stack() {
	local base="./feeds/packages/utils"
	local dockerd_mk="$base/dockerd/Makefile" docker_mk="$base/docker/Makefile"
	local containerd_mk="$base/containerd/Makefile" runc_mk="$base/runc/Makefile" tini_mk="$base/tini/Makefile"
	local tag="" ver="" old="" dfile="" cver="" rver="" tver="" dshort="" clishort="" told="" tsha=""
	[ -f "$dockerd_mk" ] || { echo ">> 追新跳过（dockerd Makefile 不存在）"; return 0; }
	old=$(grep -m1 -oP '^PKG_VERSION:=\K.+' "$dockerd_mk" 2>/dev/null || true)
	tag=$(latest_tag moby/moby)
	ver="${tag#docker-v}"
	if [ -z "$ver" ] || ! printf '%s' "$ver" | grep -qE '^[0-9][0-9.]*$'; then
		echo ">> 追新跳过（未取到 moby 最新版，保留 $old）"
		return 0
	fi
	if [ "$ver" = "$old" ]; then
		echo ">> 已是最新: moby/moby $old"
		return 0
	fi
	dfile=$(curl -fsSL "https://raw.githubusercontent.com/moby/moby/docker-v$ver/Dockerfile" 2>/dev/null || true)
	cver=$(printf '%s' "$dfile" | grep -m1 -oP 'CONTAINERD_VERSION=v\K[0-9.]+' || true)
	rver=$(printf '%s' "$dfile" | grep -m1 -oP 'RUNC_VERSION=v\K[0-9.]+' || true)
	tver=$(printf '%s' "$dfile" | grep -m1 -oP 'TINI_VERSION=v\K[0-9.]+' || true)
	dshort=$(git ls-remote https://github.com/moby/moby.git "refs/tags/docker-v$ver" "refs/tags/docker-v$ver^{}" 2>/dev/null | tail -1 | cut -f1 | cut -c1-7 || true)
	clishort=$(git ls-remote https://github.com/docker/cli.git "refs/tags/v$ver" "refs/tags/v$ver^{}" 2>/dev/null | tail -1 | cut -f1 | cut -c1-7 || true)
	told=$(grep -m1 -oP '^PKG_VERSION:=\K.+' "$tini_mk" 2>/dev/null || true)
	if [ "$tver" != "$told" ]; then
		tsha=$(git ls-remote https://github.com/krallin/tini.git "refs/tags/v$tver" "refs/tags/v$tver^{}" 2>/dev/null | tail -1 | cut -f1 || true)
	fi
	if [ -z "$cver" ] || [ -z "$rver" ] || [ -z "$tver" ] \
		|| ! printf '%s' "$dshort" | grep -qE '^[0-9a-f]{7}$' \
		|| ! printf '%s' "$clishort" | grep -qE '^[0-9a-f]{7}$' \
		|| { [ "$tver" != "$told" ] && ! printf '%s' "$tsha" | grep -qE '^[0-9a-f]{40}$'; }; then
		echo ">> 追新跳过（联动数据不齐：containerd=$cver runc=$rver tini=$tver，整组保留 $old）"
		return 0
	fi
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$ver/" "$dockerd_mk"
	sed -i "s/^PKG_GIT_SHORT_COMMIT:=.*/PKG_GIT_SHORT_COMMIT:=$dshort/" "$dockerd_mk"
	skip_hashes "$dockerd_mk"
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$ver/" "$docker_mk"
	sed -i "s/^PKG_GIT_SHORT_COMMIT:=.*/PKG_GIT_SHORT_COMMIT:=$clishort/" "$docker_mk"
	skip_hashes "$docker_mk"
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$cver/" "$containerd_mk"
	skip_hashes "$containerd_mk"
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$rver/" "$runc_mk"
	skip_hashes "$runc_mk"
	if [ "$tver" != "$told" ]; then
		sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$tver/" "$tini_mk"
		sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$tsha/" "$tini_mk"
		skip_hashes "$tini_mk"
	fi
	echo ">> 已追新: Docker 全家桶 dockerd/docker $old -> $ver（containerd $cver / runc $rver / tini $tver）"
	return 0
}

# ---------- 追新执行 ----------
bump_latest "$PACKAGE_DIR/lucky/Makefile" gdy666/lucky
bump_latest "$PACKAGE_DIR/ddns-go/Makefile" jeessy2/ddns-go
bump_latest "$PACKAGE_DIR/xray-core/Makefile" XTLS/Xray-core
bump_latest "$PACKAGE_DIR/sing-box/Makefile" SagerNet/sing-box
bump_latest "$PACKAGE_DIR/hysteria/Makefile" apernet/hysteria "app/v"
bump_latest "$PACKAGE_DIR/chinadns-ng/Makefile" zfl9/chinadns-ng ""
bump_latest "$PACKAGE_DIR/shadowsocks-rust/Makefile" shadowsocks/shadowsocks-rust
bump_latest "$PACKAGE_DIR/shadow-tls/Makefile" ihciah/shadow-tls
bump_latest "$PACKAGE_DIR/geoview/Makefile" snowie2000/geoview ""
bump_latest "$PACKAGE_DIR/v2ray-plugin/Makefile" teddysun/v2ray-plugin
bump_latest "$PACKAGE_DIR/xray-plugin/Makefile" teddysun/xray-plugin
bump_latest "$PACKAGE_DIR/microsocks/Makefile" rofl0r/microsocks
bump_latest "$PACKAGE_DIR/ipt2socks/Makefile" zfl9/ipt2socks
bump_geodata
bump_naiveproxy
bump_smartdns
bump_linkease
# OpenList 本体走 lede packages feed，直接对 feed 的 Makefile 追新（FRONTEND_VERSION 由 bump_latest 同步）
bump_latest "./feeds/packages/net/openlist/Makefile" OpenListTeam/OpenList
# Docker 全家桶联动追新暂时停用（2026-11-01）：验证构建 run 41226023294 中
# containerd 升到 2.4.2 后编译失败（go:embed 资源文件缺失：
# pattern autocomplete / markdown.md.gotmpl: no matching files found），
# 故 Docker 暂随 feed 版本（29.6.1 全家桶）。函数保留，待适配后再启用。
# bump_docker_stack

# v2ray-geodata 的 geoip.dat / geosite.dat 预下载进 dl/（须在 bump_geodata
# 之后执行，读到的才是最终版本/哈希；失败会立即终止构建，见函数注释）
predownload_geodata

echo "=================================================="
echo ">> 全部插件源码安装完成"
