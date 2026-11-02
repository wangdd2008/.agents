# Agent Skills 集合

本仓库收集了 **46** 个 Agent Skill，用于扩展 AI 代理的各种能力，涵盖工程开发、设计、文档处理、生产力等多个领域。

## 什么是 Agent Skills？

Skills 是模块化的能力包，通过结构化的 Markdown 文件（`SKILL.md`）定义，让 AI 代理获得特定领域的专业工作流程、模板和知识。本项目使用 [Skills CLI](https://skills.sh/) (`npx skills`) 进行 Skill 的安装和管理。

## Skill 来源分类

### 1. [Vercel Labs](https://github.com/vercel-labs) — 浏览器与发现

| Skill | 描述 |
|-------|------|
| [agent-browser](https://github.com/vercel-labs/agent-browser) | AI 代理浏览器自动化 CLI，支持页面导航、表单填写、截图、数据提取等 |
| [find-skills](https://github.com/vercel-labs/skills) | 帮助用户从开放的 agent skills 生态中发现和安装合适的 skill |

### 2. [Matt Pocock](https://github.com/mattpocock/skills) — 工程与生产力（27 个）

涵盖软件开发全生命周期的技能集合，从需求打磨到代码实现、审查、发布。

| Skill | 描述 |
|-------|------|
| ask-matt | 路由技能，帮助选择当前场景最适合的 skill 或工作流 |
| code-review | 双轴代码审查：规范检查 + 需求符合度检查 |
| codebase-design | 代码库深度模块设计，提升可测试性和 AI 可导航性 |
| diagnosing-bugs | 顽固 Bug 和性能回归的诊断循环 |
| domain-modeling | 领域模型构建与术语表（GLOSSARY.md、ADR）维护 |
| grill-me | 通过 relentless interview 打磨计划和设计 |
| grill-with-docs | 带文档输出的 grill（生成 ADR 和术语表） |
| grilling | grill 原语，用于压力测试想法、决策或计划 |
| handoff | 将当前会话压缩为交接文档，供其他代理继续 |
| implement | 基于规格或工单集实现功能 |
| implement-spec | 实现 `/to-spec` 和 `/to-tickets` 的产出 |
| improve-codebase-architecture | 扫描代码库寻找深化机会，生成可视化报告 |
| pr | 编写 PR 描述正文 |
| prototype | 构建一次性原型来回答设计问题 |
| research | 针对问题调研高可信度的一手资料 |
| retro | 对编码会话进行回顾 |
| setup-matt-pocock-skills | 配置工程技能所需的问题跟踪器、标签和领域文档 |
| tdd | 测试驱动开发：红-绿-重构循环 |
| teach | 在仓库内教用户新技能或概念 |
| to-questionnaire | 将不确定的决策转化为问卷供他人填写 |
| to-spec | 将当前对话转为规格说明并发布到问题跟踪器 |
| to-tickets | 将计划、规格或对话拆分为可追踪的 tracer-bullet 工单 |
| triage | 对问题和 PR 进行分诊分类，编写代理可用的简报 |
| wait-what | 当用户觉得上一条消息没讲清楚时，重新表述 |
| wayfinder | 规划大型工作，将决策映射为共享的问题跟踪器工单 |
| wizard | 生成交互式 bash 向导，引导人类完成基础设施配置等步骤 |
| writing-for-agents | 为代理编写文档（SKILL.md、AGENTS.md、CLAUDE.md） |

### 3. [Anthropics](https://github.com/anthropics/skills) — 文档与开发（7 个）

| Skill | 描述 |
|-------|------|
| docx | 创建、读取、编辑 Word 文档（.docx / .dotx） |
| pdf | PDF 文件的读取、合并、拆分、旋转、水印、创建、表单填写、OCR 等 |
| pptx | PowerPoint 演示文稿的创建、读取、编辑、模板填充 |
| xlsx | 电子表格（.xlsx / .csv / .tsv）的创建、读取、编辑、格式化和转换 |
| frontend-design | 新 UI 构建或现有 UI 重塑的前端设计指导 |
| webapp-testing | 使用 Playwright 与本地 Web 应用交互和测试 |
| mcp-builder | 构建高质量的 MCP（Model Context Protocol）服务器指南 |

### 4. 独立社区 Skill

| 来源 | Skill | 描述 |
|------|-------|------|
| [leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill) | design-taste-frontend | tasteskill v2，反模板化前端设计技能，基于 247 个精选画廊网站的艺术指导 |
| [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) | diagram-design | 创建品牌化架构图、流程图、时序图、ER 图等 45+ 种图表类型，输出为 HTML/SVG/PNG |
| [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates) | markitdown | 将 PDF、DOCX、PPTX、图片、音频等文件转换为 Markdown（基于 Microsoft MarkItDown） |
| [hugohe3/ppt-master](https://github.com/hugohe3/ppt-master) | ppt-master | AI 驱动的演示文稿工作流，生成可编辑的 PPTX 幻灯片、重构页面视觉、创建可复用的品牌/样式/布局工作空间 |
| [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) | i-have-adhd | 为 ADHD 读者调整输出格式：先行动、编号步骤、重述状态、抑制旁支、给出具体时间估计 |
| [jackwener/opencli](https://github.com/jackwener/opencli) | opencli-adapter-author | 基于观察到的网站行为构建或改进 OpenCLI JS 适配器 |
| [backnotprop/pstack](https://github.com/backnotprop/pstack) | poteto-mode | poteto 的代理风格：简洁详细的回应、克制的子代理、反套话、简单代码、验证工作 |
| [dietrichgebert/ponytail](https://github.com/dietrichgebert/ponytail) | ponytail | 懒加载的高级开发者模式：用最少的改动完整解决问题，回复让忙碌的人一眼看懂（支持 lite / full / ultra 级别） |
| [morluto/rea](https://github.com/morluto/rea) | reverse-engineer-anything | 使用 REA 对原生、托管、Electron/JavaScript、打包、固件和浏览器目标进行逆向工程 |

---

## 安装与管理

使用 Skills CLI 安装新的 skill：

```bash
# 安装技能
npx skills add <owner/repo@skill> -g -y

# 搜索技能
npx skills find <query>

# 更新所有技能
npx skills update
```

## 目录结构

```
skills/
├── <skill-name>/           # 每个 skill 一个目录
│   ├── SKILL.md            # 技能定义文件
│   ├── agents/             # 代理配置（可选）
│   ├── scripts/            # 辅助脚本（可选）
│   └── ...
└── ...

.skill-lock.json            # 已安装 skill 的来源和版本锁定文件
```

## 许可证说明

各 skill 的许可证由其原始仓库决定。具体请查看各 skill 目录下的 `LICENSE`、`LICENSE.txt` 或 `SKILL.md` 中的 `license` 元数据字段。

## 相关链接

- **Skills 生态**: https://skills.sh/
- **Skills CLI 文档**: https://github.com/vercel-labs/skills
- **本仓库锁定文件**: `.skill-lock.json`
