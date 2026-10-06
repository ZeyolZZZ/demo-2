### AnyKernel3 Ramdisk Mod Script
## 基于 osm0sis @ xda-developers 的 AnyKernel3 (gki-2.0)
## 目标: realme Neo7 SE RMX5080 (GKI android15-6.6, 内核镜像位于 boot 分区)

### AnyKernel setup
properties() { '
kernel.string=RMX5080 GKI 6.6.118 | SukiSU-Ultra built-in + SUSFS v2.3.0
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
do.check_boot_version=0
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
keycheck.timeout=10
'; } # end properties


### AnyKernel install
## boot shell variables
block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto
no_magisk_check=1

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh

# ---- GKI 校验 ----
kernel_version=$(cat /proc/version | awk -F '-' '{print $1}' | awk '{print $3}')
case $kernel_version in
    5.10*|5.15*|6.1*|6.6*|6.12*) ;;
    *) abort "  -> 非 GKI 设备 (当前 $kernel_version), 已中止。" ;;
esac

ui_print " "
ui_print "  RMX5080 / MT6899  GKI android15-6.6"
ui_print "  内核基础版本: 6.6.118"
ui_print "  Root: SukiSU-Ultra (built-in)  |  SUSFS v2.3.0"
ui_print " "

# ---- 写入 boot ----
# 本机型 boot 分区只含内核镜像 (无 ramdisk), 走 flash_boot 分支
split_boot

if [ -f "$SPLITIMG/ramdisk.cpio" ]; then
    unpack_ramdisk
    write_boot
else
    flash_boot
fi

ui_print " "
ui_print "  刷入完成。重启后内置 KernelSU 生效。"
ui_print "  init_boot 里的 LKM 会自动跳过, 无需处理。"
ui_print " "
