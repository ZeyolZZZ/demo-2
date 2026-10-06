#!/bin/bash
# 刷入后验证 SUSFS + 内置 KernelSU 是否生效
# 用法: bash verify-after-flash.sh
set -u
S() { adb shell "su -c '$1'" 2>&1; }

echo "============================== 1. 内核版本 =============================="
S 'uname -r'
echo "--- 期望: 6.6.118-... (含 -4k) ---"

echo
echo "============================== 2. KSU 是否为内置 =============================="
echo "--- /proc/modules 里不应再有独立加载的 kernelsu 模块 (内置的不显示) ---"
S 'grep -i kernelsu /proc/modules || echo "  (无 kernelsu 模块 => 内置模式 ✓)"'
echo "--- ksud 版本 (uapi 必须与管理器一致) ---"
S '/data/adb/ksud -V'

echo
echo "============================== 3. SUSFS 状态 =============================="
echo "--- status (期望 true) ---";        S '/data/adb/ksud susfs status'
echo "--- version (期望 v2.3.0) ---";     S '/data/adb/ksud susfs version'
echo "--- variant ---";                   S '/data/adb/ksud susfs variant'
echo "--- features ---";                  S '/data/adb/ksud susfs features'

echo
echo "============================== 4. 内核 KMI 校验 =============================="
echo "--- 期望: android15-6.6 / KMI 8 / 4K 页 ---"
S 'getconf PAGE_SIZE'
S '/data/adb/ksud boot-info current-kmi'
S '/data/adb/ksud boot-info supported-kmis'

echo
echo "============================== 5. 原厂 vendor 模块是否正常 =============================="
echo "--- 随机抽查几个 MTK 模块是否已加载 ---"
for m in bt_drv_6899 mtk_rpmsg_mbox apusys; do
  printf "  %-24s " "$m"
  S "grep -c '^$m ' /proc/modules" | tr -d '\r'
done
echo "--- 已加载模块总数 ---"; S 'wc -l < /proc/modules'

echo
echo "============================== 6. 结论 =============================="
echo "若上面 susfs status=true 且 version=v2.3.0, 且 vendor 模块都在, 则刷入成功。"
echo "若开不了机/卡 logo, 用备份的 boot_a.img 回滚:"
echo "  adb shell su -c 'dd if=/sdcard/boot_a.img of=/dev/block/by-name/boot_a'"
