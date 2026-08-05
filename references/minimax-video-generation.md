# MiniMax Video Generation (Optional)

> Back to [SKILL.md](../SKILL.md)

Use this optional path only when the user explicitly asks for a generated video asset, such as original B-roll, a transition, or a standalone clip for a Narrator AI project. It is not part of the default narration pipeline and must not replace source footage unless the user has the right to generate and use that footage.

This reference covers both MiniMax video API generations:

- **v2 default:** `MiniMax-H3` with content-based requests at `/v2/video_generation`.
- **v1 compatibility:** the listed Hailuo, T2V, and I2V models with prompt-based requests at `/v1/video_generation`.

## Confirm Before Submitting

A generation request may be billable and irreversible. Before the `POST` request, show the user and confirm:

- the selected API region, API version, and video model
- text-to-video, image-to-video, first/last-frame-to-video, or reference-to-video mode
- the exact prompt and every image, video, or audio content item
- every optional request field, including ratio, callback URL, and the China-only `aigc_watermark` field
- the required resolution and duration
- the maximum number of five-second status checks
- the expected cost calculated from the selected region's pricing below

Do not automatically retry the generation `POST`. A retry can create and charge for a duplicate task.

For a v2 `MiniMax-H3` request, also enforce these limits before asking for final approval:

- include one non-empty text item; total text must not exceed 7,000 characters
- use `2K` resolution and an integer duration from 4 through 15 seconds
- use only `text`, `image_url`, `video_url`, and `audio_url` content types
- use only `first_frame`, `last_frame`, `reference_image`, `reference_video`, and `reference_audio` roles
- include an image or video when using `reference_audio`
- do not mix first/last-frame roles with reference roles in the same request
- keep the complete request body at or below 64 MB

## Regions, Models, and Pricing

Choose one regional API origin with the user:

| Region | API origin | v2 create endpoint | v1 create endpoint |
|---|---|---|---|
| Global | `https://api.minimax.io` | `https://api.minimax.io/v2/video_generation` | `https://api.minimax.io/v1/video_generation` |
| China | `https://api.minimaxi.com` | `https://api.minimaxi.com/v2/video_generation` | `https://api.minimaxi.com/v1/video_generation` |

| API version | Models |
|---|---|
| v2 | `MiniMax-H3` (default) |
| v1 | `MiniMax-Hailuo-2.3`, `MiniMax-Hailuo-2.3-Fast`, `MiniMax-Hailuo-02`, `T2V-01-Director`, `T2V-01`, `I2V-01-Director`, `I2V-01-live`, `I2V-01` |

`MiniMax-H3` was released on 2026-07-31. It accepts text, image, video, and audio input; supports text-to-video, image-to-video, first/last-frame-to-video, and reference-to-video; and returns video and audio output.

| Region | Output video | Reference video | Reference audio | Reference images |
|---|---|---|---|---|
| Global | USD 0.13 per 2K output second | USD 0.02 per 2K input second | Free | First 5 free, then USD 0.03 per image |
| China | CNY 0.8 per 2K output second | CNY 0.8 per 2K input second | Free | First 5 free, then CNY 0.2 per image |

Keep the API key in the environment and never place it in `request.json` or a committed file.

```bash
export MINIMAX_API_KEY="<your MiniMax API key>"

# Global
export MINIMAX_API_BASE="https://api.minimax.io"

# China (use this instead of the global value when selected)
# export MINIMAX_API_BASE="https://api.minimaxi.com"

export MINIMAX_VIDEO_API_VERSION="${MINIMAX_VIDEO_API_VERSION:-v2}"
export MINIMAX_VIDEO_MODEL="${MINIMAX_VIDEO_MODEL:-MiniMax-H3}"
export MINIMAX_MAX_POLLS="<approved positive integer>"

case "${MINIMAX_API_KEY:-}" in
  ""|"<"*) echo "Set MINIMAX_API_KEY before continuing." >&2; exit 1 ;;
esac
case "${MINIMAX_API_BASE:-}" in
  https://api.minimax.io|https://api.minimaxi.com) ;;
  *) echo "Select a documented MINIMAX_API_BASE value." >&2; exit 1 ;;
esac
case "${MINIMAX_VIDEO_API_VERSION:-}" in
  v2)
    [ "$MINIMAX_VIDEO_MODEL" = "MiniMax-H3" ] || {
      echo "MiniMax-H3 is the supported v2 model." >&2
      exit 1
    }
    ;;
  v1)
    case "$MINIMAX_VIDEO_MODEL" in
      MiniMax-Hailuo-2.3|MiniMax-Hailuo-2.3-Fast|MiniMax-Hailuo-02|T2V-01-Director|T2V-01|I2V-01-Director|I2V-01-live|I2V-01) ;;
      *) echo "Select a documented v1 video model." >&2; exit 1 ;;
    esac
    ;;
  *) echo "Set MINIMAX_VIDEO_API_VERSION to v2 or v1." >&2; exit 1 ;;
esac
case "${MINIMAX_MAX_POLLS:-}" in
  ""|"<"*|0*|*[!0-9]*)
    echo "Set MINIMAX_MAX_POLLS to a positive integer." >&2
    exit 1
    ;;
esac
```

