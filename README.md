# scoop-apps

个人 Scoop bucket。应用清单由两个来源桶迁移合并而来：

- [maqibg/MQBucket](https://github.com/maqibg/MQBucket)：111 个应用（两个桶有同名应用时以此为准）
- [lanqiguoguo/custom-bucket](https://github.com/lanqiguoguo/custom-bucket)：补充 4 个应用（ant-browser、nyaterm、pixshell、sshping）

迁移时统一做了两件事：

1. **GitHub 下载链接全部经 [gh-proxy.org](https://gh-proxy.org/) 代理**：`github.com` / `raw.githubusercontent.com` 的下载地址（含 `autoupdate` 模板）统一加 `https://gh-proxy.org/` 前缀，国内网络可直接安装与更新。
2. **用户数据统一持久化到 Scoop 的 `persist`**：配置、会话、数据库等用户数据保存在 `<scoop 根目录>\persist\<应用>`。数据原本位于 `%APPDATA%`、`%LOCALAPPDATA%`、`%USERPROFILE%` 的应用，安装时会自动把旧数据迁移到 persist（robocopy 复制，原目录改名备份为 `<目录>.backup-<时间戳>`）并创建 Junction 指回原路径；卸载时只移除链接，数据保留在 persist（用 `scoop uninstall <应用> -p` 才会连数据一起删除）。

## 安装

```powershell
scoop bucket add scoop-apps https://github.com/lanqiguoguo/scoop-apps
scoop install scoop-apps/<应用名>
```

每个应用的数据目录与持久化方式都写在 manifest 的 `notes` 里，可用 `scoop info <应用名>` 查看。

## 应用列表（115 个）

| 应用 | 应用 | 应用 | 应用 |
| --- | --- | --- | --- |
| 115-plus-desktop | dbx | moor | ReadAny |
| agent-skills | Dev-Janitor | Moraya | relaydesk |
| ai-cli-complete-notify | DevTool-Manager | motrix-next | res-downloader |
| ai-toolbox | DnsTools | Mouser | RogueCleaner |
| aio-coding-hub | Game-Cheats-Manager | MShell | SecondDesk |
| AIO-Hub | geekez-browser | MusicTag | shelf |
| AionUi | Github-Store | nebula | skills-manager |
| AliasGUI | GithubStarsManager | netcatty | SmartHostsTool |
| Ani | go-music-dl | Nexus_Terminal | snippai |
| ant-browser | guan-manager | nexus-terminal-rust | SoNovel |
| aramgg_client | hikit | NipaPlay-Reload | sparkle |
| bbmusic | imfile-desktop | nwinfo | sshping |
| belfry-desktop | karing | nyaterm | SteamCommunity-302 |
| buildby | kdeconnect | OpenPencil | sTerminal |
| c_cleaner_plus | KeymouseGo | oxideterm | Tai |
| cc-gui | keyStats | pebble | tbtool |
| cc-sessions-viewer | kikoplay | pebrel | tdl |
| cc-switch | killerpdf | pi-desktop | tty7 |
| ccg-gateway | LGHUB | PicList | tubatool |
| chromix | linuxdo-accelerator | PiliNara | Tuboshu |
| clawbench | LiteMonitor | PixPin | turbo-browser |
| cloaksession | Lumina-Note | pixshell | Unihub |
| cockpit-tools | mangodisk | Pot | UotanToolboxNT |
| CodeConductor | meatshell | powershell | UsbEAm-Hosts-Editor |
| CodeSwitch | MemCleaner | PromptOptimizer | winterm2 |
| CodeSwitchR | MemoryCleanr | pure_live | wsl-dashboard |
| codux | MicYou | QuantumTV | XTerminal |
| copaw | milkup | Quick-Launcher | ZTools |
| CursorLens | mini-term | QuickCut | |

## 数据与使用提示

- 安装、升级、卸载前请先关闭对应应用（尤其是 belfry-desktop、pebrel 等会锁定数据文件的应用），各 manifest 的 notes 中已有说明。
- 数据迁移产生的 `<原目录>.backup-<时间戳>` 备份目录，确认数据无误后可自行删除。
- `LGHUB` 只是 Logitech 官方安装器的下载引导，应用本体与数据由官方安装程序管理，不纳入 persist。
- `powershell`、`sshping` 等没有独立用户数据的 CLI 工具，以及闭源且无可靠数据目录证据的 `UsbEAm-Hosts-Editor`，未做 persist 接管；`tdl` 通过 `TDL_STORAGE` 环境变量把数据目录重定向到 persist，日志与扩展仍保留在 `~/.tdl`。

## 仓库结构

- `bucket/`：应用清单，自动更新由清单内的 `checkver` / `autoupdate` 与 Excavator 工作流驱动
- `scripts/AppsUtils.psm1`：数据目录挂载辅助模块（`Mount-ExternalRuntimeData` / `Dismount-ExternalRuntimeData`），供 `Ani`、`pure_live` 使用；路径通过 `$bucket` 动态解析，`scoop bucket add` 时可用任意桶名
- `deprecated/`：已废弃清单目录
- 仓库结构基于 [ScoopInstaller/BucketTemplate](https://github.com/ScoopInstaller/BucketTemplate)；CI 会校验 manifest schema、文件编码（UTF-8 无 BOM、CRLF、结尾换行、无行尾空格）与 PowerShell 语法
