# Magic Video — Visual Templates (Optional Step)

> ⚠️ **Agent restriction**: Do NOT auto-create magic-video tasks. Only create when the user **explicitly requests** a visual template. Present the catalog, explain options, let the user choose. Multiple templates can be selected — each produces a separate output video.

Magic Video is a value-added service applied **after** video-composing:

- Adds professional subtitle styles and branded layouts to the finished video
- Multiple templates may be selected simultaneously (one output video per template)
- **Pricing: 30 points/minute** (based on output video duration)

**Input**: the `task_id` returned from `video-composing`.

---

## Template Catalog

Fetch real-time template details (params, descriptions, pricing) via API:

```bash
curl -X GET "https://openapi.jieshuo.cn/v2/task/commentary/get_magic_template_info" \
    -H "app-key: $NARRATOR_APP_KEY"
```

Templates are organized by distribution platform and aspect ratio.

### 油管 (YouTube)

| Aspect Ratio | Template Name | Configurable Params |
|---|---|---|
| 9:16 垂直 | 竖屏·合规剧集 | `main_title`, `bottom_disclaimer_text`, `vertical_text_content`, `segment_count` |
| 9:16 垂直 | 竖屏·柔光剧集 | `segment_count` |
| 9:16 垂直 | 竖屏·模糊剧集 | `main_title`, `segment_count` |
| 9:16 垂直 | 竖屏·简约剧集 | `segment_count` |
| 9:16 垂直 | 竖屏·黑金剧集 | `main_title`, `sub_title`, `segment_count` |
| 16:9 水平 | 横屏·沉浸剧集 | `segment_count` |
| 16:9 水平 | 横屏·电影剧集 | `main_title`, `sub_title`, `segment_count` |
| 16:9 水平 | 横屏·简约剧集 | `segment_count` |

### 抖音 (TikTok / Douyin)

| Aspect Ratio | Template Name | Configurable Params |
|---|---|---|
| 1:1 矩形 | 方屏·简约剧集 | `main_title`, `watermark_text`, `segment_count` |
| 1:1 矩形 | 方屏·雅致剧集 | `main_title`, `segment_count` |
| 9:16 垂直 | 竖屏·流光剧集 | `slogan`, `vertical_text_content`, `segment_count` |

### 油管短视频 (YouTube Shorts)

| Aspect Ratio | Template Name | Configurable Params |
|---|---|---|
| 9:16 垂直 | 竖屏·精准剧集 | `segment_count` |
| 9:16 垂直 | 竖屏·重磅剧集 | `sub_title` ⚠️, `segment_count` |

---

## Language Awareness (Critical)

> All text params (`main_title`, `sub_title`, `bottom_disclaimer_text`, `vertical_text_content`, `watermark_text`, `slogan`) have **Chinese default values hardcoded in the template** and do NOT auto-adapt to the target language.

When the narration target language is **not Chinese**, the agent MUST:

1. **Never submit Chinese default values.** Submitting Chinese defaults will produce Chinese text in a non-Chinese video — always wrong.
2. **Proactively provide localized values for every text param.** Do not ask the user whether they want localization — assume yes and act on it.
3. **Translate the standard defaults to the target language and confirm with the user before submitting.** Required translations:
   - `bottom_disclaimer_text` default `本故事纯属虚构 请勿模仿` → e.g. English: `This story is purely fictional. Do not imitate.`
   - `vertical_text_content` default `影视效果 请勿模仿 合理安排生活` → e.g. English: `Cinematic effects only. Do not imitate. Manage your life wisely.`
   - `main_title`, `sub_title`, `watermark_text`, `slogan` — if left empty, AI may still generate Chinese; proactively ask for user input or suggest a translated value.
4. **This rule applies even when the user does not mention language.** The pipeline language is a single chain (dubbing → writing `language` → magic-video text params) — see SKILL.md § Agent Rules ("Honor the language chain"). Never treat the three steps as independent.
5. **Ask all user-facing questions in the same language as the ongoing conversation.** Do not default to Chinese if the conversation is in another language.
6. **Scope**: this rule governs magic-video template text params only. The narration-script `language` param is handled at the writing step (`fast-writing` / `generate-writing`).

---

## Param Reference

> ⚠️ **Agent behavior**: When the user picks a template, walk through each of its configurable params, explain what it controls, and ask for a value. Only submit once every param is confirmed or explicitly left at default.

All params are optional — omitting them lets AI auto-generate where supported.

### `segment_count` — 分集设置 (`int`, in all templates)

Controls how the video is split into episodes:

| Value | Behavior | When to use |
|---|---|---|
| `0` (default) | AI auto-determines episode count based on content length | Recommended for most cases |
| `-1` | No splitting — output as a single video | Source is short, or user wants one file |
| `1`, `2`, `3`… | Force exactly N episodes | User has a specific series structure in mind |

> Ask: "要分集吗？留 `0` 让 AI 自动判断，指定集数，还是 `-1` 不分集？"

### `main_title` — 主标题 (`string`)

