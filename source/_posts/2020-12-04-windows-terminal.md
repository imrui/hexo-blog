---
title: Windows Terminal 美化与包管理工具
date: 2021-11-24 16:46:18
tags: [System,开发工具]
description: Windows Terminal 美化配置，Windows 包管理工具 winget / scoop / chocolatey 的安装使用。
---

## Windows Terminal 安装

`请参阅` [安装和设置 Windows 终端](https://docs.microsoft.com/zh-cn/windows/terminal/get-started)

```json5
{
  "actions": [
    // 自定义快捷键
    { "command": "closeWindow", "keys": "alt+F4" },
    { "command": "nextTab", "keys": "alt+shift+]" },
    { "command": "prevTab", "keys": "alt+shift+[" },
    { "command": "nextTab", "keys": "ctrl+alt+right" },
    { "command": "prevTab", "keys": "ctrl+alt+left" },
    { "command": "closeTab", "keys": "alt+w" },
    { "command": "closeTab", "keys": "ctrl+w" },
    { "command": "newTab", "keys": "alt+t" },
    { "command": "newTab", "keys": "ctrl+t" },
    { "command": "newTab", "keys": "ctrl+shift+t" },
    { "command": "duplicateTab", "keys": "ctrl+shift+d" },
  ]
}
```

## Windows Terminal 美化

`请参阅` [教程：在 Windows 终端中设置 Powerline](https://docs.microsoft.com/zh-cn/windows/terminal/tutorials/powerline-setup)

### Nerd Fonts

Oh My Posh was designed to use [Nerd Fonts](https://www.nerdfonts.com/). Nerd Fonts are popular fonts that are patched to include icons. We recommend [Meslo LGM NF](https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Meslo.zip), but any Nerd Font should be compatible with the standard [themes](https://github.com/JanDeDobbeleer/oh-my-posh/tree/main/themes).

### 安装 Powerline 字体

可以使用scoop安装，也可以从 [Cascadia Code GitHub发布页](https://github.com/microsoft/cascadia-code/releases) 安装这些字体。

```shell script
# 搜索字体相关信息
scoop search CascadiaCode
# 搜索结果如下
'nerd-fonts' bucket:
    CascadiaCode-NF-Mono (2.1.0)
    CascadiaCode-NF (2.1.0)

# 添加字体库的bucket
scoop bucket add nerd-fonts

# 安装字体，需要申请管理员权限，若无sudo请先安装 scoop install sudo
sudo scoop install CascadiaCode-NF
```

**修改字体配置**

Windows PowerShell 配置文件 settings.json 文件现在应如下所示：

```json5
{
// If enabled, selections are automatically copied to your clipboard.
"copyOnSelect": true,
"profiles":
    {
        "defaults":
        {
            // Put settings here that you want to apply to all profiles.
            "fontFace": "Cascadia Code PL"
        },
        // ...
    }
}
```

### 设置 Powerline

如果尚未安装，请 [安装适用于 Windows 的 Git](https://git-scm.com/downloads) 。

使用 PowerShell，安装 Posh-Git 和 Oh-My-Posh：

```shell script
Install-Module posh-git -Scope CurrentUser
Install-Module oh-my-posh -Scope CurrentUser
# 安装 Get-ChildItemColor 为 PowerShell 的输出添加颜色（比如为 ls 的输出上色）
Install-Module -AllowClobber Get-ChildItemColor -Scope CurrentUser
```

**自定义 PowerShell 提示符**

使用 notepad $PROFILE 或所选的文本编辑器打开 PowerShell 配置文件。 这不是你的 Windows 终端配置文件。 你的 PowerShell 配置文件是一个脚本，该脚本在每次启动 PowerShell 时运行。 [详细了解 PowerShell 配置文件](https://docs.microsoft.com/zh-cn/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7) 。
在 PowerShell 配置文件中，将以下内容添加到文件的末尾：

```shell script
Import-Module posh-git
Import-Module oh-my-posh
Import-Module Get-ChildItemColor
Set-Alias ll Get-ChildItem # 设置ll别名
Set-Theme Robbyrussell
```

现在，每个新实例启动时都会导入 Posh-Git 和 Oh-My-Posh，然后从 Oh-My-Posh 设置 Paradox 主题。 Oh-My-Posh 附带了若干[内置主题](https://github.com/JanDeDobbeleer/oh-my-posh#themes) 。

## Windows 包管理工具安装

### winget

**可使用多种方法安装 winget 工具：**

- [Windows 应用安装程序](https://www.microsoft.com/p/app-installer/9nblggh4nns1?ocid=9nblggh4nns1_ORSEARCH_Bing&rtc=1&activetab=pivot:overviewtab) 的外部测试版或预览版中包含 winget 工具。 必须安装 应用安装程序 的预览版本才能使用 winget 。 若要获取提前访问权限，请将你的请求提交到 [Windows 程序包管理器预览体验计划](https://aka.ms/AppInstaller_InsiderProgram) 。 参与外部测试版 Ring 将保证你可以看到最新的预览版更新。
- 参与 [Windows 外部测试版 Ring](https://insider.windows.com/) 。
- 安装位于 [winget 存储库](https://github.com/microsoft/winget-cli) 的 release 文件夹中的 Windows 桌面应用安装程序包。

`请参阅` [使用 winget 工具安装和管理应用程序](https://docs.microsoft.com/zh-cn/windows/package-manager/winget/)
_winget 工具需要 Windows 10 版本 1709 (10.0.16299) 或更高版本的 Windows 10。_

Usage Example:

```shell script
winget -v
# or
winget install postman --rainbow
```

### scoop

`请参阅` [scoop.sh](https://scoop.sh/)

Scoop installs the tools you know and love

```shell script
scoop install curl
```

Make sure PowerShell 5 (or later, include PowerShell Core) and .NET Framework 4.5 (or later) are installed. Then run:

```shell script
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
# or shorter
iwr -useb get.scoop.sh | iex
```

Note: if you get an error you might need to change the execution policy (i.e. enable Powershell) with

```shell script
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
```

**推荐安装软件**

```shell script
scoop install git  # scoop依赖git
scoop install 7zip # scoop依赖7zip解压
scoop install aria2 # 可以考虑开启aria2下载
scoop install sudo # 申请管理员权限，和linux下sudo命令相似，全局安装必备
```

**List**

```shell script
scoop list # 列出已安装软件
scoop bucket list # 列出bucket（）
```

**Bucket**

每个bucket中维护了许多json文件，描述了软件的相关信息，安装方式，更新方式，可以理解为软件源（虽然并不相同），默认只有一个main，几乎全是命令行工具，可以添加其他的：

```shell script
scoop bucket known # 列出已知的bucket
scoop bucket list # 列出已添加的bucket
scoop bucket add extras # 添加bucket
scoop bucket rm games # 移除bucket
```

**推荐的bucket**

- main
- extras

_因不符合main收录标准，但常用的一些库_

- versions

_安装特定版本_

- nerd-fonts


### chocolatey

`请参阅` [Chocolatey.org](https://chocolatey.org/install#individual)

PowerShell 安装 Chocolatey 非常简单，管理员运行，然后输入如下命令

```shell script
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

Usage Example:

```shell script
choco
# or
choco -?
```
