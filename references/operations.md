# Operations — Polling, Files, Account, Errors

> ← Back to [SKILL.md](../SKILL.md)

Reference for task polling, task management commands, file operations, user/account commands, and the full error code table.

---

## Task Query Response Shape

`narrator-ai-cli task query <task_id> --json` returns a **flat** object. The top level is the task envelope; `results.tasks[]` is a nested array of sub-tasks with a different status code system. Reading the wrong path is the #1 cause of silent infinite polling.

| Path | Type | What it is |
|---|---|---|
| `.status` | int (0–4) | **Task-level status — what polling reads.** See "Task status codes" below |
| `.task_id` | str (32-char hex) | Same id you passed to `task query` |
| `.task_order_num` | str (prefixed, e.g. `generate_writing_xxxxx`) | **Pass this as `order_num` to downstream tasks.** Never pass `.task_id` (hex) instead |
| `.completed_at` | str / null | ISO timestamp once `status=2` |
| `.consumed_points` | float | Billing amount actually charged |
| `.files[]` | list | Output files. Each entry: `{file_id, file_path, file_name, suffix, ...}` |
| `.files[0].file_id` | str | **The output `file_id` to pass to the next step** (e.g. fast-writing's narration script → fast-clip-data) |
| `.results.tasks[0].video_url` | str | Finished MP4 URL (video-composing only) |
| `.results.tasks[0].task_result` | str | Output path or JSON string. For writing tasks: narration script path. For popular-learning: JSON containing `agent_unique_code` |
| `.results.tasks[0].status` | int (different system, e.g. `9`) | **Sub-task status. Do NOT poll on this — it uses a different code system from `.status`** |
| `.results.order_info.order_num` | str (e.g. `script_xxxxx`) | Billing-side identifier. **NOT** what downstream tasks accept — submitting it returns `10001` |

> ⚠️ **Two `status` fields exist.** Top-level `.status` (0–4) is what polling watches. Nested `.results.tasks[0].status` uses a different code system (e.g. `9` on success). Polling against the nested one returns nonsense values and loops forever.
>
> ⚠️ **Two `order_num`-shaped fields exist.** Top-level `.task_order_num` (prefixed string like `generate_writing_xxxxx` / `fast_writing_clip_data_xxxxx`) is what downstream tasks accept. Nested `.results.order_info.order_num` (`script_xxxxx`) is a billing-side id and is rejected. Also: `.task_id` is a 32-char hex string — never submit it as `order_num`, returns `10001 任务关联记录数据异常`.

---

## Task Polling

> ⚠️ **Agent behavior — standard polling pattern**: Always use the `while` loop below when monitoring a task. **Never** use a `for` loop with a fixed iteration count — it may exhaust before the task finishes. The loop runs until status `2` (success) or `3` (failed) and cannot be silently interrupted mid-run.

```bash
# Standard polling loop — use this every time a task needs to be monitored
# NOTE: variable is named `task_status`, not `status` — `$status` is a
# read-only built-in in zsh (alias for $?), so plain `status=...` will
# error with "read-only variable: status" on macOS default shell.
TASK_ID="<task_id>"
empty_streak=0
iter=0
MAX_EMPTY=12        # ~1 min of consecutive parse failures → bail out
MAX_ITERATIONS=720  # ~1 hour absolute cap → bail out regardless of status
while [ "$iter" -lt "$MAX_ITERATIONS" ]; do
  iter=$((iter + 1))
  result=$(narrator-ai-cli task query "$TASK_ID" --json 2>&1)
  task_status=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('status', ''))   # top-level field — see 'Task Query Response Shape' above
except Exception:
    print('')
" 2>/dev/null)
  echo "[$(date '+%H:%M:%S')] iter=$iter task=$TASK_ID status=$task_status"
  [ "$task_status" = "2" ] && echo "Done." && break
  [ "$task_status" = "3" ] && echo "Failed:" && echo "$result" && break
  if [ -z "$task_status" ]; then
    empty_streak=$((empty_streak + 1))
    if [ "$empty_streak" -ge "$MAX_EMPTY" ]; then
      echo "Aborting: $MAX_EMPTY consecutive unparseable responses. Last response:" && echo "$result"
      break
    fi
  else
    empty_streak=0
  fi
  sleep 5
done
[ "$iter" -ge "$MAX_ITERATIONS" ] && echo "Aborting: hit MAX_ITERATIONS=$MAX_ITERATIONS (~1h). Last response:" && echo "$result"
```

> ⚠️ **Why `task_status`, not `status`**: in zsh (macOS default shell) `$status` is a read-only built-in (alias for `$?`). Assigning to it errors out with `read-only variable: status` and the loop never starts. Use a different variable name.

> ⚠️ **Why the empty-status guard**: `task query` may return non-JSON (network error, auth failure, CLI traceback). Without the guard, an empty `task_status` neither triggers success nor failure, and the loop runs forever. After `MAX_EMPTY` consecutive unparseable responses (~1 min at 5 s intervals), the loop bails out with the last raw response so the agent can diagnose.

> ⚠️ **Why the absolute iteration cap**: `MAX_ITERATIONS=720` (~1 hour) is a belt-and-suspenders ceiling for the case where `task_status` parses cleanly to a value that is neither `"2"` nor `"3"` (e.g., the API adds a new status code, returns `"running"`, or the task is genuinely stuck in `1`). The empty-status guard does NOT catch this — non-empty parses reset `empty_streak` to 0. Without the cap, such a response loops forever. Tune `MAX_ITERATIONS` upward only for genuinely long-running tasks.

> ⚠️ **If you write your own polling in Python instead of bash**: the API returns task `status` as an **integer** (`2`, `3`, etc.). Compare with `int` (`if s == 2`) **or** coerce both sides to string (`if str(s) == "2"`) — but be consistent. Using `if s == "2"` against an integer response (or vice versa) will silently never match and the loop will run forever.

### Resuming after the loop bails out

**Bailing out (`MAX_EMPTY` or `MAX_ITERATIONS` triggered) does NOT cancel the task** — the loop only stops local polling. The server-side task continues running independently. To resume:

1. **Spot-check current status** with a single query (no loop):
   ```bash
   narrator-ai-cli task query "$TASK_ID" --json | python3 -m json.tool
   ```
   If top-level `.status` is already `2`, the task finished while you weren't watching — read the result fields (`.task_order_num`, `.files[0].file_id`, `.results.tasks[0].video_url`, etc. — see "Task Query Response Shape" above) directly and continue to the next step. No need to re-poll.

2. **Re-enter the loop** with the same `TASK_ID` if status is still `0` or `1`. The API has no notion of "who is polling" — re-querying simply returns the latest state.

3. **Lost the `TASK_ID`?** List in-progress tasks (status `1`) and pick yours by type or recency:
   ```bash
   narrator-ai-cli task list --status 1 --json            # all in-progress
   narrator-ai-cli task list --status 1 --type 9 --json   # in-progress fast-writing only
   ```
   See "Task type IDs" below for the `--type` mapping.

**Polling rules:**
- Poll every **5 seconds**. Faster polling adds API load without benefit.
- Most tasks complete in 30 seconds to several minutes.
- `search-movie` may take 60+ seconds (Gradio backend, results cached 24h).

**Task status codes:**

| Code | Meaning |
|---|---|
| 0 | init |
| 1 | in_progress |
| 2 | success |
| 3 | failed |
| 4 | cancelled |

---

## Task Management Commands

```bash
# Single query (spot-checks only — do not use in automated polling)
narrator-ai-cli task query <task_id> --json

# List tasks with filters
narrator-ai-cli task list --json
narrator-ai-cli task list --status 2 --type 9 --json     # completed fast-writing
narrator-ai-cli task list --category commentary --json

# Estimate point cost before creating
narrator-ai-cli task budget --json -d '{
  "learning_model_id": "<id>",
  "native_video": "<video_file_id>",
  "native_srt": "<srt_file_id>"
}'
# Returns: viral_learning_points, commentary_generation_points,
#          video_synthesis_points, visual_template_points, total_consume_points

# Verify materials before task creation
narrator-ai-cli task verify --json -d '{
  "bgm": "<bgm_id>",
  "dubbing_id": "<voice_id>",
  "native_video": "<video_file_id>",
  "native_srt": "<srt_file_id>"
}'
# Returns: is_valid (bool), errors (list), warnings (list)

# Retrieve / save narration scripts
narrator-ai-cli task get-writing --json
narrator-ai-cli task save-writing -d '{...}'
narrator-ai-cli task save-clip -d '{...}'

# List task types with details
narrator-ai-cli task types -V
```

**Task type IDs** (for the `--type` filter on `task list`):

| ID | Type |
|---|---|
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

---

## File Operations

```bash
narrator-ai-cli file upload ./video.mp4 --json           # 3-step: presigned → OSS → callback
narrator-ai-cli file transfer --link "<url>" --json       # import by HTTP/Baidu/PikPak link
narrator-ai-cli file list --json                          # pagination, --search filter
narrator-ai-cli file info <file_id> --json                # name, path, size, category, timestamps
narrator-ai-cli file download <file_id> --json            # returns time-limited presigned URL
narrator-ai-cli file storage --json                       # used_size, max_size, usage_percentage
narrator-ai-cli file delete <file_id> --json              # irreversible
```

**File categories**: 1 = video, 2 = audio, 3 = image, 4 = doc, 5 = torrent, 6 = other.

**Supported formats**: `.mp4`, `.mkv`, `.mov`, `.mp3`, `.m4a`, `.wav`, `.srt`, `.jpg`, `.jpeg`, `.png`.

---

## User & Account

```bash
narrator-ai-cli user balance --json                       # account points balance
narrator-ai-cli user login --json                         # login with username/password
narrator-ai-cli user keys --json                          # list sub API keys
narrator-ai-cli user create-key --json                    # create a new sub API key
```

---

## Error Codes

> **Support contact** (for balance/billing, app_key issues — including obtaining, renewing, or troubleshooting API keys): WeChat `gezimufeng`, or email `merlinyang@gridltd.com`.

| Code | Meaning | Action |
|---|---|---|
| `10000` | Success | - |
| `10001` | Failed | Check params |
| `10002` | App key expired | Contact support to renew |
| `10003` | Sign expired | Check timestamp |
| `10004` | Invalid app key | Run `config show` to verify; contact support if invalid |
| `10005` | Invalid sign | Check `app_key` config; contact support if persists |
| `10006` | Invalid timestamp | Check clock sync |
| `10007` | Not found | Check resource ID |
| `10008` | Invalid method | Check HTTP method |
| `10009` | Insufficient balance | Contact support to top up |
| `10010` | Task not found | Verify `task_id` |
| `10011` | Task create failed | Retry or check params |
| `10012` | Task type not found | Use `task types` to list valid types |
| `10013` | Insufficient balance (key) | Contact support to top up sub-key quota |
| `40000` | Gradio timeout | Retry (backend overloaded) |
| `50000` | Unauthorized | Check `app_key` config; contact support |
| `50001` | Database error | Retry later |
| `50002` | System busy | Retry later |
| `50003` | System error | Contact support |
| `60000` | Retryable error | Safe to retry |

CLI exits with code `1` on any error and prints to stderr.
