#!/bin/bash
# SPDX-License-Identifier: MIT
# OpenWRT-CI-X86 源码级补丁
#
# 1. x86 内核启用 BBR（lede 默认未开启，内核自带最新 BBR）
# 2. TurboACC 默认 TCP 拥塞算法改为 bbr
# 3. 默认主题切换为 Argon
# 4. 默认 LAN 地址 / 主机名
# 5. LuCI 状态页追加编译日期标识
#
# 依赖环境变量：WRT_THEME / WRT_NAME / WRT_IP / WRT_MARK / WRT_DATE
set -e

# ---------- 1. x86 内核启用 BBR ----------
KVER=$(grep -m1 -oP '^KERNEL_PATCHVER:=\K.*' ./target/linux/x86/Makefile 2>/dev/null || true)
KCFG="./target/linux/x86/config-$KVER"
if [ -n "$KVER" ] && [ -f "$KCFG" ]; then
	sed -i '/^CONFIG_TCP_CONG_BBR/d; /^CONFIG_DEFAULT_TCP_CONG/d' "$KCFG"
	printf 'CONFIG_TCP_CONG_BBR=y\nCONFIG_DEFAULT_TCP_CONG="bbr"\n' >> "$KCFG"
	echo ">> 内核 $KVER: 已启用 TCP BBR 并设为默认拥塞算法"
else
	echo "!! 未找到 x86 内核配置（$KCFG），跳过 BBR 补丁"
fi

# ---------- 2. TurboACC 默认拥塞算法 ----------
TUCFG=$(find ./feeds/luci/applications/luci-app-turboacc/root/etc/uci-defaults/ -type f 2>/dev/null | head -1)
if [ -n "$TUCFG" ]; then
	sed -i "s/option tcpcca 'cubic'/option tcpcca 'bbr'/" "$TUCFG"
	echo ">> TurboACC 默认 TCP 拥塞算法已设为 bbr"
else
	echo "!! 未找到 TurboACC uci-defaults，跳过"
fi

# ---------- 3. 默认主题 ----------
for MF in $(find ./feeds/luci/collections/ -maxdepth 1 -name "Makefile"); do
	sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" "$MF"
done
echo ">> 默认主题已切换为 $WRT_THEME"

# ---------- 4. 默认 LAN 地址 / 主机名 ----------
CFG_GEN="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_GEN" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_GEN"
	sed -i "s/hostname='[^']*'/hostname='$WRT_NAME'/" "$CFG_GEN"
	echo ">> 默认 LAN 地址=$WRT_IP 主机名=$WRT_NAME"
else
	echo "!! 未找到 config_generate，跳过"
fi

