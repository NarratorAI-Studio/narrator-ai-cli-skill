# Workflows — Detailed Steps

Full parameter tables and JSON request examples for both pipelines. The high-level flow lives in **SKILL.md § Fast Path / Standard Path**. Resource selection (material, BGM, dubbing, template) is covered in `resources.md`.

---

## Fast Path — Detailed Steps

### Step 0 — Find source material & determine `target_mode`

Decision flow (see `resources.md` for the material-list command and programmatic search):

1. **Found in pre-built materials** → construct `confirmed_movie_json` from material fields (mapping in `resources.md`). Ask user which mode:
   - **`mode=1` 纯解说 (Pure narration)**: only metadata (title, synopsis, cast). Faster, no subtitle processing. Best when narration can be written from plot knowledge alone. **No `episodes_data`.**
   - **`mode=2` 原声混剪 (Original mix)**: uses the actual subtitle track (`srt_file_id`) to align narration with original dialogue. More authentic. Requires `episodes_data` with `srt_oss_key = material.srt_file_id`.
2. **Not found, known movie/drama** → run `task search-movie` (below) → `mode=1` with the returned `confirmed_movie_json`. **No `episodes_data`.**
3. **Not found, user provides their own SRT (known movie)** → run `task search-movie` for `confirmed_movie_json` → `mode=2`. Use uploaded SRT as `srt_oss_key` in `episodes_data`.
4. **Obscure / new drama, user provides SRT** → `mode=3`. `confirmed_movie_json` optional. Use uploaded SRT in `episodes_data`.

**`search-movie` command** (only for cases 2 and 3 above; never fabricate its output):

```bash
narrator-ai-cli task search-movie "飞驰人生" --json
```

Returns up to 3 results, each:

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

### Step 1 — fast-writing

Construct the request body based on the `target_mode` chosen in Step 0:

```bash
narrator-ai-cli task create fast-writing --json -d @request.json
```

**Request shape by case** (use `-d @request.json` for readability; the four cases differ only in `target_mode`, `confirmed_movie_json`, and `episodes_data`):

| Case | `target_mode` | `confirmed_movie_json` | `episodes_data` |
|---|---|---|---|
| A1 — material found, pure narration | `"1"` | mapped from material fields | omit |
| A2 — material found, original mix | `"2"` | mapped from material fields | `[{srt_oss_key: <material.srt_file_id>, num: 1}]` |
| B — known movie via search-movie, pure narration | `"1"` | from `search-movie` result | omit |
| C — known movie + user SRT, original mix | `"2"` | from `search-movie` result | `[{srt_oss_key: <uploaded srt file_id>, num: 1}]` |
| D — obscure/new drama, user SRT | `"3"` | optional (omit if unknown) | `[{srt_oss_key: <uploaded srt file_id>, num: 1}]` |

**Example — Case D** (obscure drama):

```json
{
  "learning_model_id": "<from narration-styles>",
  "target_mode": "3",
  "playlet_name": "<drama name>",
  "episodes_data": [{"srt_oss_key": "<uploaded srt file_id>", "num": 1}],
  "model": "flash"
}
```

**Full parameter table:**

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `learning_model_id` | str | Exactly one (mutually exclusive with `learning_srt`) | - | Style model ID from a pre-built template or popular-learning result. **Do not provide both.** |
| `learning_srt` | str | Exactly one (mutually exclusive with `learning_model_id`) | - | Reference SRT file_id. Use only when no template / popular-learning model is available. **Do not provide both.** |
| `target_mode` | str | Yes | - | `"1"` Hot Drama, `"2"` Original Mix, `"3"` New Drama |
| `playlet_name` | str | Yes | - | Movie / drama name |
| `playlet_num` | str | No | `"1"` | Episode/part number. Use `"1"` for single-episode; increment for multi-part |
| `confirmed_movie_json` | obj | mode=1, 2; optional mode=3 | - | From material data (material found) or `search-movie` result. **Never fabricate.** |
| `episodes_data` | list | mode=2, 3 | - | For fast-writing: `[{srt_oss_key, num}]`. For fast-clip-data: `[{video_oss_key, srt_oss_key, negative_oss_key, num}]` — video fields added at the clip-data step |
| `model` | str | No | `"pro"` | `"pro"` (higher quality, 15 pts/char) or `"flash"` (faster, 5 pts/char) |
| `language` | str | No | `"Chinese (中文)"` | Output language for the narration script. **Must match the selected dubbing voice language.** If voice is non-Chinese, set this explicitly — never leave at default |
| `perspective` | str | No | `"third_person"` | `"first_person"` or `"third_person"` |
| `target_character_name` | str | 1st person | - | Required when `perspective=first_person` |
| `custom_script_result_path` | str | No | - | Custom script result path |
| `webhook_url` | str | No | - | Async callback URL |
| `webhook_token` | str | No | - | Callback authentication token |
| `webhook_data` | str | No | - | Passthrough data for callback |

