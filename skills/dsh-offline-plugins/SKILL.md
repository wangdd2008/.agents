---
name: dsh-offline-plugins
description: 把已装好的 dsh 插件搬到内网或断网机器安装。Use when 用户要离线安装 dsh 插件、内网装机、air-gapped 部署、把插件拷给别人、迁移整个 profile，或问没有外网怎么装插件。
---

# dsh 离线插件搬运

dsh 的插件不是独立进程，而是某个 profile 目录里的一个 npm 包 + 两行清单。所以断网装机不需要 registry，把**三件套**搬过去就行。

## 三件套

`%USERPROFILE%\.dsh\profiles\<profile>\` 下：

| 件 | 位置 |
| --- | --- |
| 包本体 | `node_modules\<name>\` |
| 依赖声明 | `package.json` 的 `dependencies` |
| 装载清单 | `package.json` 的 `dsh.profile.bundles` |

`dsh plugin --profile <p> ...` 只是把参数转发给该目录里的 pnpm，所以断网时它装不了东西——手装 = 直接对齐三件套。

## 选路

| 现场 | 做法 |
| --- | --- |
| 几个插件、另一台机器、一次性 | 单插件搬运（默认，步骤 1–5），多插件加 `deps\` 与 `install-all.cmd` |
| 整机换环境、插件很多 | 整 profile 迁移（A） |
| 内网长期维护、要能升级 | 内部 registry（B） |

## 步骤

### 1. 读现场

读源机器（装好插件的那台）profile 的 `package.json`（插件名/版本/依赖），再看 `node_modules\.modules.yaml` 的 `nodeLinker`：`hoisted` 时 `node_modules` 里是实体文件，没有跨目录软链，搬运最省事。

**闭包要递归算**：从插件的 `dependencies` 出发沿依赖图走到底（含 `optionalDependencies`，跳过 `peerDependencies`）。别只看一级——实测 5 个插件闭包是 240 个包 / 346 MB，其中一个右栏插件（CodeMirror + mermaid→d3 + xterm）就贡献了两百多。只搬直接依赖，装完在目标机上是 import 失败。

每个包落在哪一层，决定它怎么搬：

- **已嵌套**：`node_modules\<name>\node_modules\<dep>` → 随包目录一起走（`billion-context`、`dsh-agency-agents` 自带的 `zod` 就是这样）。
- **被提升**：只在 profile 根 `node_modules\<dep>` → 收进 `deps\`，由安装脚本补进目标 profile。

`peerDependencies` 由 dsh 本体提供（`react`、`react-dom`、多数 `@deepseek-ai/*`），profile 根通常根本没有它们。

完成标准：手上有一份**递归闭包清单**（包名 + 嵌套/提升），没有 `unknown`，并粗算过体积——闭包上到几百个包、几百 MB 时提前说明，别让内网同事最后一刻才发现要拷很久。

### 2. 打离线包

```powershell
Copy-Item "<src>\node_modules\<name>" ".\plugin\<name>" -Recurse
Push-Location ".\plugin\<name>"; npm pack --ignore-scripts --pack-destination ..\..\package; Pop-Location
```

闭包里判为「被提升」的包，逐个复制到 `.\deps\<name>`（保持 `@scope` 层级，那是 node 解析要的布局）。
插件目录名与包名无关，scoped 的用 `@scope+name`：`plugin\@liustack+modlens`，装的时候包名从它自己的 `package.json` 读。

`--ignore-scripts` 是必须的：`prepare` 会跑 husky/tsdown，在内网机器上必失败。

完成标准：`tar -tzf package\<name>-<ver>.tgz` 里只有发布文件（`lib/`、`cordis.patch.yml`、`icon.svg`、`locale/`、`README`），没有 `node_modules/`；`deps\` 的目录数 = 闭包里「被提升」的包数；`install-plugin.ps1` 的依赖自检不报 WARNING。

### 3. 生成安装脚本

把 `assets\install-plugin.ps1` 和 `assets\install.cmd` 原样拷到包根；多个插件时再加 `assets\install-all.cmd`（遍历 `plugin\*` 逐个调用）。不要重写脚本——执行策略、编码、`DSH_HOME` 继承、重复执行、依赖补齐都处理过了：

```
<包根>\
├─ install-all.cmd           ← 多个插件时用；单个可省
├─ install.cmd
├─ install-plugin.ps1
├─ plugin\<name>\            ← 第 2 步的 payload（scoped 用 @scope+name）
├─ deps\<name>\              ← 第 2 步的「被提升」依赖
└─ package\<name>-<ver>.tgz  ← 发给内部 registry 时用
```

脚本自己找 `plugin\` 下唯一的包目录；有多个时必须传 `-Payload`，`install-all.cmd` 就是这么调的（`for /d` 不会进 `@scope` 子目录，所以 payload 目录必须摊平）。

完成标准：脚本在一个**空 profile** 上跑出 `自检通过`，重复执行第二次仍返回 0，且全程没有 `WARNING: 依赖…`。

### 4. 断网验收

在独立的 `DSH_HOME` 上验，别碰真 profile：

```powershell
$env:DSH_HOME = "<scratch>"
dsh --profile web --dump-config | Select-String '<name>'      # 应出现 "# == <name>"
```

再冷启动冒烟：后台起 `dsh --profile web --port 3998 --no-open`，等 30–45 秒（插件多、依赖树大时启动更慢）确认进程还活着、stderr 为空，然后杀掉。

完成标准：`dump-config` 里出现插件层，冒烟启动无报错，两步都没有网络超时/解析失败的迹象（`--dump-config` 与启动本身不联网）。

### 5. 交付

包根放一份 README：三件套表格、一条安装命令、前置条件（同版本 dsh + Node、profile 已初始化过一次）、限制（陷阱 5–7）。

完成标准：内网同事只读 README 就能装完，不需要回来问你。

## 陷阱

1. **执行策略**：内网机常是 Restricted，`.ps1` 直接跑会被判 "not digitally signed"。用 `install.cmd` 包一层 `-ExecutionPolicy Bypass`，有 pwsh 就优先 pwsh。
2. **编码，两头都要对**：`package.json` 必须**无 BOM**——PowerShell 5.1 的 `Set-Content -Encoding UTF8` 会加 BOM，Node 解析直接炸，改用 `[IO.File]::WriteAllText($p, $json, [Text.UTF8Encoding]::new($false))`。反向：**含中文的 `.ps1` 必须带 BOM**，否则 5.1 按 ANSI 解码成乱码并语法报错；`.cmd` 则保持纯 ASCII，命令解释器不认 BOM。`install.cmd` 优先找 pwsh，但机器上常常没有、会落到 5.1，所以 BOM 不是可选项——每次改完脚本复核前三字节是 `EF BB BF`，编辑器和格式化工具会悄悄把它吃掉。
3. **别调 `dsh plugin add`**：它转发 pnpm，离线解析依赖必然失败。手装只改三件套；`--offline` 只有在把整个 pnpm store 一起搬过去时才成立。
4. **`DSH_HOME` 会被子进程继承**：脚本里先存 `$env:DSH_HOME`，安装和验收都显式指向同一个 home。否则会出现「装到 A、验到 B」——验收通过而实际没装上，或反过来。
5. **`link:` 依赖跨机即断**：`@local/...` 指向源机器的绝对路径 junction，整 profile 搬过去后启动直接挂。删掉 `dependencies` 里那两条，并从 `dsh.profile.bundles` 里一并移除，或把目录搬过去再改路径。
6. **手装的目录不在 pnpm 锁里**：之后在内网跑 `dsh plugin add/remove` 可能把它当多余依赖 prune 掉。要么别在那台机器上跑 pnpm 安装，要么走 B。
7. **别搬凭据**：`~\.dsh\.credentials.yaml`、`sessions\`、`storages\` 都留在原机器。插件市场（`dshmarket`）在内网没有列表，只能靠搬运。
8. **PowerShell 变量名不区分大小写**：`param([string]$Deps)` 之后再写 `$deps = @(…)`，两者是同一个变量，数组会被 `[string]` 强转成空格拼接（`mysql2 zod`），依赖自检于是整段误报「不在包里也不在 profile 里」。局部变量换个名字。

## A. 整 profile 迁移

`hoisted` 布局下 `node_modules` 是实体文件，整目录复制基本可用：

```powershell
robocopy "<src>\.dsh\profiles\web" "<dst>\.dsh\profiles\web" /E
```

只在你确认过陷阱 5、7 之后用；目标机 `.dsh` 路径不同时，`link:` 和绝对路径都要改。

## B. 内部 registry

把第 2 步的 tarball（以及被判为「被提升」的依赖）发到 verdaccio / Nexus，内网就能正常：

```powershell
dsh plugin --profile web add <name>@<ver>
```

这样 `pnpm-lock.yaml` 和 `.modules.yaml` 保持一致，后续升级也顺。代价是内网得有个私有 npm 源——插件多、要长期维护时才值得。

## 版本门禁

兼容性由插件自己 `package.json` 的 `dsh.compatibility.dshReleases` 声明，离线也能判。内网 dsh 版本不同会被拦，提示里给出放行命令：

```powershell
dsh plugin --profile web allow-version <name>@<ver> --dsh-version <dsh 版本> --accept-risk
```

## 套到别的插件

换 `plugin\<name>`、`deps\`、`package\<name>-<ver>.tgz` 和 README 里的名字即可；真正要重新算的只有步骤 1 的闭包——换一个插件，闭包可能从一个依赖变成两百多个。步骤 2–4 原样复用 `assets\` 里的三个脚本。