# 同步修改 LuCI 恢复页中的默认地址提示
FLASH_JS=$(find ./feeds/luci/modules/luci-mod-system -name "flash.js" | head -1)
if [ -n "$FLASH_JS" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$FLASH_JS"
	echo ">> LuCI 恢复页默认地址已同步为 $WRT_IP"
fi

# ---------- 5. LuCI 状态页编译日期标识 ----------
SYSJS=$(find ./feeds/luci/modules/luci-mod-status -name "10_system.js" | head -1)
if [ -n "$SYSJS" ]; then
	sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/" "$SYSJS" || true
	echo ">> 已写入编译日期标识 $WRT_MARK-$WRT_DATE"
fi

# ---------- 6. 升级 dnsmasq 到 2.92（PassWall 要求 >=2.92） ----------
# 仅当 lede 仍为 2.91 时才需要手动升。lede 自 2026-10-15 起自带 2.93：
# 此时版本 sed 不再匹配、只剩哈希 sed 生效，会把 2.93 的 Makefile 盖上
# 2.92 的哈希，造成下载校验永久不匹配（2026-10-18 起连环构建失败的根因）。
# 因此两个 sed 必须绑在同一个版本判断里，要么一起执行，要么都不动。
DNSMASQ_MAKE="./package/network/services/dnsmasq/Makefile"
if [ -f "$DNSMASQ_MAKE" ]; then
	if grep -q 'PKG_UPSTREAM_VERSION:=2.91' "$DNSMASQ_MAKE"; then
		sed -i 's/PKG_UPSTREAM_VERSION:=2.91/PKG_UPSTREAM_VERSION:=2.92/' "$DNSMASQ_MAKE"
		sed -i 's|PKG_HASH:=.*|PKG_HASH:=4bf50c2c1018f9fbc26037df51b90ecea0cb73d46162846763b92df0d6c3a458|' "$DNSMASQ_MAKE"
		echo ">> dnsmasq 已升级到 2.92"
	else
		echo ">> lede 自带 dnsmasq 已 >=2.92，跳过手动升级"
	fi
else
	echo "!! 未找到 dnsmasq Makefile，跳过"
fi

# ---------- 7. 顶级菜单重排（用户指定顺序） ----------
# 目标顺序: 状态10 系统20 iStore30 Docker40 服务50 网络存储60 Control70 网络80 统计90 退出999
# Docker40 由 lisaac/luci-app-dockerman 的 controller 原生注册（admin/docker, order 40），无需补丁
python3 - <<'EOF'
import json

# luci-base: services 30->50, nas 40->60, vpn 50->70, network 60->80
p = "./feeds/luci/modules/luci-base/root/usr/share/luci/menu.d/luci-base.json"
d = json.load(open(p))
d["admin/services"]["order"] = 50
d["admin/nas"]["order"] = 60
d["admin/vpn"]["order"] = 70
d["admin/network"]["order"] = 80
json.dump(d, open(p, "w"), indent="\t")

# statistics: 80->90
p = "./feeds/luci/applications/luci-app-statistics/root/usr/share/luci/menu.d/luci-app-statistics.json"
d = json.load(open(p))
d["admin/statistics"]["order"] = 90
json.dump(d, open(p, "w"), indent="\t")
EOF

# iStore (store.lua): 31->30
sed -i 's/call("redirect_index"), _("iStore"), 31/call("redirect_index"), _("iStore"), 30/' \
	./package/luci-app-store/luasrc/controller/store.lua

# Control (eqosplus.lua): 44->70
sed -i 's/firstchild(), "Control", 44/firstchild(), "Control", 70/' \
	./package/luci-app-eqosplus/luasrc/controller/eqosplus.lua

# ---------- 8b. 修复 lua controller 覆盖 admin/nas 分组 order 的问题 ----------
# 问题: LuCI 新版加载顺序为 先 menu.d/*.json 后 controller/*.lua，后加载的 lua 会覆盖 json 里的 order。
#       luci-app-vsftpd 等包的 controller 里硬编码 entry({"admin","nas"}, firstchild(), "NAS", 44/45)，
#       把上面 python 刚设好的 admin/nas order=60 覆盖成 44，导致网络存储(44) 跑到服务(50) 前面。
# 修复: 全量扫描 feeds/luci 与 package/ 下所有 controller lua，把 nas 分组 firstchild 的 order 统一刷成 60。
NAS_CTRLS=$(grep -rlE 'entry\(\{"admin", *"nas"\}, *firstchild' \
	./feeds/luci/applications ./feeds/luci/modules ./package 2>/dev/null \
	| grep '/luasrc/controller/.*\.lua$' || true)
if [ -n "$NAS_CTRLS" ]; then
	for F in $NAS_CTRLS; do
		sed -i -E 's/(entry\(\{"admin", *"nas"\}, *firstchild\(\),[^,]*), *[0-9]+/\1, 60/' "$F"
		echo ">> 修复 nas 分组 order -> 60: ${F#./}"
	done
else
	echo ">> 未发现 lua controller 注册 nas 分组，跳过"
fi

echo ">> 顶级菜单已重排: 状态10 系统20 iStore30 Docker40 服务50 网络存储60 Control70 网络80 统计90 退出999"

# ---------- 9. Watchcat 默认配置安全化（防止"刷机后无限重启"） ----------
# 问题: lede feed 自带默认 mode=ping_reboot + pinghosts=8.8.8.8 + forcedelay=30,
#      且 init 无 enable 开关(默认启用)。刷机后 WAN 未就绪(未配 PPPoE/拨号慢/升级
#      保留配置网络恢复慢)时, 开机约 30 秒 ping 不通 8.8.8.8 即触发 reboot -> 无限重启循环。
# 修复: 默认改为 ping 内网网关(10.0.1.1, 路由器自身, 仅系统卡死才触发) + 延迟 600s,
#      外网监测由用户在界面按需改回(如 8.8.8.8)。
WC_CFG=$(find ./feeds/packages/utils/watchcat/files -name "watchcat.config" 2>/dev/null | head -1)
if [ -n "$WC_CFG" ]; then
	cat > "$WC_CFG" <<'WCCFG'
config watchcat
	option period '1d'
	option mode 'ping_reboot'
	option pinghosts '10.0.1.1'
	option forcedelay '600'
WCCFG
	echo ">> Watchcat 默认配置已安全化（ping 内网网关 10.0.1.1 / 延迟 600s，防重启循环）"
else
	echo "!! 未找到 watchcat.config，跳过安全化补丁"
fi

# ---------- 10. 修复 linkease-common-bin 上游 CONTROL hack 导致编译失败 ----------
# 问题: linkease/nas-packages 上游最近在 linkease-common-bin/Makefile 末尾加了一段
#       递归变量覆盖 CONTROL 的 hack（用于 OpenWrt 24.10 追加 Replaces 字段），
#       该写法在 lede openwrt-25.12 构建系统上 make 解析即报错（1 秒失败）。
# 修复: 直接删掉这段不兼容的 CONTROL 覆盖块（全新安装不需要从旧版 linkease 迁移的 Replaces）。
LE_MAKE="./package/linkease-common-bin/Makefile"
if [ -f "$LE_MAKE" ] && grep -q "LINKEASE_COMMON_BIN_GENERATED_CONTROL" "$LE_MAKE"; then
	# 从 "# OpenWrt 24.10 does not expose" 这行注释开始，删到文件末尾
	sed -i '/^# OpenWrt 24.10 does not expose/,$d' "$LE_MAKE"
	echo ">> 已移除 linkease-common-bin 不兼容的 CONTROL hack（上游 24.10 补丁在 25.12 报错）"
else
	echo ">> linkease-common-bin Makefile 无 CONTROL hack 或不存在，跳过"
fi

# 修复: 上游 v1.7.6 release 包打错了——tar.gz 内顶层目录名仍是 1.7.5，
# install 段按 $(PKG_BUILD_DIR)/heif-converter 找文件时多嵌套一层目录而失败。
# 用 find 在 install 时动态定位文件实际路径，不依赖目录名。
sed -i \
	-e 's#\$(PKG_BUILD_DIR)/heif-converter#`find $(PKG_BUILD_DIR) -name heif-converter -type f | head -1`#g' \
	-e 's#\$(PKG_BUILD_DIR)/linkease-media#`find $(PKG_BUILD_DIR) -name linkease-media -type f | head -1`#g' \
	"$LE_MAKE"
echo ">> 已修改 linkease-common-bin install 段用 find 动态定位文件"

echo ">> 全部补丁应用完成"