**Output**: Creation response contains only `data.task_id`. Poll `task query <task_id> --json` every 5 s until `status=2`. The completed response contains `file_ids`:

```json
{
  "tasks": [{
    "task_id": "<task_id>",
    "task_order_num": "fast_writing_xxxxx",
    "order_num": "<32-char hex internal hash — NOT used downstream>"
  }],
  "file_ids": ["<file_id>"]
}
```

**Save**: `task_id` from the **creation response** (input to fast-clip-data), and `file_ids[0]` from the **completed poll response** (also input to fast-clip-data).

### Step 2 — fast-clip-data

```bash
narrator-ai-cli task create fast-clip-data --json -d '{
  "task_id": "<task_id from step 1>",
  "file_id": "<file_id from step 1>",
  "bgm": "<bgm_id>",
  "dubbing": "<voice_id>",
  "dubbing_type": "<dubbing_type from selected voice>",
  "episodes_data": [{
    "video_oss_key": "<video_file_id>",
    "srt_oss_key": "<srt_file_id>",
    "negative_oss_key": "<video_file_id>",
    "num": 1
  }]
}'
```

**Output**: Creation response → `data.task_id`. Poll until `status=2`. The completed task record contains **two different fields with similar names** — pick the right one:

| Field in `tasks[0]` | Format | Use as next step's `order_num`? |
|---|---|---|
| `task_order_num` | `fast_writing_clip_data_xxxxx` (prefixed string) | ✅ **YES — this is what video-composing wants** |
| `order_num` | `2c95333519417a28b0d9d754fc6b8cc5` (32-char hex) | ❌ Internal hash. Submitting this returns error `10001 任务关联记录数据异常` |

### Step 3 — video-composing

> ⚠️ **Field name collision warning**: video-composing's input parameter is also named `order_num`, but its **value** must be the `task_order_num` field from Step 2's task record — NOT the `order_num` field. They have the same parameter name but different semantics. If you submit the hex `order_num`, the API returns `10001 任务关联记录数据异常`.

```bash
narrator-ai-cli task create video-composing --json -d '{
  "order_num": "<value of tasks[0].task_order_num from Step 2 — looks like fast_writing_clip_data_xxxxx>"
}'
```

**`order_num` is the only required parameter.** Its value = fast-clip-data's `tasks[0].task_order_num` (the prefixed string), not `tasks[0].order_num` (the hex hash).

**Output**: Creation returns `data.task_id`. Poll until `status=2`. Extract `video_url`:

```json
{
  "tasks": [{
    "video_url": "https://oss.example.com/.../output.mp4"
  }]
}
```

`type_name` is `video_composing` (no BGM) or `video_composing_2` (with BGM); both return `video_url` in the same place.

### Step 4 (optional) — magic-video

Only on explicit user request. See `magic-video.md`.

---

## Standard Path — Detailed Steps

### Step 0 — Find source material

Same flow as Fast Path Step 0 but simpler — no `target_mode` decision. Either use a material's `video_file_id` + `srt_file_id`, or upload your own. Both feed directly into Step 2's `episodes_data`.

### Step 1 — popular-learning (optional if using a pre-built template)

```bash
narrator-ai-cli task create popular-learning --json -d '{
  "video_srt_path": "<srt_file_id from Step 0>",
  "narrator_type": "movie",
  "model_version": "advanced"
}'
```

**`narrator_type`**: `短剧`, `电影`, `第一人称电影`, `多语种电影`, `第一人称多语种`, `movie`, `short_drama`, `first_person_movie`, `multilingual`, `first_person_multilingual`.

**`model_version`**: `advanced` (高级版) or `standard` (标准版).

**Output**: Poll until `status=2`. Parse `task_result` (a JSON string) → `agent_unique_code` is the `learning_model_id`:

```json
{
  "tasks": [{
    "task_result": "{\"agent_unique_code\": \"narrator-20251121160424-wjtOXO\"}"
  }]
}
```

→ `learning_model_id = "narrator-20251121160424-wjtOXO"`

**Alternative (recommended)**: skip this step entirely — use a pre-built template `id` from `task narration-styles --json` directly as `learning_model_id`.

### Step 2 — generate-writing

