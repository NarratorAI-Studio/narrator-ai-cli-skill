# narrator-ai-cli Skill

> AI Agent skill for [narrator-ai-cli](https://github.com/jieshuo-ai/narrator-ai-cli) — CLI client for Narrator AI video narration API.

## What is this?

A machine-readable skill file (`SKILL.md`) that teaches AI agents how to use the `narrator-ai-cli` tool for automated video narration production.

When loaded by an AI agent (e.g., [OpenClaw](https://github.com/openclaw/openclaw), Claude Code, Cursor, Windsurf), it provides structured instructions for the complete video narration pipeline.

## Capabilities

- **Two workflow paths**: Adapted Narration (二创文案) and Original Narration (原创文案)
- **Three modes**: Hot Drama / Original Mix / New Drama
- **Pre-built resources**: 93 movies, 146 BGM tracks, 63 dubbing voices, 90+ narration style templates across 12 genres
- **Full pipeline**: narration script → clip data → video composing → magic video
- **Standalone tasks**: voice cloning, text-to-speech
- **Complete data flow mapping**: which output feeds into which input
- **Error handling**: all 18 API error codes with recommended actions
- **Cost estimation**: budget and material verification before task creation

## Quick Start

### 1. Install the CLI tool

```bash
pip install "narrator-ai-cli @ git+https://github.com/jieshuo-ai/narrator-ai-cli.git"
```

### 2. Configure API key

```bash
narrator-ai-cli config set app_key <your_app_key>
```

### 3. Install the skill

**OpenClaw:**

```bash
mkdir -p ~/.openclaw/skills/narrator-ai-cli
cp SKILL.md ~/.openclaw/skills/narrator-ai-cli/SKILL.md
```

**Claude Code / Cursor / Windsurf:**

```bash
# Copy to your project's agent skills directory
cp SKILL.md /path/to/your/project/.skills/narrator-ai-cli/SKILL.md
```

**Or any agent that reads markdown skill files:**

```bash
cp SKILL.md /path/to/agent/skills/narrator-ai-cli/SKILL.md
```

## What's in SKILL.md?

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

## Compatibility

| Platform | Tested | Notes |
|----------|--------|-------|
| OpenClaw | ✅ | Native skill loading |
| Claude Code | ✅ | SKILL.md in project root |
| Cursor | ✅ | Via rules/skills directory |
| Windsurf | ✅ | Via rules directory |
| Any markdown-reading agent | ✅ | Just point to SKILL.md |

## CLI Requirements

- **CLI**: narrator-ai-cli v0.1.0+
- **Python**: 3.10+
- **Dependencies**: typer, httpx[socks], httpx-sse, pyyaml, rich
- **API key**: Get from Narrator AI platform

## Links

- [narrator-ai-cli CLI repo](https://github.com/jieshuo-ai/narrator-ai-cli)
- [Narrator AI resources preview (Feishu)](https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc)
- [OpenClaw agent framework](https://github.com/openclaw/openclaw)

## Contact

![Contact](imgs/contact.png)

## License

MIT
