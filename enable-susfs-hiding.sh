#!/bin/bash
# 启用 SUSFS 实际隐藏效果 —— 引导式脚本
#
# 背景: SUSFS 只是"机制"。要让隐藏真正生效, 必须有"执行者"(susfs4ksu 模块)
#       在开机时调用 ksu_susfs, 把"目标"(sus_path.txt / config.sh 等)注册进内核。
#
# 本脚本只做检查 + 打印指引, 不会擅自改你的系统。要执行哪一步由你决定。
#
# 用法: bash enable-susfs-hiding.sh

S() { adb shell "su -c '$1'" 2>&1; }
hr() { echo "------------------------------------------------------------"; }

echo "==================== 1. 内核侧: SUSFS 是否就绪 ===================="
KREL=$(adb shell 'uname -r' 2>&1 | tr -d '\r')
echo "内核: $KREL"
case "$KREL" in
  6.6.118*) echo "  ✅ 是我们的构建" ;;
  *)        echo "  ⚠️  不是预期内核 (期望 6.6.118-...)" ;;
esac
echo "SUSFS status : $(S '/data/adb/ksud susfs status')"
echo "SUSFS version: $(S '/data/adb/ksud susfs version')"
echo "SUSFS variant: $(S '/data/adb/ksud susfs variant')"
hr
echo "已编入的 SUSFS 功能:"
S '/data/adb/abk/susfs/bin/ksu_susfs show enabled_features' | sed 's/^/  /'
echo
echo "关键: SUS_PATH 必须在上面列表里, 否则 add_sus_path 无效。"
echo "      (Run #10 的包才带 SUS_PATH; 之前的包是 n)"

hr
echo "==================== 2. 用户态: 执行者(susfs4ksu 模块) ===================="
MOD=$(S '/data/adb/ksud susfs module status')
echo "模块状态: $MOD"
if echo "$MOD" | grep -qi "not installed"; then
  echo
  echo "  ❌ 模块未安装 —— 这就是「没有任何隐藏效果」的直接原因!"
  echo "     没有它, config.sh / sus_path.txt / sus_mount.txt 全都不会被执行。"
  echo
  echo "  安装方式(二选一, 重启后生效):"
  echo "    A) 用 ksud 自带安装器:"
  echo "         adb shell su -c '/data/adb/ksud susfs module install'"
  echo "    B) 用 SukiSU 管理器刷入我给你打包的 susfs4ksu-module-v2.3.0.zip"
  echo "       (官方模块, 与内核里的 SUSFS 核心补丁同为 commit a0f9c59)"
else
  echo "  ✅ 模块已安装"
fi

hr
echo "==================== 3. 配置: 要隐藏什么 ===================="
echo "持久化配置 (ksud susfs config):"
S '/data/adb/ksud susfs config list' | sed 's/^/  /' | head -20
echo "  (空 = 没有任何持久化配置)"
echo
echo "susfs4ksu 数据目录:"
S 'ls -1 /data/adb/susfs4ksu/ 2>/dev/null' | sed 's/^/  /'
echo
echo "sus_path.txt 当前内容:"
S 'grep -v "^#" /data/adb/susfs4ksu/sus_path.txt 2>/dev/null | grep -v "^$"' | sed 's/^/  /'
echo "  (只有 # 注释 = 没有配置任何要隐藏的路径)"

hr
echo "==================== 4. 建议的下一步 ===================="
cat <<'TIP'
1) 刷 Run #10 的新内核 (带 CONFIG_KSU_SUSFS_SUS_PATH=y)

2) 安装 susfs4ksu 模块 (见上面第 2 步)

3) 填要隐藏的路径, 例如:
     adb shell su -c 'echo "/system/addon.d 1" >> /data/adb/susfs4ksu/sus_path.txt'
     adb shell su -c 'echo "/vendor/bin/install-recovery.sh 1" >> /data/adb/susfs4ksu/sus_path.txt'

4) 检查/调整 /data/adb/susfs4ksu/config.sh, 常用项:
     hide_revanced=1                        隐藏 ReVanced 相关
     hide_loops=1                           隐藏 loop 挂载
     spoof_cmdline=1                        伪造 /proc/bootconfig
     force_hide_lsposed=1                   隐藏 LSPosed
     hide_sus_mnts_for_all_or_non_su_procs=1 对非 su 进程隐藏 SUS 挂载
     spoof_uname=0                          改成 1 可伪造 uname(注意: 会骗过所有 App)

5) 重启, 然后验证:
     adb shell su -c '/data/adb/abk/susfs/bin/ksu_susfs show enabled_features'
     adb shell su -c '/data/adb/ksud susfs config list'
     adb shell su -c 'ls /proc/1/mountinfo'   # 看 KSU/SUSFS 痕迹是否还在

⚠️ 提示: 隐藏策略越激进, 越容易让某些 App 异常(闪退/检测到环境异常)。
   建议先只开 hide_sus_mnts + spoof_cmdline, 逐项加, 每加一项重启验证。
TIP
