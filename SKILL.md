---
name: narrator-ai-cli
version: "1.0.0"
license: MIT
description: >-
  Create AI-narrated film/drama commentary videos via CLI.
  Two workflow paths (Original & Adapted narration), 93 movies,
  146 BGM tracks, 63 dubbing voices in 11 languages, 90+
  narration templates. Use when creating narration videos,
  film commentary, short drama dubbing, or video production.
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
        spec: "narrator-ai-cli @ https://github.com/jieshuo-ai/narrator-ai-cli/archive/refs/tags/v1.0.0.zip"
    requires:
      bins:
        - narrator-ai-cli
      env:
        - NARRATOR_APP_KEY
---

# narrator-ai-cli — AI Video Narration CLI Skill

CLI client for [Narrator AI](https://openapi.jieshuo.cn) video narration API. Designed for AI Agents and developers.

**CLI Repo**: https://github.com/jieshuo-ai/narrator-ai-cli
**Resources Preview**: https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc

## Installation

```bash
# From GitHub release (recommended — pinned to a specific version)
pip install "narrator-ai-cli @ https://github.com/jieshuo-ai/narrator-ai-cli/archive/refs/tags/v1.0.0.zip"

# Or from GitHub latest (tracks main branch)
pip install "narrator-ai-cli @ git+https://github.com/jieshuo-ai/narrator-ai-cli.git"

# Or clone + editable install
git clone https://github.com/jieshuo-ai/narrator-ai-cli.git
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
│   ├── materials.py    # 93 pre-built movies (--genre, --search filters)
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
popular-learning → generate-writing → clip-data → video-composing → magic-video(optional)
```

### Path 2: Original Narration (原创文案, Fast & Cheaper)

```
search-movie → fast-writing → fast-clip-data → video-composing → magic-video(optional)
```

### 3 Modes (target_mode for fast-writing)

| Mode | Name | Required Input |
|------|------|----------------|
| `"1"` | 热门影视 (Hot Drama) | `confirmed_movie_json` from `search-movie` |
| `"2"` | 原声混剪 (Original Mix) | `episodes_data[{srt_oss_key, num}]` |
| `"3"` | 冷门/新剧 (New Drama) | `episodes_data[{srt_oss_key, num}]` |

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

> ⚠️ **Agent behavior**: Run `material list --search "<movie name>"` and present **all returned results** (usually ≤ 3) to the user — show title, year, genre, and summary. Wait for the user to pick one before proceeding. If the user wants to upload their own files, guide them through the `file upload` flow for both video and SRT. Do NOT proceed to any writing step until `video_file_id` and `srt_file_id` are confirmed by the user.

```bash
# Option A: Pre-built materials (93 movies, recommended)
narrator-ai-cli material list --json
narrator-ai-cli material list --search "飞驰人生" --json
narrator-ai-cli material list --genre 喜剧片 --json
narrator-ai-cli material genres --json
# Returns: video_id (= video_oss_key & negative_oss_key), srt_id (= srt_oss_key)

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

### Step 0: Search Movie Info

**Required for target_mode=1.** Do NOT fabricate `confirmed_movie_json`.

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

```bash
# Save search result, then write full request body to a JSON file (required for confirmed_movie_json)
# request.json:
# {
#   "learning_model_id": "<from narration-styles>",
#   "target_mode": "1",
#   "playlet_name": "飞驰人生",
#   "confirmed_movie_json": { ...paste search-movie result object... },
#   "model": "flash"
# }
narrator-ai-cli task create fast-writing --json -d @request.json
```

**Full parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `learning_model_id` | str | One of two | - | Style model ID (from template or popular-learning) |
| `learning_srt` | str | One of two | - | Reference SRT file_id (when no template available) |
| `target_mode` | str | Yes | - | "1"=Hot Drama, "2"=Original Mix, "3"=New Drama |
| `playlet_name` | str | Yes | - | Movie/drama name |
| `confirmed_movie_json` | obj | mode=1 | - | From `search-movie` (MUST use search result) |
| `episodes_data` | list | mode=2,3 | - | [{srt_oss_key, num}] |
| `model` | str | No | "pro" | "pro" (higher quality, 15pts/char) or "flash" (faster, 5pts/char) |
| `language` | str | No | "Chinese (中文)" | Output language |
| `perspective` | str | No | "third_person" | "first_person" or "third_person" |
| `target_character_name` | str | 1st person | - | Required when perspective=first_person |
| `custom_script_result_path` | str | No | - | Custom script result path |
| `webhook_url` | str | No | - | Async callback URL |
| `webhook_token` | str | No | - | Callback authentication token |
| `webhook_data` | str | No | - | Passthrough data for callback |

**Output**: On creation returns `data.task_id`. Poll `task query <task_id> --json` until `status=2`. Extract `file_ids[0]`:

```json
{
  "tasks": [{
    "task_id": "nq_20260409132701_3fa1be",
    "order_num": "nq_20260409132701_3fa1be"
  }],
  "file_ids": ["1f599a1087354945892a082b72c680bf"]
}
```

Save: `task_id` from creation response (for fast-clip-data `task_id` input), `file_ids[0]` (for fast-clip-data `file_id` input).

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

Save `data.task_id`. Poll `task query <task_id> --json` until `status=2`. On success, read `task_order_num` from the task record — this is the `order_num` required for video-composing (step 3).

### Step 3: Video Composing

**IMPORTANT**: `order_num` comes from fast-clip-data (step 2). This is the **only required parameter**.

```bash
narrator-ai-cli task create video-composing --json -d '{
  "order_num": "<task_order_num from step 2>"
}'
```

**Output**: On creation returns `data.task_id`. Poll `task query <task_id> --json` until `status=2`. Extract `video_url` from results:

```json
{
  "tasks": [{
    "video_url": "https://oss.example.com/.../output.mp4"
  }]
}
```

Note: `type_name` is `video_composing` (no BGM) or `video_composing_2` (with BGM); both return `video_url` in the same structure.

### Step 4 (Optional): Magic Video — Visual Template

> ⚠️ **Agent restriction**: Do NOT auto-create magic-video tasks. Only create when the user explicitly requests a visual template. Present available templates as options and let the user choose.

```bash
# List templates first
narrator-ai-cli task templates --json

