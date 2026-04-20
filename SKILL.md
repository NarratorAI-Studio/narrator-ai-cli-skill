---
name: narrator-ai-cli
version: "1.0.4"
license: MIT
description: >-
  AI 电影/短剧解说视频自动生成（AI 解说大师 CLI Skill）。当用户需要创建电影解说视频、短剧解说、影视二创、AI 配音旁白视频、film commentary、video narration、drama dubbing、movie narration 时触发。内置电影素材库、BGM、多语种配音、解说模板。通过 narrator-ai-cli 命令行实现：搜片→选模板→选 BGM→选配音→生成文案→合成视频的全流程自动化。CLI client for Narrator AI video narration API.
user-invocable: true
tags:
  - video-narration
  - film-commentary
  - ai-video
  - short-drama
  - content-creation
  - dubbing
  - tts
  - video-production
metadata:
  openclaw:
    emoji: "🎬"
    primaryEnv: NARRATOR_APP_KEY
    install:
      - name: narrator-ai-cli
        type: pip
        spec: "narrator-ai-cli @ https://github.com/GridLtd-ProductDev/narrator-ai-cli/archive/refs/tags/v1.0.0.zip"
    requires:
      bins:
        - narrator-ai-cli
      env:
        - NARRATOR_APP_KEY
---

# narrator-ai-cli — AI Video Narration CLI Skill

