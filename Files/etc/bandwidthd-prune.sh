#!/bin/sh
# 删除 bandwidthd CDF 数据中 13 个月（395 天）以前的记录行（用户定的保留期）。
# CDF 每行第 2 列为 unix 时间戳。守护进程运行中会持续追加写这些文件，
# 故先停服务、等进程退出后再逐个过滤，完后重启（每周一凌晨执行一次，
# 中断仅数秒）。数据目录 /mnt/sdb2/tongji 由 packages.sh 给 feed 的
# bandwidthd init 打补丁而来。
DIR=/mnt/sdb2/tongji
[ -d "$DIR" ] || exit 0
CUT=$(( $(date +%s) - 395 * 86400 ))

/etc/init.d/bandwidthd stop
for i in 1 2 3 4 5; do
	pidof bandwidthd >/dev/null 2>&1 || break
	sleep 1
done

for f in "$DIR"/log.*.cdf; do
	[ -f "$f" ] || continue
	awk -F, -v cut="$CUT" '$2 >= cut' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

/etc/init.d/bandwidthd start
exit 0