# One-stop mode (from video-composing task_id)
narrator-ai-cli task create magic-video --json -d '{
  "task_id": "<task_id from step 3>",
  "template_name": ["template_name"]
}'

# Staged mode (from clip-data/fast-clip-data file_ids[0])
narrator-ai-cli task create magic-video --json -d '{
  "file_id": "<file_ids[0] from clip-data or fast-clip-data results>",
  "template_name": ["template_name"]
}'
```

Optional: template_params (per-template params dict), mode (one_stop/staged), clip_data (JSON object for staged mode)

**Output**: sub_tasks with rendered video URLs

## Standard Path Workflow

### Step 1: Popular Learning (optional if using pre-built template)

```bash
narrator-ai-cli task create popular-learning --json -d '{
  "video_srt_path": "<srt_file_id>",
  "narrator_type": "movie",
  "model_version": "advanced"
}'
```

**narrator_type options**: `短剧` `电影` `第一人称电影` `多语种电影` `第一人称多语种` `movie` `short_drama` `first_person_movie` `multilingual` `first_person_multilingual`

**model_version**: `advanced` (高级版) or `standard` (标准版)

**Output**: On creation returns `data.task_id`. Poll `task query <task_id> --json` until `status=2`. Parse `task_result` JSON string → `agent_unique_code` is the `learning_model_id`:

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

**Output**: On creation returns `data.task_id`. Poll `task query <task_id> --json` until `status=2`. Extract `task_result` (narration script file path) and `order_info` from results:

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

Save `data.task_id`. Poll `task query <task_id> --json` until `status=2`. On success, read `task_order_num` from the task record — this is the `order_num` required for video-composing (step 4).

### Step 4-5: Same as Fast Path Steps 3-4

**IMPORTANT**: video-composing uses `order_num` from **clip-data (step 3)** `order_info.order_num`, NOT from generate-writing.

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

```bash
# Query task status (poll until status 2=success or 3=failed)
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
 popular-learning       │              search-movie
 OUT: learning_model_id │              OUT: confirmed_movie_json
 (or use template)      │                        │
    │                   │                        ▼
    ▼                   │              fast-writing
 generate-writing       │              OUT: task_id, file_ids[0]
 OUT: task_id ─────────┬│                        │
    │                  ││                        ▼
    ▼                  ││              fast-clip-data
 clip-data             ││              IN: task_id + file_id
 IN: generate-writing  ││              OUT: file_ids[0]
     task_id           ││                  order_info.order_num
 OUT: file_ids[0]      ││                        │
     order_info        ││                        │
     .order_num ───────┴┴────────────────────────┘
                        │
                        ▼
                 video-composing
                 IN: order_num (from clip-data or fast-clip-data!)
                     bgm, dubbing, dubbing_type
                 OUT: task_id, tasks[0].video_url
                        │
                        ▼
                 magic-video (OPTIONAL — only on explicit user request)
                 IN: task_id (one-stop) OR file_ids[0] from clip-data (staged)
                     template_name (from 'task templates')
                 OUT: sub_tasks with rendered video URLs
```

## ⚠️ Important Notes

1. **Always `search-movie` before fast-writing with target_mode=1.** Never fabricate `confirmed_movie_json` — it produces nonsensical narration.
2. **Source file_ids from `file list` or `material list`.** Never guess file_ids.
3. **Tasks are async.** Create returns `task_id` → poll `task query <task_id> --json` until status `2` (success) or `3` (failed).
4. **`search-movie` may take 60+ seconds** (Gradio backend, cached 24h). Set adequate timeout.
5. **video-composing uses the clip-data step's `order_info.order_num`** (clip-data in Standard Path, fast-clip-data in Fast Path). NOT the writing step's order_num — this is the most common mistake.
6. **Prefer pre-built narration templates** over running popular-learning. Use `task narration-styles --json` to list, browse https://ceex7z9m67.feishu.cn/wiki/WLPnwBysairenFkZDbicZOfKnbc for preview.
7. **Use `-d @file.json`** for large request bodies to avoid shell quoting issues.
8. **Use `task verify`** before creating expensive tasks to catch missing/invalid materials early.
9. **Use `task budget`** to estimate points cost before committing to a task.

## 🔒 Data & Privacy

- **API Endpoint**: All API requests are sent to `https://openapi.jieshuo.cn` (the Narrator AI service). No data is sent to any other third-party service.
- **File Upload**: The file upload flow (presigned URL → OSS PUT → callback) transfers user-provided media files to the Narrator AI cloud for server-side video processing. Uploaded files are bound to your account and are not shared publicly.
- **Credentials**: An API key (`NARRATOR_APP_KEY`) is required and stored locally at `~/.narrator-ai/config.yaml`. Keep this file private and do not commit it to version control.
- **Scope**: This skill only orchestrates CLI commands — it does not access, read, or transmit any files beyond those you explicitly provide as input to a task.
