---
title: "重启之后，我的 Ubuntu 远程桌面全挂了，只剩 SSH 还活着"
description: "HWE 内核缺 NVIDIA 模块、无显示器无画面、分辨率锁死 4:3，附 Xorg headless 配置和 RustDesk 一键升级脚本。"
type: article
tags:
  - 若白知行
  - 器·工具志
date: 2026-10-12
status: published
platform: 公众号
seq: 9
---

![Image 1](https://maxcdn.hjhblr.com/blog/posts/2026-10-12-ubuntu-rustdesk/01.webp)

> 一台放在机房角落、不接显示器的 Ubuntu 24.04 桌面机，平时靠 RustDesk 和 3389 远程桌面使用。某天重启之后，两条路同时断了，只剩 SSH 还活着。
>
> 这篇文章复盘整个过程：从"远程桌面连不上"一路追到"内核升级后 NVIDIA 模块缺失"，再到"没有显示器导致 RustDesk 无画面"和"分辨率被锁在 4:3"。每一步都给出可直接复制的命令和判断依据。

---

## 一、现象：SSH 正常，图形远程全部失效

环境：

- Ubuntu 24.04.4 桌面版，GNOME + GDM
- 显卡 NVIDIA RTX 3060（GA106），**不接显示器**，只插着一根 HDMI 线，线的另一头是空的
- 远程方式：RustDesk（自建中继）、GNOME 自带远程桌面（RDP 3389）、SSH

重启之后：

- RustDesk 能连上 ID，但没有画面
- 3389 端口直接连不上
- SSH 一切正常

**两种完全不同的远程桌面同时失效，而 SSH 正常**，这个组合本身就是线索：问题不在网络，也不在某个远程软件，而在它们共同依赖的东西，也就是**图形会话**。

---

## 二、排查：在 SSH 里确认图形栈是否活着

### 1. 先看有没有图形会话

```bash
loginctl list-sessions
```

正常情况下，即使没人登录，也应该能看到一个 `gdm` 用户的会话，也就是登录界面。当时的输出里**只有我自己的 SSH 会话**，连登录界面都没有。

这一步把问题范围从"没人登录"缩小到了"图形界面根本没起来"。

### 2. RustDesk 的日志印证了这一点

```bash
systemctl status rustdesk
```

服务本身在运行，但日志里反复出现：

```
rustdesk[...]: cannot open display: :0
```

RustDesk 先尝试以 gdm 身份抓屏，再尝试以普通用户身份抓屏，都打不开 `:0`。原因很简单：X Server 不存在。

### 3. 去 GDM 日志里找根因

```bash
journalctl -b -u gdm3 --no-pager | tail -40
```

关键的三行：

```
gdm3: modprobe: FATAL: Module nvidia not found in directory /lib/modules/7.0.0-38-generic
Gdm: GdmDisplay: Session never registered, failing
Gdm: GdmLocalDisplayFactory: maximum number of X display failures reached
```

真相大白：**内核被升级到了 7.0.0-38（HWE 内核），但这个内核下没有对应的 NVIDIA 模块**。Xorg 起不来，GDM 重试几次之后放弃。没有图形会话，RustDesk 无屏可抓，3389 也无从监听。

`nvidia-smi` 也给出了同样的结论：

```
NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver.
```

### 4. 为什么内核升级会"弄丢"显卡驱动

`dkms status` 提示命令不存在，说明这台机器**没有用 DKMS**，而是用 Ubuntu 预编译的驱动模块包：

```
linux-modules-nvidia-<驱动版本>-<内核版本>
```

这类包**和具体内核版本绑定**。如果只装了针对某个旧内核的模块包，没有装对应的 HWE 元包，那么内核一升级，新内核下就没有 nvidia.ko。

`/lib/modules/` 下面已经堆了十几个内核版本，6.17 系列和 7.0 系列都有。这也说明 HWE 内核一直在自动滚动升级，问题迟早会出现。

---

## 三、修复一：给新内核补上 NVIDIA 驱动

```bash
sudo apt update
sudo ubuntu-drivers install
```

`ubuntu-drivers` 会为当前内核选择合适的驱动。这次装上的是：

- `nvidia-driver-595-open`
- `linux-modules-nvidia-595-open-7.0.0-38-generic`
- `linux-modules-nvidia-595-open-generic-hwe-24.04`

**第三个包是关键。** 它是 HWE 元包，以后内核升级时会自动拉取匹配的 NVIDIA 模块，从根上杜绝这次的问题。

如果你的机器是手动装的驱动，建议检查一下有没有这个元包：

```bash
dpkg -l | grep -E 'nvidia-driver|linux-modules-nvidia' | awk '{print $2, $3}'
```

验证：

```bash
sudo modprobe nvidia && nvidia-smi
```

一个小插曲：`modprobe` 刚执行完时，`nvidia-smi` 仍然报连不上驱动。查了 `lsmod`、`modinfo` 和 `dmesg`，模块版本一致（595.99.02），Secure Boot 也是关闭的，一切正常。过了几秒再执行就好了，应该是模块刚加载、还在初始化的时间差。

重启后：

```
SESSION  UID USER SEAT  TTY
      3 1000 hui  -     pts/0
     c1  120 gdm  seat0 tty1
```

gdm 会话回来了，`nvidia-smi` 里也能看到 Xorg 和 gnome-shell 在用显卡。

---

## 四、坑二：RustDesk 连上了，却提示"没有显示器"

图形界面起来之后，RustDesk 终于能建立连接，但弹出了一个错误：**没有显示器**。

回头看 dmesg 里有一行当时被忽略的信息：

```
nvidia 0000:01:00.0: [drm] Cannot find any crtc or sizes
```

检查各个输出口：

```bash
for c in /sys/class/drm/card0-*; do echo "$(basename $c): $(cat $c/status)"; done
```

```
card0-DP-1: disconnected
card0-DP-2: disconnected
card0-DP-3: disconnected
card0-HDMI-A-1: disconnected
```

**HDMI 线插着，但另一头没有显示器，读不到 EDID，等于没接。** 之前能用，大概率是当时那根线连着一台开着的显示器。X 里没有任何活动的屏幕，RustDesk 自然没东西可抓。

### 方案 A：HDMI 假负载（最推荐）

十几块钱的"显卡欺骗器"，插上就能模拟一台显示器。EDID、分辨率、刷新率都是真实的，不受驱动升级影响。**长期不接屏的机器，这是最省心的方案。**

### 方案 B：让 NVIDIA 假装接了显示器

先找到 NVIDIA 给输出口起的名字。注意：**GDM 的 Xorg 日志不在 `/var/log`**，而在 gdm 用户的家目录下：

```bash
sudo grep -oE 'DFP-[0-9]+[^,)]*' /var/lib/gdm3/.local/share/xorg/Xorg.0.log | sort -u
```

RTX 3060 列出了 DFP-0 到 DFP-6，其中 TMDS 类型（HDMI）的像素时钟上限是 165 MHz，DisplayPort 类型的是 2670 MHz。

写入配置，强制把 DFP-0 视为已连接，并固定 1080p：

```bash
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/10-nvidia-headless.conf >/dev/null <<'EOF'
Section "Monitor"
    Identifier  "Monitor0"
    HorizSync   28.0-80.0
    VertRefresh 48.0-75.0
    Modeline "1920x1080_60" 148.50 1920 2008 2052 2200 1080 1084 1089 1125 +hsync +vsync
EndSection

Section "Device"
    Identifier "NvidiaGPU"
    Driver     "nvidia"
    Option     "AllowEmptyInitialConfiguration" "true"
    Option     "ConnectedMonitor" "DFP-0"
    Option     "ModeValidation" "NoDFPNativeResolutionCheck,NoVirtualSizeCheck,NoMaxPClkCheck,NoHorizSyncCheck,NoVertRefreshCheck,NoEdidMaxPClkCheck,AllowNonEdidModes"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device     "NvidiaGPU"
    Monitor    "Monitor0"
    DefaultDepth 24
    Option     "MetaModes" "DFP-0: 1920x1080_60 +0+0"
    SubSection "Display"
        Depth   24
        Modes   "1920x1080_60"
        Virtual 1920 1080
    EndSubSection
EndSection
EOF
sudo systemctl restart gdm3
```

几个关键选项的作用：

| 选项 | 作用 |
|---|---|
| `ConnectedMonitor` | 强制驱动认为该口接了显示器 |
| `AllowEmptyInitialConfiguration` | 没有真实显示器时也允许 X 启动 |
| `ModeValidation` | 跳过依赖 EDID 的各项校验 |
| `Modeline` + `MetaModes` | 没有 EDID 时手动指定分辨率 |

> 💡 如果只加 `ConnectedMonitor` 而不给 Modeline，驱动会退回一个保守的默认分辨率。我第一次就是这样，连上去是 4:3 的画面。

想要 2K 分辨率，需要换用 DP 口（如 DFP-1），因为 165 MHz 不够用。Modeline 也要相应替换：

```
Modeline "2560x1440_60" 241.50 2560 2608 2640 2720 1440 1443 1448 1481 +hsync -vsync
```

**回滚方法：** 如果改完 gdm 起不来，用 SSH 删掉配置即可：

```bash
sudo rm /etc/X11/xorg.conf.d/10-nvidia-headless.conf && sudo systemctl restart gdm3
```

### 让登录界面也用同样的分辨率

在桌面里调好分辨率后，把显示配置同步给 gdm：

```bash
sudo cp ~/.config/monitors.xml /var/lib/gdm3/.config/
sudo chown gdm:gdm /var/lib/gdm3/.config/monitors.xml
```

---

## 五、两个"不算问题"的现象

### 1. RustDesk 首次连接会"被对方拒绝"，一闪后自动连上

RustDesk 的系统服务（`rustdesk --service`）平时只在后台待命，有连接进来时，才在当前图形会话里拉起抓屏进程（`--server`）。第一次握手时这个进程还没就绪，所以被拒；客户端自动重连时进程已经起来了，就连上了。

在登录界面输入密码、切换到用户会话时，也会断开一下再重连，原因相同。

如果想消除这一闪，可以开启 GDM 自动登录。代价是开机即进入桌面，不需要密码。我选择保持现状。

### 2. 3389 要先登录桌面才可用

Ubuntu 24.04 设置里的"桌面共享"是**用户级**服务，需要用户已登录、keyring 已解锁，才会监听 3389。所以现在的使用路径是：

> RustDesk 连接 → 在登录界面输入密码 → 进入桌面后 3389 可用

如果希望重启后 3389 直接可用，有两条路（本文未实测，供参考）：

- **自动登录 + keyring 空密码**：在 `/etc/gdm3/custom.conf` 开启 `AutomaticLogin`，并把"登录"密钥环的密码设为空
- **系统级远程登录**：24.04 新增的 `grdctl --system rdp enable`。它在登录界面就监听 3389，并创建无头会话，不需要显示器

---

## 六、顺手做的：RustDesk 一键升级脚本

RustDesk 是用 GitHub Release 的 `.deb` 包安装的，`apt upgrade` 不会更新它。我顺手写了一个升级脚本，主要做这几件事：

1. 对比当前版本和最新正式版，已经是最新就直接退出
2. 备份 root 和当前用户的 RustDesk 配置（中继地址、Key 都在里面）
3. 下载 deb 包，校验后覆盖安装
4. 检查配置是否丢失，丢了就自动恢复
5. 重启服务并确认运行状态，全程写日志

```bash
sudo ./rustdesk-upgrade.sh          # 升级到最新正式版
sudo ./rustdesk-upgrade.sh 1.4.2    # 指定版本
sudo https_proxy=http://127.0.0.1:7890 ./rustdesk-upgrade.sh   # 走代理
```

**建议通过 SSH 或 3389 执行升级。** 3389 走的是 gnome-remote-desktop，和 RustDesk 互不依赖，升级时服务重启不会把自己踢下线。

完整脚本见文末附录。

---

## 七、总结：一张排障地图

| 现象 | 检查命令 | 结论 |
|---|---|---|
| RDP 和 RustDesk 都挂、SSH 正常 | `loginctl list-sessions` | 没有 gdm 会话，说明图形栈没起来 |
| RustDesk 报 `cannot open display` | `systemctl status rustdesk` | X Server 不存在 |
| GDM 反复失败 | `journalctl -b -u gdm3` | `Module nvidia not found`，新内核缺驱动 |
| 驱动装好，RustDesk 提示"没有显示器" | `cat /sys/class/drm/card0-*/status` | 全部 disconnected，没有屏幕 |
| 能连上但分辨率不对 | `xrandr` / Xorg 日志 | 没有 EDID，需要手动指定 Modeline |

三条经验：

1. **"多个远程方式同时失效"，先查它们的公共依赖**，不要逐个去折腾远程软件
2. **HWE 内核 + 预编译 NVIDIA 模块，一定要装 `-generic-hwe-24.04` 元包**，否则每次内核升级都可能翻车
3. **不接显示器的 GPU 机器，花十几块钱买个 HDMI 假负载**，比任何 Xorg 配置都稳

---

## 附录：rustdesk-upgrade.sh

```bash
#!/usr/bin/env bash
# RustDesk 一键升级脚本 (Ubuntu / Debian, .deb 安装方式)
# 用法: sudo ./rustdesk-upgrade.sh [版本号] [-f]
# 可选: GH_MIRROR=下载加速前缀  https_proxy=代理地址

set -euo pipefail

LOG=/var/log/rustdesk-upgrade.log
WORKDIR=/tmp/rustdesk-upgrade
BACKUP_ROOT=/var/backups/rustdesk
FORCE=0
TARGET_VER=""

for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    *) TARGET_VER="${arg#v}" ;;
  esac
done

[[ $EUID -ne 0 ]] && exec sudo -E bash "$0" "$@"

exec > >(tee -a "$LOG") 2>&1
log() { echo -e "[$(date '+%F %T')] $*"; }
die() { log "❌ $*"; exit 1; }

case "$(uname -m)" in
  x86_64)  ARCH=x86_64 ;;
  aarch64) ARCH=aarch64 ;;
  *) die "不支持的架构: $(uname -m)" ;;
esac

CUR_VER="$(dpkg-query -W -f='${Version}' rustdesk 2>/dev/null || true)"
log "当前版本: ${CUR_VER:-未安装}"

if [[ -z "$TARGET_VER" ]]; then
  TARGET_VER="$(curl -fsSL --max-time 20 \
      https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
      | grep -oP '"tag_name":\s*"\K[^"]+' | sed 's/^v//')" \
    || die "获取最新版本失败"
fi
[[ "$TARGET_VER" =~ ^[0-9]+\.[0-9]+ ]] || die "版本号异常: '$TARGET_VER'"
log "目标版本: $TARGET_VER"

if [[ -n "$CUR_VER" && $FORCE -eq 0 ]] && dpkg --compare-versions "$CUR_VER" eq "$TARGET_VER"; then
  log "✅ 已是最新版本"; exit 0
fi

BK="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$BK"
[[ -d /root/.config/rustdesk ]] && cp -a /root/.config/rustdesk "$BK/root"
REAL_USER="${SUDO_USER:-}"
if [[ -n "$REAL_USER" && "$REAL_USER" != root ]]; then
  USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
  [[ -d "$USER_HOME/.config/rustdesk" ]] && cp -a "$USER_HOME/.config/rustdesk" "$BK/user-$REAL_USER"
fi
log "配置已备份到: $BK"

DEB="rustdesk-${TARGET_VER}-${ARCH}.deb"
URL="${GH_MIRROR:-}https://github.com/rustdesk/rustdesk/releases/download/${TARGET_VER}/${DEB}"
mkdir -p "$WORKDIR"
curl -fL --retry 3 --connect-timeout 20 -o "$WORKDIR/$DEB" "$URL" || die "下载失败"
dpkg-deb -I "$WORKDIR/$DEB" >/dev/null 2>&1 || die "deb 包损坏"

DEBIAN_FRONTEND=noninteractive apt-get install -y "$WORKDIR/$DEB" || die "安装失败，备份在 $BK"

if [[ -d "$BK/root" && ! -f /root/.config/rustdesk/RustDesk2.toml ]]; then
  cp -a "$BK/root/." /root/.config/rustdesk/; log "⚠️ 已恢复 root 配置"
fi
if [[ -n "${USER_HOME:-}" && -d "$BK/user-$REAL_USER" && ! -f "$USER_HOME/.config/rustdesk/RustDesk2.toml" ]]; then
  mkdir -p "$USER_HOME/.config/rustdesk"
  cp -a "$BK/user-$REAL_USER/." "$USER_HOME/.config/rustdesk/"
  chown -R "$REAL_USER:" "$USER_HOME/.config/rustdesk"; log "⚠️ 已恢复用户配置"
fi

systemctl daemon-reload
systemctl enable rustdesk >/dev/null 2>&1 || true
systemctl restart rustdesk; sleep 3

NEW_VER="$(dpkg-query -W -f='${Version}' rustdesk)"
systemctl is-active --quiet rustdesk \
  && log "✅ 升级完成: ${CUR_VER:-无} → $NEW_VER" \
  || { log "⚠️ 服务未运行: journalctl -u rustdesk -n 50"; exit 1; }

rm -rf "$WORKDIR"
ls -1dt "$BACKUP_ROOT"/*/ 2>/dev/null | tail -n +6 | xargs -r rm -rf
```

---

**若白知行 · Rubai AI**