## Build a v2 Request

The v2 create operation requires `model`, `content`, `resolution`, and `duration`. `ratio` and `callback_url` are optional. The allowed ratio values are `adaptive`, `21:9`, `16:9`, `4:3`, `1:1`, `3:4`, and `9:16`.

For text-to-video, start with the required text content:

```bash
PROMPT="<approved prompt>"
DURATION_SECONDS=5

jq -n \
  --arg model "$MINIMAX_VIDEO_MODEL" \
  --arg prompt "$PROMPT" \
  --argjson duration "$DURATION_SECONDS" \
  '{
    model: $model,
    content: [
      {type: "text", text: $prompt}
    ],
    resolution: "2K",
    duration: $duration
  }' > request.json
```

For image-to-video, add the approved image as a `first_frame` content item:

```bash
PROMPT="<approved prompt>"
FIRST_FRAME_URL="<approved image URL>"
DURATION_SECONDS=5

jq -n \
  --arg model "$MINIMAX_VIDEO_MODEL" \
  --arg prompt "$PROMPT" \
  --arg first_frame_url "$FIRST_FRAME_URL" \
  --argjson duration "$DURATION_SECONDS" \
  '{
    model: $model,
    content: [
      {type: "text", text: $prompt},
      {
        type: "image_url",
        image_url: {url: $first_frame_url},
        role: "first_frame"
      }
    ],
    resolution: "2K",
    duration: $duration,
    ratio: "adaptive"
  }' > request.json
```

Use `last_frame`, `reference_image`, `reference_video`, or `reference_audio` only when that role matches the user's approved mode. Add `callback_url` only when the user approved it. Add `aigc_watermark` only for the China endpoint and only after approval.

Show the complete `request.json` to the user and get final confirmation before continuing.

## Create the v2 Task

```bash
jq -e 'type == "object"' request.json >/dev/null || exit 1

if ! CREATE_RESPONSE="$(curl -sS --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  -X POST "$MINIMAX_API_BASE/v2/video_generation" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d @request.json)"; then
  echo "Task creation failed or timed out; do not resubmit automatically." >&2
  exit 1
fi

jq -e . >/dev/null <<<"$CREATE_RESPONSE" || exit 1
TASK_ID="$(jq -r '.task_id // empty' <<<"$CREATE_RESPONSE")"
[ -n "$TASK_ID" ] || {
  printf '%s\n' "$CREATE_RESPONSE" | jq .
  exit 1
}
```

Do not repeat this command automatically if the response is interrupted or ambiguous. Query the returned task ID when available; otherwise ask the user before creating another task.

## Poll and Retrieve the v2 Result

Poll `GET /v2/query/video_generation/{task_id}` at five-second intervals. The response exposes `task.id`, `task.model`, `task.status`, `task.error`, `task.content.url`, `task.resolution`, `task.duration`, `task.usage.total_seconds`, `task.usage.input_seconds`, `task.usage.output_seconds`, `task.usage.image_count`, `task.ratio`, `task.task_type`, and `task.modality`.

