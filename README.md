<p align="center">
  <a href="https://www.atlascloud.ai/?utm_source=github&utm_medium=link&utm_campaign=narrator-ai-cli-skill">
    <img src="assets/atlas-cloud-logo.png" alt="Atlas Cloud" width="140" />
  </a>
  <br />
  <sub><strong>Atlas Cloud</strong> provides OpenAI-compatible LLM APIs and async image/video generation APIs for narration, video, and agent-assisted media workflows.</sub>
</p>

# 🧠 Narrator AI CLI Skill — Teach Your AI Agent to Create Movie Narration Videos

[中文文档](README_CN.md)

> Install this Skill in your AI agent (OpenClaw, Windsurf, WorkBuddy, etc.), then just say "create a movie narration video" — the AI handles the rest.

## What is this?

A machine-readable skill file (`SKILL.md`) that teaches AI agents how to use the [narrator-ai-cli](https://github.com/NarratorAI-Studio/narrator-ai-cli) tool for automated video narration production.

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
pip install "narrator-ai-cli @ git+https://github.com/NarratorAI-Studio/narrator-ai-cli.git"
```

> See [narrator-ai-cli](https://github.com/NarratorAI-Studio/narrator-ai-cli) for detailed installation options.

### Step 2: Configure API key

```bash
narrator-ai-cli config set app_key <your_app_key>
```

> 📧 Need an API key? Email **merlinyang@gridltd.com** or scan the QR code at the bottom of this page.

### Step 3: Install the Skill

The skill consists of `SKILL.md` **and** the `references/` directory — both are required. Clone the repo directly into your agent's skills folder:

**OpenClaw:**
```bash
mkdir -p ~/.openclaw/skills
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  ~/.openclaw/skills/narrator-ai-cli
```

**Windsurf / Claude Code:**
```bash
mkdir -p /path/to/your/project/.skills
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  /path/to/your/project/.skills/narrator-ai-cli
```

**Cursor:**
```bash
mkdir -p /path/to/your/project/.cursor/rules
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  /path/to/your/project/.cursor/rules/narrator-ai-cli
```

**Any markdown-reading agent:**
```bash
mkdir -p /path/to/agent/skills
git clone https://github.com/NarratorAI-Studio/narrator-ai-cli-skill.git \
  /path/to/agent/skills/narrator-ai-cli
```

**WorkBuddy / QClaw (Tencent):**

Upload `SKILL.md` and the entire `references/` folder through the skill management UI, keeping the directory structure intact (`references/` must remain a subfolder alongside `SKILL.md` — do not flatten the files).

> 💡 **Tip**: To update the skill later, just run `git pull` inside the cloned directory.

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
| **OpenClaw** | `git clone` into skills directory | ✅ Verified |
| **Windsurf** | `git clone` into .skills directory | ✅ Verified |
| **WorkBuddy** (Tencent) | Upload SKILL.md + all files in references/ | ✅ Verified |
| **QClaw** (Tencent) | Upload SKILL.md + all files in references/ | ✅ Verified |
| **Youdao Lobster** | `git clone` into skills directory | ✅ Verified |
| **Yuanqi AI** | `git clone` into skills directory | ✅ Verified |
| **Claude Code** | `git clone` into project .skills directory | ✅ Verified |
| **Cursor** | `git clone` into .cursor/rules directory | ✅ Verified |
| Any markdown-skill agent | `git clone` repo, point agent to SKILL.md | ✅ Compatible |

---

## Capabilities

| Feature | Details |
|---------|---------|
| Two workflow paths | Adapted Narration and Original Narration |
| Three creation modes | Hot Drama / Original Mix / New Drama |
| Built-in resources | ~100 movies, 146 BGM tracks, 63 dubbing voices, 90+ narration templates |
| Full pipeline | Script → Clip data → Video composing → Visual template |
| Standalone tasks | Voice cloning, text-to-speech |
| Data flow mapping | Which output feeds into which input |
| Error handling | All 18 API error codes with recommended actions |
| Cost estimation | Budget verification before task creation |

### What's in SKILL.md

| Section | Description |
|---------|-------------|
| Frontmatter | Skill metadata (name, description, requirements) |
| Reference Index | Pointers to detailed lookup tables in `references/` (resources, workflows, magic-video, operations) |
| Pipeline at a Glance | ASCII diagram of Fast Path and Standard Path |
| Agent Rules | Mandatory rules: confirm before acting, language chain, polling pattern, etc. |
| Prerequisites | Assumes `narrator-ai-cli` is installed and `NARRATOR_APP_KEY` is set |
| Core Concepts | Key terms: file_id, task_id, task_order_num, etc. |
| Conversation Initiation | How to open a session and the decision sequence |
| Two Workflow Paths | Fast Path (Original Narration) vs Standard Path (Adapted Narration) |
| Resource Selection Protocol | BGM, dubbing, template selection order and rules |
| Fast Path | Steps 0–4 with parameter notes |
| Standard Path | Steps 0–5 with parameter notes |
| Standalone Tasks | Voice clone and TTS |
| Important Notes | 7 critical gotchas and best practices |
| Data & Privacy | API endpoint, file handling, credentials scope |

---

## Requirements

- **CLI**: narrator-ai-cli v1.0.0+
- **Python**: 3.10+
- **Dependencies**: typer, httpx[socks], httpx-sse, pyyaml, rich
- **API key**: Contact us to get one

## Links

- 📦 [narrator-ai-cli CLI repo](https://github.com/NarratorAI-Studio/narrator-ai-cli)
- 📖 [Resource preview (Feishu Docs)](https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc)
- 🦞 [OpenClaw agent framework](https://github.com/openclaw/openclaw)

## Contact

Need an API key or help?

- 📧 Email: merlinyang@gridltd.com
- 💬 WeChat: Scan the QR code below

![Contact us](imgs/contact.png)

## License

MIT
