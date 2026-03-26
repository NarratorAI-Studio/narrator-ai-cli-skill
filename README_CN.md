# 🧠 Narrator AI CLI Skill — 让 AI Agent 学会做电影解说视频

[English](README.md)

> 安装这个 Skill，你的小龙虾（OpenClaw）就能理解如何使用 [narrator-ai-cli](https://github.com/jieshuo-ai/narrator-ai-cli) 来制作电影解说视频。对着 AI 说一句「帮我做一个电影解说」，剩下的交给它。

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
pip install "narrator-ai-cli @ git+https://github.com/jieshuo-ai/narrator-ai-cli.git"
```

> 详细安装说明见 [narrator-ai-cli](https://github.com/jieshuo-ai/narrator-ai-cli)

### 第 2 步：配置 API Key

```bash
narrator-ai-cli config set app_key 你的API_Key
```

> 📧 没有 API Key？发送邮件至 **merlinyang@gridltd.com** 或扫描文末二维码添加微信获取。

### 第 3 步：安装 Skill

根据你使用的 Agent 平台，选择对应的安装方式：

**小龙虾 OpenClaw：**
```bash
mkdir -p ~/.openclaw/skills/narrator-ai-cli
cp SKILL.md ~/.openclaw/skills/narrator-ai-cli/SKILL.md
```

**WorkBuddy / QClaw（腾讯系）：**

在技能管理界面上传 `SKILL.md` 文件即可。

**Windsurf：**
```bash
cp SKILL.md /path/to/your/project/.skills/narrator-ai-cli/SKILL.md
```

**其他支持 Markdown 技能文件的 Agent：**
```bash
cp SKILL.md /path/to/agent/skills/narrator-ai-cli/SKILL.md
```

> 💡 **提示**：你也可以直接把本仓库地址发给 AI，让它自己学习安装——大部分 Agent 都能理解 GitHub 仓库结构并自动完成配置。

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
| **小龙虾 OpenClaw** | 原生 Skill 加载 | ✅ 已验证 |
| **WorkBuddy**（腾讯） | 上传 SKILL.md | ✅ 已验证 |
| **QClaw**（腾讯） | 上传 SKILL.md | ✅ 已验证 |
| **Windsurf** | .skills 目录 | ✅ 已验证 |
| **有道龙虾** | Skill 加载 | ✅ 已验证 |
| **元气 AI** | Skill 加载 | ✅ 已验证 |
| **Claude Code** | 项目根目录 SKILL.md | ✅ 已验证 |
| **Cursor** | rules/skills 目录 | ✅ 已验证 |
| 其他支持 Markdown Skill 的 Agent | 指向 SKILL.md 即可 | ✅ 兼容 |

---

## Skill 能力范围

| 能力 | 说明 |
|------|------|
| 两条工作流 | 二创文案（爆款学习）和原创文案（快速模式） |
| 三种创作模式 | 热门影视 / 原声混剪 / 冷门新剧 |
| 内置资源 | 93 部电影、146 首 BGM、63 个配音角色、90+ 解说风格模板 |
| 完整流水线 | 文案生成 → 剪辑数据 → 视频合成 → 视觉模板 |
| 独立任务 | 声音克隆、文本转语音 |
| 数据流映射 | 每一步的输出如何传入下一步 |
| 错误处理 | 全部 18 个 API 错误码及对应处理方式 |
| 成本预估 | 创建任务前可预估积分消耗 |

### SKILL.md 包含什么

| 章节 | 内容 |
|------|------|
| Frontmatter | 技能元数据（名称、描述、依赖） |
| Architecture | CLI 源码结构和设计说明 |
| Core Concepts | 关键概念：file_id、task_id、order_num 等 |
| Workflow Paths | 两条完整流水线的分步命令 |
| Prerequisites | 资源选择方法（素材、BGM、配音、模板） |
| Fast Path | 推荐工作流：搜索 → 文案 → 剪辑 → 合成 → 视觉模板 |
| Standard Path | 完整工作流：爆款学习 → 文案 → 剪辑 → 合成 → 视觉模板 |
| Standalone Tasks | 声音克隆和 TTS |
| Task Management | 查询、列表、预算、验证、保存 |
| File Operations | 上传、下载、列表、删除 |
| Error Handling | 全部 18 个错误码及处理建议 |
| Data Flow | 完整流水线的 ASCII 图 |
| Important Notes | 9 条关键注意事项和最佳实践 |

---

## 系统要求

- **CLI 工具**: narrator-ai-cli v0.1.0+
- **Python**: 3.10+
- **依赖库**: typer, httpx[socks], httpx-sse, pyyaml, rich
- **API Key**: 联系我们获取

## 相关链接

- 📦 [narrator-ai-cli 命令行工具](https://github.com/jieshuo-ai/narrator-ai-cli)
- 📖 [资源预览（飞书文档）](https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc)
- 🦞 [OpenClaw Agent 框架](https://github.com/openclaw/openclaw)

## 联系我们

需要 API Key 或使用帮助？

- 📧 邮箱：merlinyang@gridltd.com
- 💬 微信：扫描下方二维码

![联系客服](imgs/contact.png)

## 许可协议

MIT