CLI client for [Narrator AI](https://openapi.jieshuo.cn) video narration API. Designed for AI agents and developers.

- **CLI repo**: https://github.com/GridLtd-ProductDev/narrator-ai-cli
- **Resources preview** (BGM / dubbing / templates): https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc

## Reference Index

This file covers decision flow, the common workflow, and pointers. Detailed lookups live in `references/`:

| Topic | File |
|---|---|
| Resource selection (material / BGM / dubbing / templates) — list commands, response formats, field mapping | `references/resources.md` |
| Full workflow steps with parameter tables and JSON examples (Fast Path + Standard Path) | `references/workflows.md` |
| Magic Video — optional visual template step (catalog, params, language rules) | `references/magic-video.md` |
| Polling pattern, task types, file ops, user account, error codes | `references/operations.md` |

## Installation

```bash
# Recommended: pinned release
pip install "narrator-ai-cli @ https://github.com/GridLtd-ProductDev/narrator-ai-cli/archive/refs/tags/v1.0.0.zip"

# Or from main
pip install "narrator-ai-cli @ git+https://github.com/GridLtd-ProductDev/narrator-ai-cli.git"
```

Requires Python 3.10+.

## Setup

```bash
narrator-ai-cli config init                          # interactive (server URL + API key)
narrator-ai-cli config set app_key <your_app_key>
narrator-ai-cli config show
narrator-ai-cli user balance                         # verify
```

No API key? Contact: WeChat `gezimufeng` or email `merlinyang@gridltd.com`.

Config: `~/.narrator-ai/config.yaml` (mode 0600). Server defaults to `https://openapi.jieshuo.cn`.

**Env overrides** (take precedence over config file):

| Variable | Description | Default |
|---|---|---|
| `NARRATOR_SERVER` | API server URL | `https://openapi.jieshuo.cn` |
| `NARRATOR_APP_KEY` | API key | (from config) |
| `NARRATOR_TIMEOUT` | Request timeout (seconds) | 30 |

## Core Concepts

| Concept | Description |
|---|---|
| **file_id** | UUID for uploaded files. Via `file upload` or task results |
| **task_id** | UUID returned on task creation. Poll with `task query` |
| **task_order_num** | Assigned after task creation. Used as `order_num` for downstream tasks |
| **file_ids** | Output file IDs in completed task results. Input for next steps |
| **learning_model_id** | Narration style model — from a pre-built template (90+) or `popular-learning` result |
| **learning_srt** | Reference SRT file_id. **Mutually exclusive** with `learning_model_id` |

## Two Workflow Paths

Two end-to-end paths produce a finished narrated video. Choose with the user before starting.

| | **Fast Path** (原创文案, recommended) | **Standard Path** (二创文案) |
|---|---|---|
| Pipeline | material → fast-writing → fast-clip-data → video-composing → magic-video* | material → popular-learning** → generate-writing → clip-data → video-composing → magic-video* |
| Cost / speed | Faster, cheaper | Higher quality narration |
| When to use | Default unless user wants adapted-style narration | When user wants narration learned from a reference style |

\* magic-video is optional; only on explicit user request.
\*\* popular-learning is skippable when using a pre-built template (recommended).

> ⚠️ **Always ask the user which path to use** before starting. Do not auto-select.

### Fast Path `target_mode` (chooses fast-writing input shape)

| Mode | Use when | Required input |
|---|---|---|
| `"1"` 热门影视 (纯解说) | Known movie, narration from plot only | `confirmed_movie_json`; **no `episodes_data`** |
| `"2"` 原声混剪 (Original Mix) | Known movie + you have its SRT | `confirmed_movie_json` + `episodes_data[{srt_oss_key, num}]` |
| `"3"` 冷门/新剧 (New Drama) | Obscure/new content | `episodes_data[{srt_oss_key, num}]`; `confirmed_movie_json` optional |

## Resource Selection Protocol

Before any task, gather these resources **in this order, with explicit user confirmation at each step**:

1. **Source files** (video + SRT) — from `material list` or via `file upload`
2. **BGM** — from `bgm list`
3. **Dubbing voice** — from `dubbing list`
4. **Narration style template** — from `task narration-styles`

Detailed list commands, response shapes, and field mappings live in `references/resources.md`.

> ⚠️ **Universal rules — apply at every resource step:**
> 1. **Never auto-select.** Fetch options via CLI, present to user, wait for confirmation.
> 2. **Pre-filter by context.** Use `--search`, `--lang`, `--genre` flags to narrow results.
> 3. **Default presentation: 5–8 options** with the resource ID and key descriptive fields.
> 4. **If the user has no preference**: present **3 recommendations** with a one-line reason for each. Still wait for confirmation.
> 5. **Confirm one resource at a time.** Do not advance until the current one is confirmed.

> ⚠️ **Language linkage** (single source of truth — applies across the whole pipeline):
> Once the dubbing voice is confirmed, the narration script `language` param **must match** the voice's language. If the voice is **not Chinese (普通话)**, explicitly set `language` in fast-writing / generate-writing — do NOT leave the default `"Chinese (中文)"`. The same target language must also flow into magic-video template text params (see `references/magic-video.md`). If the user pre-specified a `language` value that conflicts with the chosen voice, surface the mismatch and ask before proceeding.

## Fast Path — High-Level Flow

> Detailed parameter tables, all `target_mode` cases, and full JSON examples live in `references/workflows.md`.

**Step 0 — Find source material & determine `target_mode`:**

1. List materials: `narrator-ai-cli material list --json --page 1 --size 100`. Search programmatically with `grep -i` or `python3 -c` on the JSON output — do **NOT** rely on the terminal display (may be truncated). Paginate (`--page 2`, etc.) until exhausted if `total > 100`.
2. **Found in materials** → ask user: pure narration (`mode=1`) or original mix (`mode=2`)? Construct `confirmed_movie_json` from material fields (mapping in `references/resources.md`).
3. **Not found, known title** → `task search-movie "<name>" --json` → `mode=1` (or `mode=2` if user uploads SRT). May take 60+ seconds (Gradio backend, results cached 24h).
4. **Obscure / new content** → `mode=3` with user's uploaded SRT. `confirmed_movie_json` optional.

**Step 1 — fast-writing**: pass `learning_model_id`, `target_mode`, `playlet_name`, `confirmed_movie_json` and/or `episodes_data`, `model` (`flash` 5pts/char or `pro` 15pts/char). Save `task_id` from the **creation response**, then poll until `status=2` and save `file_ids[0]` from the completed task.

**Step 2 — fast-clip-data**: pass `task_id` + `file_id` from Step 1, plus `bgm`, `dubbing`, `dubbing_type`, and `episodes_data` with `video_oss_key` / `srt_oss_key` / `negative_oss_key`. Poll until `status=2`; read `task_order_num` from the task record.

**Step 3 — video-composing**: pass `order_num: <task_order_num from Step 2>`. **Only required param.** Poll → `tasks[0].video_url` is the finished MP4.

**Step 4 (optional) — magic-video**: only on explicit user request. See `references/magic-video.md`.

## Standard Path — High-Level Flow

> Detailed parameter tables and JSON examples live in `references/workflows.md`.

**Step 0 — Source material**: same material/upload flow as Fast Path. Use `video_file_id` as `video_oss_key` and `negative_oss_key`, and `srt_file_id` as `srt_oss_key` in `episodes_data`.

**Step 1 — popular-learning** (skip if using a pre-built template): pass `video_srt_path`, `narrator_type`, `model_version`. Poll, then parse `task_result` JSON → `agent_unique_code` is the `learning_model_id`. Or use a pre-built template `id` from `task narration-styles --json` directly.

**Step 2 — generate-writing**: pass `learning_model_id`, `playlet_name`, `playlet_num`, `episodes_data`. Save `task_id` from the creation response.

**Step 3 — clip-data**: pass `task_id` from Step 2, plus `bgm`, `dubbing`, `dubbing_type`. Poll until `status=2`; read `task_order_num` from the task record.

**Step 4-5 — video-composing & (optional) magic-video**: identical to Fast Path Step 3-4. `order_num` for video-composing is the `task_order_num` from clip-data (this path) — never from the writing step.

## Standalone Tasks

```bash
# Voice clone — input audio_file_id, returns voice_id
narrator-ai-cli task create voice-clone --json -d '{"audio_file_id": "<file_id>"}'

# Text to speech — input voice_id + audio_text
narrator-ai-cli task create tts --json -d '{"voice_id": "<voice_id>", "audio_text": "Text to speak"}'
```

Both accept optional `clone_model` (default: `pro`).

## Important Notes

1. **`confirmed_movie_json` is required** for `target_mode=1` and `2`, optional for `3`. Construct from material fields when found in pre-built materials; use `search-movie` otherwise. **Never fabricate.**
2. **`file_id` always comes from `file list` or `material list`.** Never guess.
3. **Tasks are async.** Poll `task query <task_id> --json` every **5 seconds** until status `2` (success) or `3` (failed). Do not poll faster — see `references/operations.md` for the standard polling loop.
4. **`search-movie` may take 60+ seconds** (Gradio backend, results cached 24h).
5. **`video-composing.order_num` field-name trap**: video-composing's input parameter is named `order_num`, but its **value** must be the clip-step's `tasks[0].task_order_num` (a prefixed string like `fast_writing_clip_data_xxxxx`) — **NOT** `tasks[0].order_num` (a 32-char hex hash). Submitting the hex hash returns error `10001 任务关联记录数据异常`. Same parameter name, different semantics. Also: never use the writing step's order_num — always the immediately preceding clip step.
6. **Prefer pre-built templates** over `popular-learning`. List with `task narration-styles --json`; preview at the resources URL above.
7. **Use `-d @file.json`** for large request bodies to avoid shell quoting issues.
8. **Use `task verify`** before expensive tasks to catch missing/invalid materials early; **`task budget`** to estimate point cost.

## Data & Privacy

- **API endpoint**: All requests go to `https://openapi.jieshuo.cn`. No third-party services.
- **File upload**: presigned URL → OSS PUT → callback. Files are bound to your account, not public.
- **Credentials**: `NARRATOR_APP_KEY` stored at `~/.narrator-ai/config.yaml`. Keep private; do not commit.
- **Scope**: this skill only orchestrates the CLI; it does not access files outside what you explicitly pass as input.
