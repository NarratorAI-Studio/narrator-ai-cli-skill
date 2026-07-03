# 🧠 Narrator AI CLI Skill — 让 AI Agent 学会做电影解说视频

[English](README.md)

> 安装这个 Skill，你的小龙虾（OpenClaw）就能理解如何使用 [narrator-ai-cli](https://github.com/NarratorAI-Studio/narrator-ai-cli) 来制作电影解说视频。对着 AI 说一句「帮我做一个电影解说」，剩下的交给它。

## 这是什么？

这是一份 AI Agent 的技能描述文件（`SKILL.md`），教会 AI Agent 如何调用 narrator-ai-cli 命令行工具来完成视频解说的全流程：

```
你说：「帮我做一个飞驰人生的电影解说视频，喜剧风格」

AI 自动执行：搜索影片 → 选择模板 → 选择BGM → 选择配音 → 生成文案 → 合成视频 → 返回下载链接
```

### CLI 和 Skill 的关系

| | CLI（命令行工具） | Skill（技能描述文件） |
|---|---|---|
| **是什么** | 一套可执行的命令 | 一份教 AI 怎么用这些命令的说明书 |
| **类比** | 一套厨具 | 一本菜谱 |
| **单独能用吗** | 可以在终端手动使用 | 不能，必须配合 CLI |

简单说：**CLI 是手脚，Skill 是大脑。** 两者配合，AI Agent 才能完整地帮你做视频。

---

## 快速安装

### 第 1 步：安装 CLI 工具

```bash
pip install "narrator-ai-cli @ git+https://github.com/NarratorAI-Studio/narrator-ai-cli.git"
```

> 详细安装说明见 [narrator-ai-cli](https://github.com/NarratorAI-Studio/narrator-ai-cli)

### 第 2 步：配置 API Key

```bash
narrator-ai-cli config set app_key 你的API_Key
```

> 📧 没有 API Key？发送邮件至 **merlinyang@gridltd.com** 或扫描文末二维码添加微信获取。

### 第 3 步：安装 Skill

Skill 由 `SKILL.md` **和** `references/` 目录共同组成，两者缺一不可。将整个仓库 clone 到 Agent 的技能目录即可：

**小龙虾 OpenClaw：**
```bash
mkdir -p ~/.openclaw/skills
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  ~/.openclaw/skills/narrator-ai-cli
```

**Autohand Code：**
```bash
mkdir -p ~/.autohand/skills
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  ~/.autohand/skills/narrator-ai-cli

# 或者只安装到当前项目：
mkdir -p .autohand/skills
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  .autohand/skills/narrator-ai-cli
```

**Windsurf / Claude Code：**
```bash
mkdir -p /path/to/your/project/.skills
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  /path/to/your/project/.skills/narrator-ai-cli
```

**Cursor：**
```bash
mkdir -p /path/to/your/project/.cursor/rules
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  /path/to/your/project/.cursor/rules/narrator-ai-cli
```

**其他支持 Markdown 技能文件的 Agent：**
```bash
mkdir -p /path/to/agent/skills
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  /path/to/agent/skills/narrator-ai-cli
```

**WorkBuddy / QClaw（腾讯系）：**

在技能管理界面上传 `SKILL.md` 以及完整的 `references/` 目录，**必须保持目录结构**（`references/` 需作为子目录与 `SKILL.md` 并列，不能将文件平铺上传或改名），否则 `SKILL.md` 中的相对路径引用会失效。

> 💡 **提示**：后续升级只需在 clone 目录里执行 `git pull` 即可。

### 第 4 步：开始对话！

安装完成后，直接用自然语言和 AI 交流：

- 「帮我做一个飞驰人生的电影解说视频」
- 「查看有哪些内置电影素材」
- 「用热血动作风格做一个解说视频」
- 「帮我做 5 条不同电影的解说视频」

---

---

## 已测试平台

| 平台 | 安装方式 | 状态 |
|------|---------|------|
| **小龙虾 OpenClaw** | `git clone` 到技能目录 | ✅ 已验证 |
| **Autohand Code** | `git clone` 到 `~/.autohand/skills` 或 `.autohand/skills` | ✅ 兼容 |
| **WorkBuddy**（腾讯） | 上传 SKILL.md + references/ 全部文件 | ✅ 已验证 |
| **QClaw**（腾讯） | 上传 SKILL.md + references/ 全部文件 | ✅ 已验证 |
| **Windsurf** | `git clone` 到 .skills 目录 | ✅ 已验证 |
| **有道龙虾** | `git clone` 到技能目录 | ✅ 已验证 |
| **元气 AI** | `git clone` 到技能目录 | ✅ 已验证 |
| **Claude Code** | `git clone` 到项目 .skills 目录 | ✅ 已验证 |
| **Cursor** | `git clone` 到 .cursor/rules 目录 | ✅ 已验证 |
| 其他支持 Markdown Skill 的 Agent | `git clone` 后指向 SKILL.md | ✅ 兼容 |

---

## Skill 能力范围

| 能力 | 说明 |
|------|------|
| 两条工作流 | 二创文案（爆款学习）和原创文案（快速模式） |
| 三种创作模式 | 热门影视 / 原声混剪 / 冷门新剧 |
| 内置资源 | 约 100 部电影、146 首 BGM、63 个配音角色、90+ 解说风格模板 |
| 完整流水线 | 文案生成 → 剪辑数据 → 视频合成 → 视觉模板 |
| 独立任务 | 声音克隆、文本转语音 |
| 数据流映射 | 每一步的输出如何传入下一步 |
| 错误处理 | 全部 18 个 API 错误码及对应处理方式 |
| 成本预估 | 创建任务前可预估积分消耗 |

### SKILL.md 包含什么

| 章节 | 内容 |
|------|------|
| Frontmatter | 技能元数据（名称、描述、依赖） |
| Reference Index | 指向 `references/` 详细查阅表的索引（resources、workflows、magic-video、operations） |
| Pipeline at a Glance | Fast Path 和 Standard Path 的 ASCII 流程图 |
| Agent Rules | 强制规则：操作前确认、语言链、轮询模式等 |
| Prerequisites | 前置条件：已安装 `narrator-ai-cli` 且配置了 `NARRATOR_APP_KEY` |
| Core Concepts | 关键概念：file_id、task_id、task_order_num 等 |
| Conversation Initiation | 如何开启会话及决策顺序 |
| Two Workflow Paths | Fast Path（原创文案）vs Standard Path（二创文案） |
| Resource Selection Protocol | BGM、配音、模板的选择顺序与规则 |
| Fast Path | 步骤 0–4 及参数说明 |
| Standard Path | 步骤 0–5 及参数说明 |
| Standalone Tasks | 声音克隆和 TTS |
| Important Notes | 7 条关键注意事项和最佳实践 |
| Data & Privacy | API 端点、文件处理、凭证范围 |

---

## 系统要求

- **CLI 工具**: narrator-ai-cli v1.0.0+
- **Python**: 3.10+
- **依赖库**: typer, httpx[socks], httpx-sse, pyyaml, rich
- **API Key**: 联系我们获取

## 相关链接

- 📦 [narrator-ai-cli 命令行工具](https://github.com/NarratorAI-Studio/narrator-ai-cli)
- 📖 [资源预览（飞书文档）](https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc)
- 🦞 [OpenClaw Agent 框架](https://github.com/openclaw/openclaw)

## 联系我们

需要 API Key 或使用帮助？

- 📧 邮箱：merlinyang@gridltd.com
- 💬 微信：扫描下方二维码

![联系客服](imgs/contact.png)

## 许可协议

MIT
