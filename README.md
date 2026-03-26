# 🧠 Narrator AI CLI Skill — Teach Your AI Agent to Create Movie Narration Videos

[中文文档](README_CN.md)

> Install this Skill in your AI agent (OpenClaw, Windsurf, WorkBuddy, etc.), then just say "create a movie narration video" — the AI handles the rest.

## What is this?

A machine-readable skill file (`SKILL.md`) that teaches AI agents how to use the [narrator-ai-cli](https://github.com/jieshuo-ai/narrator-ai-cli) tool for automated video narration production.

```
You say: "Create a narration video for Pegasus in a comedy style"

AI executes: Search movie → Select template → Choose BGM → Pick voice → Generate script → Compose video → Return download link
```

### How CLI and Skill work together

| | CLI (command-line tool) | Skill (capability description) |
|---|---|---|
| **What it is** | A set of executable commands | Instructions that teach AI how to use those commands |
| **Analogy** | Kitchen tools | A recipe book |
| **Works alone?** | Yes, in terminal manually | No, requires CLI |

In short: **CLI is the hands. Skill is the brain.** Together, the AI agent can produce videos end-to-end.

---

## Quick Start

### Step 1: Install the CLI tool

```bash
pip install "narrator-ai-cli @ git+https://github.com/jieshuo-ai/narrator-ai-cli.git"
```

> See [narrator-ai-cli](https://github.com/jieshuo-ai/narrator-ai-cli) for detailed installation options.

### Step 2: Configure API key

```bash
narrator-ai-cli config set app_key <your_app_key>
```

> 📧 Need an API key? Email **merlinyang@gridltd.com** or scan the QR code at the bottom of this page.

### Step 3: Install the Skill

Choose the method for your agent platform:

**OpenClaw:**
```bash
mkdir -p ~/.openclaw/skills/narrator-ai-cli
cp SKILL.md ~/.openclaw/skills/narrator-ai-cli/SKILL.md
```

**WorkBuddy / QClaw (Tencent):**

Upload `SKILL.md` through the skill management UI.

**Windsurf:**
```bash
cp SKILL.md /path/to/your/project/.skills/narrator-ai-cli/SKILL.md
```

**Claude Code / Cursor:**
```bash
cp SKILL.md /path/to/your/project/.skills/narrator-ai-cli/SKILL.md
```

**Any markdown-reading agent:**
```bash
cp SKILL.md /path/to/agent/skills/narrator-ai-cli/SKILL.md
```

> 💡 **Tip**: You can also just give the agent this repo URL — most agents can read the GitHub repo structure and auto-configure.

### Step 4: Start talking!

Once installed, use natural language:

- "Create a narration video for The Shawshank Redemption"
- "Show me what movies are available"
- "Make 5 narration videos for different action movies"
- "Use a comedy template and generate a narration"

---

---

## Tested Platforms

| Platform | Setup | Status |
|----------|-------|--------|
| **OpenClaw** | Native skill loading | ✅ Verified |
| **Windsurf** | .skills directory | ✅ Verified |
| **WorkBuddy** (Tencent) | Upload SKILL.md | ✅ Verified |
| **QClaw** (Tencent) | Upload SKILL.md | ✅ Verified |
| **Youdao Lobster** | Skill loading | ✅ Verified |
| **Yuanqi AI** | Skill loading | ✅ Verified |
| **Claude Code** | SKILL.md in project root | ✅ Verified |
| **Cursor** | rules/skills directory | ✅ Verified |
| Any markdown-skill agent | Point to SKILL.md | ✅ Compatible |

---

## Capabilities

| Feature | Details |
|---------|---------|
| Two workflow paths | Adapted Narration and Original Narration |
| Three creation modes | Hot Drama / Original Mix / New Drama |
| Built-in resources | 93 movies, 146 BGM tracks, 63 dubbing voices, 90+ narration templates |
| Full pipeline | Script → Clip data → Video composing → Visual template |
| Standalone tasks | Voice cloning, text-to-speech |
| Data flow mapping | Which output feeds into which input |
| Error handling | All 18 API error codes with recommended actions |
| Cost estimation | Budget verification before task creation |

### What's in SKILL.md

| Section | Description |
|---------|-------------|
| Frontmatter | Skill metadata (name, description, requirements) |
| Architecture | CLI source structure and design choices |
| Core Concepts | Key terms: file_id, task_id, order_num, etc. |
| Workflow Paths | Two complete pipelines with step-by-step commands |
| Prerequisites | How to select resources (materials, BGM, dubbing, templates) |
| Fast Path | Recommended workflow: search → write → clip → compose → magic |
| Standard Path | Full workflow: learn → write → clip → compose → magic |
| Standalone Tasks | Voice clone and TTS |
| Task Management | Query, list, budget, verify, save |
| File Operations | Upload, download, list, delete |
| Error Handling | All 18 API error codes with actions |
| Data Flow | ASCII diagram of complete pipeline |
| Important Notes | 9 critical gotchas and best practices |

---

## Requirements

- **CLI**: narrator-ai-cli v0.1.0+
- **Python**: 3.10+
- **Dependencies**: typer, httpx[socks], httpx-sse, pyyaml, rich
- **API key**: Contact us to get one

## Links

- 📦 [narrator-ai-cli CLI repo](https://github.com/jieshuo-ai/narrator-ai-cli)
- 📖 [Resource preview (Feishu Docs)](https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc)
- 🦞 [OpenClaw agent framework](https://github.com/openclaw/openclaw)

## Contact

Need an API key or help?

- 📧 Email: merlinyang@gridltd.com
- 💬 WeChat: Scan the QR code below

![Contact us](imgs/contact.png)

## License

MIT
