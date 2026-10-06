# RMX5080 · GKI 6.6.118 · SukiSU-Ultra (built-in) + SUSFS

为 **realme Neo7 SE (RMX5080 / MT6899 / Dimensity 8400-Max)** 构建的 AnyKernel3 刷机包。
内核侧 **内置** KernelSU 与 SUSFS（不是 LKM 注入模式）。

---

## 一、目标设备实测参数

| 项目 | 实测值 |
|---|---|
| 型号 | realme RMX5080 (Neo7 SE)，MT6899 |
| 系统 | Android 16 / realme UI 7.0，`V.29b902b-480ceb-4d8eea` |
| 内核 | `6.6.118-android15-8-ge58033dc8ea6-abogki498046332-4k` |
| KMI | `android15-6.6`，`KMI_GENERATION=8` |
| 页大小 | 4K (`CONFIG_ARM64_4K_PAGES=y`，`CONFIG_LOCALVERSION="-4k"`) |
| 编译器 | AOSP clang `r510928` (18.0.0)，`CONFIG_LTO_NONE=y`，`CONFIG_CFI_CLANG=y` |
| 内核位置 | `boot` 分区（`boot_a`，仅内核镜像，无 ramdisk） |
| 当前 root | SukiSU-Ultra **v4.2.0**，LKM 注入在 `init_boot` 的 ramdisk |

## 二、为什么这样选（都是实测结论，不是猜的）

### 1. 内核源码：Google GKI `android15-6.6-2026-01`

realme 官方只公开了 RMX5080 的 **6.6.89** 源码（realme UI 7.0 早期快照），
拿不到 6.6.118。所以改用 Google 官方 GKI 源码：

```
android15-6.6-2025-10 → 6.6.102
android15-6.6-2026-01 → 6.6.118   ← 与本机完全一致
android15-6.6-2026-04 → 6.6.127
```

`android15-6.6-2026-01` 的 `KMI_GENERATION=8`、`CONFIG_LOCALVERSION="-4k"`、`CLANG_VERSION=r510928`
三项全部与设备匹配。

### 2. 符号 CRC 兼容性：已数学级验证 ✅

对比 realme 官方树的 `android/abi_gki_aarch64.stg` 与 Google 2026-01 的同一文件，
逐符号比对 `crc` 字段：

| 指标 | 结果 |
|---|---|
| realme 导出符号总数 | 8,962 |
| Google 导出符号总数 | 9,312 |
| realme 有、Google 没有的符号 | **0** |
| 共有符号中 **CRC 不一致** 的个数 | **0** |

即：Google 官方 GKI 6.6.118 的内核 **导出符号集合是 realme 的超集，且所有共有符号 CRC 完全相同**。
所以原厂 `vendor_dlkm` 模块可以正常加载。

### 3. Root：SukiSU-Ultra `builtin` 分支

- 设备管理器是 `com.sukisu.ultra` **v4.2.0**（`ksud 4.2.0-1-g904c60d1`, uapi 2）。
- 因此把 SukiSU 固定到 `builtin` 分支上 v4.2.0 之后的提交 `b20dee7020`，与你的管理器对齐。
- 必须用 **`builtin` 分支**：只有它自带 SUSFS 的 KSU 侧胶水
  （`kernel/Kconfig` 里有 `config KSU_SUSFS`，`kernel/Makefile` 会检测 `fs/susfs.c`）。
  `main`/`dev` 分支没有，需要额外打 `10_enable_susfs_for_ksu.patch`，而该补丁目前打不上 v4.2.0。

### 4. SUSFS：`gki-android15-6.6` (v2.3.0)

核心侧只需投放三个文件 + 一个补丁：
`fs/susfs.c`、`include/linux/susfs.h`、`include/linux/susfs_def.h`，
再打 `50_add_susfs_in_gki-android15-6.6.patch`。

### 5. 关于 `init_boot` 里的 LKM —— 不用管

`init_boot` 的 ramdisk 里被 SukiSU 注入了 `init`（包装器）、`init.real`、`kernelsu.ko`。
该包装器内含字符串：

```
KernelSU may be already loaded in kernel, skip!
```

刷入内置 KSU 的内核后，它会**检测到内核已有 KernelSU 并自动跳过 insmod**，然后 exec `/init.real`。
所以 **不需要** 卸载或还原 `init_boot`。

## 三、使用方法

1. 在 GitHub 上新建一个**空仓库**，把本目录推上去（`main` 分支）。
2. `Actions` → `Build RMX5080 GKI 6.6.118 (SukiSU-Ultra built-in + SUSFS)` → `Run workflow`。
   默认参数即可，无需改动。
3. 等约 40–90 分钟（含 ccache 的再次构建会快很多）。
4. 在 run 的 Artifacts 里下载
   `RMX5080-GKI-6.6.118-SukiSU-SUSFS-AnyKernel3.zip`
   （勾了 `create_release` 时也会出现在 Releases 里）。

编译过程会自动校验：内核必须是 **6.6.118**、`KMI_GENERATION=8`、`LOCALVERSION=-4k`，
任何一项不符会直接失败，不会产出错误的包。

## 四、刷入

> ⚠️ 刷内核有风险。刷前请确认已备份原厂 `boot` / `init_boot`。

用支持 AnyKernel3 的刷入器（**Kernel Flasher** / HorizonKernelFlasher / EX Kernel Manager），
选择下载到的 zip 刷入即可。它会解包当前 `boot`，替换内核镜像，重新打包写回 `boot`。

刷完重启后验证：

```bash
adb shell su -c 'uname -r'            # 应显示 6.6.118-...
adb shell su -c 'ls /sys/module/' | grep -i susfs
adb shell su -c '/data/adb/ksu/bin/ksud susfs status'    # 应为 true
adb shell su -c '/data/adb/ksu/bin/ksud susfs version'   # 应为 v2.3.0
```

### 回滚

原厂 `boot` 备份：
```bash
adb shell su -c 'dd if=/sdcard/boot_a.img of=/dev/block/by-name/boot_a'
```
（把备份好的 `boot_a.img` 推回手机；或直接用 `ksud boot-restore`）

## 五、可调参数

| 输入 | 默认 | 说明 |
|---|---|---|
| `gki_branch` | `common-android15-6.6-2026-01` | AOSP 清单分支，= 6.6.118 |
| `ksu_ref` | `b20dee7020` | SukiSU-Ultra `builtin` 分支上的提交（对应 v4.2.0） |
| `susfs_branch` | `gki-android15-6.6` | SUSFS 分支（v2.3.0） |
| `susfs_commit` | 空 | 固定 SUSFS 提交 |
| `lto` | `thin` | `thin` 或 `none`（出厂是 `none`） |
| `create_release` | true | 是否创建 Release |

## 六、来源与致谢

- [Google AOSP kernel/common](https://android.googlesource.com/kernel/common) — GKI 源码
- [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) — KernelSU 分支
- [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS（GitHub 镜像 `ShirkNeko/susfs4ksu`）
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3)（模板 `WildPlusKernel/AnyKernel3` gki-2.0）