`episodes_data` field sources:

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
  "target_platform": "douyin",
  "vendor_requirements": "",
  "target_character_name": "<protagonist name, or empty string>",
  "episodes_data": [{
    "video_oss_key": "<video_file_id>",
    "srt_oss_key": "<srt_file_id>",
    "negative_oss_key": "<video_file_id>",
    "num": 1
  }],
  "refine_srt_gaps": false
}'
```

**Required parameters:**

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `learning_model_id` | str | ✅ | From popular-learning result OR a pre-built template `id` |
| `playlet_name` | str | ✅ | Movie / drama name |
| `playlet_num` | str | ✅ | Episode number, e.g. `"1"` |
| `target_platform` | str | ✅ | Distribution platform — `"douyin"`, `"youtube"`, etc. **API rejects request if missing.** Ask the user; default to `"douyin"` if unspecified |
| `vendor_requirements` | str | ✅ | Custom vendor requirements. **Pass empty string `""` if none** — omitting the key returns `10001 vendor_requirements Field required` |
| `target_character_name` | str | ✅ | Protagonist name. **Required even for third-person narration** — pass empty string `""` if not applicable. API will return a Pydantic `string_type` error if `null` / missing |
| `episodes_data` | list | ✅ | Each entry **must contain all four** sub-fields: `video_oss_key`, `srt_oss_key`, `negative_oss_key`, `num`. Dropping `negative_oss_key` returns `第N个剧集缺少必要字段: negative_oss_key` |

**Optional parameters:**

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `refine_srt_gaps` | bool | `false` | Enables AI scene analysis. **Only set to `true` on explicit user request** |
| `language` | str | `"Chinese (中文)"` | Output language for the narration script — see Language linkage below |

> ⚠️ **Common 10001 errors and their fix** (in order — fix one and the next surfaces):
> 1. `target_platform Field required` → add `"target_platform": "douyin"` (or other platform)
> 2. `vendor_requirements Field required` → add `"vendor_requirements": ""`
> 3. `target_character_name ... Input should be a valid string` → add `"target_character_name": "<name or empty string>"`
> 4. `第N个剧集缺少必要字段: negative_oss_key` → ensure every `episodes_data` entry contains all of `video_oss_key`, `srt_oss_key`, `negative_oss_key`, `num`

> ⚠️ **Language linkage**: If the selected dubbing voice is non-Chinese, add `"language": "<target language>"` to this request. Default is Chinese; do NOT omit when using a non-Chinese voice. (See SKILL.md § Resource Selection Protocol § Language linkage.)

**Output**: Poll until `status=2`. The completed response includes:

```json
{
  "tasks": [{
    "task_result": "video-clips-data/.../narration.txt"
  }],
  "order_info": {
    "order_num": "script_69269bfc_GfVEgA"
  }
}
```

**Save (TWO different fields, both needed):**
- `task_id` from the **creation response** — used to poll Step 2 to completion
- `task_order_num` from the **completed task record** (after polling) — required as `order_num` input for clip-data in Step 3 (e.g. `generate_writing_19c237b0_4ee66d`)

### Step 3 — clip-data

> ⚠️ **Input field name differs from fast-clip-data**: `clip-data` takes **`order_num`** (value = generate-writing's `task_order_num`, the prefixed string). `fast-clip-data` in Fast Path takes `task_id` instead. Same conceptual chaining, different parameter name. Submitting `task_id` to `clip-data` returns `10001 请输入合成时的任务ID或者订单号`.

```bash
narrator-ai-cli task create clip-data --json -d '{
  "order_num": "<task_order_num from Step 2 — looks like generate_writing_xxxxx>",
  "bgm": "<bgm_id>",
  "dubbing": "<voice_id>",
  "dubbing_type": "<dubbing_type from selected voice>"
}'
```

**Output**: Creation returns `data.task_id`. Poll until `status=2`. The task record contains **two different fields with similar names** — same trap as Fast Path:

| Field in `tasks[0]` | Format | Use as next step's `order_num`? |
|---|---|---|
| `task_order_num` | prefixed string (e.g. `clip_data_xxxxx`) | ✅ **YES — this is what video-composing wants** |
| `order_num` | 32-char hex internal hash | ❌ Submitting this returns `10001 任务关联记录数据异常` |

### Step 4 — video-composing

Identical to Fast Path Step 3 — including the field-name-collision warning. `order_num` parameter value comes from clip-data's `tasks[0].task_order_num` (prefixed string), **not** `tasks[0].order_num` (hex hash).

### Step 5 (optional) — magic-video

Only on explicit user request. See `magic-video.md`.
