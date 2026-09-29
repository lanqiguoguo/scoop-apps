# scoop-apps

个人 Scoop bucket。应用清单由两个来源桶迁移合并而来：

- [maqibg/MQBucket](https://github.com/maqibg/MQBucket)：迁移时 111 个应用（两个桶有同名应用时以此为准）
- [lanqiguoguo/custom-bucket](https://github.com/lanqiguoguo/custom-bucket)：迁移时补充 4 个应用（ant-browser、nyaterm、pixshell、sshping）

迁移时统一做了两件事：

1. **GitHub 下载链接全部经 [gh-proxy.org](https://gh-proxy.org/) 代理**：`github.com` / `raw.githubusercontent.com` 的下载地址（含 `autoupdate` 模板）统一加 `https://gh-proxy.org/` 前缀，国内网络可直接安装与更新。
2. **用户数据统一持久化到 Scoop 的 `persist`**：配置、会话、数据库等用户数据保存在 `<scoop 根目录>\persist\<应用>`。数据原本位于 `%APPDATA%`、`%LOCALAPPDATA%`、`%USERPROFILE%` 的应用，安装时会自动把旧数据迁移到 persist（主流做法是 robocopy 复制，原目录改名备份为 `<目录>.backup-<时间戳>`，`Ani`、`pure_live`、`MemCleaner` 也走同样的复制+备份流程）并创建 Junction 指回原路径；`cockpit-tools`、`pebrel`、`tdl` 采用「复制播种、保留原目录」模式，不产生备份目录。卸载时移除链接（仅链接，数据保留在 persist；用 `scoop uninstall <应用> -p` 才连数据一起删除）。

## 安装

```powershell
scoop bucket add scoop-apps https://github.com/lanqiguoguo/scoop-apps
scoop install scoop-apps/<应用名>
```

多数应用的数据目录与持久化方式都写在 manifest 的 `notes` 里（部分 CLI 工具型清单没有独立数据目录，未写 notes），可用 `scoop info <应用名>` 查看。

## 应用列表（116 个）

| 应用 | 应用 | 应用 | 应用 |
| --- | --- | --- | --- |
| 115-plus-desktop | dbx | moor | QuickCut |
| agent-skills | Dev-Janitor | Moraya | ReadAny |
| ai-cli-complete-notify | DevTool-Manager | motrix-next | relaydesk |
| ai-toolbox | DnsTools | Mouser | res-downloader |
| aio-coding-hub | Game-Cheats-Manager | MShell | RogueCleaner |
| AIO-Hub | geekez-browser | MusicTag | SecondDesk |
| AionUi | Github-Store | nebula | shelf |
| AliasGUI | GithubStarsManager | netcatty | skills-manager |
| Ani | go-music-dl | Nexus_Terminal | SmartHostsTool |
| ant-browser | guan-manager | nexus-terminal-rust | snippai |
| aramgg_client | hikit | NipaPlay-Reload | SoNovel |
| bbmusic | imfile-desktop | nwinfo | sparkle |
| belfry-desktop | karing | nyaterm | sshping |
| buildby | kdeconnect | OpenPencil | SteamCommunity-302 |
| c_cleaner_plus | KeymouseGo | oxideterm | sTerminal |
| cc-gui | keyStats | pebble | Tai |
| cc-sessions-viewer | kikoplay | pebrel | tbtool |
| cc-switch | killerpdf | pi-desktop | tdl |
| ccg-gateway | LGHUB | PicList | tty7 |
| chromix | linuxdo-accelerator | pideck | tubatool |
| clawbench | LiteMonitor | PiliNara | Tuboshu |
| cloaksession | Lumina-Note | PixPin | turbo-browser |
| cockpit-tools | mangodisk | pixshell | Unihub |
| CodeConductor | meatshell | Pot | UotanToolboxNT |
| CodeSwitch | MemCleaner | powershell | UsbEAm-Hosts-Editor |
| CodeSwitchR | MemoryCleanr | PromptOptimizer | winterm2 |
| codux | MicYou | pure_live | wsl-dashboard |
| copaw | milkup | QuantumTV | XTerminal |
| CursorLens | mini-term | Quick-Launcher | ZTools |

## 数据与使用提示

- 安装、升级、卸载前请先关闭对应应用（尤其是 belfry-desktop、pebrel 等会锁定数据文件的应用），各 manifest 的 notes 中已有说明。
- 数据迁移产生的 `<原目录>.backup-<时间戳>` 备份目录，确认数据无误后可自行删除。
- `LGHUB` 只是 Logitech 官方安装器的下载引导，应用本体与数据由官方安装程序管理，不纳入 persist；该清单为占位版本（`version` 固定为 1.0，无 `checkver`/`autoupdate`），Scoop 不会更新它，需通过官方安装器更新。
- `powershell`、`sshping` 等没有独立用户数据的 CLI 工具，以及闭源且无可靠数据目录证据的 `UsbEAm-Hosts-Editor`，未做 persist 接管；`tdl` 通过 `TDL_STORAGE` 环境变量把数据目录重定向到 persist，日志与扩展仍保留在 `~/.tdl`。
- 其它 bucket 也可能存在同名清单（本机已确认 `dorado` 桶中的 `powershell` 与本仓库清单逐字相同），建议始终用桶限定名安装（如 `scoop install scoop-apps/powershell`），避免装错来源。

## 仓库结构

- `bucket/`：应用清单，自动更新由清单内的 `checkver` / `autoupdate` 与 Excavator 工作流驱动
- `scripts/AppsUtils.psm1`：数据目录挂载辅助模块，`Ani`、`pure_live` 安装/升级时调用 `Mount-ExternalRuntimeData`；`Dismount-ExternalRuntimeData` 目前没有清单调用，两者的卸载逻辑写在各自清单内；路径通过 `$bucket` 动态解析，`scoop bucket add` 时可用任意桶名
- `bin/`：BucketTemplate 提供的维护脚本，CI 通过 `bin/test.ps1` 运行 Pester 校验
- `deprecated/`：已废弃清单目录
- 仓库结构基于 [ScoopInstaller/BucketTemplate](https://github.com/ScoopInstaller/BucketTemplate)；CI 会校验 manifest schema、文件编码（UTF-8 无 BOM、CRLF、结尾换行、无行尾空格）与 PowerShell 语法

## 关于 gh-proxy.org

GitHub 下载（以及部分清单的 hash 获取）都经由第三方代理 [gh-proxy.org](https://gh-proxy.org/) 中转。该代理与 scoop-apps 没有隶属关系，若不完全信任它，可以自行去掉链接前缀直连原始地址，或改用自建代理。
