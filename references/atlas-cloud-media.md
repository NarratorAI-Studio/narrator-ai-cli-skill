# Atlas Cloud Media Assist

> Back to [SKILL.md](../SKILL.md)

Use Atlas Cloud only as an optional helper when the user explicitly asks for generated images, cover art, B-roll, or other media assets around a Narrator AI project. It is not part of the default narration pipeline, and it should not replace the required Narrator resource-selection flow in `resources.md`.

## When to Use It

Use this path only when all of the following are true:

- The user asks for a generated visual or video asset, not just a narrated movie recap.
- The asset can be treated as a separate generated file or reference, then imported into Narrator AI with `narrator-ai-cli file transfer --link`.
- The user has approved the model, prompt, request body, and any expected cost before the generation request is submitted.

Do not use Atlas Cloud to upload or regenerate source movie files unless the user has the rights to do so. Keep source movies, subtitles, BGM, dubbing, and narration templates in the normal Narrator AI workflow.

## Required Runtime Discovery

Model IDs and input schemas change. Always fetch the live model list and the selected model schema before constructing a request body.

```bash
curl -s https://api.atlascloud.ai/api/v1/models \
  | jq '.data[]
    | select(.display_console == true and (.type == "Image" or .type == "Video"))
    | {model, type, categories, schema, readme, price}'
```

After the user chooses a model, fetch its schema:

```bash
MODEL_ID="<model from live list>"
SCHEMA_URL="$(curl -s https://api.atlascloud.ai/api/v1/models \
  | jq -r --arg model "$MODEL_ID" '.data[] | select(.model == $model) | .schema')"

curl -s "$SCHEMA_URL" | jq '.components.schemas.Input.properties'
```

Only send fields that appear in the schema. If a field is not in the schema, do not include it.
If the selected model has no schema URL, choose a different model or stop and ask for the authoritative model docs. Do not guess the request fields.

## Submit a Generation Task

Set the API key in the environment; never write it into a repo file or task request that will be committed.

```bash
export ATLASCLOUD_API_KEY="<your Atlas Cloud API key>"
export ATLAS_MEDIA_BASE="https://api.atlascloud.ai/api/v1"
```

Create `request.json` from the selected model schema. This placeholder is intentionally generic:

```json
{
  "model": "<MODEL_ID>",
  "<schema-required-field>": "<value approved by user>"
}
```

For image models:

```bash
curl -s -X POST "$ATLAS_MEDIA_BASE/model/generateImage" \
  -H "Authorization: Bearer $ATLASCLOUD_API_KEY" \
  -H "Content-Type: application/json" \
  -d @request.json
```

For video models:

```bash
curl -s -X POST "$ATLAS_MEDIA_BASE/model/generateVideo" \
  -H "Authorization: Bearer $ATLASCLOUD_API_KEY" \
  -H "Content-Type: application/json" \
  -d @request.json
```

Save the returned prediction ID from `.data.id`.

## Poll for Results

Poll until the task reaches a terminal state. Do not retry POST requests automatically, because generation can be billable and a retry may create a duplicate task.

```bash
PREDICTION_ID="<prediction id from submit response>"

while true; do
  result="$(curl -s "$ATLAS_MEDIA_BASE/model/prediction/$PREDICTION_ID" \
    -H "Authorization: Bearer $ATLASCLOUD_API_KEY")"

  prediction_status="$(echo "$result" | jq -r '.data.status // empty')"
  echo "prediction=$PREDICTION_ID status=$prediction_status"

  case "$prediction_status" in
    completed|succeeded)
      echo "$result" | jq '.data.outputs'
      break
      ;;
    failed)
      echo "$result"
      break
      ;;
  esac

  sleep 5
done
```

## Import the Output into Narrator AI

When Atlas Cloud returns an output URL that should become part of the Narrator AI workflow, import it through the CLI instead of downloading and re-uploading manually:

```bash
narrator-ai-cli file transfer --link "<atlas output url>" --json
```

Use the returned `file_id` only after showing the imported asset details to the user and getting confirmation. Continue with the normal Narrator steps after that.
