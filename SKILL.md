---
name: narrator-ai-cli
version: "1.0.3"
license: MIT
description: >-
  AI电影解说视频自动生成技能（AI解说大师 CLI Skill）。当用户需要创建电影解说视频、短剧解说、影视二创、AI配音旁白视频、film commentary、video narration、drama dubbing、movie narration时触发。内置93部电影素材、146首BGM、63种配音音色（11种语言）、90+解说模板。通过narrator-ai-cli命令行工具实现：搜片选片→选择模板→选BGM→选配音→生成文案→合成视频的全流程自动化。CLI client for Narrator AI (AI解说大师) video narration API. Use when user needs to create AI narration videos, manage narration tasks, browse dubbing/BGM/material resources, or automate video production.
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

CLI client for [Narrator AI](https://openapi.jieshuo.cn) video narration API. Designed for AI Agents and developers.

**CLI Repo**: https://github.com/GridLtd-ProductDev/narrator-ai-cli
**Resources Preview**: https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc

## Installation

```bash
# From GitHub release (recommended — pinned to a specific version)
pip install "narrator-ai-cli @ https://github.com/GridLtd-ProductDev/narrator-ai-cli/archive/refs/tags/v1.0.0.zip"

# Or from GitHub latest (tracks main branch)
pip install "narrator-ai-cli @ git+https://github.com/GridLtd-ProductDev/narrator-ai-cli.git"

# Or clone + editable install
git clone https://github.com/GridLtd-ProductDev/narrator-ai-cli.git
cd narrator-ai-cli && pip install -e .
```

Requires Python 3.10+. Dependencies: typer, httpx[socks], httpx-sse, pyyaml, rich.

## Setup

```bash
# Interactive setup (server URL + API key)
narrator-ai-cli config init

# Or set directly
narrator-ai-cli config set app_key <your_app_key>
# No API key yet? Contact support: WeChat `gezimufeng` or email merlinyang@gridltd.com

# Verify
narrator-ai-cli config show
narrator-ai-cli user balance
```

Config stored at `~/.narrator-ai/config.yaml` (permissions 0600).
Server defaults to `https://openapi.jieshuo.cn`.

**Environment variable overrides** (take precedence over config file):

| Variable | Description | Default |
|----------|-------------|---------|
| `NARRATOR_SERVER` | API server URL | `https://openapi.jieshuo.cn` |
| `NARRATOR_APP_KEY` | API key | (from config) |
| `NARRATOR_TIMEOUT` | Request timeout in seconds | 30 |

## Architecture

```
src/narrator_ai/
├── cli.py              # Typer main entry point, 7 sub-command groups
├── client.py           # httpx client: GET/POST/DELETE/SSE/upload, auto auth via app-key header
├── config.py           # YAML config (~/.narrator-ai/config.yaml), env var override
├── output.py           # Rich table + JSON dual output (--json flag)
├── commands/
│   ├── config_cmd.py   # config init/show/set
│   ├── user.py         # balance/login/keys/create-key
│   ├── task.py         # 9 task types, create/query/list/budget/verify/search-movie/narration-styles/templates/get-writing/save-writing/save-clip
│   ├── file.py         # 3-step upload (presigned URL → OSS PUT → callback), download/list/info/storage/delete
│   ├── materials.py    # 100+ pre-built movies (--page/--size pagination; no --genre/--search, filter locally)
│   ├── bgm.py          # 146 BGM tracks (--search filter)
│   └── dubbing.py      # 63 voices, 11 languages (--lang, --tag, --search filters)
└── models/
    └── responses.py    # API response codes (SUCCESS=10000, FAILED=10001, etc.) + task status constants
```

**Key design choices:**
- All commands support `--json` for machine-readable output (always use when parsing programmatically)
- Request body via `-d '{"key": "value"}'` or `-d @file.json`
- HTTP client uses `app-key` header (not Bearer token)
- SSE streaming supported for real-time task progress (`--stream`)
- File upload is 3-step: presigned URL → direct OSS upload → callback confirmation

## Core Concepts

| Concept | Description |
|---------|-------------|
| **file_id** | UUID for uploaded files. Via `file upload` or task results |
| **task_id** | UUID returned on task creation. Poll with `task query` |
| **task_order_num** | Assigned after task creation. Used as `order_num` for downstream tasks |
| **file_ids** | Output file IDs in completed task results. Input for next steps |
| **learning_model_id** | Narration style model. From popular-learning OR pre-built template (90+) |
| **learning_srt** | Reference SRT file_id. Only needed when NOT using learning_model_id |

## Two Workflow Paths

### Path 1: Adapted Narration (二创文案, Standard)

```
material list (local search) → [file upload if not in materials] → popular-learning → generate-writing → clip-data → video-composing → magic-video(optional)
```

### Path 2: Original Narration (原创文案, Fast & Cheaper)

```
material list (local search) → [search-movie if not in materials] → fast-writing → fast-clip-data → video-composing → magic-video(optional)
```

> ⚠️ **Agent behavior**: Before starting, always ask the user which path to use — **Standard** (二创文案, adapted narration) or **Fast** (原创文案, recommended). Do not auto-select a path.

### 3 Modes (target_mode for fast-writing)

| Mode | Name | Required Input |
|------|------|----------------|
| `"1"` | 热门影视 (纯解说) | `confirmed_movie_json` (from material data or `search-movie`); **no `episodes_data`** |
| `"2"` | 原声混剪 (Original Mix) | `confirmed_movie_json` + **`episodes_data[{srt_oss_key, num}]`** required |
| `"3"` | 冷门/新剧 (New Drama) | **`episodes_data[{srt_oss_key, num}]`** required; `confirmed_movie_json` optional |

## Resource Selection Protocol

**All resource selection steps require user confirmation before proceeding.** Follow these rules at every resource step:

1. **Never auto-select.** Always fetch options via CLI, present them to the user, and wait for explicit confirmation before using any resource in a task.
2. **Present up to 5–8 options** per resource type. Pre-filter by context (content genre, mood, language) to surface the most relevant candidates.
3. **Fallback when user has no preference.** If the user expresses no preference, present exactly **3 options** with a recommendation and the reasoning for each — still wait for confirmation before proceeding.
4. **Show the right fields.** Agent decides which fields to display per resource type, but always include the resource ID needed for the task parameter.
5. **Confirm one resource at a time.** Source files → BGM → Dubbing → Template. Do not advance to task creation until all required resources are confirmed.

## Prerequisites: Select Resources

Before creating any task, gather these resources first.

### 1. Source Files (Video + SRT)

> ⚠️ **Agent behavior**: Use `material list --json --page 1 --size 100` to fetch pre-built materials. Check the `total` field in the response — if `total > 100`, fetch additional pages until all items are retrieved. **Search programmatically using `grep` or `python3 -c` piped from the JSON output — do NOT rely on the terminal display, which may be truncated and can miss items.** Present **all matching results** (usually ≤ 3) to the user — show title, year, genre, and summary. Wait for the user to pick one before proceeding. If the user wants to upload their own files, guide them through the `file upload` flow for both video and SRT. Do NOT proceed to any writing step until `video_file_id` and `srt_file_id` are confirmed by the user.

```bash
# Option A: Pre-built materials (90+ movies, recommended)
narrator-ai-cli material list --json --page 1 --size 100
# If total > 100, fetch more pages: --page 2 --size 100, etc., until all items are retrieved
```

Response structure:

```json
{
  "total": 101,
  "page": 1,
  "size": 100,
  "items": [
    {
      "id": "<material_id>",
      "name": "极限职业",
      "title": "Extreme Job",
      "year": "2019",
      "type": "喜剧片",
      "story_info": "...",
      "character_name": "[柳承龙 (Ryu Seung-ryong), 李荷妮 (Lee Ha-nee), ...]",
      "cover": "https://...",
      "video_file_id": "<video_file_id>",
      "srt_file_id": "<srt_file_id>"
    }
  ]
}
```

```bash
# Search programmatically (case-insensitive) — do NOT rely on truncated terminal output:
narrator-ai-cli material list --json --page 1 --size 100 | grep -i "飞驰人生"
narrator-ai-cli material list --json --page 1 --size 100 \
  | python3 -c "import json, sys; items = json.load(sys.stdin).get('items', []); \
[print(json.dumps(i, ensure_ascii=False)) for i in items if '飞驰' in i.get('name','') or '飞驰' in i.get('title','')]"
```

**Material → `confirmed_movie_json` field mapping** (construct locally, no `search-movie` needed):

| Material field | `confirmed_movie_json` field | Notes |
|---|---|---|
| `name` | `local_title` | Chinese title |
| `title` | `title` | English title |
| `year` | `year` | |
| `type` | `genre` | e.g. `喜剧片` |
| `story_info` | `summary` | |
| `character_name` | `stars` | Parse JSON array string |
| (not in material) | `director` | Omit if unavailable |

```bash
# Option B: Upload your own
narrator-ai-cli file upload ./movie.mp4 --json    # Returns file_id
narrator-ai-cli file upload ./subtitles.srt --json
narrator-ai-cli file list --json
narrator-ai-cli file transfer --link "<url>" --json          # transfer by HTTP/Baidu/PikPak link
narrator-ai-cli file info <file_id> --json
narrator-ai-cli file download <file_id> --json
narrator-ai-cli file storage --json
narrator-ai-cli file delete <file_id> --json
```

Supported formats: .mp4, .mkv, .mov, .mp3, .m4a, .wav, .srt, .jpg, .jpeg, .png

### 2. BGM (Background Music)

> ⚠️ **Agent behavior**: Infer the mood/genre from context, then use `bgm list --search "<keyword>"` to pre-filter. Present **5–8 tracks** (Agent decides which fields best represent each track — e.g., name, style description). If the user has no preference, recommend **3 tracks** with a brief reason for each (e.g., "matches the film's fast-paced action tone") and wait for confirmation. Do NOT use a `bgm` ID in any task until the user confirms.

```bash
narrator-ai-cli bgm list --json                    # 146 tracks
narrator-ai-cli bgm list --search "单车" --json
# Returns: id (= bgm parameter in task creation)
```

### 3. Dubbing Voice

> ⚠️ **Agent behavior**: Infer the target language from context; if ambiguous, ask the user before listing. Run `dubbing list --lang <language>` to filter, then present **all matching voices** (typically < 15 per language) — include name and tags. If the user has no preference, recommend **3 voices** with reasoning (e.g., "neutral tone fits documentary narration style") and wait for confirmation. Do NOT use a dubbing `id` or `dubbing_type` in any task until the user confirms both.
>
> ⚠️ **Language linkage**: Once the dubbing voice is confirmed, the narration script language must match. If the selected voice is **not Chinese (普通话)**, the agent MUST set the `language` parameter in the writing task (fast-writing or generate-writing) to the corresponding language — do NOT leave it at the default `"Chinese (中文)"`. Carry this language value forward from the dubbing selection step to the writing task creation step. If the user has already specified a `language` value, verify it matches the dubbing language; if they conflict, surface the mismatch and ask the user to resolve it before proceeding.

```bash
narrator-ai-cli dubbing list --json                 # 63 voices, 11 languages
narrator-ai-cli dubbing list --lang 普通话 --json
narrator-ai-cli dubbing list --tag 喜剧 --json
narrator-ai-cli dubbing languages --json
narrator-ai-cli dubbing tags --json
# Returns: id (= dubbing), type (= dubbing_type)
```

Languages: 普通话(39), English(4), 日语(3), 韩语(2), Spanish(3), Portuguese(2), German(2), French(2), Arabic(2), Thai(2), Indonesian(2).

### 4. Narration Style Templates (90+, 12 genres)

> ⚠️ **Agent behavior**: Infer the content genre from context and run `task narration-styles --genre <genre>` to pre-filter. Present **3–5 templates** (Agent decides which fields best represent each). Also share the preview link https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc to help the user browse visually. If the user has no preference, recommend **3 templates** with a brief style description and reasoning, and wait for confirmation. Do NOT use a `learning_model_id` in any task until the user confirms.

```bash
narrator-ai-cli task narration-styles --json
narrator-ai-cli task narration-styles --genre 爆笑喜剧 --json
```

Genres: 热血动作, 烧脑悬疑, 励志成长, 爆笑喜剧, 灾难求生, 悬疑惊悚, 惊悚恐怖, 东方奇谈, 家庭伦理, 情感人生, 奇幻科幻, 传奇人物

Use `learning_model_id` from template directly — **no need for popular-learning step**.

## Fast Path Workflow (Recommended)

### Step 0: Find Source Material & Determine Mode

> ⚠️ **Agent behavior**: Confirm the movie or drama name with the user before proceeding (ask if not yet specified). Then follow this decision flow to determine source material and `target_mode`.

**Decision flow:**

1. Run `material list --json --page 1 --size 100`. Check `total` in the response — if `total > 100`, fetch subsequent pages until all items are retrieved. **Search programmatically using `grep -i` or `python3 -c` piped from the JSON output — do NOT rely on the terminal display, which may be truncated.** Repeat for each page until a match is found or all pages are exhausted.
2. **Found in pre-built materials** → construct `confirmed_movie_json` from material fields (see mapping in Prerequisites § Source Files). Present the match to the user and **ask which mode**:
   - **纯解说 / Pure narration (target_mode=1)**: Uses only movie metadata (title, synopsis, cast). Faster, no subtitle processing. Best for movies where the narration can be written from plot knowledge alone. **No `episodes_data`.**
   - **原声混剪 / Original mix (target_mode=2)**: Uses the actual subtitle track from the material (`srt_file_id`) to align narration with the original dialogue and scenes. More authentic, closer to the source. Requires `episodes_data` with `srt_oss_key = material.srt_file_id`.
3. **Not found in materials (known movie/drama)** → run `task search-movie` (see command below) → `target_mode=1`. Use returned `confirmed_movie_json`. **No `episodes_data`.**
4. **Not found, user provides their own SRT (known movie)** → run `task search-movie` for `confirmed_movie_json` → `target_mode=2`. Use uploaded SRT as `srt_oss_key` in `episodes_data`.
5. **Obscure/new drama, user provides SRT** → `target_mode=3`. `confirmed_movie_json` is optional. Use uploaded SRT in `episodes_data`.

**`search-movie` command** (run only for flows 3 and 4 above; never fabricate its output):

```bash
narrator-ai-cli task search-movie "飞驰人生" --json
```

Returns up to 3 results. Each result contains:

```json
{
  "title": "string",
  "local_title": "string",
  "year": "string",
  "director": "string",
  "stars": ["string"],
  "genre": "string",
  "summary": "string"
}
```

⚠️ May take **60+ seconds** (Gradio backend). Results cached 24h.

### Step 1: Fast Writing

Using the `target_mode`, `confirmed_movie_json`, and `episodes_data` determined in Step 0, create the fast-writing task:

```bash
# Case A1: Pre-built material found, user chose pure narration (target_mode=1)
#   No episodes_data. confirmed_movie_json mapped from material fields — see Prerequisites § Source Files.
narrator-ai-cli task create fast-writing --json -d @request.json
# request.json:
# {
#   "learning_model_id": "...",
#   "target_mode": "1",
#   "playlet_name": "飞驰人生",
#   "confirmed_movie_json": {<mapped from material — see field mapping table in Prerequisites>},
#   "model": "flash"
# }

# Case A2: Pre-built material found, user chose original mix (target_mode=2)
#   episodes_data uses material.srt_file_id. confirmed_movie_json from material fields.
narrator-ai-cli task create fast-writing --json -d @request.json
# request.json:
# {
#   "learning_model_id": "...",
#   "target_mode": "2",
#   "playlet_name": "飞驰人生",
#   "confirmed_movie_json": {<mapped from material — see field mapping table in Prerequisites>},
#   "episodes_data": [{"srt_oss_key": "<material.srt_file_id>", "num": 1}],
#   "model": "flash"
# }

# Case B: Not in pre-built materials, known movie (target_mode=1) — run search-movie in Step 0
narrator-ai-cli task create fast-writing --json -d @request.json
# request.json: {"learning_model_id": "...", "target_mode": "1", "playlet_name": "...",
#   "confirmed_movie_json": {<from search-movie>}, "model": "flash"}

# Case C: User's own SRT, known movie (target_mode=2) — run search-movie in Step 0 for confirmed_movie_json
narrator-ai-cli task create fast-writing --json -d @request.json
# request.json: {"learning_model_id": "...", "target_mode": "2", "playlet_name": "<drama name>",
#   "confirmed_movie_json": {<from search-movie>}, "episodes_data": [{"srt_oss_key": "<uploaded srt file_id>", "num": 1}], "model": "flash"}

# Case D: Obscure/new drama, user's own SRT (target_mode=3) — confirmed_movie_json optional
narrator-ai-cli task create fast-writing --json -d '{
  "learning_model_id": "<from narration-styles>",
  "target_mode": "3",
  "playlet_name": "<drama name>",
  "episodes_data": [{"srt_oss_key": "<uploaded srt file_id>", "num": 1}],
  "model": "flash"
}'
```

**Full parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `learning_model_id` | str | Exactly one (mutually exclusive with `learning_srt`) | - | Style model ID from a pre-built template or popular-learning result. **Do not provide both.** |
| `learning_srt` | str | Exactly one (mutually exclusive with `learning_model_id`) | - | Reference SRT file_id. Only use when no template or popular-learning model is available. **Do not provide both.** |
| `target_mode` | str | Yes | - | "1"=Hot Drama, "2"=Original Mix, "3"=New Drama |
| `playlet_name` | str | Yes | - | Movie/drama name |
| `playlet_num` | str | No | "1" | Episode/part number. Use `"1"` for single-episode content; increment for multi-part series. |
| `confirmed_movie_json` | obj | mode=1,2; optional mode=3 | - | From material data (mode=2 pre-built) or `search-movie` result (mode=1, mode=2 user SRT). Never fabricate. |
| `episodes_data` | list | mode=2,3 | - | For fast-writing: `[{srt_oss_key, num}]`. For fast-clip-data: `[{video_oss_key, srt_oss_key, negative_oss_key, num}]` — the video fields are added at the clip-data step. |
| `model` | str | No | "pro" | "pro" (higher quality, 15pts/char) or "flash" (faster, 5pts/char) |
| `language` | str | No | "Chinese (中文)" | Output language for the narration script. **Must match the selected dubbing voice language.** If the dubbing voice is non-Chinese, this param must be set explicitly — never leave it at the default when a non-Chinese voice is selected. |
| `perspective` | str | No | "third_person" | "first_person" or "third_person" |
| `target_character_name` | str | 1st person | - | Required when perspective=first_person |
| `custom_script_result_path` | str | No | - | Custom script result path |
| `webhook_url` | str | No | - | Async callback URL |
| `webhook_token` | str | No | - | Callback authentication token |
| `webhook_data` | str | No | - | Passthrough data for callback |

**Output**: Creation response contains only `data.task_id`. Poll `task query <task_id> --json` every 5 seconds until `status=2`. The completed task response contains `file_ids`:

```json
{
  "tasks": [{
    "task_id": "<task_id>",
    "order_num": "<order_num>"
  }],
  "file_ids": ["<file_id>"]
}
```

Save: `task_id` from the **creation response** (for fast-clip-data `task_id` input). Save `file_ids[0]` from the **completed task poll response** (for fast-clip-data `file_id` input).

### Step 2: Fast Clip Data

**Input**: `task_id` and `file_id` from Fast Writing (step 1), plus `bgm`, `dubbing`, `episodes_data`.

```bash
narrator-ai-cli task create fast-clip-data --json -d '{
  "task_id": "<task_id from step 1>",
  "file_id": "<file_id from step 1>",
  "bgm": "<bgm_id>",
  "dubbing": "<voice_id>",
  "dubbing_type": "<dubbing_type from selected voice>",
  "episodes_data": [{"video_oss_key": "<video_file_id>", "srt_oss_key": "<srt_file_id>", "negative_oss_key": "<video_file_id>", "num": 1}]
}'
```

**Output**: Creation response:

```json
{"code": 10000, "message": "", "data": {"task_id": ""}}
```

Save `data.task_id`. Poll `task query <task_id> --json` every 5 seconds until `status=2`. On success, read `task_order_num` from the task record — this is the `order_num` required for video-composing (step 3).

### Step 3: Video Composing

**IMPORTANT**: `order_num` comes from fast-clip-data (step 2) task record's task_order_num. This is the **only required parameter**.

```bash
narrator-ai-cli task create video-composing --json -d '{
  "order_num": "<task_order_num>"
}'
```

**Output**: On creation returns `data.task_id`. Poll `task query <task_id> --json` every 5 seconds until `status=2`. Extract `video_url` from results:

```json
{
  "tasks": [{
    "video_url": "https://oss.example.com/.../output.mp4"
  }]
}
```

Note: `type_name` is `video_composing` (no BGM) or `video_composing_2` (with BGM); both return `video_url` in the same structure.

### Step 4 (Optional): Magic Video — Visual Template

> ⚠️ **Agent restriction**: Do NOT auto-create magic-video tasks. Only create when the user explicitly requests a visual template. Present the template catalog, explain options, let the user choose. Multiple templates can be selected — each produces a separate output video.

**Visual Templates** is a value-added service applied after video composing:
- Adds professional subtitle styles and branded layouts to the finished video
- Multiple templates may be selected simultaneously (one output video per template)
- Pricing: **30 points/minute** (based on output video duration)

#### Template Catalog

Fetch real-time template details (params, descriptions, pricing):

```bash
curl -X GET "https://openapi.jieshuo.cn/v2/task/commentary/get_magic_template_info" \
    -H "app-key: $NARRATOR_APP_KEY"
```

Templates are organized by distribution platform and aspect ratio:

**油管 (YouTube)**

| Aspect Ratio | Template Name | Configurable Params |
|---|---|---|
| 9:16 垂直 | 竖屏·合规剧集 | 主标题, 底部免责文案, 侧边警示语, 分集设置 |
| 9:16 垂直 | 竖屏·柔光剧集 | 分集设置 |
| 9:16 垂直 | 竖屏·模糊剧集 | 主标题, 分集设置 |
| 9:16 垂直 | 竖屏·简约剧集 | 分集设置 |
| 9:16 垂直 | 竖屏·黑金剧集 | 主标题, 副标题, 分集设置 |
| 16:9 水平 | 横屏·沉浸剧集 | 分集设置 |
| 16:9 水平 | 横屏·电影剧集 | 主标题, 副标题, 分集设置 |
| 16:9 水平 | 横屏·简约剧集 | 分集设置 |

**抖音 (TikTok / Douyin)**

| Aspect Ratio | Template Name | Configurable Params |
|---|---|---|
| 1:1 矩形 | 方屏·简约剧集 | 主标题, 水印文案, 分集设置 |
| 1:1 矩形 | 方屏·雅致剧集 | 主标题, 分集设置 |
| 9:16 垂直 | 竖屏·流光剧集 | 顶部标语, 侧边文案, 分集设置 |

**油管短视频 (YouTube Shorts)**

| Aspect Ratio | Template Name | Configurable Params |
|---|---|---|
| 9:16 垂直 | 竖屏·精准剧集 | 分集设置 |
| 9:16 垂直 | 竖屏·重磅剧集 | 副标题 ⚠️, 分集设置 |

#### Template Param Reference

> ⚠️ **Agent behavior**: When the user selects a template, proactively walk through each of its configurable params, explain what it controls, and ask the user for a value. Only proceed to task creation once every param is confirmed or explicitly left at default.

> ⚠️ **Language awareness**: All text params (`main_title`, `sub_title`, `bottom_disclaimer_text`, `vertical_text_content`, `watermark_text`, `slogan`) have **Chinese default values hardcoded in the template** and do NOT auto-adapt to the target language. When the narration target language is **not Chinese**, the agent MUST:
> 1. **Never submit Chinese default values.** Submitting Chinese defaults will result in Chinese text appearing in a non-Chinese video — this is always wrong.
> 2. **Proactively provide localized values for every text param in the template.** Do not ask the user whether they want localization — assume yes and act on it.
> 3. **Translate the standard defaults to the target language and confirm with the user before submitting.** Do not skip this — even if the user hasn't mentioned it. Required translations by language:
>    - `bottom_disclaimer_text` default `本故事纯属虚构 请勿模仿` → e.g. English: `This story is purely fictional. Do not imitate.`
>    - `vertical_text_content` default `影视效果 请勿模仿 合理安排生活` → e.g. English: `Cinematic effects only. Do not imitate. Manage your life wisely.`
>    - `main_title`, `sub_title`, `watermark_text`, `slogan` — if left empty, AI may still generate Chinese; proactively ask for user input or suggest a translated value.
> 4. **This rule applies even when the user does not explicitly mention language.** The target language flows through the entire pipeline as a single chain: **dubbing voice language → narration script `language` param → magic-video template text params.** If the dubbing voice is non-Chinese, all three must be set to the matching language. Never treat these as independent decisions.
> 5. **All user-facing questions in this section (the "Ask the user" prompts below) must be asked in the same language as the ongoing conversation.** Do not default to Chinese if the conversation is in another language.
> 6. **Scope note**: This rule governs magic-video **template text params** only. The `language` param in fast-writing / generate-writing controls the narration script language and is handled at the writing step. Both are downstream consequences of the dubbing language selection and must be consistent.

All params are optional — omitting them lets AI auto-generate where supported. The table below explains what each param does and **how to fill it appropriately**.

---

**`segment_count` — 分集设置** (`int`, present in all templates)

Controls how the video is split into episodes:

| Value | Behavior | When to use |
|---|---|---|
| `0` (default) | AI auto-determines episode count based on content length | Recommended for most cases; let AI decide |
| `-1` | No splitting — output as a single video | When the source is short or the user wants one file |
| `1`, `2`, `3`… | Force exactly N episodes | When the user has a specific series structure in mind |

> Ask the user: "要分集吗？留 0 让 AI 自动判断，还是指定集数，或者 -1 不分集？"

---

**`main_title` — 主标题** (`string`, templates: 竖屏·合规剧集, 竖屏·模糊剧集, 竖屏·黑金剧集, 横屏·电影剧集, 方屏·简约剧集, 方屏·雅致剧集)

The primary title displayed prominently on screen.

- **Leave empty (recommended)**: AI generates the most fitting title from the content
- **Fill in**: When the user wants a custom series name, channel brand name, or the AI-generated title doesn't meet their expectation
- **Format tip**: Keep under 10–12 characters for vertical layouts; under 16 for horizontal. Avoid punctuation that may break layout.
- ⚠️ **Non-Chinese narration**: See Language Awareness rule above — leaving empty may cause AI to generate a Chinese title.

> Ask the user whether they want a custom title, or prefer AI to generate one. (Ask in the conversation language — see Language Awareness rule 5.)

---

**`sub_title` — 副标题** (`string`, templates: 竖屏·黑金剧集, 横屏·电影剧集, 竖屏·重磅剧集)

Secondary text displayed near the main title.

- **Leave empty (recommended)**: AI auto-generates a short tagline
- **Fill in**: When the user wants a specific promotional slogan or episode label
- ⚠️ **Special behavior in 竖屏·重磅剧集**: filling `sub_title` will **completely override the main title display** — the value you enter replaces whatever would appear as the main title. Only fill this if the user specifically wants to override the title.
- ⚠️ **Non-Chinese narration**: See Language Awareness rule above — leaving empty may cause AI to generate a Chinese tagline.

> Ask the user whether they want a custom subtitle. For 竖屏·重磅剧集, warn that filling this field will override the main title. (Ask in the conversation language — see Language Awareness rule 5.)

---

**`bottom_disclaimer_text` — 底部免责文案** (`string`, template: 竖屏·合规剧集 only)

Disclaimer text pinned to the bottom of the screen — required for compliance on many platforms.

- **Chinese narration — keep default**: Default value is `本故事纯属虚构 请勿模仿` — covers standard platform compliance requirements
- **Non-Chinese narration — MUST translate**: The default is Chinese and will display as Chinese text in a non-Chinese video. Translate to the target language (e.g. English: `This story is purely fictional. Do not imitate.`) and confirm with the user before submitting. **Do not submit the Chinese default for non-Chinese narration.**
- **Customize**: When the user's content has a specific legal disclaimer or the platform requires different wording
- **Do not leave blank**: An empty value removes the disclaimer, which may cause compliance issues on distribution platforms

> **Chinese narration**: "底部免责文案保留默认「本故事纯属虚构 请勿模仿」就好，有特殊合规需求才需要改。" — **Non-Chinese narration**: Translate the default to the target language, show the translated value to the user, and ask for confirmation or edits before submitting.

---

**`vertical_text_content` — 侧边警示语 / 侧边文案** (`string`, templates: 竖屏·合规剧集, 竖屏·流光剧集)

Vertical text displayed along the side edge of the screen.

- **Chinese narration — keep default**: Default is `影视效果 请勿模仿 合理安排生活` — standard compliance phrasing
- **Non-Chinese narration — MUST translate**: The default is Chinese and will display as Chinese text in a non-Chinese video. Translate to the target language (e.g. English: `Cinematic effects only. Do not imitate. Manage your life wisely.`) and confirm with the user before submitting. **Do not submit the Chinese default for non-Chinese narration.**
- **Customize**: When the user wants a channel-specific watermark phrase or branded vertical tagline
- **Format tip**: Keep concise; the text renders vertically, so shorter phrases look cleaner

> **Chinese narration**: "侧边文案保留默认合规文案即可，如需换成频道专属文案可以自定义。" — **Non-Chinese narration**: Translate the default to the target language, show the translated value to the user, and ask for confirmation or edits before submitting.

---

**`watermark_text` — 水印文案** (`string`, template: 方屏·简约剧集 only)

Copyright/brand text that roams randomly across the frame as a floating watermark.

- **Leave empty**: No watermark displayed
- **Fill in**: When the user wants copyright protection or channel branding (e.g., `@ChannelName`, `© Studio Name`)
- **Format tip**: Short phrases work best (under 15 characters); long text may look cluttered as it moves across the frame
- ⚠️ **Non-Chinese narration**: See Language Awareness rule above — value must be in the target language.

> Ask the user if they want a watermark. If yes, ask for the text. (Ask in the conversation language — see Language Awareness rule 5.)

---

**`slogan` — 顶部标语** (`string`, template: 竖屏·流光剧集 only)

Custom text that fills the entire top title bar, overriding whatever the AI would generate.

- **Leave empty (recommended)**: AI auto-generates a contextually appropriate top title
- **Fill in**: Only when the user has a fixed brand slogan or exclusive tagline they want locked in. Once filled, AI title generation for this slot is completely bypassed.
- ⚠️ **Non-Chinese narration**: See Language Awareness rule above — leaving empty may cause AI to generate a Chinese slogan.

> Ask the user if they want a fixed top slogan. (Ask in the conversation language — see Language Awareness rule 5.)

#### Creating a Magic Video

Input is the `task_id` returned from video-composing (step 3).

> ⚠️ **Agent behavior — mandatory pre-submission confirmation**: Before running any `magic-video` create command, the agent MUST display the full request parameters to the user in a readable format (templates selected, all `template_params` values for each template), then explicitly ask for confirmation. Do NOT submit until the user confirms. This applies every time a `magic-video` task is created — including multiple calls within the same session. Ask in the conversation language (not necessarily Chinese).

```bash
# Without custom params (AI handles all defaults)
narrator-ai-cli task create magic-video --json -d '{
  "task_id": "<task_id from step 3>",
  "template_name": ["竖屏·黑金剧集", "横屏·电影剧集"]
}'

# With custom params — key is template name, value is a params dict
narrator-ai-cli task create magic-video --json -d '{
  "task_id": "<task_id from step 3>",
  "template_name": ["竖屏·合规剧集"],
  "template_params": {
    "竖屏·合规剧集": {
      "segment_count": 0,
      "bottom_disclaimer_text": "本故事纯属虚构 请勿模仿",
      "vertical_text_content": "影视效果 请勿模仿 合理安排生活"
    }
  }
}'
```

**Output**: `sub_tasks` array — one entry per template, each with a rendered video URL

## Standard Path Workflow

### Step 0: Find Source Material

> ⚠️ **Agent behavior**: Confirm the movie or drama name with the user before proceeding. For material list usage, pagination, and programmatic search, see **Prerequisites § Source Files**.

**Decision flow:**

1. Run `material list --json` (all pages). Search programmatically — do NOT rely on terminal display.
2. **Found in pre-built materials** → use the material's `video_file_id` as `video_oss_key`/`negative_oss_key` and `srt_file_id` as `srt_oss_key` in `episodes_data` for Step 2 (generate-writing). No need to upload files.
3. **Not found** → guide user to upload their own video and SRT files via `file upload` (see Prerequisites § Source Files). Use the returned `file_id` values as `video_oss_key`/`negative_oss_key` and `srt_oss_key` in `episodes_data`.

### Step 1: Popular Learning (optional if using pre-built template)

```bash
narrator-ai-cli task create popular-learning --json -d '{
  "video_srt_path": "<srt_file_id from Step 0>",
  "narrator_type": "movie",
  "model_version": "advanced"
}'
```

**narrator_type options**: `短剧` `电影` `第一人称电影` `多语种电影` `第一人称多语种` `movie` `short_drama` `first_person_movie` `multilingual` `first_person_multilingual`

**model_version**: `advanced` (高级版) or `standard` (标准版)

**Output**: On creation returns `data.task_id`. Poll `task query <task_id> --json` every 5 seconds until `status=2`. Parse `task_result` JSON string → `agent_unique_code` is the `learning_model_id`:

```json
{
  "tasks": [{
    "task_result": "{\"agent_unique_code\": \"narrator-20251121160424-wjtOXO\"}"
  }]
}
```

→ `learning_model_id = "narrator-20251121160424-wjtOXO"`

Alternatively, use a pre-built template `id` from `task narration-styles --json` as `learning_model_id` directly — **no popular-learning step needed**.

### Step 2: Generate Writing

**Input**: Use `video_file_id` and `srt_file_id` determined in Step 0 to construct `episodes_data`:

| `episodes_data` field | Source |
|---|---|
| `video_oss_key` | `video_file_id` from material (Step 0) or uploaded video `file_id` |
| `negative_oss_key` | same as `video_oss_key` |
| `srt_oss_key` | `srt_file_id` from material (Step 0) or uploaded SRT `file_id` |
| `num` | episode number, starting from `1` |

```bash
narrator-ai-cli task create generate-writing --json -d '{
  "learning_model_id": "<from step 1 or pre-built template>",
  "playlet_name": "Movie Name",
  "playlet_num": "1",
  "episodes_data": [{"video_oss_key": "<video_file_id>", "srt_oss_key": "<srt_file_id>", "negative_oss_key": "<video_file_id>", "num": 1}],
  "refine_srt_gaps": false
}'
```

Optional: `refine_srt_gaps` (bool) — enables AI scene analysis. **Only set to `true` when user explicitly requests it.**

> ⚠️ **Language linkage**: If the selected dubbing voice is non-Chinese, add `"language": "<target language>"` to this request to match. Do not omit this param for non-Chinese dubbing — the default is Chinese.

**Output**: On creation returns `data.task_id`. Poll `task query <task_id> --json` every 5 seconds until `status=2`. Extract `task_result` (narration script file path) and `order_info` from results:

```json
{
  "tasks": [{
    "task_result": "video-clips-data/20251126/narrator/t_66449_47KIRY/narration.txt"
  }],
  "order_info": {
    "order_num": "script_69269bfc_GfVEgA"
  }
}
```

Save: `task_id` from the initial creation response — **required as input for clip-data step**.

### Step 3: Clip Data

**Input**: `task_id` from generate-writing (step 2), plus `bgm` and `dubbing`.

```bash
narrator-ai-cli task create clip-data --json -d '{
  "task_id": "<task_id from step 2 (generate-writing) creation response>",
  "bgm": "<bgm_id>",
  "dubbing": "<voice_id>",
  "dubbing_type": "<dubbing_type from selected voice>"
}'
```

**Output**: Creation response:

```json
{"code": 10000, "message": "", "data": {"task_id": ""}}
```

Save `data.task_id`. Poll `task query <task_id> --json` every 5 seconds until `status=2`. On success, read `task_order_num` from the task record — this is the `order_num` required for video-composing (step 4).

### Step 4-5: Video Composing & Magic Video

Same commands as Fast Path Steps 3–4. The only difference: `order_num` for video-composing comes from **clip-data** (this step's Step 3) `task_order_num`, not from fast-clip-data. In both paths, video-composing always uses the `task_order_num` from the immediately preceding clip step.


## Standalone Tasks

### Voice Clone

```bash
narrator-ai-cli task create voice-clone --json -d '{"audio_file_id": "<file_id>"}'
```

Optional: clone_model (default: pro). Output: task_id, voice_id.

### Text to Speech

```bash
narrator-ai-cli task create tts --json -d '{"voice_id": "<voice_id>", "audio_text": "Text to speak"}'
```

Optional: clone_model (default: pro). Output: task_id with audio result.

## Task Management

> ⚠️ **Agent behavior — standard polling pattern**: Always use the `while` loop below when monitoring a task. Never use a `for` loop with a fixed iteration count (it may exhaust before the task finishes). The loop below runs until status `2` (success) or `3` (failed) and cannot be silently interrupted mid-run.

```bash
# Standard polling loop — use this every time a task needs to be monitored
TASK_ID="<task_id>"
while true; do
  result=$(narrator-ai-cli task query "$TASK_ID" --json 2>&1)
  status=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    tasks = d.get('tasks') or d.get('data', {}).get('tasks', [])
    print(tasks[0].get('status', '') if tasks else '')
except Exception:
    print('')
" 2>/dev/null)
  echo "[$(date '+%H:%M:%S')] task=$TASK_ID status=$status"
  [ "$status" = "2" ] && echo "Done." && break
  [ "$status" = "3" ] && echo "Failed:" && echo "$result" && break
  sleep 5
done
```

```bash
# Single query (for spot-checks only — do not use in automated polling)
narrator-ai-cli task query <task_id> --json

# List tasks with filters
narrator-ai-cli task list --json
narrator-ai-cli task list --status 2 --type 9 --json    # completed fast-writing
narrator-ai-cli task list --category commentary --json

# Estimate points cost before creating
narrator-ai-cli task budget --json -d '{
  "learning_model_id": "<id>",
  "native_video": "<file_id>",
  "native_srt": "<file_id>"
}'
# Returns: viral_learning_points, commentary_generation_points, video_synthesis_points, visual_template_points, total_consume_points

# Verify materials before task creation
narrator-ai-cli task verify --json -d '{
  "bgm": "<file_id>",
  "dubbing_id": "<voice_id>",
  "native_video": "<file_id>",
  "native_srt": "<file_id>"
}'
# Returns: is_valid (bool), errors (list), warnings (list)

# Retrieve/save narration scripts
narrator-ai-cli task get-writing --json
narrator-ai-cli task save-writing -d '{...}'
narrator-ai-cli task save-clip -d '{...}'

# List task types with details
narrator-ai-cli task types -V
```

**Task type IDs** (for --type filter):

| ID | Type |
|----|------|
| 1 | popular_learning |
| 2 | generate_writing |
| 3 | video_composing |
| 4 | voice_clone |
| 5 | tts |
| 6 | clip_data |
| 7 | magic_video |
| 8 | subsync |
| 9 | fast_writing |
| 10 | fast_clip_data |

**Task status codes**: 0=init, 1=in_progress, 2=success, 3=failed, 4=cancelled.

## File Operations

```bash
narrator-ai-cli file upload ./video.mp4 --json       # 3-step: presigned → OSS → callback
narrator-ai-cli file transfer --link "<url>" --json  # import by HTTP/Baidu/PikPak link (alternative to upload)
narrator-ai-cli file list --json                       # pagination, --search filter
narrator-ai-cli file info <file_id> --json             # name, path, size, category, timestamps
narrator-ai-cli file download <file_id> --json         # returns presigned URL (time-limited)
narrator-ai-cli file storage --json                    # used_size, max_size, usage_percentage
narrator-ai-cli file delete <file_id> --json           # irreversible
```

File categories: 1=video, 2=audio, 3=image, 4=doc, 5=torrent, 6=other.

## User & Account

```bash
narrator-ai-cli user balance --json      # account points balance
narrator-ai-cli user login --json        # login with username/password
narrator-ai-cli user keys --json         # list sub API keys
narrator-ai-cli user create-key --json   # create a new sub API key
```

## Error Handling

> **Support Contact** (for balance/billing, app_key issues — including obtaining, renewing, or troubleshooting API keys): WeChat `gezimufeng`, or email `merlinyang@gridltd.com`

| Code | Meaning | Action |
|------|---------|--------|
| `10000` | Success | - |
| `10001` | Failed | Check params |
| `10002` | App key expired | Contact support to renew key (see **Support Contact** above) |
| `10003` | Sign expired | Check timestamp |
| `10004` | Invalid app key | Run `config show` to verify; if incorrect, contact support to obtain a valid key (see **Support Contact** above) |
| `10005` | Invalid sign | Check app_key config; contact support if issue persists (see **Support Contact** above) |
| `10006` | Invalid timestamp | Check clock sync |
| `10007` | Not found | Check resource ID |
| `10008` | Invalid method | Check HTTP method |
| `10009` | Insufficient balance | Contact support to top up (see **Support Contact** above) |
| `10010` | Task not found | Verify task_id |
| `10011` | Task create failed | Retry or check params |
| `10012` | Task type not found | Use `task types` to list valid types |
| `10013` | Insufficient balance (key) | Contact support to top up sub-key quota (see **Support Contact** above) |
| `40000` | Gradio timeout | Retry (backend overloaded) |
| `50000` | Unauthorized | Check app_key config; contact support if key is missing or invalid (see **Support Contact** above) |
| `50001` | Database error | Retry later |
| `50002` | System busy | Retry later |
| `50003` | System error | Contact support |
| `60000` | Retryable error | Safe to retry |

CLI exits code 1 on any error, prints to stderr.

## Data Flow Summary

```
                 material list / file upload → video_file_id, srt_file_id
                 bgm list → bgm_id
                 dubbing list → dubbing, dubbing_type
                 narration-styles → learning_model_id
                        │
    ┌───────────────────┼───────────────────────┐
    │  Standard Path    │           Fast Path    │
    │                   │                        │
    ▼                   │                        ▼
 material list --json   │         material list --json
 (local search)         │         (local search by title)
 found → video_file_id  │         found → ask user: mode=1 or mode=2?
         srt_file_id    │         mode=1: confirmed_movie_json from material
 not found → file upload│         mode=2: confirmed_movie_json + episodes_data from material
    │                   │         (both skip search-movie)
    ▼                   │         not found → search-movie (Step 0) → target_mode=1
 popular-learning       │         user SRT known → search-movie + target_mode=2
 OUT: learning_model_id │         user SRT obscure → target_mode=3 (optional confirmed_movie_json)
 (or use template)      │                        │
    ▼                   │                        ▼
    │                   │              fast-writing
 generate-writing       │              OUT: task_id, file_ids[0]
 OUT: task_id ─────────┬│                        │
    │                  ││                        ▼
    ▼                  ││              fast-clip-data
 clip-data             ││              IN: task_id + file_id
 IN: generate-writing  ││              OUT: clip task task_id
     task_id           ││                 
 OUT: clip task task_id ───────┴┴────────────────────────┘
                        │
                        ▼
                 video-composing
                 IN: order_num = task_order_num from preceding clip step
                     (clip-data in Standard Path; fast-clip-data in Fast Path)
                 OUT: task_id, tasks[0].video_url
                        │
                        ▼
                 magic-video (OPTIONAL — only on explicit user request)
                 IN: task_id (one-stop) OR file_ids[0] from clip-data (staged)
                     template_name (from 'task templates')
                 OUT: sub_tasks with rendered video URLs
```

## ⚠️ Important Notes

1. **`confirmed_movie_json` is required for target_mode=1 and target_mode=2, optional for target_mode=3.** When a pre-built material is found, construct it from material fields directly (no `search-movie` needed). For mode=1 or mode=2 with user-uploaded SRT (no material), always run `search-movie` — never fabricate this value.
2. **Source file_ids from `file list` or `material list`.** Never guess file_ids.
3. **Tasks are async.** Create returns `task_id` → poll `task query <task_id> --json` every **5 seconds** until status `2` (success) or `3` (failed). Most tasks complete in 30 seconds to several minutes; do not poll faster than 5 s to avoid unnecessary API load.
4. **`search-movie` may take 60+ seconds** (Gradio backend, cached 24h). Set adequate timeout.
5. **video-composing always uses `task_order_num` from the immediately preceding clip step** as its `order_num` param — clip-data in Standard Path, fast-clip-data in Fast Path. Never use the writing step's order_num.
6. **Prefer pre-built narration templates** over running popular-learning. Use `task narration-styles --json` to list, browse https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc for preview.
7. **Use `-d @file.json`** for large request bodies to avoid shell quoting issues.
8. **Use `task verify`** before creating expensive tasks to catch missing/invalid materials early.
9. **Use `task budget`** to estimate points cost before committing to a task.

## 🔒 Data & Privacy

- **API Endpoint**: All API requests are sent to `https://openapi.jieshuo.cn` (the Narrator AI service). No data is sent to any other third-party service.
- **File Upload**: The file upload flow (presigned URL → OSS PUT → callback) transfers user-provided media files to the Narrator AI cloud for server-side video processing. Uploaded files are bound to your account and are not shared publicly.
- **Credentials**: An API key (`NARRATOR_APP_KEY`) is required and stored locally at `~/.narrator-ai/config.yaml`. Keep this file private and do not commit it to version control.
- **Scope**: This skill only orchestrates CLI commands — it does not access, read, or transmit any files beyond those you explicitly provide as input to a task.