```bash
POLL_COUNT=0
TASK_STATUS=""
DOWNLOAD_URL=""

while [ "$POLL_COUNT" -lt "$MINIMAX_MAX_POLLS" ]; do
  POLL_COUNT=$((POLL_COUNT + 1))
  if ! STATUS_RESPONSE="$(curl -sS --fail-with-body \
    --connect-timeout 10 --max-time 60 \
    "$MINIMAX_API_BASE/v2/query/video_generation/$TASK_ID" \
    -H "Authorization: Bearer $MINIMAX_API_KEY")"; then
    echo "Status request failed or timed out." >&2
    exit 1
  fi

  jq -e . >/dev/null <<<"$STATUS_RESPONSE" || exit 1
  TASK_STATUS="$(jq -r '.task.status // empty' <<<"$STATUS_RESPONSE")"
  echo "task=$TASK_ID status=$TASK_STATUS"

  case "$TASK_STATUS" in
    queued|running)
      [ "$POLL_COUNT" -ge "$MINIMAX_MAX_POLLS" ] || sleep 5
      ;;
    succeeded)
      DOWNLOAD_URL="$(jq -r '.task.content.url // empty' <<<"$STATUS_RESPONSE")"
      [ -n "$DOWNLOAD_URL" ] || exit 1
      break
      ;;
    failed|cancelled)
      printf '%s\n' "$STATUS_RESPONSE" | jq '{status: .task.status, error: .task.error}'
      exit 1
      ;;
    *)
      echo "Unknown video generation status: $TASK_STATUS" >&2
      exit 1
      ;;
  esac
done

[ "$TASK_STATUS" = "succeeded" ] || {
  echo "Polling stopped after $MINIMAX_MAX_POLLS status checks." >&2
  exit 1
}
```

The v2 API also supports task management. Listing accepts `page_num`, `page_size`, `filter.status`, `filter.task_ids`, `filter.model`, and `filter.task_type`; the response contains `items` and `total`.

```bash
# List tasks. Add approved filter fields when needed.
curl -sS --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  -G "$MINIMAX_API_BASE/v2/query/video_generation" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  --data-urlencode "page_num=1" \
  --data-urlencode "page_size=20" | jq '{items, total}'

# Delete or cancel one approved task.
curl -sS --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  -X DELETE "$MINIMAX_API_BASE/v2/video_generation/$TASK_ID" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" | jq '{task_id, action, status}'
```

Import the completed video only after the user approves the result:

```bash
narrator-ai-cli file transfer --link "$DOWNLOAD_URL" --json
```

Show the imported file details and get user confirmation before using its `file_id` in any downstream task. Keep normal source, subtitle, BGM, dubbing, and narration-template selection in the standard Narrator AI workflow.

## v1 Compatibility Workflow

Use v1 only when the selected approved model is one of the documented v1 models. Text-to-video requires `model` and `prompt`. Image-to-video requires `model` and `first_frame_image`; `prompt` is optional. Supported optional fields are `prompt_optimizer`, `fast_pretreatment`, `duration`, `resolution`, and `callback_url`.

```bash
# Text-to-video
jq -n \
  --arg model "$MINIMAX_VIDEO_MODEL" \
  --arg prompt "<approved prompt>" \
  '{model: $model, prompt: $prompt}' > request.json

# Image-to-video
jq -n \
  --arg model "$MINIMAX_VIDEO_MODEL" \
  --arg prompt "<approved prompt>" \
  --arg first_frame_image "<approved image URL or data URL>" \
  '{
    model: $model,
    prompt: $prompt,
    first_frame_image: $first_frame_image
  }' > request.json
```

Create and query the v1 task with Bearer authorization:

```bash
if ! CREATE_RESPONSE="$(curl -sS --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  -X POST "$MINIMAX_API_BASE/v1/video_generation" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d @request.json)"; then
  echo "Task creation failed or timed out; do not resubmit automatically." >&2
  exit 1
fi

jq -e . >/dev/null <<<"$CREATE_RESPONSE" || exit 1
[ "$(jq -r '.base_resp.status_code // empty' <<<"$CREATE_RESPONSE")" = "0" ] || {
  printf '%s\n' "$CREATE_RESPONSE" | jq .
  exit 1
}
TASK_ID="$(jq -r '.task_id // empty' <<<"$CREATE_RESPONSE")"
[ -n "$TASK_ID" ] || exit 1

POLL_COUNT=0
TASK_STATUS=""
FILE_ID=""
DOWNLOAD_URL=""

while [ "$POLL_COUNT" -lt "$MINIMAX_MAX_POLLS" ]; do
  POLL_COUNT=$((POLL_COUNT + 1))
  STATUS_RESPONSE="$(curl -sS --fail-with-body \
    --connect-timeout 10 --max-time 60 \
    -G "$MINIMAX_API_BASE/v1/query/video_generation" \
    -H "Authorization: Bearer $MINIMAX_API_KEY" \
    --data-urlencode "task_id=$TASK_ID")" || exit 1

  jq -e . >/dev/null <<<"$STATUS_RESPONSE" || exit 1
  TASK_STATUS="$(jq -r '.status // .task.status // empty' <<<"$STATUS_RESPONSE")"
  echo "task=$TASK_ID status=$TASK_STATUS"

  case "$TASK_STATUS" in
    Preparing|Queueing|Processing)
      [ "$POLL_COUNT" -ge "$MINIMAX_MAX_POLLS" ] || sleep 5
      ;;
    Success)
      DOWNLOAD_URL="$(jq -r '.task.content.url // empty' <<<"$STATUS_RESPONSE")"
      FILE_ID="$(jq -r '.file_id // empty' <<<"$STATUS_RESPONSE")"
      [ -n "$DOWNLOAD_URL" ] || [ -n "$FILE_ID" ] || exit 1
      break
      ;;
    Fail)
      printf '%s\n' "$STATUS_RESPONSE" | jq .
      exit 1
      ;;
    *)
      echo "Unknown video generation status: $TASK_STATUS" >&2
      exit 1
      ;;
  esac
done

[ "$TASK_STATUS" = "Success" ] || {
  echo "Polling stopped after $MINIMAX_MAX_POLLS status checks." >&2
  exit 1
}

if [ -z "$DOWNLOAD_URL" ]; then
  FILE_RESPONSE="$(curl -sS --fail-with-body \
    --connect-timeout 10 --max-time 60 \
    -G "$MINIMAX_API_BASE/v1/files/retrieve" \
    -H "Authorization: Bearer $MINIMAX_API_KEY" \
    --data-urlencode "file_id=$FILE_ID")" || exit 1

  jq -e . >/dev/null <<<"$FILE_RESPONSE" || exit 1
  [ "$(jq -r '.base_resp.status_code // empty' <<<"$FILE_RESPONSE")" = "0" ] || exit 1
  DOWNLOAD_URL="$(jq -r '.file.download_url // empty' <<<"$FILE_RESPONSE")"
  [ -n "$DOWNLOAD_URL" ] || exit 1
fi
```

Import the approved v1 result with the same `narrator-ai-cli file transfer --link "$DOWNLOAD_URL" --json` command used for v2.

## Official References

### v2

| Region | Create | Query | List | Delete | OpenAPI |
|---|---|---|---|---|---|
| Global | https://platform.minimax.io/docs/api-reference/video-generation-v2-create | https://platform.minimax.io/docs/api-reference/video-generation-v2-query | https://platform.minimax.io/docs/api-reference/video-generation-v2-list | https://platform.minimax.io/docs/api-reference/video-generation-v2-delete | https://platform.minimax.io/docs/api-reference/video/generation/api/v2-video-generation.json |
| China | https://platform.minimaxi.com/docs/api-reference/video-generation-v2-create | https://platform.minimaxi.com/docs/api-reference/video-generation-v2-query | https://platform.minimaxi.com/docs/api-reference/video-generation-v2-list | https://platform.minimaxi.com/docs/api-reference/video-generation-v2-delete | https://platform.minimaxi.com/docs/api-reference/video/generation/api/v2-video-generation.json |

### v1

| Region | Text-to-video | Image-to-video | Query | Download | Text OpenAPI | Image OpenAPI |
|---|---|---|---|---|---|---|
| Global | https://platform.minimax.io/docs/api-reference/video-generation-t2v | https://platform.minimax.io/docs/api-reference/video-generation-i2v | https://platform.minimax.io/docs/api-reference/video-generation-query | https://platform.minimax.io/docs/api-reference/video-generation-download | https://platform.minimax.io/docs/api-reference/video/generation/api/text-to-video.json | https://platform.minimax.io/docs/api-reference/video/generation/api/image-to-video.json |
| China | https://platform.minimaxi.com/docs/api-reference/video-generation-t2v | https://platform.minimaxi.com/docs/api-reference/video-generation-i2v | https://platform.minimaxi.com/docs/api-reference/video-generation-query | https://platform.minimaxi.com/docs/api-reference/video-generation-download | https://platform.minimaxi.com/docs/api-reference/video/generation/api/text-to-video.json | https://platform.minimaxi.com/docs/api-reference/video/generation/api/image-to-video.json |
