# MiniMax Video Generation (Optional)

> Back to [SKILL.md](../SKILL.md)

Use this optional path only when the user explicitly asks for a generated video asset, such as original B-roll, a transition, or a standalone clip for a Narrator AI project. It is not part of the default narration pipeline and must not replace source footage unless the user has the right to generate and use that footage.

## Confirm Before Submitting

A generation request may be billable and irreversible. Before the `POST` request, show the user and confirm:

- the selected API region and video model
- text-to-video or image-to-video mode
- the exact prompt and, for image-to-video, the first-frame image
- every optional request field, including duration and resolution
- the expected cost shown by the current MiniMax pricing documentation

Do not automatically retry the generation `POST`. A retry can create and charge for a duplicate task.

## Configure the Region and Credentials

Choose one region with the user. Keep the API key in the environment and never place it in `request.json` or a committed file.

```bash
export MINIMAX_API_KEY="<your MiniMax API key>"

# Global
export MINIMAX_API_BASE="https://api.minimax.io/v1"

# China (use this instead of the global value when selected)
# export MINIMAX_API_BASE="https://api.minimaxi.com/v1"
```

Select a currently supported model from the official API reference immediately before building the request. Model availability and valid option combinations can change, so do not guess or reuse a stale model ID.

| Region | Text-to-video reference | Image-to-video reference |
|---|---|---|
| Global | https://platform.minimax.io/docs/api-reference/video-generation-t2v | https://platform.minimax.io/docs/api-reference/video-generation-i2v |
| China | https://platform.minimaxi.com/docs/api-reference/video-generation-t2v | https://platform.minimaxi.com/docs/api-reference/video-generation-i2v |

```bash
export MINIMAX_VIDEO_MODEL="<model ID from the selected region's current API reference>"
```

## Build the Approved Request

For text-to-video, start with only the required fields. Add optional fields only when they appear in the current API reference and the user has approved their values.

```bash
jq -n \
  --arg model "$MINIMAX_VIDEO_MODEL" \
  --arg prompt "<approved prompt>" \
  '{model: $model, prompt: $prompt}' > request.json
```

For image-to-video, add the approved first-frame image. The API accepts a public image URL or a Base64 data URL; check the current size, format, dimension, and aspect-ratio requirements before submitting.

```bash
jq -n \
  --arg model "$MINIMAX_VIDEO_MODEL" \
  --arg prompt "<approved prompt>" \
  --arg first_frame_image "<approved image URL or data URL>" \
  '{model: $model, prompt: $prompt, first_frame_image: $first_frame_image}' > request.json
```

Show the complete `request.json` to the user and get final confirmation before continuing.

## Create the Task

```bash
CREATE_RESPONSE="$(curl -sS -X POST "$MINIMAX_API_BASE/video_generation" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d @request.json)"

echo "$CREATE_RESPONSE" | jq .
[ "$(echo "$CREATE_RESPONSE" | jq -r '.base_resp.status_code')" = "0" ] || exit 1
TASK_ID="$(echo "$CREATE_RESPONSE" | jq -r '.task_id // empty')"
[ -n "$TASK_ID" ] || exit 1
```

Do not repeat this command automatically if the response is interrupted or ambiguous. Query the returned task ID when available; otherwise ask the user before creating another task.

## Poll and Retrieve the Video

Poll at five-second intervals until the API returns a terminal status. Stop on unknown statuses instead of guessing.

```bash
while true; do
  STATUS_RESPONSE="$(curl -sS -G "$MINIMAX_API_BASE/query/video_generation" \
    -H "Authorization: Bearer $MINIMAX_API_KEY" \
    --data-urlencode "task_id=$TASK_ID")"

  [ "$(echo "$STATUS_RESPONSE" | jq -r '.base_resp.status_code')" = "0" ] || {
    echo "$STATUS_RESPONSE" | jq .
    exit 1
  }

  STATUS="$(echo "$STATUS_RESPONSE" | jq -r '.status // empty')"
  echo "task=$TASK_ID status=$STATUS"
  case "$STATUS" in
    Success)
      FILE_ID="$(echo "$STATUS_RESPONSE" | jq -r '.file_id // empty')"
      [ -n "$FILE_ID" ] || exit 1
      break
      ;;
    Fail)
      echo "$STATUS_RESPONSE" | jq .
      exit 1
      ;;
    Preparing|Queueing|Processing)
      sleep 5
      ;;
    *)
      echo "Unknown video generation status: $STATUS"
      exit 1
      ;;
  esac
done

FILE_RESPONSE="$(curl -sS -G "$MINIMAX_API_BASE/files/retrieve" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  --data-urlencode "file_id=$FILE_ID")"

[ "$(echo "$FILE_RESPONSE" | jq -r '.base_resp.status_code')" = "0" ] || {
  echo "$FILE_RESPONSE" | jq .
  exit 1
}
DOWNLOAD_URL="$(echo "$FILE_RESPONSE" | jq -r '.file.download_url // empty')"
[ -n "$DOWNLOAD_URL" ] || exit 1
```

The download URL is temporary. Import it promptly if the user wants to use the asset in the narration workflow:

```bash
narrator-ai-cli file transfer --link "$DOWNLOAD_URL" --json
```

Show the imported file details and get user confirmation before using its `file_id` in any downstream task. Keep normal source, subtitle, BGM, dubbing, and narration-template selection in the standard Narrator AI workflow.

## Official Status and Download References

| Region | Task status | File download |
|---|---|---|
| Global | https://platform.minimax.io/docs/api-reference/video-generation-query | https://platform.minimax.io/docs/api-reference/video-generation-download |
| China | https://platform.minimaxi.com/docs/api-reference/video-generation-query | https://platform.minimaxi.com/docs/api-reference/video-generation-download |