Templates: 竖屏·合规剧集, 竖屏·模糊剧集, 竖屏·黑金剧集, 横屏·电影剧集, 方屏·简约剧集, 方屏·雅致剧集.

Primary title displayed prominently on screen.

- **Leave empty (recommended)**: AI generates the most fitting title from content
- **Fill in**: when the user wants a custom series name, channel brand, or overrides the AI-generated title
- **Format tip**: keep under 10–12 chars for vertical layouts; under 16 for horizontal. Avoid layout-breaking punctuation
- ⚠️ **Non-Chinese narration**: leaving empty may cause AI to generate a Chinese title. See Language Awareness above

> Ask whether the user wants a custom title or prefers AI-generated. (In the conversation language.)

### `sub_title` — 副标题 (`string`)

Templates: 竖屏·黑金剧集, 横屏·电影剧集, 竖屏·重磅剧集.

Secondary text displayed near the main title.

- **Leave empty (recommended)**: AI auto-generates a short tagline
- **Fill in**: when user wants a specific promotional slogan or episode label
- ⚠️ **Special behavior in 竖屏·重磅剧集**: filling `sub_title` will **completely override the main title display** — the value entered replaces whatever would appear as main title. Only fill if the user specifically wants to override
- ⚠️ **Non-Chinese narration**: leaving empty may cause AI to generate a Chinese tagline

> Ask whether the user wants a custom subtitle. For 竖屏·重磅剧集, warn that filling will override main title.

### `bottom_disclaimer_text` — 底部免责文案 (`string`)

Template: 竖屏·合规剧集 only.

Disclaimer pinned to the bottom of the screen — required for compliance on many platforms.

- **Chinese narration — keep default**: `本故事纯属虚构 请勿模仿` covers standard platform compliance
- **Non-Chinese narration — MUST translate**: default is Chinese and would display as Chinese in a non-Chinese video. Translate to target language (e.g. English: `This story is purely fictional. Do not imitate.`) and confirm before submitting. **Do NOT submit the Chinese default for non-Chinese narration.**
- **Customize**: when user has a specific legal disclaimer or platform requires different wording
- **Do not leave blank**: empty value removes the disclaimer, which may cause compliance issues

> Chinese narration: "底部免责文案保留默认「本故事纯属虚构 请勿模仿」就好，有特殊合规需求才需要改。"
> Non-Chinese narration: translate default → show translated value → ask for confirmation/edits.

### `vertical_text_content` — 侧边警示语 / 侧边文案 (`string`)

Templates: 竖屏·合规剧集, 竖屏·流光剧集.

Vertical text displayed along the side edge.

- **Chinese narration — keep default**: `影视效果 请勿模仿 合理安排生活` is standard compliance phrasing
- **Non-Chinese narration — MUST translate**: default is Chinese (e.g. English: `Cinematic effects only. Do not imitate. Manage your life wisely.`). Confirm before submitting. **Do NOT submit the Chinese default for non-Chinese narration.**
- **Customize**: channel-specific watermark phrase or branded vertical tagline
- **Format tip**: keep concise — text renders vertically, shorter phrases look cleaner

> Same prompts as `bottom_disclaimer_text` above.

### `watermark_text` — 水印文案 (`string`)

Template: 方屏·简约剧集 only.

Copyright/brand text that roams randomly across the frame as a floating watermark.

- **Leave empty**: no watermark displayed
- **Fill in**: copyright protection or channel branding (e.g. `@ChannelName`, `© Studio Name`)
- **Format tip**: short phrases work best (under 15 chars) — long text looks cluttered as it moves
- ⚠️ **Non-Chinese narration**: value must be in the target language

> Ask if the user wants a watermark. If yes, ask for the text.

### `slogan` — 顶部标语 (`string`)

Template: 竖屏·流光剧集 only.

Custom text that fills the entire top title bar, overriding whatever the AI would generate.

- **Leave empty (recommended)**: AI auto-generates a contextually appropriate top title
- **Fill in**: only when the user has a fixed brand slogan or exclusive tagline. Once filled, AI title generation for this slot is bypassed
- ⚠️ **Non-Chinese narration**: leaving empty may cause AI to generate a Chinese slogan

> Ask if the user wants a fixed top slogan.

---

## Creating a Magic Video

> ⚠️ **Agent behavior — mandatory pre-submission confirmation**: Before running any `magic-video` create command, the agent MUST display the full request parameters to the user in a readable format (templates selected, all `template_params` values for each template), then explicitly ask for confirmation. Do NOT submit until the user confirms. This applies **every time** a `magic-video` task is created — including multiple calls within the same session. Ask in the conversation language.

```bash
# Without custom params (AI handles all defaults)
narrator-ai-cli task create magic-video --json -d '{
  "task_id": "<task_id from video-composing>",
  "template_name": ["竖屏·黑金剧集", "横屏·电影剧集"]
}'

# With custom params — key is template name, value is params dict
narrator-ai-cli task create magic-video --json -d '{
  "task_id": "<task_id from video-composing>",
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

**Output**: `sub_tasks` array — one entry per template, each with a rendered video URL.
