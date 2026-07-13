# MiniMax Video Generation (Optional)

> Back to [SKILL.md](../SKILL.md)

Use this optional path only when the user explicitly asks for a generated video asset, such as original B-roll, a transition, or a standalone clip for a Narrator AI project. It is not part of the default narration pipeline and must not replace source footage unless the user has the right to generate and use that footage.

## Confirm Before Submitting

A generation request may be billable and irreversible. Before the `POST` request, show the user and confirm:

- the selected API region and video model
- text-to-video or image-to-video mode
- the exact prompt and, for image-to-video, the first-frame image
- every optional request field, including duration and resolution
- the maximum number of five-second status checks
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
export MINIMAX_MAX_POLLS="<approved positive integer>"

case "${MINIMAX_API_KEY:-}" in
  ""|"<"*) echo "Set MINIMAX_API_KEY before continuing." >&2; exit 1 ;;
esac
case "${MINIMAX_VIDEO_MODEL:-}" in
  ""|"<"*) echo "Set MINIMAX_VIDEO_MODEL before continuing." >&2; exit 1 ;;
esac
case "${MINIMAX_API_BASE:-}" in
  https://api.minimax.io/v1|https://api.minimaxi.com/v1) ;;
  *) echo "Select a documented MINIMAX_API_BASE value." >&2; exit 1 ;;
esac
case "${MINIMAX_MAX_POLLS:-}" in
  ""|"<"*|0*|*[!0-9]*)
    echo "Set MINIMAX_MAX_POLLS to a positive integer." >&2
    exit 1
    ;;
esac
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
jq -e 'type == "object"' request.json >/dev/null || exit 1

if ! CREATE_RESPONSE="$(curl -sS --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  -X POST "$MINIMAX_API_BASE/video_generation" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d @request.json)"; then
  echo "Task creation failed or timed out; do not resubmit automatically." >&2
  exit 1
fi

printf '%s\n' "$CREATE_RESPONSE" | jq . || exit 1
[ "$(jq -r '.base_resp.status_code' <<<"$CREATE_RESPONSE")" = "0" ] || exit 1
TASK_ID="$(jq -r '.task_id // empty' <<<"$CREATE_RESPONSE")"
[ -n "$TASK_ID" ] || exit 1
```

Do not repeat this command automatically if the response is interrupted or ambiguous. Query the returned task ID when available; otherwise ask the user before creating another task.

## Poll and Retrieve the Video

Poll at five-second intervals until the API returns a terminal status. Stop on unknown statuses instead of guessing.

```bash
POLL_COUNT=0
STATUS=""
while [ "$POLL_COUNT" -lt "$MINIMAX_MAX_POLLS" ]; do
  POLL_COUNT=$((POLL_COUNT + 1))
  if ! STATUS_RESPONSE="$(curl -sS --fail-with-body \
    --connect-timeout 10 --max-time 60 \
    -G "$MINIMAX_API_BASE/query/video_generation" \
    -H "Authorization: Bearer $MINIMAX_API_KEY" \
    --data-urlencode "task_id=$TASK_ID")"; then
    echo "Status request failed or timed out." >&2
    exit 1
  fi

  jq -e . >/dev/null <<<"$STATUS_RESPONSE" || exit 1
  [ "$(jq -r '.base_resp.status_code' <<<"$STATUS_RESPONSE")" = "0" ] || {
    printf '%s\n' "$STATUS_RESPONSE" | jq .
    exit 1
  }

  STATUS="$(jq -r '.status // empty' <<<"$STATUS_RESPONSE")"
  echo "task=$TASK_ID status=$STATUS"
  case "$STATUS" in
    Success)
      FILE_ID="$(jq -r '.file_id // empty' <<<"$STATUS_RESPONSE")"
      [ -n "$FILE_ID" ] || exit 1
      break
      ;;
    Fail)
      printf '%s\n' "$STATUS_RESPONSE" | jq .
      exit 1
      ;;
    Preparing|Queueing|Processing)
      [ "$POLL_COUNT" -ge "$MINIMAX_MAX_POLLS" ] || sleep 5
      ;;
    *)
      echo "Unknown video generation status: $STATUS"
      exit 1
      ;;
  esac
done

[ "$STATUS" = "Success" ] || {
  echo "Polling stopped after $MINIMAX_MAX_POLLS status checks." >&2
  exit 1
}

if ! FILE_RESPONSE="$(curl -sS --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  -G "$MINIMAX_API_BASE/files/retrieve" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  --data-urlencode "file_id=$FILE_ID")"; then
  echo "File retrieval failed or timed out." >&2
  exit 1
fi

jq -e . >/dev/null <<<"$FILE_RESPONSE" || exit 1
[ "$(jq -r '.base_resp.status_code' <<<"$FILE_RESPONSE")" = "0" ] || {
  printf '%s\n' "$FILE_RESPONSE" | jq .
  exit 1
}
DOWNLOAD_URL="$(jq -r '.file.download_url // empty' <<<"$FILE_RESPONSE")"
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
